# Neovim Workflow

> Context for AI agents. Describes how the user organises code repos, runs
> Neovim, and navigates between projects.

## Overview

The user runs **one herdr workspace per project (repo)**, and each workspace
contains the standard set: **Neovim** (main tab), a **pi agent** pane (pi
tab), a **terminal** (term tab), and a **GitLab TUI** pane (gitlab tab). herdr
is the terminal multiplexer — workspaces, tabs, panes, and agents all live in
herdr. Neovim is launched inside the workspace's main tab; the pi agent, the
workspace terminal, and the GitLab TUI are herdr panes that nvim routes to
(`<M-k>` / `<leader>ot`) or that you toggle with `alt+k` / `alt+i` / `alt+g`.

```
┌────────────────────────────────────────────────────┐
│ herdr workspace "state-machine"                    │
│  tab 1 (main):  nvim                               │
│  tab pi:        pi agent  (alt+k toggles)          │
│  tab term:      shell / lazygit  (alt+i toggles)   │
│  tab gitlab:    gitlab-tui  (alt+g toggles)          │
│                                                    │
│  ┌─────────────┬───────────────────────────────┐   │
│  │ main        │ pi / term / gitlab (toggles)  │   │
│  └─────────────┴───────────────────────────────┘   │
└────────────────────────────────────────────────────┘
```

herdr is mouse-native (click panes/tabs/workspaces) and keyboard-driven. The
prefix key is `ctrl+b`.

## Herdr Workspaces = Code Repos

Each code repo gets its own herdr workspace. Workspaces are persistent: the
headless herdr server keeps every workspace (and its panes) running between
TUI sessions.

### Current workspaces

| Workspace               | Repository / context                      |
| ----------------------- | ----------------------------------------- |
| `dotfiles`              | `~/dotfiles` — personal dotfiles          |
| `e2e-performance-tests` | alpha master repo (diagnostics, planning) |
| `relationStore`         | `back-end/relationStore`                  |
| `state-machine`         | `back-end/state-machine`                  |
| `middleware`            | `front-end/formio/middleware`             |

### Keybindings

| Key                     | Action                                   |
| ----------------------- | ---------------------------------------- |
| `prefix+w`              | Workspace navigation (switch workspaces) |
| `prefix+g`              | Goto picker                              |
| `prefix+c`              | New tab                                  |
| `prefix+v` / `prefix+-` | Split right / down                       |
| `prefix+h/j/k/l`        | Move between panes                       |
| `prefix+b`              | Toggle sidebar (agents list)             |
| `prefix+shift+n/w/d`    | New / rename / close workspace           |
| `prefix+q`              | Detach (everything keeps running)        |
| `alt+k`                 | Toggle the pi agent pane (pi tab)        |
| `alt+i`                 | Toggle the workspace terminal (term tab) |
| `alt+g`                 | Toggle the GitLab TUI pane (gitlab tab)  |
| `alt+r`                 | Re-run the boot restore (nvim + term; pi agents stay lazy) |

`alt+k`/`alt+i`/`alt+g`/`alt+r` are herdr-level keybindings wired to
`herdr/pi-toggle.sh` / `herdr/term-toggle.sh` / `herdr/gitlab-toggle.sh` /
`herdr/restore.sh` (park the pane in its own tab; the agent keeps running
while hidden). When focus is inside nvim, the same chords route through nvim's
`<M-k>` / `<leader>ot` handlers instead (see below). `alt+r` re-runs the boot
restore — use it after attaching if the boot-time run missed the workspaces.

The Agent sidebar (`prefix+b`) shows every pi agent across all workspaces with
live state (working / idle / blocked), so you can monitor multiple concurrent
agents in real time.

## Inside Neovim: The Full Stack

One Neovim instance runs in the workspace's main tab. Everything else lives
inside Neovim or in the workspace's herdr panes:

### File navigation

