# Structure smoke test for the stride-gemini-exploratory-testing extension.
# PowerShell mirror of test-structure.sh.
#
# Confirms the extension's required files and directories exist and that the
# gemini-extension.json manifest is valid JSON carrying name/version/
# contextFileName. Offline and read-only — it never executes or evaluates any
# extension file; it only checks existence and parses the manifest as data.
#
# The manifest is gemini-extension.json at the ROOT (Gemini CLI convention).
# This test deliberately does NOT look for a .claude-plugin/plugin.json or a
# package.json — the Gemini extension has neither.
#
# Exit code: 0 if every check passes; 1 if any check fails.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PluginRoot = Split-Path -Parent $ScriptDir

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

function Test-Exists([string]$relative, [string]$label) {
    $path = Join-Path $PluginRoot $relative
    if (Test-Path -LiteralPath $path) {
        Pass "$label exists ($relative)"
    } else {
        Fail "$label missing" $relative
    }
}

Write-Host 'stride-gemini-exploratory-testing structure test'
Write-Host "plugin root: $PluginRoot"
Write-Host ''

# --- Manifest ---------------------------------------------------------------

Write-Host 'Manifest'
$manifest = Join-Path $PluginRoot 'gemini-extension.json'
if (-not (Test-Path -LiteralPath $manifest)) {
    Fail 'gemini-extension.json missing at the root' $manifest
} else {
    try {
        $data = Get-Content -Raw -LiteralPath $manifest | ConvertFrom-Json
        $present = @($data.PSObject.Properties.Name)
        $missing = @()
        foreach ($key in @('name', 'version', 'contextFileName')) {
            if ($present -notcontains $key) { $missing += $key }
        }
        if ($missing.Count -gt 0) {
            Fail 'gemini-extension.json missing keys' ($missing -join ', ')
        } else {
            Pass 'gemini-extension.json is valid JSON with name/version/contextFileName'
        }
    } catch {
        Fail 'gemini-extension.json invalid JSON' $_.Exception.Message
    }
}

# Guard: the Gemini extension must NOT rely on Claude Code / npm manifests.
if (Test-Path -LiteralPath (Join-Path $PluginRoot '.claude-plugin/plugin.json')) {
    Fail 'unexpected .claude-plugin/plugin.json present' 'the Gemini extension is declared by gemini-extension.json only'
} else {
    Pass 'no .claude-plugin/plugin.json (correct for a Gemini extension)'
}
if (Test-Path -LiteralPath (Join-Path $PluginRoot 'package.json')) {
    Fail 'unexpected package.json present' 'the Gemini extension does not use npm'
} else {
    Pass 'no package.json (correct for a Gemini extension)'
}

# --- Skills -----------------------------------------------------------------

Write-Host ''
Write-Host 'Skills'
foreach ($skill in @('stride-exploratory-testing', 'chartering', 'heuristics', 'oracles', 'session')) {
    Test-Exists "skills/$skill/SKILL.md" "skill '$skill' SKILL.md"
}

# --- Commands ---------------------------------------------------------------

Write-Host ''
Write-Host 'Commands'
foreach ($cmd in @('charter', 'nightmare-headline', 'explore', 'recon', 'debrief')) {
    Test-Exists "commands/$cmd.toml" "command /$cmd"
}

# --- Agents -----------------------------------------------------------------

Write-Host ''
Write-Host 'Agents'
foreach ($agent in @('charter-generator', 'explorer')) {
    Test-Exists "agents/$agent.md" "agent '$agent'"
}

# --- Root docs & license ----------------------------------------------------

Write-Host ''
Write-Host 'Root docs'
foreach ($doc in @('GEMINI.md', 'README.md', 'HEURISTICS.md', 'CHANGELOG.md', 'LICENSE')) {
    Test-Exists $doc $doc
}

# --- Fixtures ---------------------------------------------------------------

Write-Host ''
Write-Host 'Fixtures'
foreach ($fx in @('example-charters.md', 'example-session-sheet.md', 'example-debrief.md')) {
    Test-Exists "fixtures/$fx" "fixture $fx"
}

# --- Summary ----------------------------------------------------------------

Write-Host ''
Write-Host "$($script:PASS) passed, $($script:FAIL) failed"
if ($script:FAIL -gt 0) { exit 1 }
