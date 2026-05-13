# SwaggerHub User & ACL Migration Script

## Overview

This script migrates:

* Organization members
* Organization-level roles
* Resource-level ACL permissions

between two SwaggerHub organizations using the SwaggerHub User Management API.

The script supports migration of permissions for:

* APIs
* Domains
* Projects

It also includes:

* detailed debug logging
* ACL discovery
* role normalization
* URL encoding for resource names
* graceful handling of existing users
* error handling for missing target resources

---

# Features

## User Migration

Migrates organization members from a source organization to a target organization.

## Organization Role Migration

Migrates organization-level roles such as:

* OWNER
* DESIGNER
* CONSUMER

## Resource-Level ACL Migration

Migrates explicit resource permissions for:

* APIs
* Domains
* Projects

## Debug Logging

Provides detailed request/response output for troubleshooting.

## Safe Error Handling

Handles:

* existing users
* invalid resource references
* missing APIs/domains/projects
* malformed ACL entries

without terminating the entire migration.

---

# Requirements

## Dependencies

The following tools must be installed:

* bash
* curl
* jq

Verify dependencies:

```bash
curl --version
jq --version
```

---

# Configuration

Update the following variables in the script:

```bash
SOURCE_ORG="source_org"
TARGET_ORG="target_org"

SOURCE_API_KEY="source_api_key"
TARGET_API_KEY="target_api_key"
```

---

# API Permissions Required

The API keys used must have sufficient permissions to:

* read members from the source org
* read ACLs from the source org
* add members to the target org
* manage ACLs in the target org

---

# Running the Script

Make the script executable:

```bash
chmod +x swaggerhub-user-migration-script.sh
```

Run the script:

```bash
./swaggerhub-user-migration-script.sh
```

---

# Example Output

```text
[INFO] Processing user: daisy.priya@smartbear.com
[INFO] Added user: daisy.priya@smartbear.com (DESIGNER)
[INFO] Migrating resource permissions for: daisy.priya@smartbear.com
[INFO]   -> API / citizen-api / DESIGNER
[INFO]      Permission migrated
```

---

# Understanding ACL Migration Errors

## 404 Unknown API/Domain/Project

Example:

```text
Unknown API smartbear-bank/citizen-api
```

This means:

* the target organization does not contain the resource
* ACLs cannot be assigned until the resource exists

### Solution

Create or migrate the resource into the target org before running ACL migration.

---

# Supported Resource Types

The script currently supports:

* api
* domain
* project
* organization

Organization-level roles are handled separately through the `/members` endpoint.

---

# Important Behavioral Notes

## Organization Roles

Organization roles are migrated using:

```text
POST /orgs/{org}/members
```

These are NOT migrated as resource ACLs.

---

## Resource ACLs

ACLs are migrated using:

```text
POST /orgs/{org}/resources/{resource}/resource-type/{type}/users
```

The target resource must already exist.

---

# Troubleshooting

## Users Not Appearing In Target Org

If users are not appearing:

1. Verify the API key permissions
2. Verify the `/members` payload structure
3. Enable DEBUG logging
4. Check the API response body

---

## Users Incorrectly Reported As Existing

The script previously matched all 400 responses as duplicate users.

This has been corrected by narrowing duplicate detection logic.

---

## ACLs Not Migrating

If ACL migration fails:

* verify the target resource exists
* verify resource names match exactly
* verify resource type casing
* check the generated ACL URL in debug logs

---

# Debug Mode

Enable debug logging:

```bash
DEBUG=true
```

Debug mode outputs:

* raw API responses
* generated payloads
* generated URLs
* ACL responses

---

# Security Recommendations

## Rotate API Keys

If API keys were:

* committed to source control
* shared in chat
* exposed in logs

rotate them immediately.

---

# Known Limitations

## Resource Dependencies

ACL migration requires:

* APIs to exist
* domains to exist
* projects to exist

in the target organization.

## Pagination

The script currently requests:

```text
pageSize=1000
```

Organizations with more than 1000 users or ACLs may require pagination support.

---

# Recommended Future Enhancements

Potential improvements:

* CSV migration reports
* dry-run mode
* retry logic for transient API failures
* automatic resource existence checks
* automatic API/domain/project migration
* parallelized migrations
* configurable logging levels

---

# Exit Behavior

The script:

* continues when users already exist
* skips ACLs for missing resources
* logs failures without terminating the entire migration

Fatal API failures will still terminate execution.

---

# Disclaimer

This script is provided as-is and should be tested in a non-production environment before large-scale migration operations.
