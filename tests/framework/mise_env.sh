#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Tests run the tools mise installed, never mise's shims. A shim looks its
# tool up from HOME, so one run under a test's sandbox HOME finds no
# installs there and, with auto_install on, downloads the tool into the
# sandbox (about 2.4 GB for python). A non-interactive shell carries the
# shims directory ahead of the install directories, so `command -v` and the
# fixtures' symlinks picked the shim. Sourced by assertions.sh and
# test_runner.sh, before any test changes HOME.

# A tool a sandbox cannot resolve fails instead of downloading.
export MISE_AUTO_INSTALL=false

# dot_test_mise_unshim: replace the mise shims directory on PATH with the
# install directories `mise bin-paths` resolves now, under the real HOME,
# in the shims' place so precedence is kept. Without mise, or when it
# resolves nothing, PATH is left as it is.
dot_test_mise_unshim() {
  local bins="" out="" line entry
  local -a entries
  case ":$PATH:" in
    *"/mise/shims:"*) ;;
    *) return 0 ;;
  esac
  command -v mise >/dev/null 2>&1 || return 0
  while IFS= read -r line; do
    [[ -n "$line" ]] && bins="${bins:+$bins:}$line"
  done < <(MISE_OFFLINE=1 mise bin-paths 2>/dev/null)
  [[ -n "$bins" ]] || return 0
  IFS=: read -ra entries <<<"$PATH"
  for entry in "${entries[@]}"; do
    case "$entry" in
      */mise/shims)
        [[ -n "$bins" ]] && out="${out:+$out:}$bins"
        bins=""
        ;;
      *) out="${out:+$out:}$entry" ;;
    esac
  done
  export PATH="$out"
}

dot_test_mise_unshim
