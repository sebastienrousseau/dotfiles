#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

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

ui_init

run_step() {
  local title="$1"
  shift
  local out
  out="$(mktemp)"
  if [[ "$UI_ENABLED" = "1" ]]; then
    if gum spin --spinner dot --title "$title" -- "$@" >"$out" 2>&1; then
      ui_ok "$title"
      if [[ "${DOTFILES_CHEZMOI_VERBOSE:-0}" = "1" ]] && [[ -s "$out" ]]; then
        cat "$out"
      fi
    else
      ui_err "$title"
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

ui_header "Applying dotfiles"
if [[ "${DOTFILES_ALIAS_STRICT_MODE:-0}" == "1" ]]; then
  governance_script="$SCRIPT_DIR/../diagnostics/alias-governance.sh"
  if [[ -f "$governance_script" ]]; then
    run_step "Alias governance (strict)" env DOTFILES_ALIAS_POLICY=strict bash "$governance_script"
  fi
fi
run_step "Chezmoi apply" chezmoi apply "${args[@]}"

check_ai_cli() {
  local name="$1"
  local label="$2"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "NOT FOUND: $label"
  fi
}

echo ""
ui_header "AI provider CLI checks (optional)"
if command -v claude >/dev/null 2>&1; then
  ui_ok "claude"
else
  ui_err "claude" "recommended — install to enable this provider"
fi
if command -v gemini >/dev/null 2>&1; then
  ui_ok "gemini"
else
  ui_err "gemini" "optional — install to enable this provider"
fi
if command -v sgpt >/dev/null 2>&1; then
  ui_ok "sgpt"
else
  ui_err "sgpt" "optional — install to enable this provider"
fi
if command -v ollama >/dev/null 2>&1; then
  ui_ok "ollama"
else
  ui_err "ollama" "optional — install to enable this provider"
fi
if command -v opencode >/dev/null 2>&1; then
  ui_ok "opencode"
else
  ui_err "opencode" "optional — install to enable this provider"
fi
if command -v aider >/dev/null 2>&1; then
  ui_ok "aider"
else
  ui_err "aider" "optional — AI pair programming"
fi

if [[ "${DOTFILES_CHEZMOI_STATUS:-1}" = "1" ]]; then
  printf "\n"
  ui_header "Status"
  status_out="$(chezmoi status || true)"
  if [[ -z "$status_out" ]]; then
    ui_ok "Clean"
  else
    printf "%s\n" "$status_out"
  fi
fi
