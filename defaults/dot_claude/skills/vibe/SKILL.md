---
name: vibe
description: |
  Delegate a coding task to a cheap AI model (Mistral Vibe by default,
  but any provider Vibe knows about — DeepSeek, Gemini Flash, etc.) and
  supervise the result via git diff. Claude orchestrates, the cheap
  model codes. Claude consumes ~500-1500 tokens per delegation
  regardless of how many file reads the delegate does internally —
  reported ~10-17x cost savings vs Claude doing the work directly.
  Trigger: /vibe <instruction>. Also handles /vibe-report, /vibeon,
  /vibeoff, /vibestatus, /vibe-model-pick, /vibe-model-clear.
version: 1.0.0
maintainer: Sebastien Rousseau <sebastian.rousseau@gmail.com>
license: MIT
tags: [ai, delegation, cost-optimization, mistral, vibe, claude-code]
upstream: https://github.com/pcx-wave/vibe-skill
requires:
  - bash >= 4.0
  - python3 >= 3.8
  - vibe (mistral-vibe; install via `mise use -g pipx:mistral-vibe`)
user-invocable: true
allowed-tools:
  - bash
  - read_file
  - grep
---

# Vibe Orchestrator

Ported from [pcx-wave/vibe-skill](https://github.com/pcx-wave/vibe-skill).
This dotfiles edition deploys the skill files to `~/.claude/skills/vibe/`
via chezmoi, plus a `dot ai delegate` / `dot ai cost` shim that lets
non-Claude-Code users access the same delegator.

## Why

Claude (Sonnet 4.6) costs $3/M input, $15/M output. Cheap delegates:

- Mistral Medium 3.5: $1.50/$7.50 per M tokens (or $0 within Le Chat Pro sub)
- DeepSeek V4 Flash: $0.14/$0.28 per M tokens

For coding tasks that do many file reads, the delegator pattern saves
massively because Claude sees a single tool call + final diff instead
of every intermediate read/edit.

## How to use

### From Claude Code (preferred)

```
/vibe rename every UserService method that starts with "get" to "fetch"
```

Claude writes the prompt → invokes `tools/vibe-delegate` → reads the
streaming JSON output → reviews the resulting `git diff`. You see one
compact report instead of 30 file reads.

Toggle auto-delegate mode with `/vibeon` / `/vibeoff`. While ON,
every coding task is sent through Vibe by default.

### From the terminal (no Claude Code)

```sh
dot ai delegate "rename every UserService method that starts with get to fetch"
dot ai cost --since 7   # spend report
```

The CLI shim wraps the same delegator. Cost log lives at
`~/.local/share/delegate-runs.jsonl`.

## Model selection

Default: whatever your `~/.vibe/config.toml` lists as `default_model`.

Override per session:

```
/vibe-model-pick deepseek-v4-flash
```

The override writes a flag at `~/.local/share/vibe-model.flag` consumed
by `tools/vibe-delegate`. Clear with `/vibe-model-clear`.

## Reports

```
/vibe-report                # all-time overview
/vibe-report --since 7      # last 7 days
/vibe-report --project foo  # one project
/vibe-report --fails        # only failures + breakdown by failure type
```

Reports show: total runs, success rate, tokens delegated, delegate cost,
Claude-equivalent cost (the would-have-been spend), savings ratio, and
failure breakdown (timeouts, exit_err, syntax errors, search/replace
fails, empty runs).
