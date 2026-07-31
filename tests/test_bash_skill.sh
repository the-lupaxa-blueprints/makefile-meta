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

mkdir -p "$CONSUMER/bin"
cat > "$CONSUMER/bin/ok.sh" <<'EOF'
#!/usr/bin/env bash
echo ok
EOF
chmod +x "$CONSUMER/bin/ok.sh"

out="$(make -C "$CONSUMER" help SKILLS=bash)"
assert_contains "$out" "bash-shellcheck"
assert_not_contains "$out" "python-lint"

out="$(make -C "$CONSUMER" bash-list-scripts SKILLS=bash)"
assert_contains "$out" "bin/ok.sh"

make -C "$CONSUMER" bash-syntax SKILLS=bash

test -x "$CONSUMER/.makefiles/skills/bash/find-shell-files"

echo "PASS: test_bash_skill.sh"
