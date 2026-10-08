#!/usr/bin/env bash
set -euo pipefail

# Install Tailscale and lock it down for one purpose: the Collie front door.
# `home/collie.nix` runs a bridge on 127.0.0.1:8787 and `collie serve`
# publishes it on this host's MagicDNS name with `tailscale serve` — tailnet
# only. This script installs the daemon and applies the settings that make
# that safe.
#
# Cross-platform across this repo's tracks: Fedora, Nobara, Arch, Ubuntu, and
# Ubuntu under WSL2. The daemon needs root, so Tailscale is deliberately NOT in
# the Nix layer (see AGENTS.md, "Outside Nix (by design)").
#
# Idempotent: re-run any time. It re-asserts the security flags each run.
#
# What "secure" means here:
#   * Tailnet-only. NEVER `tailscale funnel` — that publishes to the open
#     internet. The script refuses to finish silently if funnel looks active.
#   * accept-routes=false   — do not join subnet routes other devices advertise.
#   * ssh=false             — no Tailscale SSH into this host from any tailnet
#     device, regardless of ACLs.
#   * No exit node, no advertised routes or exit node.
#   * operator=<login user> — lets the login user run `tailscale serve` without
#     root, which is what `collie serve` needs. Without it, `collie serve` fails.
#   * shields-up stays OFF on purpose: it would block the phone's own tailnet
#     requests to the served port.
#
# The one thing this cannot script is enabling HTTPS certificates for the
# tailnet — that is an admin-console toggle. The script prints the link; turn
# it on once and `collie serve` provisions the cert itself.

# shellcheck source=scripts/nix-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/nix-lib.sh"   # say/ok/alert

is_wsl() { [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; }

USER_NAME="$(id -un)"

# Writes to /etc/yum.repos.d, sources.list.d and systemd, so everything here
# goes through sudo. The repo is Tailscale's own, not the distro's, so the
# package tracks upstream regardless of how stale the distro archive is.
install_tailscale() {
  if command -v tailscale >/dev/null 2>&1; then
    ok "tailscale already installed — $(tailscale version 2>/dev/null | head -1)"
    return
  fi

  if is_wsl || grep -qi ubuntu /etc/os-release 2>/dev/null; then
    local codename
    codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
    [ -n "$codename" ] || codename="$(lsb_release -cs 2>/dev/null || true)"
    [ -n "$codename" ] || { alert "Could not detect the Ubuntu codename."; exit 1; }
    say "Installing Tailscale from the official apt repository ($codename)..."
    curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.noarmor.gpg" \
      | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.tailscale-keyring.list" \
      | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y tailscale

  elif [ -f /etc/arch-release ]; then
    say "Installing Tailscale from the official Arch repositories..."
    sudo pacman -S --needed --noconfirm tailscale

  elif [ -f /etc/fedora-release ] || [ -f /etc/nobara-release ] || [ -f /etc/Nobara-release ]; then
    say "Installing Tailscale from the official Fedora repository..."
    # dnf5 (Fedora 41+) renamed this to `config-manager addrepo --from-repofile=`;
    # dnf4 used `config-manager --add-repo`. Support both.
    sudo dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo 2>/dev/null \
      || sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo
    sudo dnf install -y tailscale

  else
    alert "Unsupported distro. Install Tailscale manually, then re-run this script."
    exit 1
  fi
}

start_daemon() {
  if ! command -v systemctl >/dev/null 2>&1 || [ "$(ps -p 1 -o comm= 2>/dev/null)" != "systemd" ]; then
    alert "systemd is not PID 1 — start tailscaled yourself (in WSL: set"
    alert "[boot] systemd=true in /etc/wsl.conf, then `wsl --shutdown`)."
    return
  fi
  say "Enabling and starting tailscaled..."
  sudo systemctl enable --now tailscaled
}

# Security flags. `tailscale up` and `tailscale set` take the same spelling, so
# one array serves both. Do NOT add --reset: it would drop the flags applied by
# an earlier run before re-applying them, and offers nothing here.
secure_flags=(
  --accept-routes=false
  --ssh=false
  --shields-up=false
  --operator="$USER_NAME"
)

configure() {
  local state
  state="$(tailscale status --json 2>/dev/null \
    | grep -o '"BackendState":"[^"]*"' | head -1 | cut -d'"' -f4 || true)"

  if [ "$state" = "Running" ]; then
    say "Already signed in — re-asserting the security settings..."
    sudo tailscale set "${secure_flags[@]}"
  else
    say "Signing in. This prints a URL (or QR) to authenticate in a browser;"
    say "open it and approve this machine to your tailnet."
    sudo tailscale up "${secure_flags[@]}"
  fi
}

check_funnel() {
  # The single worst mistake: `funnel` opens the served port to the internet.
  # `serve` is tailnet-only; never funnel Collie. Read it off `serve status
  # --json`, which carries an explicit AllowFunnel map — `funnel status` can
  # echo a plain `serve` config and read as a false positive.
  if sudo tailscale serve status --json 2>/dev/null | grep -q '"AllowFunnel":{[^}]*true'; then
    alert "WARNING: Tailscale Funnel is configured — that exposes the port to the PUBLIC internet."
    alert "Turn it off:  sudo tailscale funnel --https=443 off"
  fi
}

report() {
  echo
  ok "tailscale installed and configured."
  say "MagicDNS: $(tailscale status --json 2>/dev/null | grep -o '"DNSName":"[^"]*"' | head -1 | cut -d'"' -f4 || true)"
  echo
  echo "Remaining manual steps (once):"
  echo "  1. Enable HTTPS certificates for the tailnet:"
  echo "     https://login.tailscale.com/admin/dns  ->  turn on HTTPS"
  echo "  2. Rebuild and start Collie:"
  echo "       home-manager switch --flake ~/dotfiles#$(nix_attr)"
  echo "       collie serve && collie qr && collie pair"
  echo
  echo "Never run 'tailscale funnel' — that is public internet. 'serve' is tailnet-only."
}

install_tailscale
start_daemon
configure
check_funnel
report
