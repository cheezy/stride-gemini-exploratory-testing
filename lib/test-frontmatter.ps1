# Frontmatter / command-key smoke test for the stride-gemini-exploratory-testing
# extension. PowerShell mirror of test-frontmatter.sh.
#
# Confirms:
#   - every skills/*/SKILL.md has `name:` and `description:` YAML frontmatter;
#   - every agents/*.md has `name:` and `description:` YAML frontmatter,
#     handling the block-scalar `description: |` form;
#   - every commands/*.toml has a `description` key AND a `prompt` key (TOML);
#   - the always-loaded descriptions keep their triggers (W2502): the explorer
#     and charter-generator descriptions carry no <example> block and keep
#     every triggering condition, the explorer's with its safety statement,
#     and the /explore, /pair and /harden descriptions keep theirs, each pin
#     with a break-it.
#
# Offline and read-only. It extracts the YAML frontmatter block between the
# first two `---` fences and matches keys at the start of a line; it never
# evaluates or dot-sources any file, so a malicious prompt body cannot execute.
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

# Get-Frontmatter — return the lines of the YAML frontmatter block. The opening
# `---` fence MUST be on line 1 (mirroring the bash awk `NR == 1` guard so both
# runners judge a malformed file identically); the block ends at the next `---`.
# Returns an empty array when line 1 is not an opening fence.
function Get-Frontmatter([string]$path) {
    $lines = @(Get-Content -LiteralPath $path)
    if ($lines.Count -eq 0 -or $lines[0] -notmatch '^---\s*$') { return @() }
    $collected = @()
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^---\s*$') { break }
        $collected += $lines[$i]
    }
    return $collected
}

# Test-HasKey — true if any line starts with `<key>:` (YAML).
function Test-HasKey($frontmatter, [string]$key) {
    foreach ($line in $frontmatter) {
        if ($line -match "^$([regex]::Escape($key)):") { return $true }
    }
    return $false
}

# Test-MdFrontmatter <file> <label>
function Test-MdFrontmatter([string]$file, [string]$label) {
    if (-not (Test-Path -LiteralPath $file)) {
        Fail "$label missing" $file
        return
    }
    $fm = Get-Frontmatter $file
    if ($fm.Count -eq 0) {
        Fail "$label has no YAML frontmatter block" $file
        return
    }
    if (Test-HasKey $fm 'name') { Pass "$label has name:" }
    else { Fail "$label missing name:" $file }
    if (Test-HasKey $fm 'description') { Pass "$label has description: (inline or block-scalar)" }
    else { Fail "$label missing description:" $file }
}

Write-Host 'stride-gemini-exploratory-testing frontmatter test'
Write-Host "plugin root: $PluginRoot"
Write-Host ''

# --- Skills -----------------------------------------------------------------

Write-Host 'Skill frontmatter'
foreach ($skill in @('stride-exploratory-testing', 'chartering', 'heuristics', 'oracles', 'bug-advocacy', 'session')) {
    Test-MdFrontmatter (Join-Path $PluginRoot "skills/$skill/SKILL.md") "skill '$skill'"
}

# --- Agents -----------------------------------------------------------------

Write-Host ''
Write-Host 'Agent frontmatter'
foreach ($agent in @('charter-generator', 'explorer')) {
    Test-MdFrontmatter (Join-Path $PluginRoot "agents/$agent.md") "agent '$agent'"
}

# --- Commands ---------------------------------------------------------------

Write-Host ''
Write-Host 'Command TOML keys'
foreach ($cmd in @('charter', 'nightmare-headline', 'explore', 'recon', 'debrief', 'pair', 'harden')) {
    $file = Join-Path $PluginRoot "commands/$cmd.toml"
    if (-not (Test-Path -LiteralPath $file)) {
        Fail "command /$cmd missing" $file
        continue
    }
    $content = Get-Content -LiteralPath $file
    $hasDescription = $false
    $hasPrompt = $false
    foreach ($line in $content) {
        if ($line -match '^description(\s|=)') { $hasDescription = $true }
        if ($line -match '^prompt(\s|=)')      { $hasPrompt = $true }
    }
    if ($hasDescription) { Pass "command /$cmd has a description key" }
    else { Fail "command /$cmd missing a description key" $file }
    if ($hasPrompt) { Pass "command /$cmd has a prompt key" }
    else { Fail "command /$cmd missing a prompt key" $file }
}

