---
render_with_liquid: false
---

# Agent Interop

The repository now ships an agent card and an A2A-ready discovery document.

Artifacts:

- [agent-card.json](https://github.com/sebastienrousseau/dotfiles/blob/main/defaults/dot_config/dotfiles/agent-card.json)
- [agent.json](https://github.com/sebastienrousseau/dotfiles/blob/main/.well-known/agent.json)

Core properties:

- bounded profiles: `ask`, `plan`, `apply`, `audit`
- MCP-governed execution
- workstation attestation export
- persistent agent session logs
- replayable checkpoints
- fleet attestation export

Tracked governance artifacts:

- policy bundles
- prompt registry
- model registry

Session events are `session_<event>` records in the agent log, `~/.local/state/dot/agent/log.jsonl` (log.v1).
Checkpoints are stored in `~/.local/state/dotfiles/checkpoints/`.

Validate conformance with:

```bash
dot agent card check
dot agent card check --strict --json
```

The current posture is A2A-ready with tracked conformance checks. It exposes identity, governance, checkpoints, and local evidence.
