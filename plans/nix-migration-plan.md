# Nix Package Manager Migration Plan

> Migrate dotfiles install scripts from OS-specific package managers (dnf, brew, apt) to Nix + Home Manager.
> Date: 2026-07-15
> Nix version: 2.35.1 (single-user, `--no-daemon`)
> OS: Fedora/Nobara (primary) + macOS + Ubuntu

---

## Table of Contents

1. [Current State](#1-current-state)
2. [Goal](#2-goal)
3. [Options Analysis](#3-options-analysis)
4. [Recommended Approach: Flake + Home Manager](#4-recommended-approach-flake--home-manager)
5. [Step-by-Step Migration Plan](#5-step-by-step-migration-plan)
6. [Nix Package Reference](#6-nix-package-reference)
7. [OS-specific Configs That Stay](#7-os-specific-configs-that-stay)
8. [Flake Structure](#8-flake-structure)
9. [Rollout Strategy](#9-rollout-strategy)
10. [Risks & Mitigations](#10-risks--mitigations)

---

## 1. Current State

### 1.1 What install scripts do

| OS | Script | Package manager | Packages installed |
|----|--------|-----------------|-------------------|
| Fedora | `fedora/install.sh` | dnf + flatpak + pip + cargo + mise + npm | git, vim, neovim, lazygit, tmux, podman-docker, mise, htop, ncdu, speedtest-cli, pip3, golang, kubectl, cargo, zellij + flatpaks |
| Nobara | `nobara/install.sh` | dnf + nobara-sync + flatpak + pip + cargo + mise + npm | Same as Fedora |
| macOS | `macos/install.sh` | (none in script — `macos/Brewfile` for Homebrew) | bat, fastfetch, htop, jq, lazygit, ncdu, neovim, podman, podman-compose, rsync, speedtest-cli, tmux |
| Ubuntu | `ubuntu/install.sh` | (symlinks only, no package install) | None |

### 1.2 Cross-platform tools to migrate

All of these exist in `nixpkgs` and can be installed declaratively:

```
git, vim, neovim, lazygit, tmux, zellij,
htop, ncdu, speedtest-cli, bat, jq, fastfetch,
rsync, golang, kubectl, podman, podman-compose,
node (via nodejs_24), java (via temurin-bin-21)
```

### 1.3 Things that stay OS-specific

- **System packages:** Docker/Podman daemon, systemd services, display drivers, kernel modules
- **COPR repos / dnf.conf:** Can't be nix-managed
- **Flatpaks:** Extension Manager, Flatseal — GUI apps better via flatpak
- **dnf.conf / apt sources:** OS-level config only
- **macOS Brewfile:** Could be replaced, but some things (podman-compose) are cleaner via Homebrew on macOS

---

## 2. Goal

```diff
- dnf install git neovim lazygit tmux ...
- brew install bat neovim lazygit tmux ...
+ nix profile install nixpkgs#neovim nixpkgs#lazygit ...
```

But more ambitiously:

- **Declarative machine:** A single `nix` command installs all dev tools on any OS
- **Pin everything:** `flake.lock` pins exact versions — reproducible across machines
- **Dotfiles integration:** Home Manager manages `~/.config/nvim`, `~/.config/tmux` symlinks declaratively
- **mise stays for per-project version overrides:** Nix provides global defaults (Node 24, Java 21); mise overrides them per project for team compatibility
- **Cross-platform:** Same flake works on Fedora, Nobara, macOS, Ubuntu

---

## 3. Options Analysis

### Option A: `nix profile` only (simplest)

```
nix profile install nixpkgs#neovim nixpkgs#lazygit ...
```

**Pros:**
- Minimal change to repo structure
- Works immediately
- Familiar imperative feel (like dnf/brew)

**Cons:**
- No declarative config (no flake.lock pinning without extra work)
- No automatic dotfile management
- Manual per-machine bootstrap
- No easy rollback of a set of tools

**Verdict:** Good starting point, insufficient long-term.

### Option B: Flake + `nix profile` from flake outputs

Create a flake that outputs `packages.x86_64-linux.devTools` and install via:
```
nix profile install .#devTools
```

**Pros:**
- Declarative package set with lockfile
- Reproducible across machines
- Can compose by OS (Fedora vs macOS packages)

**Cons:**
- Still manual per-machine install
- No dotfile management
- Must manually update

**Verdict:** Better, but still lacks config management.

### Option C: Flake + Home Manager (recommended) ⭐

```
nix run home-manager/master -- switch --flake .
```

**Pros:**
- Declarative packages + dotfiles in one file
- `home.nix` manages `~/.config/nvim`, `~/.config/tmux`, etc.
- Manages shell config, environment variables, systemd user services
- Pins exact versions via flake.lock
- Rollback with `home-manager generations`
- Cross-platform (Fedora, macOS, Ubuntu — all supported)
- Home Manager already has modules for Neovim, tmux, git, zsh/bash, etc.

**Cons:**
- Learning curve for Nix language
- Home Manager has its own module system to learn
- Some configs still need `xdg.configFile` or raw `home.file` copying
- The symlink approach in install scripts becomes partially redundant

**Verdict:** The idiomatic Nix approach. Best long-term value.

---

## 4. Recommended Approach: Flake + Home Manager

### 4.1 Architecture

```
dotfiles/
├── flake.nix                 # Entry point: inputs + outputs
├── flake.lock                # Pinned versions (auto-generated)
├── home.nix                  # Home Manager configuration (cross-platform)
├── home/
│   ├── packages.nix          # Package list (all tools)
│   ├── programs/             # Home Manager program modules
│   │   ├── git.nix           # Git config
│   │   ├── neovim.nix        # Neovim config path + runtime
│   │   ├── tmux.nix           # Tmux config
│   │   ├── zellij.nix        # Zellij config
│   │   ├── zed.nix           # Zed config
│   │   └── ...
│   ├── shell.nix             # Shell (bash/zsh) config
│   │   └── aliases.nix       # Shell aliases (migrated from bash/)
│   ├── services.nix          # User services (tmux systemd, etc.)
│   └── files.nix             # xdg.configFile for any non-program-managed configs
├── overlays/                 # (optional) custom package overrides
│   └── default.nix
│
├── fedora/install.sh         # KEPT: system-level setup only (dnf.conf, COPR)
├── fedora/dnf.conf           # KEPT
├── macos/Brewfile            # KEPT (until all tools migrate; some macOS-only GUI apps stay)
├── ubuntu/install.sh         # KEPT (system-level only)
│
├── bash/                     # PARTIALLY REPLACED: aliases migrate to home-manager
├── nvim/ → managed by home-manager xdg.configFile
├── tmux/ → managed by home-manager xdg.configFile
├── zellij/ → managed by home-manager xdg.configFile
├── zed/ → managed by home-manager xdg.configFile
│
└── install.sh                # NEW: one-shot bootstrap script
```

### 4.2 What Nix replaces

| Current tool | Nix replacement |
|-------------|----------------|
| `sudo dnf install neovim` | `home.packages = [ pkgs.neovim ]` |
| `brew install lazygit` | `home.packages = [ pkgs.lazygit ]` |
| `sudo dnf install mise` (or brew) | `home.packages = [ pkgs.mise ]` |
| `sudo dnf copr enable ...` | `home.packages = [ pkgs.lazygit ]` (already in nixpkgs) |
| `sudo pip install pydf` | `home.packages = [ pkgs.pydf ]` |
| `cargo install zellij` | Already in nixpkgs: `pkgs.zellij` |
| `sudo npm install -g pi-coding-agent` | N/A — use npm or keep as-is |
| `fedora/bashrc` sources `bash/` aliases | `home.sessionVariables` + `programs.bash.shellAliases` |

### 4.3 mise → Nix relationship

| Role | Tool |
|------|------|
| **mise CLI itself** | Installed via Nix (`pkgs.mise`) — no more dnf/brew `mise install` |
| **Global defaults** (what's on `$PATH` by default) | `home.packages` via Nix (Node 24, Java 21) |
| **Per-project overrides** (repo-specific versions) | `mise` with `.mise.toml` (Node 20, Java 25, etc.) |

mise's shim mechanism works independently of Nix — it prepends to `$PATH` when inside a project directory, so per-project versions shadow the Nix-provided global ones automatically.

```
# How PATH resolution works:
# ~/project-with-java-25/$ cd                 → mise shims in PATH → Java 25
# ~/                                        → Nix profile in PATH → Java 21
```

Both version sources are kept in sync where it matters:
- Nix `home.nix` sets the **global default** (Node 24, Java 21), replacing `mise use -g`
- mise `.mise.toml` per project sets the **override** (Node 20, Java 25, etc.)
- mise itself comes from Nix — no separate dnf/brew install needed

### 4.4 What stays outside Nix

| Thing | Why |
|-------|-----|
| `fedora/dnf.conf` | OS-level config, not user-level |
| `fedora/bashrc` sourcing nix.sh | Nix needs to be sourced; kept minimal |
| `flatpak install ExtensionManager Flatseal` | GUI desktop apps — flatpak is fine |
| `ghostty/config` | Ghostty terminal needs Nixpkgs unstable, may lag |
| `sudo dnf install` system packages | Nix doesn't manage kernel, systemd, display drivers |
| `hyprland/` | WM config — stays OS-specific |
| `intellij/ideavimrc` | IdeaVim config stays as symlink |
| `pi/` + `claude/` | Agent configs — not managed by Nix |
| Homebrew remaining items | Convenience for macOS-specific apps |
| `pi-coding-agent` | npm global — stay with npm |

---

## 5. Step-by-Step Migration Plan

### Phase 0: Enable Nix features & source Nix

**Status:** ✅ Nix 2.35.1 installed | ⬜ Experimental features enabled | ⬜ Nix in PATH

```bash
# Already done: nix installed at /nix/
# Enable experimental features
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf

# Nix is already sourced via .bash_profile:
# [[ -e ~/.nix-profile/etc/profile.d/nix.sh ]] && source ~/.nix-profile/etc/profile.d/nix.sh
```

### Phase 1: Bootstrap Home Manager (standalone)

**Files to create:**
- `flake.nix` (root)
- `home.nix` (root)
- `home/packages.nix`
- `install.sh` (root — new bootstrap script)

```bash
# Initial bootstrap (replaces most of fedora/install.sh / macos/install.sh)
nix run nixpkgs#home-manager -- switch --flake .
```

**`flake.nix`** (initial skeleton):
```nix
{
  description = "dis446 dotfiles - cross-platform dev environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    homeConfigurations."neddy" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [ ./home.nix ];
    };
  };
}
```

**`home.nix`** (initial):
```nix
{ config, pkgs, ... }: {
  home = {
    username = "neddy";
    homeDirectory = "/home/neddy";
    stateVersion = "25.05";
  };
  imports = [ ./home/packages.nix ];
}
```

**`home/packages.nix`**:
```nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Editors
    neovim
    vim
    
    # Version control
    git
    lazygit
    
    # Terminal
    tmux
    zellij
    
    # System tools
    htop
    ncdu
    bat
    jq
    fastfetch
    rsync
    
    # Languages & runtimes
    nodejs_24
    temurin-bin-21
    go
    
    # Cloud
    kubectl
    
    # Container (management CLIs only)
    podman
    
    # Other
    speedtest-cli
    pydf
  ];
  
  programs.bash = {
    enable = true;
    shellAliases = {
      dtf = "cd ~/dotfiles";
      src = "source ~/.bashrc";
      v = "nvim";
      c = "cat";
      b = "bat";
      l = "ls -lAh";
      ll = "ls -al";
      cl = "clear";
      mkdir = "mkdir -pv";
    };
  };
}
```

### Phase 2: Migrate program configs to Home Manager modules

Migrate configs one at a time, testing each. Home Manager can manage config files declaratively:

```nix
# In home.nix or a module:
{
  # Git
  programs.git = {
    enable = true;
    userName = "Tsetsen-erdene Ganbaatar";
    userEmail = "dis446@yahoo.com";
    extraConfig = { pull.rebase = true; };
  };
  
  # Neovim (point to existing dotfiles config)
  xdg.configFile."nvim" = {
    source = ./nvim;
    recursive = true;
  };
  
  # Tmux
  xdg.configFile."tmux" = {
    source = ./tmux;
    recursive = true;
  };
  
  # Zed
  xdg.configFile."zed" = {
    source = ./zed;
    recursive = true;
  };
  
  # Zellij
  xdg.configFile."zellij" = {
    source = ./zellij;
    recursive = true;
  };
}
```

**Migration order (lowest risk first):**
1. Git config (simple, Home Manager has native module)
2. Shell aliases (move from `bash/` to `programs.bash.shellAliases`)
3. Neovim (keep existing `nvim/` dir, just manage the symlink via `xdg.configFile`)
4. Tmux (keep `tmux/`, manage symlink)
5. Zed, Zellij (same pattern)

### Phase 3: Migrate OS-specific configs

**Fedora/Nobara:** Keep `fedora/install.sh` minimal — only:
- RPM Fusion COPR (system-level repos)
- `dnf.conf` symlink
- Flatpak installs (Extension Manager, Flatseal)
- Remove all package installs (they're now in Nix)

**macOS:** Keep `Brewfile` but shrink it — remove packages that Nix now manages.

**Ubuntu:** No changes needed (already symlinks-only).

### Phase 4: Add tmux systemd auto-start via Home Manager

Replace continuum's auto-generated systemd service with Home Manager's `systemd.user.services`:

```nix
systemd.user.services.tmux = {
  Unit = {
    Description = "tmux default session (detached)";
    Documentation = "man:tmux(1)";
  };
  Service = {
    Type = "forking";
    Environment = "DISPLAY=:0";
    ExecStart = "${pkgs.tmux}/bin/tmux start-server";
    ExecStop = "${pkgs.tmux}/bin/tmux kill-server";
    RestartSec = 2;
  };
  Install.WantedBy = [ "default.target" ];
};
```

This replaces `@continuum-boot 'on'` and gives cleaner control.

### Phase 5: Bootstrap script

Create root `install.sh` that works on any OS:

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Run OS-specific system setup
case "$(uname)" in
  Linux)
    if [ -f /etc/fedora-release ]; then
      source fedora/install.sh   # system-only: COPR, dnf.conf, flatpaks
    elif [ -f /etc/nobara ]; then
      source nobara/install.sh
    elif [ -f /etc/lsb-release ]; then
      source ubuntu/install.sh
    fi
    ;;
  Darwin)
    # System setup is minimal on macOS — just ensure Homebrew basics
    if command -v brew &>/dev/null; then
      brew bundle --file macos/Brewfile  # will be smaller after migration
    fi
    ;;
esac

# 2. Symlink configs that Home Manager doesn't manage
link_target() { rm -rf "$2"; ln -s "$1" "$2"; }
link_target "$HOME/dotfiles/pi/agent" "$HOME/.agents"
link_target "$HOME/dotfiles/pi" "$HOME/.pi"
link_target "$HOME/dotfiles/claude" "$HOME/.claude"
link_target "$HOME/dotfiles/intellij/ideavimrc" "$HOME/.ideavimrc"

# 3. Apply Home Manager (installs all tools + manages dotfiles)
nix run nixpkgs#home-manager -- switch --flake "$HOME/dotfiles"
```

---

## 6. Nix Package Reference

### 6.1 Tool → Nixpkgs package name

| Tool | Package | Notes |
|------|---------|-------|
| git | `pkgs.git` | |
| vim | `pkgs.vim` | |
| neovim | `pkgs.neovim` | |
| lazygit | `pkgs.lazygit` | |
| tmux | `pkgs.tmux` | |
| zellij | `pkgs.zellij` | |
| htop | `pkgs.htop` | |
| ncdu | `pkgs.ncdu` | |
| bat | `pkgs.bat` | |
| jq | `pkgs.jq` | |
| fastfetch | `pkgs.fastfetch` | |
| rsync | `pkgs.rsync` | |
| speedtest-cli | `pkgs.speedtest-cli` | |
| golang | `pkgs.go` | |
| kubectl | `pkgs.kubectl` | |
| podman | `pkgs.podman` | CLI only, daemon is system-managed |
| podman-compose | `pkgs.podman-compose` | |
| Node.js 24 | `pkgs.nodejs_24` | Replaces `mise use -g node@24` |
| Java Temurin 21 | `pkgs.temurin-bin-21` | Replaces `mise use -g java@temurin-21` |
| mise CLI | `pkgs.mise` | Replaces `sudo dnf install mise` / `brew install mise` |
| Python pydf | `pkgs.pydf` | |

### 6.2 Programs not in Nixpkgs

| Tool | Alternative |
|------|------------|
| `pi-coding-agent` | Stay with `npm install -g @earendil-works/pi-coding-agent` |
| `Extension Manager` (flatpak) | Stay with flatpak |
| `Flatseal` (flatpak) | Stay with flatpak |
| Ghostty | Available in nixpkgs-unstable as `pkgs.ghostty` |

---

## 7. OS-specific Configs That Stay

### 7.1 Fedora (`fedora/`)

Keep:
- `fedora/dnf.conf` — system-level dnf config
- `fedora/install.sh` — minimal: RPM Fusion, dnf.conf symlink, flatpaks
- `fedora/bash_aliases` — `sudo dnf install` aliases (still useful for non-nix packages)

Remove from install script:
- All `sudo dnf install` lines for tools now in Nix (`neovim`, `lazygit`, `tmux`, `htop`, `ncdu`, `zellij`, etc.)
- `sudo dnf install` for `mise`, `nodejs`, `java` — replace with Nix's `nodejs_24` and `temurin-bin-21`
- `sudo dnf copr enable` lines for tools moved to Nix
- `sudo pip install`, `cargo install` lines (tools → nix)
- `sudo npm install -g pi-coding-agent` (keep as explicit step)

Keep in install script:
- `mise use -g` lines — **removed**, Nix provides global Node/Java now

### 7.2 macOS (`macos/`)

Keep:
- `macos/Brewfile` — reduced to GUI apps and things not in nixpkgs
- `macos/zshrc` / `bash_aliases` — keep sourcing Nix

### 7.3 Ubuntu (`ubuntu/`)

No packages installed currently, so no change needed.

### 7.4 Cross-platform shell config

The per-OS shell rc files currently source `bash/` aliases. After migration:
- Most aliases move to `programs.bash.shellAliases` in Home Manager
- OS-specific aliases stay in per-OS files
- The shell rc file stays minimal: source nix.sh, source OS aliases

---

## 8. Flake Structure

### 8.1 Recommended final layout

```
dotfiles/
├── flake.nix                # Main entry: inputs + outputs for each system
├── flake.lock               # Auto-generated lockfile
├── home.nix                 # Cross-platform home-manager config
├── home/
│   ├── packages.nix         # All installed packages
│   ├── programs/
│   │   ├── git.nix
│   │   ├── neovim.nix
│   │   ├── tmux.nix
│   │   ├── zellij.nix
│   │   ├── zed.nix
│   │   ├── ghostty.nix      # When/if ghostty is nix-managed
│   │   └── ...
│   ├── shell.nix            # Bash/zsh config + aliases
│   ├── services.nix         # systemd user services (tmux)
│   └── files.nix            # xdg.configFile for remaining configs
├── nvim/                    # KEPT: actual config content
├── tmux/                    # KEPT: actual config content
├── zellij/                  # KEPT
├── zed/                     # KEPT
├── bash/                    # KEPT for non-nix-managed systems; aliases mirrored in home-manager
├── fedora/install.sh        # KEPT: system-level setup only
├── macos/Brewfile           # KEPT: reduced
├── ubuntu/install.sh        # KEPT: no change
└── install.sh               # NEW: one-shot bootstrap
```

### 8.2 Multi-system support (future)

```nix
{
  outputs = { self, nixpkgs, home-manager, ... }: {
    homeConfigurations = {
      "neddy@fedora" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { system = "x86_64-linux"; };
        modules = [
          ./home.nix
          ({ pkgs, ... }: { home.packages = [ pkgs.ghostty ]; })
        ];
      };
      "neddy@mac" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { system = "aarch64-darwin"; };
        modules = [
          ./home.nix
          ({ pkgs, ... }: { home.packages = [ pkgs.ghostty ]; })
        ];
      };
    };
  };
}
```

---

## 9. Rollout Strategy

### Phase 0-1 (immediate)
```
⬜ Enable nix experimental features (nix-command + flakes)  [~5 min]
⬜ Create flake.nix + home.nix + home/packages.nix         [~30 min]
⬜ Bootstrap: nix run home-manager -- switch --flake .     [~15 min, downloads]
⬜ Verify packages are available (neovim, tmux, lazygit...)  [~10 min]
```

### Phase 2 (this week)
```
⬜ Migrate git config → programs.git                       [~15 min]
⬜ Migrate shell aliases → programs.bash.shellAliases      [~30 min]
⬜ Migrate xdg.configFile for nvim, tmux, zellij, zed      [~30 min]
⬜ Update install scripts to remove nix-managed packages    [~30 min]
⬜ Test on Fedora (primary machine)                        [~1 hour]
```

### Phase 3 (next week)
```
⬜ Test on Nobara                                           [~1 hour]
⬜ Test on macOS                                            [~1 hour]
⬜ Test on Ubuntu                                           [~1 hour]
⬜ Add tmux systemd service via home-manager                [~15 min]
⬜ Clean up continuum boot config (replaced by HM service)  [~10 min]
```

### Phase 4 (ongoing)
```
⬜ Remove fedora/setup package installs (already migrated)
⬜ Remove nobara/setup package installs
⬜ Shrink macos/Brewfile (remove nix-managed brew formulas)
⬜ Document nix commands in AGENTS.md
```

---

## 10. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Nix not in PATH** on reboot | Can't run `home-manager switch` | The Nix installer added sourcing to `~/.bash_profile` — verify it works after login |
| **Missing nixpkgs package** | Tool unavailable | Check `search.nixos.org` first. If unofficial, use `nix pkgs` override or overlay |
| **Version mismatch** (Nixpkgs has older tool than dnf) | Tool version differs | Use `nixpkgs-unstable` (already in plan) for fresher packages |
| **Disk usage** | `/nix/store` grows | `nix store gc` periodically; `nix profile wipe-history` |
| **Home Manager conflicts with existing dotfiles** | Duplicate or broken configs | Test each config migration individually. Keep existing configs as source, HM only manages symlinks |
| **macOS aarch64** | Different system | flake supports multiple systems natively via different pkgs imports |
| **Learning curve** | Slower migration | Phase 1 is simple (just packages). Phase 2+ adds config management. Can stop at any phase. |
| **Nix removal if needed** | Can't uninstall easily | Single-user install is removable: `rm -rf /nix ~/.nix-profile ~/.nix-defexpr ~/.nix-channels ~/.config/nix` |

---

## Appendix: Cancellation / Rollback

If the migration proves problematic:

```bash
# View home-manager generations
home-manager generations

# Rollback to previous generation
home-manager switch --rollback

# Or a specific generation
nix profile rollback --to <generation-id>

# To fully remove home-manager and go back to dnf/brew:
rm -rf ~/.config/home-manager
rm -rf ~/.local/state/home-manager
# Then re-run the original install script
./fedora/install.sh
```
