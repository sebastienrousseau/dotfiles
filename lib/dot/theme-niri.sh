#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# The niri target of dot-theme-sync, which sources this file: a config.kdl
# that chezmoi manages goes through chezmoi; the usual unmanaged one is
# rendered from the template, or skipped. Uses _skip and CHEZMOI_SRC from
# dot-theme-sync.
# Sourced by dot-theme-sync; inherits set -euo pipefail
#
# Bash 3.2 compatible (macOS /bin/bash).

# _theme_niri_managed <target>: whether chezmoi manages the niri config.
# The niri feature flag keeps .config/niri in .chezmoiignore, so a config
# on disk is usually unmanaged, and applying it through chezmoi fails with
# "not managed", a failure that once rolled back every switch here.
_theme_niri_managed() {
  chezmoi managed --include files --path-style absolute 2>/dev/null | grep -Fxq -- "$1"
}

# _theme_render_niri_template <target>: render the niri template straight
# over an unmanaged config. niri is optional, so no template, or a render
# that fails, is noted and returns 1 without failing the switch. When niri
# is installed the render must also pass `niri validate`: a config niri
# cannot parse makes it fall back to its defaults at the next login. The
# temp file sits beside the target so relative includes resolve.
_theme_render_niri_template() {
  local target="$1" template="$CHEZMOI_SRC/dot_config/niri/config.kdl.tmpl" tmp_file
  if [[ ! -f "$template" ]]; then
    _skip "Niri" "config.kdl is not managed by chezmoi and there is no template to render"
    return 1
  fi
  tmp_file="$(umask 077 && mktemp "$(dirname "$target")/.config.kdl.XXXXXX")"
  if ! chezmoi execute-template <"$template" >"$tmp_file" 2>/dev/null; then
    rm -f "$tmp_file"
    _skip "Niri" "config.kdl is not managed by chezmoi and its template did not render"
    return 1
  fi
  if command -v niri >/dev/null 2>&1 && ! niri validate -c "$tmp_file" >/dev/null 2>&1; then
    rm -f "$tmp_file"
    _skip "Niri" "the rendered config.kdl failed niri validate; the current one is kept"
    return 1
  fi
  if mv "$tmp_file" "$target"; then
    return 0
  fi
  rm -f "$tmp_file"
  _skip "Niri" "the rendered config.kdl could not replace the current one"
  return 1
}
