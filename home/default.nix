{ username, ... }:
{
  # Phase 4 adds:
  #   ./git.nix         (git identity)
  #   ./npm-globals.nix (pi agent via activation)
  imports = [
    ./packages.nix
    ./dotfiles.nix
    ./bash.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  # Version at time of adoption. Do not bump casually.
  home.stateVersion = "25.11";

  # Machine PATH additions that used to live in the distro ~/.profile —
  # Home Manager now owns ~/.profile and ~/.bash_profile.
  home.sessionPath = [
    "/home/${username}/.local/share/JetBrains/Toolbox/scripts"
  ];

  programs.home-manager.enable = true;
}
