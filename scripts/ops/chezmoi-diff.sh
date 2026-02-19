#!/usr/bin/env bash
set -euo pipefail

excludes=(scripts)
if [[ -n "${DOTFILES_CHEZMOI_DIFF_EXCLUDES:-}" ]]; then
  IFS=',' read -r -a excludes <<<"${DOTFILES_CHEZMOI_DIFF_EXCLUDES}"
fi

args=()
for ex in "${excludes[@]}"; do
  args+=("--exclude" "$ex")
done

chezmoi diff "${args[@]}" "$@"
