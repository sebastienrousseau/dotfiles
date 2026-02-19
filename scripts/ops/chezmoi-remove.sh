#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: dot remove <path> [--source] [--dry-run]" >&2
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
  echo "No path provided." >&2
  exit 1
fi

if [[ $remove_source -eq 0 ]]; then
  args+=("--keep-source")
fi

printf "About to run: chezmoi remove %s %s\n" "${args[*]}" "${paths[*]}"
read -r -p "Proceed? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  exit 1
fi

chezmoi remove "${args[@]}" "${paths[@]}"
