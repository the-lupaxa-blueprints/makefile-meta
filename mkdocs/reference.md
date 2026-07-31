# Reference

## Lifecycle (wrapper)

<div class="lupaxa-table lupaxa-table--commands" markdown="1">

| Command | Description |
| --- | --- |
| `make init` / `make install` | Sparse-clone `skills/` into `MAKEFILES_DIR` (default `.makefiles`) |
| `make update` | Fetch and check out `MAKEFILES_REF` (keeps sparse `skills/` tree) |
| `make help` | List lifecycle commands and enabled skill help |
| `make status` | Project / version / Git / skill status (Status help section) |
| `make doctor` | Top-level: lifecycle + `doctor-versioning` + each enabled `*-doctor` |
| `make completion` | Print bash completion snippet for `make` targets |

</div>

### Wrapper variables

<div class="lupaxa-table lupaxa-table--vars-desc" markdown="1">

| Variable | Default | Description |
| --- | --- | --- |
| `SKILLS` | _(empty)_ | Optional skills: `python`, `mkdocs`, `bash` |
| `MAKEFILES_DIR` | `.makefiles` | Clone location (gitignored in consumers) |
| `MAKEFILES_TRANSPORT` | `ssh` | `ssh`, `https`, or `http` |
| `MAKEFILES_REPO_SSH` | `git@github.com:the-lupaxa-blueprints/makefile-skills.git` | SSH URL |
| `MAKEFILES_REPO_HTTP` | `https://github.com/the-lupaxa-blueprints/makefile-skills.git` | HTTPS URL |
| `MAKEFILES_REPO` | _(derived)_ | Selected URL; override for one-offs |
| `MAKEFILES_REF` | `head` | `head` → tip of `master`, or a tag such as `v1.0.0` |

</div>

## Versioning (always on)

<div class="lupaxa-table lupaxa-table--commands" markdown="1">

| Command | Description |
| --- | --- |
| `make version` | Print current version from `.bumpversion.toml` |
| `make show-version-flow` | Valid next bump/release commands for this stage |
| `make bump-dev` | Start or continue patch development (`-devN`) |
| `make bump-minor` | Start minor cycle from stable |
| `make bump-major` | Start major cycle from stable |
| `make bump-rc` | Promote `-devN` → `-rc1` or bump `-rcN` |
| `make release` | Promote `-rcN` → stable |
| `make bump-final` | Alias of `release` |
| `make doctor-versioning` | Check version file, bump tool, git work tree |

</div>

### Versioning variables

<div class="lupaxa-table lupaxa-table--vars" markdown="1">

| Variable | Default |
| --- | --- |
| `VERSION_FILE` | `.bumpversion.toml` |
| `BUMP` | `bump-my-version` |
| `PROJECT_NAME` | directory name |

</div>

## Python skill

Enable with `SKILLS ?= python` (or include `python` in a list).

<div class="lupaxa-table lupaxa-table--commands" markdown="1">

| Command | Description |
| --- | --- |
| `make python-doctor` | Check layout and tools |
| `make python-install-dev` | Editable install with `[dev]` |
| `make python-install-test` | Editable install with `[test]` |
| `make python-lint` | Ruff lint + format check |
| `make python-check-style` | Lint + mypy |
| `make python-format` | Ruff format |
| `make python-type` | mypy |
| `make python-test` | pytest |
| `make python-test-cov` | pytest with coverage |
| `make python-check` | lint + type + test |
| `make python-check-all` | lint + type + coverage + audit |
| `make python-audit` | pip-audit in an isolated venv |
| `make python-build` | Hatch build |
| `make python-publish` | Hatch publish |
| `make python-clean` | Remove Python artefacts |

</div>

### Python variables

<div class="lupaxa-table lupaxa-table--vars" markdown="1">

| Variable | Default |
| --- | --- |
| `SRC_DIR` | `src` |
| `TEST_DIR` | `tests` |
| `PYPROJECT_FILE` | `pyproject.toml` |
| `PYTHON` / `RUFF` / `MYPY` / `PYTEST` / `HATCH` | tool names on `PATH` |

</div>

## MkDocs skill

Enable with `SKILLS ?= mkdocs`.

<div class="lupaxa-table lupaxa-table--commands" markdown="1">

| Command | Description |
| --- | --- |
| `make mkdocs-doctor` | Check config and `mkdocs` binary |
| `make mkdocs-build` | Build static site |
| `make mkdocs-serve` | Live-reload server |
| `make mkdocs-clean` | Remove `site/` |

</div>

### MkDocs variables

<div class="lupaxa-table lupaxa-table--vars" markdown="1">

| Variable | Default |
| --- | --- |
| `MKDOCS_CONFIG` | `mkdocs.yml` |
| `MKDOCS_HOST` | `127.0.0.1` |
| `MKDOCS_PORT` | `8000` |
| `MKDOCS` | `mkdocs` |

</div>

## Bash skill

Enable with `SKILLS ?= bash`.

<div class="lupaxa-table lupaxa-table--commands" markdown="1">

| Command | Description |
| --- | --- |
| `make bash-doctor` | Check discovery helper and tools |
| `make bash-list-scripts` | List discovered scripts |
| `make bash-syntax` | `bash -n` on each script |
| `make bash-shellcheck` | ShellCheck analysis |
| `make bash-lint` | Alias of `bash-shellcheck` |
| `make bash-test` / `make bash-check` | syntax + ShellCheck |

</div>

### Bash variables

<div class="lupaxa-table lupaxa-table--vars" markdown="1">

| Variable | Default |
| --- | --- |
| `SHELL_SOURCE_DIR` | `.` |
| `SHELL_FILE_FINDER` | `$(MAKEFILES_DIR)/skills/bash/find-shell-files` |
| `SHELL_FILES` | auto-discovered |
| `SHELLCHECK_SHELL` | `bash` |
| `BASH` / `SHELLCHECK` | tool names on `PATH` |

</div>

## Repository layout (this library)

```text
templates/Makefile              Canonical consumer wrapper
examples/                       Wrapper profiles (versioning, python, docs, bash)
skills/                         Skill fragments (.mk) and bash helper
skills/_template.language.mk    Starter for a new language skill (copy → rename)
mkdocs/                         Documentation source (this site)
mkdocs.yml                      MkDocs configuration
tests/                          Shell integration tests
overrides/                      Material theme overrides
```

## Adding a language skill

Copy [`skills/_template.language.mk`](https://github.com/the-lupaxa-blueprints/makefile-skills/blob/master/skills/_template.language.mk)
to `skills/<id>.mk` (for example `go.mk`), replace `lang` / `Lang`, implement the stub
targets, then enable with `SKILLS ?= go`. See the checklist in the template header.
