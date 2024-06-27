#!/usr/bin/env bash

NETBOX_URL="${NETBOX_URL:-https://demo.netbox.dev}"
NETBOX_API_TOKEN="${NETBOX_API_TOKEN:-}"

COMPACT="${COMPACT:-}"
CONFIRM="${CONFIRM:-1}"
DRY_RUN="${DRY_RUN:-}"
DEBUG="${DEBUG:-}"
DEBUG_REDACT="${DEBUG_REDACT:-}"
DEBUG_TRUNCATE="${DEBUG_TRUNCATE:-}"
GRAPHQL="${GRAPHQL:-}"
KEEP_HEADER="${KEEP_HEADER:-}"
NO_COLOR="${NO_COLOR:-}"
NO_HEADER="${NO_HEADER:-}"
NO_WARNINGS="${NO_WARNINGS:-}"
OUTPUT="${OUTPUT:-pretty}"
PEDANTIC="${PENDANTIC:-}"
SORT_BY="${SORT_BY:-name}"
WITH_ID_COL="${WITH_ID_COL:-}"

mapfile -t CUSTOM_COLUMNS < <(tr ',' '\n' <<< "${CUSTOM_COLUMNS:-}")
JSON_COLUMNS=()
COLUMN_NAMES=()

declare -A NETBOX_API_ENDPOINTS=(
  [aggregates]="ipam/aggregates/"
  [cables]="dcim/cables/"
  [circuits]="circuits/circuits/"
  [cluster-groups]="virtualization/cluster-groups/"
  [cluster-types]="virtualization/cluster-types/"
  [clusters]="virtualization/clusters/"
  [config-contexts]="extras/config-contexts/"
  [console-ports]="dcim/console-ports/"
  [console-server-ports]="dcim/console-server-ports/"
  [contact-assignments]="tenancy/contact-assignments/"
  [contact-groups]="tenancy/contact-groups/"
  [contact-roles]="tenancy/contact-roles/"
  [contacts]="tenancy/contacts/"
  [custom-fields]="extras/custom-fields/"
  [device-bays]="dcim/device-bays/"
  [device-roles]="dcim/device-roles/"
  [device-types]="dcim/device-types/"
  [devices]="dcim/devices/"
  [front-ports]="dcim/front-ports/"
  [interfaces]="dcim/interfaces/"
  [inventory-items]="dcim/inventory-items/"
  [ip-addresses]="ipam/ip-addresses/"
  [locations]="dcim/locations/"
  [manufacturers]="dcim/manufacturers/"
  [platforms]="dcim/platforms/"
  [power-outlets]="dcim/power-outlets/"
  [power-ports]="dcim/power-ports/"
  [prefixes]="ipam/prefixes/"
  [providers]="circuits/providers/"
  [rack-reservations]="dcim/rack-reservations/"
  [rack-roles]="dcim/rack-roles/"
  [racks]="dcim/racks/"
  [rear-ports]="dcim/rear-ports/"
  [regions]="dcim/regions/"
  [rirs]="ipam/rirs/"
  [roles]="ipam/roles/"
  [services]="ipam/services/"
  [sites]="dcim/sites/"
  [tags]="extras/tags/"
  [tenant-groups]="tenancy/tenant-groups/"
  [tenants]="tenancy/tenants/"
  [virtual-chassis]="dcim/virtual-chassis/"
  [virtual-machine-interfaces]="virtualization/interfaces/"
  [virtual-machines]="virtualization/virtual-machines/"
  [vlan-groups]="ipam/vlan-groups/"
  [vlans]="ipam/vlans/"
  [vrfs]="ipam/vrfs/"
  [webhooks]="extras/webhooks/"
  [wireless-lans]="wireless/wireless-lans/"
)

usage() {
  echo "Usage: $(basename "$0") [options] ACTION [ARGS]" >&2
  echo
  echo "GLOBAL OPTIONS"
  echo
  echo "  -a, --api TOKEN    Netbox API Token (default: \$NETBOX_API_TOKEN)"
  echo "  -u, --url URL      Netbox URL (default: \$NETBOX_URL)"
  echo "  -g, --graphql      Use GraphQL API instead of REST API (list actions only)"
  echo "  -D, --debug        Enable debug output"
  echo "  -P, --pedantic     Enable pedantic mode (exit on any error)"
  echo "  -W, --no-warnings  Disable warnings"
  echo "  -k, --dry-run      Dry-run mode"
  echo "  --confirm          Confirm before executing actions"
  echo "  --no-confirm       Do not confirm before executing actions"
  echo "  -o, --output TYPE  Output format: pretty (default), json, field"
  echo "  -F, --field FIELD  Field to output when using 'field' output format"
  echo "  -j, --json         Output format: json"
  echo "  -N, --no-header    Do not print header"
  echo "  -c, --no-color     Disable color output"
  echo "  --compact          Truncate long fields"
  echo "  --header           Keep header when piping output (default: remove)"
  echo "  -I, --with-id      Include ID column"
  echo "  -C, --comments     Include comments column (shorthand for --cols +comments)"
  echo "  --columns COLUMNS  List of columns to display (prefix with '+' to append, '-' to remove)"
  echo "  -s, --sort FIELD   Sort by field/column (prefix with '-' to sort in reverse order)"
  echo
  echo
  echo "LIST ACTIONS"
  echo
  echo "  aggregates            [FILTERS]   List aggregates"
  echo "  cables                [FILTERS]   List cables"
  echo "  circuits              [FILTERS]   List circuits"
  echo "  cluster-groups        [FILTERS]   List cluster groups"
  echo "  cluster-types         [FILTERS]   List cluster types"
  echo "  clusters              [FILTERS]   List clusters"
  echo "  config-contexts       [FILTERS]   List config contexts"
  echo "  console-ports         [FILTERS]   List console ports"
  echo "  console-server-ports  [FILTERS]   List console server ports"
  echo "  contact-assignments   [FILTERS]   List contact assignments"
  echo "  contact-groups        [FILTERS]   List contact groups"
  echo "  contact-roles         [FILTERS]   List contact roles"
  echo "  contacts              [FILTERS]   List contacts"
  echo "  custom-fields         [FILTERS]   List custom fields"
  echo "  device-bays           [FILTERS]   List device bays"
  echo "  device-roles          [FILTERS]   List device roles"
  echo "  device-types          [FILTERS]   List device types"
  echo "  devices               [FILTERS]   List devices"
  echo "  front-ports           [FILTERS]   List front ports"
  echo "  interfaces            [FILTERS]   List interfaces"
  echo "  inventory-items       [FILTERS]   List inventory items"
  echo "  ip-addresses          [FILTERS]   List IP addresses"
  echo "  locations             [FILTERS]   List locations"
  echo "  manufacturers         [FILTERS]   List manufacturers"
  echo "  platforms             [FILTERS]   List platforms"
  echo "  power-outlets         [FILTERS]   List power outlets"
  echo "  power-ports           [FILTERS]   List power ports"
  echo "  prefixes              [FILTERS]   List prefixes"
  echo "  providers             [FILTERS]   List providers"
  echo "  rack-reservations     [FILTERS]   List rack reservations"
  echo "  rack-roles            [FILTERS]   List rack roles"
  echo "  racks                 [FILTERS]   List racks"
  echo "  rear-ports            [FILTERS]   List rear ports"
  echo "  regions               [FILTERS]   List regions"
  echo "  rirs                  [FILTERS]   List RIRs"
  echo "  services              [FILTERS]   List services"
  echo "  sites                 [FILTERS]   List sites"
  echo "  tags                  [FILTERS]   List tags"
  echo "  tenant-groups         [FILTERS]   List tenants groups"
  echo "  tenants               [FILTERS]   List tenants"
  echo "  virtual-chassis       [FILTERS]   List virtual chassis"
  echo "  vlan-groups           [FILTERS]   List VLAN groups"
  echo "  vlan-roles            [FILTERS]   List Prefix & VLAN roles"
  echo "  vlans                 [FILTERS]   List VLANs"
  echo "  vm                    [FILTERS]   List virtual machines"
  echo "  vm-interfaces         [FILTERS]   List vm interfaces"
  echo "  vrf                   [FILTERS]   List VRFs"
  echo "  webhooks              [FILTERS]   List webhooks"
  echo "  wifi                  [FILTERS]   List wireless LANs"
  echo
  echo
  echo "META ACTIONS"
  echo
  echo "  cols OBJECT_TYPE                                     List available columns for an object type"
  echo "  introspect (--types|--query|--fields) [OBJECT_TYPE]  Introspect GraphQL API"
  echo
  echo
  echo "WORKFLOWS COMMANDS"
  echo
  echo "  assign-to-cluster CLUSTER [FILTERS]  Assign devices to a cluster"
  echo
  echo
  echo "RAW COMMANDS"
  echo
  echo "  graphql  [--raw] QUERY [FIELDS]    GraphQL query"
  echo "  raw      ENDPOINT                  Fetch raw data from an endpoint (REST)"
}

