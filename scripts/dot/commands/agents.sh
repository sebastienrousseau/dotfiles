#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck shell=bash
#
# scripts/dot/commands/agents.sh
#
# `dot agents` — multi-harness AI agent configuration manager.
#
# Closes the #1 competitive gap identified in HARD_AUDIT_2026:
# every other dotfiles framework either targets one AI tool or
# requires hand-maintenance of N parallel config files. This command
# keeps CLAUDE.md (canonical) and AGENTS.md (cross-harness standard)
# in sync, plus stubs the Cursor/Codex tool-specific formats.
#
# Subcommands:
#   render   Regenerate AGENTS.md and tool-specific stubs from CLAUDE.md.
#   check    Verify AGENTS.md tracks CLAUDE.md (exit 0 in sync, 1 drifted).
#   list     Show which harnesses are recognised + their target paths.
#
# Reads:  CLAUDE.md (repo root) — the canonical agent context.
# Writes: AGENTS.md, .cursor/rules/dotfiles.mdc, .codex/config.toml
#         (only when invoked with `render`).

set -euo pipefail

# shellcheck disable=SC1091
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/ui.sh"
source "$SCRIPT_DIR/../lib/utils.sh"

_agents_repo_root() {
  # Resolve the chezmoi source dir (where CLAUDE.md/AGENTS.md live).
  # We REQUIRE the resolved dir to contain `.chezmoidata.toml` so a
  # user running `dot agents render` from inside some other git
  # checkout doesn't accidentally write CLAUDE.md/AGENTS.md/.cursor/
  # /.codex/ into that repo. Round-2 audit C-finding.
  #
  # On a CI runner `chezmoi source-path` may return a default path
  # like `$HOME/.local/share/chezmoi` that doesn't exist on disk —
  # we treat that as "not a match" and fall through to git, rather
  # than accepting the wrong candidate.
  local candidate=""
  if command -v chezmoi >/dev/null 2>&1; then
    candidate="$(chezmoi source-path 2>/dev/null || true)"
    if [[ -n "$candidate" && ! -f "$candidate/.chezmoidata.toml" ]]; then
      candidate=""
    fi
  fi
  if [[ -z "$candidate" ]]; then
    candidate="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
  fi
  if [[ -z "$candidate" ]] || [[ ! -f "$candidate/.chezmoidata.toml" ]]; then
    return 1
  fi
  printf '%s\n' "$candidate"
}

_agents_canonical() {
  printf "%s/CLAUDE.md" "$(_agents_repo_root)"
}

_agents_targets() {
  # printed one-per-line: <harness>\t<path-relative-to-repo-root>
  # Closes the round-2 audit gap #3 — harness parity with
  # TonyCasey/ai-dotfiles-manager (who covers 9 surfaces; we now
  # cover 12 to maintain a margin).
  local root
  root="$(_agents_repo_root)"
  cat <<EOF
agents-md	$root/AGENTS.md
cursor	$root/.cursor/rules/dotfiles.mdc
codex	$root/.codex/config.toml
windsurf	$root/.windsurf/rules.md
zed	$root/.zed/agent-config.toml
roo	$root/.roo/rules.md
cline	$root/.clinerules
aider	$root/.aider.conf.yml
continue	$root/.continuerc.json
jules	$root/.jules/system.md
gemini	$root/.gemini/GEMINI.md
EOF
}

# Strip the leading HTML comment header (everything up to the first blank
# line after the `-->`), the H1 title line (which differs by design
# between CLAUDE.md / AGENTS.md), and the trailing cross-reference
# block. Leaves the comparable content body.
_agents_body() {
  local file="$1"
  awk '
    BEGIN { in_header = 0; saw_close = 0; emit = 0 }
    /^<!--/ && NR <= 5 { in_header = 1; next }
    in_header && /-->/ { in_header = 0; saw_close = 1; next }
    in_header { next }
    saw_close && /^$/ && !emit { emit = 1; next }
    saw_close && emit { print }
    !saw_close { emit = 1; print }
  ' "$file" |
    # Drop the H1 (`# CLAUDE.md ...` or `# AGENTS.md ...`) and the
    # trailing "Need richer context?" footer if present.
    awk '
      /^# (CLAUDE|AGENTS)\.md/ { next }
      /^---$/ { trailer = 1; next }
      trailer && /^\*\*Need richer context\?\*\*/ { next }
      trailer && NF == 0 { next }
      { trailer = 0; print }
    '
}

