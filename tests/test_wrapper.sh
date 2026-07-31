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
assert_contains "$out" "status"
assert_contains "$out" "make init"
assert_contains "$out" "transport"

# transport selects SSH vs HTTPS URL (MAKEFILES_REPO still overridable)
out="$(make -C "$CONSUMER" help MAKEFILES_TRANSPORT=ssh)"
assert_contains "$out" "git@github.com:the-lupaxa-blueprints/makefile-meta.git"
out="$(make -C "$CONSUMER" help MAKEFILES_TRANSPORT=https)"
assert_contains "$out" "https://github.com/the-lupaxa-blueprints/makefile-meta.git"
out="$(make -C "$CONSUMER" help MAKEFILES_TRANSPORT=http)"
assert_contains "$out" "https://github.com/the-lupaxa-blueprints/makefile-meta.git"
set +e
err="$(make -C "$CONSUMER" help MAKEFILES_TRANSPORT=ftp 2>&1)"
rc=$?
set -e
test "$rc" -ne 0
assert_contains "$err" "MAKEFILES_TRANSPORT"

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

# init against a ref that predates the skills library fails clearly and
# removes the partial clone so a retry with a good ref can succeed
EARLY_SHA="$(git -C "$REPO_ROOT" rev-parse 4e5a5be)"
CONSUMER3="$TMP/consumer3"
make_consumer "$CONSUMER3"
set +e
err="$(make -C "$CONSUMER3" init MAKEFILES_REPO="$BARE" MAKEFILES_REF="$EARLY_SHA" 2>&1)"
rc=$?
set -e
test "$rc" -ne 0
assert_contains "$err" "versioning.mk"
assert_contains "$err" "$EARLY_SHA"
test ! -e "$CONSUMER3/.makefiles"

# retrying init with a good ref now succeeds
make -C "$CONSUMER3" init MAKEFILES_REPO="$BARE"
test -f "$CONSUMER3/.makefiles/skills/versioning.mk"

# update with head keeps a git checkout on master
make -C "$CONSUMER" update MAKEFILES_REF=head
branch="$(git -C "$CONSUMER/.makefiles" rev-parse --abbrev-ref HEAD)"
test "$branch" = "master"

# update with a pinned tag checks out a detached HEAD at that commit
TAG_SHA="$(git --git-dir="$BARE" rev-parse master)"
git --git-dir="$BARE" tag --no-sign v-test-pin master
make -C "$CONSUMER" update MAKEFILES_REF=v-test-pin
branch="$(git -C "$CONSUMER/.makefiles" rev-parse --abbrev-ref HEAD)"
test "$branch" = "HEAD"
sha="$(git -C "$CONSUMER/.makefiles" rev-parse HEAD)"
test "$sha" = "$TAG_SHA"

# a bogus ref fails the checkout without clobbering the existing clone
set +e
err="$(make -C "$CONSUMER" update MAKEFILES_REF=does-not-exist 2>&1)"
rc=$?
set -e
test "$rc" -ne 0
test -d "$CONSUMER/.makefiles/.git"

echo "PASS: test_wrapper.sh"
