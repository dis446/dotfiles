# macOS shell setup

This folder lets you keep using the shared files in `bash/` on macOS without rewriting them for `zsh`.

## Recommended path

`zsh` supports normal `alias` syntax, so you do not need to abandon it just to keep your current alias files.

Use the shared alias files first, then layer macOS overrides from `macos/bash_alias` on top.

## Files

- `macos/zshrc` sources every file in `bash/`, then applies macOS overrides.
- `macos/bashrc` does the same if you still want to use bash on macOS.
- `macos/bash_alias` overrides Linux-only aliases with the closest macOS equivalents.
- `macos/Brewfile` installs most tools referenced by your current aliases.

## Install the tools

```bash
brew bundle --file ~/dotfiles/macos/Brewfile
```

## Use zsh

```bash
ln -sf ~/dotfiles/macos/zshrc ~/.zshrc
source ~/.zshrc
```

## Use bash instead

```bash
ln -sf ~/dotfiles/macos/bashrc ~/.bashrc
source ~/.bashrc
```

If you also want bash as your login shell on macOS, install it from Homebrew and then run `chsh` with the brewed bash path after adding that path to `/etc/shells`.

## Alias mapping notes

- `i`, `r`, `is`, `il`, and `up` now map to Homebrew.
- `sys*` aliases map to `brew services` where that makes sense.
- `srn` and `ssn` map to macOS shutdown and reboot commands.
- `bios` and `sysbios` print a message because there is no useful macOS equivalent.
- `g` opens TextEdit because `gedit` is not a normal macOS tool.

## Known gaps

- `docker` aliases still need a Docker backend such as Docker Desktop or Colima.
- `flatpak`, `snap`, and some Linux-specific service behavior do not map cleanly to macOS.
- `work_aliases` is still sourced as-is, so any Linux-only exports in that file may need personal cleanup later if they bother you.
