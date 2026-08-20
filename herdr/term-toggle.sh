#!/usr/bin/env bash
# Toggle the workspace terminal pane, bound to prefix+t in herdr/config.toml.
# (nvim's <leader>ot also routes here when HERDR_ENV=1.)
#
# One terminal per herdr workspace, living in its own tab labeled "term".
#   bring up:  focus the "term" tab (creates it on first use)
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

# The workspace's terminal tab (label "term")
term_tab="$(json tab list --workspace "$ws" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
ws = '$ws'
print(next((t['tab_id'] for t in d.get('result', {}).get('tabs', [])
            if t.get('workspace_id') == ws and t.get('label') == 'term'), ''))
")"

if [ -z "$term_tab" ]; then
    # First use: create the terminal tab (shell in the focused pane's cwd)
    cwd="$(json pane get "$focused" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
print(d.get('result', {}).get('pane', {}).get('cwd', ''))
")"
    create_args=(tab create --workspace "$ws" --label term --no-focus)
    [ -n "$cwd" ] && create_args+=(--cwd "$cwd")
    created="$(json "${create_args[@]}" 2>/dev/null)"
    term_tab="$(printf '%s' "$created" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
print(d.get('result', {}).get('tab', {}).get('tab_id', ''))
")"
    [ -n "$term_tab" ] || exit 0
    json tab focus "$term_tab" >/dev/null 2>&1
    exit 0
fi

# Toggle: on the terminal tab → back to main; anywhere else → open terminal
if [ "$cur_tab" = "$term_tab" ]; then
    main_tab="$(json tab list --workspace "$ws" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ws = '$ws'
print(next((t['tab_id'] for t in d.get('result', {}).get('tabs', [])
            if t.get('workspace_id') == ws and t.get('label') != 'term'), ''))
")"
    [ -n "$main_tab" ] && json tab focus "$main_tab" >/dev/null 2>&1
else
    json tab focus "$term_tab" >/dev/null 2>&1
fi
