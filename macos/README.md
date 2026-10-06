# Fresh macOS setup

macOS is still the pre-Home-Manager track (`plans/nix-migration-plan.md` §10):
no Nix, no flake — Homebrew plus a symlink script.

```bash
# 1. Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Clone to the baked path — must be ~/dotfiles (symlinks hardcode it)
git clone git@github.com:dis446/dotfiles.git ~/dotfiles

# 3. Brew packages
brew bundle --file ~/dotfiles/macos/Brewfile

# 4. Config symlinks + pi + gitlab-tui (needs go + make for the last one)
~/dotfiles/macos/install.sh
```

- `git clone git@…` needs a GitHub SSH key — use the HTTPS URL if there isn't one.
- Secrets are untracked: put `GITLAB_HOST`/`GITLAB_TOKEN` (etc.) in `bash/secret_aliases`.
- Optional afterwards: `nvim --headless "+Lazy! sync" +qa`
