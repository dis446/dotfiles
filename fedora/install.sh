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
sudo_link_target() {
  local src="$1"
  local dest="$2"
  sudo rm -rf "$dest"
  sudo ln -s "$src" "$dest"
}

sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y

link_target "$HOME/dotfiles/nvim" "$HOME/.config/nvim"
link_target "$HOME/dotfiles/ghostty/linux/config.ghostty" "$HOME/.config/ghostty/config"
link_target "$HOME/dotfiles/zellij" "$HOME/.config/zellij"
link_target "$HOME/dotfiles/zed" "$HOME/.config/zed"
link_target "$HOME/dotfiles/pi/agent" "$HOME/.agents"
link_target "$HOME/dotfiles/pi" "$HOME/.pi"
link_target "$HOME/dotfiles/.ai" "$HOME/.ai"
link_target "$HOME/dotfiles/claude" "$HOME/.claude"
link_target "$HOME/dotfiles/herdr/config.toml" "$HOME/.config/herdr/config.toml"
# Apply the keybinding to a running herdr server immediately (no-op on fresh installs).
herdr server reload-config >/dev/null 2>&1 || true

# herdr headless server + boot restore (nvim/pi/terminal per workspace)
mkdir -p "$HOME/.config/systemd/user"
cp "$HOME/dotfiles/herdr/systemd/herdr-server.service" "$HOME/.config/systemd/user/herdr-server.service"
systemctl --user daemon-reload
systemctl --user enable herdr-server.service

link_target "$HOME/dotfiles/.editorconfig" "$HOME/.editorconfig"
sudo_link_target "$HOME/dotfiles/fedora/dnf.conf" "/etc/dnf/dnf.conf"
mkdir -p "$HOME/.config/lazygit"
ln -sf "$HOME/dotfiles/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
ln -sf "$HOME/dotfiles/intellij/ideavimrc" "$HOME/.ideavimrc"
link_target "$HOME/dotfiles/fedora/bashrc" "$HOME/.bashrc"
source "$HOME/.bashrc"

sudo dnf copr enable dejan/lazygit -y
sudo dnf copr enable jdxcode/mise -y
sudo dnf copr enable scottames/ghostty -y

sudo dnf update -y

sudo dnf install git vim neovim lazygit podman-docker mise htop ncdu speedtest-cli pip3 golang kubectl gcc-c++ make -y --skip-unavailable
sudo pip install pydf

mise use -g node@24
mise use -g java@temurin-21
mise use -g herdr

sudo npm install -g --ignore-scripts @earendil-works/pi-coding-agent

sudo dnf install cargo -y
cargo install cargo-binstall -y
cargo binstall -y zellij

# ── GitLab TUI (gitlab-tui: vim-key GitLab browser) ─────────────────────
# Builds from source (go.mod declares module 'gitlab-tui', so `go install
# @latest` fails) and writes ~/.config/gitlab-tui/config.json for git.and.global.
# ~/.local/bin is on PATH via fedora/bashrc.
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
  echo "WARN: go/make missing — skipping gitlab-tui build (install golang+make via dnf)" >&2
fi

# config: git.and.global server; token from $GITLAB_TOKEN, else placeholder
mkdir -p "$HOME/.config/gitlab-tui"
python3 - "${GITLAB_TOKEN:-__PASTE_GITLAB_TOKEN_HERE__}" <<'PYEOF'
import json, os, sys
cfg = {"servers": [{"name": "git.and.global", "url": "https://git.and.global", "token": sys.argv[1], "default": True}], "theme": "catppuccin"}
os.makedirs(os.path.expanduser("~/.config/gitlab-tui"), exist_ok=True)
with open(os.path.expanduser("~/.config/gitlab-tui/config.json"), "w") as f:
    json.dump(cfg, f, indent=2)
PYEOF
if [ -n "${GITLAB_TOKEN:-}" ]; then
  echo "gitlab-tui configured for git.and.global (token from GITLAB_TOKEN)"
else
  echo "NOTE: GITLAB_TOKEN not set — edit ~/.config/gitlab-tui/config.json and paste your token"
fi

curl -f https://zed.dev/install.sh | sh

flatpak install flathub com.mattjakeman.ExtensionManager com.github.tchx84.Flatseal -y

source "$HOME/.bashrc"

git config --global user.email "dis446@yahoo.com"
git config --global user.name "Tsetsen-erdene Ganbaatar"
git config --global pull.rebase true
