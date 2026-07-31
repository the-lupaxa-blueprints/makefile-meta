#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Bare repo whose master/HEAD match REPO_ROOT HEAD so head→master checkout
# in tests sees the same commit as the worktree (not upstream master).
makefiles_bare_repo() {
  local dest="$1"
  local head_commit
  head_commit="$(git -C "$REPO_ROOT" stash create --include-untracked 2>/dev/null || true)"
  if [ -z "$head_commit" ]; then
    head_commit="$(git -C "$REPO_ROOT" rev-parse HEAD)"
  fi
  git clone --bare "$REPO_ROOT" "$dest"
  git --git-dir="$dest" update-ref refs/heads/master "$head_commit"
  git --git-dir="$dest" symbolic-ref HEAD refs/heads/master
}

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
