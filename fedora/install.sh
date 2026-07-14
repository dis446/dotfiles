mkdir -p "$HOME/.config" "$HOME/.config/ghostty"
link_target() {
  local src="$1"
  local dest="$2"
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
link_target "$HOME/dotfiles/tmux" "$HOME/.config/tmux"
link_target "$HOME/dotfiles/zellij" "$HOME/.config/zellij"
link_target "$HOME/dotfiles/zed" "$HOME/.config/zed"
link_target "$HOME/dotfiles/pi/agent" "$HOME/.agents"
link_target "$HOME/dotfiles/pi" "$HOME/.pi"
link_target "$HOME/dotfiles/.ai" "$HOME/.ai"
link_target "$HOME/dotfiles/claude" "$HOME/.claude"
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

sudo dnf install git vim neovim lazygit tmux podman-docker mise htop ncdu speedtest-cli pip3 golang kubectl -y --skip-unavailable
sudo pip install pydf

mise use -g node@24
mise use -g java@temurin-21

sudo npm install -g --ignore-scripts @earendil-works/pi-coding-agent

sudo dnf install cargo
cargo install cargo-binstall
cargo binstall -y zellij

curl -f https://zed.dev/install.sh | sh

flatpak install flathub com.mattjakeman.ExtensionManager com.github.tchx84.Flatseal -y

source "$HOME/.bashrc"

git config --global user.email "dis446@yahoo.com"
git config --global user.name "Tsetsen-erdene Ganbaatar"
git config --global pull.rebase true
