# shellcheck shell=bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# 🆁🆂🆈🅽🅲 🅰🅻🅸🅰🆂🅴🆂

if command -v 'rsync' >/dev/null; then

  # Rsync with verbose and progress.
  alias rs='rsync -avz'

  # Rsync with verbose and progress.
  alias rsync='rs'
fi
