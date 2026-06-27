#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
## Dotfiles AI Commands.
##
## Provides AI CLI status, setup, RAG query, and bridge commands.
## Wraps AI CLI tools with contextual patterns and system metadata.
## Usage: dot ai [delegate|cost|dashboard|proxy|local|status]|ai-setup|ai-query|cl|copilot|agy|kiro|sgpt|ollama|opencode|aider|autohand|vibe|qwen|zai

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"
# shellcheck source=../../../lib/dot/ai-commands.sh
source "$SCRIPT_DIR/../../../lib/dot/ai-commands.sh"

dot_ui_command_banner "AI and Agents" "${1:-}"

PATTERN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ai/patterns"
AI_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/ai"
AI_STATUS_TTL="${DOTFILES_AI_STATUS_TTL:-300}"
AI_STATUS_CACHE_FILE="${AI_CACHE_DIR}/status.tsv"

# Fallback to source tree if patterns don't exist in config (common in CI)
if [[ ! -d "$PATTERN_DIR" ]]; then
  _AI_SRC="$(cd "$SCRIPT_DIR/../../.." && pwd)"
  if [[ -d "$_AI_SRC/dot_config/ai/patterns" ]]; then
    PATTERN_DIR="$_AI_SRC/dot_config/ai/patterns"
  fi
fi

_show_ai_bridge_usage() {
  echo "Usage: dot ai \"<prompt>\"              # one-shot on Claude"
  echo "       dot ai <tool> \"<prompt>\"       # one-shot on a tool"
  echo "       dot ai <tool> --style <name> \"<prompt>\""
  echo "       dot ai chat [tool]             # interactive session"
  echo ""
  echo "Tools: cl codex copilot agy goose kiro sgpt ollama opencode aider autohand vibe qwen zai"
  echo ""
  echo "Available styles:"
  # shellcheck disable=SC2012
  ls -1 "$PATTERN_DIR" 2>/dev/null | sed 's/\.md$//' | sed 's/^/  - /' || echo "  (none)"
}

_ai_cache_fresh() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  local now mtime
  now=$(date +%s)
  mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo 0)
  ((now - mtime < AI_STATUS_TTL))
}

_ai_extract_version() {
  local bin="$1"
  local output version
  output=$("$bin" --version 2>/dev/null | head -1) || true
  version=$(printf '%s' "$output" | sed 's/^[^0-9]*//' | sed 's/[[:space:]]*$//' | sed 's/\.$//')
  [[ -n "$version" ]] && printf '%s\n' "$version" || printf 'installed\n'
}

