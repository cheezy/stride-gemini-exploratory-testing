# Structure smoke test for the stride-gemini-exploratory-testing extension.
# PowerShell mirror of test-structure.sh.
#
# Confirms the extension's required files and directories exist and that the
# gemini-extension.json manifest is valid JSON carrying name/version/
# contextFileName. It also pins the explorer card in agents/explorer.md, check
# for check with test-structure.sh: its markers and position after the safety
# boundary, a 4,096-byte cap, its severity values, order and ladder against
# bug-advocacy's four levels, its stop rules against the output contract's
# stop_reason values, the RIMGEA, oracle and edge-rule text, the pointers to
# the card, and the skill references' extensionPath form (no other template
# token in agents/*.md).
#
# Offline and read-only — it never executes or evaluates any extension file; it
# checks existence, parses the manifest as data, and reads agents/*.md and
# skills/bug-advocacy/SKILL.md as text with .NET string and regex calls.
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
foreach ($skill in @('stride-exploratory-testing', 'chartering', 'heuristics', 'oracles', 'bug-advocacy', 'session')) {
    Test-Exists "skills/$skill/SKILL.md" "skill '$skill' SKILL.md"
}

# --- Commands ---------------------------------------------------------------

Write-Host ''
Write-Host 'Commands'
foreach ($cmd in @('charter', 'nightmare-headline', 'explore', 'recon', 'debrief', 'pair', 'harden')) {
    Test-Exists "commands/$cmd.toml" "command /$cmd"
}

# --- Agents -----------------------------------------------------------------

Write-Host ''
Write-Host 'Agents'
foreach ($agent in @('charter-generator', 'explorer')) {
    Test-Exists "agents/$agent.md" "agent '$agent'"
}

# --- Explorer card ----------------------------------------------------------
#
# Every rule the explorer needs to rate a bug and end a session lives on an
# inline card, because the extension's skills sit outside the workspace that
# read_file resolves against and may never load. These pins mirror
# test-structure.sh check for check, with the same messages: the card's
# markers and position after the safety boundary, its 4,096-byte cap, its
# severity values against bug-advocacy's four levels, its stop rules against
# the output contract, and the skill references' extensionPath form.
# Comparisons are ordinal and case-sensitive (-ceq / -cne / Ordinal), never
# -match, so a case change is caught exactly as the bash checks catch it.

Write-Host ''
Write-Host 'Explorer card'

function Read-Lines([string]$path) {
    # Split on LF only and keep any CR, so byte counts match sed -n | wc -c.
    $parts = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) -split "`n"
    $list = New-Object 'System.Collections.Generic.List[string]'
    foreach ($p in $parts) { $list.Add($p) }
    if ($list.Count -gt 0 -and $list[$list.Count - 1] -eq '') { $list.RemoveAt($list.Count - 1) }
    return ,$list
}

function Get-Ticked([string]$text, [string]$pattern) {
    $out = New-Object 'System.Collections.Generic.List[string]'
    foreach ($m in [regex]::Matches($text, $pattern)) { $out.Add($m.Groups[1].Value) }
    return ,$out
}

function Get-MissingNeedles([string]$text, [string[]]$needles) {
    $out = ''
    foreach ($needle in $needles) {
        if (-not $text.Contains($needle)) { $out += " [$needle]" }
    }
    return $out
}

function Get-Count([string]$text, [string]$needle) {
    $c = 0; $i = 0
    while (($i = $text.IndexOf($needle, $i, [StringComparison]::Ordinal)) -ge 0) { $c++; $i += $needle.Length }
    return $c
}

$Explorer = Join-Path $PluginRoot 'agents/explorer.md'
$Advocacy = Join-Path $PluginRoot 'skills/bug-advocacy/SKILL.md'
$ExtPrefix = '${extensionPath}/'

