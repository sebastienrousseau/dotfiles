#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles CLI - Tool Commands (moved from tools.sh, P2.1)
# tools, new, packages, env; plugins/tool/dot-tool maps the ADR-020
# spellings onto these.

set -euo pipefail

_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$_TOOLS_DIR/../../../lib/dot/utils.sh"

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
    # Validate any tool name arguments
    for arg in "$@"; do
      [[ "$arg" == -* ]] && continue
      validate_name "$arg" "tool name"
    done
    if [ -n "$src_dir" ] && [ -f "$src_dir/nix/flake.nix" ]; then
      ui_info "Entering" "Nix development shell"
      exec nix develop "$src_dir/nix" "$@"
    else
      ui_err "Nix flake" "not found in source directory"
      exit 1
    fi
  elif [ "$subcommand" = "docs" ]; then
    # docs/reference/ first: both documents were moved there, and looking
    # only in docs/ meant `dot tool list --nix docs` answered "TOOLS.md not found" on a
    # complete checkout. The legacy paths stay in the list so a pre-reorg
    # tree still resolves.
    local doc
    for doc in docs/reference/TOOLS.md docs/reference/UTILS.md \
      docs/TOOLS.md docs/UTILS.md; do
      if [ -n "$src_dir" ] && [ -f "$src_dir/$doc" ]; then
        exec cat "$src_dir/$doc"
      fi
    done
    ui_err "Docs" "TOOLS.md not found"
    exit 1
  else
    ui_header "Dot Tools"
    echo ""
    ui_info "Usage" "dot tool list --nix [command]"
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
    ui_ok "dot help tour" "Interactive tour"
  fi
}

cmd_new() {
  local template_lang="${1:-}"
  local project_name="${2:-}"

  if [ -z "$template_lang" ] || [ -z "$project_name" ]; then
    echo "Usage: dot tool new <lang> <name>"
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
  # shellcheck source-path=SCRIPTDIR source=tools/packages.sh
  source "$_TOOLS_DIR/tools/packages.sh"
  ui_header "Package Managers"
  echo ""
  show_system_package_managers
  echo ""
  ui_header "Language Package Managers"
  show_language_package_managers
}

## _validate_tool_spec <spec> — die unless <spec> is a mise tool spec.
## validate_name's [a-zA-Z0-9._-] rejected every versioned spec, so the
## documented `dot tool set node@22` could never run. A spec may carry a
## backend prefix and a version (node@22, aqua:nushell/nushell@0.114.1,
## npm:@openai/codex@latest); shell metacharacters and spaces stay out.
_validate_tool_spec() {
  if [[ ! "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._@:/+-]*$ ]]; then
    die "Invalid tool spec: $1 (allowed: letters, digits and . _ @ : / + -)"
  fi
}

cmd_env_mise() {
  # `dot tool export` is a separate sub-handler — it doesn't need mise
  # at command-time, only when actually invoked (the script checks).
  if [[ "${1:-}" == "emit" ]]; then
    shift
    # shellcheck source=./env-emit.sh
    source "$_TOOLS_DIR/env-emit.sh"
    dot_env_emit "$@"
    return $?
  fi

  if ! has_command mise; then
    ui_err "mise not installed (required for dot tool)"
    exit 1
  fi
  case "${1:-list}" in
    list | ls)
      if has_command jq; then
        ui_table_begin "Tool" "Version" "Source" "Requested"
        while IFS=$'\t' read -r tool ver source req; do
          ui_table_add "$tool" "$ver" "${source/$HOME/\~}" "$req"
        done < <(mise ls --json 2>/dev/null | jq -r '
          to_entries[] as $t
          | $t.value[]
          | [
              $t.key,
              (.version // "-"),
              (.source.path // ""),
              (.requested_version // "")
            ]
          | @tsv
        ')
        ui_table_end
      else
        mise ls
      fi
      # Surface orphan installs (tool versions on disk that no active config
      # claims). `--dry-run-code` exits 1 iff there is something to prune;
      # the call is fast (no I/O beyond reading the tracked-configs index).
      if mise prune --dry-run-code --quiet >/dev/null 2>&1; then
        :
      else
        echo ""
        ui_warn "orphan installs" "tool versions on disk are not requested by any config"
        ui_info "to clean" "run 'dot tool remove' (dry-run) or 'dot tool remove --yes' to commit"
      fi
      ;;
    prune)
      shift
      local commit=0
      for arg in "$@"; do
        case "$arg" in
          --yes | -y) commit=1 ;;
        esac
      done
      if ((commit)); then
        mise prune
      else
        ui_info "dry-run" "showing what 'mise prune' would remove (pass --yes to commit)"
        echo ""
        mise prune --dry-run
        echo ""
        ui_info "next" "re-run with 'dot tool remove --yes' to actually uninstall"
      fi
      ;;
    install)
      shift
      for arg in "$@"; do
        [[ "$arg" == -* ]] && continue
        _validate_tool_spec "$arg"
      done
      mise install "$@"
      ;;
    use)
      shift
      for arg in "$@"; do
        [[ "$arg" == -* ]] && continue
        _validate_tool_spec "$arg"
      done
      mise use "$@"
      ;;
    *) mise "$@" ;;
  esac
}

# Sourced (by tests), only the functions are defined.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    --help | -h | help)
      echo "Usage: tool.sh tools|new|packages|env [args...]"
      ;;
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
    env)
      shift
      cmd_env_mise "$@"
      ;;
    *)
      echo "Unknown tool command: ${1:-}" >&2
      exit 1
      ;;
  esac
fi
