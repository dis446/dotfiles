# Neovim Workflow

> Context for AI agents. Describes how the user organises code repos, runs
> Neovim, and navigates between projects.

## Overview

The user runs **one Neovim instance per project**, each in its own **tmux
session**. All terminal work (shell, lazygit, pi agent) happens **inside
Neovim** via `Snacks.terminal()`. No tmux panes, no tmux tabs — just one
terminal window per session, running Neovim.

```
┌────────────────────────────────────────────────┐
│ tmux session "gSim"     (1 window, 1 pane)     │
│ ┌────────────────────────────────────────────┐ │
│ │  Neovim                                    │ │
│ │  ┌──────┬────────────────┬──────────────┐  │ │
│ │  │expl. │  source.ts     │  test.ts     │  │ │
│ │  │      │                │              │  │ │
│ │  │      │                │              │  │ │
│ │  ├──────┴────────────────┴──────────────┤  │ │
│ │  │ terminal (Snacks, lazygit, or shell) │  │ │
│ │  └──────────────────────────────────────┘  │ │
│ └────────────────────────────────────────────┘ │
└────────────────────────────────────────────────┘
```

## Tmux Sessions = Code Repos

Each code repo gets its own tmux session. Sessions are created/attached with:

```bash
t <name>     # alias: tmux new-session -A -s <name>
ts <name>    # alias: tmux new -s <name>
tl           # list sessions
ta <name>    # attach to session
tk <name>    # kill session
```

### Current sessions (as of 2026-07-19)

| Session       | Repository / context                          |
|---------------|-----------------------------------------------|
| `dotfiles`    | `~/dotfiles` — personal dotfiles (attached)   |
| `gSim`        | gSim monorepo / core service                  |
| `gSimClient`  | gSim client service                           |
| `gSimConfig`  | gSim config service                           |
| `gSimNaut`    | gSim Naut service                             |
| `gSimSales`   | gSim Sales service                            |
| `gSimWeb`     | gSim Web service                              |
| `home`        | `~` — home directory                          |
| `middleware`  | Middleware project                            |
| `vpn`         | VPN management                                |

Tmux session names match repo directory names. Session switching uses
`prefix + s` (filterable `choose-tree`), and `prefix + (`/`)` cycles prev/next.

When restoring after reboot, `tmux-continuum` auto-saves every 15 minutes and
restores on server start. Systemd user service handles auto-start on login.

## Inside Neovim: The Full Stack

One Neovim instance runs in the single tmux pane. Everything else lives inside
Neovim:

### File navigation

| Action               | Key               |
|----------------------|-------------------|
| File explorer        | `<leader>ee`      |
| Reveal current file  | `<leader>ef`      |
| Find file            | `<leader>ff`      |
| Recent files         | `<leader>fr`      |
| Grep (text search)   | `<leader>fs`      |
| Grep word at cursor  | `<leader>fc`      |

All powered by `Snacks.picker()`. The explorer is a sidebar (0.66 width, no
preview). File pickers exclude `node_modules/`, `.next/`, `.turbo/`,
`.venv/`, `target/`, `build/`, `dist/`, `.nx/`.

### Editing layout

Neovim panes (splits) for side-by-side editing of related files:

| Keys                  | Action               |
|-----------------------|----------------------|
| `<C-w>s`              | Split horizontal     |
| `<C-w>v`              | Split vertical       |
| `<C-w>h/j/k/l`        | Move between panes   |
| `<C-w>c` / `<C-w>o`  | Close / close others |

Neovim tabs aren't used as OS-style tabs. Instead, **bufferline.nvim** provides
a tab bar at the top showing open buffers:

| Keys              | Action              |
|-------------------|---------------------|
| `<M-h>` / `<M-l>` | Previous/next buffer|
| `<leader>tw`      | Close buffer        |
| `<leader>to`      | Close other buffers |
| `<leader>t1-9`    | Go to buffer 1-9    |

This is the primary way to switch between files within a project.

### Terminal (Snacks)

All terminal access goes through `Snacks.terminal()` — never outside Neovim.

