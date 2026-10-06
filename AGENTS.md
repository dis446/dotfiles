# AGENTS.md

## Project Overview

Personal dotfiles repo for Tsetsen-erdene Ganbaatar (dis446). Manages cross-platform shell config, editor configs, and tooling across Fedora/Nobara, macOS, and Ubuntu. The repo lives at `~/dotfiles` — the flake and the out-of-store symlinks bake that absolute path.

**The environment is Nix + Home Manager.** `flake.nix` pins nixpkgs + home-manager and declares the CLI tools, runtimes, shell, git config, and config links; `flake.lock` makes machines reproducible. The OS install scripts are **system-only** (RPM Fusion, `dnf.conf`, zram, flatpak, systemd). See "Nix / Home Manager" below and `plans/nix-migration-plan.md`.

**Key technologies:** Nix flakes, Home Manager, Bash, Neovim (Lua/lazy.nvim), herdr, ghostty, zed, IntelliJ IdeaVim, lazygit, mise (JDK baseline + per-repo version overrides), pi-coding-agent.

## OS track parity — read before every change

Every OS track is held to the **same standard**. A change to one track is not
finished until the same change exists in every track it applies to. Never leave
a track behind because you are not running that OS, and never let two tracks
drift into different shapes.

| Track                             | Kind                  | Files beyond the common set                                                   |
| --------------------------------- | --------------------- | ----------------------------------------------------------------------------- |
| `arch/`                           | Nix + Home Manager    | `zram-generator.conf`                                                         |
| `fedora/`                         | Nix + Home Manager    | `dnf.conf`, `zram-generator.conf`                                             |
| `nobara/`                         | Nix + Home Manager    | `dnf.conf`                                                                    |
| `ubuntu/`                         | Nix + Home Manager    | — (also the platform for the WSL2 host `wsl`)                                 |
| `macos/`                          | **pre-HM** (Homebrew) | `Brewfile`, `zshrc` — no flake attr                                           |
| `windows/` + `WindowsPowerShell/` | native Windows        | `install.ps1`, `scoop.json`, `winget.json`, `profile.ps1` + `*_functions.ps1` |

Common set, required in every Linux/HM track: `bashrc`, `bash_aliases`,
`install.sh`, `README.md`.

### Per-file contract

- **`<os>/bashrc`** — sources `bash/*`, then `<os>/bash_aliases`; sets `PS1`, activates `mise`, puts `~/.local/bin`/`~/go/bin`/`~/.cargo/bin` on `PATH`, and exports the `JAVA_TOOL_OPTIONS` / `NODE_OPTIONS` ceilings. `home/bash.nix` sources `<os>/bashrc` only when the file exists — a missing one silently drops PATH, aliases, and `pi`/`gitlab-tui` resolution.
- **`<os>/bash_aliases`** — the `i` / `r` / `is` / `il` package aliases, `DOCKER_HOST` + `DOCKER_SOCK` (also set at session scope in `home/default.nix` so GUI-launched apps inherit them — keep both, neither replaces the other), and **`up()` as a function, never an alias**: `scripts/nix-update.sh` → OS package upgrade → flatpak → `pi update --extensions`, chained with `|| return`, preceded by `unalias up 2>/dev/null || true`. Keep the explanatory comments — `fedora/bash_aliases` is the reference; a shorter comment is fine only where it says "same reasoning as fedora/bashrc".
- **`<os>/install.sh`** — `#!/usr/bin/env bash`, mode `100755`, the `link_target()` helper, then the same shared tail in the same order: `pi`/`.ai`/`claude` links → herdr reload → OS packages → pi plugins → gitlab-tui build + `scripts/gitlab-tui-config.sh` → flatpak → podman socket (guarded) → `git config core.hooksPath .githooks`. **System-only** — never install anything `home/packages.nix` owns.
- **`<os>/README.md`** — the four-command fresh-install block (Nix installer → clone to `~/dotfiles` → `./<os>/install.sh` → `nix run …home-manager… -- switch -b backup --flake ~/dotfiles#<user>@<host>`), then the rebuild command, then the same three closing notes. `fedora/README.md` is the template.

### Checklist for any cross-platform change

