#!/usr/bin/env bash
# Installer source test for the stride-gemini-exploratory-testing extension.
#
# Runs install.sh four ways and checks where it took the extension from:
#
#   1. piped (bash < install.sh, as curl ... | bash runs it) from a working
#      directory that holds another extension's gemini-extension.json;
#   2. piped from a working directory whose manifest claims this extension's
#      name (a piped run never reads the working directory at all);
#   3. run as a file that sits beside another extension's manifest;
#   4. run as a file from this checkout.
#
# Runs 1-3 must take a fresh clone and install this extension's files; run 4
# must install from this checkout without cloning. Nothing touches the network
# or the real ~/.gemini: every run has HOME pointed at a mktemp -d directory,
# and a stub `git` first on PATH answers `git clone` by copying this checkout
# (and records that it was called). The temp directory is removed at the end.
#
# Exit code: 0 if every check passes; 1 if any check fails.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EXT_NAME="stride-gemini-exploratory-testing"

PASS=0
FAIL=0

ok()   { PASS=$(( PASS + 1 )); printf '  ✓  %s\n' "$1"; }
nope() { FAIL=$(( FAIL + 1 )); printf '  ✗  %s\n     %s\n' "$1" "${2:-}"; }

printf 'stride-gemini-exploratory-testing installer source test\n'
printf 'plugin root: %s\n\n' "$PLUGIN_ROOT"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The stub git: `git clone ... <dest>` copies this checkout's extension files
# to <dest> and appends to $WORK/clone-calls; anything else fails.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/git" <<'STUB'
#!/usr/bin/env bash
[ "${1:-}" = "clone" ] || { echo "stub git: only clone is supported" >&2; exit 2; }
for dest in "$@"; do :; done
mkdir -p "$dest"
for f in gemini-extension.json GEMINI.md LICENSE; do
  [ -f "$STUB_SRC/$f" ] && cp "$STUB_SRC/$f" "$dest/"
done
for d in commands skills agents lib fixtures policies; do
  cp -R "$STUB_SRC/$d" "$dest/"
done
echo "clone" >> "$STUB_LOG"
STUB
chmod +x "$WORK/bin/git"

# A foreign extension checkout and an impostor that claims this name.
make_checkout() {
  mkdir -p "$1/commands"
  printf '{\n  "name": "%s",\n  "version": "9.9.9",\n  "contextFileName": "GEMINI.md"\n}\n' "$2" > "$1/gemini-extension.json"
  printf 'FOREIGN CONTEXT FILE\n' > "$1/GEMINI.md"
  printf 'description = "foreign"\nprompt = "foreign"\n' > "$1/commands/foreign-only.toml"
}
make_checkout "$WORK/foreign" "some-other-extension"
make_checkout "$WORK/impostor" "$EXT_NAME"
cp "$PLUGIN_ROOT/install.sh" "$WORK/foreign/install.sh"

# run_case <label> <home> <cwd> <mode: piped|file> <script>
run_case() {
  local label="$1" home="$2" cwd="$3" mode="$4" script="$5" out
  mkdir -p "$home"
  : > "$WORK/clone-calls"
  if [ "$mode" = "piped" ]; then
    out="$(cd "$cwd" && HOME="$home" PATH="$WORK/bin:$PATH" STUB_SRC="$PLUGIN_ROOT" STUB_LOG="$WORK/clone-calls" bash < "$script" 2>&1)"
  else
    out="$(cd "$cwd" && HOME="$home" PATH="$WORK/bin:$PATH" STUB_SRC="$PLUGIN_ROOT" STUB_LOG="$WORK/clone-calls" bash "$script" 2>&1)"
  fi
  RUN_STATUS=$?
  RUN_OUT="$out"
  RUN_DEST="$home/.gemini/extensions/$EXT_NAME"
  RUN_CLONES="$(wc -l < "$WORK/clone-calls" | tr -d ' ')"
}

