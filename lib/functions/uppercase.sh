#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2022. All rights reserved
# License: MIT

# uppercase: Function to move filenames or directory names to uppercase
uppercase() {
  if [[ "$#" != 1 ]]; then
    echo "[ERROR] The filename or directory name is incorrect." >&2
    return 1
  fi
  for file; do
    filename=${file##*/}
    case "${filename}" in
    */*) dirname=${file%/*} ;;
    *) dirname=. ;;
    esac
    nf=$(echo "${filename}" | tr '[:upper:]' '[:lower:]')
    newname="${dirname}/${nf}"
    if [[ "${nf}" != "${filename}" ]]; then
      mv "${file}" "${newname}"
      echo "[INFO] Renaming ${file} to uppercase: ${newname}"
    else
      echo "[ERROR] The operation is not valid, ${file} has not changed."
    fi
  done
}
