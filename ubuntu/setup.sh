#!/bin/bash

mkdir -p "$HOME/.config" "$HOME/.config/ghostty"
ln -sf "$HOME/dotfiles/nvim" "$HOME/.config/nvim"
ln -sf "$HOME/dotfiles/ghostty/linux/config" "$HOME/.config/ghostty/config"
ln -sf "$HOME/dotfiles/zellij" "$HOME/.config/zellij"
ln -sf "$HOME/dotfiles/ubuntu/bash_alias" "$HOME/.bash_aliases"
ln -sf "$HOME/dotfiles/pi/agent" "$HOME/.agents"
ln -sf "$HOME/dotfiles/pi" "$HOME/.pi"
ln -sf "$HOME/dotfiles/.ai" "$HOME/.ai"
