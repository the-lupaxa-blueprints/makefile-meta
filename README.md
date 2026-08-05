<p align="center">
    <a href="https://github.com/the-lupaxa-internal-toolbox">
        <img src="https://raw.githubusercontent.com/the-lupaxa-project/brand-assets/master/logos/organisations/the-lupaxa-internal-toolbox/readme-logo.png" alt="Organisation Logo" />
    </a>
</p>

<h1 align="center">Makefile Skills</h1>

Reusable Makefile skills for project versioning, Python, MkDocs, and Bash
workflows.

## Adopt the wrapper

1. Copy [`templates/Makefile`](templates/Makefile), or one of the files in
   [`examples/`](examples/), to your project root as `Makefile`.
2. Add `.makefiles/` to the project's `.gitignore`. Commit the wrapper and
   `.gitignore`, but not the cloned skills library. `make init` sparse-clones
   only `skills/` (not this repo's MkDocs site, tests, or examples).

   **Important:** sparse checkout is implemented in the **project wrapper**
   (`Makefile`). If `make init` still materialises `mkdocs/`, `examples/`, etc.,
   replace your `Makefile` from [`templates/Makefile`](templates/Makefile) (or
   an [`examples/`](examples/) profile), then `rm -rf .makefiles && make init`.
3. Configure the skills to enable:

   ```make
   SKILLS ?= python mkdocs
   ```

   Versioning is always available. Optional skills are `python`, `mkdocs`, and
   `bash`. To add another language, copy
   [`skills/_template.language.mk`](skills/_template.language.mk) to
   `skills/<id>.mk` and follow the checklist in that file.
4. Choose clone transport (`ssh` default, or `https` / `http`):

   ```make
   MAKEFILES_TRANSPORT ?= https
   MAKEFILES_REPO_SSH  ?= git@github.com:the-lupaxa-internal-toolbox/makefile-skills.git
   MAKEFILES_REPO_HTTP ?= https://github.com/the-lupaxa-internal-toolbox/makefile-skills.git
   ```

   `MAKEFILES_TRANSPORT` selects which of the two URLs is used. Override
   `MAKEFILES_REPO` directly only when you need a one-off (for example a
   local path).

5. Run `make init`, then `make help`.

Use `make doctor` to verify tools, the skills clone, and skill-specific
configuration before you start day-to-day work. `status` and `doctor` appear
under the **Status** section in `make help`.

Enable bash completion for make targets:

```bash
eval "$(make -s completion)"
```

Use `make update` to fetch the selected revision again.

## Pin the library version

`MAKEFILES_REF` defaults to `head`, which checks out the library's `master`
branch. To pin consumers after a library release is tagged, set
`MAKEFILES_REF` to that tag:

```make
MAKEFILES_REF ?= v1.0.0
```

Create tags such as `v1.0.0` in the library when you are ready to publish a
stable pin; consumers can continue using the default `head` until then.

## Skills and commands

`versioning` is always enabled and provides direct stable bumps
(`make bump-patch`, `make bump-minor`, `make bump-major`) plus an optional
pre-release cycle (`make bump-dev`, `make bump-rc`, `make release`, and
channel-specific `bump-*-dev` / `bump-*-rc` targets). See `make help` or
`make show-version-flow` for valid next steps from the current version.

Enable `python` for prefixed commands such as `make python-lint`,
`make python-type`, `make python-test`, `make python-check`, and
`make python-build`.

Enable `mkdocs` for `make mkdocs-build`, `make mkdocs-serve`, and
`make mkdocs-clean`. Serve defaults to `127.0.0.1:8000`; override per run:

```bash
make mkdocs-serve MKDOCS_PORT=8001
make mkdocs-serve MKDOCS_PORT=8002
```

Enable `bash` for `make bash-list-scripts`, `make bash-syntax`,
`make bash-shellcheck`, and `make bash-check`.

Run `make help` in a consumer project to see only the versioning commands and
the optional skills selected by `SKILLS`.

## Documentation site

Project docs use MkDocs Material (Lupaxa technical documentation template):

```bash
python -m pip install -r requirements.txt
make mkdocs-serve   # requires SKILLS including mkdocs, or: python -m mkdocs serve
```

Source lives in `mkdocs/`; config is `mkdocs.yml` at the repository root.

<a href="https://github.com/the-lupaxa-project">
    <img src="https://raw.githubusercontent.com/the-lupaxa-project/brand-assets/master/logos/components/footer-for-child-orgs.svg" alt="The Lupaxa Project Footer" width="100%" />
</a>
