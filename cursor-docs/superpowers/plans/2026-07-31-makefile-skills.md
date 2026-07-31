# Makefile Skills Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure `makefile-meta` into a skills library that projects consume via a thin wrapper (`make init` / `make update`), with always-on versioning and optional prefixed language/docs skills.

**Architecture:** Projects commit a small `Makefile` that clones this repo into gitignored `.makefiles/`, always `-include`s `skills/versioning.mk`, and optionally includes skills from `SKILLS`. Lifecycle and base `help` live in the wrapper; each skill is a standalone `.mk` that registers `help-<name>` and optional `status-<name>` fragments. Language targets use prefixes (`python-lint`, `bash-shellcheck`).

**Tech Stack:** GNU Make, Bash, git, existing tooling assumed by skills (`bump-my-version`, Ruff, Hatch, MkDocs, ShellCheck).

## Global Constraints

- Versioning is always included; it is never listed in `SKILLS`.
- Optional skills are standalone (no skill-to-skill includes or dependency graph).
- Skills delivery is a gitignored plain clone (not submodule/subtree).
- Default branch for `MAKEFILES_REF=head` is `master`.
- `MAKEFILES_REF` is `head` (default) or a git tag.
- Language/docs targets are hyphen-prefixed by skill name; versioning stays unprefixed.
- `release` means version promotion; packaging publish is `python-publish`.
- Use `-include` so missing `.makefiles/` does not break `init` / `help`.
- Consumer projects commit wrapper + `.gitignore` entry for `.makefiles/` only.
- Spec: `cursor-docs/superpowers/specs/2026-07-31-makefile-skills-design.md`.

---

## File Structure

| Path | Responsibility |
|------|----------------|
| `templates/Makefile` | Canonical project wrapper (init/update/help/includes) copied into consumer repos |
| `skills/versioning.mk` | Unprefixed version targets + `status` core + `help-versioning` |
| `skills/python.mk` | Prefixed Python targets + `help-python` + `status-python` |
| `skills/mkdocs.mk` | Prefixed MkDocs targets + `help-mkdocs` + `status-mkdocs` |
| `skills/bash.mk` | Prefixed Bash targets + `help-bash` + `status-bash` |
| `skills/bash/find-shell-files` | Shell discovery helper used by bash skill |
| `examples/Makefile.*` | Ready-to-copy wrappers with different `SKILLS` values |
| `examples/.gitignore` | Shows `.makefiles/` ignore entry |
| `tests/harness.sh` | Shared helpers for creating a fake consumer project |
| `tests/test_wrapper.sh` | init/update/help/ref resolution tests |
| `tests/test_skills_compose.sh` | SKILLS filtering, prefixes, versioning always on |
| `README.md` | Consumer adoption guide |
| `makefile-*` (legacy) | Removed after skills extract cleanly |

---

### Task 1: Test harness and wrapper lifecycle

**Files:**
- Create: `tests/harness.sh`
- Create: `tests/test_wrapper.sh`
- Create: `templates/Makefile`
- Create: `examples/.gitignore`

**Interfaces:**
- Consumes: none
- Produces: `templates/Makefile` with targets `init`, `install`, `update`, `help`; variables `SKILLS`, `MAKEFILES_DIR`, `MAKEFILES_REPO`, `MAKEFILES_REF`; function `_makefiles_resolve_ref` behaviour via recipes (head → `master`, else tag)

- [ ] **Step 1: Write the failing wrapper tests**

Create `tests/harness.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
```

