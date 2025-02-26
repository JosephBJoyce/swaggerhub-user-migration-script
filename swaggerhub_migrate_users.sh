#!/bin/bash

# Configuration
SOURCE_ORG="source_organization_name"
TARGET_ORG="target_organization_name"
SOURCE_API_KEY="source_api_key"
TARGET_API_KEY="target_api_key"

# SwaggerHub API base URL
API_URL="https://api.swaggerhub.com/user-management/v1"

# Temporary file to store user data
TEMP_FILE=$(mktemp)

# Function to fetch users from the source organization
fetch_users() {
  curl -s -X GET "$API_URL/orgs/$SOURCE_ORG/members" \
    -H "Authorization: $SOURCE_API_KEY" \
    -H "Accept: application/json" \
    -o "$TEMP_FILE"
}

# Function to add users to the target organization
add_users() {
  while IFS= read -r user; do
    email=$(echo "$user" | jq -r '.email')
    role=$(echo "$user" | jq -r '.role')

    # Prepare JSON payload
    payload=$(jq -n --arg email "$email" --arg role "$role" \
      '{ members: [{ email: $email, role: $role }] }')

    # Add user to the target organization
    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/orgs/$TARGET_ORG/members" \
      -H "Authorization: $TARGET_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$payload")

    if [ "$response" -eq 200 ]; then
      echo "Successfully added $email to $TARGET_ORG with role $role."
    else
      echo "Failed to add $email to $TARGET_ORG. HTTP status code: $response"
    fi
  done < <(jq -c '.items[]' "$TEMP_FILE")
}

# Main script execution
fetch_users
add_users

# Clean up
rm "$TEMP_FILE"
