#!/usr/bin/env bash
# Shared helpers for the alpha feature workflow (feature-start/mr/stop/list).
#
# A "feature" = a directory under $FEATURES_ROOT (default ~/Code/and/alpha/features)
# containing one git worktree per touched repo, all on branch feat/<name>
# based off origin/dev. Feature lead agents + MRs to dev live here.
set -u

ALPHA_ROOT="${ALPHA_ROOT:-$HOME/Code/and/alpha}"
FEATURES_ROOT="${FEATURES_ROOT:-$ALPHA_ROOT/features}"
hdr="${HERDR_BIN_PATH:-herdr}"

json() { "$hdr" "$@" 2>/dev/null; }

feature_name_valid() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]]; }

feature_root() { printf '%s/%s' "$FEATURES_ROOT" "$1"; }

# Master (e2e-performance-tests) checkout — the orchestrator/knowledge hub that
# owns the shared plans/, docs/, .agents/ dirs.
E2E_MAIN="$ALPHA_ROOT/back-end/e2e-performance-tests"

# Symlink the master repo's knowledge dirs into a feature root so every feature
# workspace shares the canonical plans/, docs/, and .agents/skills/. Idempotent;
# warns on pre-existing real dirs and missing master dirs.
link_knowledge_dirs() {
  local root="$1" d
  for d in plans docs .agents; do
    if [ ! -e "$E2E_MAIN/$d" ]; then
      echo "  WARN: $E2E_MAIN/$d missing — skipping" >&2
      continue
    fi
    if [ -e "$root/$d" ] && [ ! -L "$root/$d" ]; then
      echo "  WARN: $root/$d exists and is not a symlink — leaving as-is" >&2
      continue
    fi
    ln -sfn "$E2E_MAIN/$d" "$root/$d"
    echo "  linked $d -> $E2E_MAIN/$d"
  done
}

# Standardized branch for a feature: feat/<name-lowercased>. Single source of
# truth so feature-start/mr/stop/list all match the same branch.
feature_branch() { printf 'feat/%s' "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"; }

# Resolve a repo argument (basename, alpha-relative path, or absolute path)
# to its git directory under $ALPHA_ROOT. Prints nothing on failure.
resolve_repo_dir() {
  local arg="$1" path matches count
  if [ -d "$arg/.git" ]; then printf '%s' "$arg"; return 0; fi
  if [[ "$arg" == */* ]]; then
    path="$ALPHA_ROOT/$arg"
    [ -d "$path/.git" ] && { printf '%s' "$path"; return 0; }
    return 1
  fi
  matches="$(find "$ALPHA_ROOT" -maxdepth 5 -type d -name .git 2>/dev/null | sed 's|/\.git$||' \
    | while read -r p; do [ "$(basename "$p")" = "$arg" ] && printf '%s\n' "$p"; done)"
  count="$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [ "$count" -eq 1 ]; then printf '%s' "$matches"; return 0; fi
  if [ "$count" -gt 1 ]; then
    printf 'ambiguous: "%s" matches multiple repos:\n%s\n' "$arg" "$matches" >&2
  fi
  return 1
}

# Base ref to branch a feature off: origin/dev -> dev -> origin/HEAD.
base_branch() {
  local dir="$1"
  if git -C "$dir" show-ref --verify --quiet refs/remotes/origin/dev; then printf 'origin/dev'; return 0; fi
  if git -C "$dir" show-ref --verify --quiet refs/heads/dev; then printf 'dev'; return 0; fi
  local def
  def="$(git -C "$dir" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')"
  [ -n "$def" ] && { printf 'origin/%s' "$def"; return 0; }
  return 1
}

# glab repo spec from a repo dir's origin remote (git@git.and.global:alpha/back-end/x.git)
glab_repo_of() {
  git -C "$1" remote get-url origin 2>/dev/null | sed -E 's|^[^:]+:||; s|\.git$||'
}

# pi session dir, deterministic per cwd (mirrors nvim lua/dis446/pi.lua);
# works for non-git dirs (feature roots) too.
pi_session_dir() {
  local root="$1" base name hash
  base="$HOME/.local/state/nvim/pi-sessions"
  name="$(basename "$root" | sed 's/[^[:alnum:]_.-]/_/g')"
  hash="$(printf '%s' "$root" | sha256sum | cut -c1-12)"
  mkdir -p "$base"
  printf '%s/%s-%s' "$base" "$name" "$hash"
}

# true if the last non-empty line of $1 ends with a shell prompt char
is_prompt() {
  local last
  last="$(printf '%s' "$1" | sed '/^[[:space:]]*$/d' | tail -1)"
  [ -n "$last" ] && printf '%s' "$last" | grep -qE '[$#>%][[:space:]]*$'
}

wait_prompt() {
  local pane="$1" tries="${2:-12}" i out
  for i in $(seq 1 "$tries"); do
    out="$(json pane read "$pane" --source detection --lines 8 2>/dev/null)"
    if is_prompt "$out"; then return 0; fi
    sleep 1
  done
  return 1
}

# extract .result.root_pane.pane_id from a herdr tab create response
root_pane_of() {
  printf '%s' "$1" | python3 -c "
import json, sys
try: d = json.load(sys.stdin)
except Exception: raise SystemExit
rp = d.get('result', {}).get('root_pane') or {}
print(rp.get('pane_id', '') or '')
"
}

# first pane id of a workspace
main_pane_of_ws() {
  json pane list --workspace "$1" | python3 -c "
import json, sys
try: d = json.load(sys.stdin)
except Exception: raise SystemExit
ps = d.get('result', {}).get('panes', [])
print(ps[0]['pane_id'] if ps else '')
"
}
