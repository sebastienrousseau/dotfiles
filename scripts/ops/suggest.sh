#!/usr/bin/env bash
# AI-powered suggestions for dotfiles optimization
# Usage: dot suggest [aliases|tools|config|all]
#
# Analyzes your shell history and environment to suggest:
# - Aliases for frequently typed commands
# - Tools that could improve your workflow
# - Configuration optimizations
# - Profile recommendations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"
# shellcheck source=../dot/lib/platform.sh
source "$SCRIPT_DIR/../dot/lib/platform.sh"

ui_init

# =============================================================================
# Configuration
# =============================================================================

HISTORY_FILE="${HISTFILE:-$HOME/.zsh_history}"
MIN_FREQUENCY=5          # Minimum command frequency to suggest alias
MIN_LENGTH=10            # Minimum command length to consider
MAX_SUGGESTIONS=10       # Maximum suggestions per category

# =============================================================================
# History Analysis
# =============================================================================

analyze_history() {
  local hist_file="$1"
  local min_freq="$2"

  if [[ ! -f "$hist_file" ]]; then
    return 1
  fi

  # Extract commands, normalize, count frequency
  # Handle both zsh extended history format and plain format
  if grep -q '^:' "$hist_file" 2>/dev/null; then
    # Zsh extended history format: : timestamp:0;command
    sed -n 's/^: [0-9]*:[0-9]*;//p' "$hist_file"
  else
    cat "$hist_file"
  fi | \
    # Remove leading/trailing whitespace
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
    # Filter out very short commands
    awk "length > $MIN_LENGTH" | \
    # Count frequency
    sort | uniq -c | sort -rn | \
    # Filter by minimum frequency
    awk -v min="$min_freq" '$1 >= min {$1=""; print substr($0,2)}'
}

# =============================================================================
# Alias Suggestions
# =============================================================================

