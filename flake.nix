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
        "nobara" = { username = "guddy"; role = "personal"; platform = "nobara"; system = "x86_64-linux"; };
        "ubuntu" = { username = "guddy"; role = "personal"; platform = "ubuntu"; system = "x86_64-linux"; };
      };

      mkHome = hostname: { username, role, platform, system }:
        assert nixpkgs.lib.assertOneOf "role (host ${hostname})" role roles;
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          extraSpecialArgs = { inherit username role platform; nixGL = inputs.nixGL; };
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
