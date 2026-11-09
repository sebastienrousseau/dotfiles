---
render_with_liquid: false
---

# AI Integrations (Opt-in)

The `dot ai` commands work without any setup. `DOTFILES_AI=1` turns on two extras:

```bash
export DOTFILES_AI=1
exec zsh
```

In zsh it sources the opt-in AI shell helpers (context suggestions and error analysis), and during `chezmoi apply` it lets the cockpit binary (`dot-ai-tui`) be built. zsh and bash leave it off by default; the Fish, Nushell and PowerShell configs export `DOTFILES_AI=1`. It does **not** install any AI tools or run any background service.

## Why `dot ai`?

`claude` is one tool. **`dot ai` is the cockpit for every AI CLI you use.** Use it to install the tools, launch any of them with one keystroke, meter their cost in one place, and — the headline — run every one of them on your single Claude subscription through a built-in local gateway.

You use `claude` to talk to Claude. You use `dot ai` to run *everything else* on Claude and keep one cockpit over all of it.

## Quick start

```bash
dot ai install all        # install the roster (only what's missing)
dot ai                    # open the cockpit (TUI)
dot ai "fix the auth bug" # one-shot on Claude — just like `claude "…"`
dot ai gateway serve      # serve your Claude subscription locally to every tool
```

## Prerequisites

