---
title: "AI Cost Optimization"
date: 2026-05-24
---

# AI Cost Optimization

This dotfiles framework ships an opinionated AI-cost layer designed to
keep token spend predictable and low while still using the smartest
model for orchestration. Two ideas drive it:

1. **Delegate the grunt work.** Have the expensive smart model
   orchestrate, and a cheap fast model do the file reads, edits, and
   verification. The smart model sees one tool call and the final
   `git diff` instead of every intermediate read.
2. **Account every call.** Every invocation through `dot ai <provider>`
   appends a JSONL entry so you can see spend across all providers in
   one report, not just per-tool dashboards.

## Quick reference

```sh
dot ai delegate "rename every UserService method that starts with get to fetch"
dot ai cost                # all-time overview
dot ai cost --since 7      # last 7 days
dot ai cost --fails        # only failures + breakdown by failure type
```

Inside Claude Code: `/vibe`, `/vibe-report`, `/vibeon`, `/vibeoff`,
`/vibestatus`, `/vibe-model-pick`, `/vibe-model-clear`.

## The delegator pattern

The pattern comes from [pcx-wave/vibe-skill][vibe-skill]. Mistral Vibe
is the default delegate but the same wrapper accepts any model Vibe
knows about (DeepSeek V4 Flash, Gemini Flash, etc.).

[vibe-skill]: https://github.com/pcx-wave/vibe-skill

Cost comparison (May 2026 list prices, blended 85 in / 15 out typical
of coding tasks):

| Task | Claude Sonnet 4.6 ($3 / $15) | Mistral Medium 3.5 ($1.50 / $7.50) | DeepSeek V4 Flash ($0.14 / $0.28) |
|---|---|---|---|
| 1-file tweak (800 tok) | ~$0.004 | ~$0.002 | ~$0.0001 |
| 6-read task (4,800 tok) | ~$0.023 | ~$0.012 | ~$0.0008 |
| Multi-file refactor (12,000 tok) | ~$0.058 | ~$0.029 | ~$0.002 |

Real-world stats from 254 vibe-skill runs over 10 days (May 2026):

| | Amount |
|---|---|
| Actually paid (Mistral Pro prorated + DeepSeek pay-as-you-go) | **$10.35** |
| Same workload pay-as-you-go via Mistral API | $46.61 |
| Same workload on Claude Sonnet 4.6 | $179.91 |
| Saved vs Claude | **$169.56 (17.4× cheaper)** |

Claude itself contributes ~500-1500 tokens per delegation as
orchestration overhead. Even with that overhead the savings dominate
for anything beyond a one-line edit.

## Pieces deployed by this repo

| Component | Source path | Deployed to | Role |
|---|---|---|---|
| `vibe` skill | `defaults/dot_claude/skills/vibe/` | `~/.claude/skills/vibe/` | Claude Code slash commands (`/vibe`, `/vibe-report`, etc.) |
| Delegator binary | `defaults/dot_claude/skills/vibe/tools/executable_vibe-delegate` | `~/.claude/skills/vibe/tools/vibe-delegate` | Runs the cheap-model task in a pseudo-TTY, parses streaming JSON, syntax-checks changes, logs the run |
| Reporter | `defaults/dot_claude/skills/vibe/tools/executable_delegate-report` | `~/.claude/skills/vibe/tools/delegate-report` | Reads the JSONL log, prints overview / by-model / by-project / failure tables |
| CLI shim | `scripts/dot/commands/ai.sh` | `bin/dot ai delegate` / `bin/dot ai cost` | Same delegator + reporter, callable from the terminal without Claude Code |
| Unified log hook | `_ai_log_run` in `ai.sh` | runs inside `run_ai_with_context` | Appends one JSONL line per `dot ai <provider>` invocation |
| Log file | runtime-managed | `~/.local/share/delegate-runs.jsonl` | One line per run; `dot ai cost` reads it |

## State files

| File | Owner | Purpose |
|---|---|---|
| `~/.local/share/delegate-runs.jsonl` | runtime | One JSONL entry per AI invocation (vibe + every other provider) |
| `~/.local/share/vibe-auto.flag` | `/vibeon` / `/vibeoff` | When present, Claude auto-delegates coding tasks to Vibe |
| `~/.local/share/vibe-model.flag` | `/vibe-model-pick` | Override the Vibe model for the next runs; cleared by `/vibe-model-clear` |
| `~/.vibe/config.toml` | user | Vibe's own provider / model configuration |

## Reading the report

```
DELEGATE REPORT  2026-05-17 → 2026-05-24
  Runs          : 27  (ok: 25, failed: 2, timeout: 0)
  Success rate  :  92%
  Avg duration  : 18.4s
  Tokens total  : 4,231,082
  Delegate cost : $1.4711
  Claude equiv  : $14.8294
  Saved         : $13.3583  (90% cheaper than Claude)
```

`Claude equiv` is what the same workload would have cost on Claude
Sonnet 4.6 ($3 / $15 per M tokens, blended at the same in/out ratio).
The savings line is the difference. Failure types are broken out per
model so you can see which delegate is most reliable for your repo.

## Provider coverage

Every provider exposed via `dot ai <provider>` is logged best-effort.
For providers that don't surface token counts in their CLI output, the
report still tracks: timestamp, project, exit code, duration, prompt
word count. Token / cost fields stay zero for those providers — the
report tolerates the gap and aggregates by `model` regardless.

Providers tracked today:

| Provider | Binary | Logged | Tokens surfaced? |
|---|---|---|---|
| Claude Code | `claude` | yes | no (CLI doesn't expose) |
| Codex | `codex` | yes | no |
| Copilot CLI | `copilot` | yes | no |
| Gemini CLI | `gemini` | yes | no |
| Goose | `goose` | yes | no |
| Kimi CLI | `kimi` | yes | no |
| Aider | `aider` | yes | no |
| OpenCode | `opencode` | yes | no |
| Autohand | `autohand` | yes | no |
| Mistral Vibe | `vibe` | yes | **yes** (via delegator) |
| Qwen | `qwen` | yes | no |
| ZAI | `zai` | yes | no |
| Shell-GPT | `sgpt` | yes | no |
| Ollama (local) | `ollama` | yes | n/a (no cost) |
| Kiro CLI | `kiro-cli` | yes | no |

## Future work

Not implemented yet, ordered roughly by likely impact:

1. **Provider-level budget guard.** `dot ai budget --set 50/month`
   would warn at 80% and refuse new requests at 100% (overridable).
   Needs per-provider cost estimation hooks beyond what each CLI
   surfaces today.
2. **Prompt response cache.** Many coding-helper queries are
   deterministic ("syntax for X in Y"). A local cache keyed on prompt
   hash + provider could short-circuit repeat queries.
3. **Per-task-class model routing.** `dot ai delegate --class refactor`
   would pick the cheapest model that meets the quality bar for the
   task class. Today the user picks the model.
4. **Rate-limit awareness.** Track API rate limits from response
   headers, queue requests, surface a `dot ai cost --limits` view that
   shows time-to-reset for every provider with an active limit.
