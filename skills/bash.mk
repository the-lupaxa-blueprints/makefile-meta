BASH ?= bash
SHELLCHECK ?= shellcheck

SHELL_SOURCE_DIR ?= .
SHELL_FILE_FINDER ?= $(MAKEFILES_DIR)/skills/bash/find-shell-files
SHELL_FILES ?= $(shell \
	if [ -x "$(SHELL_FILE_FINDER)" ]; then \
		"$(SHELL_FILE_FINDER)" "$(SHELL_SOURCE_DIR)" "$(MAKEFILES_DIR)" 2>/dev/null; \
	fi \
)

SHELLCHECK_SHELL ?= bash
SHELLCHECK_FLAGS ?=

STATUS_FRAGMENTS += status-bash

.PHONY: help-bash status-bash bash-doctor bash-list-scripts bash-syntax bash-shellcheck bash-lint bash-test bash-check

help-bash:
	@echo "Bash:"
	@echo "  bash-doctor        Check Bash tools and script discovery"
	@echo "  bash-list-scripts  List discovered Bash scripts"
	@echo "  bash-syntax        Validate Bash syntax using bash -n"
	@echo "  bash-shellcheck    Analyse Bash scripts using ShellCheck"
	@echo "  bash-lint          Alias of bash-shellcheck"
	@echo "  bash-test          Run Bash syntax validation and ShellCheck"
	@echo "  bash-check         Run the complete Bash validation workflow"
	@echo
	@echo "  Discovery uses .sh/.bash suffixes, shebang lines, and file(1)"
	@echo "  (including extensionless commands). Override with SHELL_SOURCE_DIR"
	@echo "  or SHELL_FILES. The skills clone (.makefiles) is excluded."
	@echo

define require_shell_files
	@test -x "$(SHELL_FILE_FINDER)" || { \
		echo "ERROR: shell script discovery helper is not executable: $(SHELL_FILE_FINDER)" >&2; \
		echo "Run: chmod +x $(SHELL_FILE_FINDER)" >&2; \
		exit 2; \
	}
	@command -v file >/dev/null 2>&1 || { \
		echo "ERROR: required command not found: file" >&2; \
		exit 2; \
	}
	@test -n "$(strip $(SHELL_FILES))" || { \
		echo "ERROR: no shell scripts were discovered." >&2; \
		echo "Search directory: $(SHELL_SOURCE_DIR)" >&2; \
		echo "Discovery helper: $(SHELL_FILE_FINDER)" >&2; \
		echo "Set SHELL_SOURCE_DIR or provide SHELL_FILES explicitly." >&2; \
		exit 2; \
	}
endef

status-bash:
	@printf '\nBash:\n'
	@printf '  %-22s %s\n' "Source directory:" "$(SHELL_SOURCE_DIR)"
	@if [ -x "$(SHELL_FILE_FINDER)" ]; then \
		printf '  %-22s %s\n' "Discovery helper:" "[OK] $(SHELL_FILE_FINDER)"; \
	else \
		printf '  %-22s %s\n' "Discovery helper:" "[MISSING] $(SHELL_FILE_FINDER)"; \
	fi; \
	set -- $(SHELL_FILES); \
	printf '  %-22s %s\n' "Scripts discovered:" "$$#"; \
	printf '  %-22s %s\n' "ShellCheck dialect:" "$(SHELLCHECK_SHELL)"; \
	if command -v "$(BASH)" >/dev/null 2>&1; then \
		printf '  %-22s %s\n' "Bash:" "[OK] $$(command -v "$(BASH)")"; \
	else \
		printf '  %-22s %s\n' "Bash:" "[MISSING] $(BASH)"; \
	fi; \
	if command -v "$(SHELLCHECK)" >/dev/null 2>&1; then \
		printf '  %-22s %s\n' "ShellCheck:" "[OK] $$(command -v "$(SHELLCHECK)")"; \
	else \
		printf '  %-22s %s\n' "ShellCheck:" "[MISSING] $(SHELLCHECK)"; \
	fi

bash-doctor:
	@failures=0; \
	printf '\nBash doctor:\n'; \
	printf '  %-22s %s\n' "Source directory:" "$(SHELL_SOURCE_DIR)"; \
	if [ -x "$(SHELL_FILE_FINDER)" ]; then \
		printf '  %-22s %s\n' "Discovery helper:" "[OK] $(SHELL_FILE_FINDER)"; \
	else \
		printf '  %-22s %s\n' "Discovery helper:" "[MISSING] $(SHELL_FILE_FINDER)"; \
		failures=$$((failures + 1)); \
	fi; \
	if command -v file >/dev/null 2>&1; then \
		printf '  %-22s %s\n' "file command:" "[OK] $$(command -v file)"; \
	else \
		printf '  %-22s %s\n' "file command:" "[MISSING] file"; \
		failures=$$((failures + 1)); \
	fi; \
	if command -v "$(BASH)" >/dev/null 2>&1; then \
		printf '  %-22s %s\n' "Bash:" "[OK] $$(command -v "$(BASH)")"; \
	else \
		printf '  %-22s %s\n' "Bash:" "[MISSING] $(BASH)"; \
		failures=$$((failures + 1)); \
	fi; \
	if command -v "$(SHELLCHECK)" >/dev/null 2>&1; then \
		printf '  %-22s %s\n' "ShellCheck:" "[OK] $$(command -v "$(SHELLCHECK)")"; \
	else \
		printf '  %-22s %s\n' "ShellCheck:" "[MISSING] $(SHELLCHECK)"; \
		failures=$$((failures + 1)); \
	fi; \
	set -- $(SHELL_FILES); \
	if [ "$$#" -gt 0 ]; then \
		printf '  %-22s %s\n' "Scripts discovered:" "[OK] $$#"; \
	else \
		printf '  %-22s %s\n' "Scripts discovered:" "[WARN] 0 — set SHELL_SOURCE_DIR or SHELL_FILES"; \
	fi; \
	if [ "$$failures" -ne 0 ]; then \
		echo "Bash doctor found $$failures issue(s)." >&2; \
		exit 1; \
	fi; \
	echo "Bash doctor: OK"

bash-list-scripts:
	@$(require_shell_files)
	@printf '%s\n' "Discovered Bash scripts:"; \
	for script in $(SHELL_FILES); do \
		printf '  %s\n' "$$script"; \
	done

bash-syntax:
	@$(require_shell_files)
	@command -v "$(BASH)" >/dev/null 2>&1 || { \
		echo "ERROR: Bash command not found: $(BASH)" >&2; \
		exit 2; \
	}
	@echo "Validating Bash syntax..."
	@failed=0; \
	for script in $(SHELL_FILES); do \
		if "$(BASH)" -n "$$script"; then \
			printf '  PASS  %s\n' "$$script"; \
		else \
			printf '  FAIL  %s\n' "$$script"; \
			failed=$$((failed + 1)); \
		fi; \
	done; \
	if [ "$$failed" -ne 0 ]; then \
		echo "Bash syntax validation failed." >&2; \
		exit 1; \
	fi; \
	echo "Bash syntax validation passed."

bash-shellcheck:
	@$(require_shell_files)
	@command -v "$(SHELLCHECK)" >/dev/null 2>&1 || { \
		echo "ERROR: ShellCheck command not found: $(SHELLCHECK)" >&2; \
		exit 2; \
	}
	@"$(SHELLCHECK)" --shell="$(SHELLCHECK_SHELL)" $(SHELLCHECK_FLAGS) $(SHELL_FILES)

bash-lint: bash-shellcheck

bash-test: bash-syntax bash-shellcheck

bash-check: bash-test
