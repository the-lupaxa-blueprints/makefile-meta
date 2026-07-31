#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

BARE="$TMP/makefiles.git"
makefiles_bare_repo "$BARE"

CONSUMER="$TMP/consumer"
make_consumer "$CONSUMER"

# help works with no clone
out="$(make -C "$CONSUMER" help)"
assert_contains "$out" "init"
assert_contains "$out" "update"
assert_contains "$out" "make init"

# version before init fails clearly
set +e
err="$(make -C "$CONSUMER" version 2>&1)"
rc=$?
set -e
test "$rc" -ne 0
assert_contains "$err" "make init"

# init clones from local repo path
make -C "$CONSUMER" init MAKEFILES_REPO="$BARE"
test -d "$CONSUMER/.makefiles/skills"
test -f "$CONSUMER/.makefiles/skills/versioning.mk"

# second init refuses to clobber
set +e
err="$(make -C "$CONSUMER" init MAKEFILES_REPO="$BARE" 2>&1)"
rc=$?
set -e
test "$rc" -ne 0
assert_contains "$err" "update"

# install is an alias of init when missing: use fresh dir
CONSUMER2="$TMP/consumer2"
make_consumer "$CONSUMER2"
make -C "$CONSUMER2" install MAKEFILES_REPO="$BARE"
test -d "$CONSUMER2/.makefiles/skills"

# update with head keeps a git checkout on master
make -C "$CONSUMER" update MAKEFILES_REF=head
branch="$(git -C "$CONSUMER/.makefiles" rev-parse --abbrev-ref HEAD)"
test "$branch" = "master"

echo "PASS: test_wrapper.sh"
