#!/usr/bin/env bash
# Dotfiles CLI - Tools Commands
# tools, new, packages, log-rotate

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"
# shellcheck source=../lib/ui.sh
source "$SCRIPT_DIR/../lib/ui.sh"

show_system_package_managers() {
  if has_command brew; then
    local brew_version brew_formulae brew_casks
    brew_version=$(brew --version | head -1)
    brew_formulae=$(brew list --formula 2>/dev/null | wc -l | tr -d ' ')
    brew_casks=$(brew list --cask 2>/dev/null | wc -l | tr -d ' ')
    ui_key_value "Homebrew" "$brew_version"
    ui_key_value "Formulae" "$brew_formulae"
    ui_key_value "Casks" "$brew_casks"
  fi
  if has_command apt; then
    local apt_version apt_packages
    apt_version=$(apt --version 2>/dev/null | head -1 || echo 'installed')
    apt_packages=$(dpkg -l 2>/dev/null | grep -c '^ii' || echo 'N/A')
    ui_key_value "APT" "$apt_version"
    ui_key_value "Packages" "$apt_packages"
  fi
  if has_command dnf; then
    ui_key_value "DNF" "$(dnf --version 2>/dev/null | head -1 || echo 'installed')"
  fi
  if has_command pacman; then
    local pacman_packages
    pacman_packages=$(pacman -Q 2>/dev/null | wc -l | tr -d ' ')
    ui_key_value "Pacman" "$(pacman --version | head -1)"
    ui_key_value "Packages" "$pacman_packages"
  fi
  if has_command nix; then
    ui_key_value "Nix" "$(nix --version)"
  fi
}

show_language_package_managers() {
  if has_command npm; then
    local npm_globals
    npm_globals=$(npm list -g --depth=0 2>/dev/null | grep -c '├──\|└──' || echo 'N/A')
    ui_key_value "npm" "$(npm --version)"
    ui_key_value "Global packages" "$npm_globals"
  fi
  if has_command pnpm; then
    ui_key_value "pnpm" "$(pnpm --version)"
  fi
  if has_command bun; then
    ui_key_value "Bun" "$(bun --version)"
  fi
  if has_command cargo; then
    local cargo_installed
    cargo_installed=$(cargo install --list 2>/dev/null | grep -c ':$' || echo 'N/A')
    ui_key_value "Cargo" "$(cargo --version | cut -d' ' -f2)"
    ui_key_value "Installed" "$cargo_installed"
  fi
  if has_command pip3; then
    ui_key_value "pip" "$(pip3 --version | cut -d' ' -f2)"
  fi
  if has_command pipx; then
    local pipx_installed
    pipx_installed=$(pipx list --short 2>/dev/null | wc -l | tr -d ' ')
    ui_key_value "pipx" "$(pipx --version)"
    ui_key_value "Installed" "$pipx_installed"
  fi
  if has_command gem; then
    ui_key_value "RubyGems" "$(gem --version)"
  fi
  if has_command go; then
    ui_key_value "Go" "$(go version | cut -d' ' -f3)"
  fi
}

