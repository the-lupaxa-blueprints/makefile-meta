PYTHON ?= python3
PIP ?= $(PYTHON) -m pip
HATCH ?= hatch
MYPY ?= mypy
PYTEST ?= pytest
RUFF ?= ruff

SRC_DIR ?= src
TEST_DIR ?= tests
COVERAGE_TARGET ?= $(SRC_DIR)
AUDIT_VENV_DIR ?= .audit-env
AUDIT_PYTHON := $(AUDIT_VENV_DIR)/bin/python
PYPROJECT_FILE ?= pyproject.toml

STATUS_FRAGMENTS += status-python

.PHONY: help-python status-python python-doctor python-install-dev python-install-test python-lint python-check-style python-check-diff python-check-diff-all python-format python-format-diff python-type python-test python-test-cov python-check python-check-all python-audit python-build python-publish python-clean

help-python:
	@echo "Python:"
	@echo "  python-doctor       Check Python tools and project layout"
	@echo "  python-install-dev  Install editable with dev extras"
	@echo "  python-install-test Install editable with test extras"
	@echo "  python-lint         Ruff lint + format check"
	@echo "  python-check-style  Lint + type"
	@echo "  python-check-diff   Show Ruff lint corrections"
	@echo "  python-check-diff-all Show lint and format changes"
	@echo "  python-format       Ruff format"
	@echo "  python-format-diff  Show Ruff formatting changes"
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
	@printf '\nPython:\n'
	@if [ -f "$(PYPROJECT_FILE)" ]; then \
		printf '  %-22s %s\n' "Configuration:" "[OK] $(PYPROJECT_FILE)"; \
	else \
		printf '  %-22s %s\n' "Configuration:" "[MISSING] $(PYPROJECT_FILE)"; \
	fi; \
	if [ -d "$(SRC_DIR)" ]; then \
		printf '  %-22s %s\n' "Source directory:" "[OK] $(SRC_DIR)"; \
	else \
		printf '  %-22s %s\n' "Source directory:" "[MISSING] $(SRC_DIR)"; \
	fi; \
	if [ -d "$(TEST_DIR)" ]; then \
		printf '  %-22s %s\n' "Test directory:" "[OK] $(TEST_DIR)"; \
	else \
		printf '  %-22s %s\n' "Test directory:" "[MISSING] $(TEST_DIR)"; \
	fi; \
	if command -v "$(PYTHON)" >/dev/null 2>&1; then \
		python_version="$$("$(PYTHON)" --version 2>&1)"; \
		printf '  %-22s %s\n' "Python:" "[OK] $$python_version"; \
		printf '  %-22s %s\n' "Python executable:" "$$(command -v "$(PYTHON)")"; \
	else \
		printf '  %-22s %s\n' "Python:" "[MISSING] $(PYTHON)"; \
		printf '  %-22s %s\n' "Python executable:" "[UNAVAILABLE]"; \
	fi; \
	if command -v "$(HATCH)" >/dev/null 2>&1; then \
		printf '  %-22s %s\n' "Hatch:" "[OK] $$(command -v "$(HATCH)")"; \
	else \
		printf '  %-22s %s\n' "Hatch:" "[MISSING] $(HATCH)"; \
	fi; \
	if command -v "$(RUFF)" >/dev/null 2>&1; then \
		printf '  %-22s %s\n' "Ruff:" "[OK] $$(command -v "$(RUFF)")"; \
	else \
		printf '  %-22s %s\n' "Ruff:" "[MISSING] $(RUFF)"; \
	fi; \
	if command -v "$(MYPY)" >/dev/null 2>&1; then \
		printf '  %-22s %s\n' "mypy:" "[OK] $$(command -v "$(MYPY)")"; \
	else \
		printf '  %-22s %s\n' "mypy:" "[MISSING] $(MYPY)"; \
	fi; \
	if command -v "$(PYTEST)" >/dev/null 2>&1; then \
		printf '  %-22s %s\n' "pytest:" "[OK] $$(command -v "$(PYTEST)")"; \
	else \
		printf '  %-22s %s\n' "pytest:" "[MISSING] $(PYTEST)"; \
	fi

