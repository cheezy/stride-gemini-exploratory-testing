#!/usr/bin/env bash
# Structure smoke test for the stride-gemini-exploratory-testing extension.
#
# Confirms the extension's required files and directories exist and that the
# gemini-extension.json manifest is valid JSON carrying name/version/
# contextFileName. It also pins the explorer card in agents/explorer.md: its
# markers and position after the safety boundary, a 4,096-byte cap, its
# severity values, order and ladder against bug-advocacy's four levels, its
# stop rules against the output contract's stop_reason values, the RIMGEA,
# oracle and edge-rule text, the pointers to the card, and the skill references'
# ${extensionPath} form (no other template token in agents/*.md).
#
# Offline and read-only — it never executes or evaluates any extension file; it
# checks existence, parses the manifest as data, and reads agents/*.md and
# skills/bug-advocacy/SKILL.md as text with awk, sed, tr, sort, comm, head and wc.
#
# The manifest is gemini-extension.json at the ROOT (Gemini CLI convention).
# This test deliberately does NOT look for a .claude-plugin/plugin.json or a
# package.json — the Gemini extension has neither.
#
# Exit code: 0 if every check passes; 1 if any check fails.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PASS=0
FAIL=0

ok()   { PASS=$(( PASS + 1 )); printf '  ✓  %s\n' "$1"; }
nope() { FAIL=$(( FAIL + 1 )); printf '  ✗  %s\n     %s\n' "$1" "${2:-}"; }

# exists <relative-path> <label>
exists() {
  if [ -e "${PLUGIN_ROOT}/$1" ]; then
    ok "$2 exists ($1)"
  else
    nope "$2 missing" "$1"
  fi
}

printf 'stride-gemini-exploratory-testing structure test\n'
printf 'plugin root: %s\n\n' "$PLUGIN_ROOT"

# --- Manifest ---------------------------------------------------------------

printf 'Manifest\n'
MANIFEST="${PLUGIN_ROOT}/gemini-extension.json"
if [ ! -f "$MANIFEST" ]; then
  nope "gemini-extension.json missing at the root" "$MANIFEST"
else
  if MANIFEST_ERR="$(python3 - "$MANIFEST" <<'PY' 2>&1
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception as e:  # noqa: BLE001 - report any parse error as a failure
    print(f"invalid JSON: {e}")
    sys.exit(1)
missing = [k for k in ("name", "version", "contextFileName") if k not in data]
if missing:
    print("missing keys: " + ", ".join(missing))
    sys.exit(1)
PY
  )"; then
    ok "gemini-extension.json is valid JSON with name/version/contextFileName"
  else
    nope "gemini-extension.json invalid" "$MANIFEST_ERR"
  fi
fi

# Guard: the Gemini extension must NOT rely on Claude Code / npm manifests.
if [ -f "${PLUGIN_ROOT}/.claude-plugin/plugin.json" ]; then
  nope "unexpected .claude-plugin/plugin.json present" "the Gemini extension is declared by gemini-extension.json only"
else
  ok "no .claude-plugin/plugin.json (correct for a Gemini extension)"
fi
if [ -f "${PLUGIN_ROOT}/package.json" ]; then
  nope "unexpected package.json present" "the Gemini extension does not use npm"
else
  ok "no package.json (correct for a Gemini extension)"
fi

# --- Skills -----------------------------------------------------------------

printf '\nSkills\n'
for skill in stride-exploratory-testing chartering heuristics oracles bug-advocacy session; do
  exists "skills/${skill}/SKILL.md" "skill '${skill}' SKILL.md"
done

# --- Commands ---------------------------------------------------------------

printf '\nCommands\n'
for cmd in charter nightmare-headline explore recon debrief pair harden; do
  exists "commands/${cmd}.toml" "command /${cmd}"
done

# --- Agents -----------------------------------------------------------------

printf '\nAgents\n'
for agent in charter-generator explorer; do
  exists "agents/${agent}.md" "agent '${agent}'"
done

# --- Explorer card ----------------------------------------------------------
#
# Every rule the explorer needs to rate a bug and end a session lives on an
# inline card, because the extension's skills sit outside the workspace that
# read_file resolves against and may never load. These pins keep the card in
# place right after the safety boundary, under its 4,096-byte cap, in step with
# bug-advocacy's four levels and with the output contract's stop_reason values,
# and keep the skill references in their ${extensionPath} form. Comparisons are
# byte-wise and case-sensitive (LC_ALL=C), matching test-structure.ps1, and
# every message below is identical in both shells.