Most tools install through [mise](https://mise.jdx.dev); `claude`, `goose`,
`agy`, `amp`, `cursor-agent`, `grok` and `kimi` use their own pinned native
installers, which need `curl`. When a tool you install needs mise and it is
missing, `dot ai` offers to install it first. Nothing installs without your
yes: `dot ai install` asks before a bulk install, `dot ai <tool>` asks before
installing a missing tool, and `--yes` (or `DOTFILES_YES=1`) answers yes.
With no terminal to ask, nothing installs. `dot ai check` lists what is
missing (mise, node, uv, curl, go) and how to add it.

## Command surface

The interface follows ADR-020 (`dot ai <verb>`), modelled on the Claude CLI: bare opens an interactive view and a prompt runs it. The older verbs in brackets still work.

| Command | What it does |
|---------|--------------|
| `dot ai` | Open the **cockpit** — a Bubble Tea TUI for the roster, gateway, and cost |
| `dot ai "<prompt>"` | One-shot prompt on Claude |
| `dot ai <tool> "<prompt>"` | One-shot prompt on a named tool (e.g. `dot ai codex "add tests"`) |
| `dot ai start [tool]` | Open an interactive session (picker if no tool) (`dot ai chat`) |
| `dot ai list` | Install status of the roster, with an install picker (`dot ai tools`) |
| `dot ai install [all\|<tool>] [--yes]` | Install all missing tools, or one, with what they need (asks first) |
| `dot ai gateway serve [stop\|status]` | Start the local Claude gateway **and** route the other tools through it (`dot ai serve`) |
| `dot ai gateway show [--json]` | The running gateway's requests, tokens, tool calls and cost |
| `dot ai cost show` | Spend report across providers (`dot ai cost`) |
| `dot ai policy show [--agent A] [--mode M]` | The [enforced policy](#enforced-policy)'s rules in force for an agent (`dot ai policy`) |
| `dot ai policy check` | Validate the policy and name the active mode |
| `dot ai login [tool]` | Authenticate a tool |
| `dot ai check` | Health-check the roster and the gateway (`dot ai doctor`) |
| `dot ai status [--json]` | Each agent session of the last 24 h and its state, from the hooks' state files; the cockpit header and the tmux status bar show the same count (`3 agents · 1 blocked`) |
| `dot ai watch` | Follow agents' states live; a desktop notification when one is blocked |
| `dot ai start --bg <tool> [task]` | Start an agent in a terminal of its own (herdr-core, else tmux), optionally with a task |
| `dot ai send <name> <text>` / `dot ai wait [<name>]` | Give a background agent more work; wait until it stops working |
| `dot ai watch service on\|off\|status` | Keep `dot ai watch` running from login (launchd agent or systemd user service), opt-in |
| `--style <name>` | Steer any prompt with a pattern (see [Steering styles](#steering-styles)) |

## The cockpit (`dot ai`)

Running `dot ai` on a terminal opens a glamorous, chat-centric TUI (built with [Bubble Tea](https://github.com/charmbracelet/bubbletea), Charm/Crush-style):

- **Header** — the `◆ dot ai` wordmark plus gateway status (`● :3456` / `○ off`) and today's cost as colour chips.
- **Left** — the roster grouped by role, with `●`/`○` install markers and a `▌` selection accent.
- **Right** — a **chat panel**: pick a tool, type a prompt in the input box, press `Enter`, and the response streams back in the transcript — all without leaving the TUI.

```text
Tab focus   ↑↓ move   ⏎ send   s serve   i install   c refresh   q quit
```

Two modes per tool: **Enter on the roster** opens the tool's *full native session* (where its own `/exit`, `/model`, `/clear`, … work); **Tab / `/`** drops into the quick in-cockpit streaming chat. In the chat input, typing `/` opens a **tool-aware command palette** — the cockpit commands (`/help /clear /style /tool /serve /cost /exit`, which run in-chat) plus the selected provider's common REPL commands (`/compact /model /resume /agents` for claude; `/add /diff /commit` for aider; `/approvals /status` for codex; …), tagged `→ <tool> session`. Navigate with `↑↓`, `Tab` to complete, `Enter` to run. Prompts run through `dot ai <tool>`, so the cockpit and the command line behave identically.

The cockpit also offers a **model picker** (`/model <name>` or the `m` key cycles `default → opus → sonnet → haiku`; the active model shows in the header and is applied to the Claude engine via `ANTHROPIC_MODEL`), **session persistence** (each completed turn is saved to `$XDG_STATE_HOME/dot-ai-tui/session.json`; `/resume` restores your last conversation, `/save` snapshots the current one), and **desktop notifications** when a reply takes longer than ~8s (macOS `osascript` / Linux `notify-send`). In non-interactive contexts (CI, pipes) `dot ai` falls back to a plain text roster listing. The cockpit binary (`dot-ai-tui`) is built on `chezmoi apply` via the mise-managed Go toolchain; `DOT_AI_SNAPSHOT=1 dot-ai-tui` prints a single frame for previews.

## Steering styles

Styles in `~/.config/ai/patterns/` (source: `defaults/dot_config/ai/patterns/`) add focused context to any prompt with `--style <name>`:

- **architect** — shell setup and stack tuning
- **hardener** — security, encryption, and compliance
- **refactor** — POSIX compatibility, performance, and linting

```bash
dot ai run claude --style architect "optimize my zshrc"
dot ai run agy --style hardener "audit my ssh config"
```

The bridge also injects system details (OS, architecture, date) so the model has the context it needs. Quick aliases ship for the common combinations: `dcla` (Claude + architect), `dagyh` (Antigravity + hardener), `dkir` (Kiro + refactor).

The same patterns are herdr-core templates. chezmoi deploys the shipped ones to `~/.config/herdr-core/templates/<name>.md`, so `hc run architect "<task>"` starts Claude Code with that role on every host. `dot ai pattern export --hc` writes them, and any pattern you added, again; `--agent codex` runs them with another agent (one without dot's hooks gets `ready: quiet`).

## Running tools

```bash
dot ai "explain this stack trace"            # one-shot on Claude
dot ai run codex "add a test for parse()"    # one-shot on a specific tool
dot ai start                           # pick a tool and open its session
dot ai start aider                     # open aider directly
```

## The local Claude gateway (`dot ai gateway serve`)

Run one Claude subscription locally and point every tool at it — with **no third-party dependency**. `dot-ai-serve` is a small, stdlib-only Python server (no pip packages) that wraps the `claude` CLI you already have and exposes the standard Anthropic (`/v1/messages`) **and** OpenAI (`/v1/chat/completions`) endpoints. Any tool that speaks either protocol — codex, aider, Open WebUI, an OpenAI SDK — connects to `http://127.0.0.1:3456` and gets Claude on your existing subscription.

```bash
claude login              # one-time: authenticate the engine
dot ai gateway serve          # start the gateway AND route the non-Claude tools
dot ai gateway serve status   # process + /health + routing state
dot ai gateway serve stop     # stop the gateway and un-route
```

**Native session, never a key.** The gateway authenticates through your `claude` CLI's native session — there is no API key anywhere. Routing is applied **per-invocation** to non-Claude tools (`dot ai codex "…"`); it is **not** sourced into your interactive shell. The primary `claude` is never routed — it always uses its own native session, so claude.ai connectors stay enabled. (Setting `ANTHROPIC_API_KEY` in your shell would disable those connectors, which is exactly why routing stays scoped to each tool's subprocess.)

**Streaming, routing & metering.** Replies stream **token-by-token** (real SSE for both protocols). Model **aliases/routing** map friendly names to a Claude tier — `cheap`/`fast` → haiku, `smart` → opus, and common OpenAI ids (`gpt-4` → sonnet, `gpt-3.5-turbo` → haiku); extend with `DOT_AI_MODEL_MAP`. Every request is **metered**: `GET /metrics` (Prometheus text) and `GET /v1/usage` (JSON) report requests, tokens, and estimated cost per model. An optional `DOT_AI_DAILY_BUDGET` (USD) caps daily spend — once reached, requests get `429`.

**Config:** `DOT_AI_HOST` (default `127.0.0.1`), `DOT_AI_PORT` (default `3456`), `DOT_AI_DEFAULT_MODEL` (default `sonnet`), `DOT_AI_API_KEY` (shared secret; defaults to a generated token), `DOT_AI_ALLOWED_HOSTS` (extra accepted `Host` values), `DOT_AI_DAILY_BUDGET` (USD, `0` = off), `DOT_AI_MODEL_MAP` / `DOT_AI_PRICING` (JSON overrides).

**Security:** the server binds to loopback by default. If you set `DOT_AI_HOST` to a LAN address, both the launcher *and* the server itself refuse to start unless `DOT_AI_API_KEY` is set — an unprotected network proxy leaks your subscription. Every request needs a key: without `DOT_AI_API_KEY` the server and `dot ai proxy local on` share a random 0600 token at `$XDG_STATE_HOME/dot/ai/serve/gateway.token` (`dot-ai-serve --token-path` prints its location). Requests whose `Host` header is not the server's own address are refused (DNS-rebinding guard), and the `claude` engine runs with all tools disabled in an empty temporary directory.

**Images and tool calls.** Both endpoints take images, base64 or by URL (the API fetches a URL itself), in PNG, JPEG, GIF or WebP. A request's tools reach the model, and its calls come back in each protocol's own form: `tool_use` blocks with `stop_reason: "tool_use"`, or `tool_calls` with `finish_reason: "tool_calls"`, whole or streamed. The client runs them and sends the results in its next request, as it would to the API. Inside the gateway nothing runs them: the engine lists them through a stub MCP server and is allowed none, and the gateway stops it at the end of the model's turn. Only client-defined tools are supported; a server tool such as `web_search` is a `400`. Earlier turns, tool calls and results included, reach the engine as a transcript, and session resumption is out of scope.

**Statistics.** `dot ai gateway show` summarises the running gateway: requests, errors, tokens, images, tool calls and estimated cost, in all and per model, against the daily budget. `--json` prints the report as `ai/gateway-usage.v1` ([schema](../schemas/cli/ai-gateway-usage.v1.schema.json)).

**Policy.** With an [enforced policy](#enforced-policy), its `[gateway]` table limits each request before the engine sees it: `models` allows only the models it lists (globs over what the request resolves to, such as `haiku` or `claude-sonnet-*`), and `max_input_tokens` caps the gateway's estimate of its input (four characters a token, 1,600 an image). A refused request gets a `403` with the reason. As for the hooks, a policy that does not load, or a missing `dot-policy`, refuses every request.

**Anthropic's terms.** A Claude subscription signs in for "ordinary use of Claude Code and other native Anthropic applications", and Anthropic says its plan limits assume ordinary, individual use and that it may enforce this without notice ([legal and compliance](https://code.claude.com/docs/en/legal-and-compliance)). The gateway runs the unmodified `claude` CLI on your own machine and login. Pointing other tools' agent loops at it is your call, and the risk to your account is yours; with `claude` signed in with an API key, use is billed to that key instead.

## The roster

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
  - `kimi` — Moonshot AI's Kimi Code CLI; installed natively to `~/.kimi-code/bin/kimi` and supports native interactive use and one-shot prompts

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

`dot ai list` shows install status grouped by role and offers an interactive install picker. Status is cached in `~/.cache/dotfiles/ai/status.tsv` for 5 minutes (tune with `DOTFILES_AI_STATUS_TTL`).

## Run cost and telemetry

Every run through the bridge is logged to a local SQLite database (`~/.local/share/dotfiles-ai.db`). `dot ai cost show` reports spend across providers, and the cockpit's cost panel and recent-runs list read from the same log. Token-level cost is populated for providers that surface it (and for everything routed through `dot ai gateway serve`).

## Old command names

The top-level provider shortcuts were removed in 0.2.538: each now exits 127 and prints its new name.

| Removed | Use instead |
|---------|-------------|
| `dot cl` / `dot claude` | `dot ai run claude` |
| `dot codex`, `dot copilot`, `dot kimi`, `dot agy`, `dot goose`, `dot kiro`, `dot sgpt`, `dot ollama`, `dot opencode`, `dot aider`, `dot autohand`, `dot vibe`, `dot qwen`, `dot zai` | `dot ai run codex`, `dot ai run copilot`, `dot ai run kimi`, `dot ai run agy`, `dot ai run goose`, `dot ai run kiro`, `dot ai run sgpt`, `dot ai run ollama`, `dot ai run opencode`, `dot ai run aider`, `dot ai run autohand`, `dot ai run vibe`, `dot ai run qwen`, `dot ai run zai` |
| `dot ai-setup` | `dot ai install --interactive` |
| `dot ai-query` | `dot ai ask` |
| `dot patterns` | `dot ai pattern` |

These verbs inside `dot ai` still work but print a one-line hint with the new name. The shortcut aliases (`dagy`, `dkm`, `dcla`, `dkia`, …) run `dot ai <tool>`; `dcl` and `dki` are the Docker aliases (`docker compose logs`, `docker info`).

| Deprecated | Use instead |
|------------|-------------|
| `dot ai dashboard` / `dot ai dash` | `dot ai` (the cockpit) |
| `dot ai proxy …` / `dot ai local on\|off` | `dot ai gateway serve` |
| `--pattern <name>` | `--style <name>` |

## Agentic terminal workflows

If your terminal has built-in AI agents, keep your shell lean and fast:

- Use `DOTFILES_FAST=1` or `DOTFILES_ULTRA_FAST=1`.
- Let the terminal handle agents and its own UI.
- Keep dotfiles focused on consistency, safety, and clean repeats.

## Enforced policy

`~/.config/dotfiles/ai-policy.toml` says what each agent may do in each mode, and the agents' own pre-tool hooks enforce it ([ADR-025](adr/ADR-025-enforced-ai-policy.md)). Without the file nothing is enforced.

```toml
schema = "ai-policy.v1"
default_mode = "ask"          # when dot agent mode has none set

[mode.ask]
tools = ["read", "search"]    # classes: shell read write search fetch mcp, or tool names

[mode.apply]
tools = ["*"]
tools_deny = ["mcp__github__*"]
paths_allow = ["{cwd}/**", "/tmp/**"]
paths_deny = ["~/.ssh/**", "~/.aws/**", "**/.env"]
hosts_allow = ["github.com", "*.github.com"]
commands_deny = ["rm -rf *", "git push --force*", "sudo *", "curl * | sh"]

[agent.codex.mode.apply]      # replaces only the lists it sets
tools = ["read", "search", "shell", "write"]

[gateway]                     # what dot ai gateway serve lets a request use
models = ["haiku", "sonnet", "claude-sonnet-*"]
max_input_tokens = 100000
```

The active mode is the one `dot agent mode set` chose. `dot cli hook install` wires `dot cli hook check` into Claude Code (`PreToolUse`), Gemini CLI (`BeforeTool`) and Codex (`~/.codex/hooks.json`; trust it once in Codex's `/hooks`). A denied call reaches the agent with the reason, such as `dot ai policy (mode ask): tool Write (write) is not allowed`. `dot ai policy show` prints the rules in force for an agent (`--agent codex`) in the active mode, or another (`--mode apply`), and `dot ai policy check` validates the file and names the active mode.

It fails closed: a file with an error or an unknown key, a mode it has no rules for, or a missing `dot-policy` binary (chezmoi builds it when Go is installed) denies every tool call until fixed. It is a guardrail, not a sandbox: commands are split at `;`, `&&`, `|` and `$(`, but a script the agent writes and runs is not looked into.

## Privacy and safety

- No AI tools are installed for you.
- No background services run by default; the gateway runs only while you keep `dot ai gateway serve` up.
- You control AI helpers with `DOTFILES_AI=1`.
- The gateway uses your native Claude session — no API keys are stored or required.
