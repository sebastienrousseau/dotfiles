---
render_with_liquid: false
---

# ADR-012: AI Fleet — Native Local Claude Proxy and Cockpit

## Status

Accepted

## Date

2026-06-27

## Context

The dotfiles manage a fleet of ~18 AI CLIs (claude, codex, copilot, goose,
crush, amp, cursor-agent, grok, aider, opencode, agy, sgpt, ollama, autohand, vibe,
qwen, zai, kiro-cli). Three problems had accumulated:

1. **Incoherent command surface.** The fleet was driven by three incompatible
   shapes — `dot ai <thing>`, `dot <tool>`, and `dot ai-<thing>` — with opaque
   names (`cl`, `agy`, `dash`) and no stated reason to prefer `dot ai` over
   running a tool directly.
2. **No way to share one subscription.** Each tool needed its own provider/key.
   Running the whole fleet on a single Claude subscription required a gateway,
   but adding a third-party proxy (e.g. Meridian) meant a new runtime dependency
   and 7k+ lines of engine to track.
3. **No unified cockpit.** Status, cost, and launching were scattered.

## Decision

Build the capability **in-tree**, with no third-party runtime dependency, and
present it behind a flat, verb-first surface modelled on the Claude CLI.

- **Command surface.** A single `dot ai` namespace: bare opens a cockpit; a
  bare prompt runs a one-shot on Claude; `<tool> "<prompt>"` targets a tool;
  plus `chat`, `tools`, `install`, `serve`, `cost`, `login`, `doctor`, and a
  `--style` steering flag. Old forms remain as deprecated aliases that print a
  one-line hint. (`scripts/dot/commands/ai.sh`, `lib/dot/ai-commands.sh`.)
- **Local gateway (`dot ai serve`).** `dot-ai-serve` is a stdlib-only Python
  server that wraps the already-installed `claude` CLI in headless
  `stream-json` mode and exposes the Anthropic (`/v1/messages`) and OpenAI
  (`/v1/chat/completions`) protocols. The `claude` CLI owns auth, caching, and
  rate limits — the server only translates wire formats. There is **no API key
  anywhere**; the native Claude session is the credential.
- **Routing safety.** The primary `claude` is **never** routed through the
  gateway (it keeps its native session and claude.ai connectors). Routing is
  applied per-invocation to non-Claude tools only and is never written into the
  interactive shell environment.
- **Cockpit (`dot-ai-tui`).** A Bubble Tea (Go) TUI built on `chezmoi apply`
  via the mise-managed Go toolchain. It shells out to the `dot ai` verbs so
  behaviour has one source of truth.

## Consequences

- **No new dependency for the headline feature.** The gateway leans on the
  `claude` CLI the user already has; the cockpit is the only Go artefact and is
  opt-in (built when `DOTFILES_AI` is set or already installed).
- **Single source of truth.** The cockpit and completions both derive from the
  `ai.sh` verb dispatch; a completion-parity test and the docs-coverage contract
  keep them from drifting.
- **Scope (v2).** The gateway does chat/completions for both protocols with
  real token-by-token streaming, model routing/aliases, cost metering
  (`/metrics`, `/v1/usage`), an optional daily budget cap, `/v1/models`, and
  `/health`. Because it wraps the `claude` CLI (an agent, not the raw API),
  tool-call passthrough and multimodal image input are handled gracefully but
  not forwarded, and session resumption stays out of scope — documented in
  [`docs/AI.md`](../AI.md).
- **Naming churn.** Existing muscle memory (`dot cl`, `dot ai dashboard`,
  `dot ai proxy`) is preserved via deprecated aliases, so nothing breaks while
  users migrate.

## References

- [`docs/AI.md`](../AI.md) — user guide for the full surface
- [ADR-004](ADR-004-cli-architecture.md) — the `dot` CLI wrapper this extends
- [ADR-008](ADR-008-alias-system-architecture.md) — the alias system the
  deprecated bridges live in
