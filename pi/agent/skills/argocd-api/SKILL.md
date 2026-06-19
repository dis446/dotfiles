---
name: argocd-api
description: Use when interacting with ArgoCD via its REST API. Covers auth, application management, sync, rollback, project operations, and cluster/repo management across multiple environments.
---

# ArgoCD API

## Setup

### Configuration

Copy `.env.example` to `.env` and fill in your ArgoCD credentials for dev and/or test environments:

```bash
cp "$(dirname "$(readlink -f "$0")")/.env.example" "$(dirname "$(readlink -f "$0")")/.env"
```

Edit `.env` with your ArgoCD server URLs and API tokens:

```bash
# .env
# Select active environment: "dev" or "test"
ARGOCD_ENV=dev

# Dev environment
ARGOCD_DEV_URL=https://argocd.dev.example.com
ARGOCD_DEV_TOKEN=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...

# Test environment
ARGOCD_TEST_URL=https://argocd.test.example.com
ARGOCD_TEST_TOKEN=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Never commit `.env`** (already gitignored via `pi/agent/skills/**/*.env*`).

### Activating

Source the env file to set variables:

```bash
source /home/ubby/.pi/agent/skills/argocd-api/.env
```

Or source directly if working from the dotfiles repo:

```bash
source /home/ubby/dotfiles/pi/agent/skills/argocd-api/.env
```

After sourcing, use the helper variables and functions below.

## Environment Resolution

The skill provides helper variables that resolve to the active environment:

| Variable | Description |
|----------|-------------|
| `ARGOCD_ENV` | Active environment: `dev` or `test` |
| `ARGOCD_URL` | Resolves to the active env's URL |
| `ARGOCD_TOKEN` | Resolves to the active env's API token |

After sourcing `.env`, you can switch environments by changing `ARGOCD_ENV` and re-sourcing:

```bash
# Switch to test
ARGOCD_ENV=test
source /home/ubby/.pi/agent/skills/argocd-api/.env

# Switch back to dev
ARGOCD_ENV=dev
source /home/ubby/.pi/agent/skills/argocd-api/.env
```

### Helper Script

Use the included helper to resolve env vars:

```bash
# Source the skill helper (keeps ARGOCD_URL/ARGOCD_TOKEN in sync with ARGOCD_ENV)
source /home/ubby/.pi/agent/skills/argocd-api/helpers.sh
```

## API Basics

All commands use `curl` against the ArgoCD REST API. The base pattern:

```bash
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/$ENDPOINT"
```

ArgoCD API docs: <https://cd.apps.and.global/swagger-ui>

### Common Headers

```bash
AUTH="Authorization: Bearer $ARGOCD_TOKEN"
CONTENT_JSON="Content-Type: application/json"
BASE_URL="$ARGOCD_URL/api/v1"
```

## Common Operations

### Authentication

ArgoCD API tokens are long-lived and environment-specific. Create a token via the ArgoCD UI or CLI:

```bash
argocd account generate-token --account <username>
```

Then set it in `.env` for the relevant environment.

### Applications

#### List all applications

```bash
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/applications" | jq
```

#### List applications in a specific project

```bash
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/applications?project=$PROJECT" | jq
```

#### Get application details

```bash
APP=my-service
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/applications/$APP" | jq
```

#### Get application resource tree

```bash
APP=my-service
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/applications/$APP/resource-tree" | jq
```

#### Sync an application

```bash
APP=my-service
curl -s -X POST \
  -H "Authorization: Bearer $ARGOCD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"revision": "HEAD", "prune": true, "dryRun": false}' \
  "$ARGOCD_URL/api/v1/applications/$APP/sync" | jq
```

#### Sync with specific revision

```bash
APP=my-service
REVISION=main
curl -s -X POST \
  -H "Authorization: Bearer $ARGOCD_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"revision\": \"$REVISION\", \"prune\": true, \"dryRun\": false}" \
  "$ARGOCD_URL/api/v1/applications/$APP/sync" | jq
```

#### Sync with resource overrides (specific manifests)

```bash
APP=my-service
curl -s -X POST \
  -H "Authorization: Bearer $ARGOCD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "revision": "HEAD",
    "prune": true,
    "dryRun": false,
    "resources": [
      {"group": "apps", "kind": "Deployment", "name": "my-service"},
      {"group": "", "kind": "Service", "name": "my-service"}
    ]
  }' \
  "$ARGOCD_URL/api/v1/applications/$APP/sync" | jq
```

#### Rollback an application

```bash
APP=my-service
# List deployment history to find the rollback ID
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/applications/$APP" | jq '.status.history[] | {id, revision, deployedAt}'

# Rollback to a specific deployment ID
ROLLBACK_ID=42
curl -s -X POST \
  -H "Authorization: Bearer $ARGOCD_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"id\": $ROLLBACK_ID, \"prune\": true, \"dryRun\": false}" \
  "$ARGOCD_URL/api/v1/applications/$APP/rollback" | jq
```

#### Get application sync status

```bash
APP=my-service
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/applications/$APP" | jq '.status.sync.status, .status.health.status'
```

#### Get application events

```bash
APP=my-service
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/applications/$APP/events" | jq
```

### ApplicationSets

#### List ApplicationSets

```bash
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/applicationsets" | jq
```

#### Get ApplicationSet details

```bash
APPSET=my-appset
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/applicationsets/$APPSET" | jq
```

### Projects

#### List projects

```bash
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/projects" | jq
```

#### Get project details

```bash
PROJECT=my-project
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/projects/$PROJECT" | jq
```

#### Create a project

```bash
PROJECT=my-project
curl -s -X POST \
  -H "Authorization: Bearer $ARGOCD_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"project\": {
      \"metadata\": {\"name\": \"$PROJECT\"},
      \"spec\": {
        \"sourceRepos\": [\"*\"],
        \"destinations\": [
          {\"namespace\": \"*\", \"server\": \"https://kubernetes.default.svc\"}
        ],
        \"clusterResourceWhitelist\": [{\"group\": \"*\", \"kind\": \"*\"}]
      }
    }
  }" \
  "$ARGOCD_URL/api/v1/projects" | jq
