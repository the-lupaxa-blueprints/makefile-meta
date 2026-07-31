PROJECT_NAME ?= $(notdir $(CURDIR))
BUMP ?= bump-my-version
VERSION_FILE ?= .bumpversion.toml
PROJECT_VERSION := $(shell sed -n 's/^[[:space:]]*current_version[[:space:]]*=[[:space:]]*"\([^"]*\)"[[:space:]]*$$/\1/p' "$(VERSION_FILE)" 2>/dev/null | head -n 1)

# Defaults so top-level doctor works even with an older consumer wrapper.
MAKEFILES_DIR ?= .makefiles
MAKEFILES_MODE ?= consumer
MAKEFILES_REF ?= head
MAKEFILES_TRANSPORT ?= ssh
SKILLS ?=

.PHONY: \
	bump-dev \
	bump-final \
	bump-major \
	bump-minor \
	bump-rc \
	doctor \
	doctor-versioning \
	help-versioning \
	release \
	show-version-flow \
	status \
	version

# Status is always-on (printed before Versioning) so it appears even when the
# consumer wrapper's help text is outdated.
help-versioning:
	@echo "Status:"
	@echo "  status              Show project, version, Git, and enabled-skill status"
	@echo "  doctor              Run all doctors (lifecycle + versioning + enabled skills)"
	@echo
	@echo "Versioning:"
	@echo "  version             Show the current project version"
	@echo "  show-version-flow   Show the version stage and valid next steps"
	@echo "  bump-dev            Start or continue the next patch development cycle"
	@echo "  bump-minor          Start the next minor development cycle"
	@echo "  bump-major          Start the next major development cycle"
	@echo "  bump-rc             Start or continue the release candidate cycle"
	@echo "  release             Publish the current release candidate as stable"
	@echo "  bump-final          Alias of release"
	@echo "  doctor-versioning   Check versioning config and tools"
	@echo

# Top-level doctor lives in skills so `make doctor` works after init/update
# even if the project wrapper predates the doctor target.
# Always runs every section (versioning + each enabled skill); exits non-zero
# only after all sections have reported.
doctor:
	@set +e; \
	failures=0; \
	printf '%s\n' "$(or $(PROJECT_NAME),$(notdir $(CURDIR))) Doctor"; \
	printf '%s\n' "========================================"; \
	printf '\nLifecycle:\n'; \
	printf '  %-22s %s\n' "Mode:" "$(MAKEFILES_MODE)"; \
	printf '  %-22s %s\n' "Transport:" "$(MAKEFILES_TRANSPORT)"; \
	printf '  %-22s %s\n' "Repository URL:" "$(MAKEFILES_REPO)"; \
	printf '  %-22s %s\n' "Ref:" "$(MAKEFILES_REF)"; \
	if command -v git >/dev/null 2>&1; then \
		printf '  %-22s %s\n' "git:" "[OK] $$(command -v git)"; \
	else \
		printf '  %-22s %s\n' "git:" "[MISSING] git"; \
		failures=$$((failures + 1)); \
	fi; \
	if [ "$(MAKEFILES_MODE)" = "library" ]; then \
		if [ -f "$(MAKEFILES_DIR)/skills/versioning.mk" ]; then \
			printf '  %-22s %s\n' "Skills tree:" "[OK] $(MAKEFILES_DIR)/skills"; \
		else \
			printf '  %-22s %s\n' "Skills tree:" "[MISSING] $(MAKEFILES_DIR)/skills/versioning.mk"; \
			failures=$$((failures + 1)); \
		fi; \
	elif [ -d "$(MAKEFILES_DIR)/.git" ]; then \
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

define require_version
	@test -f "$(VERSION_FILE)" || { \
		echo "ERROR: version file not found: $(VERSION_FILE)" >&2; \
		exit 2; \
	}
	@test -n "$(PROJECT_VERSION)" || { \
		echo "ERROR: current_version was not found in $(VERSION_FILE)" >&2; \
		exit 2; \
	}
endef

