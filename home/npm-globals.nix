# The pi agent binary is the one npm global. It is managed outside the nix
# store (like an npm-only tool) because npm from nix has its prefix locked to
# the store. pi *plugins* are managed by the agent itself (`pi install npm:...`)
# via its own settings — never declared here.
#
# Prefix is ~/.local to match the existing install (~/.local/bin/pi); using a
# different prefix would leave two pi binaries on PATH. npm_config_prefix is an
# env var, not `npm config set`, so activation never rewrites ~/.npmrc (which
# holds a registry auth token).
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
