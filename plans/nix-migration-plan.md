# Nix + Home Manager Migration Plan

> Regenerated 2026-09-23. Supersedes the previous draft, which assumed a Nobara
> start and a single-user `--no-daemon` Nix install. Neither matches the current
> Fedora 44 Workstation host.
>
> Reference: a review of a friend's macOS `nix-darwin` + `home-manager` config.
> Its module shape, out-of-store symlink pattern, and update/cleanup scripts are
> the model below. Its macOS-only layers (nix-darwin, nix-homebrew, launchd) do
> not exist on Linux and are dropped.

---

## 1. Decision

Adopt **standalone Home Manager driven by a flake**. The repo stays at
`~/dotfiles`.

- **Linux (Fedora, Nobara, Ubuntu):** standalone `home-manager`. No NixOS, no
  nix-darwin (nix-darwin is macOS-only and has no Linux equivalent).
- **macOS:** optional later track — nix-darwin + home-manager, sharing the same
  `home/` modules. Tracked separately in §10.
- **One flake, one `hosts` map, a `role` tag** (`personal` / `work`) gates
  machine-specific packages.
- **Nix owns:** CLI tools, dev toolchains, and out-of-store symlinks for pure
  config dirs. Versions pin via `flake.lock`.
- **Imperative, stays in the per-OS install script:** dnf/copr/rpmfusion,
  `dnf.conf`, flatpak GUI apps, system-level systemd units, kernel/codecs.
- **Out-of-store symlinks** (`mkOutOfStoreSymlink`) so config edits are live and
  need no rebuild.

Why not the alternatives:

| Option | Verdict |
| --- | --- |
| `nix profile install` only | No lockfile pinning, no config management, manual per machine. Rejected as end state. |
| Flake + `nix profile` | Locks packages but still no config management. Rejected as end state. |
| **Flake + standalone Home Manager** | Declarative packages **and** config, pins via `flake.lock`, rollback via generations, works on Fedora without NixOS. **Chosen.** |
| NixOS | Would replace Fedora. Out of scope — the point is to keep Fedora. |
| nix-darwin on Linux | Does not exist. Only macOS. |

---

## 2. Current state (verified 2026-09-23)

| Item | Status |
| --- | --- |
| Host | Fedora Linux 44 (Workstation Edition), `x86_64` |
| `nix` on PATH | ✅ Determinate Nix 3.22.5 (Nix 2.35.2); `/etc/profile.d/nix.sh` covers login shells — non-login shells need explicit PATH (Phase 3) |
| `/nix` | ✅ present |
| `~/.config/nix/nix.conf` | ➖ not used — Determinate manages experimental features itself |
| `flake.nix` / `home/` in repo | ✅ `flake.nix`, `flake.lock`, `home/{default,packages,dotfiles,bash,git,npm-globals}.nix` (Phase 1-4) |
| `~/.local/state/home-manager` | ✅ active 2026-09-24 — packages, out-of-store config links, HM-owned `~/.bashrc` |
| Repo checked out at | `~/dotfiles` (the flake and symlinks bake this absolute path) |
| Git tree | Phase 1 files committed |

**Phase 0 complete** (Determinate multi-user install, verified 2026-09-24).
**Phase 1 complete** — first `home-manager switch` activated generation 1; all
packages resolve from `~/.nix-profile/bin` (`nvim` 0.12.5, `herdr` 0.9.1, node
24, temurin JDK 21).

### 2.1 What the install scripts do (after Phase 6)

The Linux scripts are **system-only** now — CLI tools, runtimes, and config
links all come from Home Manager.