1. Apply it to **every** track in the table — arch, fedora, nobara, ubuntu, macos, windows — not just the one you happen to be running.
2. Registering a new machine or distro is four edits, not one: the `hosts` map in `flake.nix`, `nix_platform` in `scripts/nix-lib.sh`, the `case "$DISTRO"` + `install_prereqs` branches in `scripts/e2e-nix-container.sh`, and this table.
3. Update every doc surface that enumerates tracks: this section, **Directory Layout**, **Setup Commands**, the `hosts` key lists under **Nix / Home Manager**, and the "every OS track has a shell rc" bullet under **Code Style Guidelines**.
4. Gate before committing: `bash -n` on every touched script, `bash scripts/check-identifiers.sh`, `nix build --no-link .#homeConfigurations."<user>@<host>".activationPackage`, and a real `E2E_DISTRO=<fedora|ubuntu|arch> scripts/e2e-nix-container.sh` run. Report the e2e result.

### Deliberate exceptions — do not "fix" these

- `macos/` is the pre-Home-Manager track (`plans/nix-migration-plan.md` §10): Homebrew + `install.sh` symlinks only, no Nix, no flake attr.
- `windows/` is a **curated** layer, not a full `scoop export` / `winget export` — drivers, games and vendor utilities are excluded on purpose.
- GUI apps stay outside Nix where the OS already ships them (flatpak/system); only ghostty and orca are nix-wrapped (nixGL, Linux non-WSL).
- `nobara/` has no zram step while `arch/` and `fedora/` do. Known, unresolved difference — do not silently copy one into the other; decide it and record the outcome here.

## Directory Layout

| Path                                               | Managed by                              | Purpose                                                                          |
| -------------------------------------------------- | --------------------------------------- | -------------------------------------------------------------------------------- |
| `flake.nix`, `flake.lock`                          | —                                       | Nix inputs + pinned versions (`flake.lock` is committed)                         |
| `home/`                                            | Home Manager                            | `home/*.nix` modules: packages, dotfile links, bash, git, herdr unit, pi agent |
| `scripts/`                                         | —                                       | `nix-*` helpers + `e2e-nix-container.sh`; `check-identifiers.sh`                 |
| `bash/`                                            | Home Manager (sourced)                  | Cross-platform shell aliases, split by topic                                     |
| `arch/`, `fedora/`, `nobara/`, `macos/`, `ubuntu/` | system-only                             | OS-specific aliases, bashrc, system install scripts                              |
| `nvim/`                                            | HM link → `~/.config/nvim`              | Neovim config (Lua, lazy.nvim)                                                   |
| `herdr/`                                           | HM link + `home/herdr.nix`              | herdr config + systemd unit, toggles, boot restore (see WORKFLOW.md)             |
| `ghostty/`                                         | HM link → `~/.config/ghostty`           | Ghostty terminal config (linux/ + macos/ variants)                               |
| `zed/`                                             | HM file links → `~/.config/zed`         | Zed editor config + themes                                                       |
| `lazygit/`                                         | HM link → `~/.config/lazygit`           | lazygit config                                                                   |
| `gradle/`                                          | HM link → `~/.gradle/gradle.properties` | Gradle worker/heap limits (concurrency budget)                                   |
| `intellij/`                                        | HM link → `~/.ideavimrc`                | IdeaVim config + keymap references                                               |
| `pi/`                                              | install.sh → `~/.pi`, `~/.agents`       | pi-coding-agent config (runtime state ignored)                                   |
| `claude/`                                          | install.sh → `~/.claude`                | Claude Code config (settings tracked, runtime ignored)                           |
| `WindowsPowerShell/`                               | `windows/install.ps1` links `$PROFILE`  | Native PowerShell shell layer (`profile.ps1` + topic files)                      |
| `windows/`                                         | `install.ps1` (run manually)            | Native-Windows layer: Scoop + winget manifests, `$PROFILE` link                  |
| `hyprland/`, `k8s/`                                | (not linked)                            | WM config, k8s cheatsheet                                                        |

## Setup Commands

**Fresh machine (Linux):**

```bash
# 1. Nix (Determinate multi-user installer)
curl -fsSL https://install.determinate.systems/nix | sh -s -- install

# 2. Clone to the baked path
git clone git@github.com:dis446/dotfiles.git ~/dotfiles

# 3. System-level setup (RPM Fusion, dnf.conf, zram, flatpak, systemd)
./fedora/install.sh          # or nobara/install.sh / ubuntu/install.sh / arch/install.sh

# 4. Apply the Nix environment (tools + config + shell + herdr unit)
home-manager switch --flake ~/dotfiles#$(id -un)@nobara   # platform: fedora | nobara | ubuntu | arch
```

