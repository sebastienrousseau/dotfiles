#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by scripts/dot/commands/ai.sh — the `dot ai` subcommand bodies.
# Split out of ai.sh to keep that dispatcher under the 600-line limit.
# Requires ui_*/has_command/run_script (utils.sh) and run_ai_with_context
# (ai.sh) to be defined by the caller before these run.

# Re-source guard.
[[ "${_DOT_LIB_AI_COMMANDS_LOADED:-0}" == "1" ]] && return 0
_DOT_LIB_AI_COMMANDS_LOADED=1

# _ai_deprecated <new-command> — one-line stderr hint; the old form still runs.
_ai_deprecated() {
  ui_warn "deprecated" "use: $1" >&2
}

# _ai_invoke_provider <tool> <full_prompt> — run a fleet tool headlessly and
# return its exit code. Each provider has its own one-shot incantation; kept
# here (not in the ai.sh dispatcher) so adding a tool is a single edit and the
# dispatcher stays under the line budget.
_ai_invoke_provider() {
  local tool="$1" full_prompt="$2" rc=0
  case "$tool" in
    cl | claude) printf "%s" "$full_prompt" | claude || rc=$? ;;
    codex) printf "%s" "$full_prompt" | codex || rc=$? ;;
    copilot) copilot -sp "$full_prompt" || rc=$? ;;
    agy) printf "%s" "$full_prompt" | agy chat || rc=$? ;;
    goose) goose run -t "$full_prompt" || rc=$? ;;
    crush) crush run "$full_prompt" || rc=$? ;;
    amp) amp -x "$full_prompt" || rc=$? ;;
    cursor | cursor-agent) cursor-agent -p "$full_prompt" || rc=$? ;;
    grok) grok --no-auto-update -p "$full_prompt" || rc=$? ;;
    kimi) kimi -p "$full_prompt" --quiet || rc=$? ;;
    kiro | kiro-cli) printf "%s" "$full_prompt" | kiro-cli chat || rc=$? ;;
    sgpt) printf "%s" "$full_prompt" | sgpt --chat shell-gpt || rc=$? ;;
    ollama) printf "%s" "$full_prompt" | ollama run llama3.2 || rc=$? ;;
    opencode) printf "%s" "$full_prompt" | opencode query || rc=$? ;;
    aider) printf "%s" "$full_prompt" | aider --msg "-" || rc=$? ;;
    autohand) printf "%s" "$full_prompt" | autohand chat || rc=$? ;;
    vibe) printf "%s" "$full_prompt" | vibe chat || rc=$? ;;
    qwen) printf "%s" "$full_prompt" | qwen chat || rc=$? ;;
    zai) printf "%s" "$full_prompt" | zai chat || rc=$? ;;
    *)
      ui_err "Unsupported tool" "$tool"
      return 2
      ;;
  esac
  return "$rc"
}

# _ai_cockpit <fallback-cmd…> — launch the Bubble Tea cockpit (dot-ai-tui)
# when it is built and we're on a TTY; otherwise run the fallback (the plain
# fleet launcher for CI, pipes, or before the binary is built).
_ai_cockpit() {
  if has_command dot-ai-tui && [[ -t 1 ]]; then
    exec dot-ai-tui
  fi
  "$@"
}

# _ai_oneshot [tool] <prompt…> — run a one-shot. An optional leading tool
# name selects the provider; otherwise the prompt runs on Claude. This is
# the engine behind `dot ai "<prompt>"` and `dot ai <tool> "<prompt>"`.
_ai_oneshot() {
  local tool="claude"
  case "${1:-}" in
    cl | claude | codex | copilot | goose | crush | amp | cursor-agent | grok | kimi | agy | kiro | sgpt | ollama | opencode | aider | autohand | vibe | qwen | zai)
      tool="$1"
      shift
      ;;
  esac
  run_ai_with_context "$tool" "$@"
}

# _ai_serve [stop|status|logs|setup] — the local Claude gateway. `serve`
# does both: start also routes the non-Claude fleet through it; stop also
# un-routes. Thin wrapper over the dot-ai-proxy lifecycle helper.
_ai_serve() {
  if ! has_command dot-ai-proxy; then
    ui_warn "dot-ai-proxy" "not found — run: chezmoi apply"
    return 1
  fi
  case "${1:-start}" in
    "" | start)
      dot-ai-proxy start && dot-ai-proxy local on
      ;;
    stop)
      dot-ai-proxy local off
      dot-ai-proxy stop
      ;;
    status)
      dot-ai-proxy status
      ;;
    logs)
      shift
      dot-ai-proxy logs "$@"
      ;;
    setup)
      dot-ai-proxy setup
      ;;
    *)
      ui_err "Usage" "dot ai serve [stop|status|logs|setup]"
      return 1
      ;;
  esac
}

# cmd_ai_chat [tool] — open an interactive session with a tool. With no
# tool, fall back to the fleet launcher.
cmd_ai_chat() {
  if [[ $# -eq 0 ]]; then
    cmd_ai_status
    return
  fi
  local tool="$1" bin="$1"
  case "$tool" in
    cl | claude) bin=claude ;;
    kiro) bin=kiro-cli ;;
  esac
  if ! has_command "$bin"; then
    ui_err "$tool" "not installed — run 'dot ai tools' to install"
    return 1
  fi
  exec "$bin"
}

