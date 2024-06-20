#!/usr/bin/env bash

NETBOX_URL="${NETBOX_URL:-https://demo.netbox.dev}"
NETBOX_API_TOKEN="${NETBOX_API_TOKEN:-}"

COMPACT="${COMPACT:-}"
CONFIRM="${CONFIRM:-1}"
DRY_RUN="${DRY_RUN:-}"
DEBUG="${DEBUG:-}"
GRAPHQL="${GRAPHQL:-}"
NO_COLOR="${NO_COLOR:-}"
NO_HEADER="${NO_HEADER:-}"
NO_WARNINGS="${NO_WARNINGS:-}"
OUTPUT="${OUTPUT:-pretty}"
SORT_BY="${SORT_BY:-name}"
WITH_ID_COL="${WITH_ID_COL:-}"

declare -A NETBOX_API_ENDPOINTS=(
  [clusters]="virtualization/clusters/"
  [devices]="dcim/devices/"
  [device-roles]="dcim/device-roles/"
  [locations]="dcim/locations/"
  [manufacturers]="dcim/manufacturers/"
  [racks]="dcim/racks/"
  [sites]="dcim/sites/"
  [tenants]="tenancy/tenants/"
)

usage() {
  echo "Usage: $(basename "$0") [options] ACTION [ARGS]" >&2
  echo
  echo "List actions:"
  echo "  clusters      [FILTERS]   List clusters"
  echo "  devices       [FILTERS]   List devices"
  echo "  device-roles  [FILTERS]   List device roles"
  echo "  locations     [FILTERS]   List locations"
  echo "  manufacturers [FILTERS]   List manufacturers"
  echo "  racks         [FILTERS]   List racks"
  echo "  sites         [FILTERS]   List sites"
  echo "  tenants       [FILTERS]   List tenants"
  echo
  echo "Workflows commands:"
  echo "  assign-to-cluster CLUSTER [FILTERS]  Assign devices to a cluster"
  echo
  echo "raw commands:"
  echo "  graphql  QUERY FIELDS                GraphQL query"
  echo "  raw      ENDPOINT                    Fetch raw data from an endpoint"
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
  echo -en "\e[1m\e[35mDBG\e[0m " >&2
  echo "$*" >&2
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
    echo_debug "curl ${args[*]@Q}"
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

netbox_graphql() {
  local jq_filter=".data"

  while [[ "${#@}" -gt 0 ]]
  do
    case "$1" in
      --jq*)
        jq_filter="$2"
        shift 2
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

  local fields=("$@")
  if [[ "${#fields[@]}" -lt 1 ]]
  then
    # Default to output id and name fields
    fields=(id name)
  fi

  # Transform nested fields to GraphQL format
  local fields_ql
  fields_ql=$(to_graphql "${fields[@]}")

  echo_debug "GraphQL fields: $fields_ql"

  local data
  data=$(jq -nc \
    --arg query "$query" \
    --arg fields "$fields_ql" '
      {
        query: "query {\($query) {\($fields)}}"
      }
    ')

  echo_debug "GraphQL query: $data"

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

netbox_graphql_objects() {
  local object_type="${1%%s}"
  shift

  local -a args filters
  local key val

  # shellcheck disable=SC2046
  set -- $(TARGET_OBJECT="$object_type" resolve_filters "$@")

  while [[ -n $* ]]
  do
    case "$1" in
      *=*)
        # convert filters like rack_id=691 to GraphQL format (rack_id: "691")
        IFS="=" read -r key val <<< "$1"
        filters+=("${key}:\"${val}\"")
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

  # Resolve filters
  local f
  for f in "${filters[@]}"
  do
    IFS=":" read -r key val <<< "$f"

  done

  set -- "${args[@]}"

  local fields=("$@")
  # Default fields
  if [[ "${#fields[@]}" -eq 0 ]]
  then
    fields=(id name)
  fi

  local key="${object_type}_list"
  local q="${key}"

  if [[ "${#filters[@]}" -gt 0 ]]
  then
    q+="($(arr_join ', ' "${filters[@]}"))"
  fi

  netbox_graphql --jq ".data[\"${key}\"]" \
    "$q" "${fields[@]}"
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

  local filter key val obj matches search_prop
  local -A data

  for filter in "$@"
  do
    IFS="=" read -r key val <<< "$filter"

    case "$key" in
      *_id)
        if [[ ! "$val" =~ ^[0-9]+$ ]]
        then
          search_prop="name" # look for matches on name by default
          obj=${key%_id}

          # some objects don't have a name field
          case "$obj" in
            device_type)
              search_prop="slug"
              ;;
            role)
              # If we target devices, the "role" refers to a device_role
              case "$target_obj" in
                device|devices)
                  echo_debug "Rewrote filter 'role' to 'device_role'"
                  obj="device_role"
                  ;;
              esac
              ;;
          esac


          if [[ -z "${data[$obj]}" ]]
          then
            data[$obj]="$(netbox_graphql_objects "$obj" id "$search_prop")"
          fi

          mapfile -t matches < <(jq -er \
            --arg val "$val" \
            --arg search_prop "$search_prop" '
            .[] | select(.[$search_prop] == $val) | .id
          ' <<< "${data[$obj]}")

          case "${#matches[@]}" in
            0)
              echo_error "No matching $obj found for '$val'"
              return 1
              ;;
            1)
              val="${matches[0]}"
              ;;
            *)
              echo_error "Ambiguous $obj name '$val': ${matches[*]}"
              return 1
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
          if (. | length) == 0
          then
            $NA
          else
            if all(.[]; type == "object" and has("name"))
            then
              40 as $maxwidth |
              [.[].name] | sort | join(" ") as $out |
              if ($compact and (($out | length) > $maxwidth))
              then
                $out[0:$maxwidth] + "…"
              else
                $out
              end
            else
              (. | join(", "))
            end
          end
        else
          .
        end
      ) | @tsv
    ' | colorizecolumns
  } | column -t -s '	'
}

