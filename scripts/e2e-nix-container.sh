#!/usr/bin/env bash
# E2E: bootstrap the dotfiles nix flake from scratch in a throwaway Fedora
# container and verify the resulting Home Manager generation.
#
#   scripts/e2e-nix-container.sh
#   E2E_KEEP=1      scripts/e2e-nix-container.sh   # keep the container on success
#   E2E_ROLE_TEST=0 scripts/e2e-nix-container.sh   # skip the <user>@ubuntu switch
#   E2E_IMAGE=registry.fedoraproject.org/fedora:44 scripts/e2e-nix-container.sh
#
# Requires podman + network. Exits non-zero and keeps the container for
# inspection on failure. The working tree (tracked + untracked, gitignore
# respected) is copied in, so uncommitted edits are tested too.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/nix-lib.sh
. "$REPO/scripts/nix-lib.sh"

IMAGE="${E2E_IMAGE:-docker.io/library/fedora:44}"
NAME="${E2E_NAME:-nix-e2e}"
U="${E2E_USER:-guddy}"
ATTR="${E2E_ATTR:-$U@fedora}"
KEEP="${E2E_KEEP:-0}"
ROLE_TEST="${E2E_ROLE_TEST:-1}"
EXPECT_EMAIL="${E2E_EMAIL:-dis446@yahoo.com}"

command -v podman >/dev/null 2>&1 || { alert "podman not found"; exit 1; }
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || { alert "not a git repo: $REPO"; exit 1; }

fail() { alert "FAIL: $*"; exit 1; }

on_exit() {
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    alert "E2E failed (rc=$rc) — container '$NAME' kept for inspection:"
    alert "  podman exec -it -u $U $NAME bash -l"
    return
  fi
  if [ "$KEEP" = "1" ]; then say "container '$NAME' kept (E2E_KEEP=1)"; return; fi
  podman rm -f "$NAME" >/dev/null 2>&1 || true
  say "container '$NAME' removed"
}
trap on_exit EXIT

# Run a command in the container (root), or as the test user with E2E_ATTR set.
exec_root() { podman exec "$NAME" "$@"; }
switch_to() {
  podman exec -u "$U" -e E2E_ATTR="$1" "$NAME" bash -lc '
    export PATH=$HOME/.nix-profile/bin:$PATH
    cd "$HOME/dotfiles"
    nix flake check && nix run github:nix-community/home-manager/master -- switch -b backup --flake ".#$E2E_ATTR"
  '
}

say "Starting fresh container $NAME ($IMAGE)..."
podman rm -f "$NAME" >/dev/null 2>&1 || true
podman run -d --name "$NAME" --hostname "$NAME" "$IMAGE" sleep infinity >/dev/null

say "Installing container prerequisites..."
exec_root dnf -y install curl tar xz git shadow-utils findutils procps-ng \
  --setopt=install_weak_deps=False >/dev/null

say "Creating user $U and a user-owned /nix..."
exec_root bash -c "useradd -m -s /bin/bash '$U' && mkdir -p /nix && chown -R '$U':'$U' /nix"
exec_root bash -c 'mkdir -p /etc/nix && printf "experimental-features = nix-command flakes\nsandbox = false\n" > /etc/nix/nix.conf'

say "Installing single-user Nix..."
exec_root bash -c "su - '$U' -c 'sh <(curl -fsSL https://nixos.org/nix/install) --no-daemon --yes'" >/dev/null

say "Copying working tree into the container..."
git -C "$REPO" ls-files -z -c -o --exclude-standard \
  | tar -C "$REPO" --null --files-from=- -czf - \
  | podman exec -i "$NAME" bash -c "mkdir -p /home/$U/dotfiles && tar -xzf - -C /home/$U/dotfiles && chown -R '$U':'$U' /home/$U/dotfiles"

LOG="/tmp/$NAME-switch.log"
say "Running nix flake check + home-manager switch ($ATTR)..."
if ! switch_to "$ATTR" >"$LOG" 2>&1; then
  tail -40 "$LOG"
  fail "home-manager switch failed (full log: $LOG)"
