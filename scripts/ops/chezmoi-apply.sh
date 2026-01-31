#!/usr/bin/env bash
set -euo pipefail

args=()
if [[ -n "${DOTFILES_CHEZMOI_APPLY_FLAGS:-}" ]]; then
  # Safely parse space-separated flags into array
  read -ra flag_array <<<"$DOTFILES_CHEZMOI_APPLY_FLAGS"
  args+=("${flag_array[@]}")
fi

if [[ "${DOTFILES_CHEZMOI_VERBOSE:-0}" = "1" ]]; then
  args+=("--verbose")
fi

if [[ "${DOTFILES_CHEZMOI_KEEP_GOING:-0}" = "1" ]]; then
  args+=("--keep-going")
fi

echo "Applying dotfiles..."
chezmoi apply "${args[@]}"

check_ai_cli() {
  local name="$1"
  local label="$2"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "NOT FOUND: $label"
  fi
}

echo ""
echo "AI provider CLI checks (optional):"
check_ai_cli "claude" "claude (recommended — install to enable this provider)"
check_ai_cli "gemini" "gemini (optional — install to enable this provider)"
check_ai_cli "sgpt" "sgpt (optional — install to enable this provider)"
check_ai_cli "ollama" "ollama (optional — install to enable this provider)"
check_ai_cli "opencode" "opencode (optional — install to enable this provider)"

if [[ "${DOTFILES_CHEZMOI_STATUS:-1}" = "1" ]]; then
  printf "\nStatus:\n"
  chezmoi status || true
fi
