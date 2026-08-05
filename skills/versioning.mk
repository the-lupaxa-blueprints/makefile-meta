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

.PHONY: bump-patch bump-minor bump-major bump-patch-dev bump-minor-dev bump-major-dev bump-dev \
	bump-patch-rc bump-minor-rc bump-major-rc bump-rc release bump-final draft-tag \
	doctor doctor-versioning help-versioning show-version-flow status version

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
	@echo "  bump-patch          Bump to the next stable patch (X.Y.Z+1)"
	@echo "  bump-minor          Bump to the next stable minor (X.Y+1.0)"
	@echo "  bump-major          Bump to the next stable major (X+1.0.0)"
	@echo "  bump-dev            Alias of bump-patch-dev"
	@echo "  bump-patch-dev      Start/continue patch -devN"
	@echo "  bump-minor-dev      Start/continue minor -devN"
	@echo "  bump-major-dev      Start/continue major -devN"
	@echo "  bump-rc             Alias of bump-patch-rc"
	@echo "  bump-patch-rc       Start patch -rc1 from stable/dev, or bump -rcN"
	@echo "  bump-minor-rc       Start minor -rc1 from stable/dev, or bump -rcN"
	@echo "  bump-major-rc       Start major -rc1 from stable/dev, or bump -rcN"
	@echo "  release             Publish -rcN as stable"
	@echo "  bump-final          Alias of release"
	@echo "  doctor-versioning   Check versioning config and tools"
	@echo
	@echo "GitHub packaging (does not change current_version):"
	@echo "  draft-tag           Create next vX.Y.Z-draftN tag at HEAD for draft releases"
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

