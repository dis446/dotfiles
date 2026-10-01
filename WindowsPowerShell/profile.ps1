# $PROFILE entry point. Linked by windows/install.ps1 — do not add logic here.
# Edit the topic files under WindowsPowerShell/ instead (general_functions.ps1,
# git_functions.ps1, work_functions.ps1); this just loads them.
#
# The repo lives at ~\dotfiles on Windows too — the same absolute-path
# invariant the Nix side bakes (see home/dotfiles.nix).
$dotfilesPowerShell = Join-Path $HOME 'dotfiles\WindowsPowerShell'

Get-ChildItem -Path $dotfilesPowerShell -Filter '*.ps1' -File |
    Where-Object { $_.Name -ne 'profile.ps1' } |
    ForEach-Object { . $_.FullName }
