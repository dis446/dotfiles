{ config, lib, pkgs, role, isWsl ? false, llmAgents, piAgent, ... }:
let
  # llm-agents.nix ships its own pinned nixpkgs; reference its per-system set
  # directly (Option A) rather than overlaying ours.
  llm = llmAgents.packages.${pkgs.stdenv.hostPlatform.system};
  # Same for pi: its own flake builds the agent from the upstream npm tree (real
  # node_modules + dist/bundle/cli.js, not a bun-compiled binary), which is the
  # host layout pi-subagents resolves when spawning child agents.
  piPkg = piAgent.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  home.packages = with pkgs; [
    # AI coding agent. The binary moves with the flake input (no npm global);
    # plugins stay agent-managed under ~/.pi/agent/npm.
    piPkg

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
    herdr

    # Version managers / runtimes
    mise
    nodejs_24
    temurin-bin-21

    # Cloud / k8s / containers (CLIs only; daemon is system-managed)
    kubectl
    k9s
    podman
    podman-compose
    lazydocker

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
