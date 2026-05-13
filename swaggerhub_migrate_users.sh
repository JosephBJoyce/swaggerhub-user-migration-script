#!/usr/bin/env bash

set -euo pipefail

########################################
# Dependency Checks
########################################

command -v curl >/dev/null || {
  echo "curl is required"
  exit 1
}

command -v jq >/dev/null || {
  echo "jq is required"
  exit 1
}

########################################
# Configuration
########################################

SOURCE_ORG="xxx"
TARGET_ORG="xxx"
SOURCE_API_KEY="xxx"
TARGET_API_KEY="xxx"

########################################
# API Configuration
########################################

API_URL="https://api.swaggerhub.com/user-management/v1"

########################################
# Debug Mode
########################################

DEBUG=true

########################################
# Temp Files
########################################

USERS_FILE=$(mktemp)

trap 'rm -f "$USERS_FILE"' EXIT

########################################
# Helper Functions
########################################

log() {
  echo "[INFO] $1"
}

error() {
  echo "[ERROR] $1" >&2
}

debug() {
  if [[ "$DEBUG" == "true" ]]; then
    echo "[DEBUG] $1"
  fi
}

########################################
# URL Encode
########################################

urlencode() {
  jq -nr --arg v "$1" '$v|@uri'
}

########################################
# Normalize Role Casing
########################################

normalize_role() {
  echo "$1" | tr '[:lower:]' '[:upper:]'
}

########################################
# Normalize Resource Type
########################################

normalize_resource_type() {

  local resource_type="$1"

  case "$(echo "$resource_type" | tr '[:upper:]' '[:lower:]')" in

    api|apis)
      echo "API"
      ;;

    domain|domains)
      echo "DOMAIN"
      ;;

    organization)
      echo "organization"
      ;;

    *)
      echo "$resource_type"
      ;;

  esac
}

########################################
# Fetch Organization Members
########################################

fetch_users() {

  log "Fetching users from source org: $SOURCE_ORG"

  http_code=$(curl -s \
    -w "%{http_code}" \
    -o "$USERS_FILE" \
    -X GET \
    "$API_URL/orgs/$SOURCE_ORG/members?page=0&pageSize=1000" \
    -H "Authorization: $SOURCE_API_KEY" \
    -H "Accept: application/json")

  if [[ "$http_code" != "200" ]]; then

    error "Failed to fetch users. HTTP $http_code"
    cat "$USERS_FILE"

    exit 1
  fi
}

########################################
# Add User To Target Org
########################################

add_user_to_target_org() {

  local email="$1"
  local role="$2"

  role=$(normalize_role "$role")

  payload=$(jq -n \
    --arg email "$email" \
    --arg role "$role" \
    '{
      members: [
        {
          email: $email,
          role: $role
        }
      ]
    }')

  debug "Add User Payload:"
  debug "$payload"

  http_code=$(curl -s \
    -o /tmp/swaggerhub_add_user_response.json \
    -w "%{http_code}" \
    -X POST \
    "$API_URL/orgs/$TARGET_ORG/members" \
    -H "Authorization: $TARGET_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload")

  response_body=$(cat /tmp/swaggerhub_add_user_response.json)

  debug "Add User Response:"
  debug "$response_body"

  case "$http_code" in

    200|201|204)

      log "Added user: $email ($role)"
      return 0
      ;;

    400)

      if echo "$response_body" | grep -qiE "already exists"; then

        log "User already exists: $email"

        return 0
      fi

      error "Bad request while adding user: $email"
      echo "$response_body"

      return 1
      ;;

    409)

      log "User already exists: $email"

      return 0
      ;;

    *)

      error "Failed to add user: $email (HTTP $http_code)"
      echo "$response_body"

      return 1
      ;;

  esac
}

########################################
# Fetch Resource Roles For User
########################################

