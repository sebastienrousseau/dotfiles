---
render_with_liquid: false
---

# AI Integrations (Opt-in)

AI helpers are **off by default**. You choose if and when to turn them on.

## Enable AI helpers

```bash
export DOTFILES_AI=1
exec zsh
```

This turns on the local helper scripts for context suggestions and error analysis. It does not install any AI tools.

## Steering Patterns

Patterns in `~/.dotfiles/dot_config/ai/patterns/` add focused context to AI requests.

- **Architect** — shell setup and stack tuning
- **Hardener** — security, encryption, and compliance
- **Refactor** — POSIX compatibility, performance, and linting

### Contextual Bridge

Use the `dot` CLI to run AI tools with added context:

```bash
# General usage
dot cl|codex|copilot|agy|goose|kiro|sgpt|ollama|opencode|aider|autohand|vibe|qwen|zai --pattern <name> "prompt"

# Quick aliases
dcla "Optimize my zshrc"      # Claude + Architect
dagyh "Audit my ssh config"   # Antigravity + Hardener
dkir "Refactor this script"   # Kiro + Refactorer
```

The bridge adds system details (OS, architecture, date) to the prompt. This gives the AI the context it needs for accurate answers.

Supported bridge commands:

| Command | Provider |
|---------|----------|
| `dot cl` | Claude Code |
| `dot codex` | OpenAI Codex CLI |
| `dot copilot` | GitHub Copilot CLI |
| `dot agy` | Antigravity CLI |
| `dot goose` | Goose (Block) |
| `dot kiro` | Kiro CLI |
| `dot sgpt` | Shell-GPT |
| `dot ollama` | Ollama |
| `dot opencode` | OpenCode |
| `dot aider` | Aider |
| `dot autohand` | Autohand Code |
| `dot vibe` | Mistral Vibe |
| `dot qwen` | Qwen Code |
| `dot zai` | ZAI (Zhipu AI) |

### `dot ai` status and launcher

`dot ai` shows which AI CLIs are installed, grouped by category. If `gum` is available, it also opens a quick launcher.

Current categories:

- Agents (autonomous)
- Coding (interactive)
- General (prompt-based)
- Runtime (local)
- Cloud (platform)

The launcher is simple and fast. It shows short role labels like `agent`, `coding`, `general`, `local`, and `cloud` so you can pick quickly.

To stay fast, `dot ai` caches provider info in `~/.cache/dotfiles/ai/status.tsv` for 5 minutes. You can change this with `DOTFILES_AI_STATUS_TTL`.

Related AI commands:

- `dot ai` — check status and launch tools
- `dot ai dashboard` / `dot ai dash` — real-time multi-agent TUI dashboard
- `dot ai-setup` — set up AI CLIs step by step
- `dot ai-query` — run context-aware queries on the dotfiles repo

### `dot ai dashboard`

A real-time terminal dashboard for monitoring all running AI agents at once. Opens a Python curses TUI showing:

- **AGENTS** — which providers are running, how long they have been up
- **COST TODAY** — spend by provider, bar chart, running total
- **RECENT RUNS** — last 50 runs from the SQLite log with status, tokens, and duration

```bash
dot ai dashboard          # open dashboard (auto-refreshes every 5s)
dot ai dash               # alias
dot-ai-dash --refresh 10  # set refresh interval
# Keys: q/ESC → quit   r → force refresh
```

Data comes from `~/.local/share/dotfiles-ai.db` (written by `dot ai delegate` and `vibe-delegate`). No runs yet? The dashboard shows empty panels and waits — start an agent and it will appear on the next refresh.

Aliases: `daid`, `daish`.

### Local Claude proxy (`dot ai proxy` / `dot ai local`)

Run one Claude subscription locally and point your whole AI fleet at it — with **no third-party dependency**. `dot-ai-serve` is a small, stdlib-only Python server (no pip packages) that wraps the `claude` CLI you already have and exposes the standard Anthropic (`/v1/messages`) **and** OpenAI (`/v1/chat/completions`) endpoints. Any tool that speaks either protocol — codex, aider, Open WebUI, an OpenAI SDK, Claude Code itself — connects to `http://127.0.0.1:3456` and gets Claude on your existing subscription.

The `claude` CLI owns auth, prompt caching, and rate limits; the server only translates wire formats.

```bash
# One-time: make sure the engine is authenticated
claude login
dot ai proxy setup        # checks the claude CLI is present + ready

# Run it
dot ai proxy start        # launch dot-ai-serve in the background
dot ai proxy status       # process + /health + routing state
dot ai proxy logs -f      # follow the log

# Point the fleet at it (writes ANTHROPIC_BASE_URL / OPENAI_BASE_URL)
dot ai local on           # new shells route automatically; `source` it for the current one
dot ai local off          # stop routing through the proxy
```

`dot ai local on` writes `~/.config/dotfiles/ai-local.env` (and a fish variant), auto-sourced by the shell when `DOTFILES_AI` is set. With routing on, `dot cl "…"` and direct tool invocations (`codex`, `aider`, …) all run on the proxied subscription — no per-provider API keys needed.

**Config:** `DOT_AI_HOST` (default `127.0.0.1`), `DOT_AI_PORT` (default `3456`), `DOT_AI_DEFAULT_MODEL` (default `sonnet`), `DOT_AI_API_KEY` (optional shared secret).

**Security:** the server binds to loopback by default. If you set `DOT_AI_HOST` to a LAN address, `dot ai proxy start` refuses to launch unless `DOT_AI_API_KEY` is set — an unprotected network proxy leaks your subscription.

**Scope (v1):** chat/completions for both protocols, streaming and non-streaming, `/v1/models`, `/health`. Out of scope for now: tool-call passthrough for coding agents, token-by-token streaming (responses stream as one block), multimodal input, and session resumption.

## Optional AI CLI tools

These tools are not installed for you. Pick and install only the ones you want:

- **Agents**: `claude`, `codex`, `copilot`, `goose`
- **Coding assistants**: `aider`, `opencode`
- **General AI**: `agy`, `sgpt`
- **Local-first**: `ollama`
- **Coding agents**: `autohand`, `vibe`, `qwen`, `zai`
- **Cloud / platform**: `kiro-cli`

Once installed, the dotfiles add helper functions and shortcuts. These only load when `DOTFILES_AI=1` is set.

## Agentic terminal workflows

If your terminal has built-in AI agents, keep your shell lean and fast:

- Use `DOTFILES_FAST=1` or `DOTFILES_ULTRA_FAST=1`.
- Let the terminal handle agents and its own UI.
- Keep dotfiles focused on consistency, safety, and clean repeats.

## Privacy and safety

- No AI tools are installed for you.
- No background services run by default.
- You control AI helpers with `DOTFILES_AI=1`.