# installed_problems — print a problem for each way the install at RUN_DEST is
# not this extension's own files.
installed_problems() {
  [ "$RUN_STATUS" -eq 0 ] || printf ' [exit %s: %s]' "$RUN_STATUS" "$(printf '%s' "$RUN_OUT" | tail -n 1)"
  cmp -s "$RUN_DEST/gemini-extension.json" "$PLUGIN_ROOT/gemini-extension.json" || printf ' [installed manifest is not this extension'"'"'s]'
  cmp -s "$RUN_DEST/GEMINI.md" "$PLUGIN_ROOT/GEMINI.md" || printf ' [installed GEMINI.md is not this extension'"'"'s]'
  [ -f "$RUN_DEST/commands/explore.toml" ] || printf ' [commands/explore.toml not installed]'
  [ -e "$RUN_DEST/commands/foreign-only.toml" ] && printf ' [a foreign command was installed]'
  return 0
}

check_case() {
  local label="$1" want_clones="$2" problems
  problems="$(installed_problems)"
  [ "$RUN_CLONES" = "$want_clones" ] || problems="$problems [git clone called $RUN_CLONES time(s), want $want_clones]"
  if [ -z "$problems" ]; then ok "$label"; else nope "$label" "$problems"; fi
}

if [ -f "$PLUGIN_ROOT/install.sh" ] && [ -f "$PLUGIN_ROOT/gemini-extension.json" ]; then
  run_case piped "$WORK/home1" "$WORK/foreign" piped "$PLUGIN_ROOT/install.sh"
  check_case "piped install.sh run from another extension's checkout clones and installs this extension, not the working directory's" 1

  run_case piped "$WORK/home2" "$WORK/impostor" piped "$PLUGIN_ROOT/install.sh"
  check_case "piped install.sh ignores a working directory whose manifest claims this extension's name" 1

  run_case file "$WORK/home3" "$WORK" file "$WORK/foreign/install.sh"
  check_case "install.sh run as a file beside another extension's manifest clones instead of installing it" 1

  run_case file "$WORK/home4" "$WORK/foreign" file "$PLUGIN_ROOT/install.sh"
  check_case "install.sh run as a file from this checkout installs it without cloning, whatever the working directory" 0

  # The guard on the clone: a download that is not this extension installs nothing.
  sed 's/"name": "stride-gemini-exploratory-testing"/"name": "some-other-extension"/' "$PLUGIN_ROOT/gemini-extension.json" > "$WORK/other-manifest.json"
  mkdir -p "$WORK/other-src"
  cp -R "$PLUGIN_ROOT/commands" "$PLUGIN_ROOT/skills" "$PLUGIN_ROOT/agents" "$PLUGIN_ROOT/lib" "$PLUGIN_ROOT/fixtures" "$PLUGIN_ROOT/policies" "$PLUGIN_ROOT/GEMINI.md" "$WORK/other-src/"
  cp "$WORK/other-manifest.json" "$WORK/other-src/gemini-extension.json"
  mkdir -p "$WORK/home5"
  : > "$WORK/clone-calls"
  RUN_OUT="$(cd "$WORK/foreign" && HOME="$WORK/home5" PATH="$WORK/bin:$PATH" STUB_SRC="$WORK/other-src" STUB_LOG="$WORK/clone-calls" bash < "$PLUGIN_ROOT/install.sh" 2>&1)"
  RUN_STATUS=$?
  if [ "$RUN_STATUS" -ne 0 ] && [ ! -e "$WORK/home5/.gemini/extensions/$EXT_NAME/gemini-extension.json" ]; then
    ok "a downloaded copy whose manifest names another extension stops the install with nothing installed"
  else
    nope "a downloaded copy whose manifest names another extension stops the install with nothing installed" "exit $RUN_STATUS"
  fi
else
  nope "installer source checks need install.sh and gemini-extension.json" ""
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