Create `tests/test_wrapper.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

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
make -C "$CONSUMER" init MAKEFILES_REPO="$REPO_ROOT"
test -d "$CONSUMER/.makefiles/skills"
test -f "$CONSUMER/.makefiles/skills/versioning.mk"

# second init refuses to clobber
set +e
err="$(make -C "$CONSUMER" init MAKEFILES_REPO="$REPO_ROOT" 2>&1)"
rc=$?
set -e
test "$rc" -ne 0
assert_contains "$err" "update"

# install is an alias of init when missing: use fresh dir
CONSUMER2="$TMP/consumer2"
make_consumer "$CONSUMER2"
make -C "$CONSUMER2" install MAKEFILES_REPO="$REPO_ROOT"
test -d "$CONSUMER2/.makefiles/skills"

# update with head keeps a git checkout on master
make -C "$CONSUMER" update MAKEFILES_REF=head
branch="$(git -C "$CONSUMER/.makefiles" rev-parse --abbrev-ref HEAD)"
test "$branch" = "master"

echo "PASS: test_wrapper.sh"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `chmod +x tests/harness.sh tests/test_wrapper.sh && bash tests/test_wrapper.sh`

Expected: FAIL (missing `templates/Makefile` and/or skills)

- [ ] **Step 3: Create `examples/.gitignore` and `templates/Makefile`**

`examples/.gitignore`:

```gitignore
.makefiles/
```

`templates/Makefile` (complete wrapper):

```makefile
# Lupaxa makefile-skills project wrapper
# Copy this file to your project root as Makefile.

SKILLS         ?=
MAKEFILES_DIR  ?= .makefiles
MAKEFILES_REPO ?= git@github.com:the-lupaxa-blueprints/makefile-meta.git
MAKEFILES_REF  ?= head

.DEFAULT_GOAL := help

.PHONY: init install update help version bump-dev bump-minor bump-major bump-rc release bump-final show-version-flow status

# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------

init install:
	@set -e; \
	if [ -e "$(MAKEFILES_DIR)" ]; then \
		echo "ERROR: $(MAKEFILES_DIR) already exists. Use 'make update' or remove it first." >&2; \
		exit 2; \
	fi; \
	echo "==> Cloning $(MAKEFILES_REPO) into $(MAKEFILES_DIR)"; \
	git clone "$(MAKEFILES_REPO)" "$(MAKEFILES_DIR)"; \
	$(MAKE) --no-print-directory _makefiles-checkout

update:
	@set -e; \
	if [ ! -d "$(MAKEFILES_DIR)/.git" ]; then \
		echo "ERROR: $(MAKEFILES_DIR) is not a git clone. Run: make init" >&2; \
		exit 2; \
	fi; \
	echo "==> Updating makefile skills in $(MAKEFILES_DIR) (ref=$(MAKEFILES_REF))"; \
	git -C "$(MAKEFILES_DIR)" fetch --tags origin; \
	git -C "$(MAKEFILES_DIR)" fetch origin; \
	$(MAKE) --no-print-directory _makefiles-checkout

.PHONY: _makefiles-checkout
_makefiles-checkout:
	@set -e; \
	if [ "$(MAKEFILES_REF)" = "head" ]; then \
		git -C "$(MAKEFILES_DIR)" checkout master; \
		git -C "$(MAKEFILES_DIR)" pull --ff-only origin master; \
	else \
		git -C "$(MAKEFILES_DIR)" checkout "$(MAKEFILES_REF)"; \
	fi; \
	echo "==> makefile skills at $$(git -C "$(MAKEFILES_DIR)" rev-parse --short HEAD) ($(MAKEFILES_REF))"

# -----------------------------------------------------------------------------
# Help / missing-skills guards
# -----------------------------------------------------------------------------

help:
	@echo "$(or $(PROJECT_NAME),$(notdir $(CURDIR))) Makefile"
	@echo
	@echo "Lifecycle:"
	@echo "  init / install      Clone makefile skills into $(MAKEFILES_DIR)"
	@echo "  update              Refresh skills to MAKEFILES_REF ($(MAKEFILES_REF))"
	@echo
	@if [ ! -f "$(MAKEFILES_DIR)/skills/versioning.mk" ]; then \
		echo "Skills not installed. Run: make init"; \
		echo; \
	else \
		$(MAKE) --no-print-directory help-versioning; \
		for s in $(SKILLS); do \
			$(MAKE) --no-print-directory help-$$s; \
		done; \
	fi

ifeq ($(wildcard $(MAKEFILES_DIR)/skills/versioning.mk),)
version bump-dev bump-minor bump-major bump-rc release bump-final show-version-flow status:
	@echo "ERROR: makefile skills not installed. Run: make init" >&2
	@exit 2
endif

# -----------------------------------------------------------------------------
# Skills includes
# -----------------------------------------------------------------------------

