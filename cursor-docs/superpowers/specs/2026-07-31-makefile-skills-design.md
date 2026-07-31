# Makefile Skills Library — Design

**Date:** 2026-07-31  
**Status:** Approved for planning  
**Repo:** `makefile-meta` (the-lupaxa-blueprints)

## Problem

This repository grew from a single versioning Makefile into four near-copies:

- `makefile-versioning` — bump / release flow
- `makefile-python` — Python toolchain + duplicated versioning
- `makefile-python-mkdocs` — Python + MkDocs + duplicated versioning
- `makefile-bash` — Bash/ShellCheck + duplicated versioning

Versioning logic is copied ~4×. Language and docs features are additive layers that should compose, not fork. Projects should not vendor large Makefiles; they need a thin wrapper and a shared, updatable skill set.

## Goals

- One shared skills library repo (this repo, restructured).
- Each project commits only a thin `Makefile` wrapper (and `.gitignore`).
- Skills live in a local clone that is **not** pushed to the project repo.
- `make init` / `make install` downloads the skills repo; `make update` refreshes it.
- **Versioning is always enabled.**
- Optional skills are **standalone** (no skill dependency graph).
- `make` / `make help` only presents versioning plus enabled skills.
- Language targets are **prefixed** to avoid clashes (`python-lint`, `bash-shellcheck`, …).
- Skills pin via `MAKEFILES_REF`: `head` (default) or a git tag.

## Non-goals (v1)

- Git submodules or git subtrees for skills delivery.
- Automatic skill dependency resolution (e.g. `mkdocs` implying `python`).
- Fake space-separated subcommands (`make python lint`).
- Supporting multiple language skills with overlapping unprefixed names in one project.

## Distribution approach

**Chosen:** gitignored plain clone (not submodule, not subtree).

| Mechanism | Decision |
|-----------|----------|
| Gitignored clone into `.makefiles/` | **Yes** — easiest; matches “don’t push skills” |
| Git submodule | No — pins and tracks content in the project |
| Git subtree | No — embeds skills history in the project |

## Architecture

```text
Project repo (committed)          On disk after init (gitignored)
─────────────────────────         ───────────────────────────────
Makefile                          .makefiles/   ← clone of makefile-meta
.gitignore  (.makefiles/)           skills/
                                      versioning.mk
                                      python.mk
                                      mkdocs.mk
                                      bash.mk
                                      bash/find-shell-files
```

**Composition rules:**

1. Wrapper always `-include`s `versioning.mk` when present.
2. Wrapper `-include`s each entry in `SKILLS` (optional list only).
3. Skills never `include` other skills.
4. Lifecycle targets (`init`, `install`, `update`, base `help`) live in the wrapper so they work before the clone exists.

## Wrapper behaviour

### Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `SKILLS` | empty | Optional skills only, e.g. `python mkdocs` or `bash` |
| `MAKEFILES_DIR` | `.makefiles` | Clone location |
| `MAKEFILES_REPO` | this library’s git URL | Source for init |
| `MAKEFILES_REF` | `head` | `head` → tip of `master`; otherwise a tag (e.g. `v1.0.0`) |

Versioning is **not** listed in `SKILLS`; it is always included.

### Lifecycle targets

- **`init` / `install`** (aliases): clone `MAKEFILES_REPO` into `MAKEFILES_DIR` if missing; check out resolved ref. Do not clobber an existing directory (direct user to `update` or remove).
- **`update`**: require existing git clone; fetch and check out resolved ref. Fail clearly on network/auth errors.

### Ref resolution

- `MAKEFILES_REF=head` → fetch + checkout `master` at latest tip.
- `MAKEFILES_REF=<tag>` → fetch tags + checkout that tag (detached HEAD is acceptable for tooling).

### Includes

Use `-include` so missing `.makefiles/` does not break `make init` / `make help`.

Help when the clone is missing still works and tells the user to run `make init`. Invoking a skill target before init fails with a clear guard message.

### Project overrides

Existing override style remains: set variables in the wrapper or on the CLI (`SRC_DIR`, `VERSION_FILE`, `PROJECT_NAME`, etc.). Bash discovery helper defaults to a path inside the clone (e.g. `$(MAKEFILES_DIR)/skills/bash/find-shell-files`).

