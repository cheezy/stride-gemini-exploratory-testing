#!/usr/bin/env bash
# Top-level smoke-test runner for the stride-gemini-exploratory-testing extension.
#
# Runs the structure check, the frontmatter check and the installer source
# check in sequence and exits non-zero if any fails. Offline, and it writes
# nothing outside a temp directory: the installer check runs install.sh with
# HOME pointed at a mktemp -d directory and a stub git — suitable for gating a
# release.
#
# Usage:
#   ./lib/test-all.sh
#
# Exit code: 0 only if EVERY check passes; 1 if any fails.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FAILED=0

printf '=== structure ===\n'
if bash "${SCRIPT_DIR}/test-structure.sh"; then
  :
else
  FAILED=1
fi

printf '\n=== frontmatter ===\n'
if bash "${SCRIPT_DIR}/test-frontmatter.sh"; then
  :
else
  FAILED=1
fi

printf '\n=== installers ===\n'
if bash "${SCRIPT_DIR}/test-install.sh"; then
  :
else
  FAILED=1
fi

printf '\n=== result ===\n'
if [ "$FAILED" -eq 0 ]; then
  printf 'ALL CHECKS PASSED\n'
  exit 0
else
  printf 'ONE OR MORE CHECKS FAILED\n'
  exit 1
fi
