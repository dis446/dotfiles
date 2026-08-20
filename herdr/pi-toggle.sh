#!/usr/bin/env bash
# Toggle the pi agent pane inside herdr (bound to alt+k in herdr/config.toml).
#
# Pure focus toggle, identical model to term-toggle.sh / gitlab-toggle.sh —
# works from ANY pane (nvim, gitlab-tui, shells, anywhere):
#   bring up:  focus the "pi" tab (creates it on first use and spawns
#              `pi -c --session-dir <dir>` in it)
#   dismiss:   focus the main tab
#
# herdr spawns custom shell commands detached with HERDR_ACTIVE_PANE_ID set to
# the UI-focused pane, HERDR_ACTIVE_WORKSPACE_ID, and HERDR_SOCKET_PATH.
set -u

hdr="${HERDR_BIN_PATH:-herdr}"
focused="${HERDR_ACTIVE_PANE_ID:-${HERDR_PANE_ID:-}}"
ws="${HERDR_ACTIVE_WORKSPACE_ID:-${HERDR_WORKSPACE_ID:-}}"
[ -n "$focused" ] && [ -n "$ws" ] || exit 0

json() { "$hdr" "$@" 2>/dev/null; }

# The workspace's pi agent pane (if any)
pi_pane="$("$hdr" agent list 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
ws = '$ws'
agents = d.get('result', {}).get('agents', [])
print(next((a['pane_id'] for a in agents
            if a.get('agent') == 'pi' and a.get('workspace_id') == ws), ''))
")"

# pi session dir, deterministic per repo root (mirrors nvim lua/dis446/pi.lua)
pi_session_dir() {
  local root="$1" base name hash
  base="$HOME/.local/state/nvim/pi-sessions"
  name="$(basename "$root" | sed 's/[^[:alnum:]_.-]/_/g')"
  hash="$(printf '%s' "$root" | sha256sum | cut -c1-12)"
  mkdir -p "$base"
  printf '%s/%s-%s' "$base" "$name" "$hash"
}

tab_id_of_pane() {
  json pane get "$1" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
print(d.get('result', {}).get('pane', {}).get('tab_id', ''))
"
}

focus_tab() {
  [ -n "$1" ] && json tab focus "$1" >/dev/null 2>&1
}

if [ -z "$pi_pane" ]; then
  # ---- first use: create the pi tab (spawn pi in the focused pane's repo root)
  cwd="$(json pane get "$focused" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
print(d.get('result', {}).get('pane', {}).get('cwd', ''))
")"
  root="$cwd"
  [ -n "$cwd" ] && root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "$cwd")"
  created="$(json tab create --workspace "$ws" --label pi --cwd "$root" --no-focus 2>/dev/null)"
  rp="$(printf '%s' "$created" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
rp = d.get('result', {}).get('root_pane') or {}
print(rp.get('pane_id', '') or '')
")"
  [ -n "$rp" ] || exit 0
  sdir="$(pi_session_dir "$root")"
  json pane run "$rp" "pi -c --session-dir '$sdir'" >/dev/null 2>&1
  focus_tab "$(printf '%s' "$created" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
print(d.get('result', {}).get('tab', {}).get('tab_id', ''))
")"
  exit 0
fi

pi_tab="$(tab_id_of_pane "$pi_pane")"
[ -n "$pi_tab" ] || exit 0

# Is pi parked in a tab labeled "pi"?
parked="$(json tab list --workspace "$ws" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
ws = '$ws'
tab = '$pi_tab'
print('yes' if any(t.get('tab_id') == tab and t.get('label') == 'pi'
                   for t in d.get('result', {}).get('tabs', [])
                   if t.get('workspace_id') == ws) else '')
")"

if [ "$parked" != "yes" ]; then
  # Pi lives in a regular tab (e.g. nvim split) → park it in a "pi" tab, focus it
  json pane move "$pi_pane" --new-tab --label pi --no-focus >/dev/null 2>&1
  focus_tab "$(tab_id_of_pane "$pi_pane")"
  exit 0
fi

# Toggle: on the pi tab → back to main; anywhere else → open pi
cur_tab="$(tab_id_of_pane "$focused")"
if [ "$cur_tab" = "$pi_tab" ]; then
  main_tab="$(json tab list --workspace "$ws" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ws = '$ws'
print(next((t['tab_id'] for t in d.get('result', {}).get('tabs', [])
            if t.get('workspace_id') == ws and t.get('label') != 'pi'), ''))
")"
  focus_tab "$main_tab"
else
  focus_tab "$pi_tab"
fi
