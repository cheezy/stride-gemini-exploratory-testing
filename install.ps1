<#
.SYNOPSIS
    Install the Stride exploratory-testing extension for Gemini CLI.

.DESCRIPTION
    Installs gemini-extension.json, GEMINI.md, and the commands/, skills/,
    agents/, lib/, and fixtures/ directories into your Gemini extensions
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

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# Source: the directory this script lives in if it already contains the
# extension files, otherwise clone a fresh copy to a temp dir.
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Cleanup = $null
if (Test-Path (Join-Path $ScriptDir 'gemini-extension.json')) {
    $Src = $ScriptDir
} else {
    $Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
    $Cleanup = $Tmp
    Write-Host "Downloading from $Repo..."
    git clone --quiet --depth 1 $Repo (Join-Path $Tmp $ExtName)
    $Src = Join-Path $Tmp $ExtName
}

try {
    Copy-Item (Join-Path $Src 'gemini-extension.json') -Destination $InstallDir -Force
    Copy-Item (Join-Path $Src 'GEMINI.md')             -Destination $InstallDir -Force
    $license = Join-Path $Src 'LICENSE'
    if (Test-Path $license) { Copy-Item $license -Destination $InstallDir -Force }
    foreach ($dir in @('commands', 'skills', 'agents', 'lib', 'fixtures')) {
        $dest = Join-Path $InstallDir $dir
        Copy-Item (Join-Path $Src $dir) -Destination $dest -Recurse -Force
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
