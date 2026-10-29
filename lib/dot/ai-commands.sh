#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by plugins/ai/libexec/ai.sh — the `dot ai` subcommand bodies.
# Split out of ai.sh to keep that dispatcher under the 600-line limit.
# Requires ui_*/has_command/run_script (utils.sh) and run_ai_with_context
# (ai.sh) to be defined by the caller before these run.

# Re-source guard.
[[ "${_DOT_LIB_AI_COMMANDS_LOADED:-0}" == "1" ]] && return 0
_DOT_LIB_AI_COMMANDS_LOADED=1

# shellcheck source=ai-provision.sh disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ai-provision.sh"

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
    cl | claude) printf "%s" "$full_prompt" | claude --print || rc=$? ;;
    codex) printf "%s" "$full_prompt" | codex exec - || rc=$? ;;
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
    ollama) printf "%s" "$full_prompt" | ollama run "${DOTFILES_OLLAMA_MODEL:-qwen3.5:4b}" || rc=$? ;;
    opencode) opencode run "$full_prompt" || rc=$? ;;
    aider) aider --message "$full_prompt" || rc=$? ;;
    autohand) autohand --prompt "$full_prompt" || rc=$? ;;
    vibe) vibe --prompt "$full_prompt" || rc=$? ;;
    qwen) qwen --prompt "$full_prompt" || rc=$? ;;
    zai) zai --prompt "$full_prompt" || rc=$? ;;
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
  if [[ $# -gt 0 ]] && ai_roster_bin "$1" >/dev/null; then
    tool="$1"
    shift
  fi
  run_ai_with_context "$tool" "$@"
}

# cmd_ai_update: `dot ai update` — update every AI tool past its pin
# (mise core, npm and pipx globals, native agents, Ollama, LM Studio) with
# the ai-update script. `dot update` keeps the AI CLIs at their pins and
# lists the bumps instead; this is the explicit request to go beyond them.
cmd_ai_update() {
  exec bash "$(resolve_source_dir)/defaults/dot_local/bin/executable_ai-update" "$@"
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
  local tool="$1" bin
  bin="$(ai_roster_bin "$tool")" || bin="$tool"
  if ! has_command "$bin"; then
    ui_err "$tool" "not installed — run 'dot ai tools' to install"
    return 1
  fi
  if [[ "$bin" == "ollama" ]]; then
    exec ollama run "${DOTFILES_OLLAMA_MODEL:-qwen3.5:4b}"
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
  ui_section "Prerequisites"
  ai_prereq_rows
  local installed=0 total=0 eco_installed=0 b
  for b in "${AI_ROSTER_BINS[@]}"; do
    total=$((total + 1))
    has_command "$b" && installed=$((installed + 1))
  done
  ui_info "Fleet" "$installed/$total tools installed — 'dot ai tools' to manage"
  for b in "${AI_ROSTER_ECO_BINS[@]}"; do
    has_command "$b" && eco_installed=$((eco_installed + 1))
  done
  local eco_list="${AI_ROSTER_ECO_BINS[*]}"
  ui_info "Ecosystem" "$eco_installed/${#AI_ROSTER_ECO_BINS[@]} suite tools (${eco_list// /, }) — 'dot ai eco' to inspect"
}

# cmd_ai_setup [tool…] — authenticate / initialize AI CLIs (dot ai login).
cmd_ai_setup() {
  run_script "scripts/ops/ai-setup.sh" "AI setup script" "$@"
}

# cmd_ai_query <question…> — RAG query over the dotfiles repo (dot ai ask).
cmd_ai_query() {
  run_script "dot_local/bin/executable_dot-ai" "AI RAG script" "$@"
}

# cmd_ai_install [all|<tool>] [--yes] — install missing roster tools, or one.
# Prerequisites (mise, curl) are offered first; a bulk install asks once for
# the whole list. Non-zero when any tool failed to install.
cmd_ai_install() {
  local target="" arg failed=0 b rc
  local -a todo=()
  dot_apply_yes_flag "$@"
  for arg in "$@"; do [[ "$arg" == -* ]] || target="${target:-$arg}"; done
  _ai_install_todo "${target:-all}" || return 0
  ai_prepare "${todo[@]}" || return 1
  if [[ "${target:-all}" == all ]] && ! dot_consent "Install ${#todo[@]} AI tool(s): ${todo[*]}?"; then
    ui_info "AI roster" "nothing installed — rerun with --yes, or: dot ai install <tool>"
    return 0
  fi
  for b in "${todo[@]}"; do
    rc=0
    ai_install_tool "$b" "$b" || rc=$?
    ai_install_report "$b" "$b" "$rc"
    [[ "$rc" == 0 ]] || failed=$((failed + 1))
  done
  rm -f "${AI_STATUS_CACHE_FILE:-}" 2>/dev/null || true
  [[ "$failed" == 0 ]] || {
    ui_err "AI roster" "$failed tool(s) not installed"
    return 1
  }
  ui_ok "Done" "run 'dot ai tools' to verify"
}

# _ai_install_todo <all|tool>: fill the caller's todo with what is missing.
# Returns 1 (having said so) when there is nothing to install.
_ai_install_todo() {
  local b
  if [[ "$1" != all ]]; then
    has_command "$1" && {
      ui_ok "$1" "already installed"
      return 1
    }
    todo=("$1")
    return 0
  fi
  for b in "${AI_ROSTER_BINS[@]}"; do
    has_command "$b" || todo+=("$b")
  done
  [[ ${#todo[@]} -gt 0 ]] && return 0
  ui_ok "AI roster" "all tools already installed"
  return 1
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

# cmd_ai_corral [status|sync|doctor|mcp|args…] — workspace & multi-forge repo plane.
cmd_ai_corral() {
  if ! has_command corralctl; then
    ui_warn "corralctl" "not installed — run: dot ai install corralctl (or mise use -g github:sebastienrousseau/corralctl)"
    return 1
  fi
  case "${1:-status}" in
    status)
      shift || true
      corralctl status "${1:-$HOME/Code}"
      ;;
    doctor)
      shift
      corralctl doctor "${1:-$HOME/Code}" --refresh-tags
      ;;
    sync)
      shift
      corralctl "${1:-sebastienrousseau}" -c 8
      ;;
    mcp)
      shift
      corralctl mcp "$@"
      ;;
    *)
      corralctl "$@"
      ;;
  esac
}

