{
  description = "dis446 dotfiles — flake + standalone Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # GPU library wrappers so nix GUI apps (ghostty) can use the host GPU
    # stack on non-NixOS. See home/default.nix + home/packages.nix.
    nixGL.url = "github:nix-community/nixGL";
    # AI coding agents / dev tools (orca ADE, etc.). Option A: consume its
    # per-system packages directly — its own pinned nixpkgs, best binary-cache
    # hits. No `follows` so we don't have to track unstable in lockstep.
    llm-agents.url = "github:numtide/llm-agents.nix";
    # The pi coding agent's own flake — upstream's supported install, and what
    # its `pi update` recommends over the npm-global one. Consumed per-system
    # like llm-agents; `stable` is a branch, so flake.lock pins the revision and
    # `nix flake update` is what moves the agent.
    pi.url = "github:earendil-works/pi/stable";
    # Collie — self-hosted PWA that drives herdr's panes/agents from a phone,
    # over a Tailscale tailnet. Consumed per-system like llm-agents/pi; its
    # flake wraps the release tarball by sha256 (no source build). See
    # home/collie.nix.
    collie.url = "github:AltanS/collie";
  };

  outputs = inputs@{ self, nixpkgs, home-manager, ... }:
    let
      # Semantic tags, not hostname string comparisons. mkHome asserts
      # membership so a new host cannot silently select an unknown role.
      roles = [ "personal" "work" ];

      # One entry per machine. `hostname` keys are descriptive labels; the real
      # hostname matters only for darwinConfigurations, added on the macOS track.
      hosts = {
        "fedora" = { username = "guddy"; role = "work";     platform = "fedora"; system = "x86_64-linux"; };
        "nobara" = { username = "neddy"; role = "personal"; platform = "nobara"; system = "x86_64-linux"; };
        "ubuntu" = { username = "guddy"; role = "personal"; platform = "ubuntu"; system = "x86_64-linux"; };
        # Arch rolling release (work box). No RPM Fusion equivalent — the OS
        # layer is pacman + zram-generator + flatpak (see arch/install.sh).
        "arch" = { username = "archy"; role = "work"; platform = "arch"; system = "x86_64-linux"; };
        # Fedora 44 Server (personal home desktop). No display server, no nixGL.
        "servy" = { username = "servy"; role = "personal"; platform = "fedora"; system = "x86_64-linux"; };
        # Ubuntu under WSL2 on the Windows 11 work machine. Shares the `ubuntu`
        # platform label (same shell/aliases) but `isWsl` gates host-only bits:
        # no ghostty/nixGL (no GPU/display server of its own), while herdr still
        # applies because Ubuntu WSL boots systemd.
        "wsl" = { username = "winny"; role = "work"; platform = "ubuntu"; system = "x86_64-linux"; isWsl = true; };
      };

      mkHome = hostname: { username, role, platform, system, isWsl ? false }:
        assert nixpkgs.lib.assertOneOf "role (host ${hostname})" role roles;
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          extraSpecialArgs = {
            inherit username role platform isWsl;
            nixGL = inputs.nixGL;
            llmAgents = inputs.llm-agents;
            piAgent = inputs.pi;
            collieAgent = inputs.collie;
          };
          modules = [ ./home ];
        };
    in
    {
      homeConfigurations = nixpkgs.lib.mapAttrs'
        (hostname: cfg:
          nixpkgs.lib.nameValuePair "${cfg.username}@${hostname}" (mkHome hostname cfg))
        hosts;
    };
}
