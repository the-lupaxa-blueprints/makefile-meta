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

cat > "$CONSUMER/.bumpversion.toml" <<'EOF'
[tool.bumpversion]
current_version = "1.2.3"
parse = "(?P<version>.*)"
serialize = ["{version}"]
commit = false
tag = false
allow_dirty = true
EOF

STUB_BIN="$TMP/bin"
install_bump_stub "$STUB_BIN"
export PATH="$STUB_BIN:$PATH"

set_version() {
  local v="$1"
  sed -i.bak "s/^current_version = \".*\"/current_version = \"$v\"/" "$CONSUMER/.bumpversion.toml"
  rm -f "$CONSUMER/.bumpversion.toml.bak"
}

assert_version() {
  local expected="$1"
  local out file_ver
  out="$(make -C "$CONSUMER" version)"
  assert_contains "$out" "$expected"
  file_ver="$(sed -n 's/^current_version = "\([^"]*\)"/\1/p' "$CONSUMER/.bumpversion.toml")"
  [ "$file_ver" = "$expected" ] || {
    echo "ASSERT: .bumpversion.toml has $file_ver, expected $expected" >&2
    exit 1
  }
}

run_bump() {
  make -C "$CONSUMER" "$1" >/dev/null
}

assert_bump_fails() {
  local target="$1"
  local err rc=0
  err="$(make -C "$CONSUMER" "$target" 2>&1 >/dev/null)" || rc=$?
  if [ "$rc" -ne 2 ]; then
    echo "ASSERT: expected make $target to exit 2, got $rc" >&2
    exit 1
  fi
  assert_contains "$err" "ERROR"
}

assert_alias_equivalent() {
  local start="$1" canonical="$2" alias="$3" expected="$4"
  set_version "$start"
  run_bump "$canonical"
  assert_version "$expected"
  set_version "$start"
  run_bump "$alias"
  assert_version "$expected"
}

# Help lists new flexible bump targets
out="$(make -C "$CONSUMER" help)"
for target in bump-patch bump-minor bump-major bump-dev bump-minor-dev bump-major-dev \
  bump-rc bump-minor-rc bump-major-rc release; do
  assert_contains "$out" "$target"
done
assert_not_contains "$out" "python-lint"

# Happy-path transition matrix
assert_version "1.2.3"

run_bump bump-patch
assert_version "1.2.4"

set_version "1.2.3"
run_bump bump-minor
assert_version "1.3.0"

set_version "1.2.3"
run_bump bump-major
assert_version "2.0.0"

set_version "1.2.3"
run_bump bump-dev
assert_version "1.2.4-dev1"

run_bump bump-dev
assert_version "1.2.4-dev2"

run_bump bump-rc
assert_version "1.2.4-rc1"

run_bump release
assert_version "1.2.4"

set_version "1.2.3"
run_bump bump-minor-dev
assert_version "1.3.0-dev1"

run_bump bump-minor-rc
assert_version "1.3.0-rc1"

run_bump release
assert_version "1.3.0"

# Aliases behave like their canonical targets
assert_alias_equivalent "1.2.3" bump-patch-dev bump-dev "1.2.4-dev1"
assert_alias_equivalent "1.2.4-dev1" bump-patch-rc bump-rc "1.2.4-rc1"
assert_alias_equivalent "1.2.3" bump-patch-rc bump-rc "1.2.4-rc1"
assert_alias_equivalent "1.2.4-rc1" release bump-final "1.2.4"

# Direct stable → -rc1 (no -dev required)
set_version "1.2.3"
run_bump bump-rc
assert_version "1.2.4-rc1"

set_version "1.2.3"
run_bump bump-minor-rc
assert_version "1.3.0-rc1"

# Major pre-release channel
set_version "1.2.3"
run_bump bump-major-dev
assert_version "2.0.0-dev1"

run_bump bump-major-rc
assert_version "2.0.0-rc1"

run_bump release
assert_version "2.0.0"

# Strict-channel error cases (stable → rc is allowed)
set_version "1.2.4-dev1"
assert_bump_fails bump-minor-dev
assert_bump_fails bump-patch
assert_bump_fails release

set_version "1.2.4-rc1"
assert_bump_fails bump-dev

set_version "2.0.0-dev1"
assert_bump_fails bump-patch-dev

# show-version-flow / status: channel-specific target names for open cycles
set_version "1.3.0-dev1"
out="$(make -C "$CONSUMER" show-version-flow)"
assert_contains "$out" "bump-minor-dev"
assert_contains "$out" "bump-minor-rc"
out="$(make -C "$CONSUMER" status)"
assert_contains "$out" "bump-minor-dev"
assert_contains "$out" "bump-minor-rc"

set_version "2.0.0-rc1"
out="$(make -C "$CONSUMER" show-version-flow)"
assert_contains "$out" "bump-major-rc"
out="$(make -C "$CONSUMER" status)"
assert_contains "$out" "bump-major-rc"

# 0.0.0-devN / 0.0.0-rcN must not be misclassified as an open major channel
set_version "0.0.0-dev1"
out="$(make -C "$CONSUMER" show-version-flow)"
assert_not_contains "$out" "bump-major-dev"
assert_contains "$out" "No matching channel"
out="$(make -C "$CONSUMER" status)"
assert_not_contains "$out" "bump-major-dev"
assert_contains "$out" "No matching channel"

set_version "0.0.0-rc1"
out="$(make -C "$CONSUMER" show-version-flow)"
assert_not_contains "$out" "bump-major-rc"
assert_contains "$out" "No matching channel"
assert_contains "$out" "make release"
out="$(make -C "$CONSUMER" status)"
assert_not_contains "$out" "bump-major-rc"
assert_contains "$out" "No matching channel"

# draft-tag: packaging helper outside the version flow
out="$(make -C "$CONSUMER" help-versioning)"
assert_contains "$out" "draft-tag"
assert_contains "$out" "GitHub packaging"

git -C "$CONSUMER" init -q
git -C "$CONSUMER" config user.email "test@example.com"
git -C "$CONSUMER" config user.name "Test"
git -C "$CONSUMER" config commit.gpgsign false
git -C "$CONSUMER" config tag.gpgSign false
git -C "$CONSUMER" add -A
git -C "$CONSUMER" commit -qm "init"

set_version "1.2.4-rc1"
before="$(sed -n 's/^current_version = "\([^"]*\)"/\1/p' "$CONSUMER/.bumpversion.toml")"
out="$(make -C "$CONSUMER" draft-tag)"
assert_contains "$out" "v1.2.4-draft1"
assert_contains "$out" "unchanged: 1.2.4-rc1"
after="$(sed -n 's/^current_version = "\([^"]*\)"/\1/p' "$CONSUMER/.bumpversion.toml")"
test "$before" = "$after"
git -C "$CONSUMER" rev-parse -q --verify refs/tags/v1.2.4-draft1 >/dev/null

out="$(make -C "$CONSUMER" draft-tag)"
assert_contains "$out" "v1.2.4-draft2"
git -C "$CONSUMER" rev-parse -q --verify refs/tags/v1.2.4-draft2 >/dev/null

out="$(make -C "$CONSUMER" draft-tag DRAFT_BASE=9.9.9)"
assert_contains "$out" "v9.9.9-draft1"

echo "PASS: test_versioning.sh"
