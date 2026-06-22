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
