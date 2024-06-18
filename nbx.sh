#!/usr/bin/env bash

NETBOX_URL="${NETBOX_URL:-http://localhost:8000}"
NETBOX_API_TOKEN="${NETBOX_API_TOKEN:-}"

usage() {
  echo "Usage: $(basename "$0") [options] ACTION [ARGS]" >&2
  echo
  echo "Actions:"
  echo "  clusters [FILTERS]     List clusters"
  echo "  devices  [FILTERS]     List devices"
  echo "  graphql  QUERY FIELDS  GraphQL query"
  echo "  raw      ENDPOINT      Fetch raw data from an endpoint"
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

arr_to_json() {
  printf '%s\n' "$@" | jq -Rn '[inputs]'
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

  curl -fsSL \
    -H "Authorization: Token $NETBOX_API_TOKEN" \
    -H "Accept: application/json; indent=2" \
    "$@" \
    "$url"
}

netbox_graphql() {
  # NOTE We need to set the full URL here to prevent curl_raw to prepend
  # NETBOX_URL/api to the endpoint URL
  local endpoint="${NETBOX_URL}/graphql/"

  if [[ "${#@}" -lt 2 ]]
  then
    echo_error "Missing query and/or fields data for GraphQL query"
    return 2
  fi

  local query="${1//"/\\"}"
  shift
  local fields=("$@")

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
    --header "Content-Type: application/json" \
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

      echo_debug "Filtering by: $filter_key=$filter_val_enc"

      [[ -z "$first" ]] && sep="&"
      endpoint+="${sep}${filter_key}=${filter_val_enc}"
      unset first
    done
  fi

  netbox_curl "$endpoint"
}

netbox_list_clusters() {
  netbox_list virtualization/clusters "$@"
}

netbox_list_devices() {
  netbox_list dcim/devices "$@"
}

netbox_list_locations() {
  netbox_list dcim/locations "$@"
}

netbox_list_sites() {
  netbox_list dcim/sites "$@"
}

netbox_list_tenants() {
  netbox_list tenancy/tenants "$@"
}

main() {
  local args=()

  while [[ -n "$*" ]]
  do
    case "$1" in
      -D|--debug)
        DEBUG=1
        shift
        ;;
      help|h|-h|--help)
        usage
        exit 0
        ;;
      -a|--api-token)
        NETBOX_API_TOKEN="$2"
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
    t|ten*)
      netbox_list_tenants "$@"
      ;;
    raw)
      netbox_curl "$@"
      ;;
    graph*)
      netbox_graphql "$@"
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
