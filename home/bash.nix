{ config, platform, ... }:
{
  # Home Manager owns ~/.bashrc. The repo rc is sourced from it, so the alias
  # files under bash/ stay the single source and remain editable without a
  # rebuild. Do not also symlink ~/.bashrc in the install scripts — they fight.
  programs.bash = {
    enable = true;
    enableCompletion = true;

    # initExtra runs after Home Manager's interactive-shell guard
    # (`[[ $- == *i* ]] || return`), so non-interactive shells skip it.
    initExtra = ''
      # ~/.profile sources hm-session-vars for login shells; source it here too
      # so interactive non-login shells (tmux/herdr panes) also get the nix
      # profile and sessionPath on PATH. The file self-guards against re-entry.
      [ -f "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh" ] \
        && source "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"

      # OS rc sources ~/dotfiles/bash/* plus the OS-specific aliases and env.
      # Ubuntu has no <os>/bashrc — source the shared aliases directly there.
      if [ -f "$HOME/dotfiles/${platform}/bashrc" ]; then
        source "$HOME/dotfiles/${platform}/bashrc"
      else
        for alias_file in "$HOME/dotfiles/bash/"*; do
          [ -f "$alias_file" ] && source "$alias_file"
        done
        [ -f "$HOME/dotfiles/${platform}/bash_aliases" ] && source "$HOME/dotfiles/${platform}/bash_aliases"
      fi
    '';
  };
}
