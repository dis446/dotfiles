#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/nix-lib.sh
. "$(dirname "$0")/nix-lib.sh"

nix_path
REPO="$HOME/dotfiles"
ATTR="$(nix_attr)"
cd "$REPO"
require_clean_tree

say "Pulling dotfiles..."
before=$(git rev-parse HEAD)
git pull --ff-only -q
after=$(git rev-parse HEAD)

if [ "$before" = "$after" ]; then
  say "Already up to date."
elif ! git diff --quiet "$before" "$after" -- '*.nix' flake.lock; then
  say "Nix files changed — rebuild: home-manager switch --flake $REPO#$ATTR"
else
  say "No nix changes (config-only edits are live via out-of-store links)."
fi

ok "Pull complete!"