| OS | Script | Handles |
| --- | --- | --- |
| Fedora | `fedora/install.sh` (114 lines) | RPM Fusion, `dnf.conf`, zram, `mpv-libs`, flatpak (ExtensionManager, Flatseal, Bruno), herdr systemd unit, `pi`/`.ai`/`claude` symlinks, gitlab-tui build, podman socket, pi plugins |
| Nobara | `nobara/install.sh` (162 lines) | Fedora set + `nobara-sync`, Zed app, noize (flatpak instead of Bruno) |
| macOS | `macos/install.sh` (28 lines) | symlinks only; `macos/Brewfile` still lists brew formulae (macOS track) |
| Ubuntu | `ubuntu/install.sh` | `pi`/`.ai`/`claude` symlinks only (CLI tools + config via Home Manager) |

All four scripts symlink the same config set: `nvim`, `ghostty`, `zellij`,
`zed`, `pi` + `.ai`, `claude`, `herdr/config.toml`, `.editorconfig`, `lazygit`,
`ideavimrc`, `gradle.properties`, and the OS shell rc.

### 2.2 Reference architecture (friend's macOS config)

Load-bearing ideas, each portable to Linux:

1. `hosts` attrset: hostname → `{ username, role, system }`; `role` gates
   packages; `mkHost` asserts the role is in an allowed list. Never branch on
   hostname strings.
2. `specialArgs` / `extraSpecialArgs` thread `username`, `role`, and inputs into
   every module.
3. `home/dotfiles.nix` uses `mkOutOfStoreSymlink` to link config dirs out of the
   nix store — edits stay live, a rebuild is only needed when adding/removing a
   top-level link.
4. **File-level** links (not dir links) where the app writes mutable state next
   to its config (zed, herdr, dbeaver, claude).
5. Home Manager generates the shell rc; the repo rc is `source`d from it.
6. `home/scripts/`: `update.sh`, `nix-pull.sh`, `cleanup.sh`, `lib.sh`
   (`say`/`ok`/`alert`, `require_clean_tree`).
7. `home.activation` npm-global install for the pi agent binary, idempotent.
8. `flake.lock` committed; versions move only on `nix flake update`;
   `nix flake check` is the only gate (no CI).
9. A written list of things deliberately managed outside nix (rustup, mason LSP,
   claude plugins, herdr plugins, pi plugins).

---

## 3. Corrections to the previous draft

These three were wrong and are fixed here:

1. **`xdg.configFile."nvim".source = ./nvim; recursive = true;` copies into the
   read-only nix store.** nvim rewrites `lazy-lock.json` on plugin update, so
   that breaks the write or forces a rebuild every time. Use the `link` helper
   (`mkOutOfStoreSymlink`) instead. Same for zed, zellij, lazygit.
2. **Do not migrate aliases into `programs.bash.shellAliases`.** The `bash/`
   files are cross-OS and edited often. HM should generate `~/.bashrc` and
   source the repo rc files, keeping aliases editable without a rebuild.
3. **herdr is now in nixpkgs** (the reference `packages.nix` lists it). Verify
   with `nix search nixpkgs herdr`; if present, drop the mise install and the
   mise-built binary path.

Also fixed: the previous draft's single-user Nix install is replaced by the
Determinate multi-user installer (§4), and `~/.bashrc` ownership is resolved in
§6.

---

## 4. Phase 0 — Install Nix (Determinate, multi-user)

Use the Determinate Systems installer. It sets up the daemon, `/nix`, flake +
`nix-command` features, and `/etc/profile.d` sourcing — the same installer the
reference config uses on macOS.

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

Verify:

```bash
nix --version
nix flake --help >/dev/null && echo "flakes ok"
ls -ld /nix
```

Notes:

- Non-login, non-interactive shells (scripts, agents) do not read
  `/etc/profile.d`. Add `$HOME/.nix-profile/bin` to PATH from the generated
  `~/.bashrc` in Phase 3, or rely on `home.sessionPath`.
- Do **not** use the single-user `--no-daemon` install. It creates store
  permission and PATH papercuts and cannot be shared across users.

---

## 5. Phase 1 — Scaffold the flake and `home/`

Files to create:

