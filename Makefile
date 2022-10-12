#!/usr/bin/env make -f

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.458) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

.DEFAULT_GOAL := help

language := en
PNPM := $(shell command -v pnpm 2> /dev/null)
HOMEDIR:= $(shell pwd)

.PHONY: backup
backup: # @HELP Backup your current dotfiles.
backup: ## Backup your current dotfiles.
ifdef PNPM
	pnpm run backup
else
	sh $(HOMEDIR)/scripts/dotfiles backup
endif

.PHONY: assemble
assemble: # @HELP Assemble the dotfiles on your system.
assemble: ## Prepare the dotfiles on your system.
ifdef PNPM
	pnpm run assemble
else
	sh $(HOMEDIR)/scripts/dotfiles assemble
endif

.PHONY: copy
copy: # @HELP Copy the dotfiles on your system.
copy: ## Copy the dotfiles on your system.
ifdef PNPM
	pnpm run copy
else
	sh $(HOMEDIR)/scripts/dotfiles copy
endif

.PHONY: download
download: # @HELP Download the dotfiles on your system.
download: ## Download the dotfiles on your system.
ifdef PNPM
	pnpm run download
else
	sh $(HOMEDIR)/scripts/dotfiles download
endif

.PHONY: unpack
unpack: # @HELP Unpack the dotfiles on your system.
unpack: ## Unpack the dotfiles on your system.
ifdef PNPM
	pnpm run unpack
else
	sh $(HOMEDIR)/scripts/dotfiles unpack
endif

.PHONY: clean
clean: # @HELP Removes any previous setup directories.
clean:
ifdef PNPM
	pnpm run clean
else
	sh $(HOMEDIR)/scripts/dotfiles clean
endif

.PHONY: help
help: # @HELP Display the help menu.
help:
ifdef PNPM
	pnpm run help
else
	@grep -E '^.*: *# *@HELP' $(MAKEFILE_LIST)    \
	| awk '                                   \
			BEGIN {FS = ": *# *@HELP"};           \
			{ printf "  %-30s %s\n"$$1$$2 };  \
	'
endif
