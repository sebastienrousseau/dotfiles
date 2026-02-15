#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck source=../dot/lib/ui.sh
source "$REPO_ROOT/scripts/dot/lib/ui.sh"

if [[ $# -lt 1 ]]; then
  ui_error "Usage: dot remove <path> [--source] [--dry-run]"
  exit 1
fi

remove_source=0
args=()
paths=()

for arg in "$@"; do
  case "$arg" in
    --source)
      remove_source=1
      ;;
    --dry-run)
      args+=("--dry-run")
      ;;
    *)
      paths+=("$arg")
      ;;
  esac
done

if [[ ${#paths[@]} -eq 0 ]]; then
  ui_error "No path provided."
  exit 1
fi

if [[ $remove_source -eq 0 ]]; then
  args+=("--keep-source")
fi

ui_logo_dot "Dot Remove • Chezmoi"
ui_info "About to run: chezmoi remove ${args[*]} ${paths[*]}"
if ! ui_ask "Proceed?"; then
  ui_info "Aborted."
  exit 1
fi

chezmoi remove "${args[@]}" "${paths[@]}"
