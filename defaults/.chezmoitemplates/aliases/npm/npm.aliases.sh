# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# 🅽🅿🅼 🅰🅻🅸🅰🆂🅴🆂
if command -v npm &>/dev/null; then
  # Audit npm packages.
  alias npa='npm audit'

  # Cache npm package.
  alias npc='npm cache'

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

  # Test npm script.
  alias npt='npm test'

  # Update npm package.
  alias npu='npm update'

  # Exec npm package.
  alias npexec='npm exec'

  # Why npm package.
  alias npy='npm why'

fi
