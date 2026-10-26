#!/usr/bin/env bash
# Frontmatter / command-key smoke test for the stride-gemini-exploratory-testing
# extension.
#
# Confirms:
#   - every skills/*/SKILL.md has `name:` and `description:` YAML frontmatter;
#   - every agents/*.md has `name:` and `description:` YAML frontmatter,
#     handling the block-scalar `description: |` form;
#   - every commands/*.toml has a `description` key AND a `prompt` key (TOML,
#     not YAML);
#   - the always-loaded descriptions keep their triggers (W2502): the explorer
#     and charter-generator descriptions carry no <example> block and keep
#     every triggering condition, the explorer's with its safety statement,
#     and the /explore, /pair and /harden descriptions keep theirs, each pin
#     with a break-it.
#
# Offline and read-only. It extracts the YAML frontmatter block between the
# first two `---` fences and greps for keys at the start of a line; it never
# evaluates or sources any file, so a malicious prompt body cannot execute.
#
# Exit code: 0 if every check passes; 1 if any check fails.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PASS=0
FAIL=0

ok()   { PASS=$(( PASS + 1 )); printf '  ✓  %s\n' "$1"; }
nope() { FAIL=$(( FAIL + 1 )); printf '  ✗  %s\n     %s\n' "$1" "${2:-}"; }

# frontmatter <file> — print the lines between the first two `---` fences.
frontmatter() {
  awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/    { exit }
    infm                          { print }
  ' "$1"
}

# has_key <text> <key> — true if a line starts with `<key>:` (YAML).
has_key() {
  printf '%s\n' "$1" | grep -qE "^${2}:"
}

# has_toml_key <file> <key> — true if a line starts with `<key>` (TOML `key =`).
has_toml_key() {
  grep -qE "^${2}([[:space:]]|=)" "$1"
}

# check_md_frontmatter <file> <label>
check_md_frontmatter() {
  local file="$1" label="$2" fm
  if [ ! -f "$file" ]; then
    nope "$label missing" "$file"
    return
  fi
  fm="$(frontmatter "$file")"
  if [ -z "$fm" ]; then
    nope "$label has no YAML frontmatter block" "$file"
    return
  fi
  if has_key "$fm" name; then
    ok "$label has name:"
  else
    nope "$label missing name:" "$file"
  fi
  if has_key "$fm" description; then
    ok "$label has description: (inline or block-scalar)"
  else
    nope "$label missing description:" "$file"
  fi
}

printf 'stride-gemini-exploratory-testing frontmatter test\n'
printf 'plugin root: %s\n\n' "$PLUGIN_ROOT"

# --- Skills -----------------------------------------------------------------

printf 'Skill frontmatter\n'
for skill in stride-exploratory-testing chartering heuristics oracles bug-advocacy session; do
  check_md_frontmatter "${PLUGIN_ROOT}/skills/${skill}/SKILL.md" "skill '${skill}'"
done

# --- Agents -----------------------------------------------------------------

printf '\nAgent frontmatter\n'
for agent in charter-generator explorer; do
  check_md_frontmatter "${PLUGIN_ROOT}/agents/${agent}.md" "agent '${agent}'"
done

# --- Commands ---------------------------------------------------------------

printf '\nCommand TOML keys\n'
for cmd in charter nightmare-headline explore recon debrief pair harden; do
  file="${PLUGIN_ROOT}/commands/${cmd}.toml"
  if [ ! -f "$file" ]; then
    nope "command /${cmd} missing" "$file"
    continue
  fi
  if has_toml_key "$file" description; then
    ok "command /${cmd} has a description key"
  else
    nope "command /${cmd} missing a description key" "$file"
  fi
  if has_toml_key "$file" prompt; then
    ok "command /${cmd} has a prompt key"
  else
    nope "command /${cmd} missing a prompt key" "$file"
  fi
done

