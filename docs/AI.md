---
render_with_liquid: false
---

# AI Integrations (Opt-in)

AI helpers are **off by default**. You choose if and when to turn them on.

```bash
export DOTFILES_AI=1
exec zsh
```

This enables the local helper scripts and the `dot ai` command surface. It does **not** install any AI tools or run any background service.

## Why `dot ai`?

`claude` is one tool. **`dot ai` is the cockpit for your whole AI-CLI fleet.** Use it to install the tools, launch any of them with one keystroke, meter their cost in one place, and — the headline — run every one of them on your single Claude subscription through a built-in local gateway.

You use `claude` to talk to Claude. You use `dot ai` to run *everything else* on Claude and keep one cockpit over all of it.

## Quick start

```bash
dot ai install all        # install the fleet (only what's missing)
dot ai                    # open the cockpit (TUI)
dot ai "fix the auth bug" # one-shot on Claude — just like `claude "…"`
dot ai serve              # serve your Claude subscription locally to the fleet
```

## Command surface

The interface is flat and verb-first, modelled on the Claude CLI: bare opens an interactive view, a prompt runs it, and old commands keep working as deprecated aliases.

| Command | What it does |
|---------|--------------|
| `dot ai` | Open the **cockpit** — a Bubble Tea TUI for the fleet, gateway, and cost |
| `dot ai "<prompt>"` | One-shot prompt on Claude |
| `dot ai <tool> "<prompt>"` | One-shot prompt on a named tool (e.g. `dot ai codex "add tests"`) |
| `dot ai chat [tool]` | Open an interactive session (picker if no tool) |
| `dot ai tools` | Install / manage the fleet |
| `dot ai install [all\|<tool>]` | Install all missing tools, or one |
| `dot ai serve [stop\|status]` | Start the local Claude gateway **and** route the fleet through it |
| `dot ai cost` | Spend report across providers |
| `dot ai login [tool]` | Authenticate a tool |
| `dot ai doctor` | Health-check the fleet and the gateway |
| `--style <name>` | Steer any prompt with a pattern (see [Steering styles](#steering-styles)) |

## The cockpit (`dot ai`)

Running `dot ai` on a terminal opens a glamorous, chat-centric TUI (built with [Bubble Tea](https://github.com/charmbracelet/bubbletea), Charm/Crush-style):

- **Header** — the `◆ dot ai` wordmark plus gateway status (`● :3456` / `○ off`) and today's cost as colour chips.
- **Left** — the fleet grouped by role, with `●`/`○` install markers and a `▌` selection accent.
- **Right** — a **chat panel**: pick a tool, type a prompt in the input box, press `Enter`, and the response streams back in the transcript — all without leaving the TUI.

```text
Tab focus   ↑↓ move   ⏎ send   s serve   i install   c refresh   q quit
```

Two modes per tool: **Enter on the fleet** opens the tool's *full native session* (where its own `/exit`, `/model`, `/clear`, … work); **Tab / `/`** drops into the quick in-cockpit streaming chat. In the chat input, typing `/` opens a **tool-aware command palette** — the cockpit commands (`/help /clear /style /tool /serve /cost /exit`, which run in-chat) plus the selected provider's common REPL commands (`/compact /model /resume /agents` for claude; `/add /diff /commit` for aider; `/approvals /status` for codex; …), tagged `→ <tool> session`. Navigate with `↑↓`, `Tab` to complete, `Enter` to run. Prompts run through `dot ai <tool>`, so the cockpit and the command line behave identically.

The cockpit also offers a **model picker** (`/model <name>` or the `m` key cycles `default → opus → sonnet → haiku`; the active model shows in the header and is applied to the Claude engine via `ANTHROPIC_MODEL`), **session persistence** (each completed turn is saved to `$XDG_STATE_HOME/dot-ai-tui/session.json`; `/resume` restores your last conversation, `/save` snapshots the current one), and **desktop notifications** when a reply takes longer than ~8s (macOS `osascript` / Linux `notify-send`). In non-interactive contexts (CI, pipes) `dot ai` falls back to a plain text fleet listing. The cockpit binary (`dot-ai-tui`) is built on `chezmoi apply` via the mise-managed Go toolchain; `DOT_AI_SNAPSHOT=1 dot-ai-tui` prints a single frame for previews.

## Steering styles

Styles in `~/.dotfiles/dot_config/ai/patterns/` add focused context to any prompt with `--style <name>`:

- **architect** — shell setup and stack tuning
- **hardener** — security, encryption, and compliance
- **refactor** — POSIX compatibility, performance, and linting

```bash
dot ai claude --style architect "optimize my zshrc"
dot ai agy --style hardener "audit my ssh config"
```

The bridge also injects system details (OS, architecture, date) so the model has the context it needs. Quick aliases ship for the common combinations: `dcla` (Claude + architect), `dagyh` (Antigravity + hardener), `dkir` (Kiro + refactor).

## Running tools

```bash
dot ai "explain this stack trace"     # one-shot on Claude
dot ai codex "add a test for parse()" # one-shot on a specific tool
dot ai chat                            # pick a tool and open its session
dot ai chat aider                      # open aider directly
```

## The local Claude gateway (`dot ai serve`)

Run one Claude subscription locally and point your whole fleet at it — with **no third-party dependency**. `dot-ai-serve` is a small, stdlib-only Python server (no pip packages) that wraps the `claude` CLI you already have and exposes the standard Anthropic (`/v1/messages`) **and** OpenAI (`/v1/chat/completions`) endpoints. Any tool that speaks either protocol — codex, aider, Open WebUI, an OpenAI SDK — connects to `http://127.0.0.1:3456` and gets Claude on your existing subscription.

```bash
claude login              # one-time: authenticate the engine
dot ai serve              # start the gateway AND route the non-Claude fleet
dot ai serve status       # process + /health + routing state
dot ai serve stop         # stop the gateway and un-route
```

**Native session, never a key.** The gateway authenticates through your `claude` CLI's native session — there is no API key anywhere. Routing is applied **per-invocation** to non-Claude tools (`dot ai codex "…"`); it is **not** sourced into your interactive shell. The primary `claude` is never routed — it always uses its own native session, so claude.ai connectors stay enabled. (Setting `ANTHROPIC_API_KEY` in your shell would disable those connectors, which is exactly why routing stays scoped to each tool's subprocess.)

**Streaming, routing & metering.** Replies stream **token-by-token** (real SSE for both protocols). Model **aliases/routing** map friendly names to a Claude tier — `cheap`/`fast` → haiku, `smart` → opus, and common OpenAI ids (`gpt-4` → sonnet, `gpt-3.5-turbo` → haiku); extend with `DOT_AI_MODEL_MAP`. Every request is **metered**: `GET /metrics` (Prometheus text) and `GET /v1/usage` (JSON) report requests, tokens, and estimated cost per model. An optional `DOT_AI_DAILY_BUDGET` (USD) caps daily spend — once reached, requests get `429`.

**Config:** `DOT_AI_HOST` (default `127.0.0.1`), `DOT_AI_PORT` (default `3456`), `DOT_AI_DEFAULT_MODEL` (default `sonnet`), `DOT_AI_API_KEY` (optional shared secret), `DOT_AI_DAILY_BUDGET` (USD, `0` = off), `DOT_AI_MODEL_MAP` / `DOT_AI_PRICING` (JSON overrides).

**Security:** the server binds to loopback by default. If you set `DOT_AI_HOST` to a LAN address, both the launcher *and* the server itself refuse to start unless `DOT_AI_API_KEY` is set — an unprotected network proxy leaks your subscription.

**Engine limits.** The gateway wraps the `claude` CLI (an agent), not the raw API, so two things are handled gracefully rather than forwarded: **image** blocks are acknowledged inline but not sent (the engine is text-only), and **function/tool-calling** requests are answered in plain text (the CLI can't return caller-defined `tool_use` blocks). Session resumption is still out of scope.

## The fleet

These tools are not installed for you. Install what you want with `dot ai install <tool>` (or `dot ai install all`):

- **Agents (autonomous)** — full coding agents that plan and execute:
  - `claude` — Anthropic's flagship agentic coder (Claude Code)
  - `codex` — OpenAI's autonomous coding agent
  - `copilot` — GitHub Copilot in the terminal
  - `goose` — Block's open-source coding agent
  - `crush` — Charm's glamorous TUI coding agent
  - `amp` — Sourcegraph's agentic coder
  - `cursor-agent` — Cursor's terminal agent
  - `grok` — xAI's terminal coding agent (Grok Build; needs a SuperGrok / X Premium+ plan)
- **Coding (interactive)** — focused pair-programming assistants:
  - `aider` — Git-aware AI pair programmer
  - `opencode` — open-source terminal coding agent
  - `autohand` — autonomous multi-file coding agent
  - `vibe` — Mistral's coding agent
  - `qwen` — Alibaba Qwen coding assistant
  - `zai` — Zhipu GLM coding agent
- **General (prompt-based)** — quick prompt/shell helpers:
  - `agy` — Google's Antigravity agent
  - `sgpt` — ChatGPT for the shell (Shell-GPT)
- **Runtime (local)**:
  - `ollama` — run local **and** cloud-hosted open models (`ollama signin` for cloud)
- **Cloud (platform)**:
  - `kiro-cli` — AWS's agentic dev assistant

`dot ai tools` shows install status grouped by role and offers an interactive install picker. Status is cached in `~/.cache/dotfiles/ai/status.tsv` for 5 minutes (tune with `DOTFILES_AI_STATUS_TTL`).

## Run cost and telemetry

Every run through the bridge is logged to a local SQLite database (`~/.local/share/dotfiles-ai.db`). `dot ai cost` reports spend across providers, and the cockpit's cost panel and recent-runs list read from the same log. Token-level cost is populated for providers that surface it (and for everything routed through `dot ai serve`).

## Deprecated commands

The old command shapes still work, but print a one-line hint pointing at the new name. Update your muscle memory when convenient — the shortcut aliases (`dcl`, `dagy`, `dki`, …) already target the new surface.

| Deprecated | Use instead |
|------------|-------------|
| `dot cl` | `dot ai claude` |
| `dot codex` / `dot copilot` / `dot agy` / `dot goose` | `dot ai codex` / `dot ai copilot` / `dot ai agy` / `dot ai goose` |
| `dot kiro` / `dot sgpt` / `dot ollama` / `dot opencode` | `dot ai kiro` / `dot ai sgpt` / `dot ai ollama` / `dot ai opencode` |
| `dot aider` / `dot autohand` / `dot vibe` / `dot qwen` / `dot zai` | `dot ai aider` / `dot ai autohand` / `dot ai vibe` / `dot ai qwen` / `dot ai zai` |
| `dot ai status` | `dot ai tools` |
| `dot ai dashboard` / `dot ai dash` | `dot ai` (the cockpit) |
| `dot ai proxy …` / `dot ai local on\|off` | `dot ai serve` |
| `dot ai-setup` | `dot ai login` |
| `dot ai-query` | `dot ai ask` |
| `--pattern <name>` | `--style <name>` |

## Agentic terminal workflows

If your terminal has built-in AI agents, keep your shell lean and fast:

- Use `DOTFILES_FAST=1` or `DOTFILES_ULTRA_FAST=1`.
- Let the terminal handle agents and its own UI.
- Keep dotfiles focused on consistency, safety, and clean repeats.

## Privacy and safety

- No AI tools are installed for you.
- No background services run by default; the gateway runs only while you keep `dot ai serve` up.
- You control AI helpers with `DOTFILES_AI=1`.
- The gateway uses your native Claude session — no API keys are stored or required.
