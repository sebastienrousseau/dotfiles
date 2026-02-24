#!/usr/bin/env bash
# Interactive setup wizard for dotfiles
# Usage: dot setup [--quick]
#
# A guided experience for configuring your development environment.
# Uses gum for enhanced TUI when available, falls back gracefully.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init

# Configuration paths
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi"
CONFIG_FILE="$CONFIG_DIR/chezmoi.toml"
DOTFILES_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.dotfiles}"
mkdir -p "$CONFIG_DIR"

# Setup state
QUICK_MODE=0
CURRENT_STEP=0
TOTAL_STEPS=6

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick | -q)
      QUICK_MODE=1
      shift
      ;;
    *) shift ;;
  esac
done

# =============================================================================
# UI Helpers
# =============================================================================

choose() {
  local prompt="$1"
  shift
  if command -v gum >/dev/null 2>&1 && [[ -t 1 ]]; then
    gum choose --cursor.foreground=212 --selected.foreground=212 --header "$prompt" "$@"
  else
    echo "$prompt" >&2
    select opt in "$@"; do
      echo "$opt"
      return
    done
  fi
}

confirm() {
  local prompt="$1"
  local default="${2:-n}"
  if command -v gum >/dev/null 2>&1 && [[ -t 1 ]]; then
    if [[ "$default" == "y" ]]; then
      gum confirm --default=yes "$prompt"
    else
      gum confirm "$prompt"
    fi
  else
    local hint="[y/N]"
    [[ "$default" == "y" ]] && hint="[Y/n]"
    read -r -p "$prompt $hint: " ans
    if [[ "$default" == "y" ]]; then
      [[ ! "$ans" =~ ^[Nn]$ ]]
    else
      [[ "$ans" =~ ^[Yy]$ ]]
    fi
  fi
}

input() {
  local prompt="$1"
  local default="${2:-}"
  local placeholder="${3:-}"
  if command -v gum >/dev/null 2>&1 && [[ -t 1 ]]; then
    gum input --placeholder "$placeholder" --value "$default" --header "$prompt"
  else
    read -r -p "$prompt [$default]: " ans
    echo "${ans:-$default}"
  fi
}

spin() {
  local title="$1"
  shift
  if command -v gum >/dev/null 2>&1 && [[ -t 1 ]]; then
    gum spin --spinner dot --title "$title" -- "$@"
  else
    echo "$title..."
    "$@"
  fi
}

progress_bar() {
  local current="$1"
  local total="$2"
  local width=30
  local filled=$((current * width / total))
  local empty=$((width - filled))

  if [[ "$UI_COLOR" = "1" ]]; then
    printf "\r  %s[" "$GRAY"
    printf "%s" "${GREEN}"
    printf '█%.0s' $(seq 1 $filled 2>/dev/null) || true
    printf "%s" "$GRAY"
    printf '░%.0s' $(seq 1 $empty 2>/dev/null) || true
    printf "]%s Step %d/%d" "$NORMAL" "$current" "$total"
  else
    printf "\r  [Step %d/%d]" "$current" "$total"
  fi
}

step_header() {
  local title="$1"
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo ""
  progress_bar "$CURRENT_STEP" "$TOTAL_STEPS"
  echo ""
  ui_section "$title"
  echo ""
}

# =============================================================================
# Welcome Screen
# =============================================================================

show_welcome() {
  clear 2>/dev/null || true
  ui_logo_dot "Dotfiles Setup Wizard"

  if command -v gum >/dev/null 2>&1 && [[ -t 1 ]]; then
    gum style --border rounded --padding "1 2" --border-foreground 212 \
      "Welcome to the dotfiles setup wizard!" \
      "" \
      "This will configure your development environment." \
      "You can re-run this anytime with: dot setup"
  else
    echo "  Welcome to the dotfiles setup wizard!"
    echo ""
    echo "  This will configure your development environment."
    echo "  You can re-run this anytime with: dot setup"
  fi
  echo ""

  if [[ "$QUICK_MODE" == "0" ]]; then
    confirm "Ready to begin?" "y" || exit 0
  fi
}

# =============================================================================
# Step 1: Profile Selection
# =============================================================================

step_profile() {
  step_header "Profile Selection"

  echo "  Profiles determine which tools and features are enabled:"
  echo ""
  ui_bullet "laptop    - Full development (recommended for personal machines)"
  ui_bullet "desktop   - Same as laptop with extra GUI tools"
  ui_bullet "workstation - Everything including enterprise tools"
  ui_bullet "server    - Headless, minimal, optimized for SSH"
  ui_bullet "minimal   - Bare essentials only"
  ui_bullet "work      - Corporate environment with strict policies"
  echo ""

  PROFILE=$(choose "Select your profile" laptop desktop workstation server minimal work)
  ui_ok "Profile" "$PROFILE"
}

