# ADR-025: The AI policy is enforced at the agent's pre-tool hook

Status: Accepted 2026-11-09.

## Context

The agent modes (`ask`, `plan`, `apply`, `audit`) and the RBAC in
`agent-profiles.json` say what an agent may do, but nothing stops it:
`"enforcement": "advisory"`. Plan P1.1 turns that into enforcement.

Three agents can refuse a tool call from a hook, each in its own form:

- Claude Code: a `PreToolUse` hook prints
  `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":…}}`.
- Codex: the same form, from a `PreToolUse` hook in `~/.codex/hooks.json`,
  which runs once the user trusts it in Codex's `/hooks`. It covers shell,
  `apply_patch` and MCP calls, not hosted tools such as web search.
- Gemini CLI: a `BeforeTool` hook prints `{"decision":"deny","reason":…}`.

A hook that crashes, or prints something else, lets the call run in all
three. The decision has to come from the hook's output, every time.

## Decision

- One file, `~/.config/dotfiles/ai-policy.toml`, schema `ai-policy.v1`.
  `[mode.<name>]` holds the rules of a mode: `tools` (an allow-list of
  classes `shell`, `read`, `write`, `search`, `fetch`, `mcp`, or tool
  names), `tools_deny`, and allow and deny globs for `paths`, `hosts` and
  `commands`. `[agent.<id>.mode.<name>]` replaces, for one agent, the lists
  it sets. `default_mode` applies when no mode is active.
- The active mode is the one `dot agent mode` keeps:
  `$DOT_AGENT_PROFILE`, else the last `DOT_AGENT_PROFILE=` in
  `agent-mode.env`, else `default_mode`.
- `dot-policy`, a Go binary (ADR-022) built by chezmoi, reads the file and
  decides each call. `dot cli hook check --agent <id>` is the hook, wired
  by `dot cli hook install` on each agent's pre-tool event. It prints the
  denial in that agent's form.
- It fails closed. A file that does not parse or validate (an unknown key
  included), a mode it has no rules for, a payload with no tool call, or a
  `dot-policy` that is missing or exits non-zero: each denies the call and
  says why. With no file, nothing is enforced and the hook returns at once.
- `dot ai policy check` validates the file and names the active mode.
- `[gateway]` (0.2.543, plan P1.2) limits the local AI gateway's
  requests: `models` (globs over the resolved model) and
  `max_input_tokens`. `dot-policy gateway` decides each request before
  the engine sees it, and fails closed as the hook does.
- `[budget]` (0.2.543, plan P1.3) caps what agents spend, at the API list
  prices `dot ai cost show` reports: `daily_usd` (today, every session)
  and `session_usd`. The check also runs on each prompt
  (`UserPromptSubmit`, `BeforeAgent`): from 80% of a cap the prompt
  carries a warning, at 100% it is blocked before the model sees it. A
  budget whose spend cannot be read blocks, as the hook fails closed.

## Consequences

- The policy is a guardrail, not a sandbox. Commands are split at `;`,
  `&&`, `||`, `|`, `&`, `$(` and backticks, without parsing quotes, and a
  path is not resolved through symlinks. An agent that runs a script it
  wrote runs that script's commands unchecked. The OS sandbox of each
  agent still matters.
- A host with a policy and no Go toolchain denies every tool call until
  `dot-policy` is built. That is the fail-closed choice; `dot ai policy
  check` names the cause.
- Each tool call pays one `bin/dot` start plus the check (about 0.5 ms in
  process); `BenchmarkCheck` measures the latter.
- The schema is the contract later work builds on: budgets (P1.3), the
  policy hash in the inventory (P1.5), and signed policy packs (P1.6).

## Amendment 2026-11-18 (0.2.548): the credentials dot manages

Status: the preset change is Accepted; the default policy is Proposed.

- Every preset in `ai-policy-pack` (1.0.1) denies, in every mode, reads
  of the credentials dot itself manages: the chezmoi age identity
  (`~/.config/chezmoi/key.txt`, which decrypts every `.age` secret),
  `~/.config/chezmoi/chezmoi.*`, `~/.netrc`, `~/.npmrc`,
  `~/.config/gh/hosts.yml`, dot's secrets store
  (`~/.config/dotfiles/secrets/**`), the AI gateway token
  (`~/.local/state/dot/ai/serve/gateway.token`) and `~/Library/Keychains/**`.
  Apply mode also denies shell commands that name those files or dump
  them (`security find-generic-password`, `security dump-keychain`,
  `gh auth token`, `chezmoi decrypt`, `age -d`). As above, this is a
  guardrail: a command that reaches a secret without naming it is not
  caught.
- Decided (maintainer, 2026-11-18): with no `ai-policy.toml`, `dot cli
  hook check` enforces the deny-only floor in
  `~/.local/share/dot-policy/floor.toml` (`$DOT_AI_POLICY_FLOOR`). It has
  one mode, `floor`, which the hook always passes, so the active agent mode
  cannot select a stricter one: every tool is allowed except reading the
  credentials listed above and the commands that print or decrypt them.
  It sets no budget, so prompts are not checked. Unlike a policy file, the
  floor fails open: without `dot-policy` (no Go on the host) the call is
  allowed, because denying every call on such a host would leave agents
  unusable. The "With no file, nothing is enforced" rule above now reads
  "With no file, only the floor is enforced".

Related: [ADR-020](ADR-020-command-naming-system.md),
[ADR-022](ADR-022-family-language-go.md).
