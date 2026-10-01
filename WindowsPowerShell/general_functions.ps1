# Windows-side shell layer, loaded by WindowsPowerShell/profile.ps1.
#
# Option C: the dev environment lives in WSL2 (Ubuntu + Nix + Home Manager);
# this file only covers the native PowerShell session and the Windows-native
# tools. Keep behaviour/feel aligned with the bash aliases where it makes sense.

Set-Alias c Clear-Host

# Captured at load time: $PSScriptRoot is not reliable inside a function after
# the profile is dot-sourced through a symlink.
$script:DotfilesPowerShellDir = $PSScriptRoot

# Re-source the Windows shell layer after an edit (mirrors bash `src`).
function src {
    Get-ChildItem -Path $script:DotfilesPowerShellDir -Filter '*.ps1' -File |
        Where-Object { $_.Name -ne 'profile.ps1' } |
        ForEach-Object { . $_.FullName }
}

# Jump to the repo root (mirrors bash `dtf`).
function dtf { Set-Location (Join-Path $HOME 'dotfiles') }

# Shortcuts for the CLI tools windows/install.ps1 puts on PATH.
Set-Alias v nvim
Set-Alias lg lazygit