# =============================================================================
# Step 2: Git Identity
# =============================================================================

step_git_identity() {
  step_header "Git Identity"

  # Try to detect existing git config
  local current_name current_email
  current_name="$(git config --global user.name 2>/dev/null || echo "")"
  current_email="$(git config --global user.email 2>/dev/null || echo "")"

  echo "  Configure your Git identity for commits."
  echo ""

  GIT_NAME=$(input "Your name" "$current_name" "John Doe")
  GIT_EMAIL=$(input "Your email" "$current_email" "john@example.com")

  # Signing key (optional)
  GIT_SIGNINGKEY=""
  if [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
    if confirm "Use SSH key for commit signing?" "y"; then
      GIT_SIGNINGKEY="$HOME/.ssh/id_ed25519"
      ui_ok "Signing" "SSH key configured"
    fi
  fi

  ui_ok "Identity" "$GIT_NAME <$GIT_EMAIL>"
}

# =============================================================================
# Step 3: Features
# =============================================================================

step_features() {
  step_header "Feature Selection"

  echo "  Enable or disable optional features:"
  echo ""

  # Set defaults based on profile
  case "$PROFILE" in
    minimal)
      FEAT_ZSH=true
      FEAT_NVIM=false
      FEAT_TMUX=false
      FEAT_GUI=false
      FEAT_SECRETS=false
      FEAT_AI=false
      ;;
    server)
      FEAT_ZSH=true
      FEAT_NVIM=true
      FEAT_TMUX=true
      FEAT_GUI=false
      FEAT_SECRETS=true
      FEAT_AI=false
      ;;
    work)
      FEAT_ZSH=true
      FEAT_NVIM=true
      FEAT_TMUX=true
      FEAT_GUI=true
      FEAT_SECRETS=true
      FEAT_AI=true
      ;;
    *)
      FEAT_ZSH=true
      FEAT_NVIM=true
      FEAT_TMUX=true
      FEAT_GUI=true
      FEAT_SECRETS=true
      FEAT_AI=true
      ;;
  esac

  if [[ "$QUICK_MODE" == "0" ]]; then
    confirm "Zsh shell configuration?" "y" && FEAT_ZSH=true || FEAT_ZSH=false
    confirm "Neovim editor configuration?" "y" && FEAT_NVIM=true || FEAT_NVIM=false
    confirm "tmux terminal multiplexer?" "y" && FEAT_TMUX=true || FEAT_TMUX=false
    confirm "GUI extras (fonts, themes)?" "y" && FEAT_GUI=true || FEAT_GUI=false
    confirm "Secrets management (age encryption)?" "y" && FEAT_SECRETS=true || FEAT_SECRETS=false
    confirm "AI tools (Claude, Copilot configs)?" "y" && FEAT_AI=true || FEAT_AI=false
  fi

  ui_ok "Features" "$(echo "$FEAT_ZSH,$FEAT_NVIM,$FEAT_TMUX,$FEAT_GUI,$FEAT_SECRETS,$FEAT_AI" | tr ',' ' ')"
}

# =============================================================================
# Step 4: Theme
# =============================================================================

step_theme() {
  step_header "Appearance"

  echo "  Choose your color theme:"
  echo ""

  THEME=$(choose "Select theme" \
    "catppuccin-mocha (dark, warm)" \
    "catppuccin-latte (light)" \
    "tokyonight-night (dark, blue)" \
    "tokyonight-day (light, blue)" \
    "gruvbox-dark" \
    "nord")

  # Extract theme name
  THEME="${THEME%% *}"

  ui_ok "Theme" "$THEME"
}

# =============================================================================
# Step 5: Generate Config
# =============================================================================

step_generate_config() {
  step_header "Configuration"

  echo "  Generating chezmoi configuration..."
  echo ""

  # Backup existing config
  if [[ -f "$CONFIG_FILE" ]]; then
    local backup="$CONFIG_DIR/chezmoi.toml.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_FILE" "$backup"
    ui_info "Backup" "$backup"
  fi

  # Generate config
  cat >"$CONFIG_FILE" <<TOML
# Generated by dot setup - $(date +%Y-%m-%d)
[data]
profile = "$PROFILE"
theme = "$THEME"
name = "$GIT_NAME"
email = "$GIT_EMAIL"
signingkey = "$GIT_SIGNINGKEY"

[data.features]
zsh = $FEAT_ZSH
nvim = $FEAT_NVIM
tmux = $FEAT_TMUX
gui = $FEAT_GUI
secrets = $FEAT_SECRETS
ai_tools = $FEAT_AI

[data.aliases]
profile = "standard"

[data.aliases.policy]
strict_mode = $([ "$PROFILE" = "work" ] && echo "true" || echo "false")

[data.aliases.buckets]
system = true
svn = true

[data.secrets.policy]
provider = "auto"
auto_load = true
TOML

  ui_ok "Config" "Written to $CONFIG_FILE"
}

