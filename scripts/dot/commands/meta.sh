#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles CLI - Meta Commands
# upgrade, prewarm, docs, learn, keys, sandbox, mcp, mode, agent

set -euo pipefail

_META_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$_META_DIR/../../../lib/dot/utils.sh"
# shellcheck source=../../../lib/dot/log.sh
source "$_META_DIR/../../../lib/dot/log.sh"
# shellcheck source=agent.sh
source "$_META_DIR/agent.sh"

meta_banner_section() {
  case "${1:-}" in
    mcp | mode | agent)
      printf '%s\n' "AI and Agents"
      ;;
    docs | keys | learn | search | help | version)
      printf '%s\n' "Reference"
      ;;
    *)
      printf '%s\n' "Meta"
      ;;
  esac
}

dot_ui_command_banner "$(meta_banner_section "${1:-}")" "${1:-}" "$@"

# Last meaningful line of a captured log, used as a step's `ok` detail.
# Collapses carriage-return progress (git/nvim spam \r), strips ANSI,
# takes the last non-empty line, and clips it so the rendered step stays
# on one line.
_upgrade_last_line() {
  tr '\r' '\n' <"$1" 2>/dev/null |
    sed -E 's/\x1b\[[0-9;?]*[a-zA-Z]//g' |
    awk 'NF{last=$0} END{print last}' |
    cut -c1-56
}

