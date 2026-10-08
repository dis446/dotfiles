{ pkgs, ... }:
# Fonts are owned by Nix, not the distro.
#
# `fonts.fontconfig.enable` is the load-bearing line. home.packages only puts the
# font into the Home Manager profile, and fontconfig does not look there until HM
# writes its conf.d entry — without it every `font-family` in ghostty, zed etc.
# silently falls back to Noto Sans Mono. That is not hypothetical: the configs
# used to ask for "Iosevka Term SS04" and nothing had ever installed it, so the
# terminal had been rendering a fallback.
#
# Nerd Fonts rule of thumb, applied in the configs: use the **Mono** variant
# wherever there is a cell grid (ghostty, zed's terminal, and everything drawn
# inside them — nvim's bufferline/lualine icons, herdr, lazygit), so each glyph is
# single-width and icons align to the grid. The plain `Nerd Font` variant keeps
# upstream metrics, which suits a code buffer like zed's.
{
  home.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
  fonts.fontconfig.enable = true;
}