-include $(MAKEFILES_DIR)/skills/versioning.mk
$(foreach s,$(SKILLS),$(eval -include $(MAKEFILES_DIR)/skills/$(s).mk))
```

For Task 1 tests that require `versioning.mk` after init, also create a **minimal stub** so init tests can proceed before Task 2:

Create `skills/versioning.mk`:

```makefile
# Minimal stub — replaced in Task 2
.PHONY: help-versioning version
help-versioning:
	@echo "Versioning:"
	@echo "  version             Show the current project version (stub)"

version:
	@echo "versioning stub OK"
```

- [ ] **Step 4: Run wrapper tests again**

Run: `bash tests/test_wrapper.sh`

Expected: `PASS: test_wrapper.sh`

Note: `update` with `head` runs `pull`; for a local path clone of this repo that may already be current — that is fine. If `pull` fails because the clone has no `origin` remote matching expectations when `MAKEFILES_REPO` is a path: `git clone /path` sets `origin` to that path; `fetch`/`pull` work offline. Confirm this during the run; if `pull --ff-only` fails on a brand-new clone with no upstream tracking, change `_makefiles-checkout` for `head` to:

```makefile
git -C "$(MAKEFILES_DIR)" checkout master
git -C "$(MAKEFILES_DIR)" reset --hard origin/master
```

after `fetch`, and adjust the template accordingly so the test passes.

- [ ] **Step 5: Commit**

```bash
git add templates/Makefile examples/.gitignore skills/versioning.mk tests/harness.sh tests/test_wrapper.sh
git commit -m "$(cat <<'EOF'
Add project wrapper template with init/update lifecycle.

Establish the gitignored-clone bootstrap path and a shell test harness for consumer projects.
EOF
)"
```

---

### Task 2: Extract real `skills/versioning.mk`

**Files:**
- Modify: `skills/versioning.mk` (replace stub)
- Create: `tests/test_versioning.sh`
- Source content from: `makefile-versioning/Makefile`

**Interfaces:**
- Consumes: wrapper includes; `VERSION_FILE`, `PROJECT_NAME`, `BUMP`, `PROJECT_VERSION`
- Produces: targets `help-versioning`, `status` (core + `$(STATUS_FRAGMENTS)`), `status` sections for project/version/git only, `version`, `show-version-flow`, `bump-dev`, `bump-minor`, `bump-major`, `bump-rc`, `release`, `bump-final`; variable `STATUS_FRAGMENTS` (skills append)

- [ ] **Step 1: Write versioning composition test**

Create `tests/test_versioning.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CONSUMER="$TMP/consumer"
make_consumer "$CONSUMER"
make -C "$CONSUMER" init MAKEFILES_REPO="$REPO_ROOT"

# Minimal bumpversion file
cat > "$CONSUMER/.bumpversion.toml" <<'EOF'
[tool.bumpversion]
current_version = "1.2.3"
EOF

out="$(make -C "$CONSUMER" version)"
assert_contains "$out" "1.2.3"

out="$(make -C "$CONSUMER" help)"
assert_contains "$out" "bump-dev"
assert_contains "$out" "show-version-flow"
assert_not_contains "$out" "python-lint"

out="$(make -C "$CONSUMER" show-version-flow)"
assert_contains "$out" "bump-dev"

echo "PASS: test_versioning.sh"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `chmod +x tests/test_versioning.sh && bash tests/test_versioning.sh`

Expected: FAIL (stub `version` does not read `.bumpversion.toml`)

- [ ] **Step 3: Replace stub with extracted versioning skill**

Rewrite `skills/versioning.mk` by copying behaviour from `makefile-versioning/Makefile` with these structural changes:

1. Keep variables: `PROJECT_NAME`, `BUMP`, `VERSION_FILE`, `PROJECT_VERSION`, `require_version`.
2. Keep recipes for `version`, `bump-dev`, `bump-minor`, `bump-major`, `bump-rc`, `release`/`bump-final`, `show-version-flow` unchanged in logic.
3. Replace monolithic `help` with:

```makefile
.PHONY: help-versioning
help-versioning:
	@echo "Versioning:"
	@echo "  version             Show the current project version"
	@echo "  show-version-flow   Show the version stage and valid next steps"
	@echo "  bump-dev            Start or continue the next patch development cycle"
	@echo "  bump-minor          Start the next minor development cycle"
	@echo "  bump-major          Start the next major development cycle"
	@echo "  bump-rc             Start or continue the release candidate cycle"
	@echo "  release             Publish the current release candidate as stable"
	@echo "  bump-final          Alias of release"
	@echo
```

