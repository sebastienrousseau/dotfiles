#!/usr/bin/env make -f
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.452) - Dotfiles Installer makefile.

.DEFAULT_GOAL := help

homedir := ./installer
language := en

.PHONY: backup
backup: # @HELP Backup your current dotfiles.
backup: ## Backup your current dotfiles.
	@set -e; \
	pnpm run backup

.PHONY: install
install: # @HELP Install the dotfiles on your system.
install: ## Install the dotfiles on your system.
	@set -e; \
	pnpm run build

.PHONY: clean
clean: # @HELP Removes any previous setup directories. (site, theme source and theme folders)
clean: pnpm run clean

.PHONY: help
help: # @HELP Display the help menu.
help:
	@grep -E '^.*: *# *@HELP' $(MAKEFILE_LIST)    \
		| awk '                                   \
				BEGIN {FS = ": *# *@HELP"};           \
				{ printf "  %-30s %s\n", $$1, $$2 };  \
		'