```
flake.nix
home/default.nix
home/packages.nix
home/dotfiles.nix
home/bash.nix
home/git.nix
home/npm-globals.nix
scripts/nix-lib.sh
scripts/nix-update.sh
scripts/nix-pull.sh
scripts/nix-cleanup.sh
```

### 5.1 `flake.nix`

```nix
{
  description = "dis446 dotfiles — flake + standalone Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      # Semantic tags, not hostname string comparisons. mkHome asserts
      # membership so a new host cannot silently select an unknown role.
      roles = [ "personal" "work" ];

      # One entry per machine. `platform` picks the OS rc + extra packages.
      hosts = {
        "fedora" = { username = "guddy"; role = "work";     platform = "fedora"; system = "x86_64-linux"; };
        "nobara" = { username = "guddy"; role = "personal"; platform = "nobara"; system = "x86_64-linux"; };
        "ubuntu" = { username = "guddy"; role = "personal"; platform = "ubuntu"; system = "x86_64-linux"; };
      };

      mkHome = hostname: { username, role, platform, system }:
        assert nixpkgs.lib.assertOneOf "role (host ${hostname})" role roles;
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          extraSpecialArgs = { inherit username role platform; };
          modules = [ ./home ];
        };
    in
    {
      homeConfigurations = nixpkgs.lib.mapAttrs'
        (hostname: cfg:
          nixpkgs.lib.nameValuePair "${cfg.username}@${hostname}" (mkHome hostname cfg))
        hosts;
    };
}
```

### 5.2 `home/default.nix`

```nix
{ username, ... }:
{
  imports = [
    ./packages.nix
    ./dotfiles.nix
    ./bash.nix
    ./git.nix
    ./npm-globals.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  # Version at time of adoption. Do not bump casually.
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
```

### 5.3 First switch

```bash
nix flake check ~/dotfiles
nix run home-manager/master -- switch --flake ~/dotfiles#guddy@fedora
```

After this, `home-manager` is on PATH; later switches are:

```bash
home-manager switch --flake ~/dotfiles#guddy@fedora
```

---

## 6. Phase 2/3 — Configs and the shell

### 6.1 `home/dotfiles.nix` (out-of-store links)

```nix
{ config, ... }:
let
  # Absolute repo path — the links bake it; the repo must stay at ~/dotfiles.
  repo = "${config.home.homeDirectory}/dotfiles";
  link = path: config.lib.file.mkOutOfStoreSymlink "${repo}/${path}";
in
{
  xdg.configFile = {
    # Live dir link — lazy.nvim rewrites lazy-lock.json here.
    "nvim".source = link "nvim";
    "zellij".source = link "zellij";
    "ghostty/config".source = link "ghostty/linux/config.ghostty";
    "lazygit/config.yml".source = link "lazygit/config.yml";
    # File-level: herdr writes sockets/logs/session state beside config.toml.
    "herdr/config.toml".source = link "herdr/config.toml";
    # File-level: Zed writes mutable state (prompts/extensions) next to config.
    "zed/settings.json".source = link "zed/settings.json";
    "zed/keymap.json".source = link "zed/keymap.json";
    "zed/themes".source = link "zed/themes";
  };

  home.file = {
    ".editorconfig".source = link ".editorconfig";
    ".ideavimrc".source = link "intellij/ideavimrc";
    ".gradle/gradle.properties".source = link "gradle/gradle.properties";
  };
}
```

Left imperative (not HM-managed), with the reason:

| Path | Why not HM |
| --- | --- |
| `~/.pi`, `~/.agents` | whole-dir symlinks into `pi/`; the dir carries runtime state (sessions, npm, plugin cache). Restructuring to file-level links is optional Phase 5 work. |
| `~/.claude` | same — runtime state alongside config. |
| `bash/secret_aliases`, any `secret*` | gitignored; HM must not manage secrets. Sourced imperatively. |
| `/etc/dnf/dnf.conf`, `zram-generator.conf` | system-level, sudo. |
| (moved to `home/herdr.nix`) | systemd user unit is now `systemd.user.services.herdr-server` (Phase 5b). |

