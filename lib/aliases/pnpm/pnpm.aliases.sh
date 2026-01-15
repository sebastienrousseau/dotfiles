#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# 🅿🅽🅿🅼 🅰🅻🅸🅰🆂🅴🆂
if command -v 'pnpm' >/dev/null; then
  # Add a dependency to the project.
  alias pna='pnpm add'
  # Add a dev dependency to the project.
  alias pnad='pnpm add --save-dev'
  # Add a peer dependency to the project.
  alias pnap='pnpm add --save-peer'
  # Audit the project.
  alias pnau='pnpm audit'
  # Build the project.
  alias pnb='pnpm run build'
  # Create a new project.
  alias pnc='pnpm create'
  # Run the project in dev mode.
  alias pnd='pnpm run dev'
  # Generate the project documentation.
  alias pndoc='pnpm run doc'
  # Add a global dependency.
  alias pnga='pnpm add --global'
  # List all global dependencies.
  alias pngls='pnpm list --global'
  # Remove a global dependency.
  alias pngrm='pnpm remove --global'
  # Update a global dependency.
  alias pngu='pnpm update --global'
  # Show the help.
  alias pnh='pnpm help'
  # Initialize a new project.
  alias pni='pnpm init'
  # Install the project dependencies.
  alias pnin='pnpm install'
  # Lint the project.
  alias pnln='pnpm run lint'
  # List all dependencies.
  alias pnls='pnpm list'
  # Check for outdated dependencies.
  alias pnout='pnpm outdated'
  # Shortcut to pnpm.
  alias pnp='pnpm'
  # Publish the project.
  alias pnpub='pnpm publish'
  # Remove a dependency from the project.
  alias pnrm='pnpm remove'
  # Run a script from the project.
  alias pnrun='pnpm run'
  # Run the project in serve mode.
  alias pns='pnpm run serve'
  # Start the project.
  alias pnst='pnpm start'
  # Run the project in server mode.
  alias pnsv='pnpm server'
  # Test the project.
  alias pnt='pnpm test'
  # Test the project with coverage.
  alias pntc='pnpm test --coverage'
  # Update a dependency interactively.
  alias pnui='pnpm update --interactive'
  # Update a dependency interactively to the latest version.
  alias pnuil='pnpm update --interactive --latest'
  # Uninstall the project dependencies.
  alias pnun='pnpm uninstall'
  # Update a dependency.
  alias pnup='pnpm update'
  # Check why a dependency is installed.
  alias pnwhy='pnpm why'
  # Shortcut to pnpx.
  alias pnx='pnpx'
fi