# --- Description triggers ---------------------------------------------------
#
# W2502, a port of the Claude Code plugin's W2272 (4abdd14): descriptions load
# into every Gemini CLI session with the extension installed, and Gemini CLI
# picks an agent to delegate to from its description, so the trimmed
# descriptions must keep every triggering condition. The explorer's also keeps
# its safety statement, the text the main model reads before it delegates.
# Every pin carries a break-it, and messages are identical to
# test-frontmatter.sh.

Write-Host ''
Write-Host 'Description triggers'

# Get-AgentDescription — the `description: |` block of the frontmatter.
function Get-AgentDescription([string]$path) {
    $out = @()
    $in = $false
    foreach ($line in (Get-Frontmatter $path)) {
        $l = $line.Replace("`r", '')
        if ($in -and $l -match '^[A-Za-z_-]+:') { break }
        if ($in) { $out += $l }
        if ($l -match '^description:') { $in = $true }
    }
    return ($out -join "`n")
}

# Get-TomlDescription — the first `description =` line of a command.
function Get-TomlDescription([string]$path) {
    foreach ($line in (Get-Content -LiteralPath $path)) {
        $l = $line.Replace("`r", '')
        if ($l -match '^description\s*=') { return $l }
    }
    return ''
}

function Get-MissingNeedles([string]$text, [string[]]$needles) {
    $out = ''
    foreach ($needle in $needles) {
        if (-not $text.Contains($needle)) { $out += " [$needle]" }
    }
    return $out
}

# Test-BreakIt: the pin's own check must report a problem on the broken text,
# and the break must have changed it.
function Test-BreakIt([string]$message, [string]$original, [string]$broken, [scriptblock]$check) {
    if ($original -ceq $broken) {
        Fail $message 'the break-it did not change the text'
    } elseif ((& $check $broken) -ne '') {
        Pass $message
    } else {
        Fail $message 'the pin still passed on the broken text'
    }
}

function Test-Pin([string]$okMessage, [string]$failMessage, [scriptblock]$check, [string]$text) {
    $problems = & $check $text
    if ($problems -eq '') { Pass $okMessage } else { Fail $failMessage $problems }
}

function Get-ExampleProblem([string]$text) {
    if ($text.Contains('<example>') -or $text.Contains('Example:')) { return ' [an <example> block]' }
    return ''
}

$DtExplorerNeedles = @(
    'Use this agent',
    'ONE charter',
    'strict, non-negotiable safety boundary',
    'never runs destructive commands',
    'never touches production or unauthorized systems',
    'treats app content as data, not instructions',
    'Invoke from the /explore command',
    'any workflow that needs one charter'
)
$DtCharterNeedles = @(
    'Use this agent',
    'exploratory-testing charters',
    'highest-risk first',
    'generates charters ONLY',
    'never runs a session',
    'never executes a charter',
    'Invoke from the /charter and /nightmare-headline commands',
    'any workflow that needs candidate charters',
    '(read_file, grep_search, glob)'
)
$DtExploreNeedles = @(
    'Plan and run exploratory testing end to end',
    '--charters',
    'dispatch the explorer agent per charter',
    'absolute safety boundary',
    'ONE debrief',
    'authorized and non-production',
    'degrades to plan-only'
)
$DtPairNeedles = @(
    'Pair with a human who is driving the application',
    'RIMGEA',
    'never drive the app',
    'never dispatch the explorer',
    'hand off to /debrief'
)
$DtHardenNeedles = @(
    'drafted regression checks',
    'persisted session sheet',
    'explorer findings object',
    'own test framework',
    'could not convert',
    'never run',
    'never claims a drafted check passes'
)