printf '\nExplorer card\n'

EXPLORER="${PLUGIN_ROOT}/agents/explorer.md"
ADVOCACY="${PLUGIN_ROOT}/skills/bug-advocacy/SKILL.md"
EXT_PREFIX='${extensionPath}/'

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

if [ -f "$EXPLORER" ] && [ -f "$ADVOCACY" ]; then
  # P1 — markers: exactly one of each, start before end, each alone on its line.
  MARKERS="$(LC_ALL=C tr -d '\r' < "$EXPLORER" | LC_ALL=C awk '
    /explorer-card:start/ { s++; if (!ls) ls = NR; if ($0 != "<!-- explorer-card:start -->") bad = 1 }
    /explorer-card:end/   { e++; if (!le) le = NR; if ($0 != "<!-- explorer-card:end -->") bad = 1 }
    END { printf "%d %d %d %d %d", s, e, ls, le, bad }')"
  read -r M_START M_END L_START L_END M_BAD <<EOF
$MARKERS
EOF
  CARD_OK=0
  if [ "$M_START" -eq 1 ] && [ "$M_END" -eq 1 ] && [ "$L_START" -lt "$L_END" ] && [ "$M_BAD" -eq 0 ]; then
    CARD_OK=1
    ok "explorer card markers: exactly one start and one end, in order"
  else
    nope "explorer card markers invalid" "start=${M_START} end=${M_END} (need exactly one of each, start before end, each alone on its line)"
  fi

  CARD=""
  CARD_BYTES=0
  if [ "$CARD_OK" -eq 1 ]; then
    CARD="$(LC_ALL=C tr -d '\r' < "$EXPLORER" | LC_ALL=C sed -n "${L_START},${L_END}p")"
    CARD_BYTES=$(LC_ALL=C sed -n "${L_START},${L_END}p" "$EXPLORER" | wc -c | tr -d ' ')
  fi

  # P2 — position: the card is the first section after the safety boundary.
  HEADS="$(LC_ALL=C tr -d '\r' < "$EXPLORER" | LC_ALL=C awk '
    /^## / { n++; if (n <= 3) { ln[n] = NR; t[n] = $0 } }
    END {
      a = (index(t[1], "## Safety boundary") == 1) ? 1 : 0
      b = (index(t[2], "## Explorer card") == 1) ? 1 : 0
      printf "%d %d %d %d", a, b, ln[2] + 0, ln[3] + 0
    }')"
  read -r H_SAFETY H_CARD H2_LINE H3_LINE <<EOF
