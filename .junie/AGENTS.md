# Agent Development Guide

This document provides project-specific information for developers and AI agents working on this dotfiles repository.

## Build/Configuration Instructions

The project does not use a traditional build system. Configuration is applied by symlinking files from this repository into the appropriate system locations (usually `~` or `~/.config`).

### Symlink Mechanism
Most setup scripts use a `link_target` helper function to ensure idempotency:
```bash
link_target() {
  local src="$1"
  local dest="$2"
  rm -rf "$dest"
  ln -s "$src" "$dest"
}
```
This helper explicitly removes the destination before creating the link, ensuring that existing files or directories are replaced rather than merged.

### Setup Scripts
- **Fedora**: `fedora/install.sh` (Includes package installation via `dnf`).
- **Other OS**: `nobara/setup`, `macos/setup`, `ubuntu/setup.sh` (Mainly symlinking).
- **Location**: The repository is expected to be cloned to `~/dotfiles`.

## Testing Information

### Verification Strategy
Since there is no compiled code, "testing" primarily involves verifying that symlinks are correctly created and pointing to the intended sources.

### Running a Verification Test
You can use a script similar to the following to verify the symlinking logic:

```bash
#!/bin/bash
DOTFILES_DIR="$HOME/dotfiles"
TARGET="$HOME/.config/nvim"

if [ -L "$TARGET" ] && [ "$(readlink -f "$TARGET")" == "$(readlink -f "$DOTFILES_DIR/nvim")" ]; then
    echo "✓ Symlink verified"
else
    echo "✗ Symlink missing or incorrect"
fi
```

### Guidelines for New Tests
- Use temporary directories (`mktemp -d`) for destructive tests of setup scripts.
- Verify idempotency by running the link/setup logic twice.
- Always check that `readlink -f` on the destination matches the absolute path of the source.

## Additional Development Information

### Shell Alias Architecture
Aliases are modularized and shared across platforms:
1. **Shared Aliases**: Located in `bash/` (e.g., `git_aliases`, `docker_aliases`).
2. **Auto-loading**: The `bashrc` or OS-specific `bash_alias` loops over `~/dotfiles/bash/*` and sources every file.
3. **OS-Specific**: `<os>/bash_alias` can override shared aliases.

### Neovim Configuration
- **Structure**: Lua-based, using `lazy.nvim`.
- **Namespace**: `lua/dis446/`.
- **Plugin Management**: One file per plugin in `lua/dis446/plugins/`.
- **Unified Keybinds**: `nvim/UNIFIED-KEYBINDS.md` is the source of truth for bindings shared with IdeaVim.

### Conventions
- **Idempotency**: All installation scripts must be idempotent.
- **Secrets**: Files containing `secret` in their name (e.g., `bash/secret_aliases`) are gitignored and should never be committed.
- **Pathing**: Use `$HOME/dotfiles` for absolute paths in scripts.
