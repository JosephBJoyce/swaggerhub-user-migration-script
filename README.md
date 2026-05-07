# SwaggerHub Organization User + Access Control Migration Script

This script migrates:

* Organization members
* Organization-level roles
* Resource-level access permissions (ACLs)

from one SwaggerHub organization to another using the SwaggerHub User Management API.

---

# Features

## Migrates Organization Membership

Copies users from a source organization into a target organization, preserving their org-level role.

Examples:

* OWNER
* DESIGNER
* CONSUMER

---

## Migrates Resource-Level Permissions

Copies user access assignments for resources such as:

* APIs
* Domains
* Other SwaggerHub resource types

Examples:

* READ
* WRITE
* OWNER

---

## Production-Oriented Improvements

Includes:

* Error handling
* Dependency validation
* Logging
* Temporary file cleanup
* Safer Bash settings
* API response validation

---

# Requirements

The following tools must be installed:

* `bash`
* `curl`
* `jq`

---

# SwaggerHub API Requirements

You will need:

* A source organization
* A target organization
* API keys with sufficient permissions in both orgs

The API keys should have permissions to:

* Read users and ACLs from the source org
* Add users and permissions to the target org

SwaggerHub User Management API docs:

[https://app.swaggerhub.com/apis-docs/swagger-hub/user-management-api/2.4.0#/](https://app.swaggerhub.com/apis-docs/swagger-hub/user-management-api/2.4.0#/)

---

# Environment Variables

Set the following environment variables before running the script.

## Linux / macOS

```bash
export SOURCE_ORG="source-org-name"
export TARGET_ORG="target-org-name"

export SOURCE_API_KEY="source-api-key"
export TARGET_API_KEY="target-api-key"
```

## Windows PowerShell

```powershell
$env:SOURCE_ORG="source-org-name"
$env:TARGET_ORG="target-org-name"

$env:SOURCE_API_KEY="source-api-key"
$env:TARGET_API_KEY="target-api-key"
```

---

# Running the Script

## Make Executable

```bash
chmod +x migrate-swaggerhub-users.sh
```

## Run

```bash
./migrate-swaggerhub-users.sh
```

---

# What the Script Does

For each user in the source org:

1. Fetches org membership details
2. Adds the user to the target org
3. Fetches all assigned resource permissions
4. Recreates those permissions in the target org

---

# Important Assumptions

## Resources Must Already Exist

The script assumes:

* APIs
* domains
* other resources

already exist in the target organization.

The script does NOT migrate the resources themselves.

---

## Resource Names Must Match

Resource names are assumed to be identical between:

* source org
* target org

If names differ, ACL migration will fail for those resources.

---

# Example Output

```text
[INFO] Fetching users from source org: source-org

[INFO] ----------------------------------------
[INFO] Processing user: user@example.com

[INFO] Added user: user@example.com (DESIGNER)

[INFO] Migrating resource permissions for: user@example.com

[INFO]   -> API / customer-api / OWNER
[INFO]      Permission migrated

[INFO]   -> DOMAIN / shared-models / WRITE
[INFO]      Permission migrated

[INFO] Migration complete
```

---

# Common Failure Scenarios

## User Already Exists

If a user already exists in the target org, the API may return:

* `409 Conflict`
* another 4xx response

The script will log the failure and continue.

---

## Resource Does Not Exist

If a target resource does not exist:

* permission migration for that resource will fail
* the script will continue processing other resources

---

## User Invitation Not Accepted Yet

Some ACL assignments may fail if:

* the user has not yet accepted their org invitation

---

# Recommended Migration Process

For real-world migrations:

1. Create the target org
2. Migrate APIs/resources first
3. Run this user + ACL migration script
4. Validate permissions
5. Ask users to verify access

---

# Suggested Future Enhancements

Potential improvements include:

* Dry-run mode
* CSV migration report
* Retry logic
* Parallel processing
* Pagination support beyond 1000 records
* URL encoding for special resource names
* Differential sync mode
* Verification mode (source vs target comparison)

---

# Security Notes

## Do NOT Hardcode API Keys

Use environment variables instead of storing secrets in source code.

---

## Avoid Committing Secrets

Add files like `.env` to `.gitignore`.

---

# Disclaimer

This script is provided as-is and should be tested in a non-production environment before use in production organizations.