4. Split `status`: keep the Project / Versioning / Git sections from `makefile-versioning/Makefile`’s `status` recipe in target `status`. After printing Git, invoke optional fragments:

```makefile
STATUS_FRAGMENTS ?=

status:
	@# ... existing project/version/git printf block from makefile-versioning ...
	@for t in $(STATUS_FRAGMENTS); do \
		$(MAKE) --no-print-directory $$t; \
	done
```

5. Do **not** define `.DEFAULT_GOAL` or lifecycle targets in the skill.
6. Do **not** define a top-level `help` target (wrapper owns it).
7. `.PHONY` must list versioning targets plus `help-versioning` (and not `help`).

Copy the full shell recipes from `makefile-versioning/Makefile` — do not reintroduce Python/Bash/MkDocs sections.

- [ ] **Step 4: Run tests**

Run:

```bash
bash tests/test_wrapper.sh
bash tests/test_versioning.sh
```

Expected: both PASS

- [ ] **Step 5: Commit**

```bash
git add skills/versioning.mk tests/test_versioning.sh
git commit -m "$(cat <<'EOF'
Extract versioning skill from the legacy Makefile.

Make help and status composable so optional skills can register their own fragments.
EOF
)"
```

---

### Task 3: Extract `skills/python.mk` with prefixes

**Files:**
- Create: `skills/python.mk`
- Create: `tests/test_python_skill.sh`
- Source: `makefile-python/Makefile` (Python sections only; no versioning duplication)

**Interfaces:**
- Consumes: `STATUS_FRAGMENTS` append protocol from Task 2; wrapper `SKILLS`
- Produces: `help-python`, `status-python`, and prefixed targets listed below

**Target rename map (old → new):**

| Old | New |
|-----|-----|
| `install-dev` | `python-install-dev` |
| `install-test` | `python-install-test` |
| `lint` | `python-lint` |
| `check-style` | `python-check-style` |
| `check-diff` | `python-check-diff` |
| `check-diff-all` | `python-check-diff-all` |
| `format` | `python-format` |
| `format-diff` | `python-format-diff` |
| `type` | `python-type` |
| `test` | `python-test` |
| `test-cov` | `python-test-cov` |
| `check` | `python-check` |
| `check-all` | `python-check-all` |
| `audit` | `python-audit` |
| `build` | `python-build` |
| `publish` | `python-publish` |
| `clean` | `python-clean` |

Internal dependencies must use the new names (`python-check-style: python-lint python-type`, etc.).

- [ ] **Step 1: Write failing composition test**

Create `tests/test_python_skill.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CONSUMER="$TMP/consumer"
make_consumer "$CONSUMER"

# Enable python skill in wrapper copy
# templates/Makefile uses SKILLS ?= so command-line / env works:
make -C "$CONSUMER" init MAKEFILES_REPO="$REPO_ROOT"

out="$(make -C "$CONSUMER" help SKILLS=python)"
assert_contains "$out" "python-lint"
assert_contains "$out" "bump-dev"
assert_not_contains "$out" "mkdocs-build"
assert_not_contains "$out" "bash-shellcheck"

# Without SKILLS, python help absent
out="$(make -C "$CONSUMER" help)"
assert_not_contains "$out" "python-lint"

# Target exists when skill enabled
make -C "$CONSUMER" -n python-lint SKILLS=python >/dev/null

echo "PASS: test_python_skill.sh"
```

- [ ] **Step 2: Run test — expect FAIL**

Run: `chmod +x tests/test_python_skill.sh && bash tests/test_python_skill.sh`

Expected: FAIL (missing `skills/python.mk` / `help-python`)

- [ ] **Step 3: Implement `skills/python.mk`**

Create `skills/python.mk`:

1. Copy Python variables from `makefile-python/Makefile`: `PYTHON`, `PIP`, `HATCH`, `MYPY`, `PYTEST`, `RUFF`, `SRC_DIR`, `TEST_DIR`, `COVERAGE_TARGET`, `AUDIT_VENV_DIR`, `AUDIT_PYTHON`, `PYPROJECT_FILE`.
2. Do **not** copy `BUMP`, `VERSION_FILE`, `PROJECT_VERSION`, or any bump recipes.
3. Apply the rename map above to all targets and prerequisite lists.
4. Register help and status:

