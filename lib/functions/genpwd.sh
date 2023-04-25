#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# genpwd: Function to generates a strong random password of 20 characters (similar to Apple)
genpwd() {
  m=$(openssl rand -base64 32 | cut -c 1-6 || true)
  a=$(openssl rand -base64 32 | cut -c 1-6 || true)
  c=$(openssl rand -base64 32 | cut -c 1-6 || true)
  pwd="${m}-${a}-${c}"
  echo "[INFO] The password has been copied to the clipboard: ${pwd}"
  echo "${pwd}" | pbcopy | pbpaste || true
}
