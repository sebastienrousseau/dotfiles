#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# lowercase: Function to move filenames or directory names to lowercase
lowercase() {
  if [[ "$#" != 1 ]]; then
    echo "[ERROR] The filename or directory name is incorrect." >&2
    return 1
  fi
  for file; do
    filename=${file##*/}
    case "${filename}" in
    */*) [[ "dirname" = "${file%/*}" ]] ;;
    *) dirname=. ;;
    esac
    nf=$(echo "${filename}" | tr '[:upper:]' '[:lower:]')
    newname="${dirname}/${nf}"
    if [[ "${nf}" != "${filename}" ]]; then
      mv "${file}" "${newname}"
      echo "[INFO] Renaming ${file} to lowercase: ${newname}"
    else
      echo "[ERROR] The operation is not valid, ${file} has not changed."
    fi
  done
}
