# Installer source test for the stride-gemini-exploratory-testing extension.
# PowerShell mirror of test-install.sh, run against install.ps1.
#
# Runs install.ps1 four ways and checks where it took the extension from:
#
#   1. piped (Get-Content -Raw install.ps1 | Invoke-Expression, as
#      irm ... | iex runs it) from a working directory that holds another
#      extension's gemini-extension.json;
#   2. piped from a working directory whose manifest claims this extension's
#      name (a piped run never reads the working directory at all);
#   3. run as a file that sits beside another extension's manifest;
#   4. run as a file from this checkout.
#
# Runs 1-3 must take a fresh clone and install this extension's files; run 4
# must install from this checkout without cloning. Nothing touches the network
# or a real profile directory: every run is a child PowerShell with
# USERPROFILE (and HOME) pointed at a fresh temp directory, and a stub git.ps1
# first on PATH answers `git clone` by copying this checkout (and records that
# it was called). The temp directory is removed at the end.
#
# Usage:
#   pwsh -NoProfile -File lib\test-install.ps1
#
# Exit code: 0 if every check passes; 1 if any check fails.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PluginRoot = Split-Path -Parent $ScriptDir
$ExtName = 'stride-gemini-exploratory-testing'
$Interpreter = (Get-Process -Id $PID).Path

$script:PASS = 0
$script:FAIL = 0

function Pass([string]$message) {
    $script:PASS++
    Write-Host "  [ok]   $message"
}

function Fail([string]$message, [string]$detail = '') {
    $script:FAIL++
    Write-Host "  [nope] $message"
    if ($detail) { Write-Host "         $detail" }
}

Write-Host 'stride-gemini-exploratory-testing installer source test'
Write-Host "plugin root: $PluginRoot"
Write-Host ''

$Work = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Force -Path $Work | Out-Null

# The stub git: `git clone ... <dest>` copies $env:STUB_SRC's extension files
# to <dest> and appends to $env:STUB_LOG; anything else fails.
$Bin = Join-Path $Work 'bin'
New-Item -ItemType Directory -Force -Path $Bin | Out-Null
$stub = @'
if ($args.Count -eq 0 -or $args[0] -cne 'clone') { [Console]::Error.WriteLine('stub git: only clone is supported'); exit 2 }
$dest = $args[$args.Count - 1]
New-Item -ItemType Directory -Force -Path $dest | Out-Null
foreach ($f in @('gemini-extension.json', 'GEMINI.md', 'LICENSE')) {
    $p = Join-Path $env:STUB_SRC $f
    if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination $dest }
}
foreach ($d in @('commands', 'skills', 'agents', 'lib', 'fixtures', 'policies')) {
    Copy-Item -LiteralPath (Join-Path $env:STUB_SRC $d) -Destination $dest -Recurse
}
Add-Content -LiteralPath $env:STUB_LOG -Value 'clone'
exit 0
'@
[IO.File]::WriteAllText((Join-Path $Bin 'git.ps1'), $stub)

