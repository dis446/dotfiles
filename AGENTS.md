# AGENTS.md

## Project Overview

Personal dotfiles repo for Tsetsen-erdene Ganbaatar (dis446). Manages cross-platform shell config, editor configs, and tooling across Fedora/Nobara, macOS, and Ubuntu. The repo lives at `~/dotfiles` — paths are hardcoded to `$HOME/dotfiles` throughout setup scripts.

**Key technologies:** Bash, Neovim (Lua/lazy.nvim), herdr, zellij, ghostty, zed, IntelliJ IdeaVim, lazygit, mise (node/java), pi-coding-agent.

## Directory Layout

| Path                                      | Symlinked to         | Purpose                                                |
| ----------------------------------------- | -------------------- | ------------------------------------------------------ |
| `bash/`                                   | (sourced)            | Cross-platform shell aliases, split by topic           |
| `features/`                               | (invoked)            | Alpha feature workflow: worktrees per repo + MRs to dev |
| `fedora/`, `nobara/`, `macos/`, `ubuntu/` | (per OS)             | OS-specific aliases, bashrc, install scripts           |
| `nvim/`                                   | `~/.config/nvim`     | Neovim config (Lua, lazy.nvim)                         |
| `herdr/`                                  | `~/.config/herdr`    | herdr workspaces, toggles, boot restore (see WORKFLOW.md) |
| `ghostty/`                                | `~/.config/ghostty`  | Ghostty terminal config (linux/ + macos/ variants)     |
| `zellij/`                                 | `~/.config/zellij`   | Zellij multiplexer config                              |
| `zed/`                                    | `~/.config/zed`      | Zed editor config + themes                             |
| `lazygit/`                                | `~/.config/lazygit`  | lazygit config                                         |
| `intellij/`                               | `~/.ideavimrc`       | IdeaVim config + keymap references                     |
| `pi/`                                     | `~/.pi`, `~/.agents` | pi-coding-agent config                                 |
| `claude/`                                 | `~/.claude`          | Claude Code config (settings tracked, runtime ignored) |
| `hyprland/`                               | (not symlinked)      | Hyprland WM config (waybar, scripts)                   |
| `k8s/`                                    | (not symlinked)      | Kubernetes cheatsheet                                  |
| `WindowsPowerShell/`                      | (not symlinked)      | PowerShell profile aliases                             |

## Setup Commands

**Run the appropriate install script for your OS:**

| OS     | Command             | What it does                                                                      |
| ------ | ------------------- | --------------------------------------------------------------------------------- |
| Fedora | `fedora/install.sh` | Full: COPR repos, dnf packages, symlinks, mise tools, zed, flatpaks |
| Nobara | `nobara/install.sh` | Symlinks + dnf packages (uses nobara-sync)                         |
| macOS  | `macos/install.sh`  | Symlinks + homebrew deps via `macos/Brewfile`                       |
| Ubuntu | `ubuntu/install.sh` | Symlinks + apt packages                                                |

Example:

```bash
cd ~/dotfiles
./fedora/install.sh       # Fedora full setup
./macos/install.sh        # macOS symlinks only (brew bundle first)
```

All install scripts are **idempotent** — they use `rm -rf "$dest"` before `ln -s "$src"`, so re-running is safe.

### What install scripts do (omitting OS-specific package mgmt)

1. Create `~/.config/` and ghostty dir
2. Symlink individual config dirs (nvim, herdr, zellij, zed, ghostty, pi, claude, .editorconfig)
3. Symlink OS-specific shell rc file → `~/.bashrc` (or `~/.zshrc` on macOS, `~/.bash_aliases` on Ubuntu)
4. Symlink OS-specific shell rc file → `~/.bashrc` (or `~/.zshrc` on macOS, `~/.bash_aliases` on Ubuntu)
5. Source the shell rc
6. Install packages (dnf, mise, npm, cargo, flatpak, etc.)
7. Set git global config (user, email, pull.rebase)

### Manual steps after first setup

```bash
# In Neovim, install plugins
nvim --headless "+Lazy! sync" +qa

# Open herdr once to attach (headless server + restore.sh handle the rest)
herdr
```

## Shell Alias Architecture

Per-OS bashrc/zshrc files all follow the same pattern:

```bash
# Source all shared aliases
for alias_file in "$HOME/dotfiles/bash/"*; do
  [ -f "$alias_file" ] && . "$alias_file"
done
# Then source OS-specific aliases (overrides)
[ -f "$HOME/dotfiles/fedora/bash_aliases" ] && . "$HOME/dotfiles/fedora/bash_aliases"
```

# Cross-platform aliases go in `bash/` (one file per topic): `git_aliases`, `docker_aliases`, `herdr_aliases`, `feature_aliases`, `general_aliases`, etc

