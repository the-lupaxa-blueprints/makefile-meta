#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

BARE="$TMP/makefiles.git"
makefiles_bare_repo "$BARE"

CONSUMER="$TMP/consumer"
make_consumer "$CONSUMER"

# doctor before init fails and mentions make init
set +e
err="$(make -C "$CONSUMER" doctor 2>&1)"
rc=$?
set -e
test "$rc" -ne 0
assert_contains "$err" "make init"

make -C "$CONSUMER" init MAKEFILES_REPO="$BARE"

out="$(make -C "$CONSUMER" help)"
assert_contains "$out" "doctor"

out="$(make -C "$CONSUMER" help SKILLS=bash)"
assert_contains "$out" "bash-doctor"

cat > "$CONSUMER/.bumpversion.toml" <<'TOML'
[tool.bumpversion]
current_version = "0.1.0"
TOML

set +e
out="$(make -C "$CONSUMER" doctor SKILLS=bash 2>&1)"
rc=$?
set -e
test "$rc" -ne 0
assert_contains "$out" "Lifecycle:"
assert_contains "$out" "Versioning doctor:"
assert_contains "$out" "Bash doctor:"

make -C "$CONSUMER" -n bash-doctor SKILLS=bash >/dev/null
make -C "$CONSUMER" -n doctor-versioning >/dev/null
make -C "$CONSUMER" -n python-doctor SKILLS=python >/dev/null
make -C "$CONSUMER" -n mkdocs-doctor SKILLS=mkdocs >/dev/null

echo "PASS: test_doctor.sh"