# cmd_ai_doctor — health-check the fleet + gateway in one place.
cmd_ai_doctor() {
  ui_header "AI doctor"
  if has_command claude; then
    ui_ok "claude CLI" "$(claude --version 2>/dev/null | head -1 || echo installed)"
  else
    ui_err "claude CLI" "not installed (the gateway engine needs it)"
  fi
  if has_command dot-ai-serve; then
    ui_ok "gateway engine" "dot-ai-serve deployed"
  else
    ui_warn "gateway engine" "dot-ai-serve not deployed — run: chezmoi apply"
  fi
  has_command dot-ai-proxy && dot-ai-proxy status
  local installed=0 total=0 b
  for b in claude codex copilot goose crush amp cursor-agent grok kimi agy sgpt ollama opencode aider kiro-cli autohand vibe qwen zai; do
    total=$((total + 1))
    has_command "$b" && installed=$((installed + 1))
  done
  ui_info "Fleet" "$installed/$total tools installed — 'dot ai tools' to manage"
}

# cmd_ai_setup [tool…] — authenticate / initialize AI CLIs (dot ai login).
cmd_ai_setup() {
  run_script "scripts/ops/ai-setup.sh" "AI setup script" "$@"
}

# cmd_ai_query <question…> — RAG query over the dotfiles repo (dot ai ask).
cmd_ai_query() {
  run_script "dot_local/bin/executable_dot-ai" "AI RAG script" "$@"
}

# cmd_ai_install [all|<tool>] — install missing fleet tools, or one tool.
# Uses the native installers for claude/goose/agy and mise for the rest.
cmd_ai_install() {
  local target="${1:-all}"
  local fleet=(claude codex copilot goose crush amp cursor-agent grok kimi agy sgpt ollama opencode aider kiro-cli autohand vibe qwen zai)
  local -a todo=()
  local b pkg
  case "$target" in
    all | "")
      for b in "${fleet[@]}"; do has_command "$b" || todo+=("$b"); done
      if [[ ${#todo[@]} -eq 0 ]]; then
        ui_ok "AI fleet" "all tools already installed"
        return 0
      fi
      ui_info "Installing" "${#todo[@]} missing tool(s)"
      ;;
    *)
      if has_command "$target"; then
        ui_ok "$target" "already installed"
        return 0
      fi
      todo=("$target")
      ;;
  esac
  for b in "${todo[@]}"; do
    case "$b" in
      claude)
        install_claude_native "Claude Code"
        continue
        ;;
      goose)
        install_goose_native "Goose"
        continue
        ;;
      agy)
        install_agy_native "Antigravity CLI"
        continue
        ;;
      amp)
        install_amp_native "Amp"
        continue
        ;;
      cursor-agent)
        install_cursor_native "Cursor CLI"
        continue
        ;;
      grok)
        install_grok_native "Grok Build"
        continue
        ;;
      kimi)
        install_kimi_native "Kimi CLI"
        continue
        ;;
    esac
    pkg="$(_ai_mise_pkg "$b")"
    if [[ -z "$pkg" ]]; then
      ui_warn "$b" "no installer mapping — skipping"
      continue
    fi
    if ! has_command mise; then
      ui_err "$b" "mise not available — install: mise use -g $pkg@latest"
      continue
    fi
    ui_info "Installing" "$b ($pkg)"
    if mise use -g "$pkg@latest" 2>&1; then
      ui_ok "$b" "installed"
    else
      ui_warn "$b" "install failed (continuing)"
    fi
  done
  rm -f "${AI_STATUS_CACHE_FILE:-}" 2>/dev/null || true
  ui_ok "Done" "run 'dot ai tools' to verify"
}

# Locate the vibe-delegate / delegate-report tools deployed by the /vibe
# Claude Code skill. Path stays in sync with
# defaults/dot_claude/skills/vibe/tools/.
_ai_delegate_tool() {
  local tool="$1" # vibe-delegate | delegate-report
  local path="${HOME}/.claude/skills/vibe/tools/${tool}"
  if [[ ! -x "$path" ]]; then
    ui_err "$tool" "not found at $path" >&2
    ui_info "Hint" "Run 'chezmoi apply' to deploy the /vibe skill" >&2
    return 1
  fi
  printf '%s\n' "$path"
}

# cmd_ai_delegate "<prompt>" [max-turns] [agent] [timeout] — background
# delegation via the same delegator the /vibe slash command uses.
cmd_ai_delegate() {
  if [[ $# -lt 1 ]]; then
    ui_err "Usage" "dot ai delegate \"<prompt>\" [max-turns] [agent] [timeout-secs]"
    ui_info "Example" "dot ai delegate \"add a CHANGELOG entry\""
    return 1
  fi
  local prompt="$1"
  shift
  local max_turns="${1:-10}"
  local agent="${2:-}"
  local timeout="${3:-180}"
  local tool
  tool="$(_ai_delegate_tool vibe-delegate)" || return 1
  if ! has_command vibe; then
    ui_warn "vibe" "not installed"
    ui_info "Install" "mise use -g pipx:mistral-vibe"
    return 1
  fi
  "$tool" "$(pwd)" "$prompt" "$max_turns" "$agent" "$timeout"
}

# cmd_ai_cost [args…] — unified AI spend report (wraps delegate-report).
cmd_ai_cost() {
  local tool
  tool="$(_ai_delegate_tool delegate-report)" || return 1
  "$tool" "$@"
}
