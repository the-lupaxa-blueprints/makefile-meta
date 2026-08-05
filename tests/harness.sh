#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Bare repo whose master/HEAD match the current worktree (tracked + untracked)
# so head→master checkout in tests sees the same tree as the developer.
# Prefer this over `git stash create -u`, which can omit untracked files.
makefiles_bare_repo() {
  local dest="$1"
  local head_commit tmp_index tree
  tmp_index="$(mktemp)"
  GIT_INDEX_FILE="$tmp_index" git -C "$REPO_ROOT" read-tree HEAD
  GIT_INDEX_FILE="$tmp_index" git -C "$REPO_ROOT" add -A
  tree="$(GIT_INDEX_FILE="$tmp_index" git -C "$REPO_ROOT" write-tree)"
  head_commit="$(git -C "$REPO_ROOT" commit-tree "$tree" -p HEAD -m "test worktree snapshot")"
  rm -f "$tmp_index"
  git clone --bare "$REPO_ROOT" "$dest"
  # Make the snapshot reachable in the bare repo (not only via local object hardlinks).
  git -C "$REPO_ROOT" push -q "$dest" "$head_commit":refs/heads/master
  git --git-dir="$dest" symbolic-ref HEAD refs/heads/master
}

make_consumer() {
  local dest="$1"
  mkdir -p "$dest"
  cp "$REPO_ROOT/templates/Makefile" "$dest/Makefile"
  cp "$REPO_ROOT/examples/.gitignore" "$dest/.gitignore"
  # Point at local library so tests do not need network
  # Consumers override MAKEFILES_REPO on the make command line in tests.
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  echo "$haystack" | grep -F -- "$needle" >/dev/null \
    || { echo "ASSERT: expected to contain: $needle" >&2; echo "$haystack" >&2; exit 1; }
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if echo "$haystack" | grep -F -- "$needle" >/dev/null; then
    echo "ASSERT: did not expect: $needle" >&2
    echo "$haystack" >&2
    exit 1
  fi
}

# Fake bump-my-version: updates .bumpversion.toml current_version only.
# Usage: install_bump_stub "$PATH_DIR" && export PATH="$PATH_DIR:$PATH"
install_bump_stub() {
  local bindir="$1"
  mkdir -p "$bindir"
  cat > "$bindir/bump-my-version" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
new=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --new-version) new="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$new" ] || { echo "stub bump-my-version: missing --new-version" >&2; exit 2; }
[ -f .bumpversion.toml ] || { echo "stub bump-my-version: .bumpversion.toml missing" >&2; exit 2; }
tmp="$(mktemp)"
sed "s/^[[:space:]]*current_version[[:space:]]*=[[:space:]]*\".*\"/current_version = \"${new}\"/" \
  .bumpversion.toml > "$tmp"
mv "$tmp" .bumpversion.toml
echo "stub: bumped to $new"
EOF
  chmod +x "$bindir/bump-my-version"
}