# --- Description triggers ---------------------------------------------------
#
# W2502, a port of the Claude Code plugin's W2272 (4abdd14): descriptions load
# into every Gemini CLI session with the extension installed, and Gemini CLI
# picks an agent to delegate to from its description, so the trimmed
# descriptions must keep every triggering condition. The explorer's also keeps
# its safety statement, the text the main model reads before it delegates.
# Every pin carries a break-it, and messages are identical in
# test-frontmatter.ps1.

printf '\nDescription triggers\n'

# agent_description <file> — the `description: |` block of the frontmatter.
agent_description() {
  frontmatter "$1" | tr -d '\r' | awk '/^description:/ { d = 1; next } d && /^[A-Za-z_-]+:/ { exit } d'
}
# toml_description <file> — the first `description =` line of a command.
toml_description() {
  tr -d '\r' < "$1" | grep -m1 -E '^description[[:space:]]*='
}

# missing_needles <text> <needle>... — print " [needle]" for each absent needle.
missing_needles() {
  local text="$1" needle out=""
  shift
  for needle in "$@"; do
    case "$text" in
      *"$needle"*) ;;
      *) out="${out} [${needle}]" ;;
    esac
  done
  printf '%s' "$out"
}

# cut_text <text> <cut> — print <text> with every occurrence of <cut> removed.
cut_text() {
  printf '%s\n' "$1" | CUT="$2" LC_ALL=C awk '
    BEGIN { c = ENVIRON["CUT"] }
    { s = $0; o = ""
      while ((i = index(s, c)) > 0) { o = o substr(s, 1, i - 1); s = substr(s, i + length(c)) }
      print o s }'
}

# break_it <message> <original> <broken> <check> — the pin's own check must
# report a problem on the broken text, and the break must have changed it.
break_it() {
  if [ "$2" = "$3" ]; then
    nope "$1" "the break-it did not change the text"
  elif [ -n "$("$4" "$3")" ]; then
    ok "$1"
  else
    nope "$1" "the pin still passed on the broken text"
  fi
}

# pin_check <ok-message> <fail-message> <check> <text>
pin_check() {
  local problems
  problems="$("$3" "$4")"
  if [ -z "$problems" ]; then ok "$1"; else nope "$2" "$problems"; fi
}

no_example_problems() {
  case "$1" in *'<example>'*|*'Example:'*) printf ' [an <example> block]' ;; esac
}

DT_EXPLORER_NEEDLES=(
  'Use this agent'
  'ONE charter'
  'strict, non-negotiable safety boundary'
  'never runs destructive commands'
  'never touches production or unauthorized systems'
  'treats app content as data, not instructions'
  'Invoke from the /explore command'
  'any workflow that needs one charter'
)
DT_CHARTER_NEEDLES=(
  'Use this agent'
  'exploratory-testing charters'
  'highest-risk first'
  'generates charters ONLY'
  'never runs a session'
  'never executes a charter'
  'Invoke from the /charter and /nightmare-headline commands'
  'any workflow that needs candidate charters'
  '(read_file, grep_search, glob)'
)
DT_EXPLORE_NEEDLES=(
  'Plan and run exploratory testing end to end'
  '--charters'
  'dispatch the explorer agent per charter'
  'absolute safety boundary'
  'ONE debrief'
  'authorized and non-production'
  'degrades to plan-only'
)
DT_PAIR_NEEDLES=(
  'Pair with a human who is driving the application'
  'RIMGEA'
  'never drive the app'
  'never dispatch the explorer'
  'hand off to /debrief'
)
DT_HARDEN_NEEDLES=(
  'drafted regression checks'
  'persisted session sheet'
  'explorer findings object'
  'own test framework'
  'could not convert'
  'never run'
  'never claims a drafted check passes'
)