```makefile
STATUS_FRAGMENTS += status-python

.PHONY: help-python status-python
# ... all python-* phonies ...

help-python:
	@echo "Python:"
	@echo "  python-install-dev  Install editable with dev extras"
	@echo "  python-install-test Install editable with test extras"
	@echo "  python-lint         Ruff lint + format check"
	@echo "  python-check-style  Lint + type"
	@echo "  python-format       Ruff format"
	@echo "  python-type         mypy"
	@echo "  python-test         pytest"
	@echo "  python-test-cov     pytest with coverage"
	@echo "  python-check        lint + type + test"
	@echo "  python-check-all    lint + type + test-cov + audit"
	@echo "  python-audit        pip-audit in isolated venv"
	@echo "  python-build        Hatch build"
	@echo "  python-publish      Hatch publish"
	@echo "  python-clean        Remove Python artefacts"
	@echo

status-python:
	@# Python section only from makefile-python status (pyproject, SRC_DIR, tools)
	@printf '\nPython:\n'
	@# ... same checks as makefile-python Makefile status Python block ...
```

5. Recipes: keep behaviour from `makefile-python/Makefile` Python/cleanup sections; `python-clean` matches that file’s `clean` (no `site/`).

- [ ] **Step 4: Run tests**

Run:

```bash
bash tests/test_wrapper.sh
bash tests/test_versioning.sh
bash tests/test_python_skill.sh
```

Expected: all PASS

- [ ] **Step 5: Commit**

```bash
git add skills/python.mk tests/test_python_skill.sh
git commit -m "$(cat <<'EOF'
Add standalone python skill with prefixed targets.

Drop duplicated versioning from the Python Makefile and register help/status fragments.
EOF
)"
```

---

### Task 4: Extract `skills/mkdocs.mk`

**Files:**
- Create: `skills/mkdocs.mk`
- Create: `tests/test_mkdocs_skill.sh`
- Source: docs sections of `makefile-python-mkdocs/Makefile`

**Interfaces:**
- Consumes: `STATUS_FRAGMENTS`
- Produces: `help-mkdocs`, `status-mkdocs`, `mkdocs-build`, `mkdocs-serve`, `mkdocs-clean`

**Rename map:**

| Old | New |
|-----|-----|
| `docs-build` | `mkdocs-build` |
| `docs-serve` | `mkdocs-serve` |
| docs portion of `clean` (`site/`) | `mkdocs-clean` |

- [ ] **Step 1: Write failing test**

Create `tests/test_mkdocs_skill.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CONSUMER="$TMP/consumer"
make_consumer "$CONSUMER"
make -C "$CONSUMER" init MAKEFILES_REPO="$REPO_ROOT"

out="$(make -C "$CONSUMER" help SKILLS='python mkdocs')"
assert_contains "$out" "python-lint"
assert_contains "$out" "mkdocs-build"

out="$(make -C "$CONSUMER" help SKILLS=mkdocs)"
assert_contains "$out" "mkdocs-build"
assert_not_contains "$out" "python-lint"

make -C "$CONSUMER" -n mkdocs-build SKILLS=mkdocs >/dev/null

echo "PASS: test_mkdocs_skill.sh"
```

- [ ] **Step 2: Run test — expect FAIL**

Run: `chmod +x tests/test_mkdocs_skill.sh && bash tests/test_mkdocs_skill.sh`

- [ ] **Step 3: Implement `skills/mkdocs.mk`**

