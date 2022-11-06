#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# 🅿🅽🅿🅼 🅰🅻🅸🅰🆂🅴🆂 - Pnpm aliases
if command -v pnpm &>/dev/null; then
  alias pa='pnpm add'                             # pa: Add a dependency to the project.
  alias pad='pnpm add --save-dev'                 # pad: Add a dev dependency to the project.
  alias pap='pnpm add --save-peer'                # pap: Add a peer dependency to the project.
  alias pau='pnpm audit'                          # pau: Audit the project.
  alias pb='pnpm run build'                       # pb: Build the project.
  alias pc='pnpm create'                          # pc: Create a new project.
  alias pd='pnpm run dev'                         # pd: Run the project in dev mode.
  alias pdoc='pnpm run doc'                       # pdoc: Generate the project documentation.
  alias pga='pnpm add --global'                   # pga: Add a global dependency.
  alias pgls='pnpm list --global'                 # pgls: List all global dependencies.
  alias pgrm='pnpm remove --global'               # pgrm: Remove a global dependency.
  alias pgu='pnpm update --global'                # pgu: Update a global dependency.
  alias ph='pnpm help'                            # ph: Show the help.
  alias pi='pnpm init'                            # pi: Initialize a new project.
  alias pin='pnpm install'                        # pin: Install the project dependencies.
  alias pln='pnpm run lint'                       # pln: Lint the project.
  alias pls='pnpm list'                           # pls: List all dependencies.
  alias pn='pnpm'                                 # pn: Shortcut to pnpm.
  alias pout='pnpm outdated'                      # pout: Check for outdated dependencies.
  alias ppub='pnpm publish'                       # ppub: Publish the project.
  alias prm='pnpm remove'                         # prm: Remove a dependency from the project.
  alias prun='pnpm run'                           # prun: Run a script from the project.
  alias ps='pnpm run serve'                       # ps: Run the project in serve mode.
  alias pst='pnpm start'                          # pst: Start the project.
  alias psv='pnpm server'                         # psv: Run the project in server mode.
  alias pt='pnpm test'                            # pt: Test the project.
  alias ptc='pnpm test --coverage'                # ptc: Test the project with coverage.
  alias pui='pnpm update --interactive'           # pui: Update a dependency interactively.
  alias puil='pnpm update --interactive --latest' # puil: Update a dependency interactively to the latest version.
  alias pun='pnpm uninstall'                      # pun: Uninstall the project dependencies.
  alias pup='pnpm update'                         # pup: Update a dependency.
  alias pwhy='pnpm why'                           # pwhy: Check why a dependency is installed.
  alias px='pnpx'                                 # px: Shortcut to pnpx.
fi