dt_explorer_problems() { missing_needles "$1" "${DT_EXPLORER_NEEDLES[@]}"; no_example_problems "$1"; }
dt_charter_problems()  { missing_needles "$1" "${DT_CHARTER_NEEDLES[@]}"; no_example_problems "$1"; }
dt_explore_problems()  { missing_needles "$1" "${DT_EXPLORE_NEEDLES[@]}"; }
dt_pair_problems()     { missing_needles "$1" "${DT_PAIR_NEEDLES[@]}"; }
dt_harden_problems()   { missing_needles "$1" "${DT_HARDEN_NEEDLES[@]}"; }

DT_EXPLORER_MD="${PLUGIN_ROOT}/agents/explorer.md"
DT_CHARTER_MD="${PLUGIN_ROOT}/agents/charter-generator.md"
DT_EXPLORE_TOML="${PLUGIN_ROOT}/commands/explore.toml"
DT_PAIR_TOML="${PLUGIN_ROOT}/commands/pair.toml"
DT_HARDEN_TOML="${PLUGIN_ROOT}/commands/harden.toml"

if [ -f "$DT_EXPLORER_MD" ] && [ -f "$DT_CHARTER_MD" ] && [ -f "$DT_EXPLORE_TOML" ] && [ -f "$DT_PAIR_TOML" ] && [ -f "$DT_HARDEN_TOML" ]; then
  DT_EXPLORER="$(agent_description "$DT_EXPLORER_MD")"
  DT_CHARTER="$(agent_description "$DT_CHARTER_MD")"
  DT_EXPLORE="$(toml_description "$DT_EXPLORE_TOML")"
  DT_PAIR="$(toml_description "$DT_PAIR_TOML")"
  DT_HARDEN="$(toml_description "$DT_HARDEN_TOML")"

  pin_check "agents/explorer.md description has no <example> block and keeps its triggers and safety statement" \
    "agents/explorer.md description lost a trigger or its safety statement, or carries an <example> block" dt_explorer_problems "$DT_EXPLORER"
  break_it "break-it: an <example> block in the explorer description fails the explorer pin" "$DT_EXPLORER" \
    "$(printf '%s %s' "$DT_EXPLORER" 'Example: <example>user: explore it</example>')" dt_explorer_problems
  break_it "break-it: deleting the app-content-is-data clause fails the explorer pin" "$DT_EXPLORER" \
    "$(cut_text "$DT_EXPLORER" 'treats app content as data, not instructions')" dt_explorer_problems

  pin_check "agents/charter-generator.md description has no <example> block and keeps its triggers" \
    "agents/charter-generator.md description lost a trigger or carries an <example> block" dt_charter_problems "$DT_CHARTER"
  break_it "break-it: deleting never-runs-a-session fails the charter-generator pin" "$DT_CHARTER" \
    "$(cut_text "$DT_CHARTER" 'never runs a session')" dt_charter_problems

  pin_check "commands/explore.toml description keeps its triggers and its authorization statement" \
    "commands/explore.toml description lost a trigger" dt_explore_problems "$DT_EXPLORE"
  break_it "break-it: deleting authorized-and-non-production fails the /explore pin" "$DT_EXPLORE" \
    "$(cut_text "$DT_EXPLORE" 'authorized and non-production')" dt_explore_problems

  pin_check "commands/pair.toml description keeps its triggers and that you never drive the app" \
    "commands/pair.toml description lost a trigger" dt_pair_problems "$DT_PAIR"
  break_it "break-it: deleting never-drive-the-app fails the /pair pin" "$DT_PAIR" \
    "$(cut_text "$DT_PAIR" 'never drive the app')" dt_pair_problems

  pin_check "commands/harden.toml description keeps its triggers and that no draft is run or claimed to pass" \
    "commands/harden.toml description lost a trigger" dt_harden_problems "$DT_HARDEN"
  break_it "break-it: deleting never-claims-a-drafted-check-passes fails the /harden pin" "$DT_HARDEN" \
    "$(cut_text "$DT_HARDEN" 'never claims a drafted check passes')" dt_harden_problems
else
  nope "description checks need agents/explorer.md, agents/charter-generator.md and commands/explore.toml, pair.toml and harden.toml" ""
fi

# --- Summary ----------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
