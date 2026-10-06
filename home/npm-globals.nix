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
# Version is PINNED, never @latest: an upstream pi that drops an export
# pi-subagents resolves while spawning child agents silently breaks every
# subagent launch. That is what 1.0.0 did — it removed
# `@earendil-works/pi-agent-core/node`, so the host was held at 0.99.2 until
# pi-subagents made that alias optional (runs/background/runner-aliases.js).
#
# 1.0.4 is verified good, not assumed: pi-subagents' own resolveHostPeerAliases
# returns missing: [] against it, and 1.0.x still ships @earendil-works/chord,
# which that resolver requires from any host that is not a stable 0.<85.
# Bump this and scripts/nix-update.sh together, and re-run that resolver probe
# before moving the pin — never to @latest.
{ lib, pkgs, ... }:
{
  home.activation.installNpmGlobals = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${pkgs.nodejs_24}/bin:$HOME/.local/bin:$PATH"
    export npm_config_prefix="$HOME/.local"
    # Version-aware guard: reinstalls when a different version is present, so the
    # pin self-enforces instead of silently keeping whatever `@latest` installed.
    npm ls -g "@earendil-works/pi-coding-agent@1.0.4" 2>/dev/null 1>&2 \
      || npm install -g --ignore-scripts "@earendil-works/pi-coding-agent@1.0.4"
  '';
}
