#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/nix-lib.sh
. "$(dirname "$0")/nix-lib.sh"

nix_path

before=$(df -h / | awk 'NR==2 {print $4}')

say "Deleting user profile generations older than 14 days..."
nix-collect-garbage --delete-older-than 14d

say "Deleting system generations older than 14 days (needs sudo)..."
sudo nix-collect-garbage --delete-older-than 14d

say "Deduplicating the nix store (hardlinking identical files, may take a while)..."
nix store optimise

after=$(df -h / | awk 'NR==2 {print $4}')
ok "Cleanup complete! Free space on /: $before -> $after"