### 6.2 `home/bash.nix` (HM owns `~/.bashrc`)

```nix
{ platform, ... }:
{
  programs.bash = {
    enable = true;
    enableCompletion = true;
    # Alias files stay in the repo, editable without a rebuild. The OS rc
    # sources ~/dotfiles/bash/* plus the OS-specific aliases + env.
    bashrcExtra = ''
      [ -f "$HOME/dotfiles/${platform}/bashrc" ] && source "$HOME/dotfiles/${platform}/bashrc"
    '';
  };
}
```

**Ownership handover:** `fedora/install.sh` currently does
`link_target fedora/bashrc ~/.bashrc`. Delete that line. Home Manager now owns
`~/.bashrc`; the repo rc is sourced from it. Do not do both — they will fight.

`macos` uses zsh; the macOS track (§10) mirrors this with `programs.zsh`.

### 6.3 `home/git.nix`

```nix
{ config, ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "Tsetsen-erdene Ganbaatar";
      user.email = "dis446@yahoo.com";
      init.defaultBranch = "main";
      pull.rebase = true;
      diff.tool = "nvimdiff";
      difftool.nvimdiff.cmd = "nvim -d \"$LOCAL\" \"$REMOTE\"";
      merge.tool = "nvimdiff";
      mergetool.nvimdiff.cmd = "nvim -d \"$LOCAL\" \"$BASE\" \"$REMOTE\" \"$MERGED\"";
    };
    # Machine-local work identity (untracked); a missing file is ignored by git.
    includes = [ { path = "${config.home.homeDirectory}/.gitconfig-local"; } ];
  };
}
```

Home Manager writes `~/.config/git/config` (XDG), **not** `~/.gitconfig`.
Git later-reads `~/.gitconfig`, so a stale one shadows XDG — the install
scripts must stop writing it (`git config --global …` lines removed).

The work `includeIf` (which names an employer path) never enters the repo. It
lives in `~/.gitconfig-local`, included by HM. A missing include path is
silently ignored, so a fresh machine without it still works.

---

## 7. Phase 4 — Packages

### 7.1 `home/packages.nix`

```nix
{ lib, pkgs, role, ... }:
{
  home.packages = with pkgs; [
    # Version control / editors
    git vim neovim lazygit

    # Terminal / system
    bat jq htop ncdu pydf fastfetch rsync speedtest-cli ripgrep fd fzf
    zellij herdr

    # Version managers / runtimes
    mise nodejs_24 temurin-bin-21

    # Cloud / k8s / containers (CLIs only; daemon is system-managed)
    kubectl podman podman-compose

    # Build tools
    go gcc gnumake
  ]
  ++ lib.optionals (role == "work") [ azure-cli glab gh ]
  ++ lib.optionals (pkgs.stdenv.isLinux) [ ghostty ];
}
```

Package mapping from the current scripts:

| Today | Source | Nix |
| --- | --- | --- |
| git, vim, neovim, lazygit, htop, ncdu, speedtest-cli, fastfetch, golang, kubectl, glab, azure-cli | dnf | `git vim neovim lazygit htop ncdu speedtest-cli fastfetch go kubectl glab azure-cli` |
| podman-docker | dnf | `podman` (+ see §7.3 for the `docker` shim) |
| mise | copr/dnf | `mise` (binaries only; see §7.2) |
| pydf | pip | `pydf` |
| node 24, temurin-21 | `mise use -g` | `nodejs_24`, `temurin-bin-21` |
| herdr | `mise use -g` | `herdr` (verify it is in nixpkgs-unstable) |
| zellij | cargo (Nobara) | `zellij` |
| ghostty | copr (Fedora) | `ghostty` on Linux |
| bat, jq, rsync, podman-compose | brew (macOS) | `bat jq rsync podman-compose` |
| gcc-c++, make | dnf | `gcc gnumake` |
| mpv-libs | dnf | leave to dnf (media codec lib, not a dev tool) |
| ExtensionManager, Flatseal, Bruno | flatpak | **stays flatpak** — see §8 |
| pi-coding-agent | npm -g | `home.activation` — see §7.4 |

