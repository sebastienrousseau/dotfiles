#!/bin/zsh
#
#  ____        _   _____ _ _
# |  _ \  ___ | |_|  ___(_) | ___  ___
# | | | |/ _ \| __| |_  | | |/ _ \/ __|
# | |_| | (_) | |_|  _| | | |  __/\__ \
# |____/ \___/ \__|_|   |_|_|\___||___/
#
# DotFiles v0.2.449
# https://dotfiles.io
#
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# Licensed under the MIT license
#


# uppercase: Function to move filenames or directory names to uppercase
function uppercase()
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
      nf=$(echo $filename | tr a-z A-Z)
      newname="${dirname}/${nf}"
      if [ "$nf" != "$filename" ]; then
          mv "$file" "$newname"
          echo "[INFO] Renaming $file to uppercase: $newname"
      else
          echo "[ERROR] The operation is not valid, $file has not changed."
      fi
  done
}
