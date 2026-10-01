#Requires -Version 5.1
<#
.SYNOPSIS
    Native-Windows layer for the dis446 dotfiles (Option C).

.DESCRIPTION
    The dev environment lives in WSL2 (Ubuntu + Nix + Home Manager). This script
    only sets up what must exist natively on Windows:

      * links the PowerShell profile to WindowsPowerShell/
      * installs a curated set of Scoop CLI tools
      * imports a curated set of winget GUI/dev apps

    Idempotent: safe to re-run. It does NOT enable/install WSL itself — run
    `wsl --install -d Ubuntu` from an admin shell first, then follow the WSL
    steps printed at the end (and the "Windows / WSL" section of AGENTS.md).

    Curated on purpose, not a full `scoop export` / `winget export` dump: this
    machine is also a gaming/hardware box, and drivers, Steam games and vendor
    utilities have no business being reproduced from the dotfiles.

.EXAMPLE
    pwsh -File .\windows\install.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot     # ...\dotfiles
$here = $PSScriptRoot                        # ...\dotfiles\windows

function info($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function ok($m)   { Write-Host "  ok  $m" -ForegroundColor Green }
function warn($m) { Write-Host "  !!  $m" -ForegroundColor Yellow }

# ---------------------------------------------------------------------------
# 1. PowerShell profile -> WindowsPowerShell/profile.ps1
# ---------------------------------------------------------------------------
info 'Linking the PowerShell profile'
$profileSource = Join-Path $repo 'WindowsPowerShell\profile.ps1'

# Windows PowerShell 5.1 always; PowerShell 7 only when pwsh is installed.
$profileDirs = @((Join-Path $HOME 'Documents\WindowsPowerShell'))
if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    $profileDirs += (Join-Path $HOME 'Documents\PowerShell')
}

foreach ($dir in $profileDirs) {
    $dest = Join-Path $dir 'profile.ps1'   # $PROFILE.CurrentUserAllHosts
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    if (Test-Path $dest) { Remove-Item $dest -Force -Recurse }
    try {
        New-Item -ItemType SymbolicLink -Path $dest -Target $profileSource -Force | Out-Null
        ok "linked $dest"
    } catch {
        Copy-Item $profileSource $dest -Force
        warn "symlink refused (enable Developer Mode); copied instead: $dest"
    }
}

# ---------------------------------------------------------------------------
# 2. Scoop — buckets + curated CLI apps
# ---------------------------------------------------------------------------
$scoopManifest = Join-Path $here 'scoop.json'
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    info 'Scoop buckets + CLI apps'
    $manifest = Get-Content $scoopManifest -Raw | ConvertFrom-Json

    foreach ($bucket in $manifest.buckets) {
        $present = @(scoop bucket list) -match "^\s*$([regex]::Escape($bucket.Name))\s"
        if (-not $present) {
            scoop bucket add $bucket.Name | Out-Null
            ok "bucket $($bucket.Name)"
        }
    }

    $installed = @(scoop list | ForEach-Object { ($_.ToString().Trim() -split '\s+')[0] })
    foreach ($app in $manifest.apps) {
        if ($installed -notcontains $app.Name) {
            scoop install "$($app.Source)/$($app.Name)" | Out-Null
            ok "installed $($app.Name)"
        } else {
            ok "$($app.Name) already installed"
        }
    }
} else {
    warn 'scoop not found — install from https://scoop.sh, then re-run'
}

# ---------------------------------------------------------------------------
# 3. winget — curated GUI / dev apps
# ---------------------------------------------------------------------------
$wingetManifest = Join-Path $here 'winget.json'
if (Get-Command winget -ErrorAction SilentlyContinue) {
    info 'winget GUI/dev apps'
    winget import -i $wingetManifest `
        --accept-package-agreements --accept-source-agreements --ignore-unavailable |
        Out-Null
    ok 'winget import finished'
} else {
    warn 'winget not found — skipping GUI apps'
}

# ---------------------------------------------------------------------------
# 4. Next steps (WSL2)
# ---------------------------------------------------------------------------
Write-Host ''
info 'Windows layer done. Remaining WSL2 steps:'
Write-Host @'
  1. wsl --install -d Ubuntu              # admin PowerShell; reboot when asked
  2. install the distro, create user "winny", enable systemd in /etc/wsl.conf:
       [boot]
       systemd=true
       [user]
       default=winny
     then `wsl --shutdown` from Windows
  3. inside Ubuntu: sudo apt update && sudo apt install -y curl git
  4. git clone git@github.com:dis446/dotfiles.git ~/dotfiles
  5. curl -fsSL https://install.determinate.systems/nix | sh -s -- install
  6. ~/dotfiles/ubuntu/install.sh
  7. home-manager switch --flake ~/dotfiles#winny@wsl
  See AGENTS.md ("Windows / WSL") for the full walkthrough.
'@ -ForegroundColor Gray
