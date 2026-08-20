#!/usr/bin/env bash
# Ensure every herdr workspace has its trio: nvim (main tab), pi, terminal.
#
# Runs automatically after the herdr server starts (systemd ExecStartPost in
# herdr/systemd/herdr-server.service), or manually at any time:
#   ~/dotfiles/herdr/restore.sh
#
# Per workspace, idempotently:
#   1. main tab (label != pi/term) -> launch `nvim .` if the pane is at a shell prompt
#   2. "term" tab -> create if missing (shell in the repo root)
#   3. "pi" tab   -> create if missing and start `pi -c --session-dir <dir>`
#                    (existing pi panes resume natively via herdr's integration)
set -u

hdr="${HERDR_BIN_PATH:-herdr}"
log="$HOME/.config/herdr/restore.log"

say() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$log"; }

# ---- wait for the server ----------------------------------------------
server_ready=""
for i in $(seq 1 90); do
  if "$hdr" status server >/dev/null 2>&1; then
    server_ready=1
    break
  fi
  sleep 1
done
[ -n "$server_ready" ] || { say "ERROR: herdr server not reachable after 90s"; exit 1; }

json() { "$hdr" "$@" 2>/dev/null; }

# ---- workspace ids -----------------------------------------------------
# A headless server (systemd boot) does not restore session.json workspaces
# until a client attaches (or restores asynchronously). Wait for them instead
# of bailing on the first empty poll — otherwise the boot run misses every
# workspace. If they never appear (no client attached in time), the user can
# re-run restore.sh later (herdr keybinding alt+r, or run it manually).
ws_ids=""
for i in $(seq 1 180); do
  ws_ids="$(json workspace list | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
for w in d.get('result', {}).get('workspaces', []):
    print(w.get('workspace_id', ''))
")"
  [ -n "$ws_ids" ] && break
  if [ $((i % 30)) -eq 0 ]; then say "  waiting for workspaces... (${i}s)"; fi
  sleep 1
done
if [ -z "$ws_ids" ]; then
  say "no workspaces after 180s (client not attached yet) — press alt+r in herdr or run: ~/dotfiles/herdr/restore.sh"
  exit 0
fi
say "workspaces restored: $(echo "$ws_ids" | tr '\n' ' ')"

# ---- helpers -----------------------------------------------------------
# true if the last non-empty line of $1 ends with a shell prompt char ($, #, >, %)
is_prompt() {
  local last
  last="$(printf '%s' "$1" | sed '/^[[:space:]]*$/d' | tail -1)"
  [ -n "$last" ] && printf '%s' "$last" | grep -qE '[$#>%][[:space:]]*$'
}

wait_prompt() {
  local pane="$1" tries="${2:-20}" i out
  for i in $(seq 1 "$tries"); do
    out="$(json pane read "$pane" --source detection --lines 8 2>/dev/null)"
    if is_prompt "$out"; then return 0; fi
    sleep 1
  done
  return 1
}

# pi session dir, mirroring nvim lua/dis446/pi.lua (deterministic per git root)
pi_session_dir() {
  local root="$1" base name hash
  base="$HOME/.local/state/nvim/pi-sessions"
  name="$(basename "$root" | sed 's/[^[:alnum:]_.-]/_/g')"
  hash="$(printf '%s' "$root" | sha256sum | cut -c1-12)"
  mkdir -p "$base"
  printf '%s/%s-%s' "$base" "$name" "$hash"
}

tabs_of()  { json tab list --workspace "$1"; }
panes_of() { json pane list --workspace "$1"; }

# ---- per workspace -----------------------------------------------------
for ws in $ws_ids; do
  tabs="$(tabs_of "$ws")"
  [ -n "$tabs" ] || continue

  ws_label="$(printf '%s' "$tabs" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ws = '$ws'
for t in d.get('result', {}).get('tabs', []):
    if t.get('workspace_id') == ws:
        print(t.get('label', '')); break
")"
  say "== workspace $ws ($ws_label)"

  # main tab: lowest-numbered tab that is not pi/term
  main_tab="$(printf '%s' "$tabs" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ws = '$ws'
cand = [t for t in d.get('result', {}).get('tabs', [])
        if t.get('workspace_id') == ws and t.get('label') not in ('pi', 'term')]
