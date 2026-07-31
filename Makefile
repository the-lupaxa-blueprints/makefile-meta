# makefile-skills — library development Makefile
# Uses the local skills/ tree (no .makefiles clone).

MAKEFILES_MODE := library
MAKEFILES_DIR  := .
SKILLS         ?= mkdocs bash

include templates/Makefile
