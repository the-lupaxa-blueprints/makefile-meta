#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$REPO_ROOT/templates/Makefile"

for example in "$REPO_ROOT"/examples/Makefile.*; do
  name="$(basename "$example")"

  if [ "$name" = "Makefile.versioning-only" ]; then
    if ! diff -q "$TEMPLATE" "$example" >/dev/null; then
      echo "ASSERT: $name is expected to be identical to templates/Makefile" >&2
      diff -u "$TEMPLATE" "$example" >&2 || true
      exit 1
    fi
    continue
  fi

  diff_out="$(diff "$TEMPLATE" "$example" || true)"

  if [ -z "$diff_out" ]; then
    echo "ASSERT: $name is expected to differ from templates/Makefile on the SKILLS line" >&2
    exit 1
  fi

  non_skills_diff="$(echo "$diff_out" | grep -v -- '^[<>-]*[<>] SKILLS' | grep -E '^[<>]' || true)"
  if [ -n "$non_skills_diff" ]; then
    echo "ASSERT: $name has drifted from templates/Makefile beyond the SKILLS line:" >&2
    echo "$diff_out" >&2
    exit 1
  fi
done

echo "PASS: test_examples_drift.sh"
