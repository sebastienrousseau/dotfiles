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

header() {
  local text="$1"
  if [[ "$use_ui" = "1" ]]; then
    gum style --foreground 212 --bold "$text"
  else
    echo "$text"
  fi
}

format_status() {
  local symbol="$1"
  local label="$2"
  local detail="$3"
  local width=20
  if [[ -n "$detail" ]]; then
    printf "  %-2s %-*s %s\n" "$symbol" "$width" "$label" "$detail"
  else
    printf "  %-2s %s\n" "$symbol" "$label"
  fi
}

run_step() {
  local title="$1"
  shift
  local out
  out="$(mktemp)"
  if [[ "$use_ui" = "1" ]]; then
    if gum spin --spinner dot --title "$title" -- "$@" >"$out" 2>&1; then
      format_status "✓" "$title" ""
      if [[ "${DOTFILES_CHEZMOI_VERBOSE:-0}" = "1" ]] && [[ -s "$out" ]]; then
        cat "$out"
      fi
    else
      format_status "✗" "$title" ""
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

header "Applying dotfiles"
run_step "Chezmoi apply" chezmoi apply "${args[@]}"

check_ai_cli() {
  local name="$1"
  local label="$2"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "NOT FOUND: $label"
  fi
}

echo ""
header "AI provider CLI checks (optional)"
if command -v claude >/dev/null 2>&1; then
  format_status "✓" "claude" ""
else
  format_status "✗" "claude" "recommended — install to enable this provider"
fi
if command -v gemini >/dev/null 2>&1; then
  format_status "✓" "gemini" ""
else
  format_status "✗" "gemini" "optional — install to enable this provider"
fi
if command -v sgpt >/dev/null 2>&1; then
  format_status "✓" "sgpt" ""
else
  format_status "✗" "sgpt" "optional — install to enable this provider"
fi
if command -v ollama >/dev/null 2>&1; then
  format_status "✓" "ollama" ""
else
  format_status "✗" "ollama" "optional — install to enable this provider"
fi
if command -v opencode >/dev/null 2>&1; then
  format_status "✓" "opencode" ""
else
  format_status "✗" "opencode" "optional — install to enable this provider"
fi
if command -v aider >/dev/null 2>&1; then
  format_status "✓" "aider" ""
else
  format_status "✗" "aider" "optional — AI pair programming"
fi

if [[ "${DOTFILES_CHEZMOI_STATUS:-1}" = "1" ]]; then
  printf "\n"
  header "Status"
  status_out="$(chezmoi status || true)"
  if [[ -z "$status_out" ]]; then
    format_status "✓" "Clean" ""
  else
    printf "%s\n" "$status_out"
  fi
fi
