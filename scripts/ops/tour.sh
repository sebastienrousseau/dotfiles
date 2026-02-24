#!/usr/bin/env bash
# Interactive tour of dotfiles capabilities
# Usage: dot learn

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init

# Tour state
CURRENT_PAGE=0
PAGES=(
  "welcome"
  "navigation"
  "editing"
  "git"
  "tools"
  "customization"
  "ai"
  "tips"
  "complete"
)
TOTAL_PAGES=${#PAGES[@]}

# =============================================================================
# UI Helpers
# =============================================================================

press_continue() {
  echo ""
  if command -v gum >/dev/null 2>&1 && [[ -t 1 ]]; then
    gum confirm --default=yes "Continue?" || exit 0
  else
    read -r -p "  Press Enter to continue (q to quit)... " ans
    [[ "$ans" == "q" ]] && exit 0
  fi
}

show_page_header() {
  local title="$1"
  clear 2>/dev/null || true
  ui_logo_dot "Interactive Tour"

  # Progress indicator
  local progress=$((CURRENT_PAGE * 100 / TOTAL_PAGES))
  if [[ "$UI_COLOR" = "1" ]]; then
    printf "  %s[%d/%d]%s %s\n\n" "$GRAY" "$((CURRENT_PAGE + 1))" "$TOTAL_PAGES" "$NORMAL" "$title"
  else
    printf "  [%d/%d] %s\n\n" "$((CURRENT_PAGE + 1))" "$TOTAL_PAGES" "$title"
  fi
}

show_command() {
  local cmd="$1"
  local desc="${2:-}"
  if [[ "$UI_COLOR" = "1" ]]; then
    printf "    %s\$ %s%s" "$GREEN" "$cmd" "$NORMAL"
    [[ -n "$desc" ]] && printf "  %s# %s%s" "$GRAY" "$desc" "$NORMAL"
    printf "\n"
  else
    printf "    \$ %s" "$cmd"
    [[ -n "$desc" ]] && printf "  # %s" "$desc"
    printf "\n"
  fi
}

show_key() {
  local key="$1"
  local desc="$2"
  if [[ "$UI_COLOR" = "1" ]]; then
    printf "    %s%-12s%s %s\n" "$CYAN" "$key" "$NORMAL" "$desc"
  else
    printf "    %-12s %s\n" "$key" "$desc"
  fi
}

# =============================================================================
# Tour Pages
# =============================================================================

page_welcome() {
  show_page_header "Welcome"

  if command -v gum >/dev/null 2>&1 && [[ -t 1 ]]; then
    gum style --border rounded --padding "1 2" --border-foreground 212 \
      "Welcome to your new development environment!" \
      "" \
      "This tour will introduce you to:" \
      "  • Navigation & shell features" \
      "  • File editing with Neovim" \
      "  • Git workflows" \
      "  • Available tools" \
      "  • Customization options" \
      "  • AI assistance"
  else
    echo "  Welcome to your new development environment!"
    echo ""
    echo "  This tour will introduce you to:"
    echo "    • Navigation & shell features"
    echo "    • File editing with Neovim"
    echo "    • Git workflows"
    echo "    • Available tools"
    echo "    • Customization options"
    echo "    • AI assistance"
  fi

  press_continue
}

page_navigation() {
  show_page_header "Navigation"

  echo "  Your shell includes smart navigation tools:"
  echo ""

  ui_section "Directory jumping (zoxide)"
  echo ""
  show_command "z projects" "Jump to 'projects' directory"
  show_command "z doc" "Jump to most frequent dir matching 'doc'"
  show_command "zi" "Interactive directory picker"
  echo ""

  ui_section "Fuzzy finding (fzf)"
  echo ""
  show_command "Ctrl+T" "Fuzzy find files"
  show_command "Ctrl+R" "Fuzzy search history"
  show_command "Alt+C" "Fuzzy change directory"
  echo ""

  ui_section "Modern replacements"
  echo ""
  show_command "ls" "Uses 'eza' with icons and git status"
  show_command "cat" "Uses 'bat' with syntax highlighting"
  show_command "find" "Use 'fd' for faster file finding"
  show_command "grep" "Use 'rg' (ripgrep) for faster search"

  press_continue
}

page_editing() {
  show_page_header "Editing"

  echo "  Neovim is configured as your editor:"
  echo ""

  ui_section "Quick access"
  echo ""
  show_command "nvim ." "Open current directory"
  show_command "v" "Alias for nvim"
  show_command "v ." "Open file explorer"
  echo ""

  ui_section "Key mappings (Space = leader)"
  echo ""
  show_key "Space+e" "Toggle file explorer"
  show_key "Space+ff" "Find files"
  show_key "Space+fg" "Live grep"
  show_key "Space+fb" "Browse buffers"
  show_key "gd" "Go to definition"
  show_key "K" "Hover documentation"
  show_key "Space+ca" "Code actions"
  echo ""

  ui_section "Split navigation"
  echo ""
  show_key "Ctrl+h/j/k/l" "Move between splits"
  show_key "Space+sv" "Split vertical"
  show_key "Space+sh" "Split horizontal"

  press_continue
}

page_git() {
  show_page_header "Git Workflow"

  echo "  Git is enhanced with aliases and tools:"
  echo ""

  ui_section "Quick commands"
  echo ""
  show_command "g" "Alias for git"
  show_command "gs" "git status"
  show_command "gd" "git diff"
  show_command "ga" "git add"
  show_command "gc" "git commit"
  show_command "gp" "git push"
  show_command "gl" "git pull"
  echo ""

  ui_section "Visual tools"
  echo ""
  show_command "lg" "lazygit - TUI for git"
  show_command "glog" "Pretty git log graph"
  echo ""

  ui_section "Commit signing"
  echo ""
  echo "  Your commits are signed automatically with SSH."
  show_command "git log --show-signature -1" "Verify signature"

  press_continue
}

page_tools() {
  show_page_header "Tools"

  echo "  Explore available tools with the dot CLI:"
  echo ""

  ui_section "Discovery"
  echo ""
  show_command "dot tools" "Browse available tools"
  show_command "dot packages" "List package managers"
  show_command "dot doctor" "Check system health"
  echo ""

  ui_section "Common tools"
  echo ""
  show_command "btop" "System monitor (better top)"
  show_command "duf" "Disk usage (better df)"
  show_command "ncdu" "Interactive disk usage"
  show_command "tldr" "Simplified man pages"
  show_command "jq" "JSON processor"
  show_command "yq" "YAML processor"
  echo ""

  ui_section "Development"
  echo ""
  show_command "fnm" "Fast Node Manager"
  show_command "mise" "Polyglot version manager"
  show_command "docker / podman" "Containers"

  press_continue
}

page_customization() {
  show_page_header "Customization"

  echo "  Make your environment your own:"
  echo ""

  ui_section "Appearance"
  echo ""
  show_command "dot theme" "Change color theme"
  show_command "dot fonts" "Install Nerd Fonts"
  show_command "dot wallpaper" "Set wallpaper (GUI)"
  echo ""

  ui_section "Configuration"
  echo ""
  show_command "dot edit" "Open dotfiles source"
  show_command "dot diff" "Preview pending changes"
  show_command "dot apply" "Apply changes"
  show_command "dot setup" "Re-run setup wizard"
  echo ""

  ui_section "Custom settings"
  echo ""
  echo "  Add local overrides without modifying tracked files:"
  show_command "~/.zshrc.local" "Shell customizations"
  show_command "~/.config/chezmoi/chezmoi.toml" "Profile settings"
  show_command "~/.config/nvim/lua/custom/" "Neovim plugins"

  press_continue
}

page_ai() {
  show_page_header "AI Assistance"

  echo "  AI tools are integrated into your workflow:"
  echo ""

  ui_section "Claude Code"
  echo ""
  echo "  Your Claude Code settings are in ~/.config/claude/"
  echo "  The CLAUDE.md file contains project instructions."
  echo ""
  show_command "claude" "Start Claude Code CLI"
  show_command "~/.config/claude/CLAUDE.md" "Edit instructions"
  echo ""

  ui_section "Cursor"
  echo ""
  echo "  Cursor rules are in ~/.config/cursor/rules/"
  echo "  Rules apply automatically based on file type."
  echo ""
  show_command "cursor ." "Open project in Cursor"
  echo ""

  ui_section "Shell integration"
  echo ""
  echo "  Some AI tools integrate with your shell:"
  show_command "gh copilot" "GitHub Copilot CLI"

  press_continue
}

page_tips() {
  show_page_header "Pro Tips"

  echo "  Get the most out of your environment:"
  echo ""

  ui_section "Speed"
  echo ""
  ui_bullet "Shell starts in <500ms with full features"
  ui_bullet "Use 'DOTFILES_FAST=1 zsh' for even faster startup"
  ui_bullet "Tab completion is deferred for speed"
  echo ""

  ui_section "Troubleshooting"
  echo ""
  show_command "dot doctor" "Diagnose issues"
  show_command "dot heal" "Auto-fix common problems"
  show_command "dot benchmark" "Measure startup time"
  echo ""

  ui_section "Staying updated"
  echo ""
  show_command "dot update" "Pull latest & apply"
  show_command "dot upgrade" "Update plugins & tools"
  echo ""

  ui_section "Getting help"
  echo ""
  show_command "dot help" "Show all commands"
  show_command "dot docs" "Open documentation"
  show_command "dot keys" "Show keybindings"

  press_continue
}

page_complete() {
  show_page_header "Tour Complete!"

  if command -v gum >/dev/null 2>&1 && [[ -t 1 ]]; then
    gum style --border double --padding "1 2" --border-foreground 212 \
      "🎉 You're all set!" \
      "" \
      "You now know the essentials of your new environment." \
      "" \
      "Remember:" \
      "  • dot help    - When you need help" \
      "  • dot doctor  - When something seems wrong" \
      "  • dot setup   - To reconfigure anytime" \
      "" \
      "Happy coding!"
  else
    echo "  🎉 You're all set!"
    echo ""
    echo "  You now know the essentials of your new environment."
    echo ""
    echo "  Remember:"
    echo "    • dot help    - When you need help"
    echo "    • dot doctor  - When something seems wrong"
    echo "    • dot setup   - To reconfigure anytime"
    echo ""
    echo "  Happy coding!"
  fi
  echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
  for page in "${PAGES[@]}"; do
    case "$page" in
      welcome) page_welcome ;;
      navigation) page_navigation ;;
      editing) page_editing ;;
      git) page_git ;;
      tools) page_tools ;;
      customization) page_customization ;;
      ai) page_ai ;;
      tips) page_tips ;;
      complete) page_complete ;;
    esac
    CURRENT_PAGE=$((CURRENT_PAGE + 1))
  done
}

main "$@"
