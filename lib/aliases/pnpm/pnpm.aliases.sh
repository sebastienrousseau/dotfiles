#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.464) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# 🅿🅽🅿🅼 🅰🅻🅸🅰🆂🅴🆂 - Pnpm aliases
if command -v 'pnpm' >/dev/null; then
  alias pna='pnpm add'                             # pna: Add a dependency to the project.
  alias pnad='pnpm add --save-dev'                 # pnad: Add a dev dependency to the project.
  alias pnap='pnpm add --save-peer'                # pnap: Add a peer dependency to the project.
  alias pnau='pnpm audit'                          # pnau: Audit the project.
  alias pnb='pnpm run build'                       # pnb: Build the project.
  alias pnc='pnpm create'                          # pnc: Create a new project.
  alias pnd='pnpm run dev'                         # pnd: Run the project in dev mode.
  alias pndoc='pnpm run doc'                       # pndoc: Generate the project documentation.
  alias pnga='pnpm add --global'                   # pnga: Add a global dependency.
  alias pngls='pnpm list --global'                 # pngls: List all global dependencies.
  alias pngrm='pnpm remove --global'               # pngrm: Remove a global dependency.
  alias pngu='pnpm update --global'                # pngu: Update a global dependency.
  alias pnh='pnpm help'                            # pnh: Show the help.
  alias pni='pnpm init'                            # pni: Initialize a new project.
  alias pnin='pnpm install'                        # pnin: Install the project dependencies.
  alias pnln='pnpm run lint'                       # pnln: Lint the project.
  alias pnls='pnpm list'                           # pnls: List all dependencies.
  alias pnout='pnpm outdated'                      # pnout: Check for outdated dependencies.
  alias pnp='pnpm'                                 # pnp: Shortcut to pnpm.
  alias pnpub='pnpm publish'                       # pnpub: Publish the project.
  alias pnrm='pnpm remove'                         # pnrm: Remove a dependency from the project.
  alias pnrun='pnpm run'                           # pnrun: Run a script from the project.
  alias pns='pnpm run serve'                       # pns: Run the project in serve mode.
  alias pnst='pnpm start'                          # pnst: Start the project.
  alias pnsv='pnpm server'                         # pnsv: Run the project in server mode.
  alias pnt='pnpm test'                            # pnt: Test the project.
  alias pntc='pnpm test --coverage'                # pntc: Test the project with coverage.
  alias pnui='pnpm update --interactive'           # pnui: Update a dependency interactively.
  alias pnuil='pnpm update --interactive --latest' # pnuil: Update a dependency interactively to the latest version.
  alias pnun='pnpm uninstall'                      # pnun: Uninstall the project dependencies.
  alias pnup='pnpm update'                         # pnup: Update a dependency.
  alias pnwhy='pnpm why'                           # pnwhy: Check why a dependency is installed.
  alias pnx='pnpx'                                 # pnx: Shortcut to pnpx.
fi
