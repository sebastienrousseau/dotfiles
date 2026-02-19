#!/usr/bin/env bash
# Dotfiles CLI - Tools Commands
# tools, new, packages, log-rotate

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

ui_logo_once "Dot • Tools"

ensure_line_in_file() {
  local file="$1"
  local line="$2"
  if ! grep -Fqx "$line" "$file" 2>/dev/null; then
    printf "%s\n" "$line" >>"$file"
  fi
}

apply_template_security_baseline() {
  local dest="$1"
  local template_lang="$2"

  # Baseline repo hygiene defaults
  if [[ ! -f "$dest/.editorconfig" ]]; then
    cat >"$dest/.editorconfig" <<'EOF'
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 2
trim_trailing_whitespace = true
EOF
  fi

  if [[ ! -f "$dest/.gitattributes" ]]; then
    cat >"$dest/.gitattributes" <<'EOF'
* text=auto eol=lf
*.sh text eol=lf
*.yml text eol=lf
*.yaml text eol=lf
EOF
  fi

  if [[ ! -f "$dest/.gitignore" ]]; then
    : >"$dest/.gitignore"
  fi
  ensure_line_in_file "$dest/.gitignore" ".env"
  ensure_line_in_file "$dest/.gitignore" ".env.*"
  ensure_line_in_file "$dest/.gitignore" "*.pem"
  ensure_line_in_file "$dest/.gitignore" "*.key"
  ensure_line_in_file "$dest/.gitignore" "*.p12"
  ensure_line_in_file "$dest/.gitignore" "*.agekey"

  if [[ ! -f "$dest/SECURITY.md" ]]; then
    cat >"$dest/SECURITY.md" <<'EOF'
# Security Policy

## Reporting

Do not disclose vulnerabilities publicly before a fix is available.
Open a private security advisory or contact maintainers directly.

## Baseline Controls

- No secrets in source control.
- Use environment variables for API keys/tokens.
- Keep dependencies and lockfiles up to date.
- Enable secret scanning in CI.
EOF
  fi

  mkdir -p "$dest/.github/workflows"
  if [[ ! -f "$dest/.github/workflows/security.yml" ]]; then
    cat >"$dest/.github/workflows/security.yml" <<'EOF'
name: Security Baseline

on:
  pull_request:
  push:
    branches: [main, master]

permissions:
  contents: read

jobs:
  secrets:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6
      - uses: gitleaks/gitleaks-action@ff98106e4c7b2bc287b24eaf42907196329070c7 # v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - uses: trufflesecurity/trufflehog@6961f2bace57ab32b23b3ba40f8f420f6bc7e004 # v3.93.3
        with:
          extra_args: --only-verified
EOF
  fi

  # Best-effort lockfile generation to improve reproducibility.
  case "$template_lang" in
    node)
      if has_command npm && [[ -f "$dest/package.json" ]] && [[ ! -f "$dest/package-lock.json" ]]; then
        (cd "$dest" && npm install --package-lock-only --ignore-scripts --silent >/dev/null 2>&1) || true
      fi
      ;;
    python)
      if has_command uv && [[ -f "$dest/pyproject.toml" ]] && [[ ! -f "$dest/uv.lock" ]]; then
        (cd "$dest" && uv lock >/dev/null 2>&1) || true
      fi
      ;;
    go)
      if has_command go && [[ -f "$dest/go.mod" ]]; then
        (cd "$dest" && go mod tidy >/dev/null 2>&1) || true
      fi
      ;;
  esac
}

show_system_package_managers() {
  if has_command brew; then
    local brew_version brew_formulae brew_casks
    brew_version=$(brew --version | head -1)
    brew_formulae=$(brew list --formula 2>/dev/null | wc -l | tr -d ' ')
    brew_casks=$(brew list --cask 2>/dev/null | wc -l | tr -d ' ')
    echo "  Homebrew: $brew_version"
    echo "    Formulae: $brew_formulae"
    echo "    Casks: $brew_casks"
  fi
  if has_command apt; then
    local apt_version apt_packages
    apt_version=$(apt --version 2>/dev/null | head -1 || echo 'installed')
    apt_packages=$(dpkg -l 2>/dev/null | grep -c '^ii' || echo 'N/A')
    echo "  APT: $apt_version"
    echo "    Packages: $apt_packages"
  fi
  if has_command dnf; then
    echo "  DNF: $(dnf --version 2>/dev/null | head -1 || echo 'installed')"
  fi
  if has_command pacman; then
    local pacman_packages
    pacman_packages=$(pacman -Q 2>/dev/null | wc -l | tr -d ' ')
    echo "  Pacman: $(pacman --version | head -1)"
    echo "    Packages: $pacman_packages"
  fi
  if has_command nix; then
    echo "  Nix: $(nix --version)"
  fi
}