_ai_refresh_status_cache() {
  # Entries passed by value (not a `local -n` nameref — bash 4.3+; macOS bash is 3.2).
  local ai_entries=("$@")
  local tmp_file
  tmp_file="$(mktemp)"
  mkdir -p "$AI_CACHE_DIR"

  local total=${#ai_entries[@]}

  # Cold-cache refresh runs `$bin --version` for every tool — node-
  # based ones are slow to start, so the total can hit 15-30s. Show a
  # spinner so the user has feedback.
  ui_spinner_start "Probing $total AI tools (cached for ${AI_STATUS_TTL}s)"

  local jobs="${DOTFILES_AI_PROBE_JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
  local probe_dir
  probe_dir="$(mktemp -d)"

  # Probe via xargs -P. The probe logic lives INLINE in the bash -c
  # string rather than as an exported function, because `export -f`
  # doesn't always survive across bash invocations on every platform
  # (notably macOS bash 3.2 needs the BASH_FUNC_*() env-var format,
  # which subtly breaks for some shells in PATH). Inlining sidesteps
  # the inheritance question entirely.
  local i=0
  local entry
  local indexed=()
  for entry in "${ai_entries[@]}"; do
    indexed+=("$i|$entry")
    i=$((i + 1))
  done
  # Probe is non-interactive: </dev/null is a clean EOF for tools that
  # prompt for an API key on first run; `timeout 8` caps the wait.
  # Node-based tools (codex, copilot, opencode) need 5-8s on cold start;
  # 3s caused false "not installed" results in the status cache.
  # shellcheck disable=SC2016
  local _TO=""
  command -v timeout >/dev/null 2>&1 && _TO="timeout 8 "
  local probe_script='
    payload="$1"; out_dir="$2"; to="$3"
    i="${payload%%|*}"; entry="${payload#*|}"
    IFS="|" read -r category role name bin desc <<<"$entry"
    if command -v "$bin" >/dev/null 2>&1; then
      output=$($to "$bin" --version </dev/null 2>/dev/null | head -1) || true
      version=$(printf "%s" "$output" | sed "s/^[^0-9]*//;s/[[:space:]]*$//;s/\.$//")
      printf "%s\t1\t%s\n" "$bin" "$version" >"$out_dir/$i"
    else
      printf "%s\t0\t\n" "$bin" >"$out_dir/$i"
    fi
  '
  # NOTE: `-I{}` already implies one input line per invocation. Adding
  # `-n1` on top triggers a BSD-xargs quirk where the input line is
  # word-split on whitespace ("0|Agents (autonomous)|..." → multiple
  # entries). Use only `-I{}`.
  #
  # ALSO: feed null-delimited records (`-0`) so apostrophes and
  # other quote-like characters in the descriptions ("Block's coding
  # agent") don't trigger xargs's "unterminated quote" parser.
  printf '%s\0' "${indexed[@]}" |
    xargs -0 -I{} -P"$jobs" \
      bash -c "$probe_script" _ {} "$probe_dir" "$_TO" \
      2>/dev/null || true

  # Re-assemble in original entry order.
  local n
  for ((n = 0; n < i; n++)); do
    [[ -f "$probe_dir/$n" ]] && cat "$probe_dir/$n" >>"$tmp_file"
  done
  rm -rf "$probe_dir"

  # Guard with `|| true` because ui_spinner_stop's last line evaluates
  # to rc=1 when stdout is a TTY (the `[[ ! -t 1 ]] && printf` short-
  # circuit). Under `set -euo pipefail` that rc would kill the script
  # right before we get to write the cache, leaving the user with a
  # silent broken cold-cache run. Defence in depth — the function
  # now also has an explicit `return 0` upstream.
  ui_spinner_stop || true

  mv "$tmp_file" "$AI_STATUS_CACHE_FILE"
}

_ai_get_cached_status() {
  cat "$AI_STATUS_CACHE_FILE"
}

# Look up field $2 (2=present 0/1, 3=version) for binary $1 from the
# cached TSV. Replaces a bash-4 associative array for macOS bash 3.2.
_ai_status_field() {
  awk -F'\t' -v b="$1" -v f="$2" '$1==b{print $f;exit}' "$AI_STATUS_CACHE_FILE" 2>/dev/null
}

# _ai_mise_pkg (binary -> mise package map) is defined in lib/dot/ai-install.sh.

cmd_ai_status() {
  ui_header "AI CLI Status"

  # category|role|name|binary|description
  local -a ai_clis=(
    "Agents (autonomous)|agent|Claude Code|claude|Anthropic CLI agent"
    "Agents (autonomous)|agent|Codex CLI|codex|OpenAI Codex agent"
    "Agents (autonomous)|agent|Copilot CLI|copilot|GitHub Copilot CLI"
    "Agents (autonomous)|agent|Goose|goose|Block's coding agent"
    "Coding (interactive)|coding|Aider|aider|AI pair programmer"
    "Coding (interactive)|coding|OpenCode|opencode|Terminal coding assistant"
    "Coding (interactive)|coding|Autohand Code|autohand|Autohand coding agent"
    "Coding (interactive)|coding|Mistral Vibe|vibe|Mistral AI coding agent"
    "Coding (interactive)|coding|Qwen Code|qwen|Qwen AI coding assistant"
    "Coding (interactive)|coding|ZAI|zai|Zhipu AI coding agent"
    "General (prompt-based)|general|Shell-GPT|sgpt|ChatGPT terminal interface"
    "General (prompt-based)|general|Antigravity CLI|agy|Google Antigravity CLI"
    "Runtime (local)|local|Ollama|ollama|Local LLM runner"
    "Cloud (platform)|cloud|Kiro CLI|kiro-cli|AWS AI assistant"
  )

  if ! _ai_cache_fresh "$AI_STATUS_CACHE_FILE"; then
    _ai_refresh_status_cache "${ai_clis[@]}"
  fi

  local -a installed=()
  local -a missing=()
  local current_category=""
  local category role name bin desc ver
  for entry in "${ai_clis[@]}"; do
    IFS='|' read -r category role name bin desc <<<"$entry"
    if [[ "$category" != "$current_category" ]]; then
      echo ""
      ui_section "$category"
      current_category="$category"
    fi
    if [[ "$(_ai_status_field "$bin" 2)" == "1" ]]; then
      ver="$(_ai_status_field "$bin" 3)"
      [[ -z "$ver" ]] && ver="installed"
      [[ "$bin" == "claude" ]] && ver="${ver%% *}"
      ui_ok "$name" "$ver — $desc"
      installed+=("$name|$bin|$role")
    else
      ui_info "$name" "— $desc (not installed)"
      missing+=("$name|$bin")
    fi
  done

  # Offer to install missing providers via mise
  if [[ ${#missing[@]} -gt 0 ]] && has_command mise; then
    echo ""
    local _ai_install_action=""
    if has_command gum; then
      _ai_install_action=$(printf '%s\n' "Install all" "Choose which to install" "Skip" |
        gum choose --header "Missing AI providers — install via mise?") || _ai_install_action=""
    else
      ui_info "Tip" "Install missing providers: mise install"
      ui_info "Tip" "Or individually: mise use -g <package>@latest"
    fi

    local -a _ai_to_install=()
    case "$_ai_install_action" in
      "Install all")
        _ai_to_install=("${missing[@]}")
        ;;
      "Choose which to install")
        local -a _ai_pick_choices=()
        for entry in "${missing[@]}"; do
          IFS='|' read -r name bin <<<"$entry"
          _ai_pick_choices+=("$name")
        done
        local _ai_picked
        _ai_picked=$(printf '%s\n' "${_ai_pick_choices[@]}" |
          gum choose --no-limit --header "Select providers to install (Space to toggle, Enter to confirm)") || _ai_picked=""
        if [[ -n "$_ai_picked" ]]; then
          while IFS= read -r selected; do
            [[ -z "$selected" ]] && continue
            for entry in "${missing[@]}"; do
              IFS='|' read -r name bin <<<"$entry"
              if [[ "$name" == "$selected" ]]; then
                _ai_to_install+=("$entry")
              fi
            done
          done <<<"$_ai_picked"
        fi
        ;;
    esac

    if [[ ${#_ai_to_install[@]} -gt 0 ]]; then
      echo ""
      for entry in "${_ai_to_install[@]}"; do
        IFS='|' read -r name bin <<<"$entry"
        if [[ "$bin" == "claude" ]]; then
          install_claude_native "$name"
          continue
        fi
        if [[ "$bin" == "agy" ]]; then
          install_agy_native "$name"
          continue
        fi
        local pkg
        pkg=$(_ai_mise_pkg "$bin")
        if [[ -n "$pkg" ]]; then
          if has_command gum; then
            if gum spin --spinner dot --title "Installing $name ($pkg)" -- \
              mise use -g "$pkg@latest" 2>&1; then
              ui_ok "$name" "installed"
            else
              ui_warn "$name" "install failed (continuing)"
            fi
          else
            ui_info "Installing" "$name via mise ($pkg)"
            mise use -g "$pkg@latest" 2>&1 || ui_warn "$name" "install failed (continuing)"
          fi
        fi
      done
      # Invalidate cache after installs
      rm -f "$AI_STATUS_CACHE_FILE"
      echo ""
      ui_ok "Done" "Run 'dot ai' again to see updated status"
    fi
  fi

  echo ""
  if [ ${#installed[@]} -eq 0 ]; then
    ui_warn "No AI CLIs installed"
  elif has_command gum; then
    ui_info "Launch" "Select an AI CLI to start"
    local -a choices=()
    for entry in "${installed[@]}"; do
      IFS='|' read -r name bin role <<<"$entry"
      choices+=("$(printf '%-16s — %s' "$name" "$role")")
    done
    local pick
    pick=$(printf '%s\n' "${choices[@]}" | gum choose --header "Select an AI CLI") || true
    if [ -n "$pick" ]; then
      pick="${pick%% — *}"
      pick="${pick%"${pick##*[![:space:]]}"}"
      for entry in "${installed[@]}"; do
        IFS='|' read -r name bin role <<<"$entry"
        if [ "$name" = "$pick" ]; then
          echo ""
          ui_info "Starting" "$name ($bin)"
          exec "$bin"
        fi
      done
    fi
  else
    ui_info "Tip" "Install gum for interactive launcher: mise use -g gum"
  fi
}

cmd_ai_setup() {
  run_script "scripts/ops/ai-setup.sh" "AI setup script" "$@"
}

cmd_ai_query() {
  run_script "dot_local/bin/executable_dot-ai" "AI RAG script" "$@"
}

_ai_log_run() {
  local provider="$1" exit_code="$2" duration_secs="$3" prompt_words="$4"
  local project ts log_bin
  project="$(basename "$PWD")"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  log_bin="${HOME}/.local/bin/dot-ai-log"
  [[ -x "$log_bin" ]] || return 0
  "$log_bin" "$provider" "$project" "$exit_code" "$duration_secs" "$prompt_words" "$ts" || true
}

run_ai_with_context() {
  local tool="$1"
  shift
  local pattern_name=""
  local prompt=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help | -h)
        _show_ai_bridge_usage
        exit 0
        ;;
      --style | --pattern | -p)
        pattern_name="$2"
        shift 2
        ;;
      *)
        prompt="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$prompt" ]]; then
    _show_ai_bridge_usage
    exit 1
  fi

  local system_context=""
  if [[ -n "$pattern_name" ]]; then
    local pattern_file="$PATTERN_DIR/${pattern_name}.md"
    if [[ -f "$pattern_file" ]]; then
      system_context=$(cat "$pattern_file")
    else
      ui_err "Pattern not found" "$pattern_name"
      exit 1
    fi
  fi

  # Inject dynamic system metadata
  local metadata
  metadata="## System Metadata
- OS: $(uname -s) $(uname -r)
- Arch: $(uname -m)
- Date: $(date -u)"

  local full_prompt="${system_context}

${metadata}

## User Request
${prompt}"

  # Resolve the binary name for the tool
  local tool_bin="$tool"
  case "$tool" in
    cl) tool_bin="claude" ;;
    kiro) tool_bin="kiro-cli" ;;
  esac

  # Check if the tool is installed; offer mise install if not
  if ! has_command "$tool_bin"; then
    local mise_pkg
    mise_pkg=$(_ai_mise_pkg "$tool_bin")
    if [[ -n "$mise_pkg" ]] && has_command mise; then
      ui_warn "$tool" "not installed"
      local do_install=""
      if has_command gum; then
        do_install=$(gum confirm "Install $tool via mise ($mise_pkg)?" && echo "yes" || echo "no")
      else
        printf "Install %s via mise (%s)? [y/N] " "$tool" "$mise_pkg"
        read -r do_install
        case "$do_install" in y | Y | yes) do_install="yes" ;; *) do_install="no" ;; esac
      fi
      if [[ "$do_install" == "yes" ]]; then
        ui_info "Installing" "$tool via mise ($mise_pkg)"
        mise use -g "$mise_pkg@latest" 2>&1 || {
          ui_err "$tool" "installation failed"
          exit 1
        }
        rm -f "$AI_STATUS_CACHE_FILE"
      else
        ui_err "$tool" "not installed — install with: mise use -g $mise_pkg@latest"
        exit 1
      fi
    elif [[ "$tool_bin" == "agy" ]]; then
      ui_warn "$tool" "not installed"
      ui_info "Install" "curl -fsSL -o /tmp/agy-install.sh https://antigravity.google/cli/install.sh && bash /tmp/agy-install.sh"
      exit 1
    else
      ui_err "$tool" "not installed and mise not available"
      exit 1
    fi
  fi

  ui_info "Executing $tool with pattern: ${pattern_name:-none}"

  # Route non-Claude tools through the local gateway when one is running.
  # The primary Claude ALWAYS uses its native session — never route it,
  # and never set ANTHROPIC_API_KEY where Claude Code can see it (that
  # disables claude.ai connectors). Routing is scoped to this run's
  # subprocess; the interactive shell is never touched.
  case "$tool" in
    cl | claude) : ;;
    *)
      local _ai_local_env="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/ai-local.env"
      # shellcheck disable=SC1090
      [[ -r "$_ai_local_env" ]] && source "$_ai_local_env"
      ;;
  esac

  # Wrap the provider invocation so we can log it to the unified AI run
  # log. Each entry feeds `dot ai cost` so users see spend across every
  # provider, not just vibe. Token-level fields are zero for providers
  # that don't surface them — the report tolerates missing data.
  local _ai_start_ts _ai_exit _ai_end_ts _ai_dur _ai_prompt_words
  _ai_start_ts=$(date +%s)
  _ai_prompt_words=$(printf '%s' "$prompt" | wc -w | tr -d ' ')
  _ai_exit=0
  case "$tool" in
    cl | claude)
      printf "%s" "$full_prompt" | claude || _ai_exit=$?
      ;;
    codex)
      printf "%s" "$full_prompt" | codex || _ai_exit=$?
      ;;
    copilot)
      copilot -sp "$full_prompt" || _ai_exit=$?
      ;;
    agy)
      printf "%s" "$full_prompt" | agy chat || _ai_exit=$?
      ;;
    goose)
      printf "%s" "$full_prompt" | goose session start || _ai_exit=$?
      ;;
    kiro | kiro-cli)
      printf "%s" "$full_prompt" | kiro-cli chat || _ai_exit=$?
      ;;
    sgpt)
      printf "%s" "$full_prompt" | sgpt --chat shell-gpt || _ai_exit=$?
      ;;
    ollama)
      printf "%s" "$full_prompt" | ollama run llama3.2 || _ai_exit=$?
      ;;
    opencode)
      printf "%s" "$full_prompt" | opencode query || _ai_exit=$?
      ;;
    aider)
      printf "%s" "$full_prompt" | aider --msg "-" || _ai_exit=$?
      ;;
    autohand)
      printf "%s" "$full_prompt" | autohand chat || _ai_exit=$?
      ;;
    vibe)
      printf "%s" "$full_prompt" | vibe chat || _ai_exit=$?
      ;;
    qwen)
      printf "%s" "$full_prompt" | qwen chat || _ai_exit=$?
      ;;
    zai)
      printf "%s" "$full_prompt" | zai chat || _ai_exit=$?
      ;;
    *)
      ui_err "Unsupported tool" "$tool"
      exit 1
      ;;
  esac
  _ai_end_ts=$(date +%s)
  _ai_dur=$((_ai_end_ts - _ai_start_ts))
  _ai_log_run "$tool_bin" "$_ai_exit" "$_ai_dur" "$_ai_prompt_words" 2>/dev/null || true
  return "$_ai_exit"
}