# flavour: patch|minor|major
# mode: stable|dev|rc
define run_version_bump
	@$(require_version)
	@flavour="$(1)"; mode="$(2)"; current="$(PROJECT_VERSION)"; \
	base="$${current%%-*}"; \
	maj="$${base%%.*}"; rest="$${base#*.}"; min="$${rest%%.*}"; pat="$${rest#*.}"; \
	stage=stable; n=0; \
	case "$$current" in \
	  *-dev[0-9]*) stage=dev; n="$${current##*-dev}" ;; \
	  *-rc[0-9]*) stage=rc; n="$${current##*-rc}" ;; \
	esac; \
	channel_ok() { \
	  case "$$1" in \
	    patch) [ "$$pat" -ge 1 ] ;; \
	    minor) [ "$$pat" -eq 0 ] && [ "$$min" -ge 1 ] ;; \
	    major) [ "$$pat" -eq 0 ] && [ "$$min" -eq 0 ] && [ "$$maj" -ge 1 ] ;; \
	    *) return 1 ;; \
	  esac; \
	}; \
	open_channel() { \
	  if [ "$$pat" -ge 1 ]; then echo patch; \
	  elif [ "$$min" -ge 1 ]; then echo minor; \
	  elif [ "$$maj" -ge 1 ]; then echo major; \
	  else echo ""; fi; \
	}; \
	hint_target() { \
	  case "$$1-$$2" in \
	    dev-patch) echo "bump-dev (alias: bump-patch-dev)" ;; \
	    dev-minor) echo "bump-minor-dev" ;; \
	    dev-major) echo "bump-major-dev" ;; \
	    rc-patch) echo "bump-rc (alias: bump-patch-rc)" ;; \
	    rc-minor) echo "bump-minor-rc" ;; \
	    rc-major) echo "bump-major-rc" ;; \
	    *) echo "" ;; \
	  esac; \
	}; \
	next_base() { \
	  case "$$1" in \
	    patch) echo "$$maj.$$min.$$((pat + 1))" ;; \
	    minor) echo "$$maj.$$((min + 1)).0" ;; \
	    major) echo "$$((maj + 1)).0.0" ;; \
	  esac; \
	}; \
	new_version=""; \
	case "$$mode" in \
	  stable) \
	    if [ "$$stage" != stable ]; then \
	      ofl="$$(open_channel)"; \
	      if [ "$$stage" = dev ]; then hint="$$(hint_target dev "$$ofl")"; \
	      else hint="$$(hint_target rc "$$ofl")"; fi; \
	      if [ -n "$$hint" ]; then \
	        echo "ERROR: bump-$$flavour requires a stable version (current: $$current). Hint: make $$hint" >&2; \
	      else \
	        echo "ERROR: bump-$$flavour requires a stable version (current: $$current)." >&2; \
	      fi; \
	      exit 2; \
	    fi; \
	    new_version="$$(next_base "$$flavour")" ;; \
	  dev) \
	    if [ "$$stage" = rc ]; then \
	      ofl="$$(open_channel)"; hint="$$(hint_target rc "$$ofl")"; \
	      if [ -n "$$hint" ]; then \
	        echo "ERROR: bump-$$flavour-dev cannot run on a release candidate ($$current). Hint: make $$hint or make release" >&2; \
	      else \
	        echo "ERROR: bump-$$flavour-dev cannot run on a release candidate ($$current). Hint: make release" >&2; \
	      fi; \
	      exit 2; \
	    fi; \
	    if [ "$$stage" = stable ]; then \
	      nb="$$(next_base "$$flavour")"; new_version="$$nb-dev1"; \
	    else \
	      if ! channel_ok "$$flavour"; then \
	        ofl="$$(open_channel)"; hint="$$(hint_target dev "$$ofl")"; \
	        if [ -n "$$hint" ]; then \
	          echo "ERROR: bump-$$flavour-dev does not match open channel for $$current. Hint: make $$hint" >&2; \
	        else \
	          echo "ERROR: bump-$$flavour-dev does not match open channel for $$current." >&2; \
	        fi; \
	        exit 2; \
	      fi; \
	      new_version="$$base-dev$$((n + 1))"; \
	    fi ;; \
	  rc) \
	    if [ "$$stage" = stable ]; then \
	      nb="$$(next_base "$$flavour")"; new_version="$$nb-rc1"; \
	    else \
	      if ! channel_ok "$$flavour"; then \
	        ofl="$$(open_channel)"; hint="$$(hint_target rc "$$ofl")"; \
	        if [ -n "$$hint" ]; then \
	          echo "ERROR: bump-$$flavour-rc does not match open channel for $$current. Hint: make $$hint" >&2; \
	        else \
	          echo "ERROR: bump-$$flavour-rc does not match open channel for $$current." >&2; \
	        fi; \
	        exit 2; \
	      fi; \
	      if [ "$$stage" = dev ]; then new_version="$$base-rc1"; \
	      else new_version="$$base-rc$$((n + 1))"; fi; \
	    fi ;; \
	esac; \
	echo "Bump $$mode ($$flavour): $$current -> $$new_version"; \
	$(BUMP) bump version --new-version "$$new_version"
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
		if [ "$$patch" -ge 1 ]; then flavour=patch; \
		elif [ "$$minor" -ge 1 ]; then flavour=minor; \
		elif [ "$$major" -ge 1 ]; then flavour=major; \
		else flavour=""; fi; \
		case "$$current" in \
			*-dev[0-9]*) \
				stage="Development pre-release"; \
				dev_number="$${current##*-dev}"; \
				next_dev="$$base-dev$$((dev_number + 1))"; \
				next_rc="$$base-rc1"; \
				printf '  %-22s %s\n' "Current version:" "$$current"; \
				printf '  %-22s %s\n' "Stage:" "$$stage"; \
				if [ -n "$$flavour" ]; then \
					if [ "$$flavour" = patch ]; then dev_target="bump-dev"; rc_target="bump-rc"; \
					else dev_target="bump-$$flavour-dev"; rc_target="bump-$$flavour-rc"; fi; \
					printf '  %-22s %s\n' "Next development:" "make $$dev_target ($$next_dev)"; \
					printf '  %-22s %s\n' "Next release candidate:" "make $$rc_target ($$next_rc)"; \
					printf '  %-22s %s\n' "Next stable release:" "$$base" ; \
				else \
					printf '  %-22s %s\n' "Next step:" "No matching channel continues this pre-release ($$base)" ; \
				fi ;; \
			*-rc[0-9]*) \
				stage="Release candidate"; \
				rc_number="$${current##*-rc}"; \
				next_rc="$$base-rc$$((rc_number + 1))"; \
				printf '  %-22s %s\n' "Current version:" "$$current"; \
				printf '  %-22s %s\n' "Stage:" "$$stage"; \
				if [ -n "$$flavour" ]; then \
					if [ "$$flavour" = patch ]; then rc_target="bump-rc"; else rc_target="bump-$$flavour-rc"; fi; \
					printf '  %-22s %s\n' "Next release candidate:" "make $$rc_target ($$next_rc)"; \
				else \
					printf '  %-22s %s\n' "Next release candidate:" "No matching channel continues this pre-release ($$base)"; \
				fi; \
				printf '  %-22s %s\n' "Next stable release:" "make release ($$base)" ;; \
			*) \
				stage="Final / stable release"; \
				next_patch="$$major.$$minor.$$((patch + 1))"; \
				next_minor="$$major.$$((minor + 1)).0"; \
				next_major="$$((major + 1)).0.0"; \
				next_patch_dev="$$next_patch-dev1"; \
				next_minor_dev="$$next_minor-dev1"; \
				next_major_dev="$$next_major-dev1"; \
				next_patch_rc="$$next_patch-rc1"; \
				next_minor_rc="$$next_minor-rc1"; \
				next_major_rc="$$next_major-rc1"; \
				printf '  %-22s %s\n' "Current version:" "$$current"; \
				printf '  %-22s %s\n' "Stage:" "$$stage"; \
				printf '  %-22s %s\n' "Next patch (stable):" "$$next_patch"; \
				printf '  %-22s %s\n' "Next minor (stable):" "$$next_minor"; \
				printf '  %-22s %s\n' "Next major (stable):" "$$next_major"; \
				printf '  %-22s %s\n' "Next patch (dev):" "$$next_patch_dev"; \
				printf '  %-22s %s\n' "Next minor (dev):" "$$next_minor_dev"; \
				printf '  %-22s %s\n' "Next major (dev):" "$$next_major_dev"; \
				printf '  %-22s %s\n' "Next patch (rc):" "$$next_patch_rc"; \
				printf '  %-22s %s\n' "Next minor (rc):" "$$next_minor_rc"; \
				printf '  %-22s %s\n' "Next major (rc):" "$$next_major_rc" ;; \
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

