#!/usr/bin/env make -f

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# File: Makefile
<<<<<<< HEAD
# Version: 0.2.470
=======
# Version: 0.2.471
>>>>>>> 4b0694f (feat: v0.2.471 Product Hardening Release)
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Build automation for dotfiles installation and management
# Website: https://dotfiles.io
# License: MIT
################################################################################

#------------------------------------------------------------------------------
# Configuration Variables
#------------------------------------------------------------------------------

# Default target if no target is specified
.DEFAULT_GOAL := help

# Define shell and working directory
SHELL        := /bin/bash
HOMEDIR      := $(shell pwd)
BANNER       := $(HOMEDIR)/scripts/banner.sh

# Script paths
BACKUP_SCRIPT   := $(HOMEDIR)/scripts/backup.sh
BUILD_SCRIPT    := $(HOMEDIR)/scripts/build.sh
CLEAN_SCRIPT    := $(HOMEDIR)/scripts/clean.sh
COPY_SCRIPT     := $(HOMEDIR)/scripts/copy.sh
DOWNLOAD_SCRIPT := $(HOMEDIR)/scripts/download.sh
UNPACK_SCRIPT   := $(HOMEDIR)/scripts/unpack.sh

#------------------------------------------------------------------------------
# Phony Targets Declaration
#------------------------------------------------------------------------------

.PHONY: backup build clean copy download help unpack

#------------------------------------------------------------------------------
# Backup Target
#------------------------------------------------------------------------------
# @name backup
# @brief Creates a backup of existing dotfiles
# @description Saves current dotfiles to prevent accidental loss
# @command make backup
# @example make backup

backup: ## Backup your current dotfiles
	@$(BACKUP_SCRIPT) backup

#------------------------------------------------------------------------------
# Build Target
#------------------------------------------------------------------------------
# @name build
# @brief Performs complete dotfiles installation
# @description Runs the full installation process including all necessary steps
# @command make build
# @example make build

build: ## Run the full installation process
	@$(BUILD_SCRIPT) build

#------------------------------------------------------------------------------
# Clean Target
#------------------------------------------------------------------------------
# @name clean
# @brief Removes previous dotfiles setup
# @description Cleans up any existing dotfiles installation
# @command make clean
# @example make clean

clean: ## Removes any previous setup
	@$(CLEAN_SCRIPT) clean

#------------------------------------------------------------------------------
# Copy Target
#------------------------------------------------------------------------------
# @name copy
# @brief Copies dotfiles to system
# @description Deploys dotfiles to appropriate locations
# @command make copy
# @example make copy

copy: ## Copy the dotfiles on your system
	@$(COPY_SCRIPT) copy

#------------------------------------------------------------------------------
# Download Target
#------------------------------------------------------------------------------
# @name download
# @brief Downloads latest dotfiles
# @description Retrieves the most recent version of dotfiles
# @command make download
# @example make download

download: ## Download the dotfiles on your system
	@$(DOWNLOAD_SCRIPT) download

#------------------------------------------------------------------------------
# Unpack Target
#------------------------------------------------------------------------------
# @name unpack
# @brief Extracts downloaded dotfiles
# @description Unpacks the dotfiles archive to the system
# @command make unpack
# @example make unpack

unpack: ## Extract the dotfiles to your system
	@$(UNPACK_SCRIPT) unpack

#------------------------------------------------------------------------------
# Help Target
#------------------------------------------------------------------------------
# @name help
# @brief Displays help information
# @description Shows available commands and documentation
# @command make help
# @example make help

help: ## Display the help menu
	@$(BANNER)
	@awk 'BEGIN { \
		FS = ":.*##"; \
		printf "USAGE:\n\n make \033[1;96m[COMMAND]\033[0m\n\nCOMMANDS:\n\n"; \
	} \
	/^[$$()% a-zA-Z_-]+:.*?##/ { \
		printf "  \033[1;96m%-8s\033[0m -%s\n", $$1, $$2; \
	} \
	/^##@/ { \
		printf "\n\033[1m%s\033[0m\n", substr($$0, 5); \
	}' $(MAKEFILE_LIST)
	@echo ""
	@echo "DOCUMENTATION:"
	@echo ""
	@echo -e "  \033[4;36mhttps://dotfiles.io\033[0m\n"
	@echo "LICENSE:"
	@echo ""
	@echo "  This project is licensed under the MIT License."
	@echo ""