| Key               | Terminal              |
|-------------------|-----------------------|
| `<leader>ot`      | Toggle bottom split   |
| `<leader>oT`      | Floating terminal     |

Common uses inside the snack terminal:
- Running build/watch commands (e.g., `npm run dev`, `./mvnw quarkus:dev`)
- Git operations outside lazygit
- Running tests
- Quick shell commands

### LazyGit (git TUI)

Integrated git workflow via `Snacks.lazygit()` — a full TUI opened in a Neovim
tab:

```bash
<leader>lg     # Open LazyGit
```

All common git operations (commit, push, pull, branch, diff, log, stash) happen
here. No git CLI from the terminal for day-to-day work.

### Pi coding agent

AI coding assistant integrated via `pi.lua` (`dis446.pi`). Opens a floating
Snacks terminal running `pi -c` in the repo's git root:

```bash
<M-k>          # Toggle Pi in floating window
```

Pi auto-detects the git root of the current file (or falls back to `cwd`) and
creates per-repo session data under
`~/.local/state/nvim/pi-sessions/<repo-name>-<hash>/`.

### Sessions (auto-session)

**auto-session.nvim** saves/restores Neovim state per directory:
- **Auto-restore** when opening Neovim in a project directory (`nvim .`)
- **Auto-save** on exit
- Suppressed for `~/`, `~/Dev/`, `~/Downloads/`, etc. — only restores in actual
  project directories
- After restore, lazy plugins and LSP clients are re-attached automatically

### Build / run tasks (overseer.nvim)

| Keys               | Action                  |
|--------------------|-------------------------|
| `<leader>mm`       | Run task                |
| `<leader>mr`       | Rerun last task         |
| `<leader>mk`       | Task actions            |
| `<leader>m,`       | Toggle task list panel  |

A task list + output panel opens at the bottom when a task runs, showing status
and live output.

### Debugging (DAP)

Debugging uses `nvim-dap` with adapters via Mason:

| Keys               | Action                  |
|--------------------|-------------------------|
| `<leader>rd` / F5  | Start / continue        |
| F10                | Step over               |
| F11                | Step into               |
| `<leader>dt`       | Toggle breakpoint       |
| `<leader>du`       | Toggle DAP UI panels    |

For Quarkus projects: JVM remote attach on port 5005 (standard Quarkus dev
mode).

## Project Switch Workflow

1. **Switch tmux session:** `prefix + s` (type to filter, Enter)
2. **Session is ready:** tmux-resurrect restored it, continuum restarted Neovim
3. **auto-session restores** buffer list, cursor positions, and window layout
4. **LSP re-attaches** automatically via `post_restore` hook
5. **Start working:** `<leader>ff` to find files, `<leader>fs` to grep, etc.

No need to manually start Neovim, reopen files, or restart language servers
when coming back to a project.

## Boot Flow (after system reboot)

```
systemd (user login)
  └─ tmux server (continuum boot)
       ├─ tmux-resurrect restores all sessions
       │    └─ each session: 1 window, 1 pane
       │         └─ neovim starts (auto-restore)  ← continuum's @resurrect-strategy-vim 'session'
       │              └─ auto-session restores buffers
       │              └─ LSP re-attaches
       └─ continuum auto-save timer starts (every 15 min)
```

Persistent Neovim sessions are handled by `tmux-resurrect`'s vim strategy (not
auto-session) — continuum triggers `nvim --headless -c "SessionRestore"` via
resurrect's saved vim session file.

Auto-session handles fine-grained buffer/window layout within the running
Neovim instance (daily saves on exit). Resurrect/continuum handles the
cross-reboot persistence of the tmux + Neovim state.

## Constraints to Remember

- **One terminal per session:** no tmux panes, no tmux tabs, no second tmux
  window — just the single Neovim instance
- **One repo per session:** never open files from different repos in the same
  Neovim instance
- **LazyGit is the git interface:** the git CLI is rarely used directly
- **Pi runs inside Neovim:** `Alt+K` opens the pi agent in a floating terminal
  inside the current Neovim instance, sharing the repo context
