#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.455) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅲🅾🅼🅿🅸🅻🅴 🅳🅾🆃🅵🅸🅻🅴🆂 - Compile dotfiles.

compile() {
  pnpm run cp:shell &&
  pnpm run cl:tmp &&
  pnpm run cp:bin &&
  pnpm run cp:make &&
  pnpm run minify &&
  pnpm run filesizes
}
compile