`macos/install.sh` + `macos/Brewfile` are the macOS track (see `plans/nix-migration-plan.md` §10).

**Windows 11 (work):** WSL2 (Ubuntu) runs the Nix environment; `windows/install.ps1`
bootstraps the native layer. Host `winny@wsl`, role `work`. Full walkthrough:
[Windows / WSL](#windows--wsl).

**Daily commands** (also the `nix-update` / `nix-pull` / `nix-cleanup` / `nix-e2e` aliases):

| Command                                                       | Does                                                                        |
| ------------------------------------------------------------- | --------------------------------------------------------------------------- |
| `home-manager switch --flake ~/dotfiles#$(id -un)@<platform>` | apply `.nix` changes                                                        |
| `nix-update`                                                  | `nix flake update` → `flake check` → switch → bump pi → commit `flake.lock` |
| `nix-pull`                                                    | pull; tells you to rebuild if `.nix`/`flake.lock` changed                   |
| `nix-cleanup`                                                 | GC old generations + `nix store optimise`                                   |
| `nix-e2e`                                                     | boot the flake from scratch in a throwaway Fedora container                 |

Install scripts are **idempotent** — `rm -rf "$dest"` before `ln -s "$src"`.

### What the install scripts do (system-only)

1. OS system layer — Fedora/Nobara: RPM Fusion, `dnf.conf`, zram, `mpv-libs`, flatpak GUI apps. Ubuntu: `apt` update, podman (user socket), flatpak GUI apps (skipped on WSL).
2. Symlink the imperative agent configs (`pi`, `.ai`, `claude`) and reload herdr.
3. Shared agent/tooling tail (**all five tracks**): pi plugins, gitlab-tui build + config, and `git config core.hooksPath .githooks` (identifier pre-commit hook).

Everything else on the Linux tracks — CLI tools, runtimes, shell rc, git identity, and the editor/multiplexer configs — is Home Manager. The macOS track still symlinks its own config set because it is not on Home Manager yet (`plans/nix-migration-plan.md` §10).

### Manual steps after first setup

```bash
# In Neovim, install plugins (lazy.nvim bootstraps on first launch)
nvim --headless "+Lazy! sync" +qa

# Open herdr once to attach (headless server + restore.sh handle the rest)
herdr
```

## Nix / Home Manager

- `flake.nix` — inputs (`nixpkgs-unstable`, `home-manager`, `nixGL`, `llm-agents`, `pi`) and a `hosts` map (fedora/nobara/arch/ubuntu → `{ username, role, platform, system }`) plus `homeConfigurations."<user>@<platform>"` — username is per host (`guddy` on the work fedora, `neddy` on personal nobara/ubuntu, `archy` on the work arch); `scripts/nix-lib.sh` derives it from `id -un`. `role` (`work`/`personal`) gates packages; `mkHome` asserts membership. One flake, shared `home/` modules.
- `home/` — one concern per file:
  - `packages.nix` — CLI tools + runtimes; role-gated extras (`azure-cli`, `glab`, `gh` for `work`).
  - `dotfiles.nix` — `mkOutOfStoreSymlink` links for nvim, ghostty, lazygit, herdr config, zed, `.editorconfig`, `.ideavimrc`, gradle. **Never** `source = ./dir` — that copies into the read-only store and breaks files the app rewrites (`lazy-lock.json`).
  - `bash.nix` — HM owns `~/.bashrc`; sources `$HOME/dotfiles/<platform>/bashrc` (which in turn sources `bash/*` + `<platform>/bash_aliases`), falling back to those two directly when no OS rc exists. Fedora/Nobara/Ubuntu all have a `bashrc`. Do **not** also symlink `~/.bashrc` in install scripts.
  - `git.nix` — git identity via XDG `~/.config/git/config`; the work identity lives in untracked `~/.gitconfig-local` (included).
  - `packages.nix` also carries the pi agent binary, from the upstream pi flake (`pi.url`) — so the agent moves with `flake.lock`; its plugins stay agent-managed under `~/.pi/agent/npm`. That npm tree is **per machine and gitignored** (nothing to `git pull`), so `plans/fix-pi-extension-lockfile.md` repairs it when its lockfile accumulates bogus `../dotfiles/…` keys.
  - `herdr.nix` — `systemd.user.services.herdr-server` (Linux only, **including WSL**).
- **Reproducibility:** `flake.lock` is committed; versions move only on `nix flake update` (`nix-update`). `scripts/e2e-nix-container.sh` boots the whole thing in a fresh container and asserts the result (`E2E_DISTRO=fedora|ubuntu|arch`).
- **Hosts:** the `hosts` map is keyed `fedora`/`nobara`/`arch`/`ubuntu`/**`wsl`**/`servy` and carries `{ username, role, platform, system, isWsl? }`. Username is per host (`guddy` on the work fedora, `neddy` on personal nobara/ubuntu, `archy` on the work arch, `winny` on the WSL work host). `nix-lib.sh` maps the running OS to the key (`nix_platform` detects WSL first). `isWsl` gates host-only packages (`ghostty`/nixGL) — see [Windows / WSL](#windows--wsl).
- **mise is for per-repo overrides only** (a `mise.toml` in a project). Nix owns the global Node/Java/etc. — do not `mise use -g`.
  - **Exception: JDK baselines.** `mise/config.toml` (linked to `~/.config/mise/config.toml`) declares `java = ["temurin-21", "temurin-25"]` so both Temurin JDKs exist on every machine, 21 default. Nix's `temurin-bin-21` alone left nvim-jdtls without the exact launcher/runtime paths it derives from `mise where java@...`. `home.activation.miseInstall` re-runs `mise install` on every switch, so a pruned JDK heals on the next `home-manager switch`.
- **GUI apps on Linux are wrapped with nixGL** (`nixGL` flake input; `targets.genericLinux.nixGL` in `home/default.nix`, `config.lib.nixGL.wrap` in `home/packages.nix`). Nix mesa can't init EGL on non-NixOS, so nix GL apps (ghostty) fail with `Failed to create EGL display` without the wrapper.
- **Outside Nix (by design):** RPM Fusion / `dnf.conf` / zram / flatpak GUI apps (system), `pi`/`claude` runtime state, `bash/secret_aliases` and other `secret*` files, nvim's mason LSP servers, and mise-managed per-repo toolchains.

## Windows / WSL

Windows 11 is the **work** machine. Nix has no native Windows support, so the
dev environment runs inside **WSL2 (Ubuntu)** and the repo exposes only a thin
native bootstrap layer on top.

- **WSL2 host** — `winny@wsl` (`flake.nix` `hosts."wsl"`: `platform = "ubuntu"`,
  `role = "work"`, `isWsl = true`). Inherits the `ubuntu` shell/aliases. `isWsl`
  gates host-only bits: **no ghostty/nixGL** (no GPU/display of its own), while
  herdr's `systemd.user.services.herdr-server` still applies because Ubuntu WSL
  boots systemd. `scripts/nix-lib.sh` detects WSL (`WSL_DISTRO_NAME` or
  `/proc/version` containing `microsoft`) and maps it to the `wsl` flake key, so
  `nix-update` / `nix-pull` resolve `winny@wsl` automatically.
- **Native Windows layer** — `windows/install.ps1` (Scoop + winget + `$PROFILE`
  link). `WindowsPowerShell/profile.ps1` is linked to `$PROFILE`; the topic files
  (`general_functions.ps1`, `git_functions.ps1`, `work_functions.ps1`) mirror the
  bash aliases. Tooling is _curated_ in `windows/{scoop,winget}.json` — not a
  full export; drivers, Steam games and vendor utilities are deliberately
  excluded even though the box has them.
- **The repo lives at `~\dotfiles`** on Windows too, matching the baked path.

### Bring-up

```powershell
# --- Windows (admin PowerShell) ---
wsl --install -d Ubuntu             # reboot when prompted
# after reboot: set the user to "winny" and enable systemd in /etc/wsl.conf
wsl --shutdown

# --- Windows native layer ---
pwsh -File .\windows\install.ps1    # scoop/winget + $PROFILE link
```

```bash
# --- inside Ubuntu (WSL) ---
sudo apt update && sudo apt install -y curl git
git clone git@github.com:dis446/dotfiles.git ~/dotfiles
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
~/dotfiles/ubuntu/install.sh
home-manager switch --flake ~/dotfiles#winny@wsl
```

`/etc/wsl.conf` (then `wsl --shutdown` from Windows):

```ini
[boot]
systemd=true
[user]
default=winny
```

Gotchas:

- Keep the checkout **inside WSL** (`~/dotfiles`), never on `/mnt/c` — the
  out-of-store symlinks bake `$HOME/dotfiles`, and `/mnt/c` is slow and
  case-insensitive.
- `systemd=true` is required for herdr; `loginctl enable-linger winny` keeps the
  user unit alive without an open shell.
- GUI apps (ghostty, Zed, IntelliJ, browsers) are **Windows-native**, not WSL.
  WSLg can run X apps but is not the Fedora desktop.
- `e2e-nix-container.sh` is Linux/container-oriented and is not run on Windows.
- Windows-native git uses `Git.Git` from winget; the repo's git identity is
  HM-managed only inside WSL.

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
home-manager switch --flake ~/dotfiles#$(id -un)@nobara    # apply
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
- Every `*/install.sh` starts with `#!/usr/bin/env bash` and is executable (`100755`)
- Every OS track has a shell rc (`{fedora,nobara,arch,ubuntu}/bashrc`, `macos/{zshrc,bashrc}`) that sources `bash/*` + its own `bash_aliases`, and every install script ends with the same shared tail (herdr reload, pi plugins, gitlab-tui, `core.hooksPath`)
- Line endings are LF, enforced by `.gitattributes` so shell shebangs survive a Windows checkout

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
- **Mechanism:** clone to `~/dotfiles`, install Nix, run the OS install script, then `home-manager switch --flake .#$(id -un)@<platform>` — `flake.lock` reproduces the toolchain
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
`home-manager switch --flake ~/dotfiles#$(id -un)@<platform>`.

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

| Platform   | Master repo                        | Platform root               |
| ---------- | ---------------------------------- | --------------------------- |
| platform-1 | `~/Code/<org>/<platform-1>/repo-1` | `~/Code/<org>/<platform-1>` |
| platform-2 | `~/Code/<org>/<platform-2>/repo-1` | sibling dir of the repo     |

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

| Tool               | Config location                                 | Notes                                                                |
| ------------------ | ----------------------------------------------- | -------------------------------------------------------------------- |
| Nix / Home Manager | `~/dotfiles/{flake.nix,flake.lock,home/}`       | `home-manager switch` applies; `flake.lock` pins                     |
| Neovim             | `~/.config/nvim/` (`nvim/`)                     | lazy.nvim manages plugins                                            |
| herdr              | `~/.config/herdr/` (`herdr/`)                   | Workspaces, toggles, boot restore; unit in `home/herdr.nix`          |
| Ghostty            | `~/.config/ghostty/` (`ghostty/`)               | Linux/macOS variant files                                            |
| Zed                | `~/.config/zed/` (`zed/`)                       |                                                                      |
| lazygit            | `~/.config/lazygit/config.yml`                  |                                                                      |
| IntelliJ IdeaVim   | `~/.ideavimrc` (`intellij/ideavimrc`)           |                                                                      |
| Claude Code        | `~/.claude/` (`claude/`)                        | Runtime state ignored                                                |
| pi-coding-agent    | `~/.pi/`, `~/.agents/` (`pi/`)                  | Binary via HM activation; plugins agent-managed                      |
| .editorconfig      | `~/.editorconfig`                               |                                                                      |
| Bash aliases       | `~/dotfiles/bash/*` (sourced by HM `~/.bashrc`) | See Shell Alias Architecture                                         |
| Windows (native)   | `WindowsPowerShell/*.ps1`, `windows/`           | `$PROFILE` linked by `windows/install.ps1`; Scoop + winget manifests |

### Git config (Home Manager)

`home/git.nix` writes `~/.config/git/config` (XDG): personal identity,
`pull.rebase`, `init.defaultBranch`, nvimdiff diff/merge, and an `include.path`
to `~/.gitconfig-local` (untracked machine-local file carrying the work
`includeIf`). Install scripts no longer set git config — a `~/.gitconfig` would
shadow the HM-managed XDG config.
