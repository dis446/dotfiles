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
# Version is PINNED to 0.99.2 on purpose: pi >= 1.0.0 dropped the
# `@earendil-works/pi-agent-core/node` export, which pi-subagents resolves when
# it spawns child agents (async and foreground alike). On 1.0.x every subagent
# launch fails with "Background children require the host npm package ...".
# 0.99.2 is the last release that still exports ./node AND ships chord.
# Drop the pin only once pi-subagents supports pi >= 1.0.
{ lib, pkgs, ... }:
{
  home.activation.installNpmGlobals = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${pkgs.nodejs_24}/bin:$HOME/.local/bin:$PATH"
    export npm_config_prefix="$HOME/.local"
    # Version-aware guard: reinstalls when a different version is present, so the
    # pin self-enforces instead of silently keeping whatever `@latest` installed.
    npm ls -g "@earendil-works/pi-coding-agent@0.99.2" 2>/dev/null 1>&2 \
      || npm install -g --ignore-scripts "@earendil-works/pi-coding-agent@0.99.2"
  '';
}
