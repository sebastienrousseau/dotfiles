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

Session logs are stored in `~/.local/state/dotfiles/agent-sessions.jsonl`.
