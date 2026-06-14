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

sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

link_target "$HOME/dotfiles/nvim" "$HOME/.config/nvim"
link_target "$HOME/dotfiles/ghostty/linux/config" "$HOME/.config/ghostty/config"
link_target "$HOME/dotfiles/zellij" "$HOME/.config/zellij"
link_target "$HOME/dotfiles/pi/agent" "$HOME/.agents"
link_target "$HOME/dotfiles/pi" "$HOME/.pi"
link_target "$HOME/dotfiles/.ai" "$HOME/.ai"
sudo_link_target "$HOME/dotfiles/fedora/dnf.conf" "/etc/dnf/dnf.conf"
mkdir -p "$HOME/.config/lazygit"
ln -sf "$HOME/dotfiles/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
link_target "$HOME/dotfiles/fedora/bashrc" "$HOME/.bashrc"
source "$HOME/.bashrc"

sudo dnf copr enable dejan/lazygit -y 
sudo dnf copr enable jdxcode/mise -y
sudo dnf copr enable varland/zellij -y
sudo dnf copr enable scottames/ghostty -y

sudo dnf update

sudo dnf install git vim neovim lazygit zellij mise -y

mise use -g node@24
mise use -g java@temurin-21

source "$HOME/.bashrc"

git config --global user.email "dis446@yahoo.com"
git config --global user.name "Disney Ganbaatar"
