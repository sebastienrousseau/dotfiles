#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.458) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅲🅾🅿🆈 🅳🅾🆃🅵🅸🅻🅴🆂 - Copy dotfiles.

copy() {
  pnpm run cp:bash &&
  pnpm run cp:cert &&
  pnpm run cp:curl &&
  pnpm run cp:dirs &&
  pnpm run cp:inpt &&
  pnpm run cp:jsht &&
  pnpm run cp:prof &&
  pnpm run cp:tmux &&
  pnpm run cp:vimr &&
  pnpm run cp:wget &&
  pnpm run cp:zshr
}
copy
