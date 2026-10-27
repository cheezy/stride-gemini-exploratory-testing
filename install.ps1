<#
.SYNOPSIS
    Install the Stride exploratory-testing extension for Gemini CLI.

.DESCRIPTION
    Installs gemini-extension.json, GEMINI.md, and the commands/, skills/,
    agents/, lib/, fixtures/, and policies/ directories into your Gemini extensions
    directory. By default installs globally to
    $env:USERPROFILE\.gemini\extensions\stride-gemini-exploratory-testing\ so
    the /charter, /nightmare-headline, /explore, /pair, /recon, /debrief, and /harden commands
    are available in all projects. Use -Project to install to
    .\.gemini\extensions\stride-gemini-exploratory-testing\ in the current
    directory instead.

    Prefer `gemini extensions install https://github.com/cheezy/stride-gemini-exploratory-testing`
    when available — this script is the manual fallback.

.PARAMETER Project
    Install into .\.gemini\extensions\ in the current directory instead of
    the global per-user location.

.PARAMETER Help
    Print usage information and exit.

.EXAMPLE
    irm https://raw.githubusercontent.com/cheezy/stride-gemini-exploratory-testing/main/install.ps1 | iex

    Installs globally to $env:USERPROFILE\.gemini\extensions\.

.EXAMPLE
    .\install.ps1 -Project

    Installs into .\.gemini\extensions\ in the current directory.
#>

[CmdletBinding()]
param(
    [switch]$Project,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

$Repo    = 'https://github.com/cheezy/stride-gemini-exploratory-testing.git'
$ExtName = 'stride-gemini-exploratory-testing'

if ($Help) {
    Write-Host 'Usage: install.ps1 [-Project]'
    Write-Host ''
    Write-Host "Prefer: gemini extensions install https://github.com/cheezy/$ExtName"
    Write-Host '        (this script is the manual fallback)'
    Write-Host ''
    Write-Host '  (default)   Install globally to $env:USERPROFILE\.gemini\extensions\stride-gemini-exploratory-testing\'
    Write-Host '  -Project    Install to .\.gemini\extensions\stride-gemini-exploratory-testing\ in the current directory'
    return
}

if ($Project) {
    $InstallDir = Join-Path (Get-Location) ".gemini\extensions\$ExtName"
    Write-Host "Installing $ExtName into .gemini\extensions\ (project-local)..."
} else {
    $InstallDir = Join-Path $env:USERPROFILE ".gemini\extensions\$ExtName"
    Write-Host "Installing $ExtName into `$env:USERPROFILE\.gemini\extensions\ (global)..."
}

# The "name" of a gemini-extension.json, or $null when it cannot be read.
function Get-ManifestName([string]$manifest) {
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { return $null }
    try { return [string]((Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json).name) } catch { return $null }
}

# Source: this script's own checkout only when the script runs from a file
# whose directory holds a manifest named $ExtName. $PSCommandPath is set only
# for this script run as a file; under `irm ... | iex` it is empty (while
# $MyInvocation can name whatever script called iex, in some other checkout).
# So a piped run, or a script beside some other manifest, never trusts that
# directory: it clones a fresh copy instead and checks the clone's manifest
# name too. The working directory is never a source.
$Src = $null
$Cleanup = $null
if ($PSCommandPath) {
    $ScriptDir = Split-Path -Parent $PSCommandPath
    if ((Get-ManifestName (Join-Path $ScriptDir 'gemini-extension.json')) -ceq $ExtName) {
        $Src = $ScriptDir
    }
}
if (-not $Src) {
    $Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
    $Cleanup = $Tmp
    Write-Host "Downloading from $Repo..."
    git clone --quiet --depth 1 $Repo (Join-Path $Tmp $ExtName)
    $Src = Join-Path $Tmp $ExtName
    if ($LASTEXITCODE -ne 0 -or (Get-ManifestName (Join-Path $Src 'gemini-extension.json')) -cne $ExtName) {
        Remove-Item -Recurse -Force $Cleanup
        throw "The downloaded copy is not $ExtName (git clone failed, or its gemini-extension.json names another extension); nothing was installed."
    }
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

try {
    Copy-Item (Join-Path $Src 'gemini-extension.json') -Destination $InstallDir -Force
    Copy-Item (Join-Path $Src 'GEMINI.md')             -Destination $InstallDir -Force
    $license = Join-Path $Src 'LICENSE'
    if (Test-Path $license) { Copy-Item $license -Destination $InstallDir -Force }
    foreach ($dir in @('commands', 'skills', 'agents', 'lib', 'fixtures', 'policies')) {
        $dest = Join-Path $InstallDir $dir
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        # Copy the directory's contents, not the directory: copying <src>\<dir>
        # onto an existing <dest> nests it as <dest>\<dir> on a re-install, so
        # an upgrade would leave new files such as skills\*\references\ in the
        # wrong place. Nested Join-Path keeps Windows PowerShell 5.1 working.
        Copy-Item (Join-Path (Join-Path $Src $dir) '*') -Destination $dest -Recurse -Force
    }
} finally {
    if ($Cleanup) { Remove-Item -Recurse -Force $Cleanup }
}

Write-Host ''
Write-Host "Stride Exploratory Testing for Gemini CLI installed to $InstallDir"
Write-Host ''
Write-Host 'Next steps:'
Write-Host '  1. Restart Gemini CLI so it picks up the new extension'
Write-Host '     (/charter, /nightmare-headline, /explore, /pair, /recon, /debrief, /harden).'
Write-Host '  2. Point it at a running, NON-PRODUCTION app you are authorized to test,'
Write-Host '     then run /charter <target> or /explore <target> to start a session.'