if ((Test-Path -LiteralPath $Explorer -PathType Leaf) -and (Test-Path -LiteralPath $Advocacy -PathType Leaf)) {
    $exLines  = Read-Lines $Explorer
    $advLines = Read-Lines $Advocacy
    $exTrim = New-Object 'System.Collections.Generic.List[string]'
    foreach ($l in $exLines) { $exTrim.Add($l.TrimEnd([char]13)) }

    # P1 - markers: exactly one of each, start before end, each alone on its line.
    $mStart = 0; $mEnd = 0; $lStart = 0; $lEnd = 0; $exact = $true
    for ($i = 0; $i -lt $exTrim.Count; $i++) {
        $line = $exTrim[$i]
        if ($line.Contains('explorer-card:start')) {
            $mStart++; if ($lStart -eq 0) { $lStart = $i + 1 }
            if ($line -cne '<!-- explorer-card:start -->') { $exact = $false }
        }
        if ($line.Contains('explorer-card:end')) {
            $mEnd++; if ($lEnd -eq 0) { $lEnd = $i + 1 }
            if ($line -cne '<!-- explorer-card:end -->') { $exact = $false }
        }
    }
    $cardOk = ($mStart -eq 1 -and $mEnd -eq 1 -and $lStart -lt $lEnd -and $exact)
    if ($cardOk) {
        Pass 'explorer card markers: exactly one start and one end, in order'
    } else {
        Fail 'explorer card markers invalid' "start=$mStart end=$mEnd (need exactly one of each, start before end, each alone on its line)"
    }

    $card = New-Object 'System.Collections.Generic.List[string]'
    if ($cardOk) { for ($i = $lStart - 1; $i -le $lEnd - 1; $i++) { $card.Add($exLines[$i]) } }
    $cardTrim = New-Object 'System.Collections.Generic.List[string]'
    foreach ($l in $card) { $cardTrim.Add($l.TrimEnd([char]13)) }
    $cardText = $cardTrim -join "`n"

    # P2 - position: the card is the first section after the safety boundary.
    $heads = New-Object 'System.Collections.Generic.List[object]'
    for ($i = 0; $i -lt $exTrim.Count -and $heads.Count -lt 3; $i++) {
        if ($exTrim[$i].StartsWith('## ', [StringComparison]::Ordinal)) { $heads.Add(@(($i + 1), $exTrim[$i])) }
    }
    $posOk = $cardOk -and $heads.Count -eq 3
    if ($posOk) {
        $posOk = $heads[0][1].StartsWith('## Safety boundary', [StringComparison]::Ordinal) `
            -and $heads[1][1].StartsWith('## Explorer card', [StringComparison]::Ordinal) `
            -and $heads[1][0] -eq ($lStart + 1) -and $lEnd -lt $heads[2][0]
    }
    if ($posOk) {
        Pass 'explorer card sits right after the safety boundary'
    } else {
        Fail 'explorer card must be the first section after the safety boundary' "need '## Safety boundary', then the start marker, then its '## Explorer card' heading"
    }

    # P3 - byte cap, measured as the marker range | wc -c (markers included).
    $cardBytes = 0
    foreach ($l in $card) { $cardBytes += [Text.Encoding]::UTF8.GetByteCount($l) + 1 }
    if ($cardBytes -ge 1 -and $cardBytes -le 4096) {
        Pass "explorer card is $cardBytes bytes (limit 4096)"
    } else {
        Fail 'explorer card must be 1-4096 bytes' "measured $cardBytes bytes"
    }

    # P4 - severity: the card's value line, order line and ladder bullets each
    # equal bug-advocacy's four-levels table and rank line, in order.
    $table = New-Object 'System.Collections.Generic.List[string]'
    $inTable = $false
    $rank = ''
    foreach ($raw in $advLines) {
        $line = $raw.TrimEnd([char]13)
        if ($line.StartsWith('### The four levels', [StringComparison]::Ordinal)) { $inTable = $true; continue }
        if ($line.StartsWith('### ', [StringComparison]::Ordinal)) { $inTable = $false }
        if ($inTable) {
            $m = [regex]::Match($line, '^\| \*\*([A-Za-z]+)\*\* \|')
            if ($m.Success) { $table.Add($m.Groups[1].Value) }
        }
        if ($rank -eq '') {
            $m = [regex]::Match($line, 'Rank order is \*\*([A-Za-z >]+)\*\*')
            if ($m.Success) { $rank = ($m.Groups[1].Value -split ' > ') -join ' ' }
        }
    }
    $tableStr = $table -join ' '
    $cEnum = ''; $cRank = ''
    $ladder = New-Object 'System.Collections.Generic.List[string]'
    $enumPrefix = '**Severity values (exact):** '
    $rankPrefix = '**Severity order:** '
    $enumSeen = $false; $rankSeen = $false
    foreach ($line in $cardTrim) {
        if (-not $enumSeen -and $line.StartsWith($enumPrefix, [StringComparison]::Ordinal)) {
            $enumSeen = $true
            $cEnum = (Get-Ticked $line '`([A-Za-z]+)`') -join ' '
        }
        if (-not $rankSeen -and $line.StartsWith($rankPrefix, [StringComparison]::Ordinal)) {
            $rankSeen = $true
            $cRank = ($line.Substring($rankPrefix.Length) -split ' > ') -join ' '
        }
        $m = [regex]::Match($line, '^- \*\*([A-Za-z]+)\*\*: ')
        if ($m.Success) { $ladder.Add($m.Groups[1].Value) }
    }
    $cLadder = $ladder -join ' '
    if ($table.Count -eq 4 -and $rank -ceq $tableStr -and $cEnum -ceq $tableStr -and $cRank -ceq $tableStr -and $cLadder -ceq $tableStr) {
        Pass "explorer card severity values, order and ladder match bug-advocacy's four levels"
    } else {
        Fail 'explorer card severity drifted from bug-advocacy' "table='$tableStr' rank='$rank' card values='$cEnum' card order='$cRank' card ladder='$cLadder'"
    }

    # P5 - stop_reason: the card's stop values and the output contract's row
    # must be the same set, in both directions.
    $cStops = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($line in $cardTrim) {
        $m = [regex]::Match($line, '^- `([a-z_]*)`: ')
        if ($m.Success) { [void]$cStops.Add($m.Groups[1].Value) }
    }
    $kStops = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $rowPrefix = '| `stop_reason` |'
    foreach ($line in $exTrim) {
        if ($line.StartsWith($rowPrefix, [StringComparison]::Ordinal)) {
            foreach ($v in (Get-Ticked $line.Substring($rowPrefix.Length) '`([a-z_]+)`')) { [void]$kStops.Add($v) }
        }
    }
    if ($cStops.Count -gt 0 -and $cStops.SetEquals($kStops)) {
        Pass "explorer card stop rules name exactly the output contract's stop_reason values"
    } else {
        $onlyCard = @($cStops | Where-Object { -not $kStops.Contains($_) } | Sort-Object) -join ' '
        $onlyContract = @($kStops | Where-Object { -not $cStops.Contains($_) } | Sort-Object) -join ' '
        Fail 'explorer card stop_reason values differ from the output contract' "in card only: [$onlyCard] in contract only: [$onlyContract]"
    }

    # P6 - RIMGEA mapped onto the bugs[] fields, and the three oracle verdicts.
    $missing = Get-MissingNeedles $cardText @(
        '- Replicate: ',
        '- Isolate, filling `minimal_repro`:',
        '- Maximize, filling `worst_observed`:',
        '- Generalize, filling `generalization`:',
        '- Externalize, filling `stakeholder_impact`:',
        '- And say it clearly:',
        'Three verdicts: Defect; Known-bad-but-expected (',
        '); Acceptable.')
    if ($cardOk -and $missing -eq '') {
        Pass 'explorer card maps RIMGEA onto bugs[] fields and names the oracle verdicts'
    } else {
        if ($missing -eq '') { $missing = ' (no card)' }
        Fail 'explorer card is missing RIMGEA or verdict text' $missing
    }

    # P7 - the tie rule, the three modifiers and their combination rule, the
    # likelihood rule, the unknown-impact rule, and the three kinds of oracle.
    $missing = Get-MissingNeedles $cardText @(
        'If clauses at two levels match, take the higher one, only if you demonstrated it.',
        'Reach (', 'Avoidability (', 'Persistence (',
        'two or more raise the level exactly one step',
        'never produce Critical',
        'Likelihood is not an input',
        'Cannot tell it is wrong: a question, not a bug.',
        'never Critical or High',
        'start `stakeholder_impact` with "Provisional"',
        'Three kinds, in this order: Never/Always invariants',
        '; consistency with ',
        '; approximation by ')
    if ($cardOk -and $missing -eq '') {
        Pass 'explorer card carries the tie, modifier, likelihood and unknown-impact rules and the three oracle kinds'
    } else {
        if ($missing -eq '') { $missing = ' (no card)' }
        Fail 'explorer card is missing severity or oracle rule text' $missing
    }

    # P8 - the explore loop, the bugs[] rows and the budget hard rule point at the card.
    $explorerText = $exTrim -join "`n"
    $missing = Get-MissingNeedles $explorerText @(
        'run it through RIMGEA (the card)',
        "9. **Stop** per the card's stop rules",
        "**Respect the session budget.** Stop per the card's stop rules",
        '| `bugs` | yes | array | Oracle-confirmed problems, each run through **RIMGEA** (the card)',
        '| `severity` | string | Exactly `Critical`, `High`, `Moderate` or `Minor` per the card''s ladder')
    if ($missing -eq '') {
        Pass 'explorer loop, bugs[] rows and budget rule point at the card'
    } else {
        Fail 'agents/explorer.md does not point at the card' $missing
    }

    # P9 - no skill path without the extensionPath prefix in the explorer.
    $bare = ''
    for ($i = 0; $i -lt $exTrim.Count; $i++) {
        $line = $exTrim[$i]
        foreach ($m in [regex]::Matches($line, 'skills/[a-z-]+/SKILL\.md')) {
            if ($m.Index -lt $ExtPrefix.Length -or $line.Substring($m.Index - $ExtPrefix.Length, $ExtPrefix.Length) -cne $ExtPrefix) {
                $bare += " $($i + 1):$($m.Value)"
            }
        }
    }
    if ($bare -eq '') {
        Pass 'agents/explorer.md names every skill path through ${extensionPath}/'
    } else {
        Fail 'agents/explorer.md names a skill path without the ${extensionPath}/ prefix' $bare
    }

    # P10 - Gemini CLI templates agent bodies and refuses an unknown token, so
    # every template opener in an agent must open extensionPath.
    $badTokens = ''
    foreach ($agentFile in (Get-ChildItem -LiteralPath (Join-Path $PluginRoot 'agents') -Filter '*.md' | Sort-Object Name)) {
        $agentLines = Read-Lines $agentFile.FullName
        for ($i = 0; $i -lt $agentLines.Count; $i++) {
            $line = $agentLines[$i].TrimEnd([char]13)
            if ((Get-Count $line '${') -ne (Get-Count $line '${extensionPath}')) {
                $badTokens += " $($agentFile.Name):$($i + 1)"
            }
        }
    }
    if ($badTokens -eq '') {
        Pass 'agents/*.md use no template token other than ${extensionPath}'
    } else {
        Fail 'agents/*.md carry a template token other than ${extensionPath}' $badTokens
    }

    # P11 - each optional skill reference keeps its extensionPath form, and the
    # agent says the card binds when no skill can be read.
    $missingRefs = ''
    foreach ($skill in @('heuristics', 'oracles', 'bug-advocacy', 'session')) {
        $ref = '- **`' + $skill + '`** (`' + $ExtPrefix + 'skills/' + $skill + '/SKILL.md`)'
        $n = 0
        foreach ($line in $exTrim) { if ($line.StartsWith($ref, [StringComparison]::Ordinal)) { $n++ } }
        if ($n -ne 1) { $missingRefs += " [${skill}: $n]" }
    }
    $missingRefs += Get-MissingNeedles $explorerText @('The card binds whether or not a skill was read.')
    if ($missingRefs -eq '') {
        Pass 'explorer references each skill once through ${extensionPath} and says the card binds'
    } else {
        Fail 'explorer skill references or binding sentence wrong' $missingRefs
    }
} else {
    Fail 'explorer card checks need agents/explorer.md and skills/bug-advocacy/SKILL.md'
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