```makefile
MKDOCS        ?= mkdocs
MKDOCS_CONFIG ?= mkdocs.yml

STATUS_FRAGMENTS += status-mkdocs

.PHONY: help-mkdocs status-mkdocs mkdocs-build mkdocs-serve mkdocs-clean

help-mkdocs:
	@echo "Documentation (MkDocs):"
	@echo "  mkdocs-build        Build the static MkDocs site"
	@echo "  mkdocs-serve        Serve MkDocs with live reload"
	@echo "  mkdocs-clean        Remove the generated site/ directory"
	@echo

status-mkdocs:
	@printf '\nDocumentation:\n'
	@if [ -f "$(MKDOCS_CONFIG)" ]; then \
		printf '  %-24s %s\n' "Configuration:" "[OK] $(MKDOCS_CONFIG)"; \
	else \
		printf '  %-24s %s\n' "Configuration:" "[MISSING] $(MKDOCS_CONFIG)"; \
	fi; \
	if command -v "$(MKDOCS)" >/dev/null 2>&1; then \
		printf '  %-24s %s\n' "MkDocs:" "[OK] $$(command -v "$(MKDOCS)")"; \
	else \
		printf '  %-24s %s\n' "MkDocs:" "[MISSING] $(MKDOCS)"; \
	fi

mkdocs-build:
	$(MKDOCS) build --config-file "$(MKDOCS_CONFIG)"

mkdocs-serve:
	$(MKDOCS) serve --config-file "$(MKDOCS_CONFIG)"

mkdocs-clean:
	rm -rf site
```

No Python includes or versioning includes.

- [ ] **Step 4: Run tests**

Run:

```bash
bash tests/test_wrapper.sh
bash tests/test_versioning.sh
bash tests/test_python_skill.sh
bash tests/test_mkdocs_skill.sh
```

Expected: all PASS

- [ ] **Step 5: Commit**

```bash
git add skills/mkdocs.mk tests/test_mkdocs_skill.sh
git commit -m "$(cat <<'EOF'
Add standalone mkdocs skill.

Keep docs targets independent of the Python toolchain.
EOF
)"
```

---

### Task 5: Extract `skills/bash.mk` and helper

**Files:**
- Create: `skills/bash.mk`
- Create: `skills/bash/find-shell-files` (copy from `makefile-bash/scripts/find-shell-files`, mode `+x`)
- Create: `tests/test_bash_skill.sh`
- Source: `makefile-bash/Makefile` Bash sections

**Interfaces:**
- Consumes: `MAKEFILES_DIR` from wrapper (for default helper path)
- Produces: `help-bash`, `status-bash`, prefixed bash targets

**Rename map:**

| Old | New |
|-----|-----|
| `list-scripts` | `bash-list-scripts` |
| `syntax` | `bash-syntax` |
| `shellcheck` | `bash-shellcheck` |
| `lint` | `bash-lint` |
| `test` | `bash-test` |
| `check` | `bash-check` |

Default discovery helper:

```makefile
SHELL_FILE_FINDER ?= $(MAKEFILES_DIR)/skills/bash/find-shell-files
```

(`MAKEFILES_DIR` must be defined by the wrapper before include — it is.)

- [ ] **Step 1: Write failing test**

Create `tests/test_bash_skill.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CONSUMER="$TMP/consumer"
make_consumer "$CONSUMER"
make -C "$CONSUMER" init MAKEFILES_REPO="$REPO_ROOT"

# Fixture script
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
```

- [ ] **Step 2: Run test — expect FAIL**

Run: `chmod +x tests/test_bash_skill.sh && bash tests/test_bash_skill.sh`

- [ ] **Step 3: Implement bash skill**

1. `cp makefile-bash/scripts/find-shell-files skills/bash/find-shell-files && chmod +x skills/bash/find-shell-files`
2. Create `skills/bash.mk` from Bash sections of `makefile-bash/Makefile`:
   - Variables: `BASH`, `SHELLCHECK`, `SHELL_SOURCE_DIR`, `SHELL_FILE_FINDER` (default as above), `SHELL_FILES`, `SHELLCHECK_SHELL`, `SHELLCHECK_FLAGS`, `require_shell_files`
   - No versioning block
   - Apply rename map; `bash-lint: bash-shellcheck`; `bash-test: bash-syntax bash-shellcheck`; `bash-check: bash-test`
   - `help-bash` / `status-bash` / `STATUS_FRAGMENTS += status-bash`

- [ ] **Step 4: Run all skill tests**

Run:

```bash
bash tests/test_wrapper.sh
bash tests/test_versioning.sh
bash tests/test_python_skill.sh
bash tests/test_mkdocs_skill.sh
bash tests/test_bash_skill.sh
```

Expected: all PASS

