# Trusted Agent Workstation

This repository is more than shell setup.

It defines a signed, local-first workstation baseline for agentic development on macOS, Linux, WSL, and PowerShell.

## Core model

- bounded agent profiles
- tracked MCP policy and registry
- workstation attestation
- signed commits and verified merges
- cross-platform CLI and diagnostics

## Governance artifacts

The source of truth lives in tracked JSON artifacts:

- [policy-bundles.json](/home/seb/.dotfiles/dot_config/dotfiles/policy-bundles.json)
- [agent-profiles.json](/home/seb/.dotfiles/dot_config/dotfiles/agent-profiles.json)
- [mcp-policy.json](/home/seb/.dotfiles/dot_config/dotfiles/mcp-policy.json)
- [mcp-registry.json](/home/seb/.dotfiles/dot_config/dotfiles/mcp-registry.json)
- [model-registry.json](/home/seb/.dotfiles/dot_config/dotfiles/model-registry.json)
- [prompt-registry.json](/home/seb/.dotfiles/dot_config/dotfiles/prompt-registry.json)

## Enterprise path

Phase 1 establishes:

- product framing
- policy bundles
- prompt and model change control
- attestation evidence for governance state

Implemented next-layer controls:

- filesystem-backed fleet attestation export
- replayable agent checkpoints
- signed policy bundle release workflow
- tracked A2A conformance validation

Further phases add:

- central audit export
- fleet drift dashboards
- checkpoint policies and retention controls
- broader protocol interoperability coverage

## Validation

Run:

```bash
dot doctor
dot mcp --strict
dot mode list
dot agent card --json
dot attest --json
```

Every governance change requires a signed commit.