cand.sort(key=lambda t: t.get('number', 99))
print(cand[0]['tab_id'] if cand else '')
")"
  [ -n "$main_tab" ] || { say "  skip: no main tab"; continue; }

  panes="$(panes_of "$ws")"
  [ -n "$panes" ] || continue

  # main pane: first pane of the main tab, prefer one with a cwd
  main_pane="$(printf '%s' "$panes" | python3 -c "
import json, sys
d = json.load(sys.stdin)
tab = '$main_tab'
for p in d.get('result', {}).get('panes', []):
    if p.get('tab_id') == tab and p.get('cwd'):
        print(p['pane_id']); break
")"
  [ -n "$main_pane" ] || continue

  root="$(json pane get "$main_pane" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
print(d.get('result', {}).get('pane', {}).get('cwd', ''))
")"
  [ -n "$root" ] || root="$(printf '%s' "$panes" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(next((p['cwd'] for p in d.get('result', {}).get('panes', []) if p.get('cwd')), ''))
")"
  [ -n "$root" ] || { say "  skip: no cwd"; continue; }

  # 1. nvim in the main pane
  if wait_prompt "$main_pane" 20; then
    json pane run "$main_pane" "nvim ." >/dev/null 2>&1
    say "  nvim launched in $main_pane ($root)"
  else
    say "  nvim skipped: $main_pane not at a shell prompt"
  fi

  # git root (fall back to the pane cwd)
  git_root="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || echo "$root")"

  # 2. terminal tab
  term_tab="$(printf '%s' "$tabs" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ws = '$ws'
print(next((t['tab_id'] for t in d.get('result', {}).get('tabs', [])
            if t.get('workspace_id') == ws and t.get('label') == 'term'), ''))
")"
  if [ -z "$term_tab" ]; then
    json tab create --workspace "$ws" --label term --cwd "$git_root" --no-focus >/dev/null 2>&1 \
      && say "  created term tab ($git_root)" || say "  WARN: failed to create term tab"
  fi

  # 3. pi tab (existing pi panes resume natively on client attach)
  pi_tab="$(printf '%s' "$tabs" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ws = '$ws'
print(next((t['tab_id'] for t in d.get('result', {}).get('tabs', [])
            if t.get('workspace_id') == ws and t.get('label') == 'pi'), ''))
")"
  if [ -z "$pi_tab" ]; then
    created="$(json tab create --workspace "$ws" --label pi --cwd "$git_root" --no-focus 2>/dev/null)"
    pi_root="$(printf '%s' "$created" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
rp = d.get('result', {}).get('root_pane') or {}
print(rp.get('pane_id', '') or '')
")"
    if [ -n "$pi_root" ]; then
      sdir="$(pi_session_dir "$git_root")"
      json pane run "$pi_root" "pi -c --session-dir '$sdir'" >/dev/null 2>&1
      say "  started pi in $pi_root ($sdir)"
    else
      say "  WARN: failed to create pi tab"
    fi
  fi

  # 4. gitlab tab (gitlab-tui) — only when the workspace root is a real git repo
  if git -C "$root" rev-parse --show-toplevel >/dev/null 2>&1; then
    gl_tab="$(printf '%s' "$tabs" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ws = '$ws'
print(next((t['tab_id'] for t in d.get('result', {}).get('tabs', [])
            if t.get('workspace_id') == ws and t.get('label') == 'gitlab'), ''))
")"
    if [ -z "$gl_tab" ]; then
      created="$(json tab create --workspace "$ws" --label gitlab --cwd "$git_root" --no-focus 2>/dev/null)"
      gl_root="$(printf '%s' "$created" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
rp = d.get('result', {}).get('root_pane') or {}
print(rp.get('pane_id', '') or '')
")"
      if [ -n "$gl_root" ]; then
        wait_prompt "$gl_root" 8
        json pane run "$gl_root" "gitlab-tui" >/dev/null 2>&1
        say "  started gitlab-tui in $gl_root ($git_root)"
      else
        say "  WARN: failed to create gitlab tab"
      fi
    fi
  else
    say "  skip gitlab tab: not a git repo ($root)"
  fi
done

say "done"