bump-patch:
	$(call run_version_bump,patch,stable)

bump-minor:
	$(call run_version_bump,minor,stable)

bump-major:
	$(call run_version_bump,major,stable)

bump-patch-dev bump-dev:
	$(call run_version_bump,patch,dev)

bump-minor-dev:
	$(call run_version_bump,minor,dev)

bump-major-dev:
	$(call run_version_bump,major,dev)

bump-patch-rc bump-rc:
	$(call run_version_bump,patch,rc)

bump-minor-rc:
	$(call run_version_bump,minor,rc)

bump-major-rc:
	$(call run_version_bump,major,rc)

release bump-final:
	@$(require_version)
	@current="$(PROJECT_VERSION)"; \
	case "$$current" in *-rc[0-9]*) new_version="$${current%%-*}" ;; *) echo "ERROR: release expects a -rcN version (current: $$current)." >&2; exit 2 ;; esac; \
	echo "Release version: $$current -> $$new_version"; \
	$(BUMP) bump version --new-version "$$new_version"

# Create vX.Y.Z-draftN at HEAD for generate-draft-release.yml. Does not modify
# .bumpversion.toml. Base is stripped of -devN/-rcN; override with DRAFT_BASE=X.Y.Z.
draft-tag:
	@$(require_version)
	@command -v git >/dev/null 2>&1 || { echo "ERROR: git is required for draft-tag" >&2; exit 2; }; \
	git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { \
		echo "ERROR: draft-tag must run inside a Git work tree" >&2; exit 2; \
	}; \
	current="$(PROJECT_VERSION)"; \
	if [ -n "$(DRAFT_BASE)" ]; then base="$(DRAFT_BASE)"; else base="$${current%%-*}"; fi; \
	echo "$$base" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' || { \
		echo "ERROR: draft base must be X.Y.Z (got: $$base)" >&2; exit 2; \
	}; \
	n=1; \
	while git rev-parse -q --verify "refs/tags/v$$base-draft$$n" >/dev/null 2>&1; do \
		n=$$((n + 1)); \
	done; \
	tag="v$$base-draft$$n"; \
	git tag -a "$$tag" -m "Draft release $$base-draft$$n"; \
	echo "Created annotated tag $$tag at $$(git rev-parse --short HEAD)"; \
	echo "Push with: git push origin $$tag"; \
	echo "(.bumpversion.toml unchanged: $$current)"

