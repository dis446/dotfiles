# Fresh Fedora setup

```bash
# 1. Nix (Determinate, multi-user)
curl -fsSL https://install.determinate.systems/nix | sh -s -- install

# 2. Clone to the baked path — must be ~/dotfiles (out-of-store symlinks hardcode it)
git clone git@github.com:dis446/dotfiles.git ~/dotfiles

# 3. System layer: RPM Fusion, dnf.conf, zram, flatpak, podman socket
~/dotfiles/fedora/install.sh

# 4. Nix env: tools, shell, git, herdr unit. First run bootstraps Home Manager.
nix run github:nix-community/home-manager/master -- switch -b backup --flake ~/dotfiles#$(id -un)@fedora
```

Rebuild after `.nix` edits (or just run `nix-update`):

```bash
home-manager switch --flake ~/dotfiles#$(id -un)@fedora
```

- `git clone git@…` needs a GitHub SSH key — use the HTTPS URL if there isn't one.
- Secrets are untracked: put `GITLAB_HOST`/`GITLAB_TOKEN` (etc.) in `bash/secret_aliases`.
- Optional afterwards: `nvim --headless "+Lazy! sync" +qa`
