#!/bin/bash
# Ubuntu: symlinks only. CLI tools, runtimes, and config links (nvim, ghostty,
# zellij, zed, lazygit, .editorconfig, ~/.bashrc) come from Home Manager — the
# nix flake. See plans/nix-migration-plan.md.

mkdir -p "$HOME/.config"
link_target() {
  local src="$1"
  local dest="$2"
  if [ ! -e "$src" ] && [ ! -L "$src" ]; then
    echo "WARN: source missing, skipping symlink: $src" >&2
    return 1
  fi
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  ln -s "$src" "$dest"
}

# pi / claude agent configs stay imperative (they carry runtime state).
link_target "$HOME/dotfiles/pi/agent" "$HOME/.agents"
link_target "$HOME/dotfiles/pi" "$HOME/.pi"
link_target "$HOME/dotfiles/.ai" "$HOME/.ai"
link_target "$HOME/dotfiles/claude" "$HOME/.claude"
