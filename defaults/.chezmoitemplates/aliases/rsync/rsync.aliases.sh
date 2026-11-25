# shellcheck shell=bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# 🆁🆂🆈🅽🅲 🅰🅻🅸🅰🆂🅴🆂

if command -v 'rsync' >/dev/null; then

  # Rsync with verbose and progress.
  alias rs='rsync -avz'

  # Rsync with verbose and progress.
  alias rsync='rs'
fi