# =============================================================================
# Step 6: Apply & Health Check
# =============================================================================

step_apply() {
  step_header "Apply Configuration"

  echo "  Ready to apply your dotfiles configuration."
  echo ""

  if confirm "Apply dotfiles now?" "y"; then
    if command -v chezmoi >/dev/null 2>&1; then
      echo ""
      spin "Applying dotfiles" chezmoi apply --force
      ui_ok "Apply" "Complete"

      # Run health check
      echo ""
      ui_section "Health Check"
      echo ""
      run_health_check
    else
      ui_warn "chezmoi" "Not installed - run install.sh first"
    fi
  else
    ui_info "Skipped" "Run 'chezmoi apply' when ready"
  fi
}

run_health_check() {
  local issues=0

  # Check shell
  if [[ "$SHELL" == *"zsh"* ]] || command -v zsh >/dev/null 2>&1; then
    ui_ok "Shell" "Zsh available"
  else
    ui_warn "Shell" "Zsh not installed"
    ((issues++))
  fi

  # Check editor
  if command -v nvim >/dev/null 2>&1; then
    ui_ok "Editor" "Neovim $(nvim --version | head -1 | cut -d' ' -f2)"
  elif [[ "$FEAT_NVIM" == "true" ]]; then
    ui_warn "Editor" "Neovim not installed"
    ((issues++))
  fi

  # Check git signing
  if [[ -n "$GIT_SIGNINGKEY" ]] && [[ -f "$GIT_SIGNINGKEY" ]]; then
    ui_ok "Signing" "SSH key ready"
  fi

  # Check starship
  if command -v starship >/dev/null 2>&1; then
    ui_ok "Prompt" "Starship $(starship --version | cut -d' ' -f2)"
  else
    ui_warn "Prompt" "Starship not installed"
    ((issues++))
  fi

  # Check AI tools
  if [[ "$FEAT_AI" == "true" ]]; then
    if [[ -f "$HOME/.config/claude/settings.json" ]]; then
      ui_ok "AI Config" "Claude Code configured"
    fi
  fi

  echo ""
  if [[ $issues -eq 0 ]]; then
    ui_ok "Health" "All checks passed!"
  else
    ui_warn "Health" "$issues issue(s) found - run 'dot doctor' for details"
  fi
}

# =============================================================================
# What's Next
# =============================================================================

show_whats_next() {
  echo ""
  ui_header "What's Next?"
  echo ""

  if command -v gum >/dev/null 2>&1 && [[ -t 1 ]]; then
    gum style --border rounded --padding "1 2" --border-foreground 212 \
      "Your dotfiles are configured! Here's what to do next:" \
      "" \
      "  1. Start a new shell or run: exec zsh" \
      "  2. Run 'dot doctor' to check system health" \
      "  3. Run 'dot keys' to see keybindings" \
      "  4. Run 'dot learn' for an interactive tour" \
      "" \
      "Useful commands:" \
      "  dot help      - Show all commands" \
      "  dot theme     - Change color theme" \
      "  dot update    - Update dotfiles" \
      "  dot diff      - Preview changes"
  else
    echo "  Your dotfiles are configured! Here's what to do next:"
    echo ""
    echo "  1. Start a new shell or run: exec zsh"
    echo "  2. Run 'dot doctor' to check system health"
    echo "  3. Run 'dot keys' to see keybindings"
    echo "  4. Run 'dot learn' for an interactive tour"
    echo ""
    echo "  Useful commands:"
    echo "    dot help      - Show all commands"
    echo "    dot theme     - Change color theme"
    echo "    dot update    - Update dotfiles"
    echo "    dot diff      - Preview changes"
  fi
  echo ""

  if confirm "Open interactive tour now?" "n"; then
    exec bash "$DOTFILES_DIR/scripts/ops/tour.sh"
  fi

  ui_ok "Setup" "Complete! Enjoy your new environment."
  echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
  show_welcome
  step_profile
  step_git_identity
  step_features
  step_theme
  step_generate_config
  step_apply
  show_whats_next
}

main "$@"
