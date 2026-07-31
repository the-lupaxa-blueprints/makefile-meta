#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

make_consumer() {
  local dest="$1"
  mkdir -p "$dest"
  cp "$REPO_ROOT/templates/Makefile" "$dest/Makefile"
  cp "$REPO_ROOT/examples/.gitignore" "$dest/.gitignore"
  # Point at local library so tests do not need network
  # Consumers override MAKEFILES_REPO on the make command line in tests.
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  echo "$haystack" | grep -F -- "$needle" >/dev/null \
    || { echo "ASSERT: expected to contain: $needle" >&2; echo "$haystack" >&2; exit 1; }
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if echo "$haystack" | grep -F -- "$needle" >/dev/null; then
    echo "ASSERT: did not expect: $needle" >&2
    echo "$haystack" >&2
    exit 1
  fi
}