echo_info() {
  echo -ne "\e[1m\e[34mINF\e[0m " >&2
  echo "$*" >&2
}

echo_success() {
  echo -ne "\e[1m\e[32mOK\e[0m " >&2
  echo "$*" >&2
}

echo_warning() {
  [[ -n "$NO_WARNINGS" ]] && return 0
  echo -ne "\e[1m\e[33mWRN\e[0m " >&2
  echo "$*" >&2
}

echo_error() {
  echo -ne "\e[1m\e[31mERR\e[0m " >&2
  echo "$*" >&2
}

echo_debug() {
  [[ -z "${DEBUG}" ]] && return 0

  {
    echo -en "\e[1m\e[35mDBG\e[0m "
    local m="$*"

    if [[ -n "$DEBUG_REDACT" ]]
    then
      m=${m//$NETBOX_API_TOKEN/**redacted**}
    fi

    if [[ -z "$DEBUG_TRUNCATE" ]] || [[ -n "$NO_DEBUG_TRUNCATE" ]]
    then
      echo "$m"
    else
      local max_len="${DEBUG_TRUNCATE_LEN:-200}"
      if [[ ${#m} -lt "$max_len" ]]
      then
        echo "$m"
        return 0
      fi

      head -c "$max_len" <<<"$m"
      echo "…"
    fi
  } >&2
}

echo_debug_no_trunc() {
  NO_DEBUG_TRUNCATE=1 echo_debug "$@"
}

echo_dryrun() {
  echo -e "\e[1m\e[35mDRY\e[0m " >&2
  echo "$*" >&2
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
  echo | tee >(cat >&2) # DIRTYFIX Append a NL on both stdout and stderr
  return "$rc"
}

arr_to_json() {
  printf '%s\n' "$@" | jq -Rn '[inputs]'
}

arr_join() {
  local IFS="$1"
  shift
  echo "$*"
}

# usage: arr_remove removeme removeme2 -- "${array[@]}"
arr_remove() {
  local -a remove
  local i

  for i in "$@"
  do
    case "$1" in
      --)
        shift
        break
        ;;
      *)
        remove+=("$1")
        shift
        ;;
    esac
  done

  shift
  local arr=("$@")

  local j
  for i in "${arr[@]}"
  do
    for j in "${remove[@]}"
    do
      if [[ "$i" == "$j" ]]
      then
        continue 2
      fi
    done

    echo "$i"
  done
}

arr_remove_at() {
  local index="$1"
  shift
  local arr=("$@")

  unset -v "arr[${index}]"

  local i
  for i in "${arr[@]}"
  do
    echo "$i"
  done
}

arr_replace() {
  local elem="$1"
  local replacement="$2"
  shift 2
  local arr=("$@")

  local i
  for i in "${arr[@]}"
  do
    if [[ "$i" == "$elem" ]]
    then
      echo "$replacement"
      continue
    fi

    echo "$i"
  done
}

arr_replace_multiple() {
  local -a arr_repl

  while [[ -n "$*" ]]
  do
    case "$1" in
      --)
        shift
        break
      ;;
      *)
        arr_repl+=("$1")
        shift
      ;;
    esac
  done

  local -a arr=("$@")

  local i
  for ((i=0; i<${#arr_repl[@]}; i+=2))
  do
    mapfile -t arr < <(arr_replace "${arr_repl[$i]}" "${arr_repl[$((i+1))]}" "${arr[@]}")
  done

  printf '%s\n' "${arr[@]}"
}

arr_gsub() {
  local search="$1"
  local replacement="$2"
  shift 2

  local arr=("$@")

  local i
  for i in "${arr[@]}"
  do
    echo "${i//${search}/${replacement}}"
  done
}

arr_gsub_multiple() {
  local -a arr_repl

  while [[ -n "$*" ]]
  do
    case "$1" in
      --)
        shift
        break
      ;;
      *)
        arr_repl+=("$1")
        shift
      ;;
    esac
  done

  local -a arr=("$@")

  local i
  for ((i=0; i<${#arr_repl[@]}; i+=2))
  do
    mapfile -t arr < <(arr_gsub "${arr_repl[$i]}" "${arr_repl[$((i+1))]}" "${arr[@]}")
  done

  printf '%s\n' "${arr[@]}"

}

arr_index_of() {
  local val="$1"
  shift
  local arr=("$@")

  local i
  for i in "${!arr[@]}"
  do
    if [[ "${arr[$i]}" == "$val" ]]
    then
      echo "$i"
      return 0
    fi
  done

  return 1
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
    -sSL
    -w "\n%{http_code}\n"
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

  if [[ -n "$DEBUG" ]]
  then
    echo_debug_no_trunc "curl ${args[*]@Q}"
  fi

  local http_code output raw_output

  raw_output="$(curl "${args[@]}")"
  http_code="$(tail -1 <<< "$raw_output")"
  output="$(head -n -1 <<< "$raw_output")"

  printf '%s\n' "$output"

  if [[ "$http_code" != 2* ]]
  then
    echo_error "HTTP code $http_code"
    echo_error "$output"
    return 1
  fi

  return 0
}

netbox_rest_list_columns() {
  local object_type="${1}"
  if [[ "$object_type" != *s ]]
  then
    object_type+="s"
  fi

  local object_type="$1"
  shift

  local endpoint="${NETBOX_API_ENDPOINTS[${object_type}]}"
  if [[ -z "$endpoint" ]]
  then
    echo_error "Unknown object type: $object_type"
    echo_error "Available object types: ${!NETBOX_API_ENDPOINTS[*]}"
    return 2
  fi

  netbox_curl_raw "$endpoint" | \
    jq -er '[.results[0] | keys[]] | sort[]'
}

netbox_graphql() {
  local raw
  local jq_filter=".data | to_entries[].value"

  while [[ "${#@}" -gt 0 ]]
  do
    case "$1" in
      --jq*)
        jq_filter="$2"
        shift 2
        ;;
      --raw)
        raw=1
        shift
        ;;
      --)
        shift
        break
        ;;
      *)
        break
        ;;
    esac
  done

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

  if [[ "${query:0:1}" == "{" ]]
  then
    echo_warning "Query string starts with '{', assuming it's a raw query"
    raw=1
  fi

  local data
  if [[ -n "$raw" ]]
  then
    data=$(jq -nc \
      --arg query "$query" '
        { query: ("query " + $query) }
      ')
  else
    local fields=("$@")
    if [[ "${#fields[@]}" -lt 1 ]]
    then
      # Default to output id and name fields
      fields=(id name)
    fi

    # Transform nested fields to GraphQL format
    local fields_ql
    fields_ql=$(to_graphql "${fields[@]}")

    echo_debug_no_trunc "GraphQL fields: $fields_ql"

    data=$(jq -nc \
      --arg query "$query" \
      --arg fields "$fields_ql" '
        { query: "query {\($query) {\($fields)}}" }
      ')
  fi

  echo_debug_no_trunc "GraphQL query: $data"

  local rc=0

  local res_raw
  if ! res_raw=$(netbox_curl_raw "$endpoint" --data "$data")
  then
    rc=1
  fi

  if [[ -n "$DEBUG" ]]
  then
    echo_debug "GraphQL response (RAW): $res_raw"
  fi

  local error
  error=$(jq -er '.errors' <<< "$res_raw")

  if [[ -n "$error" && "$error" != "null" ]]
  then
    echo_error "$(jq -r '.[].message' <<< "$error")"
    return 1
  fi

  local res
  res=$(jq -e "$jq_filter" <<< "$res_raw")

  if [[ -n "$DEBUG" ]]
  then
    echo_debug "GraphQL response: $res"
  fi

  printf '%s\n' "$res"
  return "$rc"
}

to_graphql() {
  local fields=("$@")

  # Recursive function to process nested fields
  process_fields() {
    local fields=("$@")
    local -A map
    local key
    local rest
    local nested_output=""

    # Split fields and map them to their parents
    for field in "${fields[@]}"
    do
      IFS='.' read -r key rest <<< "$field"
      if [[ -n "$rest" ]]
      then
        map[$key]+="${rest} "
      else
        nested_output+="$key, "
      fi
    done

    # Process each key in the map
    local nested_fields
    local sub_output
    for key in "${!map[@]}"
    do
      # shellcheck disable=SC2206
      nested_fields=(${map[$key]})
      sub_output=$(process_fields "${nested_fields[@]}")
      nested_output+="$key { $sub_output }, "
    done

    # Remove trailing comma and space from the current output
    echo "${nested_output%, }"
  }

  # Process top-level fields
  local top_level_output
  top_level_output=$(process_fields "${fields[@]}")

  # Remove trailing comma and space from the final output
  top_level_output="${top_level_output%, }"

  # Print the final result
  echo "$top_level_output"
}

netbox_graphql_introspect() {
  local output raw args

  while [[ -n "$*" ]]
  do
    case "$1" in
      --raw)
        raw=1
        shift
        ;;
      --types)
        output=types
        shift
        ;;
      --query)
        output=query
        shift
        ;;
      --cols|--columns|--fields)
        output=fields
        shift
        ;;
      --)
        shift
        args+=("$@")
        break
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  set -- "${args[@]}"

  local query
  if [[ "$output" == "query" ]]
  then
    query='
      {
        __type(name: "Query") {
          fields {
            name
            args {
              name
              type {
                kind
                name
                ofType {
                  name
                  kind
                }
              }
            }
          }
        }
      }
    '
  else
    local object_type="$1"
    shift

    case "$object_type" in
      ip-addr*|ip_addr*|IPAddr*)
        object_type="IPAddress"
        ;;
      ip-pref*|pref*|IPPref*)
        object_type="Prefix"
        ;;
      *)
        object_type="${object_type%%s}"
        ;;
    esac

    local graphql_type="${object_type^}Type"

    query='
      {
        __type(name: "'"${graphql_type}"'") {
          fields {
            name
            type {
              name
              kind
            }
          }
        }
      }
    '
  fi

  local res
  res=$(netbox_graphql --raw "$query")

  if [[ -n "$raw" ]]
  then
    printf '%s\n' "$res"
    return 0
  fi

  case "$output" in
    query)
      local func="$1"
      local arg="$2"

      if [[ -z "$func" ]]
      then
        echo_error "Missing function name"
        return 1
      fi

      if [[ -z "$arg" ]]
      then
        jq -er \
          --arg func "$func" '
            .fields[] | select(.name == $func) | .args[] |
            .name
            + " " +
            (
              if (.type.name != null)
              then
                (.type.name | ascii_downcase)
              elif (.type.kind == "LIST")
              then
                (.type.ofType.name // "null" | ascii_downcase) + "[]"
              else
                .type.kind
              end
            )
          ' <<< "$res"

        return "$?"
      fi

      jq -er \
        --arg func "$func" \
        --arg arg "$arg" '
          .fields[] | select(.name == $func) | .args[] | select(.name == $arg) |
          .type.name
        ' <<< "$res"
      ;;
    fields)
      jq -er '.fields[].name' <<< "$res"
      ;;
    types)
      local field="$1"
      if [[ -n "$field" ]]
      then
        jq -er --arg field "$field" '
          .fields[] | select(.name == $field) | .type.name
        ' <<< "$res"
      else
        # Return all
        jq -er '.fields[].type.name' <<< "$res"
      fi
      ;;
    *)
      echo_error "Unknown output value: $output"
      return 1
      ;;
  esac
}

