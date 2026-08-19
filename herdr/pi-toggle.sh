#!/usr/bin/env bash
# Toggle the pi agent pane inside herdr (bound to alt+k in herdr/config.toml).
#
# Collapse  (focused on the pi pane): park pi in its own "pi" tab — the agent
#           keeps running in the background; focus returns to the main tab.
# Expand    (anywhere else): forward alt+k to the focused pane. nvim's <M-k>
#           handler (lua/dis446/pi.lua) then opens pi in a new pane, or
#           focuses the existing pi pane (herdr agent focus switches tabs).
#
# herdr spawns custom shell commands detached with HERDR_ACTIVE_PANE_ID set to
# the UI-focused pane, HERDR_ACTIVE_WORKSPACE_ID, and HERDR_SOCKET_PATH.
set -u

hdr="${HERDR_BIN_PATH:-herdr}"
focused="${HERDR_ACTIVE_PANE_ID:-}"
ws="${HERDR_ACTIVE_WORKSPACE_ID:-}"
[ -n "$focused" ] && [ -n "$ws" ] || exit 0

# 1. Is the focused pane hosting a pi agent?
pi_pane="$("$hdr" agent list 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
focused = '$focused'
agents = d.get('result', {}).get('agents', [])
print(next((a['pane_id'] for a in agents
            if a.get('agent') == 'pi' and a.get('pane_id') == focused), ''))
")"
[ -n "$pi_pane" ] || {
    # Not on pi: forward the chord to the focused pane (nvim's <M-k> handles it).
    "$hdr" pane send-keys "$focused" alt+k >/dev/null 2>&1
    exit 0
}

# 2. Focused on pi → collapse. If pi is already parked in its "pi" tab, just
#    switch focus back to the main tab; otherwise move pi into a "pi" tab
#    (--no-focus keeps the UI on the main tab).
tabs_json="$("$hdr" tab list --workspace "$ws" 2>/dev/null)"
tab_id="$("$hdr" pane get "$pi_pane" 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
print(d.get('result', {}).get('pane', {}).get('tab_id', ''))
")"
[ -n "$tab_id" ] || exit 0

if [ -n "$tabs_json" ]; then
    is_parked="$(printf '%s' "$tabs_json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
tab = '$tab_id'
print('yes' if any(t.get('tab_id') == tab and t.get('label') == 'pi'
                   for t in d.get('result', {}).get('tabs', [])) else '')
")"
else
    is_parked=""
fi

if [ "$is_parked" = "yes" ]; then
    # Already parked: focus the main tab (the one that isn't "pi").
    main_tab="$(printf '%s' "$tabs_json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(next((t['tab_id'] for t in d.get('result', {}).get('tabs', [])
            if t.get('label') != 'pi'), ''))
")"
    [ -n "$main_tab" ] && "$hdr" tab focus "$main_tab" >/dev/null 2>&1
else
    "$hdr" pane move "$pi_pane" --new-tab --label pi --no-focus >/dev/null 2>&1
fi
