#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# 🅰🆁🅲🅷🅸🆅🅴🆁 🅰🅻🅸🅰🆂🅴🆂
if command -v 7z &>/dev/null; then
  alias c7z='7z a' # c7z: Compress a whole directory (including subdirectories) to a 7z file.
  alias e7z='7z x' # e7z: Extract a whole directory (including subdirectories) from a 7z file.
fi

if command -v tar &>/dev/null; then
  alias cbz='tar -cvjf' # cbz: Compress a whole directory (including subdirectories) to a bz2 file.
  alias cgz='tar -zcvf' # cgz: Compress a whole directory (including subdirectories) to a tarball.
  alias cxz='tar -cvJf' # cxz: Compress a whole directory (including subdirectories) to a xz file.
  alias ebz='tar -xvjf' # ebz: Extract a whole directory (including subdirectories) from a bz2 file.
  alias egz='tar -xvzf' # egz: Extract a whole directory (including subdirectories)
  alias exz='tar -xvJf' # exz: Extract a whole directory (including subdirectories) from a xz file.
fi

if command -v jar &>/dev/null; then
  alias cear='jar cvf' # cear: Compress a whole directory (including subdirectories) to a ear file.
  alias cjar='jar cvf' # cjar: Compress a whole directory (including subdirectories) to a jar file.
  alias cwar='jar cvf' # cwar: Compress a whole directory (including subdirectories) to a war file.
  alias eear='jar xvf' # eear: Extract a whole directory (including subdirectories) from a ear file.
  alias ejar='jar xvf' # ejar: Extract a whole directory (including subdirectories) from a jar file.
  alias ewar='jar xvf' # ewar: Extract a whole directory (including subdirectories) from a war file.
fi

if command -v zip &>/dev/null; then
  alias czip='zip -r' # czip: Compress a whole directory (including subdirectories) to a zip file.
  alias ezip='unzip'  # ezip: Extract a whole directory (including subdirectories) from a zip file.
fi