netbox_graphql_list_columns() {
  local object_type="$1"
  shift

  case "$object_type" in
    ip-addr*|ip_addr*|IPAddr*)
      object_type="IPAddress"
      ;;
    virtual-chassis|virtual_chassis|VirtualChassis|vc)
      object_type="VirtualChassis"
      ;;
    *)
      object_type="${object_type%%s}"
      ;;
  esac

  local supported_types
  mapfile -t supported_types < <(
    netbox_graphql --raw '
      {
        __schema {
          types {
            name
          }
        }
      }
    ' | jq -er '[
      .types[] |
      select((.name | test("Type$")) and (.name | test("^__") | not)) |
      .name
      ] | sort[]'
  )

  local graphql_type="${object_type^}Type"
  if ! grep -qw "${graphql_type}" <<< "${supported_types[*]}"
  then
    echo_error "Unknown object type: $object_type"
    echo_info "Supported types: ${supported_types[*]//Type/}"
    return 2
  fi

  netbox_graphql --raw '
    {
      __type(name: "'"${graphql_type}"'") {
        fields {
          name
          type {
            name
          }
        }
      }
    }
  ' | jq -er '[.fields[].name] | sort[]'
}

netbox_graphql_objects() {
  local object_type="$1"
  shift

  case "$object_type" in
    ip-addr*|ip_addr*)
      object_type="ip_address"
      ;;
    virtual-chassis|virtual_chassis)
      object_type="virtual_chassis"
      ;;
    *)
      object_type="${object_type%%s}"
      ;;
  esac

  local -a args filters

  # shellcheck disable=SC2046
  set -- $(TARGET_OBJECT="$object_type" resolve_filters "$@")

  local graphql_func="${object_type}_list"

  local key val

  # Only introspect if necessary (at least one filter provided)
  if [[ "$*" == *=* ]]
  then
    local -A graphql_args
    local line

    while read -r line
    do
      read -r key val <<< "$line"
      graphql_args[$key]="$val"
    done < <(netbox_graphql_introspect --query "$graphql_func")
  fi

  local arg_type
  local -A filter_values
  while [[ -n $* ]]
  do
    case "$1" in
      *=*)
        # convert filters like rack_id=691 to GraphQL format (rack_id: "691")
        IFS="=" read -r key val <<< "$1"

        arg_type="${graphql_args[$key]}"
        case "$arg_type" in
          int)
            # Use value as-is
            ;;
          *)
            val="\"$val\""
            ;;
        esac

        if [[ -n "${filter_values[$key]}" ]]
        then
          # Append to existing value
          val="${filter_values[$key]}, $val"
        fi

        filter_values[$key]="$val"
        shift
        ;;
      --)
        shift
        break
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  set -- "${args[@]}"

  # Construct filters array
  local -a filters
  for key in "${!filter_values[@]}"
  do
    if [[ "${filter_values[$key]}" == *","* ]]
    then
      # Multiple values
      filters+=("${key}: [${filter_values[$key]}]")
    else
      # Single value
      filters+=("${key}:${filter_values[$key]}")
    fi
  done

  local fields=("$@")
  # Default fields
  if [[ "${#fields[@]}" -eq 0 ]]
  then
    fields=(id name)
  fi

  # Replace _count fields with the actual field name
  # + fix some plural forms
  mapfile -t fields < <(arr_gsub_multiple \
    _count "s {id}" \
    prefixs "prefixes" \
    -- "${fields[@]}")

  local q="${graphql_func}"

  if [[ "${#filters[@]}" -gt 0 ]]
  then
    q+="($(arr_join ', ' "${filters[@]}"))"
  fi

  local data
  data=$(netbox_graphql --jq ".data[\"${graphql_func}\"]" \
    "$q" "${fields[@]}")
  local rc="$?"

  # Add _count fields
  data=$(<<<"$data" jq -er '
    map(. + (
      to_entries | map(
        select(.value | type == "array") |
        {
          key: (.key | rtrimstr("s") + "_count"),
          value: .value | length
        }
      ) | from_entries)
    )
  ')

  printf '%s\n' "$data"

  return "$rc"
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

  # shellcheck disable=SC2046
  set -- $(TARGET_OBJECT="$TARGET_OBJECT" resolve_filters "$@")

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

resolve_filters() {
  local target_obj="${TARGET_OBJECT}"

  local filter key val obj obj_repl matches search_prop
  local -A data
  local rc=0

  for filter in "$@"
  do
    IFS="=" read -r key val <<< "$filter"

    case "$key" in
      *_id)
        if [[ ! "$val" =~ ^[0-9]+$ ]]
        then
          search_prop="name" # look for matches on name by default
          obj=${key%_id}
          obj_repl=""

          # some objects don't have a name field
          case "$obj" in
            device_type)
              search_prop="slug"
              ;;
            ipaddr*|ip_addr*|ip-addr*)
              search_prop="address"
              ;;
            *prefix*)
              search_prop="prefix"
              ;;
            role)
              # If we target devices, the "role" refers to a device_role
              case "$target_obj" in
                device|devices)
                  obj_repl="device_role"
                  ;;
              esac
              ;;
            type|group)
              # For clusters, the "type" refers to a cluster_type and the
              # "group" to a cluster_group
              case "$target_obj" in
                cluster*)
                  obj_repl="cluster_${obj}"
                  ;;
              esac
              ;;
          esac

          if [[ -n "$obj_repl" ]]
          then
            echo_debug "Rewrote filter '${obj}' to '${obj_repl}'"
            obj="$obj_repl"
          fi

          if [[ ! -v data[$obj] ]]
          then
            data[$obj]="$(netbox_graphql_objects "$obj" id "$search_prop")"
          fi

          mapfile -t matches < <(jq -erc \
            --arg val "$val" \
            --arg search_prop "$search_prop" '
              .[] | select(
                # Check if the search property is not null first to avoid jq
                # errors on stderr
                (.[$search_prop] != null)
                and
                (.[$search_prop] | test("^" + $val + "$"; "i"))
              )
          ' <<< "${data[$obj]}")

          case "${#matches[@]}" in
            0)
              echo_error "No matching $obj found for '$val'"
              if [[ -n "$PEDANTIC" ]]
              then
                exit 1
              fi
              rc=1
              continue
              ;;
            1)
              val=$(jq -er '.id' <<< "${matches[0]}")
              ;;
            *)
              echo_error "Ambiguous $obj name '$val': $(jq -ser '[.[].name] | join(" ")' <<< "${matches[@]}")"
              rc=1
              continue
              ;;
          esac
        fi

        echo "$key=$val"
        ;;
      *)
        echo "$filter"
        ;;
    esac
  done

  return "$rc"
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

  # shellcheck disable=SC2046
  set -- $(TARGET_OBJECT=device resolve_filters "$@")

  local device_filters=("$@")
  if [[ "${#device_filters[@]}" -eq 0 ]] || \
     ! check_filters "${device_filters[@]}"
  then
    echo_error "Invalid device filters provided: ${device_filters[*]}"
    return 1
  fi

  local device_data
  device_data=$(netbox_list_devices "${device_filters[@]}")
  # Display device data for easier checking
  pretty_output <<< "$device_data" >&2

  if jq --argjson cluster_id "$cluster_id" -er '
      all(.[]; .cluster.id == $cluster_id)
     ' <<< "$device_data" &>/dev/null
  then
    echo_success "Nothing to do. All matched devices are already assigned to cluster $cluster"
    return 0
  fi

  local device_ids
  device_ids=$(jq -er '[.[].id]' <<< "$device_data")

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
for OBJECT_TYPE in "${!NETBOX_API_ENDPOINTS[@]}"
do
  eval "$(cat <<EOF