suggest_aliases() {
  ui_header "Alias Suggestions"
  echo ""

  if [[ ! -f "$HISTORY_FILE" ]]; then
    ui_warn "History" "No history file found at $HISTORY_FILE"
    return 1
  fi

  local suggestions=0
  local existing_aliases
  existing_aliases=$(alias 2>/dev/null | cut -d= -f1 | tr -d "'" | sort -u)

  echo "  Analyzing your command history..."
  echo ""

  # Find frequent commands that could be aliased
  while IFS= read -r cmd; do
    [[ -z "$cmd" ]] && continue
    ((suggestions >= MAX_SUGGESTIONS)) && break

    # Extract the base command
    local base_cmd="${cmd%% *}"

    # Skip if already has an alias
    if echo "$existing_aliases" | grep -qw "$base_cmd"; then
      continue
    fi

    # Skip common short commands
    case "$base_cmd" in
      cd|ls|git|vim|cat|echo|exit|clear|pwd) continue ;;
    esac

    # Generate alias suggestion
    local alias_name=""
    local full_cmd="$cmd"

    case "$cmd" in
      "git status"*)
        alias_name="gs"
        ;;
      "git diff"*)
        alias_name="gd"
        ;;
      "git add"*)
        alias_name="ga"
        ;;
      "git commit"*)
        alias_name="gc"
        ;;
      "git push"*)
        alias_name="gp"
        ;;
      "git pull"*)
        alias_name="gl"
        ;;
      "docker ps"*)
        alias_name="dps"
        ;;
      "docker compose"*)
        alias_name="dc"
        ;;
      "kubectl get"*)
        alias_name="kg"
        ;;
      "npm run"*)
        alias_name="nr"
        ;;
      "python -m pytest"*|"pytest"*)
        alias_name="pt"
        ;;
      "cargo build"*)
        alias_name="cb"
        ;;
      "cargo run"*)
        alias_name="cr"
        ;;
      "cargo test"*)
        alias_name="ct"
        ;;
      *)
        # Generate alias from first letters
        local words
        read -ra words <<< "$cmd"
        if [[ ${#words[@]} -ge 2 ]]; then
          alias_name=""
          for word in "${words[@]:0:3}"; do
            alias_name+="${word:0:1}"
          done
        fi
        ;;
    esac

    if [[ -n "$alias_name" ]] && ! echo "$existing_aliases" | grep -qw "$alias_name"; then
      if [[ "$UI_COLOR" = "1" ]]; then
        printf "  %s%-6s%s → %s\n" "$CYAN" "$alias_name" "$NORMAL" "$full_cmd"
      else
        printf "  %-6s → %s\n" "$alias_name" "$full_cmd"
      fi
      ((suggestions++))
    fi
  done < <(analyze_history "$HISTORY_FILE" "$MIN_FREQUENCY" | head -50)

  if [[ $suggestions -eq 0 ]]; then
    ui_info "None" "No new alias suggestions found"
  else
    echo ""
    ui_info "Tip" "Add aliases to ~/.config/shell/custom/aliases.sh"
  fi
}

# =============================================================================
# Tool Suggestions
# =============================================================================

suggest_tools() {
  ui_header "Tool Suggestions"
  echo ""

  local suggestions=0

  # Check for missing modern replacements
  check_tool_replacement() {
    local old="$1"
    local new="$2"
    local desc="$3"

    if command -v "$old" >/dev/null 2>&1 && ! command -v "$new" >/dev/null 2>&1; then
      if [[ "$UI_COLOR" = "1" ]]; then
        printf "  %s%s%s → %s%s%s: %s\n" "$YELLOW" "$old" "$NORMAL" "$GREEN" "$new" "$NORMAL" "$desc"
      else
        printf "  %s → %s: %s\n" "$old" "$new" "$desc"
      fi
      ((suggestions++))
    fi
  }

  echo "  Modern tool replacements:"
  echo ""

  check_tool_replacement "cat" "bat" "Syntax highlighting, git integration"
  check_tool_replacement "ls" "eza" "Icons, git status, tree view"
  check_tool_replacement "find" "fd" "Faster, intuitive syntax"
  check_tool_replacement "grep" "rg" "Ripgrep - 10x faster"
  check_tool_replacement "top" "btop" "Beautiful system monitor"
  check_tool_replacement "du" "dust" "Visual disk usage"
  check_tool_replacement "df" "duf" "Better disk free display"
  check_tool_replacement "sed" "sd" "Simpler syntax"
  check_tool_replacement "curl" "xh" "Colored output, easier syntax"
  check_tool_replacement "man" "tldr" "Simplified examples"

  echo ""

  # Check for workflow tools
  echo "  Workflow enhancements:"
  echo ""

  if ! command -v fzf >/dev/null 2>&1; then
    ui_bullet "fzf: Fuzzy finder for files, history, and more"
    ((suggestions++))
  fi

  if ! command -v zoxide >/dev/null 2>&1; then
    ui_bullet "zoxide: Smarter cd that learns your habits"
    ((suggestions++))
  fi

  if ! command -v starship >/dev/null 2>&1; then
    ui_bullet "starship: Fast, customizable prompt"
    ((suggestions++))
  fi

  if ! command -v lazygit >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
    ui_bullet "lazygit: Terminal UI for git"
    ((suggestions++))
  fi

  if ! command -v delta >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
    ui_bullet "delta: Beautiful git diffs"
    ((suggestions++))
  fi

  if ! command -v atuin >/dev/null 2>&1; then
    ui_bullet "atuin: Magical shell history with sync"
    ((suggestions++))
  fi

  echo ""

  if [[ $suggestions -eq 0 ]]; then
    ui_ok "Complete" "You have all recommended tools installed!"
  else
    ui_info "Install" "Run: dot tools install <tool>"
  fi
}

# =============================================================================
# Config Suggestions
# =============================================================================

suggest_config() {
  ui_header "Configuration Suggestions"
  echo ""

  local suggestions=0

  # Check shell startup time
  local startup_time
  startup_time=$( { time zsh -i -c exit; } 2>&1 | grep real | sed 's/real[[:space:]]*//' | sed 's/s$//' )

  if command -v bc >/dev/null 2>&1; then
    # Convert to milliseconds if possible
    local ms
    ms=$(echo "$startup_time * 1000" | bc 2>/dev/null | cut -d. -f1)
    if [[ -n "$ms" ]] && [[ "$ms" -gt 200 ]]; then
      ui_warn "Startup" "Shell starts in ${ms}ms (target: <200ms)"
      ui_bullet "Try: DOTFILES_FAST=1 for faster startup"
      ((suggestions++))
    else
      ui_ok "Startup" "Shell starts in ${ms:-$startup_time}ms"
    fi
  fi

  echo ""

  # Check for common misconfigurations
  if [[ -z "${EDITOR:-}" ]]; then
    ui_warn "EDITOR" "Not set - some tools may not work correctly"
    ui_bullet "Add to ~/.zshrc.local: export EDITOR=nvim"
    ((suggestions++))
  fi

  if [[ -z "${VISUAL:-}" ]]; then
    ui_warn "VISUAL" "Not set"
    ui_bullet "Add: export VISUAL=\$EDITOR"
    ((suggestions++))
  fi

  # Check git config
  if command -v git >/dev/null 2>&1; then
    if [[ -z "$(git config --global user.name 2>/dev/null)" ]]; then
      ui_warn "Git" "user.name not set"
      ((suggestions++))
    fi
    if [[ -z "$(git config --global user.email 2>/dev/null)" ]]; then
      ui_warn "Git" "user.email not set"
      ((suggestions++))
    fi
    if [[ -z "$(git config --global user.signingkey 2>/dev/null)" ]]; then
      ui_info "Git" "Commit signing not configured"
      ui_bullet "Run: dot setup to configure"
      ((suggestions++))
    fi
  fi

  echo ""

  # Check for unused features
  local profile="${DOTFILES_PROFILE:-laptop}"
  echo "  Profile: $profile"
  echo ""

  case "$profile" in
    minimal)
      if command -v docker >/dev/null 2>&1; then
        ui_info "Profile" "Docker detected - consider 'laptop' profile"
        ((suggestions++))
      fi
      ;;
    server)
      if dot_has_gui 2>/dev/null; then
        ui_info "Profile" "GUI detected - consider 'laptop' profile"
        ((suggestions++))
      fi
      ;;
  esac

  if [[ $suggestions -eq 0 ]]; then
    ui_ok "Config" "Your configuration looks good!"
  fi
}

