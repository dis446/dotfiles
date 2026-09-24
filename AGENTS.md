# AGENTS.md

## Project Overview

Personal dotfiles repo for Tsetsen-erdene Ganbaatar (dis446). Manages cross-platform shell config, editor configs, and tooling across Fedora/Nobara, macOS, and Ubuntu. The repo lives at `~/dotfiles` — the flake and the out-of-store symlinks bake that absolute path.

**The environment is Nix + Home Manager.** `flake.nix` pins nixpkgs + home-manager and declares the CLI tools, runtimes, shell, git config, and config links; `flake.lock` makes machines reproducible. The OS install scripts are **system-only** (RPM Fusion, `dnf.conf`, zram, flatpak, systemd). See "Nix / Home Manager" below and `plans/nix-migration-plan.md`.

**Key technologies:** Nix flakes, Home Manager, Bash, Neovim (Lua/lazy.nvim), herdr, zellij, ghostty, zed, IntelliJ IdeaVim, lazygit, mise (per-repo version overrides only), pi-coding-agent.

## Directory Layout

| Path | Managed by | Purpose |
| ---- | ---------- | ------- |
| `flake.nix`, `flake.lock` | — | Nix inputs + pinned versions (`flake.lock` is committed) |
| `home/` | Home Manager | `home/*.nix` modules: packages, dotfile links, bash, git, npm global, herdr unit |
| `scripts/` | — | `nix-*` helpers + `e2e-nix-container.sh`; `check-identifiers.sh` |
| `bash/` | Home Manager (sourced) | Cross-platform shell aliases, split by topic |
| `fedora/`, `nobara/`, `macos/`, `ubuntu/` | system-only | OS-specific aliases, bashrc, system install scripts |
| `nvim/` | HM link → `~/.config/nvim` | Neovim config (Lua, lazy.nvim) |
| `herdr/` | HM link + `home/herdr.nix` | herdr config + systemd unit, toggles, boot restore (see WORKFLOW.md) |
| `ghostty/` | HM link → `~/.config/ghostty` | Ghostty terminal config (linux/ + macos/ variants) |
| `zellij/` | HM link → `~/.config/zellij` | Zellij multiplexer config |
| `zed/` | HM file links → `~/.config/zed` | Zed editor config + themes |
| `lazygit/` | HM link → `~/.config/lazygit` | lazygit config |
| `gradle/` | HM link → `~/.gradle/gradle.properties` | Gradle worker/heap limits (concurrency budget) |
| `intellij/` | HM link → `~/.ideavimrc` | IdeaVim config + keymap references |
| `pi/` | install.sh → `~/.pi`, `~/.agents` | pi-coding-agent config (runtime state ignored) |
| `claude/` | install.sh → `~/.claude` | Claude Code config (settings tracked, runtime ignored) |
| `hyprland/`, `k8s/`, `WindowsPowerShell/` | (not linked) | WM config, k8s cheatsheet, PowerShell aliases |

## Setup Commands

**Fresh machine (Linux):**

```bash
# 1. Nix (Determinate multi-user installer)
curl -fsSL https://install.determinate.systems/nix | sh -s -- install

# 2. Clone to the baked path
git clone git@github.com:dis446/dotfiles.git ~/dotfiles

# 3. System-level setup (RPM Fusion, dnf.conf, zram, flatpak, systemd)
./fedora/install.sh          # or nobara/install.sh / ubuntu/install.sh

# 4. Apply the Nix environment (tools + config + shell + herdr unit)
home-manager switch --flake ~/dotfiles#guddy@fedora   # or guddy@nobara / guddy@ubuntu
```

`macos/install.sh` + `macos/Brewfile` are the macOS track (see `plans/nix-migration-plan.md` §10).

**Daily commands** (also the `nix-update` / `nix-pull` / `nix-cleanup` / `nix-e2e` aliases):

| Command | Does |
| ------- | ---- |
| `home-manager switch --flake ~/dotfiles#guddy@<platform>` | apply `.nix` changes |
| `nix-update` | `nix flake update` → `flake check` → switch → bump pi → commit `flake.lock` |
| `nix-pull` | pull; tells you to rebuild if `.nix`/`flake.lock` changed |
| `nix-cleanup` | GC old generations + `nix store optimise` |
| `nix-e2e` | boot the flake from scratch in a throwaway Fedora container |

