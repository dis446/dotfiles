# shellcheck shell=bash
# Sourced by scripts/nix-*.sh (never executed directly).
set -u

TEXT_COLOR="\033[34;1m"
SUCCESS_COLOR="\033[32;7m"
ALERT_COLOR="\033[31;7m"
RESET_COLOR="\033[0m"

say() { printf "%b%s%b\n" "$TEXT_COLOR" "$1" "$RESET_COLOR"; }
ok() { printf "%b%s%b\n" "$SUCCESS_COLOR" "$1" "$RESET_COLOR"; }
alert() { printf "%b%s%b\n" "$ALERT_COLOR" "$1" "$RESET_COLOR"; }

# The flake keys homeConfigurations by "<user>@<platform>" where platform is the
# hosts-map key (fedora/nobara/ubuntu), not the real hostname.
nix_platform() {
  if [ -f /etc/nobara-release ] || [ -f /etc/Nobara-release ]; then
    echo nobara
  elif [ -f /etc/fedora-release ]; then
    echo fedora
  elif grep -qi ubuntu /etc/os-release 2>/dev/null; then
    echo ubuntu
  else
    echo "${NIX_PLATFORM:-fedora}"
  fi
}

nix_attr() { echo "${NIX_USER:-guddy}@$(nix_platform)"; }

# Scripts run without a login shell, so the nix profile is not on PATH.
nix_path() {
  export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$HOME/.local/bin:$PATH"
}

# A dirty tree breaks `git pull --ff-only` with a raw git error; say so up
# front. Untracked files do not block a pull, so only tracked changes count.
require_clean_tree() {
  if ! git diff --quiet HEAD; then
    alert "Local changes to tracked files — commit or stash first."
    exit 1
  fi
}