## Skills

### Inventory (from current Makefiles)

| Skill | File | Always on? | Owns |
|-------|------|------------|------|
| versioning | `skills/versioning.mk` | Yes | `version`, `show-version-flow`, `bump-dev`, `bump-minor`, `bump-major`, `bump-rc`, `release` / `bump-final`, core status (project / version / git) |
| python | `skills/python.mk` | No | Prefixed install/quality/test/audit/packaging/clean for Python |
| mkdocs | `skills/mkdocs.mk` | No | Prefixed docs build/serve and `site/` cleanup; **no** Python toolchain |
| bash | `skills/bash.mk` + `skills/bash/find-shell-files` | No | Prefixed script discovery, syntax, ShellCheck, bash check/clean helpers |

### Target naming

- **Versioning:** unprefixed (`bump-dev`, `release`, …).
- **Languages / docs:** prefixed with skill name and hyphen:
  - `python-lint`, `python-test`, `python-build`, …
  - `mkdocs-build`, `mkdocs-serve`, …
  - `bash-syntax`, `bash-shellcheck`, `bash-lint`, …

Keep semantic split: `release` = version promotion; packaging publish stays under the language skill (e.g. `python-publish`).

### Help and status

Each skill registers a help fragment (and optionally a status section). Wrapper `help` prints:

1. Lifecycle (`init`, `update`)
2. Versioning (always)
3. Only skills listed in `SKILLS`

`status` follows the same composition: versioning core + sections from enabled skills only.

## Shared library repo layout

```text
makefile-meta/
  skills/
    versioning.mk
    python.mk
    mkdocs.mk
    bash.mk
    bash/find-shell-files
  examples/
    Makefile.versioning-only
    Makefile.python
    Makefile.python-docs
    Makefile.bash
  README.md
  cursor-docs/superpowers/specs/...
```

### Migration of existing content

1. Extract the shared versioning block once into `versioning.mk`.
2. Move Python / MkDocs / Bash logic into their skill files; apply prefixed target names.
3. Place sample configs (e.g. `.bumpversion.toml`) under `examples/` only if useful for documentation — projects keep their own configs.
4. Retire top-level `makefile-*` directories after extraction (or leave short-lived deprecated stubs pointing at the new layout).
5. Tag library releases (`v1.0.0`, …) so projects can pin with `MAKEFILES_REF`.

## What projects commit vs ignore

| Committed | Gitignored |
|-----------|------------|
| Thin `Makefile` (SKILLS, repo URL, ref, overrides) | `.makefiles/` |
| `.gitignore` entry for `.makefiles/` | |

## Example project wrapper (illustrative)

```makefile
SKILLS         ?= python mkdocs
MAKEFILES_DIR  ?= .makefiles
MAKEFILES_REPO ?= git@github.com:the-lupaxa-blueprints/makefile-meta.git
MAKEFILES_REF  ?= head

.DEFAULT_GOAL := help

.PHONY: init install update help

init install:
	@# clone if missing; checkout resolved ref

update:
	@# fetch and checkout resolved ref

-include $(MAKEFILES_DIR)/skills/versioning.mk
$(foreach s,$(SKILLS),$(eval -include $(MAKEFILES_DIR)/skills/$(s).mk))

help:
	@# lifecycle + versioning + enabled skill fragments
	@# if clone missing: prompt to run make init
```

## Testing (design-level)

- Wrapper with no clone: `make help` and `make init` succeed; skill targets error clearly.
- After init with `MAKEFILES_REF=head`: versioning targets work; optional skills only appear when listed in `SKILLS`.
- `make update` with a tag pin checks out that tag; switching back to `head` returns to `master` tip.
- Prefixed targets do not collide when documenting multi-language future use; v1 assumes one language skill per project if desired.

## Success criteria

- One skills library replaces four duplicated Makefiles.
- A new project can adopt versioning + optional skills with a small committed wrapper.
- Skills are not committed to consumer repos; `make update` refreshes them.
- Help output matches enabled skills.
- Language commands are unambiguous via prefixes.