Install scripts are **idempotent** — `rm -rf "$dest"` before `ln -s "$src"`.

### What the install scripts do (system-only)

1. RPM Fusion, `dnf.conf`, zram, `mpv-libs`, flatpak GUI apps (Fedora/Nobara)
2. Symlink the imperative agent configs (`pi`, `.ai`, `claude`)
3. `git config core.hooksPath .githooks` (identifier pre-commit hook)

Everything else — CLI tools, runtimes, shell rc, git identity, and the editor/multiplexer configs — is Home Manager.

### Manual steps after first setup

```bash
# In Neovim, install plugins (lazy.nvim bootstraps on first launch)
nvim --headless "+Lazy! sync" +qa

# Open herdr once to attach (headless server + restore.sh handle the rest)
herdr
```

## Nix / Home Manager

- `flake.nix` — inputs (`nixpkgs-unstable`, `home-manager`) and a `hosts` map (fedora/nobara/ubuntu → `{ username, role, platform, system }`) plus `homeConfigurations."guddy@<platform>"`. `role` (`work`/`personal`) gates packages; `mkHome` asserts membership. One flake, shared `home/` modules.
- `home/` — one concern per file:
  - `packages.nix` — CLI tools + runtimes; role-gated extras (`azure-cli`, `glab`, `gh` for `work`).
  - `dotfiles.nix` — `mkOutOfStoreSymlink` links for nvim, zellij, ghostty, lazygit, herdr config, zed, `.editorconfig`, `.ideavimrc`, gradle. **Never** `source = ./dir` — that copies into the read-only store and breaks files the app rewrites (`lazy-lock.json`).
  - `bash.nix` — HM owns `~/.bashrc`; sources `$HOME/dotfiles/<platform>/bashrc` (or `bash/*` + `<platform>/bash_aliases` on Ubuntu). Do **not** also symlink `~/.bashrc` in install scripts.
  - `git.nix` — git identity via XDG `~/.config/git/config`; the work identity lives in untracked `~/.gitconfig-local` (included).
  - `npm-globals.nix` — the pi agent binary (npm global, prefix `~/.local`; env var, never `npm config set`).
  - `herdr.nix` — `systemd.user.services.herdr-server` (Linux only).
- **Reproducibility:** `flake.lock` is committed; versions move only on `nix flake update` (`nix-update`). `scripts/e2e-nix-container.sh` boots the whole thing in a fresh container and asserts the result (`E2E_DISTRO=fedora|ubuntu`).
- **mise is for per-repo overrides only** (a `.mise.toml` in a project). Nix owns the global Node/Java/etc. — do not `mise use -g`.
- **GUI apps on Linux are wrapped with nixGL** (`nixGL` flake input; `targets.genericLinux.nixGL` in `home/default.nix`, `config.lib.nixGL.wrap` in `home/packages.nix`). Nix mesa can't init EGL on non-NixOS, so nix GL apps (ghostty) fail with `Failed to create EGL display` without the wrapper.
- **Outside Nix (by design):** RPM Fusion / `dnf.conf` / zram / flatpak GUI apps (system), the pi agent binary (npm), `pi`/`claude` runtime state, `bash/secret_aliases` and other `secret*` files, nvim's mason LSP servers, and mise-managed per-repo toolchains.

## Shell Alias Architecture

Home Manager generates `~/.bashrc` (`home/bash.nix`) and sources the OS rc from it, so the alias files stay the single source and remain editable without a rebuild. Per-OS bashrc/zshrc files follow the same pattern:

```bash
# Source all shared aliases
for alias_file in "$HOME/dotfiles/bash/"*; do
  [ -f "$alias_file" ] && . "$alias_file"
done
# Then source OS-specific aliases (overrides)
[ -f "$HOME/dotfiles/fedora/bash_aliases" ] && . "$HOME/dotfiles/fedora/bash_aliases"
```

# Cross-platform aliases go in `bash/` (one file per topic): `git_aliases`, `docker_aliases`, `herdr_aliases`, `general_aliases`, etc

