# Usage

## Diagnose the environment

```bash
make doctor
```

`make doctor` is the top-level check: lifecycle (clone/transport), then
`doctor-versioning`, then each enabled skill doctor (`python-doctor`,
`mkdocs-doctor`, `bash-doctor`, …). Every section runs even if an earlier one
fails; the command exits non-zero only after the full report if any section
had issues. You can still run any skill doctor on its own (those fail fast).

```bash
make status
```

`make status` and `make doctor` appear under the **Status** help section
(always listed, above Versioning). Status is informational (project, version
stage, Git, enabled skills) and does not fail on missing tools.

## Shell completion

After `make init`, enable bash target completion:

```bash
eval "$(make -s completion)"
# or permanently in ~/.bashrc:
# source /path/to/project/.makefiles/skills/completion/bash
```

## Versioning

Versioning is always on. Versions live in `.bumpversion.toml` and are applied
with `bump-my-version`.

### Direct stable bumps

```make
make bump-patch    # 1.2.3 → 1.2.4
make bump-minor    # 1.2.3 → 1.3.0
make bump-major    # 1.2.3 → 2.0.0
```

### Optional pre-release cycles

Start `-dev` and/or `-rc` when you want them — neither is required for a
stable bump, and `-rc` does not require `-dev` first:

```make
make bump-dev      # 1.2.3 → 1.2.4-dev1  (alias: bump-patch-dev)
make bump-rc       # 1.2.3 → 1.2.4-rc1   (alias: bump-patch-rc; also from -devN)
make release       # 1.2.4-rc1 → 1.2.4
```

Minor/major flavours: `bump-minor-dev` / `bump-major-dev` and
`bump-minor-rc` / `bump-major-rc`. While a `-devN` or `-rcN` cycle is open,
only the matching channel may continue (strict channel).

`-devN` versions are for local / in-repo WIP. They do **not** trigger a GitHub
release workflow (unlike `-rcN` → test/prerelease release).

### Draft GitHub tags (outside the version flow)

`make draft-tag` creates the next `vX.Y.Z-draftN` annotated tag at `HEAD`
without changing `.bumpversion.toml`. That tag triggers
`generate-draft-release.yml`. Override the base with `DRAFT_BASE=1.2.4` if
needed. Push the tag yourself (`git push origin vX.Y.Z-draftN`).

See valid next **version** steps for the current stage:

```bash
make show-version-flow
```

## Python skill

```make
SKILLS ?= python
```

Common loop:

```bash
make python-install-dev
make python-lint
make python-type
make python-test
make python-check          # lint + type + test
make python-build
```

Language targets are prefixed (`python-lint`, not `lint`) so they do not clash
with other skills.

## MkDocs skill

```make
SKILLS ?= python mkdocs
```

```bash
make mkdocs-build
make mkdocs-serve
make mkdocs-serve MKDOCS_PORT=8001
make mkdocs-clean
```

Serve defaults to `127.0.0.1:8000`. Override `MKDOCS_PORT` / `MKDOCS_HOST` when
running several sites at once.

This repository’s own docs live under `mkdocs/` with `mkdocs.yml` at the repo
root (Material theme from the Lupaxa technical documentation template).

## Bash skill

```make
SKILLS ?= bash
```

```bash
make bash-list-scripts
make bash-syntax
make bash-shellcheck
make bash-check
```

Discovery finds `.sh` / `.bash` files, shebang lines, and scripts identified by
`file(1)` (including extensionless commands). The skills clone (`.makefiles/`)
is excluded.

If nothing is found:

```bash
make bash-list-scripts SHELL_SOURCE_DIR=bin
# or
make bash-list-scripts SHELL_FILES="bin/tool scripts/install.sh"
```

## Switching SSH and HTTPS

```make
MAKEFILES_TRANSPORT ?= https   # or ssh | http
```

`MAKEFILES_REPO_SSH` and `MAKEFILES_REPO_HTTP` hold the two URLs.
`MAKEFILES_TRANSPORT` selects which one `make init` / `make update` use.
Override `MAKEFILES_REPO` only for one-offs (for example a local path).
