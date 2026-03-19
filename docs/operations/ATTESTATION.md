# Workstation Attestation

`dot attest` exports a machine-readable record of the current workstation state.

It captures:
- dotfiles version
- platform and architecture
- Git signing settings
- active agent profile
- MCP strict-mode audit status
- tracked agent card, profile, and registry data

Run:

```bash
dot attest
dot attest --json
dot attest --write ~/.local/state/dotfiles/attestations/workstation.json
```

The default output path is `~/.local/state/dotfiles/attestations/workstation-attestation.json`.
