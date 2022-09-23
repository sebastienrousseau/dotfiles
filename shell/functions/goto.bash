#! /bin/bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)
# https://dotfiles.io
#
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# Licensed under the MIT license
#


# goto: Function to change to the directory inputed
goto() {
  if [ -e "$1" ]; then
	  cd "$1" || exit; l
  else
	  echo "[ERROR] Please add a directory name" >&2
  fi
}
