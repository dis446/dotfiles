{ config, lib, pkgs, role, isWsl ? false, llmAgents, ... }:
let
  # llm-agents.nix ships its own pinned nixpkgs; reference its per-system set
  # directly (Option A) rather than overlaying ours.
  llm = llmAgents.packages.${pkgs.stdenv.hostPlatform.system};
in
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
  # GUI apps need a real GPU/display; WSL has neither, so skip them there.
  # Both are nix GUI apps on non-NixOS → nixGL wrapper (else EGL init fails).
  ++ lib.optionals (pkgs.stdenv.hostPlatform.isLinux && !isWsl) [
       (config.lib.nixGL.wrap ghostty)
       (config.lib.nixGL.wrap llm.orca)
     ];
}
