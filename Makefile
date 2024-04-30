#########
# TOOLS #
#########

PIP         ?= "pip"

###########
# CODEGEN #
###########

# TODO: codegen-hugo

.PHONY: codegen
codegen: ## Rebuild all generated code and docs

.PHONY: verify-codegen
verify-codegen: ## Verify all generated code and docs are up to date
verify-codegen: codegen
	@echo Checking codegen is up to date... >&2
	@git --no-pager diff -- .
	@echo 'If this test fails, it is because the git diff is non-empty after running "make codegen".' >&2
	@echo 'To correct this, locally run "make codegen", commit the changes, and re-run tests.' >&2
	@git diff --quiet --exit-code -- .

########
# HUGO #
########

.PHONY: hugo-serve
hugo-serve: ## Build and serve website
	@echo Build and serve website... >&2
	@npm install
	@npm start

########
# HELP #
########

.PHONY: help
help: ## Shows the available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-40s\033[0m %s\n", $$1, $$2}'
