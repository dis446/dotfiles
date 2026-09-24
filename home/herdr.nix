{ lib, pkgs, ... }:
# herdr headless server: persistent workspaces + boot restore. Declarative now
# (was an install.sh `cp` of herdr/systemd/herdr-server.service). The binary
# comes from nix (home/packages.nix), not mise.
lib.mkIf pkgs.stdenv.isLinux {
  systemd.user.services.herdr-server = {
    Unit = {
      Description = "Herdr headless server (persistent workspaces, agents, and terminals)";
      After = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      # %h expands in systemd Environment=.
      Environment = [
        "HERDR_BIN_PATH=%h/.nix-profile/bin/herdr"
        # GUI session env so panes get clipboard providers (wl-copy/xsel).
        "WAYLAND_DISPLAY=wayland-0"
        "DISPLAY=:0"
        "XDG_SESSION_TYPE=wayland"
        # systemd user services get a minimal PATH; add the nix profile so the
        # server and the nvim/pi panes it spawns resolve (mise shims kept for
        # per-repo overrides).
        "PATH=%h/.nix-profile/bin:%h/.local/bin:%h/.local/share/mise/shims:/usr/local/bin:/usr/bin"
      ];
      ExecStart = "%h/dotfiles/herdr/server.sh";
      ExecStartPost = "%h/dotfiles/herdr/restore.sh";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
