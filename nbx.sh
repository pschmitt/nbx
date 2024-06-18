#!/usr/bin/env bash

NETBOX_URL="${NETBOX_URL:-http://localhost:8000}"
NETBOX_API_TOKEN="${NETBOX_API_TOKEN:-}"

DRY_RUN="${DRY_RUN:-}"
CONFIRM="${CONFIRM:-1}"

declare -A NETBOX_API_ENDPOINTS=(
  [clusters]="virtualization/clusters/"
  [devices]="dcim/devices/"
  [locations]="dcim/locations/"
  [racks]="dcim/racks/"
  [sites]="dcim/sites/"
  [tenants]="tenancy/tenants/"
)

usage() {
  echo "Usage: $(basename "$0") [options] ACTION [ARGS]" >&2
  echo
  echo "Actions:"
  echo "  clusters [FILTERS]     List clusters"
  echo "  devices  [FILTERS]     List devices"
  echo "  graphql  QUERY FIELDS  GraphQL query"
  echo "  raw      ENDPOINT      Fetch raw data from an endpoint"
  echo "  racks    [FILTERS]     List racks"
  echo "  sites    [FILTERS]     List sites"
}

echo_info() {
  echo -e "\e[1m\e[34mINF\e[0m $*" >&2
}

echo_success() {
  echo -e "\e[1m\e[32mOK\e[0m $*" >&2
}

echo_warning() {
  [[ -n "$NO_WARNING" ]] && return 0
  echo -e "\e[1m\e[33mWRN\e[0m $*" >&2
}

echo_error() {
  echo -e "\e[1m\e[31mERR\e[0m $*" >&2
}

echo_debug() {
  [[ -z "${DEBUG}" ]] && return 0
  echo -e "\e[1m\e[35mDBG\e[0m $*" >&2
}

echo_dryrun() {
  echo -e "\e[1m\e[35mDRY\e[0m $*" >&2
}

echo_confirm() {
  if [[ -n "$NO_CONFIRM" ]]
  then
    return 0
  fi

  local msg_pre=$'\e[31mASK\e[0m'
  local msg="${1:-"Continue?"}"
  local yn
  read -r -n1 -p "${msg_pre} ${msg} [y/N] " yn
  [[ "$yn" =~ ^[yY] ]]
  local rc="$?"
  echo # append a NL
  return "$rc"
}

arr_to_json() {
  printf '%s\n' "$@" | jq -Rn '[inputs]'
}

# shellcheck disable=SC2120
colorizecolumns() {
  if [[ -n "$NO_COLOR" ]]
  then
    cat "$@"
    return "$?"
  fi

  awk '
    BEGIN {
      # Define colors
      colors[0] = "\033[36m" # cyan
      colors[1] = "\033[32m" # green
      colors[2] = "\033[35m" # magenta
      colors[3] = "\033[37m" # white
      colors[4] = "\033[33m" # yellow
      colors[5] = "\033[34m" # blue
      colors[6] = "\033[38m" # gray
      colors[7] = "\033[31m" # red
      reset = "\033[0m"
    }

    {
      field_count = 0

      # Process the line character by character
      for (i = 1; i <= length($0); i++) {
        # Current char
        char = substr($0, i, 1)

        if (char ~ /[\t]/) {
          # If the character is a tab, just print it
          printf "%s", char
        } else {
          # Apply color to printable characters
          color = colors[field_count % length(colors)]
          printf "%s%s%s", color, char, reset
          # Move to the next field after a tab
          if (substr($0, i + 1, 1) ~ /[\t]/) {
            field_count++
          }
        }
      }

      # Append trailing NL
      printf "\n"
    }' "$@"
}