doctor-versioning:
	@failures=0; \
	printf '\nVersioning doctor:\n'; \
	if [ -f "$(VERSION_FILE)" ]; then \
		printf '  %-22s %s\n' "Configuration:" "[OK] $(VERSION_FILE)"; \
	else \
		printf '  %-22s %s\n' "Configuration:" "[MISSING] $(VERSION_FILE)"; \
		failures=$$((failures + 1)); \
	fi; \
	if [ -n "$(PROJECT_VERSION)" ]; then \
		printf '  %-22s %s\n' "current_version:" "[OK] $(PROJECT_VERSION)"; \
	else \
		printf '  %-22s %s\n' "current_version:" "[MISSING]"; \
		failures=$$((failures + 1)); \
	fi; \
	if command -v "$(BUMP)" >/dev/null 2>&1; then \
		printf '  %-22s %s\n' "bump-my-version:" "[OK] $$(command -v "$(BUMP)")"; \
	else \
		printf '  %-22s %s\n' "bump-my-version:" "[MISSING] $(BUMP)"; \
		failures=$$((failures + 1)); \
	fi; \
	if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
		printf '  %-22s %s\n' "Git work tree:" "[OK]"; \
	else \
		printf '  %-22s %s\n' "Git work tree:" "[MISSING]"; \
		failures=$$((failures + 1)); \
	fi; \
	if [ "$$failures" -ne 0 ]; then \
		echo "Versioning doctor found $$failures issue(s)." >&2; \
		exit 1; \
	fi; \
	echo "Versioning doctor: OK"

STATUS_FRAGMENTS ?=