- **OS-specific overrides** go in the OS dir (e.g., `fedora/bash_aliases`)
- **Secrets** go in `bash/secret_aliases` (gitignored via `**/secret` pattern)
- After editing any alias file, re-source: `src` (alias for `source ~/.bashrc`)

**Key shell aliases:**

- `dtf` → `cd ~/dotfiles`
- `src` → `source ~/.bashrc`
- `v` → `nvim`
- `c` → `cat`, `b` → `bat`
- `nix-update` / `nix-pull` / `nix-cleanup` / `nix-e2e` → `scripts/nix-*.sh` / `e2e-nix-container.sh`

## Development Workflow

### Nix changes

```bash
dtf
v home/packages.nix                                    # add a tool / edit a module
home-manager switch --flake ~/dotfiles#guddy@fedora    # apply
# or: nix-update (also bumps flake inputs)
```

Editing files under `bash/`, `nvim/`, `zed/`, `herdr/`, … needs **no rebuild** — they are out-of-store symlinks. A rebuild is only needed for `.nix` changes (or when adding/removing a top-level link).

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
tab). The binary comes from Nix; the headless server is declared in
`home/herdr.nix` (`systemd.user.services.herdr-server`, applied by
`home-manager switch`). `herdr/restore.sh` (ExecStartPost, or `alt+r`) ensures
every workspace has nvim + a term tab — the **pi agent tab is lazy** (each
agent costs ~200MB RSS, ~8GB across 40 workspaces, so agents start on
first `alt+k` via `pi-toggle.sh`; set `RESTORE_PI=1` to boot them).
`herdr/pi-toggle.sh` / `term-toggle.sh` / `gitlab-toggle.sh` back the
`alt+k` / `alt+i` / `alt+g` keybindings. Full workflow: `nvim/WORKFLOW.md`.

## Code Style Guidelines

### Bash

- One topic per file in `bash/` directory
- No `set -e` in install scripts (intentional)
- `rm -rf "$dest"` before `ln -s "$src"` for idempotency
- Use `link_target()` helper from install scripts

### Nix

- One concern per file under `home/`; namespace nothing, import via `home/default.nix`
- Config dirs use `mkOutOfStoreSymlink` (live edits); plain `source` copies into the store
- Prefer `lib.mkIf pkgs.stdenv.isLinux` for Linux-only modules (systemd)
- Role-gate packages with `lib.optionals (role == "...")`; never branch on hostname
- Run `nix flake check ~/dotfiles` (or `nix-e2e`) before switching

### Lua (Neovim)

- One file per plugin under `lua/dis446/plugins/`
- Namespace under `dis446.` prefix
- lazy.nvim spec tables with `opts`, `config`, `keys`, `cmd`, `event` fields
- Non-lazy imports handled via `dis446.core`

### Git

- Identity set by Home Manager (`home/git.nix`); `pull.rebase = true`
- No specific commit format required

## Build and Deployment

**No build step** — this is a config repo. Config edits are live (out-of-store links); `.nix` changes apply with `home-manager switch` (or `nix-update`).

### What is tracked vs ignored

See `.gitignore` for full details. Key patterns:

| Path                                   | Tracked?                                 | Notes                                                    |
| -------------------------------------- | ---------------------------------------- | -------------------------------------------------------- |
| `claude/settings.json`                 | Tracked                                  | Whitelist approach: ignore all, re-include managed files |
| `claude/sessions/`, `claude/projects/` | Ignored                                  | Runtime state                                            |
| `intellij/`                            | Ignored (except `ideavimrc`, `keymaps/`) | Settings Sync for rest                                   |
| `bash/secret_aliases`                  | Ignored                                  | Via `**/secret` pattern                                  |
| `pi/agent/sessions`, `pi/agent/bin/`   | Ignored                                  | Runtime state                                            |
| `result`, `result-*`                   | Ignored                                  | Nix build symlinks                                       |

### Cross-machine sync

- **Canonical source:** This repo (`~/dotfiles`)
- **Mechanism:** clone to `~/dotfiles`, install Nix, run the OS install script, then `home-manager switch --flake .#guddy@<platform>` — `flake.lock` reproduces the toolchain
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

If the unit is missing, it comes from `home/herdr.nix` — run
`home-manager switch --flake ~/dotfiles#guddy@<platform>`.

