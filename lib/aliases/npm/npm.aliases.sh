#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# 🅽🅿🅼 🅰🅻🅸🅰🆂🅴🆂
if command -v npm &>/dev/null; then
  # Audit npm packages.
  alias npa='npm audit'

  # Build npm script.
  alias npb='npm build'

  # Cache npm package.
  alias npc='npm cache'

  # Dev npm script.
  alias npd='npm dev'

  # Global npm package.
  alias npg='npm global'

  # Install npm package.
  alias npi='npm install'

  # List npm packages.
  alias npl='npm list'

  # Publish npm package.
  alias npp='npm publish'

  # Remove npm package.
  alias nprm='npm uninstall'

  # Run npm script.
  alias npr='npm run'

  # Run npm script watch.
  alias nprw='npm run watch'

  # Start npm script.
  alias nps='npm start'

  # Serve npm script.
  alias npsv='npm serve'

  # Test npm script.
  alias npt='npm test'

  # Update npm package.
  alias npu='npm update'

  # Exec npm package.
  alias npx='npm exec'

  # Why npm package.
  alias npy='npm why'

fi