- [ ] **Step 5: Commit**

```bash
git add skills/bash.mk skills/bash/find-shell-files tests/test_bash_skill.sh
git commit -m "$(cat <<'EOF'
Add standalone bash skill with prefixed targets.

Vendor the shell discovery helper under skills/bash for consumer projects.
EOF
)"
```

---

### Task 6: Example wrappers, README, retire legacy trees

**Files:**
- Create: `examples/Makefile.versioning-only`
- Create: `examples/Makefile.python`
- Create: `examples/Makefile.python-docs`
- Create: `examples/Makefile.bash`
- Create: `README.md`
- Create: `tests/run_all.sh`
- Delete: `makefile-versioning/`, `makefile-python/`, `makefile-python-mkdocs/`, `makefile-bash/`

**Interfaces:**
- Consumes: `templates/Makefile`
- Produces: copy-paste examples; public docs; green `tests/run_all.sh`

- [ ] **Step 1: Add examples**

Each example is `templates/Makefile` with only `SKILLS` changed at the top:

- `examples/Makefile.versioning-only` → `SKILLS ?=`
- `examples/Makefile.python` → `SKILLS ?= python`
- `examples/Makefile.python-docs` → `SKILLS ?= python mkdocs`
- `examples/Makefile.bash` → `SKILLS ?= bash`

Keep identical lifecycle/include body (or `include` is wrong for examples — they must be self-contained copies of the template with the one-line `SKILLS` difference).

- [ ] **Step 2: Write `README.md`**

Must document:

1. Copy `templates/Makefile` (or an example) to the project root.
2. Add `.makefiles/` to `.gitignore`.
3. Set `SKILLS` and optionally `MAKEFILES_REF` (`head` or a tag).
4. Run `make init`, then `make help`.
5. Run `make update` to refresh.
6. List skills and example prefixed commands.
7. Note default branch `master` and library tagging (`v1.0.0`) for pins.

- [ ] **Step 3: Add `tests/run_all.sh` and run it**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash tests/test_wrapper.sh
bash tests/test_versioning.sh
bash tests/test_python_skill.sh
bash tests/test_mkdocs_skill.sh
bash tests/test_bash_skill.sh
echo "PASS: all makefile-skills tests"
```

Run: `chmod +x tests/run_all.sh && bash tests/run_all.sh`  
Expected: `PASS: all makefile-skills tests`

- [ ] **Step 4: Remove legacy directories**

```bash
git rm -r makefile-versioning makefile-python makefile-python-mkdocs makefile-bash
```

If they were never tracked, use filesystem delete (`rm -rf ...`) and ensure they are gone.

Re-run: `bash tests/run_all.sh`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add examples README.md tests/run_all.sh
git add -u makefile-versioning makefile-python makefile-python-mkdocs makefile-bash
git commit -m "$(cat <<'EOF'
Document adoption and remove legacy Makefile trees.

Ship example wrappers and a single test entrypoint for the skills library.
EOF
)"
```

- [ ] **Step 6: Tag guidance (no forced tag)**

Do **not** create a git tag unless the user asks. README already explains `MAKEFILES_REF=v1.0.0` once a tag exists. Optionally print a reminder in the commit message body only.

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Gitignored clone delivery | 1 |
| `init` / `install` / `update` | 1 |
| `MAKEFILES_REF=head` → `master` | 1 |
| `MAKEFILES_REF` tag pin | 1 (checkout path); README Task 6 |
| `-include` + help without clone | 1 |
| Clear error before init | 1 |
| Always-on versioning | 2 |
| Optional standalone skills | 3–5 |
| Prefixed language targets | 3–5 |
| Help shows only enabled skills | 1–5 tests |
| Status composition | 2–5 |
| `mkdocs` independent of python | 4 |
| Bash helper in skills clone | 5 |
| Examples + README | 6 |
| Retire `makefile-*` | 6 |
| Consumer commits wrapper + gitignore only | 1, 6 |

---

## Self-review notes

- No TBD placeholders; rename maps are explicit.
- `STATUS_FRAGMENTS` / `help-<skill>` names are consistent across tasks.
- Wrapper stub targets for versioning when clone missing match the always-on skill.
- Tag creation left optional per user control; pin mechanism is implemented in Task 1.
