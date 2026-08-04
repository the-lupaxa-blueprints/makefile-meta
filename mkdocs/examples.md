# Examples

Ready-made wrappers live in [`examples/`](https://github.com/the-lupaxa-internal-toolbox/makefile-skills/tree/master/examples).
Each file is a copy of [`templates/Makefile`](https://github.com/the-lupaxa-internal-toolbox/makefile-skills/blob/master/templates/Makefile)
with only the `SKILLS` line changed.

<div class="lupaxa-table lupaxa-table--examples" markdown="1">

| File | `SKILLS` | Use when |
| --- | --- | --- |
| `Makefile.versioning-only` | _(empty)_ | Version bumps only |
| `Makefile.python` | `python` | Python package / app |
| `Makefile.python-docs` | `python mkdocs` | Python project with MkDocs |
| `Makefile.bash-project` | `bash` | Shell-script repositories |

</div>

## Versioning only

```make
SKILLS ?=
```

```bash
cp examples/Makefile.versioning-only ./Makefile
# add .makefiles/ to .gitignore
make init
make doctor
make bump-dev
```

## Python

```make
SKILLS ?= python
```

```bash
cp examples/Makefile.python ./Makefile
make init
make python-install-dev
make python-check
```

## Python + MkDocs

```make
SKILLS ?= python mkdocs
```

```bash
cp examples/Makefile.python-docs ./Makefile
make init
make python-check
make mkdocs-serve MKDOCS_PORT=8000
```

## Bash

```make
SKILLS ?= bash
```

```bash
cp examples/Makefile.bash-project ./Makefile
make init
make bash-list-scripts
make bash-check
```

!!! tip "Ignore the clone"
    Consumer projects should ignore `.makefiles/` (see `examples/.gitignore`).
    Only the wrapper Makefile is committed.
