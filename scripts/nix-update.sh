#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/nix-lib.sh
. "$(dirname "$0")/nix-lib.sh"

nix_path
REPO="$HOME/dotfiles"
ATTR="$(nix_attr)"
cd "$REPO"
require_clean_tree

say "Syncing with remote..."
git pull --ff-only -q

say "Updating flake inputs (nixpkgs + home-manager)..."
nix flake update
git diff --quiet flake.lock || git --no-pager diff --stat flake.lock

say "Checking the flake (no CI on this repo — this is the only gate)..."
nix flake check "$REPO"

say "Rebuilding and switching the Home Manager generation..."
home-manager switch --flake "$REPO#$ATTR"

say "Updating the pi agent binary (npm global, outside the nix store)..."
npm_config_prefix="$HOME/.local" npm install -g --ignore-scripts \
  @earendil-works/pi-coding-agent@latest

if ! git diff --quiet flake.lock; then
  say "Committing and pushing updated flake.lock..."
  git add flake.lock
  git commit -q -m "chore: bump flake inputs"
  git push -q || alert "WARN: could not push flake.lock (offline?)"
fi

ok "Nix update complete!"
