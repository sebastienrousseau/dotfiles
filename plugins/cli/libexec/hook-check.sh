#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# dot cli hook check [--agent <id>] — the policy hook (plan P1.1, ADR-025).
#
# Claude Code and Codex run it as a PreToolUse hook and Gemini CLI as a
# BeforeTool hook, with the tool call as JSON on stdin; and on each prompt
# (UserPromptSubmit, Gemini CLI: BeforeAgent), where the policy's [budget]
# decides (P1.3). dot cli hook install wires both. With no
# ~/.config/dotfiles/ai-policy.toml ($DOT_AI_POLICY) it allows at once.
# With one, dot-policy (built from ~/.local/share/dot-policy) decides by
# the active mode's rules. When the policy is there but dot-policy is
# missing or fails, the call is denied, or the prompt blocked: a policy
# that cannot be checked fails closed. A verdict is printed in the form the
# agent reads, with the reason; an allow prints nothing (Gemini CLI: {}).
# It always exits 0, so an agent never reads a crash as a verdict.

set -uo pipefail

# _check_deny AGENT KIND REASON: the denial as AGENT's hook protocol reads
# it, for a tool call or (KIND prompt) a prompt.
_check_deny() {
  local r="${3//\\/\\\\}"
  r="${r//\"/\\\"}"
  if [[ "$1" == gemini ]]; then
    printf '{"decision":"deny","reason":"%s"}\n' "$r"
  elif [[ "$2" == prompt ]]; then
    printf '{"decision":"block","reason":"%s"}\n' "$r"
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$r"
  fi
}

check_main() {
  local agent=claude policy bin out payload="" kind=tool what="every tool call is denied"
  [[ "${1:-}" != --agent ]] || agent="${2:-claude}"
  policy="${DOT_AI_POLICY:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/ai-policy.toml}"
  bin="${DOT_POLICY_BIN:-$HOME/.local/bin/dot-policy}"
  [[ -t 0 ]] || IFS= read -r -d '' payload || :
  if [[ "$payload" =~ \"hook_event_name\"[[:space:]]*:[[:space:]]*\"(UserPromptSubmit|BeforeAgent)\" ]]; then
    kind=prompt what="every prompt is blocked"
  fi
  # dot-policy's verdict counts only when it ran to the end: a crash, or a
  # file that is not dot-policy, must not read as an allow.
  if [[ ! -e "$policy" ]]; then
    [[ "$agent" != gemini ]] || printf '{}\n'
  elif [[ -x "$bin" ]] && out="$(printf '%s' "$payload" | "$bin" check --agent "$agent" --policy "$policy")"; then
    [[ -z "$out" ]] || printf '%s\n' "$out"
  else
    _check_deny "$agent" "$kind" "dot ai policy: $policy is set but dot-policy is missing or failed (install Go with mise, then chezmoi apply); $what"
  fi
}

check_main "$@"
exit 0
