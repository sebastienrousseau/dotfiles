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

Running `dot ai` on a terminal opens a full-window TUI (built with [Bubble Tea](https://github.com/charmbracelet/bubbletea)) that puts the whole fleet on one screen:

- **Header** — gateway status (`● serving :3456` / `○ off`) and today's cost.
- **Left** — the fleet grouped by role, with `●`/`○` install markers.
- **Right** — the selected tool's status, how it routes, and recent runs.

```text
↑↓ move   ⏎ chat   i install   s serve(+route)   c refresh   q quit
```

The cockpit shells out to the `dot ai` verbs below, so its actions and the command line behave identically. In non-interactive contexts (CI, pipes) `dot ai` falls back to a plain text fleet listing. The cockpit binary (`dot-ai-tui`) is built on `chezmoi apply` via the mise-managed Go toolchain.

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

**Config:** `DOT_AI_HOST` (default `127.0.0.1`), `DOT_AI_PORT` (default `3456`), `DOT_AI_DEFAULT_MODEL` (default `sonnet`), `DOT_AI_API_KEY` (optional shared secret).

**Security:** the server binds to loopback by default. If you set `DOT_AI_HOST` to a LAN address, `dot ai serve` refuses to launch unless `DOT_AI_API_KEY` is set — an unprotected network proxy leaks your subscription.

**Scope (v1):** chat/completions for both protocols, streaming and non-streaming, `/v1/models`, `/health`. Out of scope for now: tool-call passthrough for coding agents, token-by-token streaming (responses stream as one block), multimodal input, and session resumption.

## The fleet

These tools are not installed for you. Install what you want with `dot ai install <tool>` (or `dot ai install all`):

- **Agents**: `claude`, `codex`, `copilot`, `goose`
- **Coding assistants**: `aider`, `opencode`, `autohand`, `vibe`, `qwen`, `zai`
- **General**: `agy`, `sgpt`
- **Local-first**: `ollama`
- **Cloud / platform**: `kiro-cli`

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