| Action              | Key          |
| ------------------- | ------------ |
| File explorer       | `<leader>ee` |
| Reveal current file | `<leader>ef` |
| Find file           | `<leader>ff` |
| Recent files        | `<leader>fr` |
| Grep (text search)  | `<leader>fs` |
| Grep word at cursor | `<leader>fc` |

All powered by `Snacks.picker()`. The explorer is a sidebar (0.66 width, no
preview). File pickers exclude `node_modules/`, `.next/`, `.turbo/`,
`.venv/`, `target/`, `build/`, `dist/`, `.nx/`.

### Editing layout

Neovim panes (splits) for side-by-side editing of related files:

| Keys                | Action               |
| ------------------- | -------------------- |
| `<C-w>s`            | Split horizontal     |
| `<C-w>v`            | Split vertical       |
| `<C-w>h/j/k/l`      | Move between panes   |
| `<C-w>c` / `<C-w>o` | Close / close others |

Neovim tabs aren't used as OS-style tabs. Instead, **bufferline.nvim** provides
a tab bar at the top showing open buffers:

| Keys              | Action               |
| ----------------- | -------------------- |
| `<M-h>` / `<M-l>` | Previous/next buffer |
| `<leader>tw`      | Close buffer         |
| `<leader>to`      | Close other buffers  |
| `<leader>t1-9`    | Go to buffer 1-9     |

This is the primary way to switch between files within a project.

### Terminal (herdr term tab, Snacks fallback)

The workspace has **one terminal** in its own `term` tab (herdr-managed). From
nvim, `<leader>ot` toggles it:

| Key          | In herdr (`HERDR_ENV=1`)  | Outside herdr       |
| ------------ | ------------------------- | ------------------- |
| `<leader>ot` | Toggle the herdr term tab | Snacks bottom split |
| `<M-k>`      | Focus the herdr pi pane   | Snacks float (pi)   |

Common uses in the workspace terminal:

- Running build/watch commands (e.g., `npm run dev`, `./mvnw quarkus:dev`)
- Git operations outside lazygit
- Running tests
- Quick shell commands

### GitLab TUI (gitlab-tui)

Every workspace has a **gitlab-tui** pane in its own `gitlab` tab — the GitLab
web UI in your terminal with **native vim keybindings** and keyboard-first
navigation:

```bash
alt+g          # toggle the gitlab tab (herdr-level, works from any pane)
```

```
j/k        scroll lists          n/p    next/prev page or comment
Tab/1-7    switch tabs           e      edit MR / issue
Enter      open detail           c      create MR / issue
r          refresh               x      close    O  reopen
S          switch server         P      switch project
s          state filter          a      approve   m  merge
p          pipelines             +/−    vote up/down    q  quit
```

gitlab-tui auto-detects the workspace's project from the `origin` remote of
the repo root (SSH remotes included) and authenticates with the token in
`~/.config/gitlab-tui/config.json` (git.and.global server; configured by
`fedora/install.sh` from `$GITLAB_TOKEN`). Covers MRs, pipelines, issues,
branches, tags, and the container registry.

### LazyGit (git TUI)

Integrated git workflow via `Snacks.lazygit()` — a full TUI opened in a Neovim
tab:

```bash
<leader>lg     # Open LazyGit
```

All common git operations (commit, push, pull, branch, diff, log, stash) happen
here. No git CLI from the terminal for day-to-day work.

### Pi coding agent

AI coding assistant integrated via `pi.lua` (`dis446.pi`). Inside herdr, pi
runs as a **real herdr pane** (workspace `pi` tab); outside herdr it falls back
to a floating Snacks terminal:

```bash
<M-k>          # herdr: focus/split the pi pane   outside herdr: float
alt+k          # herdr-level: toggle the pi tab (works even from a shell pane)
```

Pi auto-detects the git root of the current file (or falls back to `cwd`) and
creates per-repo session data under
`~/.local/state/nvim/pi-sessions/<repo-name>-<hash>/`. The same deterministic
session dir is used by the boot restore, so pi resumes the same session after a
server restart.

### Sessions (auto-session)