netbox_list_${OBJECT_TYPE//-/_}() {
  TARGET_OBJECT=${OBJECT_TYPE} \
    netbox_list "${NETBOX_API_ENDPOINTS[${OBJECT_TYPE}]}" "\$@"
}

netbox_${OBJECT_TYPE%%s}_id() {
  TARGET_OBJECT=${OBJECT_TYPE} \
    netbox_id "$OBJECT_TYPE" "\$@"
}
EOF
)"
done
unset OBJECT_TYPE

pretty_output() {
  local columns_json_arr
  columns_json_arr=$(arr_to_json "${JSON_COLUMNS[@]}")

  {
    if [[ -z "$NO_HEADER" ]]
    then
      # shellcheck disable=SC2031
      for col in "${COLUMN_NAMES[@]}"
      do
        if [[ -n "$NO_COLOR" ]]
        then
          echo -ne "${col}\t"
        else
          echo -ne "\e[1m${col}\e[0m\t"
        fi
      done
      echo
    fi

    local compact=false
    [[ -n "$COMPACT" ]] && compact=true

    local sort_by=${SORT_BY:-name} sort_reverse=false
    if [[ "$sort_by" == -* ]]
    then
      sort_by="${sort_by:1}"
      sort_reverse=true
    fi

    jq -er \
      --arg sort_by "$sort_by" \
      --argjson sort_reverse "$sort_reverse" \
      --argjson cols_json "$columns_json_arr" \
      --argjson compact "$compact" '
      def extractFields:
        . as $obj |
        reduce $cols_json[] as $field (
          {}; . + {
            ($field | gsub("\\."; "_")): $obj | getpath($field / ".")
          }
        );

      "N/A" as $NA |

      . |
      if (. | type == "array")
      then
        sort_by(
          if ((.[ $sort_by ] | type) == "string")
          then
            (.[ $sort_by ] | ascii_downcase)
          else
            .[ $sort_by ]
          end
        ) | (if $sort_reverse then reverse else . end) | map(extractFields)[]
      else
        extractFields
      end |
      map(
        if (
          (. | type == "null") or
          ((. | type == "string") and ((. | length) == 0))
        )
        then
          $NA
        elif (. | type == "array")
        then
          (
            if (. | length) == 0
            then
              # empty array
              $NA
            else
              # array of strings/integers
              if all(.[]; (type == "string" or type == "number"))
              then
                map(tostring) | join(", ")
              elif all(.[]; type == "object" and has("name"))
              then
                # array with multiple objects that all have names
                [.[].name] | sort | join(" ")
              end
            end
          ) as $out |

          # Truncate if needed (and requested)
          40 as $maxwidth |
          if ($compact and (($out | length) > $maxwidth))
          then
            $out[0:$maxwidth] + "…"
          else
            $out
          end

        else
          # Regular values (strings and unhandled objects)
          .
        end
      ) | @tsv
    ' | colorizecolumns
  } | column -t -s '	'
}