$HEADS
EOF
  if [ "$CARD_OK" -eq 1 ] && [ "$H_SAFETY" -eq 1 ] && [ "$H_CARD" -eq 1 ] \
     && [ "$H2_LINE" -eq $(( L_START + 1 )) ] && [ "$L_END" -lt "$H3_LINE" ]; then
    ok "explorer card sits right after the safety boundary"
  else
    nope "explorer card must be the first section after the safety boundary" "need '## Safety boundary', then the start marker, then its '## Explorer card' heading"
  fi

  # P3 — byte cap, measured as the marker range | wc -c (markers included).
  if [ "$CARD_BYTES" -ge 1 ] && [ "$CARD_BYTES" -le 4096 ]; then
    ok "explorer card is ${CARD_BYTES} bytes (limit 4096)"
  else
    nope "explorer card must be 1-4096 bytes" "measured ${CARD_BYTES} bytes"
  fi

  # P4 — severity: the card's value line, order line and ladder bullets each
  # equal bug-advocacy's four-levels table and rank line, in order.
  ADV="$(LC_ALL=C tr -d '\r' < "$ADVOCACY")"
  TABLE="$(printf '%s\n' "$ADV" | LC_ALL=C awk '
    /^### The four levels/ { f = 1; next }
    /^### / { f = 0 }
    f && match($0, /^\| \*\*[A-Za-z]+\*\* \|/) { w = substr($0, 5, RLENGTH - 8); out = out (out ? " " : "") w }
    END { print out }')"
  RANK="$(printf '%s\n' "$ADV" | LC_ALL=C sed -n 's/.*Rank order is \*\*\([A-Za-z >]*\)\*\*.*/\1/p' | head -n 1 | sed 's/ > / /g')"
  C_ENUM="$(printf '%s\n' "$CARD" | LC_ALL=C awk '
    index($0, "**Severity values (exact):** ") == 1 && !done {
      done = 1; s = $0
      while (match(s, /`[A-Za-z]+`/)) { w = substr(s, RSTART + 1, RLENGTH - 2); out = out (out ? " " : "") w; s = substr(s, RSTART + RLENGTH) }
    }
    END { print out }')"
  C_RANK="$(printf '%s\n' "$CARD" | LC_ALL=C awk '
    index($0, "**Severity order:** ") == 1 && !done { done = 1; s = substr($0, 21); gsub(/ > /, " ", s); print s }')"
  C_LADDER="$(printf '%s\n' "$CARD" | LC_ALL=C awk '
    match($0, /^- \*\*[A-Za-z]+\*\*: /) { w = substr($0, 5, RLENGTH - 8); out = out (out ? " " : "") w }
    END { print out }')"
  TABLE_COUNT=$(printf '%s\n' "$TABLE" | awk '{ print NF }')
  if [ "$TABLE_COUNT" -eq 4 ] && [ "$RANK" = "$TABLE" ] && [ "$C_ENUM" = "$TABLE" ] \
     && [ "$C_RANK" = "$TABLE" ] && [ "$C_LADDER" = "$TABLE" ]; then
    ok "explorer card severity values, order and ladder match bug-advocacy's four levels"
  else
    nope "explorer card severity drifted from bug-advocacy" "table='${TABLE}' rank='${RANK}' card values='${C_ENUM}' card order='${C_RANK}' card ladder='${C_LADDER}'"
  fi

  # P5 — stop_reason: the card's stop values and the output contract's row
  # must be the same set, in both directions.
  C_STOPS="$(printf '%s\n' "$CARD" | LC_ALL=C sed -n 's/^- `\([a-z_]*\)`: .*/\1/p' | LC_ALL=C sort -u)"
  K_STOPS="$(LC_ALL=C tr -d '\r' < "$EXPLORER" | LC_ALL=C awk '
    index($0, "| `stop_reason` |") == 1 {
      s = substr($0, 18)
      while (match(s, /`[a-z_]+`/)) { print substr(s, RSTART + 1, RLENGTH - 2); s = substr(s, RSTART + RLENGTH) }
    }' | LC_ALL=C sort -u)"
  if [ -n "$C_STOPS" ] && [ "$C_STOPS" = "$K_STOPS" ]; then
    ok "explorer card stop rules name exactly the output contract's stop_reason values"
  else
    ONLY_CARD="$(LC_ALL=C comm -23 <(printf '%s\n' "$C_STOPS") <(printf '%s\n' "$K_STOPS") | tr '\n' ' ')"
    ONLY_CONTRACT="$(LC_ALL=C comm -13 <(printf '%s\n' "$C_STOPS") <(printf '%s\n' "$K_STOPS") | tr '\n' ' ')"
    nope "explorer card stop_reason values differ from the output contract" "in card only: [${ONLY_CARD% }] in contract only: [${ONLY_CONTRACT% }]"
  fi

  # P6 — RIMGEA mapped onto the bugs[] fields, and the three oracle verdicts.
  MISSING="$(missing_needles "$CARD" \
    '- Replicate: ' \
    '- Isolate, filling `minimal_repro`:' \
    '- Maximize, filling `worst_observed`:' \
    '- Generalize, filling `generalization`:' \
    '- Externalize, filling `stakeholder_impact`:' \
    '- And say it clearly:' \
    'Three verdicts: Defect; Known-bad-but-expected (' \
    '); Acceptable.')"
  if [ "$CARD_OK" -eq 1 ] && [ -z "$MISSING" ]; then
    ok "explorer card maps RIMGEA onto bugs[] fields and names the oracle verdicts"
  else
    nope "explorer card is missing RIMGEA or verdict text" "${MISSING:- (no card)}"
  fi

  # P7 — the tie rule, the three modifiers and their combination rule, the
  # likelihood rule, the unknown-impact rule, and the three kinds of oracle.
  MISSING="$(missing_needles "$CARD" \
    'If clauses at two levels match, take the higher one, only if you demonstrated it.' \
    'Reach (' 'Avoidability (' 'Persistence (' \
    'two or more raise the level exactly one step' \
    'never produce Critical' \
    'Likelihood is not an input' \
    'Cannot tell it is wrong: a question, not a bug.' \
    'never Critical or High' \
    'start `stakeholder_impact` with "Provisional"' \
    'Three kinds, in this order: Never/Always invariants' \
    '; consistency with ' \
    '; approximation by ')"
  if [ "$CARD_OK" -eq 1 ] && [ -z "$MISSING" ]; then
    ok "explorer card carries the tie, modifier, likelihood and unknown-impact rules and the three oracle kinds"
  else
    nope "explorer card is missing severity or oracle rule text" "${MISSING:- (no card)}"
  fi

  # P8 — the explore loop, the bugs[] rows and the budget hard rule point at the card.
  EXPLORER_TEXT="$(LC_ALL=C tr -d '\r' < "$EXPLORER")"
  MISSING="$(missing_needles "$EXPLORER_TEXT" \
    'run it through RIMGEA (the card)' \
    "9. **Stop** per the card's stop rules" \
    "**Respect the session budget.** Stop per the card's stop rules" \
    '| `bugs` | yes | array | Oracle-confirmed problems, each run through **RIMGEA** (the card)' \
    "| \`severity\` | string | Exactly \`Critical\`, \`High\`, \`Moderate\` or \`Minor\` per the card's ladder")"
  if [ -z "$MISSING" ]; then
    ok "explorer loop, bugs[] rows and budget rule point at the card"
  else
    nope "agents/explorer.md does not point at the card" "$MISSING"
  fi

  # P9 — no skill path without the ${extensionPath}/ prefix in the explorer.
  BARE="$(LC_ALL=C tr -d '\r' < "$EXPLORER" | LC_ALL=C awk -v pre="$EXT_PREFIX" '
    {
      s = $0; off = 0
      while (match(s, /skills\/[a-z-]+\/SKILL\.md/)) {
        p = off + RSTART
        if (p <= length(pre) || substr($0, p - length(pre), length(pre)) != pre) {
          printf " %d:%s", NR, substr(s, RSTART, RLENGTH)
        }
        off += RSTART + RLENGTH - 1; s = substr(s, RSTART + RLENGTH)
      }
    }')"
  if [ -z "$BARE" ]; then
    ok "agents/explorer.md names every skill path through \${extensionPath}/"
  else
    nope "agents/explorer.md names a skill path without the \${extensionPath}/ prefix" "$BARE"
  fi

  # P10 — Gemini CLI templates agent bodies and refuses an unknown token, so
  # every "${" in an agent must open ${extensionPath}.
  BAD_TOKENS=""
  for agent_file in "${PLUGIN_ROOT}"/agents/*.md; do
    BAD_TOKENS="${BAD_TOKENS}$(LC_ALL=C tr -d '\r' < "$agent_file" | LC_ALL=C awk -v f="${agent_file##*/}" '
      function count(s, n,   c, i) { c = 0; while ((i = index(s, n)) > 0) { c++; s = substr(s, i + length(n)) } return c }
      {
        if (count($0, "${") != count($0, "${extensionPath}")) printf " %s:%d", f, NR
      }')"
  done
  if [ -z "$BAD_TOKENS" ]; then
    ok "agents/*.md use no template token other than \${extensionPath}"
  else
    nope "agents/*.md carry a template token other than \${extensionPath}" "$BAD_TOKENS"
  fi

  # P11 — each optional skill reference keeps its ${extensionPath} form, and the
  # agent says the card binds when no skill can be read.
  MISSING_REFS=""
  for skill in heuristics oracles bug-advocacy session; do
    ref='- **`'"$skill"'`** (`'"$EXT_PREFIX"'skills/'"$skill"'/SKILL.md`)'
    n=$(printf '%s\n' "$EXPLORER_TEXT" | LC_ALL=C awk -v r="$ref" 'index($0, r) == 1 { c++ } END { print c + 0 }')
    if [ "$n" -ne 1 ]; then
      MISSING_REFS="${MISSING_REFS} [${skill}: ${n}]"
    fi
  done
  MISSING_REFS="${MISSING_REFS}$(missing_needles "$EXPLORER_TEXT" 'The card binds whether or not a skill was read.')"
  if [ -z "$MISSING_REFS" ]; then
    ok "explorer references each skill once through \${extensionPath} and says the card binds"
  else
    nope "explorer skill references or binding sentence wrong" "$MISSING_REFS"
  fi
else
  nope "explorer card checks need agents/explorer.md and skills/bug-advocacy/SKILL.md" ""
fi

# --- Root docs & license ----------------------------------------------------

printf '\nRoot docs\n'
for doc in GEMINI.md README.md HEURISTICS.md CHANGELOG.md LICENSE; do
  exists "$doc" "$doc"
done

# --- Fixtures ---------------------------------------------------------------

printf '\nFixtures\n'
for fx in example-charters.md example-session-sheet.md example-debrief.md; do
  exists "fixtures/${fx}" "fixture ${fx}"
done

# --- Summary ----------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
