#!/usr/bin/env bash
# Dotfiles CLI - Tools Commands
# tools, new, packages, log-rotate

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

dot_ui_command_banner "Tools" "${1:-}"

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

alias_manifest_path() {
  local src_dir
  src_dir="$(require_source_dir)"
  printf "%s\n" "$src_dir/scripts/diagnostics/aliases-manifest.sh"
}

emit_alias_manifest() {
  local manifest
  manifest="$(alias_manifest_path)"
  if [[ ! -x "$manifest" ]]; then
    die "Alias manifest script not found: $manifest"
  fi
  bash "$manifest"
}

cmd_aliases() {
  local subcommand="${1:-list}"
  shift || true

  alias_tier_enabled() {
    local csv="${1:-all}"
    local token="${2:-}"
    if [[ "$csv" == "all" ]]; then
      return 0
    fi
    [[ ",${csv}," == *",${token},"* ]]
  }

  case "$subcommand" in
    list)
      ui_header "Aliases"
      echo ""
      printf "  %-18s %-42s %s\n" "Name" "Value" "Source"
      echo "  $(printf '%.18s' '------------------') $(printf '%.42s' '------------------------------------------') -------------------------"
      emit_alias_manifest | sort -t $'\t' -k1,1 | while IFS=$'\t' read -r name value file line; do
        printf "  %-18s %-42s %s:%s\n" "$name" "${value:0:42}" "${file##*/}" "$line"
      done
      ;;
    search)
      local query="${1:-}"
      if [[ -z "$query" ]]; then
        die "Usage: dot aliases search <term>"
      fi
      ui_header "Alias Search"
      ui_info "Query" "$query"
      echo ""
      local results
      results="$(emit_alias_manifest | rg -i "$query" || true)"
      if [[ -z "$results" ]]; then
        ui_warn "No matches" "$query"
        return 1
      fi
      printf "%s\n" "$results" | while IFS=$'\t' read -r name value file line; do
        printf "  %-18s %-42s %s:%s\n" "$name" "${value:0:42}" "$file" "$line"
      done
      ;;
    why)
      local alias_name="${1:-}"
      if [[ -z "$alias_name" ]]; then
        die "Usage: dot aliases why <alias>"
      fi
      ui_header "Alias Details"
      ui_info "Alias" "$alias_name"
      echo ""
      local rows
      rows="$(emit_alias_manifest | awk -F'\t' -v a="$alias_name" '$1==a')"
      local src_dir deprecations_file deprecation
      src_dir="$(require_source_dir)"
      deprecations_file="$src_dir/scripts/dot/data/alias-deprecations.tsv"
      if [[ -n "$rows" ]]; then
        printf "%s\n" "$rows" | while IFS=$'\t' read -r name value file line; do
          ui_ok "$name" "${value}"
          printf "    source: %s:%s\n" "$file" "$line"
        done
      fi
      if [[ -f "$deprecations_file" ]]; then
        deprecation="$(awk -F'\t' -v a="$alias_name" 'BEGIN{IGNORECASE=0} $1 !~ /^#/ && $1==a {print $0; exit}' "$deprecations_file")"
        if [[ -n "$deprecation" ]]; then
          local _a replacement remove_in note
          IFS=$'\t' read -r _a replacement remove_in note <<<"$deprecation"
          echo ""
          ui_warn "Deprecated" "yes"
          ui_info "Replacement" "$replacement"
          ui_info "Remove In" "$remove_in"
          ui_info "Note" "$note"
        fi
      fi
      if [[ -z "$rows" && -z "$deprecation" ]]; then
        ui_warn "Alias" "not found: $alias_name"
        return 1
      fi
      ;;
    stats)
      local histfile="${HISTFILE:-$HOME/.zsh_history}"
      if [[ ! -f "$histfile" ]]; then
        die "History file not found: $histfile"
      fi
      ui_header "Alias Usage (History)"
      ui_info "History file" "$histfile"
      echo ""
      local tmp_aliases
      tmp_aliases="$(mktemp)"
      emit_alias_manifest | awk -F'\t' '{print $1}' | sort -u >"$tmp_aliases"
      awk -v aliases_file="$tmp_aliases" '
        BEGIN {
          while ((getline < aliases_file) > 0) alias[$1]=1
        }
        {
          line=$0
          sub(/^:[[:space:]]*[0-9]+:[0-9]+;/, "", line) # zsh EXTENDED_HISTORY prefix
          split(line, parts, /[[:space:]]+/)
          cmd=parts[1]
          if (cmd in alias) count[cmd]++
        }
        END {
          for (k in count) printf "%7d  %s\n", count[k], k
        }
      ' "$histfile" | sort -nr | head -20
      rm -f "$tmp_aliases"
      ;;
    tiers)
      local profile ecosystems security_mode dangerous buckets
      profile="${DOTFILES_ALIAS_PROFILE:-standard}"
      ecosystems="${DOTFILES_ALIAS_ECOSYSTEMS:-all}"
      buckets="${DOTFILES_ALIAS_BUCKETS:-system,svn}"
      security_mode="${DOTFILES_SECURITY_MODE:-standard}"
      dangerous="${DOTFILES_ENABLE_DANGEROUS_ALIASES:-0}"

      ui_header "Alias Tiers"
      ui_info "Profile" "$profile"
      ui_info "Ecosystems" "$ecosystems"
      ui_info "Buckets" "$buckets"
      ui_info "Security Mode" "$security_mode"
      ui_info "Dangerous Aliases" "$dangerous"
      echo ""

      ui_header "Core (Always Loaded)"
      ui_ok "navigation" "cd, clear, default, diagnostics, ps"
      ui_ok "dev core" "git, editor, configuration, modern"
      ui_ok "cross-platform tooling" "docker, archives, disk-usage, rsync"
      echo ""

      ui_header "Ecosystems (Lazy)"
      if alias_tier_enabled "$ecosystems" "python"; then
        ui_ok "python" "enabled"
      else
        ui_warn "python" "disabled"
      fi
      if alias_tier_enabled "$ecosystems" "node"; then
        ui_ok "node" "enabled"
      else
        ui_warn "node" "disabled"
      fi
      if alias_tier_enabled "$ecosystems" "rust"; then
        ui_ok "rust" "enabled"
      else
        ui_warn "rust" "disabled"
      fi
      if alias_tier_enabled "$ecosystems" "network"; then
        ui_ok "network" "enabled"
      else
        ui_warn "network" "disabled"
      fi
      if alias_tier_enabled "$ecosystems" "legacy"; then
        ui_ok "legacy" "enabled"
      else
        ui_warn "legacy" "disabled"
      fi
      if alias_tier_enabled "$buckets" "system"; then
        ui_ok "system bucket" "enabled"
      else
        ui_warn "system bucket" "disabled"
      fi
      if alias_tier_enabled "$buckets" "svn"; then
        ui_ok "svn bucket" "enabled"
      else
        ui_warn "svn bucket" "disabled"
      fi
      ;;
    *)
      die "Unknown aliases subcommand: $subcommand"
      ;;
  esac
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
    ui_ok "dot verify" "Run post-merge verification checks"
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
  aliases)
    shift
    cmd_aliases "$@"
    ;;
  *)
    echo "Unknown tools command: ${1:-}" >&2
    exit 1
    ;;
esac
