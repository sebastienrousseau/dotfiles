#!/usr/bin/env make -f

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.459) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

.DEFAULT_GOAL := help
HOMEDIR:= $(shell pwd)
BANNER:= $(HOMEDIR)/scripts/banner.sh
SHELL := /bin/bash

.PHONY: backup
backup: # @HELP
backup: ## Backup your current dotfiles.
	@$(HOMEDIR)/scripts/backup.sh backup

.PHONY: assemble
assemble: # @HELP Assemble the dotfiles on your system.
assemble: ## Prepare the dotfiles on your system.
# ifdef PNPM
# 	pnpm run assemble
# else
	sh $(HOMEDIR)/scripts/dotfiles assemble
# endif

.PHONY: copy
copy: # @HELP Copy the dotfiles on your system.
copy: ## Copy the dotfiles on your system.
# ifdef PNPM
# 	pnpm run copy
# else
	sh $(HOMEDIR)/scripts/dotfiles copy
# endif

.PHONY: download
download: # @HELP Download the dotfiles on your system.
download: ## Download the dotfiles on your system.
# ifdef PNPM
# 	pnpm run download
# else
	sh $(HOMEDIR)/scripts/dotfiles download
# endif

.PHONY: unpack
unpack: # @HELP Unpack the dotfiles on your system.
unpack: ## Unpack the dotfiles on your system.
# ifdef PNPM
# 	pnpm run unpack
# else
	sh $(HOMEDIR)/scripts/dotfiles unpack
# endif

.PHONY: clean
clean: # @HELP Removes any previous setup directories.
clean:
# ifdef PNPM
# 	pnpm run clean
# else
	sh $(HOMEDIR)/scripts/dotfiles clean
# endif

.PHONY: help
help: # @HELP Display the help menu.
help: ## Display the help menu.
	@$(BANNER)
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n\n make \033[36m[target]\033[0m\n\n"} /^[$$()% a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-8s\033[0m -%s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""