fi
ok "flake check + switch succeeded"

say "Verifying tool set, config links, git identity, shell..."
if ! podman exec -i -u "$U" -e E2E_EMAIL="$EXPECT_EMAIL" "$NAME" bash -s <<'EOS'
export PATH=$HOME/.nix-profile/bin:$HOME/.local/bin:$PATH
rc=0
for t in nvim herdr zellij mise node java kubectl podman go gcc bat jq fd rg fzf \
         ghostty lazygit speedtest-cli pydf; do
  command -v "$t" >/dev/null 2>&1 || { echo "MISSING tool: $t"; rc=1; }
done
for l in .config/nvim .config/zed/settings.json .config/ghostty/config \
         .config/lazygit/config.yml .config/herdr/config.toml .editorconfig .ideavimrc; do
  case "$(readlink -f "$HOME/$l")" in
    "$HOME/dotfiles/"*) ;;
    *) echo "NOT LINKED into repo: $l"; rc=1 ;;
  esac
done
[ "$(git config --global user.email)" = "$E2E_EMAIL" ] || { echo "git email wrong"; rc=1; }
grep -q 'dotfiles/fedora/bashrc' "$HOME/.bashrc" || { echo "bashrc does not source repo rc"; rc=1; }
bash -lic 'alias dtf >/dev/null 2>&1' 2>/dev/null || { echo "aliases missing"; rc=1; }
exit $rc
EOS
then
  fail "container verification failed"
fi
ok "tools, links, git identity, bashrc, aliases all OK"

if [ "$ROLE_TEST" = "1" ]; then
  say "Role test: switching to $U@ubuntu (role=personal)..."
  if ! switch_to "$U@ubuntu" >"$LOG" 2>&1; then
    tail -40 "$LOG"
    fail "ubuntu switch failed (full log: $LOG)"
  fi
  if ! podman exec -i -u "$U" "$NAME" bash -s <<'EOS'
export PATH=$HOME/.nix-profile/bin:$HOME/.local/bin:$PATH
rc=0
for t in az glab gh; do
  command -v "$t" >/dev/null 2>&1 && { echo "UNEXPECTED work-only tool on ubuntu: $t"; rc=1; }
done
command -v nvim >/dev/null 2>&1 || { echo "nvim missing on ubuntu"; rc=1; }
grep -q 'ubuntu/bash_aliases' "$HOME/.bashrc" || { echo "ubuntu bashrc fallback missing"; rc=1; }
exit $rc
EOS
  then
    fail "ubuntu role test failed"
  fi
  ok "role gating + ubuntu bashrc fallback OK"
  switch_to "$ATTR" >"$LOG" 2>&1 || fail "switch back to $ATTR failed (log: $LOG)"
fi

say "Results:"
cgen="$(podman exec -u "$U" "$NAME" bash -lc 'export PATH=$HOME/.nix-profile/bin:$PATH; home-manager generations | head -1' || true)"
say "  container: $cgen"
if [ -x "$HOME/.nix-profile/bin/home-manager" ]; then
  hgen="$("$HOME/.nix-profile/bin/home-manager" generations 2>/dev/null | head -1 || true)"
  say "  host:      $hgen"
  cstore="$(printf '%s' "$cgen" | grep -o '/nix/store/[^ ]*-home-manager-generation' || true)"
  hstore="$(printf '%s' "$hgen" | grep -o '/nix/store/[^ ]*-home-manager-generation' || true)"
  if [ -n "$cstore" ] && [ "$cstore" = "$hstore" ]; then
    ok "Reproducible: container and host share generation $cstore"
  else
    say "  (generations differ — expected if this tree is newer than the host's last switch)"
  fi
fi
say "  container /nix: $(podman exec "$NAME" du -sh /nix 2>/dev/null | cut -f1)"

ok "E2E PASSED"
