# shellcheck shell=bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# remove_disk: spin down unneeded disk
remove_disk() {
  diskutil eject "$1"
}
