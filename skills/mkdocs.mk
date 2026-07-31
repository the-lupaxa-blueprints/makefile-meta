MKDOCS        ?= mkdocs
MKDOCS_CONFIG ?= mkdocs.yml

STATUS_FRAGMENTS += status-mkdocs

.PHONY: help-mkdocs status-mkdocs mkdocs-build mkdocs-serve mkdocs-clean

help-mkdocs:
	@echo "Documentation (MkDocs):"
	@echo "  mkdocs-build        Build the static MkDocs site"
	@echo "  mkdocs-serve        Serve MkDocs with live reload"
	@echo "  mkdocs-clean        Remove the generated site/ directory"
	@echo

status-mkdocs:
	@printf '\nDocumentation:\n'
	@if [ -f "$(MKDOCS_CONFIG)" ]; then \
		printf '  %-24s %s\n' "Configuration:" "[OK] $(MKDOCS_CONFIG)"; \
	else \
		printf '  %-24s %s\n' "Configuration:" "[MISSING] $(MKDOCS_CONFIG)"; \
	fi; \
	if command -v "$(MKDOCS)" >/dev/null 2>&1; then \
		printf '  %-24s %s\n' "MkDocs:" "[OK] $$(command -v "$(MKDOCS)")"; \
	else \
		printf '  %-24s %s\n' "MkDocs:" "[MISSING] $(MKDOCS)"; \
	fi

mkdocs-build:
	$(MKDOCS) build --config-file "$(MKDOCS_CONFIG)"

mkdocs-serve:
	$(MKDOCS) serve --config-file "$(MKDOCS_CONFIG)"

mkdocs-clean:
	rm -rf site