- **OS-specific overrides** go in the OS dir (e.g., `fedora/bash_aliases`)
- **Secrets** go in `bash/secret_aliases` (gitignored via `**/secret` pattern)
- After editing any alias file, re-source: `src` (alias for `source ~/.bashrc`)

**Key shell aliases:**

- `dtf` → `cd ~/dotfiles`
- `src` → `source ~/.bashrc`
- `v` → `nvim`
- `c` → `cat`, `b` → `bat`

## Development Workflow

### Editing config

```bash
dtf                          # jump to dotfiles root
v bash/git_aliases           # edit an alias file
src                          # re-source to pick up changes
```

### Applying changes after config edit

```bash
# Neovim: config reloads automatically via lazy.nvim
nvim ~/.config/nvim

# herdr: reload config
herdr server reload-config
# or prefix + b (sidebar) → reload config

# Shell: re-source
src  # alias for source ~/.bashrc

# Ghostty: restart the terminal app

# Zed: settings auto-reload on save
```

### Testing Neovim config

```bash
# Lint check (nvim validates on startup)
nvim --headless -c "checkhealth" -c "qa"

# Test plugin sync
nvim --headless "+Lazy! sync" +qa

# Test specific plugin health
nvim --headless -c "checkhealth lazy" -c "qa"
```

## Neovim Config

