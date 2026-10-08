{ lib, pkgs, collieAgent, ... }:
# Collie — a self-hosted PWA that drives herdr's panes and agents from a phone
# (reply to a blocked agent, send Esc/Tab/Ctrl, watch the terminal). The front
# door is `tailscale serve`: it terminates TLS on the MagicDNS name and injects
# the `Tailscale-User-Login` header COLLIE_TRUSTED_USER checks. Collie itself
# always binds loopback.
#
# Why a user service: standalone Home Manager on non-NixOS cannot own system
# units, same reasoning as herdr.nix and postgres.nix.
#
# Ownership matters here. Home Manager supervises the bridge, so it runs
# `collie _exec-bridge` — NOT `collie start`, which would install its own unit
# and fight this one. Change/remove the service by editing this module and
# switching, never with `collie start|stop|restart|uninstall`. `collie pair`,
# `devices`, `url`, `qr`, `logs` and `push keys` are safe to run normally.
#
# Config and credentials live in ~/.config/collie/.env (state in
# ~/.local/state/collie): COLLIE_TRUSTED_USER and the VAPID push keys stay
# there, untracked, and are never linked into the Nix store. Seed the file once
# per host, then pair the phone.
#
# Manual steps after the first switch (the front door is not Nix-owned):
#   tailscale up                     # put the host on the tailnet
#   # enable HTTPS certs in the tailnet admin console, once
#   mkdir -p ~/.config/collie
#   echo 'COLLIE_TRUSTED_USER=you@example.com' > ~/.config/collie/.env
#   collie push keys                 # VAPID keys for push alerts (optional)
#   systemctl --user restart collie
#   collie serve                     # tailscale serve -> 127.0.0.1:8787
#   collie qr && collie pair         # scan on the phone
# `loginctl enable-linger $USER` (once, as root) keeps it up across logout.
#
# Security: this is full remote shell access to the machine by design — anyone
# who reaches the URL reads every pane and runs commands as you. Pair only the
# physical phone, set COLLIE_TRUSTED_USER, and never expose it with
# `tailscale funnel` (that is public internet; `serve` is tailnet-only).
let
  colliePkg = collieAgent.packages.${pkgs.stdenv.hostPlatform.system}.collie;
in
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
  home.packages = [ colliePkg ];

  systemd.user.services.collie = {
    Unit = {
      Description = "Collie bridge (herdr on the phone, over Tailscale)";
      After = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      Environment = [
        # herdr is the only multiplexer on these machines; pin it so a stray
        # tmux/zellij session cannot change the backend on restart. The herdr
        # driver resolves the unix socket itself (~/.config/herdr/herdr.sock),
        # so no HERDR_SOCKET_PATH is needed.
        "COLLIE_MUX=herdr"
        "COLLIE_PORT=8787"
        # systemd user services get a minimal PATH; add the nix profile so the
        # bridge and the git/agent helpers it shells out to resolve.
        "PATH=%h/.nix-profile/bin:%h/.local/bin:/usr/local/bin:/usr/bin"
      ];
      ExecStart = "${colliePkg}/bin/collie _exec-bridge";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
