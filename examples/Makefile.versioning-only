# Lupaxa makefile-skills project wrapper
# Copy this file to your project root as Makefile.

SKILLS         ?=
MAKEFILES_DIR  ?= .makefiles
MAKEFILES_REF  ?= head

# Transport: ssh | https | http
MAKEFILES_TRANSPORT ?= ssh
MAKEFILES_REPO_SSH  ?= git@github.com:the-lupaxa-blueprints/makefile-meta.git
MAKEFILES_REPO_HTTP ?= https://github.com/the-lupaxa-blueprints/makefile-meta.git

ifeq ($(MAKEFILES_TRANSPORT),ssh)
MAKEFILES_REPO ?= $(MAKEFILES_REPO_SSH)
else ifneq ($(filter $(MAKEFILES_TRANSPORT),https http),)
MAKEFILES_REPO ?= $(MAKEFILES_REPO_HTTP)
else
$(error MAKEFILES_TRANSPORT must be ssh, https, or http (got '$(MAKEFILES_TRANSPORT)'))
endif

.DEFAULT_GOAL := help

.PHONY: init install update help doctor version bump-dev bump-minor bump-major bump-rc release bump-final show-version-flow status

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
	if ! git clone "$(MAKEFILES_REPO)" "$(MAKEFILES_DIR)" || ! $(MAKE) --no-print-directory _makefiles-checkout; then \
		echo "==> Removing incomplete $(MAKEFILES_DIR) so 'make init' can be retried" >&2; \
		rm -rf "$(MAKEFILES_DIR)"; \
		exit 2; \
	fi

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
	if [ ! -f "$(MAKEFILES_DIR)/skills/versioning.mk" ]; then \
		short_sha="$$(git -C "$(MAKEFILES_DIR)" rev-parse --short HEAD 2>/dev/null || echo unknown)"; \
		echo "ERROR: $(MAKEFILES_DIR)/skills/versioning.mk not found after checking out MAKEFILES_REF=$(MAKEFILES_REF) (commit $$short_sha)." >&2; \
		echo "This ref does not look like a valid makefile-skills checkout." >&2; \
		exit 2; \
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
	@echo "  status              Show project, version, Git, and enabled-skill status"
	@echo "  doctor              Run all doctors (lifecycle + versioning + enabled skills)"
	@echo "  transport           $(MAKEFILES_TRANSPORT) -> $(MAKEFILES_REPO)"
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

# Diagnose clone, versioning, and each enabled skill. Exits non-zero on failures.
doctor:
	@set +e; \
	failures=0; \
	printf '%s\n' "$(or $(PROJECT_NAME),$(notdir $(CURDIR))) Doctor"; \
	printf '%s\n' "========================================"; \
	printf '\nLifecycle:\n'; \
	printf '  %-22s %s\n' "Transport:" "$(MAKEFILES_TRANSPORT)"; \
	printf '  %-22s %s\n' "Repository URL:" "$(MAKEFILES_REPO)"; \
	printf '  %-22s %s\n' "Ref:" "$(MAKEFILES_REF)"; \
	if command -v git >/dev/null 2>&1; then \
		printf '  %-22s %s\n' "git:" "[OK] $$(command -v git)"; \
	else \
		printf '  %-22s %s\n' "git:" "[MISSING] git"; \
		failures=$$((failures + 1)); \
	fi; \
	if [ -d "$(MAKEFILES_DIR)/.git" ]; then \
		printf '  %-22s %s\n' "Skills clone:" "[OK] $(MAKEFILES_DIR)"; \
	elif [ -e "$(MAKEFILES_DIR)" ]; then \
		printf '  %-22s %s\n' "Skills clone:" "[INVALID] $(MAKEFILES_DIR) exists but is not a git clone"; \
		failures=$$((failures + 1)); \
	else \
		printf '  %-22s %s\n' "Skills clone:" "[MISSING] $(MAKEFILES_DIR) — run: make init"; \
		failures=$$((failures + 1)); \
	fi; \
	if [ -f "$(MAKEFILES_DIR)/skills/versioning.mk" ]; then \
		printf '  %-22s %s\n' "versioning.mk:" "[OK]"; \
	else \
		printf '  %-22s %s\n' "versioning.mk:" "[MISSING]"; \
		failures=$$((failures + 1)); \
	fi; \
	for s in $(SKILLS); do \
		if [ -f "$(MAKEFILES_DIR)/skills/$$s.mk" ]; then \
			printf '  %-22s %s\n' "skill $$s:" "[OK]"; \
		else \
			printf '  %-22s %s\n' "skill $$s:" "[MISSING] $(MAKEFILES_DIR)/skills/$$s.mk"; \
			failures=$$((failures + 1)); \
		fi; \
	done; \
	if [ ! -f "$(MAKEFILES_DIR)/skills/versioning.mk" ]; then \
		echo; \
		echo "Doctor found $$failures issue(s). Run: make init" >&2; \
		exit 2; \
	fi; \
	$(MAKE) --no-print-directory doctor-versioning; \
	ver_rc=$$?; \
	if [ $$ver_rc -ne 0 ]; then failures=$$((failures + 1)); fi; \
	for s in $(SKILLS); do \
		$(MAKE) --no-print-directory $$s-doctor; \
		skill_rc=$$?; \
		if [ $$skill_rc -ne 0 ]; then failures=$$((failures + 1)); fi; \
	done; \
	echo; \
	if [ "$$failures" -ne 0 ]; then \
		echo "Doctor found $$failures failing section(s)." >&2; \
		exit 1; \
	fi; \
	echo "Doctor: all checks passed."

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
