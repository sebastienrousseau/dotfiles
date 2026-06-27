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

# _ai_oneshot [tool] <prompt…> — run a one-shot. An optional leading tool
# name selects the provider; otherwise the prompt runs on Claude. This is
# the engine behind `dot ai "<prompt>"` and `dot ai <tool> "<prompt>"`.
_ai_oneshot() {
  local tool="claude"
  case "${1:-}" in
    cl | claude | codex | copilot | agy | goose | kiro | sgpt | ollama | opencode | aider | autohand | vibe | qwen | zai)
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
  for b in claude codex copilot goose agy sgpt ollama opencode aider kiro-cli autohand vibe qwen zai; do
    total=$((total + 1))
    has_command "$b" && installed=$((installed + 1))
  done
  ui_info "Fleet" "$installed/$total tools installed — 'dot ai tools' to manage"
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
