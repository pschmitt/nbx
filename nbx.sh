#!/usr/bin/env bash

NETBOX_URL="${NETBOX_URL:-http://localhost:8000}"
NETBOX_API_TOKEN="${NETBOX_API_TOKEN:-}"

usage() {
  echo "Usage: $(basename "$0") [options] ITEM [ACTION]" >&2
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

netbox_curl_paginate() {
  local index=0
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

netbox_list_sites() {
  local filter="$1"
  local endpoint="dcim/sites"
  if [[ -n "$filter" ]]
  then
    endpoint="dcim/sites/?$filter"
  fi

  netbox_curl "$endpoint"
}

netbox_list_devices() {
  local filter="$1"
  local endpoint="dcim/devices"
  if [[ -n "$filter" ]]
  then
    endpoint="dcim/devices/?$filter"
  fi

  netbox_curl dcim/devices
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
    s|site*)
      netbox_list_sites "$@"
      ;;
    d|dev*)
      netbox_list_devices "$@"
      ;;
    raw)
      netbox_curl "$@"
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
