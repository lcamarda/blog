#!/bin/bash

while getopts h:u:p:n:s:t: flag
do
    case "${flag}" in
        h) NSX_MANAGER=${OPTARG};;
        u) NSX_USER=${OPTARG};;
        p) NSX_PASSWORD=${OPTARG};;
        n) NODE_UUID=${OPTARG};;
        s) SERVICE_TYPE=${OPTARG};;
        t) TN_ID=${OPTARG};;
    esac
done


if [ -z $NSX_MANAGER ]; then
  echo "Supported service-types: MGMT_CLUSTER, MGMT_PLANE, API, NOTIFICATION_COLLECTOR, SYSLOG_SERVER, RSYSLOG_CLIENT, APH, APH_TN, GLOBAL_MANAGER, LOCAL_MANAGER, CLIENT_AUTH, RMQ, K8S_MSG_CLIENT, WEB_PROXY, CBM_API, CBM_CCP, CBM_CSM, CBM_MP, CBM_GM, CBM_AR, CBM_MONITORING, CBM_IDPS_REPORTING, CBM_CM_INVENTORY, CBM_MESSAGING_MANAGER, CBM_UPGRADE_COORDINATOR, CBM_SITE_MANAGER, CBM_CLUSTER_MANAGER, CBM_CORFU, CBM_SITE_PROXY_CLIENT, COMPUTE_MANAGER, CCP"
  exit 1
fi

touch ~/.rnd

file='ca.crt'

if [ -e $file ]; then
  echo "$file  exists."
else
  echo 'Generate a private key for the CA'
  openssl ecparam -genkey -name prime256v1 -out ca.key
  echo 'Create a self-signed root CA certificate'
  openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 -out ca.crt -subj "/CN=EAL4-DEMO-CA" -extensions v3_ca
fi


#Replace Host TN certificate
if [ -z $TN_ID ]; then
  echo "TN_ID not specified"
else
  file=$TN_ID'.crt'

  if [ -e $file ]; then
    echo "$file  exists."
  else

    echo "File not found, generting new certificate for TN $TN_ID"
    echo "Generate a private key for the service"
    openssl ecparam -genkey -name prime256v1 -out $TN_ID'.key' -noout
    echo "Create a CSR for the service"
    openssl req -new -key $TN_ID'.key' -out  $TN_ID'.csr' -subj "/CN=EAL4-DEMO-"$TN_ID -extensions client_server_ssl -config <(cat /etc/ssl/openssl.cnf <(printf '[client_server_ssl]\nextendedKeyUsage = serverAuth,clientAuth\n'))
    echo "Sign the CSR with the CA"
    openssl x509 -req -in $TN_ID'.csr' -CA ca.crt -CAkey ca.key -CAcreateserial -out $TN_ID'.crt' -days 365 -sha256 -extfile <(printf "extendedKeyUsage=serverAuth,clientAuth")
  fi
  cert_request=$(cat <<END
  {
    "pem_encoded": "$(awk '{printf "%s\\n", $0}' $TN_ID'.crt' ca.crt )",
    "private_key": "$(awk '{printf "%s\\n", $0}' $TN_ID'.key' )"
  }
END
)
  echo $cert_request | jq '.'

  ##Upload the certificate to NSX and collect the certificate ID:

  response=$(curl -k -X POST \
      "https://${NSX_MANAGER}/api/v1/trust-management/certificates/action/replace-host-certificate/$TN_ID" \
      -u "$NSX_USER:$NSX_PASSWORD" \
      -H 'content-type: application/json' \
      -d "$cert_request")

  echo "Result of certificate import API:"
  echo $response | jq '.'
  exit 1
fi



#Replace NSX Manager certificate

file=$SERVICE_TYPE'.crt'

if [ -e $file ]; then
  echo "$file  exists."
else



  echo "File not found, generting new certificate for the service"
  echo "Generate a private key for the service"
  openssl ecparam -genkey -name prime256v1 -out $SERVICE_TYPE'.key' -noout

  echo "Create a CSR for the service"
  openssl req -new -key $SERVICE_TYPE'.key' -out  $SERVICE_TYPE'.csr' -subj "/CN=EAL4-DEMO-"$SERVICE_TYPE -extensions client_server_ssl -config <(cat /etc/ssl/openssl.cnf <(printf '[client_server_ssl]\nextendedKeyUsage = serverAuth,clientAuth\n'))

  echo "Sign the CSR with the CA"
  openssl x509 -req -in $SERVICE_TYPE'.csr' -CA ca.crt -CAkey ca.key -CAcreateserial -out $SERVICE_TYPE'.crt' -days 365 -sha256 -extfile <(printf "extendedKeyUsage=serverAuth,clientAuth")
fi

##Prepare the body for the upload of the certificate, the entrie certicate chain must be provided (CA + Service cert in this order), and the cert private key:

echo $SERVICE_TYPE

cert_request=$(cat <<END
  {
    "display_name": "$SERVICE_TYPE",
    "pem_encoded": "$(awk '{printf "%s\\n", $0}' $SERVICE_TYPE'.crt' ca.crt )",
    "private_key": "$(awk '{printf "%s\\n", $0}' $SERVICE_TYPE'.key' )"
  }
END
)


##Upload the certificate to NSX and collect the certificate ID:

response=$(curl -k -X POST \
    "https://${NSX_MANAGER}/api/v1/trust-management/certificates?action=import" \
    -u "$NSX_USER:$NSX_PASSWORD" \
    -H 'content-type: application/json' \
    -d "$cert_request")

echo "Result of certificate import API:"
echo $response | jq '.'

echo "Certificate ID to be referenced in the apply certificate API:"
CERT_ID=$(echo $response | jq -r '.results[0] | .id')

echo $CERT_ID

##Apply the certificate to the service:
if [ -z $NODE_UUID ]; then
  curl -k -X POST \
    "https://${NSX_MANAGER}/api/v1/trust-management/certificates/$CERT_ID?action=apply_certificate&service_type=$SERVICE_TYPE" \
    -u "$NSX_USER:$NSX_PASSWORD" \
    -H 'content-type: application/json'
else
  curl -k -X POST \
    "https://${NSX_MANAGER}/api/v1/trust-management/certificates/$CERT_ID?action=apply_certificate&service_type=$SERVICE_TYPE&node_id=$NODE_UUID" \
    -u "$NSX_USER:$NSX_PASSWORD" \
    -H 'content-type: application/json'
fi