cmd_upgrade() {
  local src_dir
  src_dir="$(require_source_dir)"

  # Per-step logs. Each phase's stdout+stderr is captured here rather
  # than streamed to the terminal: the git/nvim/chezmoi output is noisy
  # (carriage-return progress bars, remote counters) and, in rich mode,
  # writing it to the terminal corrupts the dot-ui renderer that owns
  # the screen. Failing steps get their tail dumped after the run.
  local log_dir
  log_dir="$(mktemp -d "${TMPDIR:-/tmp}/dot-upgrade.XXXXXX")"
  local fail_labels=() fail_logs=()

  # _upgrade_step <id> <label> <running-detail> -- cmd [args...]
  # Renders one tracked step: spinner while it runs, then ok (with the
  # log's last line) or fail. Never aborts the run — a failed phase is
  # recorded and surfaced at the end, matching the previous `|| true`
  # behaviour but without the raw flood.
  _upgrade_step() {
    local id="$1" label="$2" running="$3"
    shift 3
    [[ "${1:-}" == "--" ]] && shift
    local log="$log_dir/$id.log" rc=0
    ui_step "$id" "$label" run "$running"
    "$@" >"$log" 2>&1 || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      ui_step "$id" "" ok "$(_upgrade_last_line "$log")"
    else
      ui_step "$id" "" fail "exited $rc"
      fail_labels+=("$label")
      fail_logs+=("$log")
    fi
    return 0
  }

  ui_steps_begin "Upgrade" ""

  if [ -f "$src_dir/nix/flake.nix" ] && has_command nix; then
    _upgrade_step nix-flake "Nix flake" "updating…" -- \
      sh -c 'cd "$1" && nix flake update' _ "$src_dir"
    _upgrade_step nix-gc "Nix GC" "collecting…" -- nix-collect-garbage -d
  fi

  _upgrade_step dotfiles "Dotfiles" "chezmoi update…" -- chezmoi update

  if has_command nvim; then
    # scripts/nvim/headless-upgrade.lua runs Lazy sync AND waits for
    # Mason's async install queue to drain, so ensure_installed installs
    # (codelldb, debugpy, delve, etc.) aren't aborted by an early quitall.
    _upgrade_step nvim "Neovim plugins" "Lazy sync + Mason drain…" -- \
      nvim --headless -l "$src_dir/scripts/nvim/headless-upgrade.lua"
  fi

  if [ "${DOTFILES_FONTS:-}" = "1" ] &&
    [ -f "$src_dir/scripts/fonts/install-nerd-fonts.sh" ]; then
    _upgrade_step fonts "Nerd Fonts" "installing…" -- \
      sh "$src_dir/scripts/fonts/install-nerd-fonts.sh"
  fi

  local n=${#fail_labels[@]}
  if [[ "$n" -eq 0 ]]; then
    ui_steps_end "toolchains, plugins, and dotfiles up to date"
    rm -rf "$log_dir"
  else
    ui_steps_end "$n step(s) failed"
    # Surfaced after ui_steps_end so the rich renderer has torn down —
    # printing mid-render would garble the display.
    local i=0
    while ((i < n)); do
      ui_err "${fail_labels[$i]}" "log tail:"
      tail -n 15 "${fail_logs[$i]}" | sed 's/^/    /'
      ((i++)) || true
    done
    ui_info "Logs" "$log_dir"
  fi
}

cmd_prewarm() {
  local src_dir
  # Clear caches first
  ui_info "Cache" "Clearing shell initialization caches"
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
  # `find ... -delete` instead of `rm -rf $glob` so an unmatched literal
  # pattern can't accidentally remove a real same-named directory, and
  # so we don't pass `-r` on what should always be files.
  [[ -d "$cache_dir/zsh" ]] && find "$cache_dir/zsh" -maxdepth 1 -type f \( -name '*-init.zsh' -o -name '*.zwc' \) -delete 2>/dev/null
  [[ -d "$cache_dir/bash" ]] && find "$cache_dir/bash" -maxdepth 1 -type f -name '*-init.bash' -delete 2>/dev/null
  [[ -d "$cache_dir/fish" ]] && find "$cache_dir/fish" -maxdepth 1 -type f -name '*-init.fish' -delete 2>/dev/null
  [[ -d "$cache_dir/nushell" ]] && find "$cache_dir/nushell" -maxdepth 1 -type f -name '*.nu' -delete 2>/dev/null
  ui_info "Cache" "Cleared. Regenerating..."
  src_dir="$(resolve_source_dir)"
  if [ -n "$src_dir" ] && [ -f "$src_dir/scripts/ops/prewarm.sh" ]; then
    bash "$src_dir/scripts/ops/prewarm.sh"
  fi
}

cmd_docs() {
  local src_dir
  src_dir="$(resolve_source_dir)"

  if [ -n "$src_dir" ] && [ -f "$src_dir/README.md" ]; then
    if has_command glow; then
      glow "$src_dir/README.md"
    else
      exec cat "$src_dir/README.md"
    fi
  else
    die "README not found."
  fi
}

cmd_learn() {
  local dot_bin
  # Post-Phase-4b: dot_local/ lives under defaults/. Legacy layout
  # (older deployments before .chezmoiroot activation) kept it at
  # repo root — probe both.
  dot_bin="$(dirname "${BASH_SOURCE[0]}")/../../../defaults/dot_local/bin"
  [[ -f "$dot_bin/executable_tour" ]] ||
    dot_bin="$(dirname "${BASH_SOURCE[0]}")/../../../dot_local/bin"
  if [ -f "$dot_bin/executable_tour" ]; then
    exec bash "$dot_bin/executable_tour" "$@"
  fi
  # Fallback to ops script
  run_script "scripts/ops/tour.sh" "Tour script" "$@"
}

cmd_keys() {
  local src_dir
  src_dir="$(resolve_source_dir)"

  if [[ "${1:-}" == "sign-check" ]]; then
    ui_header "Git Signing Status"
    local signing_key="" format="" key_file=""
    signing_key="$(git config --global user.signingkey 2>/dev/null || true)"
    format="$(git config --global gpg.format 2>/dev/null || true)"
    if [[ -z "$signing_key" ]]; then
      ui_warn "No signing key configured (git config --global user.signingkey)"
    else
      ui_info "Key" "$signing_key"
      ui_info "Format" "${format:-gpg}"
      if [[ "$format" == "ssh" ]]; then
        key_file="${signing_key/#\~/$HOME}"
        if [[ -f "$key_file" ]]; then
          ui_info "Status" "SSH key file exists: $key_file"
        else
          ui_warn "SSH key file not found: $key_file"
        fi
      else
        if has_command gpg && gpg --list-keys "$signing_key" >/dev/null 2>&1; then
          ui_info "Status" "GPG key found in keyring"
        else
          ui_warn "GPG key not found in keyring: $signing_key"
        fi
      fi
    fi
    return 0
  fi

  if [ -n "$src_dir" ] && [ -f "$src_dir/docs/KEYS.md" ]; then
    if [ -n "${1:-}" ]; then
      rg -i --fixed-strings --context 1 "${1:-}" "$src_dir/docs/KEYS.md" || true
    else
      exec cat "$src_dir/docs/KEYS.md"
    fi
  else
    run_script "scripts/diagnostics/keys.sh" "Keys script" "$@"
  fi
}

cmd_sandbox() {
  local src_dir
  src_dir="$(require_source_dir)"

  if has_command docker; then
    ui_info "Launching sandbox via Docker"
    docker build -f "$src_dir/tests/Dockerfile.sandbox" -t dotfiles-sandbox "$src_dir"
    exec docker run --rm -it dotfiles-sandbox
  elif has_command podman; then
    ui_info "Launching sandbox via Podman"
    podman build -f "$src_dir/tests/Dockerfile.sandbox" -t dotfiles-sandbox "$src_dir"
    exec podman run --rm -it dotfiles-sandbox
  else
    die "Docker or Podman is required for sandbox."
  fi
}

cmd_mcp() {
  local subcommand="${1:-doctor}"
  if [[ "${1:-}" == --* ]] || [[ "${1:-}" == -* ]] || [[ -z "${1:-}" ]]; then
    subcommand="doctor"
  else
    shift || true
  fi
  case "$subcommand" in
    doctor)
      if [[ "${1:-}" == "doctor" ]]; then
        shift || true
      fi
      run_script "scripts/diagnostics/mcp-doctor.sh" "MCP doctor script" "$@"
      ;;
    registry)
      local repo_root registry_file json_mode=0
      repo_root="$(resolve_chezmoi_source_dir)"
      [[ -z "$repo_root" ]] && repo_root="$(require_source_dir)"
      registry_file="${MCP_REGISTRY_CONFIG:-$repo_root/dot_config/dotfiles/mcp-registry.json}"
      if [[ "${1:-}" == "registry" ]]; then
        shift || true
      fi
      if [[ "${1:-}" == "--json" || "${1:-}" == "-j" ]]; then
        json_mode=1
      fi
      if [[ ! -f "$registry_file" ]]; then
        die "MCP registry not found: $registry_file"
      fi
      if [[ "$json_mode" -eq 1 ]]; then
        exec cat "$registry_file"
      fi
      if command -v jq >/dev/null 2>&1; then
        ui_header "MCP Registry"
        jq -r '
          .servers
          | to_entries[]
          | "\(.key)\t\(.value.transport)\t\(.value.launcher)\t\(.value.package // .value.url // "local")"
        ' "$registry_file" | while IFS=$'\t' read -r name transport launcher target; do
          ui_ok "$name" "$transport via $launcher -> $target"
        done
      else
        exec cat "$registry_file"
      fi
      ;;
    *)
      echo "Usage: dot mcp [doctor|registry]" >&2
      exit 1
      ;;
  esac
}

# Dispatch — cmd_mode is defined in agent.sh (sourced above)
case "${1:-}" in
  upgrade)
    shift
    cmd_upgrade "$@"
    ;;
  cache-refresh | prewarm)
    shift
    cmd_prewarm "$@"
    ;;
  docs)
    shift
    cmd_docs "$@"
    ;;
  learn)
    shift
    cmd_learn "$@"
    ;;
  keys)
    shift
    cmd_keys "$@"
    ;;
  sandbox)
    shift
    cmd_sandbox "$@"
    ;;
  mcp)
    shift
    cmd_mcp "$@"
    ;;
  mode | agent)
    shift
    cmd_mode "$@"
    ;;
  --help | -h | help)
    cat <<'EOF'
Usage: meta.sh <command> [args...]

Commands:
  cache-refresh, prewarm, docs, learn, keys, sandbox, mcp, mode, agent
EOF
    ;;
  "")
    cat <<'EOF'
Usage: meta.sh <command> [args...]

Commands:
  cache-refresh, prewarm, docs, learn, keys, sandbox, mcp, mode, agent
EOF
    exit 1
    ;;
  *)
    echo "Unknown meta command: ${1:-}" >&2
    exit 1
    ;;
esac
