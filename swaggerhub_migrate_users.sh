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
# Required Environment Variables
########################################

SOURCE_ORG="${SOURCE_ORG:?Must set SOURCE_ORG}"
TARGET_ORG="${TARGET_ORG:?Must set TARGET_ORG}"
SOURCE_API_KEY="${SOURCE_API_KEY:?Must set SOURCE_API_KEY}"
TARGET_API_KEY="${TARGET_API_KEY:?Must set TARGET_API_KEY}"

########################################
# API Configuration
########################################

API_URL="https://api.swaggerhub.com/user-management/v1"

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

  http_code=$(curl -s \
    -o /tmp/swaggerhub_add_user_response.json \
    -w "%{http_code}" \
    -X POST \
    "$API_URL/orgs/$TARGET_ORG/members" \
    -H "Authorization: $TARGET_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload")

  if [[ "$http_code" =~ ^2 ]]; then
    log "Added user: $email ($role)"
  else
    error "Failed to add user: $email (HTTP $http_code)"
    cat /tmp/swaggerhub_add_user_response.json
  fi
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
# Recreate Resource Access In Target Org
########################################

migrate_resource_access() {
  local email="$1"

  log "Migrating resource permissions for: $email"

  roles_json=$(fetch_user_roles "$email")

  echo "$roles_json" | jq -c '.items[]?' | while read -r item; do

    resource_name=$(echo "$item" | jq -r '.resourceName')
    resource_type=$(echo "$item" | jq -r '.resourceType')
    role=$(echo "$item" | jq -r '.role')

    log "  -> $resource_type / $resource_name / $role"

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

    http_code=$(curl -s \
      -o /tmp/swaggerhub_acl_response.json \
      -w "%{http_code}" \
      -X POST \
      "$API_URL/orgs/$TARGET_ORG/resources/$resource_name/resource-type/$resource_type/users" \
      -H "Authorization: $TARGET_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$payload")

    if [[ "$http_code" =~ ^2 ]]; then
      log "     Permission migrated"
    else
      error "     Failed to migrate permission"
      error "     Resource: $resource_name"
      error "     Type: $resource_type"
      error "     HTTP: $http_code"

      cat /tmp/swaggerhub_acl_response.json
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

    log "----------------------------------------"
    log "Processing user: $email"

    add_user_to_target_org "$email" "$role"

    migrate_resource_access "$email"
  done

  log "Migration complete"
}

main
