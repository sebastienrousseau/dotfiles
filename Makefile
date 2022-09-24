#!/usr/bin/env make -f
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - Dotfiles Installer makefile.

.DEFAULT_GOAL := help

homedir := ./installer
language := en

.PHONY: installer
installer: # @HELP Installation of the dotfiles packages.
installer: ## Install dotfiles
	@set -e; \
	sh "$(homedir)/$(language)/configuration/menu.sh"


build-en: # @HELP English language installer.
build-en:
	@echo
	@echo "Building the english documentation"
	sh './installer/en/dotfiles-setup-en.sh'

clean: # @HELP Removes any previous setup directories. (site, theme source and theme folders)
clean: site-clean theme-source-clean theme-clean

site-clean:
	rm -fr site

theme-source-clean:
	rm -fr mkdocs-material

theme-clean:
	rm -fr material

serve: # @HELP Starts the web server.
serve:
	@echo
	@echo "Starting web server"
	serve -p 8000 site/

help: # @HELP Display the help menu.
help:
	@grep -E '^.*: *# *@HELP' $(MAKEFILE_LIST)    \
		| awk '                                   \
				BEGIN {FS = ": *# *@HELP"};           \
				{ printf "  %-30s %s\n", $$1, $$2 };  \
		'
