#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
## `dot cli completion show <shell>` (old name: `dot completion <shell>`) —
## print the completion script for bash, zsh, fish, nu or pwsh.
##
## The scripts are generated from the plugin manifests by
## tools/docs/gen_completions.py and committed; this prints the committed
## file, so completion needs no generator at run time.
##
## Usage:
##   dot cli completion show bash  > ~/.local/share/bash-completion/completions/dot
##   dot cli completion show zsh   > "${fpath[1]}/_dot"
##   dot cli completion show fish  > ~/.config/fish/completions/dot.fish
##   dot cli completion show nu    > ~/.config/nushell/completions.nu
##   dot cli completion show pwsh  >> $PROFILE
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"

# _completion_file SHELL: the committed script for SHELL, relative to the source.
_completion_file() {
  case "$1" in
    bash) echo "defaults/dot_local/share/bash-completion/completions/dot" ;;
    zsh) echo "share/completions/zsh/_dot" ;;
    fish) echo "defaults/dot_config/fish/completions/dot.fish" ;;
    nu | nushell) echo "defaults/dot_config/nushell/completions.nu" ;;
    pwsh | powershell) echo "share/completions/powershell/dot.ps1" ;;
    *) return 1 ;;
  esac
}

usage() {
  cat <<'USAGE'
Usage: dot cli completion show <bash|zsh|fish|nu|pwsh>

Print the completion script for a shell, generated from the plugin manifests.

  dot cli completion show bash  > ~/.local/share/bash-completion/completions/dot
  dot cli completion show zsh   > "${fpath[1]}/_dot"
  dot cli completion show fish  > ~/.config/fish/completions/dot.fish
  dot cli completion show nu    > ~/.config/nushell/completions.nu
  dot cli completion show pwsh  >> $PROFILE
USAGE
}

# Dispatch: $1 is the route ("completion"); $2 is the target shell.
case "${2:-}" in
  "" | -h | --help | help) usage ;;
  *)
    if ! rel="$(_completion_file "$2")"; then
      echo "dot cli completion show: unknown shell '$2' (want: bash|zsh|fish|nu|pwsh)" >&2
      exit 1
    fi
    cat "$(resolve_source_dir)/$rel"
    ;;
esac