cmd_tools() {
  local src_dir subcommand
  src_dir="$(resolve_source_dir)"
  subcommand="${1:-}"

  render_markdown() {
    local file="$1"
    local in_code=false
    local in_note=false
    local table_active=false
    local -a table_rows=()

    trim_ws() {
      local s="$1"
      s="${s#"${s%%[![:space:]]*}"}"
      s="${s%"${s##*[![:space:]]}"}"
      printf "%s" "$s"
    }

    strip_inline() {
      local s="$1"
      s="${s//\`/}"
      s="${s//\*\*/}"
      s="${s//\*/}"
      s="${s//_/}"
      printf "%s" "$s"
    }

    flush_table() {
      if ! $table_active; then
        return
      fi
      local -a widths=()
      local row col i
      for row in "${table_rows[@]}"; do
        IFS=$'\t' read -r -a cols <<<"$row"
        for i in "${!cols[@]}"; do
          local cell="${cols[$i]}"
          if (( ${#cell} > ${widths[$i]:-0} )); then
            widths[$i]=${#cell}
          fi
        done
      done
      local header=true
      for row in "${table_rows[@]}"; do
        IFS=$'\t' read -r -a cols <<<"$row"
        local line=""
        for i in "${!cols[@]}"; do
          local cell="${cols[$i]}"
          local width="${widths[$i]}"
          if $header; then
            line+=$(printf "%s%-*s%s  " "${BOLD}${CYAN}" "$width" "$cell" "${NORMAL}")
          else
            line+=$(printf "%-*s  " "$width" "$cell")
          fi
        done
        printf "%s\n" "${line%  }"
        if $header; then
          header=false
        fi
      done
      printf "\n"
      table_rows=()
      table_active=false
    }

    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" == '```'* ]]; then
        if $in_code; then
          in_code=false
        else
          in_code=true
        fi
        continue
      fi

      if $in_code; then
        printf "  %s\n" "$line"
        continue
      fi

      if [[ "$line" =~ ^\| ]]; then
        local row="${line#|}"
        row="${row%|}"
        if [[ "$row" =~ ^[[:space:]-:|]+$ ]]; then
          continue
        fi
        IFS='|' read -r -a cols <<<"$row"
        local cleaned=()
        local c
        for c in "${cols[@]}"; do
          c=$(strip_inline "$(trim_ws "$c")")
          cleaned+=("$c")
        done
        table_rows+=("$(IFS=$'\t'; echo "${cleaned[*]}")")
        table_active=true
        continue
      fi

      if $table_active; then
        flush_table
      fi

      if [[ "$line" =~ ^\#\  ]]; then
        local h
        h=$(strip_inline "${line#\# }")
        printf "\n"
        ui_section "$h"
        continue
      fi

      if [[ "$line" =~ ^\#\# ]]; then
        local h
        h=$(strip_inline "${line#\#\# }")
        printf "\n"
        ui_section "$h"
        continue
      fi

      if [[ "$line" =~ ^\>\ \[\!NOTE\] ]]; then
        in_note=true
        ui_info "Note:"
        continue
      fi

      if [[ "$line" =~ ^\>\  ]]; then
        local q
        q=$(strip_inline "${line#\> }")
        ui_info "$q"
        continue
      fi

      if [[ -z "$line" ]]; then
        in_note=false
        printf "\n"
        continue
      fi

      if [[ "$line" =~ ^- ]]; then
        local item
        item=$(strip_inline "${line#- }")
        ui_bullet "$item"
        continue
      fi

      line=$(strip_inline "$line")
      printf "%s\n" "$line"
    done <"$file"

    flush_table
  }

  if [ "$subcommand" = "install" ]; then
    if ! has_command nix; then
      ui_logo_dot "Dot Tools • Nix"
      ui_error "Nix is not installed."
      printf "\n"
      ui_info "To install Nix, run:"
      ui_bullet "curl -L https://nixos.org/nix/install | sh"
      ui_info "Or use Homebrew/apt for individual tools."
      exit 1
    fi
    shift
    if [ -n "$src_dir" ] && [ -f "$src_dir/nix/flake.nix" ]; then
      ui_logo_dot "Dot Tools • Nix"
      ui_info "Entering Nix development shell..."
      exec nix develop "$src_dir/nix" "$@"
    else
      ui_logo_dot "Dot Tools • Nix"
      ui_error "Nix flake not found in source directory."
      exit 1
    fi
  elif [ -n "$src_dir" ] && [ -f "$src_dir/docs/TOOLS.md" ]; then
    ui_logo_dot "Dot Tools • Docs"
    render_markdown "$src_dir/docs/TOOLS.md"
  elif [ -n "$src_dir" ] && [ -f "$src_dir/docs/UTILS.md" ]; then
    ui_logo_dot "Dot Tools • Docs"
    render_markdown "$src_dir/docs/UTILS.md"
  else
    ui_logo_dot "Dot Tools"
    ui_section "Usage"
    ui_bullet "dot tools [command]"
    ui_section "Commands"
    ui_bullet "(none)    Show tools documentation"
    ui_bullet "install   Enter Nix development shell with all tools"
    ui_section "Quick Reference"
    ui_bullet "dot sync       - Apply dotfiles"
    ui_bullet "dot update     - Pull latest changes and apply"
    ui_bullet "dot doctor     - Run health checks"
    ui_bullet "dot keys       - Show keybindings catalog"
    ui_bullet "dot learn      - Interactive tour"
  fi
}

cmd_new() {
  local template_lang="${1:-}"
  local project_name="${2:-}"

  if [ -z "$template_lang" ] || [ -z "$project_name" ]; then
    ui_logo_dot "Dot New • Project"
    ui_error "Usage: dot new <lang> <name>"
    ui_info "Available templates: python, go, node, packer, molecule"
    exit 1
  fi

  # Validate inputs to prevent path traversal
  if [[ ! "$template_lang" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    die "Invalid template name: $template_lang"
  fi
  if [[ ! "$project_name" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    die "Invalid project name: $project_name"
  fi

  local src_dir
  src_dir="$(require_source_dir)"
  local template_dir="$src_dir/templates/projects/$template_lang"

  if [ ! -d "$template_dir" ]; then
    ui_logo_dot "Dot New • Project"
    ui_error "Unknown template: $template_lang"
    ui_info "Available templates: python, go, node, packer, molecule"
    exit 1
  fi

  # Pre-flight: verify Python is available before creating any files
  local python_cmd=""
  if has_command python3; then
    python_cmd="python3"
  elif has_command python; then
    python_cmd="python"
  else
    die "python3 is required to render templates."
  fi

  local dest="$PWD/$project_name"
  if [ -e "$dest" ]; then
    die "Destination exists: $dest"
  fi

  mkdir -p "$dest"
  cp -R "$template_dir/." "$dest"

  # Rename directories
  find "$dest" -depth -name "__PROJECT_NAME__" -print0 | while IFS= read -r -d '' path; do
    local parent
    parent="$(dirname "$path")"
    mv "$path" "$parent/$project_name"
  done

  # Render template placeholders
  find "$dest" -type f -print0 | while IFS= read -r -d '' file; do
    $python_cmd - "$file" "$project_name" <<'PY'
import sys
path = sys.argv[1]
name = sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    data = f.read()
data = data.replace("__PROJECT_NAME__", name)
with open(path, "w", encoding="utf-8") as f:
    f.write(data)
PY
  done

  ui_logo_dot "Dot New • Project"
  ui_success "Created $template_lang project at $dest"
}

cmd_packages() {
  ui_logo_dot "Dot Packages • Managers"
  ui_section "System Package Managers"
  show_system_package_managers
  printf "\n"
  ui_section "Language Package Managers"
  show_language_package_managers
}

cmd_log_rotate() {
  run_script "scripts/tools/log-rotate.sh" "Log rotation script" "$@"
}

# Dispatch
case "${1:-}" in
  tools)
    shift
    cmd_tools "$@"
    ;;
  new)
    shift
    cmd_new "$@"
    ;;
  packages)
    shift
    cmd_packages "$@"
    ;;
  log-rotate)
    shift
    cmd_log_rotate "$@"
    ;;
  *)
    ui_error "Unknown tools command: ${1:-}"
    exit 1
    ;;
esac