### 7.2 mise

Keep mise only if per-project version overrides are actually used (`mise.toml`
currently pins only `node = "24"`, which nix now provides). If it is only
global, drop it entirely, as the reference config did. If kept:

- Nix provides the global default (Node 24, Java 21).
- `mise.toml` in a project overrides per repo; mise shims shadow the nix
  binaries inside that directory.
- Drop the `mise use -g node@24 / java@temurin-21 / herdr` lines.

### 7.3 podman-docker

`podman` from nix does not ship the `docker` wrapper. Either add a shell alias
`docker = "podman"`, or keep `podman-docker` from dnf. Prefer the alias.

### 7.4 `home/npm-globals.nix` (pi agent)

```nix
{ lib, pkgs, ... }:
{
  home.activation.installNpmGlobals = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${pkgs.nodejs_24}/bin:$HOME/.local/bin:$PATH"
    export npm_config_prefix="$HOME/.local"
    npm ls -g @earendil-works/pi-coding-agent 2>/dev/null 1>&2 \
      || npm install -g --ignore-scripts @earendil-works/pi-coding-agent
  '';
}
```

Prefix is `~/.local` (not `~/.npm-global`) to match the existing install at
`~/.local/bin/pi`; a different prefix would leave two pi binaries on PATH.
`npm_config_prefix` is an env var, not `npm config set`, so activation never
rewrites `~/.npmrc` (which holds a registry auth token). Idempotent: only
installs when missing; `update.sh` bumps to `@latest`.

pi **plugins** (`context-mode`, `pi-subagents`, `ponytail`,
`@juicesharp/rpiv-ask-user-question`) stay agent-managed via `pi install npm:...`
— never declared in nix, per the reference config's rule. Run the plugin
installs once in `install.sh` (or let the agent own them).

---

## 8. What stays outside Nix

| Thing | Why | Where |
| --- | --- | --- |
| `fedora/dnf.conf`, `zram-generator.conf` | system-level, sudo | `fedora/install.sh` |
| RPM Fusion + copr repos | system package sources | `fedora/install.sh` |
| flatpak apps (ExtensionManager, Flatseal, Bruno) | GUI desktop apps; HM has no flatpak module | `fedora/install.sh` |
| `mpv-libs` | media codec lib | dnf |
| System systemd units, kernel, drivers | not user-level | `fedora/install.sh` |
| `herdr` user unit | moved to HM (Phase 5b) — no longer outside nix | `home/herdr.nix` |
| pi plugins, herdr plugins | tool-managed plugin installs | tool CLIs |
| nvim mason LSP servers | nvim owns `~/.local/share/nvim/mason` | nvim |
| `bash/secret_aliases`, `secret*` | secrets, gitignored | sourced imperatively |
| `pi/`, `claude/` runtime state | sessions, caches | imperative symlinks |
| `hyprland/`, `firefox/`, `skyrim/`, `WindowsPowerShell/`, `Templates/`, `Wallpapers/` | out of scope for this migration | as-is |
| macOS GUI apps | casks via nix-homebrew on the macOS track | §10 |

---

## 9. Phase 5/6 — Scripts and install-script shrink

### 9.1 Helper scripts

Mirror the reference repo, adapted for standalone HM (no `sudo
darwin-rebuild`):

- `scripts/nix-lib.sh` — `say`/`ok`/`alert`, `require_clean_tree`.
- `scripts/nix-update.sh` — `git pull --ff-only`, `nix flake update`,
  `nix flake check`, `home-manager switch --flake ~/dotfiles`,
  `npm install -g @earendil-works/pi-coding-agent@latest`, commit + push
  `flake.lock`.
