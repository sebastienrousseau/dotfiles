# shellcheck shell=bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# ql: Function to open any file in MacOS Quicklook Preview
ql() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ql: macOS only" >&2
    return 1
  fi
  qlmanage -p "$*" >&/dev/null
}
