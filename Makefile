#!/bin/sh
#
#  ____        _   _____ _ _
# |  _ \  ___ | |_|  ___(_) | ___  ___
# | | | |/ _ \| __| |_  | | |/ _ \/ __|
# | |_| | (_) | |_|  _| | | |  __/\__ \
# |____/ \___/ \__|_|   |_|_|\___||___/
#
# DotFiles v0.2.449
# https://dotfiles.io
#
# Description:
#
# Copyright (c) Sebastien Rousseau 2021. All rights reserved
# Licensed under the MIT license
#


.DEFAULT_GOAL := help

build-en: # @HELP Creates the english documentation.
build-en:
	@echo
	@echo "Building the english documentation"
	sh './tools/en/dotfiles-setup-en.sh'

build-theme-en: # @HELP Creates the english mkdocs theme.
build-theme-en:
	@echo
	@echo "Building the english theme"
	sh './tools/en/dotfiles-themes-en.sh'

build-fr: # @HELP Creates the french documentation.
build-fr:
	@echo
	@echo "Building the french documentation"
	sh './tools/en/dotfiles-setup-fr.sh'

build-theme-fr: # @HELP Creates the french mkdocs theme.
build-theme-fr:
	@echo
	@echo "Building the french theme"
	sh './tools/en/dotfiles-themes-fr.sh'

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
