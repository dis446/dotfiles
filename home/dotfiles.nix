{ config, ... }:
let
  # Absolute repo path — these links bake it; the repo must stay at ~/dotfiles.
  repo = "${config.home.homeDirectory}/dotfiles";
  # Out-of-store symlink: the link points into the repo, so edits are live and
  # need no rebuild. A rebuild is only needed when adding/removing a top-level
  # link. Plain `source = ./path` would copy into the read-only nix store and
  # break files the app rewrites (nvim's lazy-lock.json).
  link = path: config.lib.file.mkOutOfStoreSymlink "${repo}/${path}";
in
{
  xdg.configFile = {
    # Live dir link — lazy.nvim rewrites lazy-lock.json here.
    "nvim".source = link "nvim";
    "zellij".source = link "zellij";
    "ghostty/config".source = link "ghostty/linux/config.ghostty";
    "lazygit/config.yml".source = link "lazygit/config.yml";
    # File-level: herdr writes sockets/logs/session state beside config.toml.
    "herdr/config.toml".source = link "herdr/config.toml";
    # File-level: Zed writes mutable state next to its config.
    "zed/settings.json".source = link "zed/settings.json";
    "zed/keymap.json".source = link "zed/keymap.json";
    "zed/themes".source = link "zed/themes";
  };

  home.file = {
    ".editorconfig".source = link ".editorconfig";
    ".ideavimrc".source = link "intellij/ideavimrc";
    ".gradle/gradle.properties".source = link "gradle/gradle.properties";
  };
}
