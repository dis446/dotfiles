#!/usr/bin/env bash
# Ensure every herdr workspace has its core set: nvim (main tab) and a
# terminal tab. The pi agent tab is LAZY — pi agents are heavy (each ~200MB
# RSS), so they are NOT booted here; they
# start on first alt+k via pi-toggle.sh. Set RESTORE_PI=1 to boot them.
#
# Runs automatically after the herdr server starts (systemd ExecStartPost in
# herdr/systemd/herdr-server.service), or manually at any time:
#   ~/dotfiles/herdr/restore.sh
#
# Per workspace, idempotently:
#   1. main tab (label != pi/term) -> launch `nvim .` if the pane is at a shell prompt
#   2. "term" tab -> create if missing (shell in the repo root)
#   3. "pi" tab   -> only with RESTORE_PI=1: create if missing and start
#                    `pi -c` in the workspace's canonical root (otherwise
#                    left empty; existing pi panes resume natively via
#                    herdr's integration)
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
[ -n "$server_ready" ] || {
  say "ERROR: herdr server not reachable after 90s"
  exit 1
}

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

# Session root for a pane cwd: the feature root when inside a feature workspace
# (…/features/<name>/ or a worktree under it), else the git top-level. Feature
# roots now live INSIDE the e2e umbrella repo — plain `git rev-parse` would
# resolve to the umbrella repo and give every feature the same (wrong) root.
# Pi keys its sessions by the cwd it starts in, so every launcher must start pi
# with cwd = this canonical root and run plain `pi -c` (no --session-dir).
session_root() {
  local cwd="$1"
  if [[ "$cwd" =~ ^(.*/features/[^/]+)(/.*)?$ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  else
    git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd"
  fi
}

tabs_of() { json tab list --workspace "$1"; }
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

  # main pane: lowest-numbered non-pi/term tab whose first pane cwd is a real
  # project dir (skips leftover shells parked at $HOME, e.g. some older feature
  # workspaces whose first tab was never cd'd into the repo).
  panes="$(panes_of "$ws")"
  [ -n "$panes" ] || continue
  main_pane="$(printf '%s\n%s' "$tabs" "$panes" | HOME_DIR="$HOME" python3 -c "
import json, sys, os
tabs = json.loads(sys.stdin.readline())
panes = json.loads(sys.stdin.readline())
ws = '$ws'
home = os.environ['HOME_DIR']
label_of = {t['tab_id']: t.get('label') for t in tabs.get('result', {}).get('tabs', [])}
by_tab = {}
for p in panes.get('result', {}).get('panes', []):
    by_tab.setdefault(p.get('tab_id'), []).append(p)
cand = [t for t in tabs.get('result', {}).get('tabs', [])
        if t.get('workspace_id') == ws and label_of.get(t['tab_id']) not in ('pi', 'term')]
cand.sort(key=lambda t: t.get('number', 99))
for t in cand:
    for p in by_tab.get(t['tab_id'], []):
        cwd = p.get('cwd') or ''
        if cwd and cwd != home:
            print(p['pane_id']); sys.exit(0)
")"
  [ -n "$main_pane" ] || {
    say "  skip: no main pane"
    continue
  }

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
  [ -n "$root" ] || {
    say "  skip: no cwd"
    continue
  }

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
    json tab create --workspace "$ws" --label term --cwd "$git_root" --no-focus >/dev/null 2>&1 &&
      say "  created term tab ($git_root)" || say "  WARN: failed to create term tab"
  fi

  # 3. pi tab — LAZY by default: each pi agent costs ~200MB RSS plus a
  #    booting one per workspace is the dominant RAM cost after a reboot
  #    (~8GB for 40 workspaces). pi-toggle.sh (alt+k) already creates the
  #    tab and starts the agent on first use, so nothing is lost — agents
  #    just start on demand. Set RESTORE_PI=1 to boot them anyway.
  if [ "${RESTORE_PI:-0}" != "1" ]; then
    say "  pi tab skipped (lazy) — spawn on first alt+k"
  else
    pi_tab="$(printf '%s' "$tabs" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ws = '$ws'
print(next((t['tab_id'] for t in d.get('result', {}).get('tabs', [])
            if t.get('workspace_id') == ws and t.get('label') == 'pi'), ''))
")"
    if [ -z "$pi_tab" ]; then
      # Canonical root: feature root for feature workspaces, git top-level else.
      pi_cwd="$(session_root "$root")"
      created="$(json tab create --workspace "$ws" --label pi --cwd "$pi_cwd" --no-focus 2>/dev/null)"
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
        # Plain `pi -c`: default per-cwd store (keyed by $pi_cwd), resumes any
        # prior session for this project.
        json pane run "$pi_root" "pi -c" >/dev/null 2>&1
        say "  started pi in $pi_root (cwd $pi_cwd)"
      else
        say "  WARN: failed to create pi tab"
      fi
    fi
  fi

  # 4. gitlab tab (gitlab-tui) — only when gitlab-tui is installed AND the
  #    workspace root is a real git repo (gitlab-tui is optional; skip on
  #    machines where it's not installed, e.g. the home server)
  if command -v gitlab-tui >/dev/null 2>&1 && git -C "$root" rev-parse --show-toplevel >/dev/null 2>&1; then
    gl_tab="$(printf '%s' "$tabs" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ws = '$ws'
print(next((t['tab_id'] for t in d.get('result', {}).get('tabs', [])
            if t.get('workspace_id') == ws and t.get('label') == 'gitlab'), ''))
")"

    # Find the gitlab pane (existing tab or new)
    gl_pane=""
    if [ -n "$gl_tab" ]; then
      gl_pane="$(printf '%s' "$panes" | python3 -c "
import json, sys
d = json.load(sys.stdin)
tab = '$gl_tab'
for p in d.get('result', {}).get('panes', []):
    if p.get('tab_id') == tab:
        print(p.get('pane_id', '')); break
")"
      if [ -n "$gl_pane" ]; then
        # Check if gitlab-tui is already running inside the pane
        pg_out="$(json pane process-info --pane "$gl_pane" 2>/dev/null)"
        gl_running="$(printf '%s' "$pg_out" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
fps = d.get('result', {}).get('process_info', {}).get('foreground_processes', [])
cmd = ' '.join(p.get('cmdline','') for p in fps)
print('yes' if 'gitlab-tui' in cmd else 'no')
")"
        if [ "$gl_running" = "yes" ]; then
          say "  gitlab-tui already running in $gl_pane"
        else
          wait_prompt "$gl_pane" 8
          json pane run "$gl_pane" "gitlab-tui" >/dev/null 2>&1
          say "  started gitlab-tui in existing tab ($gl_pane)"
        fi
      fi
    else
      created="$(json tab create --workspace "$ws" --label gitlab --cwd "$git_root" --no-focus 2>/dev/null)"
      gl_pane="$(printf '%s' "$created" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
rp = d.get('result', {}).get('root_pane') or {}
print(rp.get('pane_id', '') or '')
")"
      if [ -n "$gl_pane" ]; then
        wait_prompt "$gl_pane" 8
        json pane run "$gl_pane" "gitlab-tui" >/dev/null 2>&1
        say "  started gitlab-tui in new tab ($gl_pane, $git_root)"
      else
        say "  WARN: failed to create gitlab tab"
      fi
    fi
  else
    say "  skip gitlab tab: gitlab-tui not installed or not a git repo ($root)"
  fi
done

say "done"