urlencode() {
  local LANG=C i char enc=''

  for ((i=0; i<${#1}; i++))
  do
    char=${1:$i:1}
    [[ "$char" =~ [a-zA-Z0-9\.\~\_\-] ]] || printf -v char '%%%02X' "'${char}"
    enc+="$char"
  done

  echo "$enc"
}

netbox_curl_raw() {
  local endpoint="$1"
  shift

  local url
  if [[ "$endpoint" == ${NETBOX_URL}* ]]
  then
    # use the provided URL as-is
    url="$endpoint"
  else
    # relative URL, prepend the base URL
    url="${NETBOX_URL}/api/${endpoint}"
  fi

  local args=(
    -fsSL
    -H "Authorization: Token $NETBOX_API_TOKEN"
    -H "Accept: application/json; indent=2"
    -H "Content-Type: application/json"
    "$@"
    "$url"
  )

  if grep -qE "(DELETE|PATCH|POST|PUT)" <<< "$*"
  then
    if [[ -n "$DRY_RUN" ]]
    then
      echo_dryrun "curl ${args[*]@Q}"
      return 0
    elif [[ -n "$CONFIRM" ]]
    then
      echo_info "curl ${args[*]@Q}"
      echo_confirm "Execute the command?" || return 1
    fi
  fi

  curl "${args[@]}"
}

netbox_graphql() {
  # NOTE We need to set the full URL here to prevent curl_raw to prepend
  # NETBOX_URL/api to the endpoint URL
  local endpoint="${NETBOX_URL}/graphql/"

  if [[ "${#@}" -lt 1 ]]
  then
    echo_error "Missing GraphQL query"
    return 2
  fi

  local query="${1//"/\\"}"
  shift

  local fields=("$@")
  if [[ "${#fields[@]}" -lt 1 ]]
  then
    # Default to output id and name fields
    fields=(id name)
  fi

  local fields_json
  fields_json=$(arr_to_json "${fields[@]}")

  local data
  data=$(jq -nc \
    --arg query "$query" \
    --argjson fields "$fields_json" '
      {
        query: "query {\($query) {\($fields | join(","))}}"
      }
    ')

  echo_debug "GraphQL query data: $data"

  netbox_curl_raw "$endpoint" \
    --data "$data" | \
      jq -e '.data'
}

netbox_curl_paginate() {
  local index=1
  local count=0

  while [[ -n "$*" ]]
  do
    case "$1" in
      -i|--index)
        index="$2"
        shift 2
        ;;
      -c|--count)
        count="$2"
        shift 2
        ;;
      *)
        break
        ;;
    esac
  done

  echo_debug "Fetching page $index"

  local res
  if ! res=$(netbox_curl_raw "$@")
  then
    echo_error "Failed to fetch data from Netbox ($1)"
    return 1
  fi

  local results
  results=$(jq -er '.results' <<< "$res")

  printf '%s\n' "$results"

  local count total
  count=$(jq -er --argjson count "$count" '$count + (.results | length)' <<< "$res")
  total=$(jq -er '.count' <<< "$res")
  echo_debug "Fetched ${count}/${total} items"

  local next
  next=$(jq -er '.next' <<< "$res")

  if [[ "$next" != "null" ]]
  then
    index=$((index + 1))
    netbox_curl_paginate --index "$index" --count "$count" "$next"
  fi
}

# Fetch all pages and merge them into a single JSON array
netbox_curl() {
  netbox_curl_paginate "$@" | jq -es 'add'
}

netbox_id() {
  local object_type="$1"
  local name="$2"

  if [[ ! "$object_type" == *s ]]
  then
    object_type+="s"
  fi

  local res
  res=$("netbox_list_${object_type}" name="$name")

  local length
  length=$(jq -er 'length' <<< "$res")

  case "$length" in
    0)
      echo_error "No ${object_type%%s} named '$name' found"
      return 1
      ;;
    1)
      jq -er '.[0].id' <<< "$res"
      ;;
    *)
      echo_warning "Ambiguous name '$name': $length results found"
      return 1
      ;;
  esac
}

netbox_list() {
  local endpoint="$1"
  shift

  local filters=("$@")
  if [[ "${#filters[@]}" -gt 0 ]]
  then
    local filter filter_key filter_val filter_val_enc
    local first=1 sep="?"
    for filter in "${filters[@]}"
    do
      IFS="=" read -r filter_key filter_val <<< "$filter"
      filter_val_enc=$(urlencode "$filter_val")

      echo_debug "GET $endpoint - filter: $filter_key=$filter_val_enc"

      [[ -z "$first" ]] && sep="&"
      endpoint+="${sep}${filter_key}=${filter_val_enc}"
      unset first
    done
  fi

  netbox_curl "$endpoint"
}

