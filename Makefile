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
		mkdocs-git-revision-date-localized-plugin
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
		mkdocs-git-revision-date-localized-plugin
	@mkdocs serve -f ./mkdocs.yaml

########
# HELP #
########

.PHONY: help
help: ## Shows the available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-40s\033[0m %s\n", $$1, $$2}'
