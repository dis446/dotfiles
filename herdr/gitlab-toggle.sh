#!/usr/bin/env bash
# Toggle the workspace GitLab TUI pane, bound to alt+g in herdr/config.toml.
#
# One glab-tui per herdr workspace, living in its own tab labeled "gitlab".
#   bring up:  focus the "gitlab" tab (creates it on first use, launches glab-tui)
#   dismiss:   focus the main tab
#
# herdr spawns custom shell commands detached with HERDR_ACTIVE_PANE_ID /
# HERDR_ACTIVE_WORKSPACE_ID set to the UI-focused pane; when invoked from
# nvim, the script falls back to HERDR_PANE_ID / HERDR_WORKSPACE_ID instead.
set -u

hdr="${HERDR_BIN_PATH:-herdr}"
focused="${HERDR_ACTIVE_PANE_ID:-${HERDR_PANE_ID:-}}"
ws="${HERDR_ACTIVE_WORKSPACE_ID:-${HERDR_WORKSPACE_ID:-}}"
[ -n "$focused" ] && [ -n "$ws" ] || exit 0

json() { "$hdr" "$@" 2>/dev/null; }

# Tab currently holding the focused pane
cur_tab="$(json pane get "$focused" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
print(d.get('result', {}).get('pane', {}).get('tab_id', ''))
")"
[ -n "$cur_tab" ] || exit 0

# The workspace's gitlab tab (label "gitlab")
gl_tab="$(json tab list --workspace "$ws" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
ws = '$ws'
print(next((t['tab_id'] for t in d.get('result', {}).get('tabs', [])
            if t.get('workspace_id') == ws and t.get('label') == 'gitlab'), ''))
")"

if [ -z "$gl_tab" ]; then
    # First use: create the gitlab tab (glab-tui in the focused pane's cwd)
    cwd="$(json pane get "$focused" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
print(d.get('result', {}).get('pane', {}).get('cwd', ''))
")"
    create_args=(tab create --workspace "$ws" --label gitlab --no-focus)
    [ -n "$cwd" ] && create_args+=(--cwd "$cwd")
    created="$(json "${create_args[@]}" 2>/dev/null)"
    root_pane="$(printf '%s' "$created" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
print(d.get('result', {}).get('root_pane', {}).get('pane_id', '') or '')
")"
    [ -n "$root_pane" ] || exit 0
    json pane run "$root_pane" "gitlab-tui" >/dev/null 2>&1
    gl_tab="$(printf '%s' "$created" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
print(d.get('result', {}).get('tab', {}).get('tab_id', ''))
")"
    [ -n "$gl_tab" ] || exit 0
    json tab focus "$gl_tab" >/dev/null 2>&1
    exit 0
fi

# Toggle: on the gitlab tab → back to main; anywhere else → open gitlab
if [ "$cur_tab" = "$gl_tab" ]; then
    main_tab="$(json tab list --workspace "$ws" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ws = '$ws'
print(next((t['tab_id'] for t in d.get('result', {}).get('tabs', [])
            if t.get('workspace_id') == ws and t.get('label') != 'gitlab'), ''))
")"
    [ -n "$main_tab" ] && json tab focus "$main_tab" >/dev/null 2>&1
else
    json tab focus "$gl_tab" >/dev/null 2>&1
fi
