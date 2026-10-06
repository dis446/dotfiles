#!/usr/bin/env bash
# Write ~/.config/gitlab-tui/config.json from the untracked secrets.
#
# gitlab-tui (nospor/gitlab-tui) reads ONLY this file — the binary has no
# env-var support (no GITLAB_* strings in it). The server + token live in
# bash/secret_aliases, which is sourced by INTERACTIVE shells only: ~/.bashrc
# early-returns for non-interactive shells ([[ $- == *i* ]] || return), so an
# install script that relies on `source ~/.bashrc` sees GITLAB_HOST unset.
#
# Hence this script sources the secrets directly and NEVER writes a
# placeholder. A placeholder host is exactly what broke gitlab-tui:
#   Get "https://<gitlab-host>/api/v4/user": dial tcp: lookup <gitlab-host>: no such host
#
# Idempotent and safe to run any time: ~/dotfiles/scripts/gitlab-tui-config.sh
set -u

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cfg="$HOME/.config/gitlab-tui/config.json"

# An already-exported value wins; otherwise pull it from the untracked secrets.
# secret_aliases is an interactive-shell file: it expands $GITLAB_TOKEN in an
# alias *before* defining it (line 6 vs line 11), so it needs nounset off.
if { [ -z "${GITLAB_HOST:-}" ] || [ -z "${GITLAB_TOKEN:-}" ]; } && [ -f "$repo/bash/secret_aliases" ]; then
  set +u
  . "$repo/bash/secret_aliases" 2>/dev/null || true
  set -u
fi

if [ -z "${GITLAB_HOST:-}" ] || [ -z "${GITLAB_TOKEN:-}" ]; then
  if [ -f "$cfg" ]; then
    echo "gitlab-tui: keeping existing config (set GITLAB_HOST/GITLAB_TOKEN in bash/secret_aliases to refresh)"
  else
    echo "WARN: gitlab-tui not configured — add GITLAB_HOST/GITLAB_TOKEN to bash/secret_aliases and re-run" >&2
  fi
  exit 0
fi

mkdir -p "$(dirname "$cfg")"
python3 - "$GITLAB_TOKEN" "$GITLAB_HOST" "$cfg" <<'PYEOF'
import json, os, sys
token, host, path = sys.argv[1], sys.argv[2], sys.argv[3]
cfg = {
    "servers": [{"name": host, "url": host, "token": token, "default": True}],
    "browser_command": "open" if sys.platform == "darwin" else "xdg-open",
    "theme": "catppuccin",
}
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
PYEOF
echo "gitlab-tui configured for $GITLAB_HOST"
