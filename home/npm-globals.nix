# The pi agent binary is the one npm global. It is managed outside the nix
# store (like an npm-only tool) because npm from nix has its prefix locked to
# the store. pi *plugins* are managed by the agent itself (`pi install npm:...`)
# via its own settings — never declared here.
#
# Prefix is ~/.local to match the existing install (~/.local/bin/pi); using a
# different prefix would leave two pi binaries on PATH. npm_config_prefix is an
# env var, not `npm config set`, so activation never rewrites ~/.npmrc (which
# holds a registry auth token).
#
# NOT version-pinned: npm installs whatever is latest at install time, and
# scripts/nix-update.sh (`nix-update` / `up`) moves it forward from there. The
# switch itself stays idempotent — the guard below installs only when pi is
# missing — so a `home-manager switch` neither hits the registry nor swaps the
# host out from under a running session.
#
# Tradeoff, taken deliberately: an upstream release that drops something an
# extension needs lands here untested. It has happened twice — pi 1.0.0 removed
# `@earendil-works/pi-agent-core/node`, which pi-subagents resolves while
# spawning child agents (it now marks that alias optional in
# runs/background/runner-aliases.js), and pi-subagents 0.76.0 called a
# completionNotifier method its own notify.js did not define. Because only the
# update path pulls a new host, that is where to re-run pi-subagents'
# resolveHostPeerAliases probe when subagents break.
{ lib, pkgs, ... }:
{
  home.activation.installNpmGlobals = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${pkgs.nodejs_24}/bin:$HOME/.local/bin:$PATH"
    export npm_config_prefix="$HOME/.local"
    # Idempotent: only install when missing (avoids npm resolution every switch).
    npm ls -g @earendil-works/pi-coding-agent 2>/dev/null 1>&2 \
      || npm install -g --ignore-scripts @earendil-works/pi-coding-agent
  '';
}