python-doctor:
	@failures=0; \
	printf '\nPython doctor:\n'; \
	if [ -f "$(PYPROJECT_FILE)" ]; then \
		printf '  %-22s %s\n' "Configuration:" "[OK] $(PYPROJECT_FILE)"; \
	else \
		printf '  %-22s %s\n' "Configuration:" "[MISSING] $(PYPROJECT_FILE)"; \
		failures=$$((failures + 1)); \
	fi; \
	if [ -d "$(SRC_DIR)" ]; then \
		printf '  %-22s %s\n' "Source directory:" "[OK] $(SRC_DIR)"; \
	else \
		printf '  %-22s %s\n' "Source directory:" "[MISSING] $(SRC_DIR)"; \
		failures=$$((failures + 1)); \
	fi; \
	if [ -d "$(TEST_DIR)" ]; then \
		printf '  %-22s %s\n' "Test directory:" "[OK] $(TEST_DIR)"; \
	else \
		printf '  %-22s %s\n' "Test directory:" "[MISSING] $(TEST_DIR)"; \
		failures=$$((failures + 1)); \
	fi; \
	for tool_pair in "Python:$(PYTHON)" "Ruff:$(RUFF)" "mypy:$(MYPY)" "pytest:$(PYTEST)" "Hatch:$(HATCH)"; do \
		label="$${tool_pair%%:*}"; \
		cmd="$${tool_pair#*:}"; \
		if command -v "$$cmd" >/dev/null 2>&1; then \
			printf '  %-22s %s\n' "$$label:" "[OK] $$(command -v "$$cmd")"; \
		else \
			printf '  %-22s %s\n' "$$label:" "[MISSING] $$cmd"; \
			failures=$$((failures + 1)); \
		fi; \
	done; \
	if [ "$$failures" -ne 0 ]; then \
		echo "Python doctor found $$failures issue(s)." >&2; \
		exit 1; \
	fi; \
	echo "Python doctor: OK"

python-install-dev:
	$(PIP) install -e ".[dev]"

python-install-test:
	$(PIP) install -e ".[test]"

python-lint:
	$(RUFF) check "$(SRC_DIR)" "$(TEST_DIR)"
	$(RUFF) format --check "$(SRC_DIR)" "$(TEST_DIR)"

python-check-style: python-lint python-type

python-check-diff:
	$(RUFF) check --diff "$(SRC_DIR)" "$(TEST_DIR)"

python-check-diff-all: python-check-diff python-format-diff

python-format:
	$(RUFF) format "$(SRC_DIR)" "$(TEST_DIR)"

python-format-diff:
	$(RUFF) format --diff "$(SRC_DIR)" "$(TEST_DIR)"

python-type:
	$(MYPY) "$(SRC_DIR)"

python-test:
	$(PYTEST) -v

python-test-cov:
	$(PYTEST) \
		--cov="$(COVERAGE_TARGET)" \
		--cov-report=term-missing \
		-v

python-check: python-lint python-type python-test

python-check-all: python-lint python-type python-test-cov python-audit

python-audit:
	@set -e; \
	echo "==> Creating temporary audit environment: $(AUDIT_VENV_DIR)"; \
	rm -rf "$(AUDIT_VENV_DIR)"; \
	trap 'rm -rf "$(AUDIT_VENV_DIR)"' EXIT HUP INT TERM; \
	"$(PYTHON)" -m venv "$(AUDIT_VENV_DIR)"; \
	"$(AUDIT_PYTHON)" -m pip install --upgrade pip; \
	"$(AUDIT_PYTHON)" -m pip install -e ".[dev]"; \
	"$(AUDIT_PYTHON)" -m pip install pip-audit; \
	echo "==> Running dependency audit"; \
	"$(AUDIT_PYTHON)" -m pip_audit; \
	echo "==> Dependency audit complete"

python-build:
	$(HATCH) build

python-publish: python-build
	$(HATCH) publish

python-clean:
	rm -rf \
		"$(AUDIT_VENV_DIR)" \
		build \
		dist \
		.pytest_cache \
		.mypy_cache \
		.ruff_cache \
		.coverage \
		coverage.xml \
		htmlcov
	find . \
		-type d \
		\( \
			-name "*.egg-info" \
			-o -name "__pycache__" \
		\) \
		-prune \
		-exec rm -rf {} +