```

### Repositories

#### List configured repos

```bash
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/repositories" | jq
```

#### Add a repository

```bash
REPO_URL=https://github.com/myorg/my-repo.git
curl -s -X POST \
  -H "Authorization: Bearer $ARGOCD_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"repo\": \"$REPO_URL\",
    \"type\": \"git\",
    \"name\": \"my-repo\"
  }" \
  "$ARGOCD_URL/api/v1/repositories" | jq
```

### Clusters

#### List clusters

```bash
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/clusters" | jq
```

#### Get cluster details

```bash
SERVER_URL=https://kubernetes.default.svc
# URL-encode the server URL
ENCODED_SERVER=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$SERVER_URL'))")
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/clusters/$ENCODED_SERVER" | jq
```

### Sync Status & Health Checks

#### Check all applications with OutOfSync status

```bash
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/applications" | jq '[.items[] | select(.status.sync.status != "Synced") | {name: .metadata.name, sync: .status.sync.status, health: .status.health.status}]'
```

#### Check all applications with degraded health

```bash
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/applications" | jq '[.items[] | select(.status.health.status == "Degraded" or .status.health.status == "Missing") | {name: .metadata.name, sync: .status.sync.status, health: .status.health.status}]'
```

### Batch operations

#### Sync all OutOfSync apps in a project

```bash
PROJECT=my-project
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/applications?project=$PROJECT" | jq -r '.items[] | select(.status.sync.status == "OutOfSync") | .metadata.name' | while read APP; do
  echo "Syncing $APP..."
  curl -s -X POST \
    -H "Authorization: Bearer $ARGOCD_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"revision": "HEAD", "prune": true, "dryRun": false}' \
    "$ARGOCD_URL/api/v1/applications/$APP/sync" | jq '.metadata.name, .status.sync.status'
done
```

#### Sync all OutOfSync apps across ALL projects

```bash
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/applications" | jq -r '.items[] | select(.status.sync.status == "OutOfSync") | .metadata.name' | while read APP; do
  echo "Syncing $APP..."
  curl -s -X POST \
    -H "Authorization: Bearer $ARGOCD_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"revision": "HEAD", "prune": true, "dryRun": false}' \
    "$ARGOCD_URL/api/v1/applications/$APP/sync" > /dev/null
  echo "  Done."
done
```

### API Version Endpoint

```bash
# Check API server version
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/version" | jq
```

### User Info

```bash
# Get current user info
curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "$ARGOCD_URL/api/v1/account" | jq
```

## Convenience Functions

Add these to your `.env` or a helper script for quick use:

```bash
# Get auth header
argocd_auth() {
  echo "Authorization: Bearer $ARGOCD_TOKEN"
}

# Base curl with auth
argocd_get() {
  curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" "$ARGOCD_URL/api/v1/$1"
}

argocd_post() {
  curl -s -X POST -H "Authorization: Bearer $ARGOCD_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$2" "$ARGOCD_URL/api/v1/$1"
}

# Quick status check
argocd_status() {
  local app="$1"
  curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
    "$ARGOCD_URL/api/v1/applications/$app" | jq '{name: .metadata.name, sync: .status.sync.status, health: .status.health.status}'
}

# List OutOfSync apps
argocd_outofsync() {
  curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
    "$ARGOCD_URL/api/v1/applications" | jq '[.items[] | select(.status.sync.status != "Synced") | {name: .metadata.name, sync: .status.sync.status, health: .status.health.status}]'
}

# Sync an app (non-blocking)
argocd_sync() {
  local app="$1"
  curl -s -X POST -H "Authorization: Bearer $ARGOCD_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"revision": "HEAD", "prune": true, "dryRun": false}' \
    "$ARGOCD_URL/api/v1/applications/$app/sync" | jq '.metadata.name, .status.sync.status'
}

# Switch environment
argocd_env() {
  export ARGOCD_ENV="$1"
  source /home/ubby/.pi/agent/skills/argocd-api/.env
  echo "Switched to ARGOCD_ENV=$ARGOCD_ENV ($ARGOCD_URL)"
}
```

## API Reference

ArgoCD REST API v1 — full docs at `<your-argocd-server>/swagger-ui`.

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/applications` | List applications |
| GET | `/api/v1/applications/{name}` | Get application details |
| GET | `/api/v1/applications/{name}/resource-tree` | Get resource tree |
| GET | `/api/v1/applications/{name}/events` | Get events |
| POST | `/api/v1/applications/{name}/sync` | Sync application |
| POST | `/api/v1/applications/{name}/rollback` | Rollback application |
| GET | `/api/v1/applicationsets` | List ApplicationSets |
| GET | `/api/v1/applicationsets/{name}` | Get ApplicationSet |
| GET | `/api/v1/projects` | List projects |
| POST | `/api/v1/projects` | Create project |
| GET | `/api/v1/projects/{name}` | Get project details |
| GET | `/api/v1/repositories` | List repositories |
| POST | `/api/v1/repositories` | Add repository |
| GET | `/api/v1/clusters` | List clusters |
| GET | `/api/v1/version` | API version info |
| GET | `/api/v1/account` | Current user info |