# cmd_ai_mcp [check|graph|watch|attest|verify|doctor] — passmcp 9-repo governance plane.
cmd_ai_mcp() {
  local sub="${1:-doctor}"
  shift || true
  case "$sub" in
    doctor)
      run_script "scripts/diagnostics/mcp-doctor.sh" "MCP doctor" "$@"
      ;;
    graph)
      if has_command passmcp-graph; then
        passmcp-graph "$@"
      else
        ui_warn "passmcp-graph" "not installed — run: dot ai install passmcp-graph (or mise use -g github:sebastienrousseau/passmcp-graph)"
        return 1
      fi
      ;;
    check | watch | attest | verify | sbom | tui | serve | --version | version | --help | help)
      if has_command passmcp; then
        passmcp "$sub" "$@"
      else
        ui_warn "passmcp" "not installed — run: dot ai install passmcp (or mise use -g github:sebastienrousseau/passmcp)"
        return 1
      fi
      ;;
    *)
      ui_err "Usage" "dot ai mcp [doctor|check|graph|watch|attest|verify|sbom|tui|serve|--version]"
      return 1
      ;;
  esac
}

# cmd_ai_draft [--green] <args…> — grounded 5-phase research & C2PA synthesis via draft.
cmd_ai_draft() {
  if ! has_command draft; then
    ui_warn "draft" "not installed — run: dot ai install draft (or mise use -g github:sebastienrousseau/draft)"
    return 1
  fi
  if [[ $# -eq 0 ]]; then
    ui_err "Usage" "dot ai draft [--green] <topic-or-sources...>"
    return 1
  fi
  if [[ "${1:-}" == "--green" ]]; then
    shift
    if has_command ollama; then
      draft --extract-engine ollama --write-engine claude --second-gate "$@"
      return $?
    fi
  fi
  draft "$@"
}

# cmd_ai_eco [args…] — btop-style sustainability, ecosystem & live process snapshot.
cmd_ai_eco() {
  if has_command dot-ai-tui; then
    DOT_AI_SNAPSHOT=1 dot-ai-tui
    return $?
  fi
  ui_header "AI Ecosystem & Green Compute"
  cmd_ai_doctor
}