main() {
  local args=()

  JSON_COLUMNS=()
  JSON_COLUMNS_AFTER=()
  COLUMN_NAMES=()
  COLUMN_NAMES_AFTER=()

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
      -I|--id*|--with-id)
        WITH_ID_COL=1
        shift
        ;;
      --columns|--cols)
        # FIXME Use an associative array for COLUMNS
        local CUSTOM_COLUMNS
        local cols_custom=()
        local after
        local val="$2"

        # If cols value starts with a '+', append to the default columns
        if [[ "${val:0:1}" == "+" ]]
        then
          val="${val:1}"
          after=1
        else
          # Setting CUSTOM_COLUMNS will override the default columns
          CUSTOM_COLUMNS=1
        fi

        mapfile -t cols_custom < <(tr ',' '\n' <<< "$val")

        # COLUMN_NAMES=() # Reset
        local col col_capitalized
        for col in "${cols_custom[@]}"
        do
          # Uppercase all if col name is 1 or 2 chars only
          if [[ ${#col} -lt 3 ]]
          then
            col_capitalized=${col^^}
          else
            col_capitalized="$(awk '
              {
                for(i=1;i<=NF;i++)
                  $i=toupper(substr($i,1,1)) tolower(substr($i,2))
              }1' <<< "${col//./ }")"
          fi

          if [[ -n "$after" ]]
          then
            JSON_COLUMNS_AFTER+=("$col")
            COLUMN_NAMES_AFTER+=("$col_capitalized")
          else
            JSON_COLUMNS+=("$col")
            COLUMN_NAMES+=("$col_capitalized")
          fi
        done

        shift 2
        ;;
      -s|--sort*)
        SORT_BY="$2"
        # CUSTOM_SORT=1
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

  case "$OUTPUT" in
    pretty)
      # Skip header and color if output is not a terminal
      if [[ ! -t 1 ]]
      then
        NO_HEADER=1
        NO_COLOR=1
      fi
      ;;
  esac

  if [[ -n "$WITH_ID_COL" ]]
  then
    JSON_COLUMNS=(id "${JSON_COLUMNS[@]}")
    COLUMN_NAMES=(ID "${COLUMN_NAMES[@]}")
  fi

  local command=()

  case "$ACTION" in
    # Shorthands
    c|cl|cluster*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(group.name)
        COLUMN_NAMES+=(Group)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(netbox_graphql_objects cluster "${JSON_COLUMNS[@]}")
      else
        command=(netbox_list_clusters)
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
        )
        COLUMN_NAMES+=(
          Manufacturer
          Model
          Role
          Rack
        )
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(netbox_graphql_objects device "${JSON_COLUMNS[@]}")
      else
        command=(netbox_list_devices)
      fi
      ;;
    dr|device-role*)
      # if [[ -z "$CUSTOM_COLUMNS" ]]
      # then
      #   JSON_COLUMNS+=(role.name rack.name)
      #   COLUMN_NAMES+=(Role Rack)
      # fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(netbox_graphql_objects device_role "${JSON_COLUMNS[@]}")
      else
        command=(netbox_list_device_roles)
      fi
      ;;
    l|loc*)
      if [[ -n "$GRAPHQL" ]]
      then
        command=(netbox_graphql_objects location "${JSON_COLUMNS[@]}")
      else
        command=(netbox_list_locations)
      fi
      ;;
    m|manufacturer*)
      if [[ -n "$GRAPHQL" ]]
      then
        command=(netbox_graphql_objects manufacturer "${JSON_COLUMNS[@]}")
      else
        command=(netbox_list_manufacturers)
      fi
      ;;
    s|site*)
      if [[ -n "$GRAPHQL" ]]
      then
        command=(netbox_graphql_objects site "${JSON_COLUMNS[@]}")
      else
        command=(netbox_list_sites)
      fi
      ;;
    r|rack*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(site.name location.name)
        COLUMN_NAMES+=(Site Location)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(netbox_graphql_objects rack "${JSON_COLUMNS[@]}")
      else
        command=(netbox_list_racks)
      fi
      ;;
    t|ten*)
      if [[ -z "$CUSTOM_COLUMNS" ]]
      then
        JSON_COLUMNS+=(group.name)
        COLUMN_NAMES+=(Group)
      fi

      if [[ -n "$GRAPHQL" ]]
      then
        command=(netbox_graphql_objects tenant "${JSON_COLUMNS[@]}")
      else
        command=(netbox_list_tenants)
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
      command=(netbox_curl)
      if [[ "$OUTPUT" != "json" ]]
      then
        echo_warning "Output format forced to 'json' for raw curl requests"
        OUTPUT=json
      fi
      ;;

    # Workflows
    assign-to-cluster)
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

  if ! JSON_DATA="$("${command[@]}" "$@")"
  then
    return 1
  fi

  # Append custom columns to the end (if they were prefixed with '+' on the CLI)
  if [[ "${#JSON_COLUMNS_AFTER[@]}" -gt 0 ]]
  then
    JSON_COLUMNS=("${JSON_COLUMNS[@]}" "${JSON_COLUMNS_AFTER[@]}")
    COLUMN_NAMES=("${COLUMN_NAMES[@]}" "${COLUMN_NAMES_AFTER[@]}")
  fi

  case "$OUTPUT" in
    json)
      jq -er '.' <<< "$JSON_DATA"
      ;;
    pretty)
      pretty_output <<< "$JSON_DATA"
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  main "$@"
fi