## Identifier hygiene

The repo is public: employer/client identifiers (internal hosts, client/tenant
names, internal repo names, employer emails) must never be committed. They live
in untracked `secret*` files (gitignored via `**/secret**`) or env vars
(`GITLAB_HOST`, `ARGOCD_BASE_URL`, …).

- `scripts/check-identifiers.sh` greps everything that would be committed and
  fails on a raw identifier (generic English "middleware" is exempt — only
  path/table contexts are checked).
- Wired as a pre-commit hook via `core.hooksPath .githooks` — set by
  `git config core.hooksPath .githooks` after cloning (install scripts do this).
- The work git identity is an untracked `~/.gitconfig-local` include, never a
  tracked `.nix` value.
- This repo pins `user.email` locally (`git config user.email`); keep it personal.

## Feature Workflow (platform master repos)

The feature workflow lives entirely inside each platform's master repo — the
dotfiles repo has no involvement:

| Platform  | Master repo                                   | Platform root        |
| --------- | --------------------------------------------- | -------------------- |
| platform-1 | `~/Code/<org>/<platform-1>/repo-1`            | `~/Code/<org>/<platform-1>` |
| platform-2 | `~/Code/<org>/<platform-2>/repo-1`            | sibling dir of the repo |

Each master repo self-contains its workflow: bash scripts in
`scripts/feature-workflow/`, the pi `feature_start`/`feature_mr`/`feature_stop`/
`feature_list` tools in its repo-local `.pi/extensions/feature-workflow.ts`, and
the `feature-master` skill in its `.agents/skills/`. All paths are derived from
file locations (no hardcoded `$HOME`), so everything works identically on both
machines. A feature = `<master-repo>/features/<name>/` containing one git
worktree per touched repo (branch `feat/<name>` off the platform base branch) +
`BRIEF.md` (line 1 = MR/PR title); feature-start also opens a herdr workspace
(label `platform-1-<name>` / `platform-2-<name>`, so same-named features on the two
platforms can't collide) and spawns the feature-lead pi. Drive it from the
master repo's pi session (`/feature-start <name>`) or the scripts directly from
a shell. Full operating pattern lives in each repo's `AGENTS.md`.

## Additional Notes

### Important paths reference

| Tool               | Config location                        | Notes                                    |
| ------------------ | -------------------------------------- | ---------------------------------------- |
| Nix / Home Manager | `~/dotfiles/{flake.nix,flake.lock,home/}` | `home-manager switch` applies; `flake.lock` pins |
| Neovim             | `~/.config/nvim/` (`nvim/`)            | lazy.nvim manages plugins                |
| herdr             | `~/.config/herdr/` (`herdr/`)          | Workspaces, toggles, boot restore; unit in `home/herdr.nix` |
| Zellij             | `~/.config/zellij/` (`zellij/`)        |                                          |
| Ghostty            | `~/.config/ghostty/` (`ghostty/`)      | Linux/macOS variant files                |
| Zed                | `~/.config/zed/` (`zed/`)              |                                          |
| lazygit            | `~/.config/lazygit/config.yml`         |                                          |
| IntelliJ IdeaVim   | `~/.ideavimrc` (`intellij/ideavimrc`)  |                                          |
| Claude Code        | `~/.claude/` (`claude/`)               | Runtime state ignored                    |
| pi-coding-agent    | `~/.pi/`, `~/.agents/` (`pi/`)         | Binary via HM activation; plugins agent-managed |
| .editorconfig      | `~/.editorconfig`                      |                                          |
| Bash aliases       | `~/dotfiles/bash/*` (sourced by HM `~/.bashrc`) | See Shell Alias Architecture      |
| Windows PowerShell | `WindowsPowerShell/*.ps1`              | Mirrors bash alias structure for Windows |

### Git config (Home Manager)

`home/git.nix` writes `~/.config/git/config` (XDG): personal identity,
`pull.rebase`, `init.defaultBranch`, nvimdiff diff/merge, and an `include.path`
to `~/.gitconfig-local` (untracked machine-local file carrying the work
`includeIf`). Install scripts no longer set git config — a `~/.gitconfig` would
shadow the HM-managed XDG config.
