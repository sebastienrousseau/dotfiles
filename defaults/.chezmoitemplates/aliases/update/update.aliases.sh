# shellcheck shell=bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# `update` and `upd` are now `dot update`. They forward to it, with a
# warning, until 0.2.538, when this file goes.

update() {
  printf "%s\n" "'update' is deprecated; use 'dot update' (it stops working in 0.2.538)" >&2
  dot update "$@"
}

upd() {
  printf "%s\n" "'upd' is deprecated; use 'dot update' (it stops working in 0.2.538)" >&2
  dot update "$@"
}