check_filters() {
  local filter
  for filter in "$@"
  do
    if [[ ! "$filter" == *=* ]]
    then
      return 1
    fi
  done

  return 0
}

netbox_assign_devices_to_cluster() {
  local cluster="$1"
  shift

  if [[ ! "$cluster" =~ ^[0-9]+$ ]]
  then
    cluster_id=$(netbox_cluster_id "$cluster")
  else
    cluster_id="$cluster"
  fi

  local device_filters=("$@")
  if [[ "${#device_filters[@]}" -eq 0 ]] || \
     ! check_filters "${device_filters[@]}"
  then
    echo_error "Invalid device filters provided: ${device_filters[*]}"
    return 1
  fi

  local device_ids
  device_ids=$(netbox_list_devices "${device_filters[@]}" | jq -er '[.[].id]')

  # NOTE below assumes that device IDs are provided as [int]
  # device_ids="$(arr_to_json "$@")"

  local data
  data=$(jq -nc \
    --argjson cluster_id "$cluster_id" \
    --argjson device_ids "$device_ids" '
    [$device_ids[] | {id: (. | tonumber), cluster: ($cluster_id | tonumber)}]
  ')

  local length
  length=$(jq -er 'length' <<< "$data")

  if [[ "$length" -eq 0 ]]
  then
    echo_error "No matching device found for filters: ${device_filters[*]}"
    return 1
  fi

  echo_info "Assigning $length devices to cluster $cluster (id: $cluster_id)"

  netbox_curl_raw "${NETBOX_API_ENDPOINTS[devices]}" \
    -X PATCH \
    --data "$data"
}

# Generate functions for each endpoint
for API_ENDPOINT in "${!NETBOX_API_ENDPOINTS[@]}"
do
  eval "$(cat <<EOF
netbox_list_${API_ENDPOINT}() {
  netbox_list "${NETBOX_API_ENDPOINTS[${API_ENDPOINT}]}" "\$@"
}

netbox_${API_ENDPOINT%%s}_id() {
  netbox_id "$API_ENDPOINT" "\$@"
}
EOF
)"
done
unset API_ENDPOINT

main() {
  local args=()

  while [[ -n "$*" ]]
  do
    case "$1" in
      help|h|-h|--help)
        usage
        exit 0
        ;;
      -D|--debug)
        DEBUG=1
        shift
        ;;
      -k|--dry-run|--dryrun)
        DRY_RUN=1
        shift
        ;;
      --confirm)
        CONFIRM=1
        shift
        ;;
      --no-confirm|--noconfirm|-y)
        NO_CONFIRM=1
        shift
        ;;
      -a|--api-token)
        NETBOX_API_TOKEN="$2"
        shift 2
        ;;
      -u|--url)
        NETBOX_URL="$2"
        shift 2
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  set -- "${args[@]}"

  ACTION="$1"
  if [[ -z "$ACTION" ]]
  then
    echo_error "No action specified"
    usage
    exit 1
  fi

  shift

  case "$ACTION" in
    # Shorthands
    c|cl|cluster*)
      netbox_list_clusters "$@"
      ;;
    d|dev*)
      netbox_list_devices "$@"
      ;;
    l|loc*)
      netbox_list_locations "$@"
      ;;
    s|site*)
      netbox_list_sites "$@"
      ;;
    r|rack*)
      netbox_list_racks "$@"
      ;;
    t|ten*)
      netbox_list_tenants "$@"
      ;;

    # RAW
    graph*)
      netbox_graphql "$@"
      ;;
    raw)
      netbox_curl "$@"
      ;;

    # Workflows
    assign-to-cluster)
      netbox_assign_devices_to_cluster "$@"
      ;;

    *)
      echo_error "Unknown action: $ACTION"
      usage
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  main "$@"
fi
