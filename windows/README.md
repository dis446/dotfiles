# Fresh Windows setup

Windows 11 is the work machine. The dev environment is **WSL2 (Ubuntu + Nix + Home Manager)**;
this folder only does the native layer (`$PROFILE` link, Scoop CLI tools, winget GUI apps).

```powershell
# 1. Admin PowerShell — reboot when asked, then set the distro user to "winny"
wsl --install -d Ubuntu

# 2. Native layer: profile link + Scoop + winget (idempotent)
pwsh -File .\windows\install.ps1
```

```bash
# 3. Inside Ubuntu (WSL) — same as ubuntu/README.md, with the `wsl` host key
sudo apt update && sudo apt install -y curl git
git clone git@github.com:dis446/dotfiles.git ~/dotfiles
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
~/dotfiles/ubuntu/install.sh
nix run github:nix-community/home-manager/master -- switch -b backup --flake ~/dotfiles#winny@wsl
```

- `/etc/wsl.conf` → `[boot] systemd=true` and `[user] default=winny`, then `wsl --shutdown` from Windows.
- Keep the checkout inside WSL (`~/dotfiles`), never on `/mnt/c`.
- GUI apps (ghostty, Zed, IntelliJ) are Windows-native — not installed in WSL.
- Secrets are untracked: put `GITLAB_HOST`/`GITLAB_TOKEN` (etc.) in `bash/secret_aliases`.