cmd_agents() {
  local subcommand="${1:-list}"
  shift || true

  case "$subcommand" in
    list)
      ui_header "Agent harness targets"
      echo ""
      ui_table_begin "Harness" "Target Path" "Status"
      while IFS=$'\t' read -r harness path; do
        if [[ -f "$path" ]]; then
          ui_table_add "$harness" "$path" "rendered"
        else
          ui_table_add "$harness" "$path" "not yet rendered"
        fi
      done < <(_agents_targets)
      ui_table_end
      ;;
    check)
      local claude_md agents_md
      claude_md="$(_agents_canonical)"
      agents_md="$(_agents_repo_root)/AGENTS.md"
      if [[ ! -f "$claude_md" ]]; then
        ui_err "CLAUDE.md" "not found at $claude_md"
        return 2
      fi
      if [[ ! -f "$agents_md" ]]; then
        ui_warn "AGENTS.md" "missing — run 'dot agents render'"
        return 1
      fi
      # Diff the bodies (header comments differ by design).
      # `--ignore-blank-lines` so the trailing newline from the footer
      # block doesn't false-positive as drift.
      if diff -q --ignore-blank-lines <(_agents_body "$claude_md") <(_agents_body "$agents_md") >/dev/null 2>&1; then
        ui_ok "AGENTS.md" "in sync with CLAUDE.md"
        return 0
      fi
      ui_warn "AGENTS.md" "drifted from CLAUDE.md — run 'dot agents render'"
      return 1
      ;;
    render)
      local claude_md root
      claude_md="$(_agents_canonical)"
      root="$(_agents_repo_root)"
      [[ -f "$claude_md" ]] || {
        ui_err "CLAUDE.md" "not found at $claude_md"
        return 2
      }

      # 1. AGENTS.md — body of CLAUDE.md + AGENTS.md cross-reference header.
      local agents_md="$root/AGENTS.md"
      {
        cat <<'HEADER'
<!--
  AGENTS.md — Cross-harness AI agent guidelines for this repository.

  This file follows the AGENTS.md standard (originated by OpenAI in
  August 2025, stewarded since December 2025 by the Linux Foundation
  Agentic AI Foundation). Native readers: Codex CLI, GitHub Copilot,
  Cursor, Windsurf, Amp, Devin, and a growing list of other agents.

  Canonical source: CLAUDE.md (Claude Code uses CLAUDE.md natively).
  This file is kept in sync via `dot agents render`. Edit CLAUDE.md
  first; do not hand-edit AGENTS.md.
-->

HEADER
        # Replace the title line so the rendered file declares its
        # purpose, but pass everything else through unchanged.
        _agents_body "$claude_md" | sed '1s/^# CLAUDE\.md.*/# AGENTS.md — AI Assistant Guidelines/'
        cat <<'FOOTER'

---

**Need richer context?** This file is the cross-harness summary. Claude Code reads the full canonical version from [`CLAUDE.md`](./CLAUDE.md). Both files are kept in sync via `dot agents render`.
FOOTER
      } >"$agents_md"
      chmod 0644 "$agents_md" 2>/dev/null || true
      ui_ok "AGENTS.md" "rendered → $agents_md"

      # 2. Cursor rules — MDC format, points at CLAUDE.md/AGENTS.md.
      local cursor_dir="$root/.cursor/rules"
      mkdir -p "$cursor_dir"
      cat >"$cursor_dir/dotfiles.mdc" <<'MDC'
---
description: Repo conventions for the dotfiles project (sourced from CLAUDE.md/AGENTS.md)
globs:
  - "**/*"
alwaysApply: true
---

See `AGENTS.md` and `CLAUDE.md` in the repository root for the full
project conventions, repository layout, testing, and CI policy. This
Cursor rule file exists so Cursor's rule engine picks up the same
context; do not duplicate content here — keep CLAUDE.md canonical.
MDC
      chmod 0644 "$cursor_dir/dotfiles.mdc" 2>/dev/null || true
      ui_ok "Cursor" "rendered → $cursor_dir/dotfiles.mdc"

      # 3. Codex CLI config stub — declares the AGENTS.md path.
      local codex_dir="$root/.codex"
      mkdir -p "$codex_dir"
      cat >"$codex_dir/config.toml" <<'TOML'
