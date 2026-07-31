#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

BARE="$TMP/makefiles.git"
makefiles_bare_repo "$BARE"

CONSUMER="$TMP/consumer"
make_consumer "$CONSUMER"

# Enable python skill in wrapper copy.
make -C "$CONSUMER" init MAKEFILES_REPO="$BARE"

out="$(make -C "$CONSUMER" help SKILLS=python)"
assert_contains "$out" "python-lint"
assert_contains "$out" "bump-dev"
assert_not_contains "$out" "mkdocs-build"
assert_not_contains "$out" "bash-shellcheck"

# Without SKILLS, python help absent.
out="$(make -C "$CONSUMER" help)"
assert_not_contains "$out" "python-lint"

# Target exists when skill enabled.
make -C "$CONSUMER" -n python-lint SKILLS=python >/dev/null

echo "PASS: test_python_skill.sh"
