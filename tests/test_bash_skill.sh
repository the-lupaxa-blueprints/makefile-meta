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

mkdir -p "$CONSUMER/bin"
cat > "$CONSUMER/bin/ok.sh" <<'EOF'
#!/usr/bin/env bash
echo ok
EOF
chmod +x "$CONSUMER/bin/ok.sh"

# Extensionless script — detected via shebang / file(1), not suffix
cat > "$CONSUMER/bin/tool" <<'EOF'
#!/usr/bin/env bash
echo tool
EOF
chmod +x "$CONSUMER/bin/tool"

out="$(make -C "$CONSUMER" help SKILLS=bash)"
assert_contains "$out" "bash-shellcheck"
assert_not_contains "$out" "python-lint"

out="$(make -C "$CONSUMER" bash-list-scripts SKILLS=bash)"
assert_contains "$out" "bin/ok.sh"
assert_contains "$out" "bin/tool"
assert_not_contains "$out" ".makefiles/"

make -C "$CONSUMER" bash-syntax SKILLS=bash

test -x "$CONSUMER/.makefiles/skills/bash/find-shell-files"

echo "PASS: test_bash_skill.sh"
