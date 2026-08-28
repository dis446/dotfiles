#!/usr/bin/env bash
# Shared helpers for the platform-2 feature workflow (feature-start/mr/stop/list).
#
# A "feature" = a directory under $FEATURES_ROOT (default
# ~/Code/platform-2/platform-2/features) containing one git worktree per touched
# repo, all on branch feat/<name> based off origin/main. Feature lead agents +
# PRs to main live here.
#
# platform-2: GitHub (gh CLI), default branch main. Repos live under the plain
# folder ~/Code/platform-2; the master orchestrator repo is platform-2
# (dev umbrella + AI harness + knowledge base).
set -u

PLATFORM2="${PLATFORM2:-$HOME/Code/platform-2}"
FEATURES_ROOT="${FEATURES_ROOT:-$PLATFORM2/platform-2/features}"
hdr="${HERDR_BIN_PATH:-herdr}"

json() { "$hdr" "$@" 2>/dev/null; }

feature_name_valid() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]]; }

feature_root() { printf '%s/%s' "$FEATURES_ROOT" "$1"; }

# Umbrella root — repos live here. The orchestrator/knowledge hub is the
# platform-2 repo: plans/, docs/ under ITS features/ dir are the shared
# knowledge base (a real git repo on GitHub — plans/docs get committed+ pushed
# there, unlike the umbrella root which is NOT a git repo).
PLATFORM2="$PLATFORM2/platform-2"

# Symlink the knowledge hub's dirs into a feature root so every feature
# workspace shares the canonical plans/ and docs/ (both under
# platform-2/features/) plus the master's .agents/skills/. Idempotent;
# warns on pre-existing real dirs and missing hub dirs.
link_knowledge_dirs() {
  local root="$1" d src
  for d in plans docs; do
    src="$PLATFORM2/features/$d"
    mkdir -p "$src"
    if [ -e "$root/$d" ] && [ ! -L "$root/$d" ]; then
      echo "  WARN: $root/$d exists and is not a symlink — leaving as-is" >&2
      continue
    fi
    ln -sfn "$src" "$root/$d"
    echo "  linked $d -> $src"
  done
  if [ -e "$PLATFORM2/.agents" ]; then
    if [ -e "$root/.agents" ] && [ ! -L "$root/.agents" ]; then
      echo "  WARN: $root/.agents exists and is not a symlink — leaving as-is" >&2
    else
      ln -sfn "$PLATFORM2/.agents" "$root/.agents"
      echo "  linked .agents -> $PLATFORM2/.agents"
    fi
  fi
}

# Standardized branch for a feature: feat/<name-lowercased>. Single source of
# truth so feature-start/mr/stop/list all match the same branch.
feature_branch() { printf 'feat/%s' "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"; }

# Resolve a repo argument (basename, platform-2-relative path, or absolute path)
# to its git directory under $PLATFORM2. Prints nothing on failure.
resolve_repo_dir() {
  local arg="$1" path matches count
  if [ -d "$arg/.git" ]; then printf '%s' "$arg"; return 0; fi
  if [[ "$arg" == */* ]]; then
    path="$PLATFORM2/$arg"
    [ -d "$path/.git" ] && { printf '%s' "$path"; return 0; }
    return 1
  fi
  matches="$(find "$PLATFORM2" -maxdepth 5 -type d -name .git 2>/dev/null | sed 's|/\.git$||' \
    | while read -r p; do [ "$(basename "$p")" = "$arg" ] && printf '%s\n' "$p"; done)"
  count="$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [ "$count" -eq 1 ]; then printf '%s' "$matches"; return 0; fi
  if [ "$count" -gt 1 ]; then
    printf 'ambiguous: "%s" matches multiple repos:\n%s\n' "$arg" "$matches" >&2
  fi
  return 1
}

# Base ref to branch a feature off: origin/main -> main -> origin/HEAD.
# PRs target main (the platform-2 default); dev branches exist but are not the
# integration target.
base_branch() {
  local dir="$1"
  if git -C "$dir" show-ref --verify --quiet refs/remotes/origin/main; then printf 'origin/main'; return 0; fi
  if git -C "$dir" show-ref --verify --quiet refs/heads/main; then printf 'main'; return 0; fi
  local def
  def="$(git -C "$dir" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')"
  [ -n "$def" ] && { printf 'origin/%s' "$def"; return 0; }
  return 1
}

# gh repo spec from a repo dir's origin remote
# (git@github.com:platform-2/x.git or https://github.com/platform-2/x.git -> platform-2/x)
gh_repo_of() {
  git -C "$1" remote get-url origin 2>/dev/null \
    | sed -E 's|^git@[^:]+:|https://github.com/|; s|^https?://[^/]+/||; s|\.git$||'
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
