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

# The pi agent binary is no longer an npm global: it comes from its own flake
# input (flake.nix), so the `nix flake update` + switch above is what moves it.
# If subagents ever break after a bump, run pi-subagents' resolveHostPeerAliases
# probe against the new host before blaming anything else (see home/packages.nix).

if ! git diff --quiet flake.lock; then
  say "Committing and pushing updated flake.lock..."
  git add flake.lock
  git commit -q -m "chore: bump flake inputs"
  git push -q || alert "WARN: could not push flake.lock (offline?)"
fi

ok "Nix update complete!"
