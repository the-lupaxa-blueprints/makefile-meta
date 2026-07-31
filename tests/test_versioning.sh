#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

BARE="$TMP/makefiles.git"
makefiles_bare_repo "$BARE"

CONSUMER="$TMP/consumer"
make_consumer "$CONSUMER"
make -C "$CONSUMER" init MAKEFILES_REPO="$BARE"

# Minimal bumpversion file
cat > "$CONSUMER/.bumpversion.toml" <<'EOF'
[tool.bumpversion]
current_version = "1.2.3"
EOF

out="$(make -C "$CONSUMER" version)"
assert_contains "$out" "1.2.3"

out="$(make -C "$CONSUMER" help)"
assert_contains "$out" "bump-dev"
assert_contains "$out" "show-version-flow"
assert_not_contains "$out" "python-lint"

out="$(make -C "$CONSUMER" show-version-flow)"
assert_contains "$out" "bump-dev"

echo "PASS: test_versioning.sh"
