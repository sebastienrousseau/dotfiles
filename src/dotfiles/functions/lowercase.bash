#!/bin/zsh
#!/usr/bin/env sh
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)
# https://dotfiles.io
#
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# Licensed under the MIT license
#


# lowercase: Function to move filenames or directory names to lowercase
function lowercase()
{
  if [[ "$#" != 1 ]]; then
    echo "[ERROR] The filename or directory name is incorrect." >&2
    return 1
  fi
  for file ; do
      filename=${file##*/}
      case "$filename" in
      */*) dirname==${file%/*} ;;
      *) dirname=.;;
      esac
      nf=$(echo $filename | tr A-Z a-z)
      newname="${dirname}/${nf}"
      if [ "$nf" != "$filename" ]; then
          mv "$file" "$newname"
          echo "[INFO] Renaming $file to lowercase: $newname"
      else
          echo "[ERROR] The operation is not valid, $file has not changed."
      fi
  done
}