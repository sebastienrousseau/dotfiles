# Workstation Attestation

`dot attest` exports a machine-readable record of the current workstation state.

It captures:
- dotfiles version
- platform and architecture
- Git signing settings
- active agent profile
- MCP strict-mode audit status
- tracked agent card, profile, and registry data
- policy bundles
- model and prompt registries

Run:

```bash
dot attest
dot attest --json
dot attest -j
dot attest --write ~/.local/state/dotfiles/attestations/workstation.json
dot attest -w ~/.local/state/dotfiles/attestations/workstation.json
dot attest --fleet-store /srv/dotfiles-fleet
dot attest -F /srv/dotfiles-fleet -I engineering
```

The default output path is `~/.local/state/dotfiles/attestations/workstation-attestation.json`.

Fleet export writes:

- `<fleet-store>/<fleet-id>/<hostname>/workstation-attestation.json`
- timestamped copies for retention

Governance evidence is embedded directly in the JSON output. That includes:

- policy bundle definitions
- model registry metadata
- prompt registry metadata
- tracked MCP policy and registry artifacts