# Codex CLI config — points at the AGENTS.md cross-harness context.
# Codex reads AGENTS.md natively; this file is a project-scoped pin so
# the CLI prefers the in-repo guidance over any global default.
project_context = "AGENTS.md"
TOML
      chmod 0644 "$codex_dir/config.toml" 2>/dev/null || true
      ui_ok "Codex" "rendered → $codex_dir/config.toml"

      # 4-11. Per-harness rules files. All eight emitters reuse the
      # same body extracted from CLAUDE.md so a single edit propagates
      # consistently. The header differs per harness so each tool sees
      # syntax it expects (front-matter style, comment block, etc.).
      _agents_render_markdown_with_header() {
        local _path="$1" _harness="$2" _header="$3"
        mkdir -p "$(dirname "$_path")"
        {
          printf '%s\n\n' "$_header"
          _agents_body "$claude_md"
          # Heredoc instead of printf — Codacy/shellcheck flags
          # printf-with-backticks-in-single-quotes (SC2016) as
          # ambiguous even when the backticks are literal Markdown.
          cat <<'FOOTER'

---

**Canonical source:** [`CLAUDE.md`](./CLAUDE.md) — keep in sync via `dot agents render`.
FOOTER
        } >"$_path"
        chmod 0644 "$_path" 2>/dev/null || true
        ui_ok "$_harness" "rendered → $_path"
      }

      # 4. Windsurf — looks for `.windsurf/rules.md`.
      _agents_render_markdown_with_header "$root/.windsurf/rules.md" \
        "Windsurf" "# Windsurf project rules

These rules govern Cascade and the Windsurf agent inside this repository."

      # 5. Roo — looks for `.roo/rules.md`.
      _agents_render_markdown_with_header "$root/.roo/rules.md" \
        "Roo" "# Roo project rules"

      # 6. Cline — looks for `.clinerules` (no extension).
      _agents_render_markdown_with_header "$root/.clinerules" \
        "Cline" "# Cline workspace rules"

      # 7. Jules — looks for `.jules/system.md`.
      _agents_render_markdown_with_header "$root/.jules/system.md" \
        "Jules" "# Jules system prompt"

      # 8. Gemini — looks for `.gemini/GEMINI.md`.
      _agents_render_markdown_with_header "$root/.gemini/GEMINI.md" \
        "Gemini" "# Gemini agent rules"

      # 9. Zed — config pointer (TOML).
      local zed_dir="$root/.zed"
      mkdir -p "$zed_dir"
      cat >"$zed_dir/agent-config.toml" <<'TOML'
# Zed agent config — points at AGENTS.md for the cross-harness body.
# Zed reads this file when its agent mode is enabled; the actual rule
# body lives in AGENTS.md (which `dot agents render` keeps current).
agent_context = "AGENTS.md"
TOML
      chmod 0644 "$zed_dir/agent-config.toml" 2>/dev/null || true
      ui_ok "Zed" "rendered → $zed_dir/agent-config.toml"

      # 10. Aider — YAML pointer to AGENTS.md / CLAUDE.md.
      cat >"$root/.aider.conf.yml" <<'YML'
# Aider config — surfaces the cross-harness context bundle.
# Aider's `--read` flag pulls in AGENTS.md / CLAUDE.md per session.
read:
  - AGENTS.md
  - CLAUDE.md
YML
      chmod 0644 "$root/.aider.conf.yml" 2>/dev/null || true
      ui_ok "Aider" "rendered → $root/.aider.conf.yml"

      # 11. Continue — JSON pointer used by VS Code / JetBrains plugin.
      cat >"$root/.continuerc.json" <<'JSON'
{
  "_comment": "Continue config pointer — see AGENTS.md for the full body.",
  "systemMessage": "Apply the rules in AGENTS.md (canonical source: CLAUDE.md). Run `dot agents render` if the two drift."
}
JSON
      chmod 0644 "$root/.continuerc.json" 2>/dev/null || true
      ui_ok "Continue" "rendered → $root/.continuerc.json"

      ui_info "Hint" "commit AGENTS.md alongside CLAUDE.md changes (or add to your pre-commit hook)"
      ;;
    --help | -h | help)
      cat <<EOF
Usage: dot agents <subcommand>

Subcommands:
  list     Show which agent harnesses are recognised and their target paths
  check    Verify AGENTS.md tracks CLAUDE.md (exit 0 in sync, 1 drifted)
  render   Regenerate AGENTS.md + 10 harness-specific files from CLAUDE.md

CLAUDE.md is the canonical source. AGENTS.md follows the cross-harness
standard read by Codex, Copilot, Cursor, Windsurf, Amp, and Devin.

Harnesses covered by 'render':
  agents-md, cursor, codex, windsurf, zed, roo, cline,
  aider, continue, jules, gemini.
EOF
      ;;
    *)
      ui_err "Unknown subcommand" "$subcommand"
      echo "Run 'dot agents --help' for usage." >&2
      return 1
      ;;
  esac
}
