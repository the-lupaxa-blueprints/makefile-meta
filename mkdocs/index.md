# makefile-skills

Reusable **Makefile skills** for project versioning, Python quality tooling,
MkDocs documentation, and Bash validation.

Each consumer project keeps a thin wrapper `Makefile`. That wrapper clones this
library into a gitignored `.makefiles/` directory, always enables
**versioning**, and optionally enables standalone skills via `SKILLS`.

## Why it exists

Copy-pasted Makefiles drift. This library keeps shared targets in one place and
lets you refresh them with `make update`, while each project only commits its
wrapper and `.gitignore`.

## Skills at a glance

<div class="lupaxa-table lupaxa-table--skills" markdown="1">

| Skill | Always on? | Purpose |
| --- | --- | --- |
| Versioning | Yes | Controlled bump / RC / release flow with `bump-my-version` |
| Python | Optional | Lint, type-check, test, audit, build, publish (prefixed targets) |
| MkDocs | Optional | Build and serve docs (`mkdocs-serve` supports custom ports) |
| Bash | Optional | Discover scripts, `bash -n`, ShellCheck |

</div>

## Next steps

- [Getting started](getting-started.md) — adopt the wrapper and run `make init`
- [Usage](usage.md) — day-to-day workflows (`doctor`, bumps, Python, docs, Bash)
- [Reference](reference.md) — commands and variables
- [Examples](examples.md) — ready-made wrapper profiles
