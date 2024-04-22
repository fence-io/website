#########
# TOOLS #
#########

PIP         ?= "pip"

###########
# CODEGEN #
###########

.PHONY: codegen-mkdocs
codegen-mkdocs: ## Generate mkdocs website
	@echo Generate mkdocs website... >&2
	@$(PIP) install --upgrade pip
	@$(PIP) install -U mkdocs \
		mkdocs-material \
		mkdocs-material[imaging] \
		mkdocs-material-extensions \
		pymdown-extensions \
		mkdocs-redirects \
		mkdocs-minify-plugin \
		mkdocs-include-markdown-plugin \
		lunr \
		mkdocs-rss-plugin \
		mkdocs-git-revision-date-localized-plugin \
		mike
	@mkdocs build

##########
# MKDOCS #
##########

.PHONY: mkdocs-serve
mkdocs-serve: ## Generate and serve mkdocs website
	@echo Generate and serve mkdocs website... >&2
	@$(PIP) install --upgrade pip
	@$(PIP) install -U mkdocs \
		mkdocs-material \
		mkdocs-material[imaging] \
		mkdocs-material-extensions \
		pymdown-extensions \
		mkdocs-redirects \
		mkdocs-minify-plugin \
		mkdocs-include-markdown-plugin \
		lunr \
		mkdocs-rss-plugin \
		mkdocs-git-revision-date-localized-plugin \
		mike
	@mkdocs serve -f ./mkdocs.yaml

.PHONY: codegen
codegen: ## Rebuild all generated code and docs
codegen: codegen-mkdocs

.PHONY: verify-codegen
verify-codegen: ## Verify all generated code and docs are up to date
verify-codegen: codegen
	@echo Checking codegen is up to date... >&2
	@git --no-pager diff -- .
	@echo 'If this test fails, it is because the git diff is non-empty after running "make codegen".' >&2
	@echo 'To correct this, locally run "make codegen", commit the changes, and re-run tests.' >&2
	@git diff --quiet --exit-code -- .

########
# HELP #
########

.PHONY: help
help: ## Shows the available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-40s\033[0m %s\n", $$1, $$2}'