- `scripts/nix-pull.sh` — pull; rebuild only if `.nix` or `flake.lock` changed.
- `scripts/nix-cleanup.sh` — `nix-collect-garbage --delete-older-than 14d`,
  `sudo nix-collect-garbage --delete-older-than 14d`, `nix store optimise`.
- `bash/nix_aliases` — exposes `nix-update` / `nix-pull` / `nix-cleanup` /
  `nix-e2e` (sourced by the OS bashrc, so live without a rebuild).
- `scripts/e2e-nix-container.sh` — boots the flake from scratch in a throwaway
  container (single-user Nix) and asserts tools, links, git identity, bashrc,
  aliases, plus the opposite-role switch. `E2E_DISTRO=fedora` (default, Fedora
  44 / `@fedora`) or `E2E_DISTRO=ubuntu` (Ubuntu 24.04 / `@ubuntu`). Keeps the
  container on failure; `E2E_KEEP=1` keeps it on success, `E2E_ROLE_TEST=0`
  skips the role test.

The reference repo already encodes the two important guards: `require_clean_tree`
before a pull/update (a dirty tree breaks `git pull --ff-only`), and
`nix flake check` before every switch (there is no CI — the local check is the
gate).

`~/.scripts` linking is optional; aliases in `bash/general_aliases` work too.

### 9.2 Shrink the install scripts

After the first successful switch, remove from `fedora/install.sh` and
`nobara/install.sh`:

- copr enable lines for `jdxcode/mise`, `dejan/lazygit`, `scottames/ghostty`
- `dnf install` for every tool now in nix
- `pip install pydf`, `cargo install cargo-binstall`, `cargo binstall zellij`
- `mise use -g node@24 / java@temurin-21 / herdr`
- `npm install -g @earendil-works/pi-coding-agent` (now HM activation)
- the `~/.bashrc` symlink (HM owns it), and the `lazygit`/`ideavimrc`/`gradle`
  symlinks if HM now owns those targets

Keep: RPM Fusion, `dnf.conf`, dnf for system packages, zram, flatpak, the herdr
systemd unit, and the `pi/`/`claude/` symlinks.

---

## 10. macOS track (optional, later)

`make` the same `home/` modules serve macOS by adding `darwinConfigurations`
alongside `homeConfigurations`, exactly as the reference config does:

- Add inputs `nix-darwin` and `nix-homebrew` (taps pinned as flake inputs).
- `darwin/` module: system settings, fonts, declarative brew casks
  (`homebrew.casks`, `cleanup = "uninstall"`), `nix.enable = false` (Determinate
  owns the daemon).
- Home Manager via `home-manager.darwinModules.home-manager`,
  `useGlobalPkgs = true`, `backupFileExtension = "hm-backup"`.
- macOS home path is `/Users/${username}` — branch `home.homeDirectory` on
  `system`.
- zsh instead of bash: `programs.zsh` + `oh-my-zsh`, sourcing `macos/zshrc`.
- GUI apps stay casks.

This is additive: the Linux track does not depend on it.

---

## 11. Risks & mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Nix not on PATH in non-login shells | agent/scripts cannot run `nix` | `/etc/profile.d` from Determinate covers login shells; add `~/.nix-profile/bin` in the generated `~/.bashrc` or `home.sessionPath` |
| `~/.bashrc` double ownership | broken shell | HM owns it from Phase 3; delete the install-script symlink |
| Copying configs into the store | `lazy-lock.json` writes break | always `mkOutOfStoreSymlink`, never `source = ./dir` |
| herdr binary path change | systemd unit points at the old mise path | update `HERDR_BIN_PATH` or drop it and rely on PATH when moving herdr to nix |
| `/nix/store` disk growth | disk pressure | `nix-collect-garbage --delete-older-than 14d`, `nix store optimise` (§9.1) |
| Missing nixpkgs package | tool unavailable | check search.nixos.org; use an overlay, or keep it imperative |
| Version differs from dnf | tool behavior changes | nixpkgs-unstable; pin via `flake.lock` |
| Work identity / secrets leak into nix | identifier-hygiene violation | role-gated, untracked `secret*`; pre-commit `check-identifiers.sh` |
| Multi-host drift | machines diverge | one `hosts` map, `role` gating, `flake.lock` committed |
| Learning curve | slower rollout | phases are independently stoppable; stop after Phase 1 with packages only |