status:
	@current="$(PROJECT_VERSION)"; \
	printf '%s\n' "$(PROJECT_NAME) Repository Status"; \
	printf '%s\n' "========================================"; \
	printf '\nProject:\n'; \
	printf '  %-22s %s\n' "Name:" "$(PROJECT_NAME)"; \
	printf '  %-22s %s\n' "Directory:" "$(CURDIR)"; \
	printf '\nVersioning:\n'; \
	if [ -f "$(VERSION_FILE)" ]; then \
		printf '  %-22s %s\n' "Configuration:" "[OK] $(VERSION_FILE)"; \
	else \
		printf '  %-22s %s\n' "Configuration:" "[MISSING] $(VERSION_FILE)"; \
	fi; \
	if [ -n "$$current" ]; then \
		base="$${current%%-*}"; \
		major="$${base%%.*}"; \
		minor_patch="$${base#*.}"; \
		minor="$${minor_patch%%.*}"; \
		patch="$${minor_patch##*.}"; \
		case "$$current" in \
			*-dev[0-9]*) \
				stage="Development pre-release"; \
				dev_number="$${current##*-dev}"; \
				next_dev="$$base-dev$$((dev_number + 1))"; \
				next_rc="$$base-rc1"; \
				printf '  %-22s %s\n' "Current version:" "$$current"; \
				printf '  %-22s %s\n' "Stage:" "$$stage"; \
				printf '  %-22s %s\n' "Next development:" "$$next_dev"; \
				printf '  %-22s %s\n' "Next release candidate:" "$$next_rc"; \
				printf '  %-22s %s\n' "Next stable release:" "$$base" ;; \
			*-rc[0-9]*) \
				stage="Release candidate"; \
				rc_number="$${current##*-rc}"; \
				next_rc="$$base-rc$$((rc_number + 1))"; \
				printf '  %-22s %s\n' "Current version:" "$$current"; \
				printf '  %-22s %s\n' "Stage:" "$$stage"; \
				printf '  %-22s %s\n' "Next release candidate:" "$$next_rc"; \
				printf '  %-22s %s\n' "Next stable release:" "$$base" ;; \
			*) \
				stage="Final / stable release"; \
				next_patch="$$major.$$minor.$$((patch + 1))-dev1"; \
				next_minor="$$major.$$((minor + 1)).0-dev1"; \
				next_major="$$((major + 1)).0.0-dev1"; \
				printf '  %-22s %s\n' "Current version:" "$$current"; \
				printf '  %-22s %s\n' "Stage:" "$$stage"; \
				printf '  %-22s %s\n' "Next patch cycle:" "$$next_patch"; \
				printf '  %-22s %s\n' "Next minor cycle:" "$$next_minor"; \
				printf '  %-22s %s\n' "Next major cycle:" "$$next_major" ;; \
		esac; \
	else \
		printf '  %-22s %s\n' "Current version:" "[UNAVAILABLE]"; \
		printf '  %-22s %s\n' "Stage:" "[UNAVAILABLE]"; \
	fi; \
	if command -v "$(BUMP)" >/dev/null 2>&1; then \
		bump_path="$$(command -v "$(BUMP)")"; \
		printf '  %-22s %s\n' "bump-my-version:" "[OK] $$bump_path"; \
	else \
		printf '  %-22s %s\n' "bump-my-version:" "[MISSING] $(BUMP)"; \
	fi; \
	printf '\nGit:\n'; \
	if command -v git >/dev/null 2>&1; then \
		printf '  %-22s %s\n' "Git command:" "[OK] $$(command -v git)"; \
		if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
			branch="$$(git branch --show-current 2>/dev/null)"; \
			if [ -z "$$branch" ]; then branch="Detached HEAD"; fi; \
			if [ -z "$$(git status --porcelain 2>/dev/null)" ]; then working_tree="Clean"; else working_tree="Changes present"; fi; \
			printf '  %-22s %s\n' "Repository:" "[OK] Git work tree"; \
			printf '  %-22s %s\n' "Branch:" "$$branch"; \
			printf '  %-22s %s\n' "Working tree:" "$$working_tree"; \
		else \
			printf '  %-22s %s\n' "Repository:" "[UNAVAILABLE] Not a Git work tree"; \
			printf '  %-22s %s\n' "Branch:" "[UNAVAILABLE]"; \
			printf '  %-22s %s\n' "Working tree:" "[UNAVAILABLE]"; \
		fi; \
	else \
		printf '  %-22s %s\n' "Git command:" "[MISSING] git"; \
		printf '  %-22s %s\n' "Repository:" "[UNAVAILABLE]"; \
		printf '  %-22s %s\n' "Branch:" "[UNAVAILABLE]"; \
		printf '  %-22s %s\n' "Working tree:" "[UNAVAILABLE]"; \
	fi
	@for t in $(STATUS_FRAGMENTS); do \
		$(MAKE) --no-print-directory $$t; \
	done

version:
	@$(require_version)
	@echo "$(PROJECT_NAME) version: $(PROJECT_VERSION)"

bump-dev:
	@$(require_version)
	@current="$(PROJECT_VERSION)"; \
	case "$$current" in \
		*-rc[0-9]*) echo "ERROR: bump-dev cannot be used on a release candidate ($$current)." >&2; exit 2 ;; \
		*-dev[0-9]*) base="$${current%-dev*}"; n="$${current##*-dev}"; new_n=$$((n + 1)); new_version="$$base-dev$$new_n" ;; \
		*) base="$${current%%-*}"; major="$${base%%.*}"; minor_patch="$${base#*.}"; minor="$${minor_patch%%.*}"; patch="$${minor_patch##*.}"; new_patch=$$((patch + 1)); new_version="$$major.$$minor.$$new_patch-dev1" ;; \
	esac; \
	echo "Bump development version: $$current -> $$new_version"; \
	$(BUMP) bump version --new-version "$$new_version"

bump-minor:
	@$(require_version)
	@current="$(PROJECT_VERSION)"; \
	case "$$current" in *-dev[0-9]*|*-rc[0-9]*) echo "ERROR: bump-minor can only be used from a stable version ($$current)." >&2; exit 2 ;; esac; \
	base="$${current%%-*}"; major="$${base%%.*}"; minor_patch="$${base#*.}"; minor="$${minor_patch%%.*}"; new_minor=$$((minor + 1)); new_version="$$major.$$new_minor.0-dev1"; \
	echo "Start minor development cycle: $$current -> $$new_version"; \
	$(BUMP) bump version --new-version "$$new_version"

