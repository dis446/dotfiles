{ config, lib, pkgs, role, isWsl ? false, ... }:
{
  home.packages = with pkgs; [
    # Version control / editors
    git
    vim
    neovim
    lazygit

    # Terminal / system
    bat
    jq
    htop
    ncdu
    pydf
    fastfetch
    rsync
    speedtest-cli
    ripgrep
    fd
    fzf
    zellij
    herdr

    # Version managers / runtimes
    mise
    nodejs_24
    temurin-bin-21

    # Cloud / k8s / containers (CLIs only; daemon is system-managed)
    kubectl
    podman
    podman-compose

    # Build tools
    go
    gcc
    gnumake
  ]
  ++ lib.optionals (role == "work") [ azure-cli glab gh ]
  # ghostty needs a real GPU/display; WSL has neither, so skip it there.
  ++ lib.optionals (pkgs.stdenv.hostPlatform.isLinux && !isWsl) [ (config.lib.nixGL.wrap ghostty) ];
}
