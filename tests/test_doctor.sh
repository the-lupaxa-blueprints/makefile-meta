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
assert_contains "$out" "Lifecycle:"
assert_contains "$out" "Status:"
# Status (status/doctor) is provided by help-versioning, above Versioning
ver_help="$(make -C "$CONSUMER" help-versioning)"
assert_contains "$ver_help" "Status:"
assert_contains "$ver_help" "Versioning:"
set +e
printf '%s\n' "$ver_help" | awk '/^Versioning:/{p=1;next} /^[A-Za-z]/{if(p)exit} p' | grep -E '^[[:space:]]+status[[:space:]]' >/dev/null
status_under_versioning=$?
printf '%s\n' "$ver_help" | awk '/^Status:/{p=1;next} /^[A-Za-z]/{if(p&&$0!~/^Status:/)exit} p' | grep -E '^[[:space:]]+status[[:space:]]' >/dev/null
status_under_status=$?
printf '%s\n' "$ver_help" | awk '/^Status:/{p=1;next} /^[A-Za-z]/{if(p&&$0!~/^Status:/)exit} p' | grep -E '^[[:space:]]+doctor[[:space:]]' >/dev/null
doctor_under_status=$?
set -e
test "$status_under_versioning" -ne 0
test "$status_under_status" -eq 0
test "$doctor_under_status" -eq 0

# completion script is part of the sparse skills tree
test -f "$CONSUMER/.makefiles/skills/completion/bash"
out="$(make -C "$CONSUMER" completion)"
assert_contains "$out" "_makefile_skills_completions"
assert_contains "$out" "complete"

out="$(make -C "$CONSUMER" help SKILLS=bash)"
assert_contains "$out" "bash-doctor"
assert_contains "$out" "doctor-versioning"

cat > "$CONSUMER/.bumpversion.toml" <<'TOML'
[tool.bumpversion]
current_version = "0.1.0"
TOML

# Versioning fails (no bump-my-version) but Bash doctor must still run; aggregate at end.
set +e
out="$(make -C "$CONSUMER" doctor SKILLS=bash 2>&1)"
rc=$?
set -e
test "$rc" -ne 0
assert_contains "$out" "Lifecycle:"
assert_contains "$out" "Versioning doctor:"
assert_contains "$out" "Bash doctor:"
assert_contains "$out" "Doctor found"
assert_contains "$out" "failing section"

# Multiple skill doctors all run even when versioning fails first.
mkdir -p "$CONSUMER/mkdocs"
cat > "$CONSUMER/mkdocs.yml" <<'YML'
site_name: test
YML
set +e
out="$(make -C "$CONSUMER" doctor SKILLS='bash mkdocs' 2>&1)"
rc=$?
set -e
test "$rc" -ne 0
assert_contains "$out" "Versioning doctor:"
assert_contains "$out" "Bash doctor:"
assert_contains "$out" "MkDocs doctor:"
# Summary comes after every section
versioning_line="$(printf '%s\n' "$out" | grep -n 'Versioning doctor:' | head -1 | cut -d: -f1)"
bash_line="$(printf '%s\n' "$out" | grep -n 'Bash doctor:' | head -1 | cut -d: -f1)"
mkdocs_line="$(printf '%s\n' "$out" | grep -n 'MkDocs doctor:' | head -1 | cut -d: -f1)"
summary_line="$(printf '%s\n' "$out" | grep -n 'Doctor found' | head -1 | cut -d: -f1)"
test "$versioning_line" -lt "$bash_line"
test "$bash_line" -lt "$mkdocs_line"
test "$mkdocs_line" -lt "$summary_line"

make -C "$CONSUMER" -n bash-doctor SKILLS=bash >/dev/null
make -C "$CONSUMER" -n doctor-versioning >/dev/null
make -C "$CONSUMER" -n python-doctor SKILLS=python >/dev/null
make -C "$CONSUMER" -n mkdocs-doctor SKILLS=mkdocs >/dev/null

echo "PASS: test_doctor.sh"
