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

use_ui=0
if command -v gum >/dev/null 2>&1 && [[ -t 1 ]]; then
  use_ui=1
fi

run_step() {
  local title="$1"
  shift
  local out
  out="$(mktemp)"
  if [[ "$use_ui" = "1" ]]; then
    if gum spin --spinner dot --title "$title" -- "$@" >"$out" 2>&1; then
      printf "  ✓ %s\n" "$title"
      if [[ "${DOTFILES_CHEZMOI_VERBOSE:-0}" = "1" ]] && [[ -s "$out" ]]; then
        cat "$out"
      fi
    else
      printf "  ✗ %s\n" "$title"
      cat "$out"
      rm -f "$out"
      exit 1
    fi
  else
    echo "$title..."
    if "$@" >"$out" 2>&1; then
      if [[ "${DOTFILES_CHEZMOI_VERBOSE:-0}" = "1" ]] && [[ -s "$out" ]]; then
        cat "$out"
      fi
    else
      cat "$out"
      rm -f "$out"
      exit 1
    fi
  fi
  rm -f "$out"
}

echo "Applying dotfiles..."
run_step "Chezmoi apply" chezmoi apply "${args[@]}"

check_ai_cli() {
  local name="$1"
  local label="$2"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "NOT FOUND: $label"
  fi
}

echo ""
echo "AI provider CLI checks (optional):"
if command -v claude >/dev/null 2>&1; then
  printf "  ✓ claude\n"
else
  printf "  ✗ claude (recommended — install to enable this provider)\n"
fi
if command -v gemini >/dev/null 2>&1; then
  printf "  ✓ gemini\n"
else
  printf "  ✗ gemini (optional — install to enable this provider)\n"
fi
if command -v sgpt >/dev/null 2>&1; then
  printf "  ✓ sgpt\n"
else
  printf "  ✗ sgpt (optional — install to enable this provider)\n"
fi
if command -v ollama >/dev/null 2>&1; then
  printf "  ✓ ollama\n"
else
  printf "  ✗ ollama (optional — install to enable this provider)\n"
fi
if command -v opencode >/dev/null 2>&1; then
  printf "  ✓ opencode\n"
else
  printf "  ✗ opencode (optional — install to enable this provider)\n"
fi
if command -v aider >/dev/null 2>&1; then
  printf "  ✓ aider\n"
else
  printf "  ✗ aider (optional — AI pair programming)\n"
fi

if [[ "${DOTFILES_CHEZMOI_STATUS:-1}" = "1" ]]; then
  printf "\nStatus:\n"
  status_out="$(chezmoi status || true)"
  if [[ -z "$status_out" ]]; then
    printf "  ✓ Clean\n"
  else
    printf "%s\n" "$status_out"
  fi
fi
