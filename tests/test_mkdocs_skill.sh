#!/usr/bin/env bash
set -euo pipefail
# CI shellcheck runs one file at a time without -x; do not require following.
# shellcheck source=/dev/null
source "$(dirname "$0")/harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

BARE="$TMP/makefiles.git"
makefiles_bare_repo "$BARE"

CONSUMER="$TMP/consumer"
make_consumer "$CONSUMER"
make -C "$CONSUMER" init MAKEFILES_REPO="$BARE"

out="$(make -C "$CONSUMER" help SKILLS='python mkdocs')"
assert_contains "$out" "python-lint"
assert_contains "$out" "mkdocs-build"

out="$(make -C "$CONSUMER" help SKILLS=mkdocs)"
assert_contains "$out" "mkdocs-build"
assert_not_contains "$out" "python-lint"

make -C "$CONSUMER" -n mkdocs-build SKILLS=mkdocs >/dev/null

out="$(make -C "$CONSUMER" -n mkdocs-serve SKILLS=mkdocs MKDOCS_PORT=8001)"
assert_contains "$out" "8001"
assert_contains "$out" "--dev-addr"

out="$(make -C "$CONSUMER" help SKILLS=mkdocs)"
assert_contains "$out" "MKDOCS_PORT"

echo "PASS: test_mkdocs_skill.sh"