show-version-flow:
	@$(require_version)
	@current="$(PROJECT_VERSION)"; \
	base="$${current%%-*}"; major="$${base%%.*}"; minor_patch="$${base#*.}"; minor="$${minor_patch%%.*}"; patch="$${minor_patch##*.}"; \
	next_patch="$$major.$$minor.$$((patch + 1))"; next_minor="$$major.$$((minor + 1)).0"; next_major="$$((major + 1)).0.0"; \
	if [ "$$patch" -ge 1 ]; then flavour=patch; \
	elif [ "$$minor" -ge 1 ]; then flavour=minor; \
	elif [ "$$major" -ge 1 ]; then flavour=major; \
	else flavour=""; fi; \
	if [ "$$flavour" = patch ]; then dev_target="bump-dev"; rc_target="bump-rc"; \
	elif [ -n "$$flavour" ]; then dev_target="bump-$$flavour-dev"; rc_target="bump-$$flavour-rc"; \
	else dev_target=""; rc_target=""; fi; \
	echo "Current version: $$current"; echo; \
	if echo "$$current" | grep -Eq -- '-dev[0-9]+$$'; then \
		dev_number="$${current##*-dev}"; next_dev="$$base-dev$$((dev_number + 1))"; next_rc="$$base-rc1"; \
		echo "Stage: development pre-release"; echo; \
		if [ -n "$$flavour" ]; then \
			echo "Suggested next steps:"; echo; \
			printf "  %-20s %-44s (%s)\n" "make $$dev_target" "Continue the development cycle" "$$next_dev"; \
			printf "  %-20s %-44s (%s)\n" "make $$rc_target" "Promote to the first release candidate" "$$next_rc"; \
		else \
			echo "No matching channel continues this pre-release ($$base): patch/minor/major bumps require the corresponding X.Y.Z part to be >=1."; \
		fi; \
	elif echo "$$current" | grep -Eq -- '-rc[0-9]+$$'; then \
		rc_number="$${current##*-rc}"; next_rc="$$base-rc$$((rc_number + 1))"; \
		echo "Stage: release candidate"; echo; echo "Suggested next steps:"; echo; \
		if [ -n "$$flavour" ]; then \
			printf "  %-20s %-44s (%s)\n" "make $$rc_target" "Continue the release candidate cycle" "$$next_rc"; \
		else \
			echo "  (No matching channel continues this pre-release ($$base); further -rc bumps are unavailable.)"; \
		fi; \
		printf "  %-20s %-44s (%s)\n" "make release" "Publish the stable release" "$$base"; \
	else \
		next_patch_dev="$$next_patch-dev1"; next_minor_dev="$$next_minor-dev1"; next_major_dev="$$next_major-dev1"; \
		next_patch_rc="$$next_patch-rc1"; next_minor_rc="$$next_minor-rc1"; next_major_rc="$$next_major-rc1"; \
		echo "Stage: final / stable release"; echo; echo "Suggested next steps:"; echo; \
		printf "  %-20s %-44s (%s)\n" "make bump-patch" "Bump to the next stable patch" "$$next_patch"; \
		printf "  %-20s %-44s (%s)\n" "make bump-minor" "Bump to the next stable minor" "$$next_minor"; \
		printf "  %-20s %-44s (%s)\n" "make bump-major" "Bump to the next stable major" "$$next_major"; \
		printf "  %-20s %-44s (%s)\n" "make bump-dev" "Start the next patch development cycle" "$$next_patch_dev"; \
		printf "  %-20s %-44s (%s)\n" "make bump-minor-dev" "Start the next minor development cycle" "$$next_minor_dev"; \
		printf "  %-20s %-44s (%s)\n" "make bump-major-dev" "Start the next major development cycle" "$$next_major_dev"; \
		printf "  %-20s %-44s (%s)\n" "make bump-rc" "Start the next patch release candidate" "$$next_patch_rc"; \
		printf "  %-20s %-44s (%s)\n" "make bump-minor-rc" "Start the next minor release candidate" "$$next_minor_rc"; \
		printf "  %-20s %-44s (%s)\n" "make bump-major-rc" "Start the next major release candidate" "$$next_major_rc"; \
	fi
