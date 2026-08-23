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
sudo_link_target "$HOME/dotfiles/nobara/dnf.conf" "/etc/dnf/dnf.conf"

mkdir -p "$HOME/.config/lazygit"
ln -sf "$HOME/dotfiles/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
ln -sf "$HOME/dotfiles/intellij/ideavimrc" "$HOME/.ideavimrc"
link_target "$HOME/dotfiles/nobara/bashrc" "$HOME/.bashrc"
source "$HOME/.bashrc"

sudo dnf copr enable dejan/lazygit -y
sudo dnf copr enable jdxcode/mise -y
sudo dnf copr enable scottames/ghostty -y

nobara-sync cli && yes | flatpak update

sudo dnf install git vim neovim lazygit podman-docker mise htop ncdu speedtest-cli pip3 golang kubectl gcc-c++ make mpv-libs -y --skip-unavailable
sudo pip install pydf

mise use -g node@24
mise use -g java@temurin-21
mise use -g herdr

sudo npm install -g --ignore-scripts @earendil-works/pi-coding-agent

sudo dnf install cargo -y
cargo install cargo-binstall
cargo binstall -y zellij

curl -f https://zed.dev/install.sh | sh

flatpak install flathub com.mattjakeman.ExtensionManager com.github.tchx84.Flatseal -y

# ── GitLab TUI (gitlab-tui: vim-key GitLab browser) ─────────────────────
# Builds from source (go.mod declares module 'gitlab-tui', so `go install
# @latest` fails) and writes ~/.config/gitlab-tui/config.json for git.and.global.
# ~/.local/bin is on PATH via nobara/bashrc.
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

# ── Noize (YouTube Music client — replaces the Firefox tab) ────────────
# Ensures the latest Linux release is installed/updated at ~/Applications/noize
# on every run (queries the GitHub latest release each invocation, verifies the
# sha256, and swaps the bundle). Needs libmpv (media_kit audio backend) —
# installed via dnf above (mpv-libs).
NOIZE_DIR="$HOME/Applications/noize"
NOIZE_ARCHIVE="$HOME/Applications/noize-linux-release.tar.gz"
if command -v curl >/dev/null 2>&1; then
  if curl -fsSL -o /tmp/noize-release.json https://api.github.com/repos/anandssm/noize/releases/latest 2>/dev/null; then
    NOIZE_VERSION="$(python3 -c "import json; print(json.load(open('/tmp/noize-release.json')).get('tag_name',''))" 2>/dev/null)"
    if [ -n "$NOIZE_VERSION" ]; then
      if [ "$(cat "$NOIZE_DIR/.version" 2>/dev/null || true)" != "$NOIZE_VERSION" ]; then
        echo "noize: updating to $NOIZE_VERSION (was $(cat "$NOIZE_DIR/.version" 2>/dev/null || echo not-installed))"
        read -r NOIZE_URL NOIZE_SHA <<META
$(python3 - <<'PYEOF'
import json
d = json.load(open('/tmp/noize-release.json'))
for a in d.get('assets', []):
    if a.get('state') == 'uploaded' and a.get('name', '').endswith('linux-release.tar.gz'):
        print(a['browser_download_url'], (a.get('digest') or '').replace('sha256:', ''))
        break
PYEOF
)
META
        if [ -n "$NOIZE_URL" ] && [ -n "$NOIZE_SHA" ] \
           && curl -fsSL -o "$NOIZE_ARCHIVE" "$NOIZE_URL" \
           && echo "$NOIZE_SHA  $NOIZE_ARCHIVE" | sha256sum -c - >/dev/null 2>&1; then
          rm -rf /tmp/noize-extract
          mkdir -p /tmp/noize-extract
          tar -xzf "$NOIZE_ARCHIVE" -C /tmp/noize-extract --strip-components=1
          rm -rf "$NOIZE_DIR"
          mv /tmp/noize-extract "$NOIZE_DIR"
          chmod +x "$NOIZE_DIR/noize"
          echo "$NOIZE_VERSION" > "$NOIZE_DIR/.version"
          echo "noize: installed $NOIZE_VERSION at $NOIZE_DIR"
        else
          echo "WARN: noize download/checksum failed — keeping existing install" >&2
        fi
        rm -f "$NOIZE_ARCHIVE"
      else
        echo "noize: already at $NOIZE_VERSION"
      fi
    else
      echo "WARN: noize release metadata unreadable — keeping existing install" >&2
    fi
  else
    echo "WARN: noize GitHub API unreachable (offline?) — keeping existing install" >&2
  fi
else
  echo "WARN: curl missing — skipping noize update" >&2
fi

# desktop entry + icon (idempotent; icon referenced from the bundle)
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/noize.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Noize
GenericName=YouTube Music Client
Comment=Free, open-source YouTube Music client (no Firefox tab needed)
Exec=$HOME/Applications/noize/noize
Icon=$HOME/Applications/noize/data/flutter_assets/assets/default_artwork.png
Terminal=false
Categories=Audio;Music;Player;
StartupNotify=true
StartupWMClass=noize
EOF
chmod +x "$HOME/.local/share/applications/noize.desktop"
update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

source "$HOME/.bashrc"

git config --global user.email "dis446@yahoo.com"
git config --global user.name "Tsetsen-erdene Ganbaatar"
git config --global pull.rebase true
