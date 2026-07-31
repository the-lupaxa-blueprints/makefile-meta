#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash tests/test_wrapper.sh
bash tests/test_versioning.sh
bash tests/test_python_skill.sh
bash tests/test_mkdocs_skill.sh
bash tests/test_bash_skill.sh
bash tests/test_examples_drift.sh
echo "PASS: all makefile-skills tests"
