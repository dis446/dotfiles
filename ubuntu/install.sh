#!/bin/bash

mkdir -p "$HOME/.config" "$HOME/.config/ghostty"
link_target() {
  local src="$1"
  local dest="$2"
  rm -rf "$dest"
  ln -s "$src" "$dest"
}

link_target "$HOME/dotfiles/nvim" "$HOME/.config/nvim"
link_target "$HOME/dotfiles/ghostty/linux/config" "$HOME/.config/ghostty/config"
link_target "$HOME/dotfiles/tmux" "$HOME/.config/tmux"
link_target "$HOME/dotfiles/zellij" "$HOME/.config/zellij"
link_target "$HOME/dotfiles/zed" "$HOME/.config/zed"
link_target "$HOME/dotfiles/ubuntu/bash_alias" "$HOME/.bash_aliases"
link_target "$HOME/dotfiles/pi/agent" "$HOME/.agents"
link_target "$HOME/dotfiles/pi" "$HOME/.pi"
link_target "$HOME/dotfiles/.ai" "$HOME/.ai"
link_target "$HOME/dotfiles/claude" "$HOME/.claude"
link_target "$HOME/dotfiles/.editorconfig" "$HOME/.editorconfig"
mkdir -p "$HOME/.config/lazygit"
ln -sf "$HOME/dotfiles/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"


# Install tmux plugins
git clone https://github.com/tmux-plugins/tpm "$HOME/.config/tmux/plugins/tpm" 2>/dev/null || true
git clone https://github.com/tmux-plugins/tmux-resurrect "$HOME/.config/tmux/plugins/tmux-resurrect" 2>/dev/null || true
git clone https://github.com/tmux-plugins/tmux-continuum "$HOME/.config/tmux/plugins/tmux-continuum" 2>/dev/null || true

