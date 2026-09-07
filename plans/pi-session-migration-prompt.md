# Migrate THIS host's pi sessions to the single native store (herdr + nvim + feature workflow, ALL platforms)

You are an AI agent on THIS Fedora host (one of several machines sharing the same dotfiles repo,
herdr setup, and feature workflow). This host may run **one or more platforms**, each with its own
master repo and its own copy of the feature-workflow scripts. The known platforms are:

| Platform | Master repo (this machine's layout) | Feature-workspace label | Feature roots |
|---|---|---|---|
| alpha | `~/Code/and/alpha/back-end/e2e-performance-tests` | `alpha-<name>` | `<master>/features/<name>/` |
| gsim | `~/Code/gsim/globalSimConfig` | `gsim-<name>` | `<master>/features/<name>/` |

Your job: make this machine behave exactly like typing `pi` / `pi -c` in a folder creates/resumes
the same sessions that herdr, nvim, and the feature-workflow spawners use — **for every platform
present on this host**. Verify each phase; stop and report on any failure instead of guessing.

## Why / background

Pi stores each project's sessions in a per-cwd default store: `~/.pi/agent/sessions/--<cwd with
/ → ->--/`. `pi` starts a new session there, `pi -c` resumes the most recent one.

Older launchers overrode this with
`pi -c --session-dir ~/.local/state/nvim/pi-sessions/<name>-<hash>/` — a SECOND, parallel store
that typing `pi` in a shell never reads. This pattern existed in BOTH platforms' feature
workflows (the shared dotfiles launchers had it too, but are already fixed). Sessions fragmented
across two stores; `/resume` in one couldn't see the other.

**Target model (one standard):** every launcher starts pi with cwd = the canonical project root
(feature root for a cwd inside `…/features/<name>/`, else the git top-level) and runs plain
`pi -c` — NO `--session-dir`. Sessions then live in the default per-cwd store and are resumable
from any plain shell.

## Phase 1 — discover THIS host's platforms and audit

```bash
# locate every feature-workflow copy on the host (one per platform master repo)
find ~ -path '*/scripts/feature-workflow/feature-lib.sh' -not -path '*/node_modules/*' 2>/dev/null
# for each: is the legacy override still present?
grep -rn 'session-dir\|pi_session_dir\|nvim/pi-sessions' <master>/.pi <master>/scripts 2>/dev/null
# legacy store in use? default store size? herdr state?
ls ~/.local/state/nvim/pi-sessions 2>/dev/null | wc -l
ls ~/.pi/agent/sessions | wc -l
env | grep -E '^HERDR_' | sort
# in-flight features per platform: feature roots with BRIEF.md/worktrees
ls <master>/features 2>/dev/null
# open herdr workspaces + live pi agents (labels alpha-* / gsim-*)
~/.local/share/mise/installs/herdr/latest/herdr workspace list
~/.local/share/mise/installs/herdr/latest/herdr agent list
```

Report what you find before changing anything if the state differs from: legacy store present
with session files, and `--session-dir` still present in at least one platform's feature workflow.

## Phase 2 — code changes per platform (launchers + every feature-workflow copy)

Reference fixes already exist upstream — prefer pulling over reimplementing:

- **dotfiles repo, branch `main`** — SHARED launchers, fixed once for all platforms
  (commit `fix(herdr): pi sessions use native default store`): `herdr/restore.sh`,
  `herdr/pi-toggle.sh`, `nvim/lua/dis446/pi.lua`. Pull dotfiles `main`.
- **alpha** master e2e repo — commit `527506d0` (`refactor(feature-workflow): pi sessions to
  native default store…`) is on the `disney` working branch, NOT `dev`: changed
  `scripts/feature-workflow/{feature-lib.sh,feature-start,feature-respawn}` and ADDED
  `scripts/feature-workflow/migrate-sessions`. Fetch it (pull or cherry-pick onto this host's
  working branch — never leave the checkout on a branch it wasn't on).
- **gsim** master repo — commit `ee9cb9c` (`refactor(feature-workflow): pi sessions to native
  default store…`) is on gsim `main`: changed
  `scripts/feature-workflow/{feature-lib.sh,feature-start}`. Pull gsim `main`.

If a platform's copy diverged and you must apply the change manually, match the reference
exactly, per file:

1. `<master>/scripts/feature-workflow/feature-lib.sh`: DELETE the `pi_session_dir()` helper (the
   nvim-store formula); replace with a comment stating the default-store model.
2. `<master>/scripts/feature-workflow/feature-start`: the pi tab already gets created with
   `--cwd "$ROOT"` (the feature root); drop the `sdir="$(pi_session_dir "$ROOT")"` line and the
   `--session-dir '$sdir'` argument — spawn `pi -c [--skill <repo-local feature-master>] "<prompt>"`.
3. If the platform has `feature-respawn`: same change (drop `--session-dir`), so respawning
   resumes prior history.
4. Shared dotfiles launchers (only if dotfiles `main` can't be pulled):
   - `restore.sh`: pi-tab spawn becomes plain `pi -c` from `session_root(main pane cwd)`; remove
     the `pi_session_dir` helper; keep `session_root` (feature root when cwd matches
     `^(.*/features/[^/]+)(/.*)?$`, else git top-level); main-pane picker must skip panes whose
     cwd == `$HOME`; keep pi tabs LAZY (RESTORE_PI gate).
   - `pi-toggle.sh` (alt+k first use): run `cd "<canonical root>" 2>/dev/null; pi -c` in the pi
     pane; remove `pi_session_dir`.
   - nvim `pi.lua`: `detect_root()` must return the feature root when the buffer/cwd is under
     `…/features/<name>/` BEFORE falling back to git top-level (feature worktrees have their own
     `.git`); launch `pi -c` (float and herdr-pane paths) with cwd = that root, no `--session-dir`.

Syntax-check every shell script (`bash -n`), load-check the lua. Do NOT run restore.sh live now
(it would launch nvim everywhere); it is exercised at the next reboot / alt+r.

## Phase 3 — migrate THIS host's existing sessions (one pass covers every platform)

Use `scripts/feature-workflow/migrate-sessions` (from the alpha e2e repo, commit `527506d0`). It
moves every session file from `~/.local/state/nvim/pi-sessions/<name>-<hash>/` into the default
store, keyed by the cwd recorded in each session header. It is platform-agnostic: alpha sessions
land under their e2e feature-root keys, gsim sessions under their gsim feature-root keys — no
separate run per platform.

Caveats:

- The script hardcodes alpha layout constants `OLD_FEATURES=/home/dubby/Code/and/alpha/features`
  and `NEW_FEATURES=/home/dubby/Code/and/alpha/back-end/e2e-performance-tests/features`
  (used only to retarget alpha sessions recorded before alpha's feature roots moved inside the
  e2e repo). Adjust both to THIS host's real paths/$HOME. For gsim these constants never match
  (gsim's feature roots never moved) — a cwd recorded as a gsim feature root or a worktree
  subpath must still collapse to that feature root, so keep the "collapse any cwd under a
  platform's features tree to that feature root" rule (this is what the reference script does).
- If the script is unavailable on this host (e.g. no alpha repo present), reimplement its
  behavior: for each legacy dir under `~/.local/state/nvim/pi-sessions/`, read the header `cwd`
  of the newest `.jsonl`; collapse it to the feature root if it sits under any platform's
  `…/features/<name>/` tree; `mv` all entries (files + `subagent-artifacts/`, including
  dotfiles) into `~/.pi/agent/sessions/--<canonical cwd>--/`, merging shared dirs entry-wise and
  skipping identical-name conflicts.
- Moving files under a running pi is safe (its fd follows the inode) — do not kill processes for
  the move.

Run it `--dry-run` first, review every target key (alpha + gsim), then for real. Verify: zero
session files left under `~/.local/state/nvim/pi-sessions`, and each project's migrated files
present under its `--<cwd>--` key.

## Phase 4 — live cutover (workspaces that are OPEN)

For each herdr workspace whose pi agent is still running against the OLD (moved) path — labels
`alpha-<name>` AND `gsim-<name>` — confirm the agent is idle, kill its pi pid, then relaunch
plain `pi -c` in the SAME pane/tab (pane cwd must be the canonical feature root). Skip any pi
that is busy, and NEVER kill/relaunch the pi session that is executing this task (you). After
each relaunch verify via `herdr agent list` that the agent's session file now sits under
`~/.pi/agent/sessions/--<cwd>--/` with the SAME session filename as before — that proves `pi -c`
resumed the migrated history instead of starting a new one.

Repo workspaces whose pi you did NOT restart will pick up the moved sessions at their next
natural restart — that is fine.

## Phase 5 — reopen CLOSED workspaces of in-flight features (both platforms)

A feature can be in flight (root + BRIEF.md + worktrees exist, session history migrated in Phase
3) while its herdr workspace is closed. After Phase 3 those features' conversations are only
reachable if a workspace is re-created at the feature root running plain `pi -c`. For EACH
platform, find feature roots with BRIEF.md/worktrees that have no open workspace, and re-open:

- If the platform has `scripts/feature-workflow/feature-respawn` (alpha has it): use it.
- Otherwise (gsim does not have it), re-create the workspace directly:
  `herdr workspace create --cwd <feature root> --label <platform>-<name> --no-focus`, then add a
  pi tab (`herdr tab create --workspace <id> --label pi --cwd <feature root> --no-focus`) and run
  plain `pi -c` in it (optionally term/nvim tabs per worktree, mirroring feature-start's layout).
  Verify via `herdr agent list` that the resumed session file sits under the default store with
  the pre-existing filename.

Only do this for features that are genuinely in flight — a root whose BRIEF is a placeholder
`<one-line summary>` with no worktrees/commits is a dead scaffold, not in flight; leave it and
report it.

## Phase 6 — cleanup + final verification

1. Only after everything above verifies: `rm -rf ~/.local/state/nvim/pi-sessions` (should be
   empty leftovers by then).
2. Final report: confirm (a) no `--session-dir`/`pi_session_dir` anywhere in the dotfiles
   launchers OR any platform's feature-workflow, (b) `herdr agent list` shows feature/repo pi
   sessions for BOTH platforms under `~/.pi/agent/sessions/`, (c) `pi -c` in each platform's
   master repo root resumes that machine's own conversation history for that platform.
   Recommend the user reboot to exercise the systemd herdr restore path, then alt+k per workspace.

## Do NOT

- Do not delete anything from `~/.pi/agent/sessions/` (the default store) — it is the target.
- Do not assume only one platform exists: every feature-workflow copy found in Phase 1 must be
  fixed; every `alpha-*`/`gsim-*` workspace and feature root must be handled.
- Do not run `~/dotfiles/herdr/restore.sh` live during this work (it launches nvim everywhere;
  wait for reboot/alt+r).
- Do not commit one repo's changes from another, or `git add` across repo boundaries; respect
  each repo's own git discipline (alpha: glab/MRs toward `dev`; gsim: gh/PRs toward `main`).
  Commit per repo and report branch/push state.
- Do not touch the pi session that is running you, and don't fabricate "done" — verify each gate.
