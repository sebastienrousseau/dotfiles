# shellcheck shell=bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Font Management Aliases

# List installed fonts (if fc-list available)
alias list-fonts='fc-list : family | sort | uniq'
