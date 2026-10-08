#!/usr/bin/env bash
mkdir -p "$HOME/.config" "$HOME/.config/ghostty"
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

# The macOS track is still pre-Home-Manager (plans/nix-migration-plan.md §10), so
# unlike the Linux scripts it symlinks the whole config set itself.
link_target "$HOME/dotfiles/nvim" "$HOME/.config/nvim"
link_target "$HOME/dotfiles/ghostty/macos/config" "$HOME/.config/ghostty/config"
# File-level (not a dir link): Zed writes mutable state next to its config.
link_target "$HOME/dotfiles/zed/settings.json" "$HOME/.config/zed/settings.json"
link_target "$HOME/dotfiles/zed/keymap.json" "$HOME/.config/zed/keymap.json"
link_target "$HOME/dotfiles/zed/themes" "$HOME/.config/zed/themes"
link_target "$HOME/dotfiles/pi/agent" "$HOME/.agents"
link_target "$HOME/dotfiles/pi" "$HOME/.pi"
link_target "$HOME/dotfiles/.ai" "$HOME/.ai"
link_target "$HOME/dotfiles/claude" "$HOME/.claude"
# orca user config dir (~/.orca holds keybindings.json overrides).
# ~/.config/orca is Electron app data holding a private key + tokens: never linked.
link_target "$HOME/dotfiles/orca" "$HOME/.orca"
link_target "$HOME/dotfiles/.editorconfig" "$HOME/.editorconfig"
link_target "$HOME/dotfiles/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
link_target "$HOME/dotfiles/macos/zshrc" "$HOME/.zshrc"

# Apply the keybinding to a running herdr server immediately (no-op on fresh
# installs). The herdr user unit itself only exists on Linux (home/herdr.nix).
herdr server reload-config >/dev/null 2>&1 || true

[ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc"

# pi agent binary is installed by the Home Manager activation on Linux; this
# track is pre-HM, so install it via npm if missing. Plugins are agent-managed.
if ! command -v pi >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  npm_config_prefix="$HOME/.local" npm install -g --ignore-scripts @earendil-works/pi-coding-agent
fi
if command -v pi >/dev/null 2>&1; then
  pi install npm:context-mode
  pi install npm:@juicesharp/rpiv-ask-user-question
  pi install npm:pi-subagents
  pi install npm:@dietrichgebert/ponytail
  pi install npm:pi-btw
fi

# ── GitLab TUI (gitlab-tui: vim-key GitLab browser) ─────────────────────
# Builds from source (go.mod declares module 'gitlab-tui', so `go install
# @latest` fails) and writes ~/.config/gitlab-tui/config.json for $GITLAB_HOST.
# ~/.local/bin is on PATH via macos/zshrc.
if command -v gitlab-tui >/dev/null 2>&1; then
  echo "gitlab-tui already installed: $(command -v gitlab-tui)"
elif command -v go >/dev/null 2>&1 && command -v make >/dev/null 2>&1; then
  git clone -q --depth 1 https://github.com/nospor/gitlab-tui /tmp/gitlab-tui-build
  if make -C /tmp/gitlab-tui-build install PREFIX="$HOME/.local"; then
    echo "gitlab-tui installed to $HOME/.local/bin"
  else
    echo "WARN: gitlab-tui build failed — re-run or install manually (github.com/nospor/gitlab-tui)" >&2
  fi
  rm -rf /tmp/gitlab-tui-build
else
  echo "WARN: go/make missing — skipping gitlab-tui build (install go + make)" >&2
fi

# config: scripts/gitlab-tui-config.sh writes ~/.config/gitlab-tui/config.json
# from the untracked GITLAB_HOST/GITLAB_TOKEN in bash/secret_aliases. It never
# writes a placeholder — a placeholder host is what broke gitlab-tui
# ("lookup <gitlab-host>: no such host"). Unlike `source ~/.bashrc`, it reads
# the secrets even when install.sh runs non-interactively.
"$HOME/dotfiles/scripts/gitlab-tui-config.sh"

[ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc"

# Git identity is Home Manager's on Linux (home/git.nix); this track keeps it out
# of the repo too. Repo-local identifier pre-commit hook (see AGENTS.md).
git -C "$HOME/dotfiles" config core.hooksPath .githooks
