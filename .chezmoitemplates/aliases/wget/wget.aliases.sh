# shellcheck shell=bash
# Copyright (c) 2015-2026 . All rights reserved.
# 🆆🅶🅴🆃 🅰🅻🅸🅰🆂🅴🆂
if command -v 'wget' >/dev/null; then

  # wget.
  alias wg='wget'

  # wget with continue.
  alias wgc='wg'

  # wget with robots=off.
  alias wge='wg -e robots=off'

  # wget with continue.
  alias wget='wget -c'
fi