# A foreign extension checkout and an impostor that claims this name.
function New-Checkout([string]$dir, [string]$name) {
    New-Item -ItemType Directory -Force -Path (Join-Path $dir 'commands') | Out-Null
    [IO.File]::WriteAllText((Join-Path $dir 'gemini-extension.json'), "{`n  `"name`": `"$name`",`n  `"version`": `"9.9.9`",`n  `"contextFileName`": `"GEMINI.md`"`n}`n")
    [IO.File]::WriteAllText((Join-Path $dir 'GEMINI.md'), "FOREIGN CONTEXT FILE`n")
    [IO.File]::WriteAllText((Join-Path (Join-Path $dir 'commands') 'foreign-only.toml'), "description = `"foreign`"`nprompt = `"foreign`"`n")
}
$Foreign = Join-Path $Work 'foreign'
$Impostor = Join-Path $Work 'impostor'
New-Checkout $Foreign 'some-other-extension'
New-Checkout $Impostor $ExtName
Copy-Item -LiteralPath (Join-Path $PluginRoot 'install.ps1') -Destination (Join-Path $Foreign 'install.ps1')

function Get-Quoted([string]$s) { return "'" + $s.Replace("'", "''") + "'" }

# Invoke-Case <home> <cwd> <piped|file> <script> <stub source>
# Returns @{ Status; Output; Dest; Clones }.
function Invoke-Case([string]$homeDir, [string]$cwd, [string]$mode, [string]$script, [string]$stubSrc) {
    New-Item -ItemType Directory -Force -Path $homeDir | Out-Null
    $log = Join-Path $Work 'clone-calls'
    [IO.File]::WriteAllText($log, '')
    if ($mode -ceq 'piped') {
        $cmd = "Set-Location -LiteralPath $(Get-Quoted $cwd); Get-Content -Raw -LiteralPath $(Get-Quoted $script) | Invoke-Expression"
    } else {
        $cmd = "Set-Location -LiteralPath $(Get-Quoted $cwd); & $(Get-Quoted $script)"
    }
    $saved = @{}
    foreach ($k in @('USERPROFILE', 'HOME', 'PATH', 'STUB_SRC', 'STUB_LOG')) { $saved[$k] = [Environment]::GetEnvironmentVariable($k) }
    try {
        [Environment]::SetEnvironmentVariable('USERPROFILE', $homeDir)
        [Environment]::SetEnvironmentVariable('HOME', $homeDir)
        [Environment]::SetEnvironmentVariable('PATH', $Bin + [IO.Path]::PathSeparator + $saved['PATH'])
        [Environment]::SetEnvironmentVariable('STUB_SRC', $stubSrc)
        [Environment]::SetEnvironmentVariable('STUB_LOG', $log)
        $out = (& $Interpreter -NoProfile -Command $cmd 2>&1 | Out-String)
        $status = $LASTEXITCODE
    } finally {
        foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
    $clones = @([IO.File]::ReadAllLines($log) | Where-Object { $_ -ceq 'clone' }).Count
    return @{ Status = $status; Output = $out; Dest = (Join-Path (Join-Path (Join-Path $homeDir '.gemini') 'extensions') $ExtName); Clones = $clones }
}

function Test-SameFile([string]$a, [string]$b) {
    if (-not (Test-Path -LiteralPath $a -PathType Leaf)) { return $false }
    return (Get-FileHash -LiteralPath $a).Hash -ceq (Get-FileHash -LiteralPath $b).Hash
}

function Test-Case([string]$label, $run, [int]$wantClones) {
    $problems = ''
    if ($run.Status -ne 0) {
        $last = @(($run.Output.Trim() -split "`n") | Select-Object -Last 1)[0]
        $problems += " [exit $($run.Status): $last]"
    }
    if (-not (Test-SameFile (Join-Path $run.Dest 'gemini-extension.json') (Join-Path $PluginRoot 'gemini-extension.json'))) { $problems += " [installed manifest is not this extension's]" }
    if (-not (Test-SameFile (Join-Path $run.Dest 'GEMINI.md') (Join-Path $PluginRoot 'GEMINI.md'))) { $problems += " [installed GEMINI.md is not this extension's]" }
    if (-not (Test-Path -LiteralPath (Join-Path (Join-Path $run.Dest 'commands') 'explore.toml'))) { $problems += ' [commands/explore.toml not installed]' }
    if (Test-Path -LiteralPath (Join-Path (Join-Path $run.Dest 'commands') 'foreign-only.toml')) { $problems += ' [a foreign command was installed]' }
    if ($run.Clones -ne $wantClones) { $problems += " [git clone called $($run.Clones) time(s), want $wantClones]" }
    if ($problems -eq '') { Pass $label } else { Fail $label $problems }
}

try {
    $installer = Join-Path $PluginRoot 'install.ps1'
    if ((Test-Path -LiteralPath $installer) -and (Test-Path -LiteralPath (Join-Path $PluginRoot 'gemini-extension.json'))) {
        $r = Invoke-Case (Join-Path $Work 'home1') $Foreign 'piped' $installer $PluginRoot
        Test-Case "piped install.ps1 run from another extension's checkout clones and installs this extension, not the working directory's" $r 1

        $r = Invoke-Case (Join-Path $Work 'home2') $Impostor 'piped' $installer $PluginRoot
        Test-Case "piped install.ps1 ignores a working directory whose manifest claims this extension's name" $r 1

        $r = Invoke-Case (Join-Path $Work 'home3') $Work 'file' (Join-Path $Foreign 'install.ps1') $PluginRoot
        Test-Case "install.ps1 run as a file beside another extension's manifest clones instead of installing it" $r 1

        $r = Invoke-Case (Join-Path $Work 'home4') $Foreign 'file' $installer $PluginRoot
        Test-Case 'install.ps1 run as a file from this checkout installs it without cloning, whatever the working directory' $r 0

        # The guard on the clone: a download that is not this extension installs nothing.
        $other = Join-Path $Work 'other-src'
        New-Item -ItemType Directory -Force -Path $other | Out-Null
        foreach ($d in @('commands', 'skills', 'agents', 'lib', 'fixtures', 'policies')) { Copy-Item -LiteralPath (Join-Path $PluginRoot $d) -Destination $other -Recurse }
        Copy-Item -LiteralPath (Join-Path $PluginRoot 'GEMINI.md') -Destination $other
        $manifest = [IO.File]::ReadAllText((Join-Path $PluginRoot 'gemini-extension.json')).Replace("`"name`": `"$ExtName`"", '"name": "some-other-extension"')
        [IO.File]::WriteAllText((Join-Path $other 'gemini-extension.json'), $manifest)
        $r = Invoke-Case (Join-Path $Work 'home5') $Foreign 'piped' $installer $other
        if ($r.Status -ne 0 -and -not (Test-Path -LiteralPath (Join-Path $r.Dest 'gemini-extension.json'))) {
            Pass 'a downloaded copy whose manifest names another extension stops the install with nothing installed'
        } else {
            Fail 'a downloaded copy whose manifest names another extension stops the install with nothing installed' "exit $($r.Status)"
        }
    } else {
        Fail 'installer source checks need install.ps1 and gemini-extension.json' ''
    }
} finally {
    Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "$($script:PASS) passed, $($script:FAIL) failed"
if ($script:FAIL -gt 0) { exit 1 }
