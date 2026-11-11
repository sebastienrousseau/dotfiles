# ADR-024: `send` and `wait`, the verbs of a running agent

Status: Accepted 2026-11-08.

## Context

Plan P0.4 makes herdr-core (`hc`) the runtime agents run on, with tmux
where it is not installed: one agent starts another in a terminal that
outlives it, gives it work, and waits for it to finish. ADR-020 fixed a
closed list of 37 verbs, and three operations are needed:

- start an agent in the background: `start` already means "start an
  interactive or background process", so this is `dot ai start --bg`.
- give a running agent text, as if typed, and submit it: no verb fits.
  `run` launches a new process; `push` moves data to a remote; `set`
  changes stored state.
- block until a running agent stops working (idle, blocked, an error, or
  its exit), or a timeout: no verb fits. `status` returns at once;
  `check` tests and exits.

Both have PowerShell approved verbs, `Send` (Communications) and `Wait`
(Lifecycle), which ADR-020 requires of every verb.

## Decision

- `send` (effect `change`, PowerShell `Send`): give a running program
  text and submit it. It replaces `paste`.
- `wait` (effect `read`, PowerShell `Wait`): block until a running program
  stops working, or until a timeout, leaving it running. It changes
  nothing, so it is `read`.
- The plan's `dot ai spawn` is `dot ai start --bg`; no `spawn` verb.

## Consequences

- The list has 39 verbs; `test_naming_registry.py` counts them.
- `dot ai send <name> <text>` and `dot ai wait [<name>] [--timeout S]`
  map onto `hc send` and `hc wait` (`hc wait --children all` with no
  name), and onto tmux where `hc` is missing.
- The generated cmdlets are `Send-DotAi` and `Wait-DotAi`.

Related: [ADR-020](ADR-020-command-naming-system.md).
