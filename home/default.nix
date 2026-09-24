{ username, ... }:
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
}