# =============================================================================
# Profile Recommendations
# =============================================================================

suggest_profile() {
  ui_header "Profile Recommendations"
  echo ""

  local detected_features=()
  local recommended_profile="laptop"

  # Detect installed tools and suggest profile
  command -v docker >/dev/null 2>&1 && detected_features+=("docker")
  command -v kubectl >/dev/null 2>&1 && detected_features+=("kubernetes")
  command -v terraform >/dev/null 2>&1 && detected_features+=("terraform")
  command -v aws >/dev/null 2>&1 && detected_features+=("aws")
  command -v nvim >/dev/null 2>&1 && detected_features+=("nvim")
  command -v code >/dev/null 2>&1 && detected_features+=("vscode")
  command -v node >/dev/null 2>&1 && detected_features+=("nodejs")
  command -v python3 >/dev/null 2>&1 && detected_features+=("python")
  command -v rustc >/dev/null 2>&1 && detected_features+=("rust")
  command -v go >/dev/null 2>&1 && detected_features+=("go")

  echo "  Detected tools: ${detected_features[*]:-none}"
  echo ""

  # Determine recommended profile
  if [[ " ${detected_features[*]} " =~ " kubernetes " ]] || \
     [[ " ${detected_features[*]} " =~ " terraform " ]] || \
     [[ " ${detected_features[*]} " =~ " aws " ]]; then
    recommended_profile="devops"
  elif [[ ${#detected_features[@]} -ge 5 ]]; then
    recommended_profile="workstation"
  elif dot_is_container 2>/dev/null || ! dot_has_gui 2>/dev/null; then
    recommended_profile="server"
  fi

  local current_profile="${DOTFILES_PROFILE:-laptop}"

  if [[ "$current_profile" == "$recommended_profile" ]]; then
    ui_ok "Profile" "Current profile '$current_profile' matches your setup"
  else
    ui_info "Suggestion" "Consider switching to '$recommended_profile' profile"
    echo ""
    echo "  Current: $current_profile"
    echo "  Suggested: $recommended_profile"
    echo ""
    echo "  To change: dot setup"
  fi
}

# =============================================================================
# AI Enhancement (Optional)
# =============================================================================

suggest_with_ai() {
  ui_header "AI-Enhanced Suggestions"
  echo ""

  # Check for AI tools
  if command -v claude >/dev/null 2>&1; then
    ui_info "AI" "Claude CLI available - enhanced suggestions possible"
    echo ""
    echo "  For AI-powered analysis, run:"
    echo "    claude \"Analyze my shell history and suggest optimizations\""
  elif command -v gh >/dev/null 2>&1 && gh copilot --help >/dev/null 2>&1; then
    ui_info "AI" "GitHub Copilot available"
    echo ""
    echo "  For AI suggestions, run:"
    echo "    gh copilot suggest \"optimize my shell configuration\""
  else
    ui_info "AI" "No AI CLI tools detected"
    echo ""
    echo "  Install Claude CLI or GitHub Copilot for enhanced suggestions"
  fi
}

# =============================================================================
# Main
# =============================================================================

show_help() {
  cat <<EOF
Usage: dot suggest [CATEGORY]

Analyze your environment and suggest improvements.

Categories:
  aliases    Suggest aliases for frequent commands
  tools      Suggest modern tool replacements
  config     Check configuration for issues
  profile    Recommend optimal profile
  ai         AI-enhanced suggestions (requires Claude/Copilot)
  all        Run all suggestion categories (default)

Examples:
  dot suggest              # Run all suggestions
  dot suggest aliases      # Only alias suggestions
  dot suggest tools        # Only tool suggestions
EOF
}

main() {
  local category="${1:-all}"

  case "$category" in
    -h|--help)
      show_help
      ;;
    aliases)
      suggest_aliases
      ;;
    tools)
      suggest_tools
      ;;
    config)
      suggest_config
      ;;
    profile)
      suggest_profile
      ;;
    ai)
      suggest_with_ai
      ;;
    all)
      suggest_aliases
      echo ""
      suggest_tools
      echo ""
      suggest_config
      echo ""
      suggest_profile
      echo ""
      suggest_with_ai
      ;;
    *)
      echo "Unknown category: $category"
      show_help
      exit 1
      ;;
  esac
}

main "$@"