fetch_user_roles() {

  local email="$1"

  curl -s \
    -X GET \
    "$API_URL/orgs/$SOURCE_ORG/roles?user=$email&page=0&pageSize=1000" \
    -H "Authorization: $SOURCE_API_KEY" \
    -H "Accept: application/json"
}

########################################
# Migrate Resource Permissions
########################################

migrate_resource_access() {

  local email="$1"

  log "Migrating resource permissions for: $email"

  roles_json=$(fetch_user_roles "$email")

  ########################################
  # DEBUG RAW RESPONSE
  ########################################

  debug "Raw Roles Response:"
  debug "$(echo "$roles_json" | jq '.')"

  echo "$roles_json" | jq -c '.items[]?' | while read -r item; do

    ########################################
    # DEBUG EACH ITEM
    ########################################

    debug "ACL Item:"
    debug "$(echo "$item" | jq '.')"

    ########################################
    # Extract Fields
    ########################################

    resource_name=$(echo "$item" | jq -r '.name // .resourceName // .resource.name // empty')
    resource_type=$(echo "$item" | jq -r '.resourceType // .resource.type // empty')
    role=$(echo "$item" | jq -r '.role // empty')

    ########################################
    # Normalize Resource Type
    ########################################

    resource_type=$(normalize_resource_type "$resource_type")

    ########################################
    # Skip Invalid Entries
    ########################################

    if [[ "$resource_type" == "organization" ]]; then

      log "     Organization-level role detected: $role"
      log "     Already migrated via /members endpoint"

      continue
    fi

    ########################################
    # Normalize Role
    ########################################

    if [[ -z "$role" ]] || [[ "$role" == "null" ]] || [[ "$role" == "NULL" ]]; then
    role="DESIGNER"
    fi

    role=$(normalize_role "$role")

    ########################################
    # URL Encode Resource Name
    ########################################

    encoded_resource_name=$(urlencode "$resource_name")

    ########################################
    # Log ACL
    ########################################

    log "  -> $resource_type / $resource_name / $role"

    ########################################
    # ACL Payload
    ########################################

    payload=$(jq -n \
      --arg email "$email" \
      --arg role "$role" \
      '{
        users: [
          {
            email: $email,
            role: $role
          }
        ]
      }')

    debug "ACL Payload:"
    debug "$payload"

    ########################################
    # POSSIBLE ENDPOINT VARIANTS
    ########################################

    ACL_URL="$API_URL/orgs/$TARGET_ORG/resources/$encoded_resource_name/resource-type/$resource_type/users"

    debug "ACL URL:"
    debug "$ACL_URL"

    ########################################
    # Create ACL
    ########################################

    http_code=$(curl -s \
      -o /tmp/swaggerhub_acl_response.json \
      -w "%{http_code}" \
      -X POST \
      "$ACL_URL" \
      -H "Authorization: $TARGET_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$payload")

    response_body=$(cat /tmp/swaggerhub_acl_response.json)

    debug "ACL Response:"
    debug "$response_body"

    if [[ "$http_code" =~ ^2 ]]; then

      log "     Permission migrated"

    else

      error "     Failed to migrate permission"
      error "     Resource: $resource_name"
      error "     Type: $resource_type"
      error "     Role: $role"
      error "     HTTP: $http_code"

      echo "$response_body"

    fi

  done
}

########################################
# Main Migration
########################################

main() {

  fetch_users

  jq -c '.items[]?' "$USERS_FILE" | while read -r user; do

    email=$(echo "$user" | jq -r '.email')
    role=$(echo "$user" | jq -r '.role')

    ########################################
    # Skip Invalid Entries
    ########################################

    if [[ -z "$email" ]] || [[ "$email" == "null" ]]; then
      continue
    fi

    role=$(normalize_role "$role")

    log "----------------------------------------"
    log "Processing user: $email"

    ########################################
    # Add User
    ########################################

    if add_user_to_target_org "$email" "$role"; then

      migrate_resource_access "$email"

    else

      error "Skipping ACL migration for $email"

    fi

  done

  log "Migration complete"
}

main