Lua-based, uses [lazy.nvim](https://github.com/folke/lazy.nvim). Namespaced under `lua/dis446/`.

### Structure

```
nvim/
├── init.lua                    # Entry: loads core → lazy
├── lazy-lock.json              # Pinned plugin versions (keep committed)
├── lua/dis446/
│   ├── core/
│   │   ├── init.lua            # Core loader
│   │   ├── options.lua         # Editor options
│   │   └── keymaps.lua         # Global keymaps
│   ├── lazy.lua                # lazy.nvim bootstrap + config
│   └── plugins/                # One file per plugin
│       ├── init.lua            # plenary.nvim
│       ├── blink.lua           # Completion engine
│       ├── snacks.lua          # Snacks.nvim (picker, dashboard, etc.)
│       ├── treesitter.lua      # Treesitter parsers
│       ├── lsp/                # LSP config
│       │   ├── lspconfig.lua   # LSP servers
│       │   ├── mason.lua       # Mason installer
│       │   ├── lazydev.lua     # LuaLS dev
│       │   └── jdtls.lua       # Java JDTLS
│       ├── dap.lua             # Debug adapter protocol
│       ├── formatting.lua      # conform.nvim
│       ├── linting.lua         # nvim-lint
│       ├── bufferline.lua      # Tab/buffer line
│       ├── lualine.lua         # Statusline
│       ├── auto-session.lua    # Session management
│       └── ...                 # + colorscheme, gitsigns, which-key, etc.
├── CHEATSHEET.md               # Full keymap reference
├── UNIFIED-KEYBINDS.md         # Cross-editor keybinds (Neovim + IdeaVim)
├── DBEE-PLAN.md                # DBee database connections plan
└── REVIEW-2026.md              # Config review notes
```

### Common tasks

```bash
# Add a new plugin: create lua/dis446/plugins/<name>.lua
# Install plugin without restart
nvim "+Lazy install <plugin-name>" +qa

# Update all plugins
nvim "+Lazy update" +qa

# Check plugin status
nvim "+Lazy" +qa

# Run healthchecks
nvim -c "checkhealth" -c "qa"
```

### Unified keybindings

`nvim/UNIFIED-KEYBINDS.md` is the canonical reference. Same muscle memory works across both Neovim and IntelliJ IdeaVim.

## herdr Config

Terminal multiplexer (replaced tmux). One herdr workspace per repo, each with
nvim (main tab), pi agent (pi tab), terminal (term tab), GitLab TUI (gitlab
tab). Headless server via `herdr/systemd/herdr-server.service`;
`herdr/restore.sh` (ExecStartPost, or `alt+r`) ensures every workspace has
nvim + a term tab — the **pi agent tab is lazy** (each agent costs ~200MB RSS
, ~8GB across 40 workspaces, so agents start on
first `alt+k` via `pi-toggle.sh`; set `RESTORE_PI=1` to boot them).
`herdr/pi-toggle.sh` / `term-toggle.sh` / `gitlab-toggle.sh` back the
`alt+k` / `alt+i` / `alt+g` keybindings. Full workflow: `nvim/WORKFLOW.md`.

## Code Style Guidelines

### Bash

- One topic per file in `bash/` directory
- No `set -e` in install scripts (intentional)
- `rm -rf "$dest"` before `ln -s "$src"` for idempotency
- Use `link_target()` helper from install scripts

### Lua (Neovim)

- One file per plugin under `lua/dis446/plugins/`
- Namespace under `dis446.` prefix
- lazy.nvim spec tables with `opts`, `config`, `keys`, `cmd`, `event` fields
- Non-lazy imports handled via `dis446.core`

### Git

- Conventions set in install scripts: `pull.rebase true`
- No specific commit format required

## Build and Deployment

**No build step** — this is a config repo. Changes are live after re-sourcing the shell or reloading the editor config.

### What is tracked vs ignored

See `.gitignore` for full details. Key patterns:

| Path                                   | Tracked?                                 | Notes                                                    |
| -------------------------------------- | ---------------------------------------- | -------------------------------------------------------- |
| `claude/settings.json`                 | Tracked                                  | Whitelist approach: ignore all, re-include managed files |
| `claude/sessions/`, `claude/projects/` | Ignored                                  | Runtime state                                            |
| `intellij/`                            | Ignored (except `ideavimrc`, `keymaps/`) | Settings Sync for rest                                   |
| `bash/secret_aliases`                  | Ignored                                  | Via `**/secret` pattern                                  |
| `pi/agent/sessions`, `pi/agent/bin/`   | Ignored                                  | Runtime state                                            |

### Cross-machine sync

- **Canonical source:** This repo (`~/dotfiles`)
- **Mechanism:** Clone on new machine, run OS-specific install script
- **IntelliJ:** JetBrains Settings Sync for keymaps/codestyles
- **Claude Code:** Tracked settings + hook/command/agent/skill config; runtime ignored
- **pi/context-mode:** Agent runtime state ignored; config tracked

## herdr Persistence Troubleshooting

### Workspaces/panes didn't come back after reboot

```bash
# 1. Is the headless server running?
systemctl --user status herdr-server.service

# 2. Did restore.sh ensure nvim + term tabs (pi agents are lazy)?
tail -30 ~/.config/herdr/restore.log

# 3. Workspaces missing? The headless server restores session.json only once
#    a client attaches — press alt+r in herdr (or run ~/dotfiles/herdr/restore.sh)
#    to re-run the restore. pi agents: spawn per workspace with alt+k.

# 4. Server log for restore/attach events
less ~/.config/herdr/herdr-server.log
```

## Feature Workflow (alpha master repo)

`features/` scripts orchestrate concurrent alpha features: one feature = `~/Code/and/alpha/back-end/e2e-performance-tests/features/<name>/` containing a git worktree per touched repo (branch `feat/<name>` off `origin/dev`) + `BRIEF.md` (line 1 = MR title). `feature-start` also opens a herdr workspace (nvim tab per repo, pi feature-lead tab, term tab) and spawns the feature-lead agent. Aliases: `fstart`/`fmr`/`fstop`/`flist`. In the master repo's pi session, `/feature-start <name>` (name required + unique) creates the feature and spawns the feature-lead pi with the global `feature-master` skill (`pi/agent/skills/feature-master/`) — prompt it with requirements and it discovers repos, creates worktrees, spawns sub-agents, and opens MRs to dev. Full operating pattern lives in `e2e-performance-tests/AGENTS.md`; the pi tools/commands (`feature_start`, `/feature-start`, …) are a repo-local extension in that repo's `.pi/extensions/`.

## Additional Notes

### Important paths reference

| Tool               | Config location                        | Notes                                    |
| ------------------ | -------------------------------------- | ---------------------------------------- |
| Neovim             | `~/.config/nvim/` (`nvim/`)            | lazy.nvim manages plugins                |
| herdr             | `~/.config/herdr/` (`herdr/`)          | Workspaces, toggles, boot restore       |
| Zellij             | `~/.config/zellij/` (`zellij/`)        |                                          |
| Ghostty            | `~/.config/ghostty/` (`ghostty/`)      | Linux/macOS variant files                |
| Zed                | `~/.config/zed/` (`zed/`)              |                                          |
| lazygit            | `~/.config/lazygit/config.yml`         |                                          |
| IntelliJ IdeaVim   | `~/.ideavimrc` (`intellij/ideavimrc`)  |                                          |
| Claude Code        | `~/.claude/` (`claude/`)               | Runtime state ignored                    |
| pi-coding-agent    | `~/.pi/`, `~/.agents/` (`pi/`)         |                                          |
| .editorconfig      | `~/.editorconfig`                      |                                          |
| Bash aliases       | `~/dotfiles/bash/*` (sourced by OS rc) | See Shell Alias Architecture             |
| Windows PowerShell | `WindowsPowerShell/*.ps1`              | Mirrors bash alias structure for Windows |

### Git config (set by install scripts)

```ini
[user]
  email = dis446@yahoo.com
  name = Tsetsen-erdene Ganbaatar
[pull]
  rebase = true
```
