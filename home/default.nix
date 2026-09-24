{ lib, pkgs, username, ... }:
{
  imports = [
    ./packages.nix
    ./dotfiles.nix
    ./bash.nix
    ./git.nix
    ./npm-globals.nix
    ./herdr.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  # Version at time of adoption. Do not bump casually.
  home.stateVersion = "25.11";

  # PATH for every HM-managed shell (login + non-login interactive). The nix
  # bins are listed because shells spawned by systemd user services (herdr
  # panes) inherit a minimal PATH that never sourced /etc/profile.d/nix.sh —
  # without these, `nix`/`nvim` are missing in a pane.
  home.sessionPath = [
    "/nix/var/nix/profiles/default/bin"
    "/home/${username}/.nix-profile/bin"
    "/home/${username}/.local/share/JetBrains/Toolbox/scripts"
  ];

  programs.home-manager.enable = true;

  # GUI apps launched from GNOME read the systemd user session environment, not
  # shell rc. Without these, nix GUI apps (ghostty) are absent from the app grid
  # and bare `Exec=` names don't resolve. `${VAR}` expands at session start.
  # Takes effect after a re-login (or `systemctl --user import-environment`).
  systemd.user.sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    PATH = "''${HOME}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:''${PATH}";
    XDG_DATA_DIRS = "''${HOME}/.nix-profile/share:/nix/var/nix/profiles/default/share:''${XDG_DATA_DIRS}";
    TERMINFO_DIRS = "''${HOME}/.nix-profile/share/terminfo:/nix/var/nix/profiles/default/share/terminfo:/usr/share/terminfo";
  };
}
