# Getting started

## Requirements

- GNU Make
- Git
- Network access to clone this library (SSH or HTTPS)
- Skill-specific tools as needed (`bump-my-version`, Python toolchain, MkDocs,
  ShellCheck, …) — use `make doctor` after init to verify

## Adopt the wrapper

1. Copy [`templates/Makefile`](https://github.com/the-lupaxa-blueprints/makefile-skills/blob/master/templates/Makefile)
   (or an example from [`examples/`](examples.md)) to your project root as
   `Makefile`.
2. Add `.makefiles/` to the project's `.gitignore`. Commit the wrapper and
   `.gitignore`, not the cloned skills library. `make init` pulls only
   `skills/` via sparse checkout (docs/tests/examples stay out of the clone).
3. Enable optional skills:

   ```make
   SKILLS ?= python mkdocs
   ```

   Versioning is always available. Optional skills are `python`, `mkdocs`, and
   `bash`.

4. Choose clone transport (`ssh` is the default):

   ```make
   MAKEFILES_TRANSPORT ?= https
   MAKEFILES_REPO_SSH  ?= git@github.com:the-lupaxa-blueprints/makefile-skills.git
   MAKEFILES_REPO_HTTP ?= https://github.com/the-lupaxa-blueprints/makefile-skills.git
   ```

5. Initialise and inspect:

   ```bash
   make init
   make help
   make doctor
   ```

## First commands

```bash
make status
make version
make show-version-flow
```

## Pin the library version

`MAKEFILES_REF` defaults to `head` (tip of `master`). To pin a release tag:

```make
MAKEFILES_REF ?= v1.0.0
```

Then run `make update` (or `make init` on a fresh clone).

## Refresh skills

```bash
make update
```

This fetches and checks out `MAKEFILES_REF` again inside `.makefiles/`.
