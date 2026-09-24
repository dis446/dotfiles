{ config, ... }:
{
  programs.git = {
    enable = true;

    # Personal identity only. The work identity lives in an untracked
    # machine-local file (see below) — employer identifiers must never be
    # committed (scripts/check-identifiers.sh).
    settings = {
      user.name = "Tsetsen-erdene Ganbaatar";
      user.email = "dis446@yahoo.com";

      init.defaultBranch = "main";
      pull.rebase = true;

      diff.tool = "nvimdiff";
      difftool.nvimdiff.cmd = "nvim -d \"$LOCAL\" \"$REMOTE\"";
      merge.tool = "nvimdiff";
      mergetool.nvimdiff.cmd = "nvim -d \"$LOCAL\" \"$BASE\" \"$REMOTE\" \"$MERGED\"";
    };

    # Machine-local overrides. The work identity lives in this untracked file
    # (not in the repo, so employer identifiers never get committed). A missing
    # file is silently ignored by git.
    includes = [
      { path = "${config.home.homeDirectory}/.gitconfig-local"; }
    ];
  };
}
