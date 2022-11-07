#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# 🅽🅿🅼 🅰🅻🅸🅰🆂🅴🆂
if command -v npm &>/dev/null; then
  alias npb='npm build'      # npb: Build npm script.
  alias npc='npm cache'      # npc: Cache npm package.
  alias npd='npm dev'        # npd: Dev npm script.
  alias npg='npm global'     # npg: Global npm package.
  alias npi='npm install'    # npi: Install npm package.
  alias npl='npm list'       # npl: List npm packages.
  alias npp='npm publish'    # npp: Publish npm package.
  alias npr='npm run'        # npr: Run npm script.
  alias nprw='npm run watch' # nprw: Run npm script watch.
  alias nps='npm start'      # nps: Start npm script.
  alias npsv='npm serve'     # npsv: Serve npm script.
  alias npt='npm test'       # npt: Test npm script.
  alias npu='npm update'     # npu: Update npm package.
  alias npx='npm exec'       # npx: Exec npm package.
  alias npy='npm why'        # npy: Why npm package.
fi
