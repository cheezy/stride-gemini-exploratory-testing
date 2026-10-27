#!/usr/bin/env bash
# install.sh — Install the Stride exploratory-testing extension for Gemini CLI
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/cheezy/stride-gemini-exploratory-testing/main/install.sh | bash
#
# Or clone and run locally:
#   ./install.sh            # global:  ~/.gemini/extensions/stride-gemini-exploratory-testing/
#   ./install.sh --project  # project: .gemini/extensions/stride-gemini-exploratory-testing/
#
# Prefer `gemini extensions install https://github.com/cheezy/stride-gemini-exploratory-testing`
# when available — this script is the manual fallback.

set -euo pipefail

REPO="https://github.com/cheezy/stride-gemini-exploratory-testing.git"
EXT_NAME="stride-gemini-exploratory-testing"
MODE="global"

for arg in "$@"; do
  case "$arg" in
    --project) MODE="project" ;;
    --help|-h)
      echo "Usage: install.sh [--project]"
      echo ""
      echo "Prefer: gemini extensions install https://github.com/cheezy/$EXT_NAME"
      echo "        (this script is the manual fallback)"
      echo ""
      echo "  (default)   Install globally to ~/.gemini/extensions/$EXT_NAME/"
      echo "  --project   Install to .gemini/extensions/$EXT_NAME/ in the current directory"
      exit 0
      ;;
  esac
done

if [ "$MODE" = "project" ]; then
  INSTALL_DIR=".gemini/extensions/$EXT_NAME"
  echo "Installing $EXT_NAME into .gemini/extensions/ (project-local)..."
else
  INSTALL_DIR="$HOME/.gemini/extensions/$EXT_NAME"
  echo "Installing $EXT_NAME into ~/.gemini/extensions/ (global)..."
fi

# manifest_name <gemini-extension.json> — print the manifest's "name" value,
# or nothing when the file has no "name" line of the usual one-key-per-line form.
manifest_name() {
  sed -n 's/^[[:space:]]*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" | sed -n '1p'
}

# Determine the source. It is this script's own checkout only when the script
# runs from a file whose directory holds a manifest named $EXT_NAME. Piped into
# bash (curl ... | bash) there is no script file: BASH_SOURCE is empty, and
# taking its dirname would land on the caller's working directory, which can be
# any other extension's checkout. So a piped run, or a script beside some other
# manifest, never trusts that directory: it clones a fresh copy instead and
# checks the clone's manifest name too. The working directory is never a source.
SRC=""
CLEANUP=""
trap '[ -n "${CLEANUP:-}" ] && rm -rf "$CLEANUP"' EXIT
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [ -n "$SCRIPT_PATH" ] && [ -f "$SCRIPT_PATH" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  if [ -f "$SCRIPT_DIR/gemini-extension.json" ] &&
     [ "$(manifest_name "$SCRIPT_DIR/gemini-extension.json")" = "$EXT_NAME" ]; then
    SRC="$SCRIPT_DIR"
  fi
fi
if [ -z "$SRC" ]; then
  WORK_DIR="$(mktemp -d)"
  CLEANUP="$WORK_DIR"
  echo "Downloading from $REPO..."
  git clone --quiet --depth 1 "$REPO" "$WORK_DIR/$EXT_NAME"
  SRC="$WORK_DIR/$EXT_NAME"
  if [ ! -f "$SRC/gemini-extension.json" ] ||
     [ "$(manifest_name "$SRC/gemini-extension.json")" != "$EXT_NAME" ]; then
    echo "error: the downloaded copy is not $EXT_NAME (its gemini-extension.json names another extension); nothing was installed." >&2
    exit 1
  fi
fi

mkdir -p "$INSTALL_DIR"

# Copy the manifest, context file, and the content directories. Use cp -a to
# preserve the executable bit on the lib/*.sh helpers.
cp "$SRC/gemini-extension.json" "$INSTALL_DIR/"
cp "$SRC/GEMINI.md" "$INSTALL_DIR/"
[ -f "$SRC/LICENSE" ] && cp "$SRC/LICENSE" "$INSTALL_DIR/"
for dir in commands skills agents lib fixtures policies; do
  mkdir -p "$INSTALL_DIR/$dir"
  cp -a "$SRC/$dir/." "$INSTALL_DIR/$dir/"
done

echo ""
echo "Stride Exploratory Testing for Gemini CLI installed to $INSTALL_DIR"
echo ""
echo "Installed:"
echo "  Commands: $(ls "$INSTALL_DIR/commands"/*.toml 2>/dev/null | wc -l | tr -d ' ') (.toml)"
echo "  Skills:   $(ls -d "$INSTALL_DIR/skills"/*/ 2>/dev/null | wc -l | tr -d ' ')"
echo "  Agents:   $(ls "$INSTALL_DIR/agents"/*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "  Helpers:  $(ls "$INSTALL_DIR/lib" 2>/dev/null | wc -l | tr -d ' ') files in lib/"
echo "  Fixtures: $(ls "$INSTALL_DIR/fixtures" 2>/dev/null | wc -l | tr -d ' ') files in fixtures/"
echo "  Policies: $(ls "$INSTALL_DIR/policies"/*.toml 2>/dev/null | wc -l | tr -d ' ') (.toml)"
echo ""
echo "Next steps:"
echo "  1. Restart Gemini CLI so it picks up the new extension"
echo "     (/charter, /nightmare-headline, /explore, /pair, /recon, /debrief, /harden)."
echo "  2. Point it at a running, NON-PRODUCTION app you are authorized to test,"
echo "     then run /charter <target> or /explore <target> to start a session."