bump-major:
	@$(require_version)
	@current="$(PROJECT_VERSION)"; \
	case "$$current" in *-dev[0-9]*|*-rc[0-9]*) echo "ERROR: bump-major can only be used from a stable version ($$current)." >&2; exit 2 ;; esac; \
	base="$${current%%-*}"; major="$${base%%.*}"; new_major=$$((major + 1)); new_version="$$new_major.0.0-dev1"; \
	echo "Start major development cycle: $$current -> $$new_version"; \
	$(BUMP) bump version --new-version "$$new_version"

bump-rc:
	@$(require_version)
	@current="$(PROJECT_VERSION)"; \
	case "$$current" in \
		*-dev[0-9]*) base="$${current%-dev*}"; new_version="$$base-rc1" ;; \
		*-rc[0-9]*) base="$${current%-rc*}"; n="$${current##*-rc}"; new_n=$$((n + 1)); new_version="$$base-rc$$new_n" ;; \
		*) echo "ERROR: bump-rc expects a -devN or -rcN version (current: $$current)." >&2; exit 2 ;; \
	esac; \
	echo "Bump release candidate: $$current -> $$new_version"; \
	$(BUMP) bump version --new-version "$$new_version"

release bump-final:
	@$(require_version)
	@current="$(PROJECT_VERSION)"; \
	case "$$current" in *-rc[0-9]*) new_version="$${current%%-*}" ;; *) echo "ERROR: release expects a -rcN version (current: $$current)." >&2; exit 2 ;; esac; \
	echo "Release version: $$current -> $$new_version"; \
	$(BUMP) bump version --new-version "$$new_version"

show-version-flow:
	@$(require_version)
	@current="$(PROJECT_VERSION)"; \
	base="$${current%%-*}"; major="$${base%%.*}"; minor_patch="$${base#*.}"; minor="$${minor_patch%%.*}"; patch="$${minor_patch##*.}"; \
	next_patch="$$major.$$minor.$$((patch + 1))"; next_minor="$$major.$$((minor + 1)).0"; next_major="$$((major + 1)).0.0"; \
	echo "Current version: $$current"; echo; \
	if echo "$$current" | grep -Eq -- '-dev[0-9]+$$'; then \
		dev_number="$${current##*-dev}"; next_dev="$$base-dev$$((dev_number + 1))"; next_rc="$$base-rc1"; \
		echo "Stage: development pre-release"; echo; echo "Suggested next steps:"; echo; \
		printf "  %-16s %-44s (%s)\n" "make bump-dev" "Continue the development cycle" "$$next_dev"; \
		printf "  %-16s %-44s (%s)\n" "make bump-rc" "Promote to the first release candidate" "$$next_rc"; \
	elif echo "$$current" | grep -Eq -- '-rc[0-9]+$$'; then \
		rc_number="$${current##*-rc}"; next_rc="$$base-rc$$((rc_number + 1))"; \
		echo "Stage: release candidate"; echo; echo "Suggested next steps:"; echo; \
		printf "  %-16s %-44s (%s)\n" "make bump-rc" "Continue the release candidate cycle" "$$next_rc"; \
		printf "  %-16s %-44s (%s)\n" "make release" "Publish the stable release" "$$base"; \
	else \
		next_dev="$$next_patch-dev1"; next_minor_dev="$$next_minor-dev1"; next_major_dev="$$next_major-dev1"; \
		echo "Stage: final / stable release"; echo; echo "Suggested next steps:"; echo; \
		printf "  %-16s %-44s (%s)\n" "make bump-dev" "Start the next patch development cycle" "$$next_dev"; \
		printf "  %-16s %-44s (%s)\n" "make bump-minor" "Start the next minor development cycle" "$$next_minor_dev"; \
		printf "  %-16s %-44s (%s)\n" "make bump-major" "Start the next major development cycle" "$$next_major_dev"; \
	fi