show_language_package_managers() {
  if has_command npm; then
    local npm_globals
    npm_globals=$(npm list -g --depth=0 2>/dev/null | grep -c '├──\|└──' || echo 'N/A')
    echo "  npm: $(npm --version)"
    echo "    Global packages: $npm_globals"
  fi
  if has_command pnpm; then
    echo "  pnpm: $(pnpm --version)"
  fi
  if has_command bun; then
    echo "  Bun: $(bun --version)"
  fi
  if has_command cargo; then
    local cargo_installed
    cargo_installed=$(cargo install --list 2>/dev/null | grep -c ':$' || echo 'N/A')
    echo "  Cargo: $(cargo --version | cut -d' ' -f2)"
    echo "    Installed: $cargo_installed"
  fi
  if has_command pip3; then
    echo "  pip: $(pip3 --version | cut -d' ' -f2)"
  fi
  if has_command pipx; then
    local pipx_installed
    pipx_installed=$(pipx list --short 2>/dev/null | wc -l | tr -d ' ')
    echo "  pipx: $(pipx --version)"
    echo "    Installed: $pipx_installed"
  fi
  if has_command gem; then
    echo "  RubyGems: $(gem --version)"
  fi
  if has_command go; then
    echo "  Go: $(go version | cut -d' ' -f3)"
  fi
}

cmd_tools() {
  local src_dir subcommand
  src_dir="$(resolve_source_dir)"
  subcommand="${1:-}"

  if [ "$subcommand" = "install" ]; then
    if ! has_command nix; then
      ui_err "Nix" "not installed"
      echo ""
      ui_header "Install Nix"
      echo "  Follow the verified installer instructions:"
      echo "  https://nixos.org/download/"
      echo ""
      ui_info "Or" "use Homebrew/apt for individual tools"
      exit 1
    fi
    shift
    if [ -n "$src_dir" ] && [ -f "$src_dir/nix/flake.nix" ]; then
      ui_info "Entering" "Nix development shell"
      exec nix develop "$src_dir/nix" "$@"
    else
      ui_err "Nix flake" "not found in source directory"
      exit 1
    fi
  elif [ "$subcommand" = "docs" ]; then
    if [ -n "$src_dir" ] && [ -f "$src_dir/docs/TOOLS.md" ]; then
      exec cat "$src_dir/docs/TOOLS.md"
    elif [ -n "$src_dir" ] && [ -f "$src_dir/docs/UTILS.md" ]; then
      exec cat "$src_dir/docs/UTILS.md"
    fi
    ui_err "Docs" "TOOLS.md not found"
    exit 1
  else
    ui_header "Dot Tools"
    echo ""
    ui_info "Usage" "dot tools [command]"
    echo ""
    ui_header "Commands"
    ui_ok "(none)" "Show tools documentation"
    ui_ok "install" "Enter Nix development shell with all tools"
    ui_ok "docs" "Show full tools markdown documentation"
    echo ""
    ui_header "Quick Reference"
    ui_ok "dot sync" "Apply dotfiles"
    ui_ok "dot update" "Pull latest changes and apply"
    ui_ok "dot doctor" "Run health checks"
    ui_ok "dot keys" "Show keybindings catalog"
    ui_ok "dot learn" "Interactive tour"
  fi
}

cmd_new() {
  local template_lang="${1:-}"
  local project_name="${2:-}"

  if [ -z "$template_lang" ] || [ -z "$project_name" ]; then
    echo "Usage: dot new <lang> <name>"
    echo "Available templates: python, go, node, packer, molecule"
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
    echo "Unknown template: $template_lang"
    echo "Available templates: python, go, node, packer, molecule"
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

  apply_template_security_baseline "$dest" "$template_lang"

  echo "Created $template_lang project at $dest"
}

cmd_packages() {
  ui_header "Package Managers"
  echo ""
  show_system_package_managers
  echo ""
  ui_header "Language Package Managers"
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
    echo "Unknown tools command: ${1:-}" >&2
    exit 1
    ;;
esac