**auto-session.nvim** saves/restores Neovim state per directory:

- **Auto-restore** when opening Neovim in a project directory (`nvim .`)
- **Auto-save** on exit
- Suppressed for `~/`, `~/Dev/`, `~/Downloads/`, etc. — only restores in actual
  project directories
- After restore, lazy plugins and LSP clients are re-attached automatically

### Build / run tasks (overseer.nvim)

| Keys         | Action                 |
| ------------ | ---------------------- |
| `<leader>mm` | Run task               |
| `<leader>mr` | Rerun last task        |
| `<leader>mk` | Task actions           |
| `<leader>m,` | Toggle task list panel |

A task list + output panel opens at the bottom when a task runs, showing status
and live output.

### Debugging (DAP)

Debugging uses `nvim-dap` with adapters via Mason:

| Keys              | Action               |
| ----------------- | -------------------- |
| `<leader>rd` / F5 | Start / continue     |
| F10               | Step over            |
| F11               | Step into            |
| `<leader>dt`      | Toggle breakpoint    |
| `<leader>du`      | Toggle DAP UI panels |

For Quarkus projects: JVM remote attach on port 5005 (standard Quarkus dev
mode).

## Project Switch Workflow

1. **Switch workspace:** `prefix+w` (or the goto picker `prefix+g`), pick the
   workspace — the server kept it running, so panes are already alive
2. **Neovim is still running** in the main tab (no restart needed)
3. **auto-session restores** buffer list, cursor positions, and window layout
4. **LSP re-attaches** automatically via `post_restore` hook
5. **Start working:** `<leader>ff` to find files, `<leader>fs` to grep, etc.

No need to manually start Neovim, reopen files, or restart language servers
when coming back to a project. `prefix+q` detaches (leaves everything running);
the Agent sidebar shows pi agents across all workspaces at a glance.

## Boot Flow (after system reboot)

```
systemd (user login)
  ├─ herdr-server.service (headless server)
  │    └─ ExecStartPost: restore.sh — waits for the server to restore its
  │         session workspaces (headless server does this once a client
  │         attaches, so restore.sh polls up to 180s; if no client attached
  │         in time, press alt+r after attaching to re-run it)
  │              └─ per workspace, ensures the set:
  │                   ├─ main tab  -> nvim .  (opens empty — auto-session is
  │                   │               disabled, so no buffers/LSP at boot)
  │                   ├─ term tab  -> shell in the repo root
  │                   └─ pi tab    -> LEFT EMPTY (lazy). Each pi agent costs
  │                       ~200MB RSS plus a tsserver (~400-700MB) that pi-lens
  │                       spawns, so booting one per workspace is ~16GB across
  │                       40 workspaces. Spawn on demand with alt+k (pi-toggle.sh
  │                       reuses the restored empty tab). Set RESTORE_PI=1 on the
  │                       restore.sh run to boot them anyway.
  └─ user opens a terminal -> `herdr` (TUI client attaches)
       └─ workspaces restore from session.json
```

Workspace/panel topology (cwd, tab labels, pane layout) persists in herdr's
session file. Pi sessions persist in `~/.local/state/nvim/pi-sessions/` and
resume natively when the agent is started (alt+k). Neovim instances are
re-launched by `restore.sh` and open empty — buffers/LSP come up when you
actually open files in that workspace.

## Constraints to Remember

- **One workspace per repo:** never open files from different repos in the same
  Neovim instance
- **One terminal per workspace:** the herdr `term` tab — no extra shell panes
- **One GitLab TUI per workspace:** the herdr `gitlab` tab (`alt+g`) — repo
  context auto-detected from the workspace root
- **Pi lives in its herdr pane:** `<M-k>` / `alt+k` focuses it; agents keep
  running when the tab is hidden (monitor via the Agent sidebar)
- **LazyGit is the git interface:** the git CLI is rarely used directly
- **herdr is the multiplexer:** everything terminal-related lives in herdr
  workspaces/tabs/panes — nothing else is used for session management