# Dispatch — flat, verb-first surface (see docs/AI.md).
case "${1:-}" in
  ai)
    shift
    case "${1:-}" in
      "")
        # Bare `dot ai` → the cockpit (fleet launcher today; a Bubble Tea
        # TUI replaces this in a later slice).
        cmd_ai_status
        ;;
      chat)
        shift
        cmd_ai_chat "$@"
        ;;
      tools)
        shift
        cmd_ai_status "$@"
        ;;
      serve)
        shift
        _ai_serve "$@"
        ;;
      cost)
        shift
        cmd_ai_cost "$@"
        ;;
      login)
        shift
        cmd_ai_setup "$@"
        ;;
      doctor)
        shift
        cmd_ai_doctor "$@"
        ;;
      ask)
        shift
        cmd_ai_query "$@"
        ;;
      run)
        shift
        _ai_oneshot "$@"
        ;;
      delegate)
        shift
        cmd_ai_delegate "$@"
        ;;
      # Deprecated verbs — still work, with a one-line hint to the new name.
      status)
        _ai_deprecated "dot ai tools"
        cmd_ai_status "$@"
        ;;
      dashboard | dash)
        _ai_deprecated "dot ai  (cockpit) or  dot ai cost"
        if has_command dot-ai-dash; then exec dot-ai-dash "${@:2}"; else cmd_ai_status; fi
        ;;
      proxy)
        shift
        _ai_deprecated "dot ai serve"
        has_command dot-ai-proxy && exec dot-ai-proxy "$@" || exit 1
        ;;
      local)
        _ai_deprecated "dot ai serve"
        has_command dot-ai-proxy && exec dot-ai-proxy "$@" || exit 1
        ;;
      *)
        # Bare prompt (`dot ai "fix this"`) or `dot ai <tool> "…"` → one-shot.
        _ai_oneshot "$@"
        ;;
    esac
    ;;
  # Deprecated top-level forms — kept for muscle memory.
  ai-setup)
    _ai_deprecated "dot ai login"
    shift
    cmd_ai_setup "$@"
    ;;
  ai-query)
    _ai_deprecated "dot ai ask"
    shift
    cmd_ai_query "$@"
    ;;
  cl | claude | codex | copilot | agy | goose | kiro | sgpt | ollama | opencode | aider | autohand | vibe | qwen | zai)
    _ai_deprecated "dot ai $1"
    tool="$1"
    shift
    run_ai_with_context "$tool" "$@"
    ;;
  *)
    echo "Unknown ai command: ${1:-}" >&2
    exit 1
    ;;
esac
