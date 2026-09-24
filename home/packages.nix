{ config, lib, pkgs, role, ... }:
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
  ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ (config.lib.nixGL.wrap ghostty) ];
}
