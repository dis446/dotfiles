{ username, ... }:
{
  # Phase 1: packages only. Later phases add the remaining modules:
  #   ./dotfiles.nix  (out-of-store config links)   — Phase 2
  #   ./bash.nix      (Home Manager owns ~/.bashrc) — Phase 3
  #   ./git.nix       (git identity)                — Phase 4
  #   ./npm-globals.nix (pi agent via activation)   — Phase 4
  imports = [
    ./packages.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  # Version at time of adoption. Do not bump casually.
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