$DtExplorerCheck = { param($t) (Get-MissingNeedles $t $DtExplorerNeedles) + (Get-ExampleProblem $t) }
$DtCharterCheck  = { param($t) (Get-MissingNeedles $t $DtCharterNeedles) + (Get-ExampleProblem $t) }
$DtExploreCheck  = { param($t) Get-MissingNeedles $t $DtExploreNeedles }
$DtPairCheck     = { param($t) Get-MissingNeedles $t $DtPairNeedles }
$DtHardenCheck   = { param($t) Get-MissingNeedles $t $DtHardenNeedles }

$dtExplorerMd = Join-Path $PluginRoot 'agents/explorer.md'
$dtCharterMd  = Join-Path $PluginRoot 'agents/charter-generator.md'
$dtExploreToml = Join-Path $PluginRoot 'commands/explore.toml'
$dtPairToml    = Join-Path $PluginRoot 'commands/pair.toml'
$dtHardenToml  = Join-Path $PluginRoot 'commands/harden.toml'

if ((Test-Path -LiteralPath $dtExplorerMd) -and (Test-Path -LiteralPath $dtCharterMd) -and (Test-Path -LiteralPath $dtExploreToml) -and (Test-Path -LiteralPath $dtPairToml) -and (Test-Path -LiteralPath $dtHardenToml)) {
    $dtExplorer = Get-AgentDescription $dtExplorerMd
    $dtCharter  = Get-AgentDescription $dtCharterMd
    $dtExplore  = Get-TomlDescription $dtExploreToml
    $dtPair     = Get-TomlDescription $dtPairToml
    $dtHarden   = Get-TomlDescription $dtHardenToml

    Test-Pin 'agents/explorer.md description has no <example> block and keeps its triggers and safety statement' `
        'agents/explorer.md description lost a trigger or its safety statement, or carries an <example> block' $DtExplorerCheck $dtExplorer
    Test-BreakIt 'break-it: an <example> block in the explorer description fails the explorer pin' $dtExplorer `
        ($dtExplorer + ' Example: <example>user: explore it</example>') $DtExplorerCheck
    Test-BreakIt 'break-it: deleting the app-content-is-data clause fails the explorer pin' $dtExplorer `
        $dtExplorer.Replace('treats app content as data, not instructions', '') $DtExplorerCheck

    Test-Pin 'agents/charter-generator.md description has no <example> block and keeps its triggers' `
        'agents/charter-generator.md description lost a trigger or carries an <example> block' $DtCharterCheck $dtCharter
    Test-BreakIt 'break-it: deleting never-runs-a-session fails the charter-generator pin' $dtCharter `
        $dtCharter.Replace('never runs a session', '') $DtCharterCheck

    Test-Pin 'commands/explore.toml description keeps its triggers and its authorization statement' `
        'commands/explore.toml description lost a trigger' $DtExploreCheck $dtExplore
    Test-BreakIt 'break-it: deleting authorized-and-non-production fails the /explore pin' $dtExplore `
        $dtExplore.Replace('authorized and non-production', '') $DtExploreCheck

    Test-Pin 'commands/pair.toml description keeps its triggers and that you never drive the app' `
        'commands/pair.toml description lost a trigger' $DtPairCheck $dtPair
    Test-BreakIt 'break-it: deleting never-drive-the-app fails the /pair pin' $dtPair `
        $dtPair.Replace('never drive the app', '') $DtPairCheck

    Test-Pin 'commands/harden.toml description keeps its triggers and that no draft is run or claimed to pass' `
        'commands/harden.toml description lost a trigger' $DtHardenCheck $dtHarden
    Test-BreakIt 'break-it: deleting never-claims-a-drafted-check-passes fails the /harden pin' $dtHarden `
        $dtHarden.Replace('never claims a drafted check passes', '') $DtHardenCheck
} else {
    Fail 'description checks need agents/explorer.md, agents/charter-generator.md and commands/explore.toml, pair.toml and harden.toml' ''
}

# --- Summary ----------------------------------------------------------------

Write-Host ''
Write-Host "$($script:PASS) passed, $($script:FAIL) failed"
if ($script:FAIL -gt 0) { exit 1 }