---

## 12. Rollback

```bash
# List / roll back home-manager generations
home-manager generations
home-manager switch --rollback

# Remove Nix entirely (Determinate)
/nix/nix-installer uninstall
rm -rf ~/.config/nix ~/.local/state/home-manager

# Then re-run the original install script
~/dotfiles/fedora/install.sh
```

The per-OS install scripts keep working at every phase — cut over package lines
only after the corresponding `home-manager switch` succeeds.

---

## 13. Rollout checklist

- [x] Phase 0 — install Determinate Nix; verify `nix --version`, flakes, `/nix`
- [x] Phase 1 — `flake.nix`, `home/default.nix`, `home/packages.nix`; first switch; verify tools on PATH
- [x] Phase 2 — `home/dotfiles.nix` out-of-store links; remove matching install-script symlinks
- [x] Phase 3 — `home/bash.nix`; delete the `~/.bashrc` symlink; verify aliases + env still load
- [x] Phase 4 — `home/git.nix`, `home/npm-globals.nix`; verify git identity and pi on PATH
- [x] Phase 5 — helper scripts (`scripts/nix-{lib,update,pull,cleanup}.sh` + `bash/nix_aliases`); herdr unit `HERDR_BIN_PATH`/`PATH` fixed to nix
- [x] Phase 5b — herdr unit moved to `home/herdr.nix` (`systemd.user.services.herdr-server`, nix binary). Apply with `home-manager switch` from a plain terminal — HM's `sd-switch` **restarts changed units**, so switching while inside herdr restarts the server and ends that session.
- [x] Phase 6 — shrunk `fedora/install.sh` (130→114) and `nobara/install.sh` (182→162): dropped copr, dnf tool installs, pip, cargo, `mise use -g`, npm. Kept RPM Fusion, `mpv-libs`, flatpak, herdr unit, `pi`/`.ai`/`claude` links. Full sudo/dnf re-run not executed (needs password, restarts zram/herdr).
- [x] E2E (2026-09-24) — automated as `scripts/e2e-nix-container.sh`, which passes end to end: fresh Fedora 44 podman container (rootless, single-user Nix 2.35.2): clone → `home-manager switch --flake .#guddy@fedora` produced the **byte-identical generation** `/nix/store/d200m55sw67x6k91lynq5p8xidanw5s2-home-manager-generation` as the host. `nix flake check` passed; all 23 tools resolved from `~/.nix-profile/bin`; out-of-store links resolved into `~/dotfiles`; pi installed via the npm activation; role gating verified (`guddy@ubuntu` → no azure-cli/glab/gh) and the Ubuntu bashrc fallback worked; `~/.bashrc`/`~/.bash_profile` skel conflicts backed up; systemd absent → skipped cleanly. Container `/nix` = 5.5 GB. Container removed after the run. (install.sh's system steps are not container-testable: no systemd/sudo/zram.)
- [x] E2E Ubuntu (2026-09-24) — `E2E_DISTRO=ubuntu` on a fresh Ubuntu 24.04 container: `home-manager switch --flake .#guddy@ubuntu` passed; role=personal (no azure-cli/glab/gh) and the ubuntu bashrc fallback (`bash/*` + `ubuntu/bash_aliases`) verified; the role test switched to `@fedora` and confirmed work tools present. Container removed.
- [ ] Phase 7 — Nobara verification (still pending: run on the actual personal machine)
- [ ] Phase 8 — macOS track (optional)
- [ ] Docs — update `AGENTS.md` with the nix commands and the outside-nix list
