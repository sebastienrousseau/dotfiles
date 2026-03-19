# Agent Interop

The repository now ships an agent card and an A2A-ready discovery document.

Artifacts:
- [agent-card.json](/home/seb/.dotfiles/dot_config/dotfiles/agent-card.json)
- [agent.json](/home/seb/.dotfiles/.well-known/agent.json)

Core properties:
- bounded profiles: `ask`, `plan`, `apply`, `audit`
- MCP-governed execution
- workstation attestation export
- persistent agent session logs

Tracked governance artifacts:
- policy bundles
- prompt registry
- model registry

Session logs are stored in `~/.local/state/dotfiles/agent-sessions.jsonl`.

The current posture is A2A-ready. It exposes identity, governance, and local evidence. Future phases add protocol conformance testing and transport validation.
