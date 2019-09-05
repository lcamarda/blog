#!/bin/bash

NSX_MANAGER="nsxmgr-01a"
NSX_USER="admin"
PI_NAME="neteng"
PI_ROLE="network_engineer"

NSX_SUPERUSER_CERT_FILE="superuser.crt"
NSX_SUPERUSER_KEY_FILE="superuser.key"

stty -echo
printf "Password: "
read NSX_PASSWORD
stty echo

openssl req \
  -newkey rsa:2048 \
  -x509 \
  -nodes \
  -keyout "$NSX_SUPERUSER_KEY_FILE" \
  -new \
  -out "$NSX_SUPERUSER_CERT_FILE" \
  -subj /CN="$PI_NAME" \
  -extensions client_server_ssl \
  -config <(
    cat /etc/ssl/openssl.cnf \
    <(printf '[client_server_ssl]\nextendedKeyUsage = clientAuth\n')
  ) \
  -sha256 \
  -days 730

cert_request=$(cat <<END
  {
    "display_name": "$PI_NAME",
    "pem_encoded": "$(awk '{printf "%s\\n", $0}' $NSX_SUPERUSER_CERT_FILE)"
  }
END
)

CERT_ID=$(curl -k -X POST \
    "https://${NSX_MANAGER}/api/v1/trust-management/certificates?action=import" \
    -u "$NSX_USER:$NSX_PASSWORD" \
    -H 'content-type: application/json' \
    -d "$cert_request" \
    | jq -r '.results[0] | .id')


NODE_ID=$(cat /proc/sys/kernel/random/uuid)

pi_request=$(cat <<END
    {
         "display_name": "$PI_NAME",
         "name": "$PI_NAME",
         "role": "$PI_ROLE",
         "certificate_id": "$CERT_ID",
         "node_id": "$NODE_ID"
    }
END
)

curl -k -X POST \
    "https://${NSX_MANAGER}/api/v1/trust-management/principal-identities" \
    -u "$NSX_USER:$NSX_PASSWORD" \
    -H 'content-type: application/json' \
    -d "$pi_request"

curl -k -X GET \
    "https://${NSX_MANAGER}/api/v1/trust-management/principal-identities" \
    -u "$NSX_USER:$NSX_PASSWORD"
