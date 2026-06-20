# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal dotfiles repo. There is no build, test, or lint step — changes are applied by symlinking files into place and re-sourcing the shell. The repo is expected to live at `~/dotfiles` (paths are hardcoded to `$HOME/dotfiles` throughout the setup scripts).

## Applying changes

Each OS/distro has its own idempotent install script that symlinks config into `$HOME` and `$HOME/.config`. They share a `link_target()` helper that does `rm -rf "$dest"` before `ln -s` — so it replaces existing files/dirs, not merges:

- `fedora/install.sh` — fullest script: enables COPR repos, installs packages via `dnf`, links `fedora/bashrc` → `~/.bashrc`, sets up `mise` (node, java), and configures git.
- `nobara/setup`, `macos/setup`, `ubuntu/setup.sh` — link-only variants (no package install). macOS links `macos/zshrc` → `~/.zshrc`; Ubuntu links `ubuntu/bash_alias` → `~/.bash_aliases`.
- `macos/Brewfile` — Homebrew bundle for macOS.

To pick up alias changes after editing, re-source the shell (`src` alias = `source ~/.bashrc`).

Symlinks created by all setup scripts: `nvim`→`~/.config/nvim`, `zellij`→`~/.config/zellij`, ghostty config, `lazygit/config.yml`, the Pi agent dirs (`pi/agent`→`~/.agents`, `pi`→`~/.pi`, `.ai`→`~/.ai`), Claude Code (`claude`→`~/.claude`), and IntelliJ IdeaVim config (`intellij/ideavimrc`→`~/.ideavimrc`).

`claude/` and the `pi/` dirs follow the same convention: the whole directory is symlinked into `$HOME`, but only hand-managed config is tracked — runtime state and secrets are gitignored. For `claude/` the `.gitignore` uses a whitelist (`claude/*` ignored, then `settings.json`, `keybindings.json`, `CLAUDE.md`, `hooks/`, `commands/`, `agents/`, `skills/` re-included), so anything Claude Code writes at runtime (`projects/`, `sessions/`, `plugins/`, `.credentials.json`, `history.jsonl`, caches) stays out of git automatically.

`intellij/` follows a different pattern: IntelliJ's config lives in a version-specific path (`~/.config/JetBrains/IntelliJIdea2026.1/`) and mixes portable config with machine state, so the entire directory cannot be symlinked. Instead, only `.ideavimrc` is symlinked to `~/.ideavimrc`. JetBrains Settings Sync handles cross-machine sync for everything else (keymaps, codestyles, options). The `intellij/keymaps/` directory holds reference copies of custom keymaps for version history.

## Shell alias architecture

The per-OS `bashrc`/`bash_alias` files all do the same thing: loop over `~/dotfiles/bash/*` and source every file, then source the OS-specific alias file. So:

- **Cross-platform aliases** live in `bash/` split by topic (`git_aliases`, `docker_aliases`, `podman_aliases`, `general_aliases`, `systemd_aliases`, `work_aliases`, etc.). Add a new topic file here and it is auto-sourced everywhere.
- **OS-specific aliases** live in `<os>/bash_alias` (or `<os>/bash_aliases`) and are sourced after the shared set, so they can override.
- `WindowsPowerShell/*.ps1` mirror the same idea for PowerShell.

`bash/secret_aliases` holds machine-local credentials and is gitignored via the `**/secret**` pattern in `.gitignore` — never commit it or move its contents into a tracked file.

## Neovim config

The largest config in the repo. Lua, lazy.nvim-based, namespaced under `lua/dis446/`. `init.lua` loads `dis446.core` then `dis446.lazy`. Plugins are one-file-per-plugin under `lua/dis446/plugins/`. See `nvim/README.md` for the full keymap/plugin reference and `nvim/CHEATSHEET.md`. `nvim/lazy-lock.json` pins plugin versions — keep it committed.

The `nvim/lua/dis446/dbee/` modules implement repo-scoped database connections (nvim-dbee) loaded from a target repo's `.nvim/dbee.lua`, with secrets pulled from ignored `.env*` files — config for *other* repos, not this one.

## Conventions

- Setup scripts are not `set -e`-guarded and use `rm -rf` in `link_target`; when editing them, preserve idempotency and double-check destination paths.
- When adding a tool's config, follow the existing pattern: store it under a topic/OS dir here and add the symlink line to each relevant setup script (they are maintained in parallel, not generated).
