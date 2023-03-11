alias l="ls"
alias l='ls -lAh'
alias ls="ls -a"
alias la="ls -a"
alias ll="ls -al"
alias mkdir="mkdir -pv"
alias mount='mount |column -t'
alias i="sudo dnf install"
alias is="dnf search"
alias dnfs="dnf list | grep"
alias r="sudo dnf remove"
alias flats="flatpak search"
alias flati="sudo flatpak install"
alias flatr="sudo flatpak remove"
alias up="sudo dnf up && sudo flatpak update"
alias crc="cat ~/.bashrc"
alias erc="nano ~/.bashrc"
alias src="source ~/.bashrc"
alias ekc="gnome-text-editor ~/.config/kitty/kitty.conf &"
alias c="cat"
alias b="bat"
alias g="gnome-text-editor"
alias n="nano"
alias sn="sudo nano"
alias f="find . | grep"
alias h="history | grep"
alias cpv='rsync -ah --info=progress2'
alias top="htop"
alias du="ncdu"
alias df="pydf"
alias count="find . -type f | wc -l"
alias srn="sudo reboot now"
alias ssn="sudo shutdown now"
alias bios="systemctl reboot --firmware-setup"
alias ff="fastfetch"
alias vpn="expressvpn"
alias vpnc="expressvpn connect"
alias vpnca="expressvpn connect usla1"
alias vpnd="expressvpn disconnect"
alias vpns="expressvpn status"
alias gedit="gnome-text-editor"
alias wtr="curl wttr.in"
alias st="speedtest-cli"
alias ppi="ping 192.168.1.5"
alias spi="ssh servy@192.168.1.5"
alias myip="curl http://ipecho.net/plain; echo"
alias sys="sudo systemctl"
alias syss="sudo systemctl status"
alias sysstop="sudo systemctl stop"
alias sysstart="sudo systemctl start"
alias sysrestart="sudo systemctl restart"
alias sysenable="sudo systemctl enable"
alias sysremove="sudo systemctl remove"
alias sysbios="sudo systemctl reboot --firmware-setup"

alias gita="git add"
alias gitc="git commit -sm"
alias gits="git status"
alias gitpull="git pull"
alias gitpush="git push"
alias gitl="git log"
alias gitd="git diff"
alias lint="npx eslint ."
alias lintf="npx eslint . --fix"
