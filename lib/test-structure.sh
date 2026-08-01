#!/usr/bin/env bash
# Structure smoke test for the stride-gemini-exploratory-testing extension.
#
# Confirms the extension's required files and directories exist and that the
# gemini-extension.json manifest is valid JSON carrying name/version/
# contextFileName. Offline and read-only — it never executes or evaluates any
# extension file; it only checks for existence and parses the manifest as data.
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
