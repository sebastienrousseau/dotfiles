#!/usr/bin/env make -f

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.460) - https://dotfiles.io
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

.PHONY: clean
clean: # @HELP
clean: ## Removes any previous setup.
clean:
	@$(HOMEDIR)/scripts/clean.sh clean

.PHONY: copy
copy: # @HELP
copy: ## Copy the dotfiles on your system.
	@$(HOMEDIR)/scripts/copy.sh copy

.PHONY: download
download: # @HELP
download: ## Download the dotfiles on your system.
	@$(HOMEDIR)/scripts/download.sh download

.PHONY: build
build: # @HELP
build: ## Run the full installation process.
	@$(HOMEDIR)/scripts/build.sh build

.PHONY: unpack
unpack: # @HELP
unpack: ## Extract the dotfiles to your system.
	@$(HOMEDIR)/scripts/unpack.sh unpack

.PHONY: help
help: # @HELP
help: ## Display the help menu.
	@$(BANNER)
	@awk 'BEGIN {FS = ":.*##"; printf "\USAGE:\n\n make \033[1;96m[COMMAND]\033[0m\n\nCOMMANDS:\n\n"} /^[$$()% a-zA-Z_-]+:.*?##/ { printf "  \033[1;96m%-8s\033[0m -%s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""
	@echo "DOCUMENTATION:"
	@echo ""
	@echo -e "  \033[4;36mhttps://dotfiles.io\033[0m\n"
	@echo "LICENSE:"
	@echo ""
	@echo "  This project is licensed under the MIT License."
	@echo ""

