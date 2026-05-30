---
name: vibe-report
description: Show Vibe usage report — token/cost/failure stats. Usage: /vibe-report [--since N] [--project NAME] [--fails]
license: MIT
user-invocable: true
allowed-tools:
  - bash
---

# /vibe-report

Run `~/.claude/skills/vibe/tools/delegate-report` with any flags
extracted from the arguments and display output verbatim. (Also
exposed as `dot ai cost` for terminal use outside Claude Code:
both call the same script.)

| User says | Flag |
|-----------|------|
| "last 7 days", "7d" | `--since 7` |
| "last 30 days", "30d" | `--since 30` |
| "project foo" | `--project foo` |
| "only failures", "fails", "bugs" | `--fails` |
| (nothing) | (no flags — full report) |
