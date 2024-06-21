#!/usr/bin/env zsh

CLUSTER_TYPE="$1"

if [[ -z "$CLUSTER_TYPE" ]]
then
  echo_error "Please provide a cluster type"
  exit 2
fi

for CLUSTER in "${(@f)$(nbx cluster type="$CLUSTER_TYPE" -j | jq -er '.[].name')}"
do
  echo_info "Processing cluster: $CLUSTER"

  for role in server storage management-server
  do
    echo_info "Cluster: $CLUSTER - Role: $ROLE"

    DATA=$(nbx d cluster_id=$CLUSTER role=$ROLE -g \
      --cols +interfaces.ip_addresses.address,interfaces.ip_addresses.id,interfaces.name \
      --ids -j |
        jq -er '[
          .[] |
          (.interfaces[] | select(.name == "fabric").ip_addresses[]) as $fabric_ip |
          (.interfaces[] | select(.name == "IPMI").ip_addresses[]) as $oob_ip |

          {
            id: (.id | tonumber),
            primary_ip4: ($fabric_ip.id | tonumber),
            oob_ip: ($oob_ip.id | tonumber),
          }
        ]')

    if [[ "$DATA" == "[]" ]]
    then
      echo_warning "No data for $CLUSTER $ROLE"
      continue
    fi

    nbx --noconfirm raw dcim/devices/ -X PATCH --data "$(jq -c <<< "$DATA")"
  done
done
