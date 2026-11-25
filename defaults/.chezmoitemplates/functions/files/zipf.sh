# shellcheck shell=bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# zipf: Function to create a ZIP archive of a folder
zipf() {
  if [[ "$#" != 1 ]]; then
    echo "[ERROR] Please add one argument" >&2
    return 1
  fi
  echo "[INFO] Creating the ZIP archive folder $1.zip"
  zip -r "$1".zip "$1"
}
