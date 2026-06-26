#!/usr/bin/env bash
# ArgoCD API helper — resolves ARGOCD_URL/ARGOCD_TOKEN from OS-level ALPHA_ARGOCD_* vars.
# Source this file: source $HOME/.pi/agent/skills/argocd-api/helpers.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Local .env overrides (optional)
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
fi

# Default to dev if not set
export ARGOCD_ENV="${ARGOCD_ENV:-dev}"

# Env-agnostic lookup: read ARGOCD_{ENV}_URL/TOKEN from the ALPHA_* vars
case "$ARGOCD_ENV" in
  dev|test)
    server_var="ALPHA_ARGOCD_$(echo "$ARGOCD_ENV" | tr '[:lower:]' '[:upper:]')_SERVER"
    key_var="ALPHA_ARGOCD_$(echo "$ARGOCD_ENV" | tr '[:lower:]' '[:upper:]')_API_KEY"

    argocd_server="${!server_var}"
    argocd_key="${!key_var}"

    if [[ -n "$argocd_server" ]]; then
      export ARGOCD_URL="https://$argocd_server"
    fi
    if [[ -n "$argocd_key" ]]; then
      export ARGOCD_TOKEN="$argocd_key"
    fi
    ;;
  *)
    echo "ArgoCD: unknown ARGOCD_ENV=$ARGOCD_ENV (expected dev or test)" >&2
    ;;
esac

# Convenience aliases
ARGOCD_DEV_SERVER="${ALPHA_ARGOCD_DEV_SERVER:-}"
ARGOCD_DEV_API_KEY="${ALPHA_ARGOCD_DEV_API_KEY:-}"
ARGOCD_TEST_SERVER="${ALPHA_ARGOCD_TEST_SERVER:-}"
ARGOCD_TEST_API_KEY="${ALPHA_ARGOCD_TEST_API_KEY:-}"

# ─────────────────────────────────────────────────────────────────────────────
# Pod logs — the main reason to reach for this skill.
# The logs endpoint is NOT in ArgoCD's published swagger but it works:
#   GET /api/v1/applications/{app}/pods/{pod}/logs?namespace=&tailLines=&follow=false
# The body is NDJSON of {"result":{"content","timeStamp"}}; decode with .result.content.
# Get pod names from the resource-tree (there is no pod-list endpoint).
# ─────────────────────────────────────────────────────────────────────────────

# List an app's pods:  name <tab> namespace <tab> health
argocd_pods() {
  local app="$1"
  curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
    "$ARGOCD_URL/api/v1/applications/$app/resource-tree" \
    | jq -r '.nodes[] | select(.kind=="Pod") | "\(.name)\t\(.namespace)\t\(.health.status // "?")"'
}

# Fetch a pod's logs (decoded plain text).
# Usage: argocd_logs <app> <pod> [tailLines=400] [namespace=alpha] [container]
argocd_logs() {
  local app="$1" pod="$2" tail="${3:-400}" ns="${4:-alpha}" container="${5:-}"
  local q="namespace=${ns}&tailLines=${tail}&follow=false"
  [[ -n "$container" ]] && q="${q}&container=${container}"
  curl -s -H "Authorization: Bearer $ARGOCD_TOKEN" \
    "$ARGOCD_URL/api/v1/applications/$app/pods/$pod/logs?${q}" \
    | jq -r '.result.content // empty'
}

# Convenience: dump logs for EVERY pod of an app (handy when an app has worker/sidecar pods).
argocd_logs_all() {
  local app="$1" tail="${2:-400}" ns="${3:-alpha}"
  argocd_pods "$app" | cut -f1 | while read -r pod; do
    echo "############ ${app} / ${pod} ############"
    argocd_logs "$app" "$pod" "$tail" "$ns"
  done
}
