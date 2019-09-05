NSX_MANAGER="nsxmgr-01a"

pi_request=$(cat <<END
  {
    "resource_type":"Infra",
    "children":[
      {
        "resource_type":"ChildTier1",
        "marked_for_delete":false,
        "Tier1":{
          "resource_type":"Tier1",
          "id":"t1-tenant2",
          "description":"tenant-2 gateway",
          "display_name":"t1-tenant2",
          "failover_mode":"NON_PREEMPTIVE",
          "tier0_path":"/infra/tier-0s/t0-sitea",
          "children":[
            {
              "resource_type":"ChildLocaleServices",
              "LocaleServices":{
                "resource_type":"LocaleServices",
                "id":"default",
                "edge_cluster_path":"/infra/sites/default/enforcement-points/default/edge-clusters/331797ee-9168-4070-9f1c-7cabd968b889"
              }
            },
            {
              "resource_type":"ChildSegment",
              "Segment":{
                "resource_type":"Segment",
                "id":"ov-web",
                "description":"overlay web logical switch",
                "display_name":"OV-WEB",
                "transport_zone_path":"/infra/sites/default/enforcement-points/default/transport-zones/992e0876-0ebd-45b4-9e47-020bc592bffd",
                "subnets":[
                  {
                    "gateway_address":"172.16.10.1/24"
                  }
                ]
              }
            },
            {
              "resource_type":"ChildSegment",
              "Segment":{
                "resource_type":"Segment",
                "id":"ov-app",
                "description":"overlay app logical switch",
                "display_name":"OV-APP",
                "transport_zone_path":"/infra/sites/default/enforcement-points/default/transport-zones/992e0876-0ebd-45b4-9e47-020bc592bffd",
                "subnets":[
                  {
                    "gateway_address":"172.16.20.1/24"
                  }
                ]
              }
            },
            {
              "resource_type":"ChildSegment",
              "Segment":{
                "resource_type":"Segment",
                "id":"ov-db",
                "description":"overlay db logical switch",
                "display_name":"OV-DB",
                "transport_zone_path":"/infra/sites/default/enforcement-points/default/transport-zones/992e0876-0ebd-45b4-9e47-020bc592bffd",
                "subnets":[
                  {
                    "gateway_address":"172.16.30.1/24"
                  }
                ]
              }
            }
          ]
        }
      }
     ]
    }

END
)

curl -k -X PATCH \
    "https://${NSX_MANAGER}/policy/api/v1/infra/" \
    -H 'content-type: application/json' \
    --key ./superuser.key \
    -d "$pi_request" \
    --cert ./superuser.crt