main() {
  local args=()

  # globals
  JSON_COLUMNS=()
  COLUMN_NAMES=()

  local JSON_COLUMNS_AFTER=()
  local JSON_COLUMNS_REMOVE=()
  local COLUMN_NAMES_AFTER=()

  # Below removes the equals signs from all opts
  # ie: --api-token=foo -> --api-token foo
  # shellcheck disable=SC2034,SC2046
  set -- $(sed -r 's#(^| )(--?[^-= ]+)=([^= ]+)#\1\2 \3#g' <<< "$@")

  while [[ -n "$*" ]]
  do
    case "$1" in
      help|h|-h|--help)
        usage
        exit 0
        ;;
      -a|--api-token)
        NETBOX_API_TOKEN="$2"
        shift 2
        ;;
      -u|--url)
        NETBOX_URL="$2"
        shift 2
        ;;
      -g|--graphql)
        GRAPHQL=1
        shift
        ;;
      -D|--debug)
        DEBUG=1
        shift
        ;;
      -P|--pedantic)
        PEDANTIC=1
        set -eu -o pipefail
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
      -o|--output)
        OUTPUT="$2"
        shift 2
        ;;
      -j|--json)
        OUTPUT=json
        shift
        ;;
      -F|--field)
        FIELD="$2"
        OUTPUT=field
        shift 2
        ;;
      -N|-no-header)
        NO_HEADER=1
        shift
        ;;
      -c|--no-color)
        NO_COLOR=1
        shift
        ;;
      --compact|--truncate)
        COMPACT=1
        shift 1
        ;;
      --header|--keep-header)
        KEEP_HEADER=1
        shift
        ;;
      -I|--id*|--with-id)
        WITH_ID_COL=1
        shift
        ;;
      -C|--comment*|--with-comment*)
        JSON_COLUMNS_AFTER+=(comments)
        COLUMN_NAMES_AFTER+=(Comments)
        shift
        ;;
      --columns|--cols)
        # FIXME Use an associative array for COLUMNS
        local CUSTOM_COLUMNS
        local cols_custom=()
        local after
        local remove
        local val="$2"

        # If cols value starts with a '+', append to the default columns
        local first_char="${val:0:1}"
        case "$first_char" in
          +)
            val="${val:1}"
            after=1
            ;;
          -)
            val="${val:1}"
            remove=1
            ;;
          *)
            # Setting CUSTOM_COLUMNS will override the default columns
            CUSTOM_COLUMNS=1
            ;;
        esac

        mapfile -t cols_custom < <(tr ',' '\n' <<< "$val")

        # COLUMN_NAMES=() # Reset
        local col col_no_undies col_capitalized
        for col in "${cols_custom[@]}"
        do
          col_no_undies=${col//_/ }
          # Uppercase all if col name is 1 or 2 chars only
          if [[ ${#col} -lt 3 ]]
          then
            col_capitalized=${col^^}
          else
            col_capitalized="$(awk '
              {
                for(i=1;i<=NF;i++)
                  $i=toupper(substr($i,1,1)) tolower(substr($i,2))
              }1' <<< "${col_no_undies//./ }")"
          fi

          if [[ -n "$after" ]]
          then
            JSON_COLUMNS_AFTER+=("$col")
            COLUMN_NAMES_AFTER+=("$col_capitalized")
          elif [[ -n "$remove" ]]
          then
            JSON_COLUMNS_REMOVE+=("$col")
          else
            JSON_COLUMNS+=("$col")
            COLUMN_NAMES+=("$col_capitalized")
          fi
        done

        unset after remove

        shift 2
        ;;
      -s|--sort*)
        SORT_BY="$2"
        CUSTOM_SORT=1
        shift 2
        ;;
      --)
        shift
        args+=("$@")
        break
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

  if [[ -z "$CUSTOM_COLUMNS" ]]
  then
    JSON_COLUMNS+=(name description)
    COLUMN_NAMES+=(Name Description)
  fi

  if [[ -n "$WITH_ID_COL" ]]
  then
    JSON_COLUMNS=(id "${JSON_COLUMNS[@]}")
    COLUMN_NAMES=(ID "${COLUMN_NAMES[@]}")
  fi

  local command=()

  case "$ACTION" in
    # Meta
    cols|columns)
      if [[ -z "$1" ]]
      then
        echo_error "Missing object type"
        usage >&2
        return 2
      fi
      if [[ -n "$GRAPHQL" ]]
      then
        netbox_graphql_list_columns "$@"
      else
        netbox_rest_list_columns "$@"
      fi
      return "$?"
      ;;
    introspect)
      netbox_graphql_introspect "$@"
      ;;

    # Shorthands
    agg*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        # aggregates have no name field
        mapfile -t JSON_COLUMNS < <(arr_replace name display "${JSON_COLUMNS[@]}")
        mapfile -t COLUMN_NAMES < <(arr_replace Name Display "${COLUMN_NAMES[@]}")

        JSON_COLUMNS+=(rir.name tenant.name)
        COLUMN_NAMES+=(RIR Tenant)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects aggregate
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_aggregates)
      fi
      ;;
    cable*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        # cables have no name field
        # mapfile -t JSON_COLUMNS < <(arr_replace name label "${JSON_COLUMNS[@]}")
        # mapfile -t COLUMN_NAMES < <(arr_replace Name Label "${COLUMN_NAMES[@]}")
        mapfile -t JSON_COLUMNS < <(arr_remove name -- "${JSON_COLUMNS[@]}")
        mapfile -t COLUMN_NAMES < <(arr_remove Name -- "${COLUMN_NAMES[@]}")
        # JSON_COLUMNS+=(a_terminations.name b_terminations.name status tenant.name)
        # COLUMN_NAMES+=("Termination A" "Termination B" Status Tenant)
        JSON_COLUMNS+=(status tenant.name type)
        COLUMN_NAMES+=(Status Tenant Type)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects cable
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_cables)
      fi
      ;;
    circuit*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        # circuits have no name field
        mapfile -t JSON_COLUMNS < <(arr_remove name -- "${JSON_COLUMNS[@]}")
        mapfile -t COLUMN_NAMES < <(arr_remove Name -- "${COLUMN_NAMES[@]}")

        JSON_COLUMNS+=(provider.name type.name status.value termination_a.display termination_z.display)
        COLUMN_NAMES+=(Provider Type Status "Side A" "Side Z")
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        mapfile -t JSON_COLUMNS < <(arr_replace status.value status "${JSON_COLUMNS[@]}")
        command=(
          netbox_graphql_objects circuit
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_circuits)
      fi
      ;;
    c|cl|cluster*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(group.name type.name device_count)
        COLUMN_NAMES+=(Group Type "Device Count")
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects cluster
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_clusters)
      fi
      ;;
    clg|clgrp*|cl-g*)
      # TODO Add support for graphql
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(cluster_count)
        COLUMN_NAMES+=("Cluster Count")
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects cluster_group
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_cluster_groups)
      fi
      ;;
    clt|cltype*|cl-t*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(cluster_count)
        COLUMN_NAMES+=("Cluster Count")
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects cluster_type
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_cluster_types)
      fi
      ;;
    config-ctx*|confctx*|conf-ctx*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(weight is_active data_synced)
        COLUMN_NAMES+=(Weight Active Synced)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects config_context
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_config_contexts)
      fi
      ;;
    con|contact|contacts)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(group.name email phone)
        COLUMN_NAMES+=(Group Email Phone)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects contact
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_contacts)
      fi
      ;;
    console-port*|consp)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(device.name type.label mark_connected)
        COLUMN_NAMES+=(Device Type Reachable)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        mapfile -t JSON_COLUMNS < <(arr_replace type.label type "${JSON_COLUMNS[@]}")
        command=(
          netbox_graphql_objects console_port
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_console_ports)
      fi
      ;;
    console-server-port*|cons*server*po)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(device.name type.label mark_connected)
        COLUMN_NAMES+=(Device Type Reachable)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        mapfile -t JSON_COLUMNS < <(arr_replace type.label type "${JSON_COLUMNS[@]}")

        command=(
          netbox_graphql_objects console_server_port
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_console_server_ports)
      fi
      ;;
    contact-ass*|conass*|con-ass*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        # contact-assignments has no name field
        mapfile -t JSON_COLUMNS < <(arr_remove name description -- "${JSON_COLUMNS[@]}")
        mapfile -t COLUMN_NAMES < <(arr_remove Name Description -- "${COLUMN_NAMES[@]}")

        JSON_COLUMNS+=(contact.name role.name)
        COLUMN_NAMES+=(Contact Role)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects contact_assignment
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        if [[ -z "$CUSTOM_COLUMNS" ]]
        then
          JSON_COLUMNS+=(object.name)
          COLUMN_NAMES+=(Object)
        fi

        command=(netbox_list_contact_assignments)
      fi
      ;;
    contact-grp*|con-grp*|congrp*)
      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects contact_group
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_contact_groups)
      fi
      ;;
    contact-roles|con-role*|conrole*)
      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects contact_role
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_contact_roles)
      fi
      ;;
    cf|cust*f*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(label group_name type.value required)
        COLUMN_NAMES+=(Label "Group" Type Required)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        mapfile -t JSON_COLUMNS < <(arr_replace_multiple \
          type.value type \
          -- "${JSON_COLUMNS[@]}")
        command=(
          netbox_graphql_objects custom_field
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        # TODO Add support for GraphQL
        if [[ -z "$CUSTOM_COLUMNS" ]]
        then
          JSON_COLUMNS+=(content_types)
          COLUMN_NAMES+=("Content Type")
        fi
        command=(netbox_list_custom_fields)
      fi
      ;;
    d|dev|devices)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(
          device_type.manufacturer.name
          device_type.model
          role.name
          rack.name
          primary_ip4.address
        )
        COLUMN_NAMES+=(
          Manufacturer
          Model
          Role
          Rack
          "Primary IPv4"
        )
      fi

      if [[ -z "$CUSTOM_SORT" ]]
      then
        SORT_BY="role"
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects device
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_devices)
      fi
      ;;
    db|device-bay*|dev*bay*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(device.name installed_device.name)
        COLUMN_NAMES+=(Device "Installed Device")
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects device_bay
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_device_bays)
      fi
      ;;
    dr|device-role*|dev*rol*)
      JSON_COLUMNS+=(vm_role device_count virtualmachine_count)
      COLUMN_NAMES+=("VM Role" "Device Count" "VM Count")

      if [[ -n "$GRAPHQL" ]]
      then
        # DIRTYFIX For REST it's virtualmachines, for GraphQL it's virtual_machines
        mapfile -t JSON_COLUMNS < <(arr_gsub "virtualmachine" "virtual_machine" "${JSON_COLUMNS[@]}")

        command=(
          netbox_graphql_objects device_role
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_device_roles)
      fi
      ;;
    dt|dev-type*|dev*typ*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        # device-types have no name field
        mapfile -t JSON_COLUMNS < <(arr_replace name display "${JSON_COLUMNS[@]}")
        JSON_COLUMNS+=(manufacturer.name model part_number u_height is_full_depth device_count)
        COLUMN_NAMES+=(Manufacturer Model "Part No" "U Height" "Full Depth" "Device Count")
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        # DIRTYFIX For REST it's device(s), for GraphQL it's instance(s)
        mapfile -t JSON_COLUMNS < <(arr_replace device_count instance_count "${JSON_COLUMNS[@]}")

        command=(
          netbox_graphql_objects device_type
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_device_types)
      fi
      ;;
    front*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(device.name type.value rear_port.name rear_port_position)
        COLUMN_NAMES+=(Device Type "Rear Port" Position)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        mapfile -t JSON_COLUMNS < <(arr_replace_multiple \
          type.value type \
          rear_port_position rear_port.positions \
          -- "${JSON_COLUMNS[@]}")
        command=(
          netbox_graphql_objects front_port
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_front_ports)
      fi
      ;;
    intf|interface|interfaces)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(device.name label enabled type.label)
        COLUMN_NAMES+=(Device Label Enabled Type)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        mapfile -t JSON_COLUMNS < <(arr_replace type.label type "${JSON_COLUMNS[@]}")

        command=(
          netbox_graphql_objects interface
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_interfaces)
      fi
      ;;
    ip|ip-*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        # ip-addresses have no name field
        mapfile -t JSON_COLUMNS < <(arr_replace name address "${JSON_COLUMNS[@]}")
        mapfile -t COLUMN_NAMES < <(arr_replace Name Address "${COLUMN_NAMES[@]}")
      fi

      JSON_COLUMNS+=(dns_name tenant.name)
      COLUMN_NAMES+=(DNS Tenant)

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects ip_address
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
        # FIXME Add support for graphql
        # We'd need to use a query like this one:
        # {
        #   ip_address_list(address:"xxxxxxx") {
        #     address
        #     assigned_object {
        #       __typename
        #       ... on InterfaceType { device { name } }
        #       ... on VMInterfaceType { virtual_machine { name } }
        #     }
        #   }
        # }
        # JSON_COLUMNS+=(assigned_object.name)
        # COLUMN_NAMES+=(Device)
      else
        command=(netbox_list_ip_addresses)
        JSON_COLUMNS+=(assigned_object.device.name assigned_object.name)
        COLUMN_NAMES+=(Device Port)
      fi
      ;;
    ipf|pref*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        # ip-addresses have no name field
        mapfile -t JSON_COLUMNS < <(arr_replace name prefix "${JSON_COLUMNS[@]}")
        mapfile -t COLUMN_NAMES < <(arr_replace Name Prefix "${COLUMN_NAMES[@]}")
        JSON_COLUMNS+=(site.name tenant.name)
        COLUMN_NAMES+=(Site Tenant)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects prefix
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_prefixes)
      fi
      ;;
    inv|inventory*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(device.name label role.name manufacturer.name serial asset_tag)
        COLUMN_NAMES+=(Device Label Role Manufacturer Serial "Asset Tag")
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects inventory_item
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_inventory_items)
      fi
      ;;
    l|loc*)
      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects location
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_locations)
      fi
      ;;
    m|manufacturer*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(devicetype_count inventoryitem_count)
        COLUMN_NAMES+=("Device Type Count" "Inventory Item Count")
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        # DIRTYFIX For REST it's devicetype and inventoryitem, for GraphQL
        # it's device_type and inventory_item
        mapfile -t JSON_COLUMNS < <(arr_gsub_multiple \
          "devicetype" "device_type" \
          "inventoryitem" "inventory_item" \
          -- "${JSON_COLUMNS[@]}")

        command=(
          netbox_graphql_objects manufacturer
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_manufacturers)
      fi
      ;;
    plat*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(manufacturer.name)
        COLUMN_NAMES+=(Manufacturer)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects platform
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_platforms)
      fi
      ;;
    pp|pow*port)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(device.name type maximum_draw allocated_draw)
        COLUMN_NAMES+=(Device Type "Maximum Draw" "Allocated Draw")
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects power_port
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_power_ports)
      fi
      ;;
    po|power*out*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(device.name type power_port.name feed_leg)
        COLUMN_NAMES+=(Device Type "Power Port" "Feed Leg")
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects power_outlet
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_power_outlets)
      fi
      ;;
    prov*)
      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects provider
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_providers)
      fi
      ;;
    r|rack|racks*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(site.name location.name)
        COLUMN_NAMES+=(Site Location)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects rack
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_racks)
      fi
      ;;
    rackres*|rack-res*|reserv*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        # rack-reservations have no name field
        mapfile -t JSON_COLUMNS < <(arr_remove name -- "${JSON_COLUMNS[@]}")
        mapfile -t COLUMN_NAMES < <(arr_remove Name -- "${COLUMN_NAMES[@]}")

        JSON_COLUMNS+=(rack.name units)
        COLUMN_NAMES+=(Rack Units)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects rack_reservation
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        JSON_COLUMNS+=(user.username)
        COLUMN_NAMES+=(User)
        command=(netbox_list_rack_reservations)
      fi
      ;;
    rackro*|rack-ro*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(rack_count)
        COLUMN_NAMES+=("Rack Count")
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects rack_role
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_rack_roles)
      fi
      ;;
    rear*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(device.name type)
        COLUMN_NAMES+=(Device Type)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects rear_port
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_rear_ports)
      fi
      ;;
    rir*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(aggregate_count is_private)
        COLUMN_NAMES+=(Aggregates Private)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
      command=(
        netbox_graphql_objects rir
        "${JSON_COLUMNS[@]}"
        "${JSON_COLUMNS_AFTER[@]}"
      )
      else
        command=(netbox_list_rirs)
      fi
      ;;
    re|region*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(parent.name)
        COLUMN_NAMES+=(Parent)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects region
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_regions)
      fi
      ;;
    svc|service*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(ports protocol)
        COLUMN_NAMES+=(Ports Protocol)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        mapfile -t JSON_COLUMNS < <(arr_replace protocol.value protocol "${JSON_COLUMNS[@]}")

        command=(
          netbox_graphql_objects service
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_services)
      fi
      ;;
    s|site*)
      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects site
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_sites)
      fi
      ;;
    t|te|ten|tenant|tenants)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(group.name)
        COLUMN_NAMES+=(Group)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects tenant
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_tenants)
      fi
      ;;
    ten-gr*|tenant-gr*|tengr*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(parent.name)
        COLUMN_NAMES+=(Parent)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects tenant_group
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_tenant_groups)
      fi
      ;;
    tag*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(color)
        COLUMN_NAMES+=(Color)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects tag
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_tags)
      fi
      ;;
    vlan|vlans)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(role.name site.name tenant.name)
        COLUMN_NAMES+=(Role Site Tenant)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects vlan
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_vlans)
      fi
      ;;
    vlg|vlan-g*|vlan*g*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(vlan_count)
        COLUMN_NAMES+=("VLAN Count")
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects vlan_group
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        # TODO GraphQL support: scope and utilization are not available in
        # GraphQL at all it seems...
        # vlg.scope does not have *any* fields in GraphQL
        if [[ -z "$CUSTOM_COLUMNS" ]]
        then
          JSON_COLUMNS+=(scope_type scope.name utilization)
          COLUMN_NAMES+=("Scope Type" "Scope" Utilization)
        fi
        command=(netbox_list_vlan_groups)
      fi
      ;;
    vlr|vlan-r*|vlan*r*|role|roles)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(prefix_count vlan_count)
        COLUMN_NAMES+=("Prefix Count" "VLAN Count")
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects role
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_roles)
      fi
      ;;
    vc|virtual-chassis|virt-cha*|virtch*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(domain master.name member_count)
        COLUMN_NAMES+=(Domain Master Members)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects virtual_chassis
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_virtual_chassis)
      fi
      ;;
    vm|virtual-machine*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(cluster.name)
        COLUMN_NAMES+=(Cluster)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects virtual_machine
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_virtual_machines)
      fi
      ;;
    vmi|vm-int*|vmint*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(virtual_machine.name enabled)
        COLUMN_NAMES+=(VM Enabled)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects vm_interface
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_virtual_machine_interfaces)
      fi
      ;;
    vrf*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(tenant.name)
        COLUMN_NAMES+=(Tenant)
      fi
      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects vrf
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_vrfs)
      fi
      ;;
    wh|webh*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(http_method http_content_type payload_url body_template)
        COLUMN_NAMES+=(Method Content-Type URL Body)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects webhook
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        # FIXME Fix tags in GraphQL
        if [[ -z "$CUSTOM_COLUMNS" ]]
        then
          JSON_COLUMNS+=(tags)
          COLUMN_NAMES+=(Tags)
        fi
        command=(netbox_list_webhooks)
      fi
      ;;
    wifi|wireless-lans)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(site.name)
        COLUMN_NAMES+=(Site)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(
          netbox_graphql_objects wireless_lan
          "${JSON_COLUMNS[@]}"
          "${JSON_COLUMNS_AFTER[@]}"
        )
      else
        command=(netbox_list_wireless_lans)
      fi
      ;;

    # RAW
    graph*)
      command=(netbox_graphql)
      if [[ "$OUTPUT" != "json" ]]
      then
        echo_warning "Output format forced to 'json' for GraphQL queries"
        OUTPUT=json
      fi
      ;;
    raw)
      command=(netbox_curl_raw)
      if [[ "$OUTPUT" != "json" ]]
      then
        echo_warning "Output format forced to 'json' for raw curl requests"
        OUTPUT=json
      fi
      ;;

    # Workflows
    assign-to-cluster)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(
          device_type.manufacturer.name
          device_type.model
          role.name
          rack.name
          cluster.name
        )
        COLUMN_NAMES+=(
          Manufacturer
          Model
          Role
          Rack
          Cluster
        )
      fi

      command=(netbox_assign_devices_to_cluster)
      if [[ "$OUTPUT" != "json" ]]
      then
        echo_warning "Output format forced to 'json' for assign-to-cluster action"
        OUTPUT=json
      fi
      ;;

    *)
      echo_error "Unknown action: $ACTION"
      usage
      exit 1
      ;;
  esac

  # Append custom columns to the end (if they were prefixed with '+' on the CLI)
  if [[ "${#JSON_COLUMNS_AFTER[@]}" -gt 0 ]]
  then
    JSON_COLUMNS=("${JSON_COLUMNS[@]}" "${JSON_COLUMNS_AFTER[@]}")
    COLUMN_NAMES=("${COLUMN_NAMES[@]}" "${COLUMN_NAMES_AFTER[@]}")
  fi

  # Remove columns from the list (if they were prefixed with '-' on the CLI)
  local col_val col_index
  for col_val in "${JSON_COLUMNS_REMOVE[@]}"
  do
    col_index=$(arr_index_of "$col_val" "${JSON_COLUMNS[@]}")

    # Look for the column in the list of column names if not found in the list
    # of json paths
    if [[ -z "$col_index" ]]
    then
      local col_names_lc=( "${COLUMN_NAMES[@],,}" )
      col_index=$(arr_index_of "$col_val" "${col_names_lc[@]}")
    fi

    if [[ -z "$col_index" ]]
    then
      echo_warning "Column '$col' not found in the list of columns, skipping"
      continue
    fi

    mapfile -t JSON_COLUMNS < <(arr_remove_at "$col_index" "${JSON_COLUMNS[@]}")
    mapfile -t COLUMN_NAMES < <(arr_remove_at "$col_index" "${COLUMN_NAMES[@]}")
  done

  echo_debug "Columns: ${JSON_COLUMNS[*]}"

  if ! JSON_DATA="$("${command[@]}" "$@")"
  then
    return 1
  fi

  case "$OUTPUT" in
    json)
      jq -er '.' <<< "$JSON_DATA"
      ;;
    field)
      jq -er --arg f "$FIELD" '.[][$f]' <<< "$JSON_DATA"
      ;;
    pretty)
      # Skip header and color if output is not a terminal
      if [[ ! -t 1 ]]
      then
        [[ -z "$KEEP_HEADER" ]] && NO_HEADER=1
        NO_COLOR=1
      fi

      case "$JSON_DATA" in
        "[]"|"{}"|"null")
          echo_warning "No data to display (empty result)"
          echo_debug "Raw data: $JSON_DATA"
          return 0
          ;;
      esac

      pretty_output <<< "$JSON_DATA"
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  main "$@"
fi
