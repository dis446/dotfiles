# Migrate this host to pi's single native session store (herdr + nvim + feature workflow)

You are an AI agent on THIS Fedora host (one of several machines that share the same dotfiles
repo, herdr setup, and alpha feature workflow). Perform the pi-session migration below so this
machine behaves exactly like typing `pi` / `pi -c` in a folder creates/resumes the same sessions
that herdr, nvim, and the feature-workflow spawners use. Verify each phase; stop and report on any
failure instead of guessing.

## Why / background

Pi stores each project's sessions in a per-cwd default store: `~/.pi/agent/sessions/--<cwd with
/ → ->--/`. `pi` starts a new session there, `pi -c` resumes the most recent one.

Older launchers (dotfiles `herdr/restore.sh`, `herdr/pi-toggle.sh`, `nvim` pi keybinding, and the
`scripts/feature-workflow/*` feature spawners) overrode this with
`pi -c --session-dir ~/.local/state/nvim/pi-sessions/<name>-<hash>/` — a SECOND, parallel store
that typing `pi` in a shell never reads. Sessions fragmented across the two stores; `/resume` in
one couldn't see the other.

**Target model (one standard):** every launcher starts pi with cwd = the canonical project root
(feature root for `…/features/<name>/` or a worktree under it, else the git top-level) and runs
plain `pi -c` — NO `--session-dir`. Sessions then live in the default per-cwd store and are
resumable from any plain shell.

## Phase 1 — confirm this host's state (audit first)

```bash
ls ~/.local/state/nvim/pi-sessions 2>/dev/null | wc -l      # >0 => legacy store in use here
ls ~/.pi/agent/sessions | wc -l                               # default store projects
grep -rn 'session-dir\|nvim/pi-sessions' ~/dotfiles/herdr/*.sh ~/dotfiles/nvim/lua/dis446/pi.lua 2>/dev/null   # leftover overrides
env | grep -E '^HERDR_' | sort                                # confirm running inside herdr
```

Report what you find before changing anything if the state differs from: legacy store present
with session files, and `--session-dir` still present in the launchers.

## Phase 2 — code changes (launchers must match the reference implementation)

The reference fix is already committed to the shared repos (this is the source of truth):

- dotfiles repo, branch `main`: commit `fix(herdr): pi sessions use native default store — plain
  'pi -c', no --session-dir` — changed `herdr/restore.sh`, `herdr/pi-toggle.sh`,
  `nvim/lua/dis446/pi.lua`.
- e2e-performance-tests repo, branch `disney`, commit `527506d0`
  `refactor(feature-workflow): pi sessions to native default store + migrate legacy nvim-store
  sessions` — changed `scripts/feature-workflow/{feature-lib.sh,feature-start,feature-respawn}`
  and ADDED `scripts/feature-workflow/migrate-sessions`.

If this host's checkouts can fetch those (git pull / fetch + cherry-pick the commit onto whatever
branch this host's working checkout is on), do that — but never leave the checkout on a branch it
wasn't on. If the repo states diverged, apply the equivalent change manually, matching the
reference exactly:

1. `restore.sh`: pi-tab spawn becomes plain `pi -c` from `session_root(main pane cwd)`; remove the
   `pi_session_dir` helper; main-pane picker must skip panes whose cwd == `$HOME`; keep
   `session_root` (feature root when cwd matches `^(.*/features/[^/]+)(/.*)?$`, else git
   top-level). Keep pi tabs LAZY (RESTORE_PI gate) — do not boot pi per workspace at restore.
2. `pi-toggle.sh` (alt+k first use): run `cd "<canonical root>" 2>/dev/null; pi -c` in the pi
   pane; remove `pi_session_dir`.
3. nvim `pi.lua`: `detect_root()` must return the feature root when the buffer/cwd is under
   `…/features/<name>/` BEFORE falling back to git top-level (feature worktrees have their own
   `.git`); launch `pi -c` (float and herdr-pane paths) with cwd = that root, no `--session-dir`.
4. feature-workflow `feature-lib.sh` / `feature-start` / `feature-respawn`: drop `--session-dir`
   (and the `pi_session_dir` helper); spawn `pi -c [--skill <repo-local feature-master>]`
   with the pi tab cwd = feature root.

Syntax-check every shell script (`bash -n`) and load-check the lua. Do NOT run restore.sh now
(it would launch nvim everywhere); it is exercised at the next reboot / alt+r.

## Phase 3 — migrate this host's existing sessions (one-time)

Use `scripts/feature-workflow/migrate-sessions` (from the e2e repo commit above) — it moves every
session file from `~/.local/state/nvim/pi-sessions/<name>-<hash>/` into the default store, keyed
by the cwd recorded in each session header, retargeting to the CURRENT feature root when a cwd
points at a deleted/old feature location. If that script is not available on this host,
reimplement its behavior: for each legacy dir, read the header `cwd` of the newest `.jsonl`,
`mv` all entries (files + `subagent-artifacts/`, incl. dotfiles) into
`~/.pi/agent/sessions/--<canonical cwd>--/`, merging shared dirs entry-wise and skipping
identical-name conflicts.

Hardcoded path caveat: the reference script encodes `OLD_FEATURES=/home/dubby/Code/and/alpha/
features` and `NEW_FEATURES=/home/dubby/Code/and/alpha/back-end/e2e-performance-tests/features`
— adjust both to THIS host's real layout/$HOME. Moving files under a running pi is safe (its fd
follows the inode) — do not kill processes for the move.

Run it `--dry-run` first, review every target key, then for real. Verify: zero session files left
under `~/.local/state/nvim/pi-sessions`, and each project's migrated files present under its
`--<cwd>--` key.

## Phase 4 — live cutover (restart the running feature/repo pi agents)

For each herdr workspace whose pi agent is currently running against the OLD (moved) path: confirm
the agent is idle, kill its pi pid, then relaunch plain `pi -c` in the SAME pane/tab (pane cwd
must be the canonical root). Skip any pi that is busy, and NEVER kill/relaunch the pi session that
is executing this task (you). After each relaunch verify via `herdr agent list` that the agent's
session file now sits under `~/.pi/agent/sessions/--<cwd>--/` with the SAME session filename as
before — that proves `pi -c` resumed the migrated history instead of starting a new one.

Repo workspaces whose pi you did NOT restart will pick up the moved sessions at their next natural
restart — that is fine.

## Phase 5 — cleanup + final verification

1. Only after everything above verifies: `rm -rf ~/.local/state/nvim/pi-sessions` (legacy store
   should be empty leftovers by now).
2. Final report: confirm (a) no `--session-dir` anywhere in the launchers, (b) `herdr agent list`
   shows feature/repo pi sessions under `~/.pi/agent/sessions/`, (c) `pi -c` in the e2e repo root
   resumes this machine's own conversation history. Recommend the user reboot to exercise the
   systemd herdr restore path (like the reference machine did) and then alt+k per workspace.

## Do NOT

- Do not delete anything from `~/.pi/agent/sessions/` (the default store) — it is the target.
- Do not run `~/dotfiles/herdr/restore.sh` live during this work (it launches nvim everywhere;
  wait for reboot/alt+r).
- Do not push branches you did not intend to; commit changes to the local checkout and report
  branch/push state.
- Do not touch the pi session that is running you, and don't fabricate "done" — verify each gate.
