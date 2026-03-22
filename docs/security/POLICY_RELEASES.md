# Policy Bundle Releases

Policy bundles are released as tracked governance artifacts.

They include:

- policy bundles
- model registry
- prompt registry
- agent profiles
- agent card
- MCP policy, registry, and lock
- A2A discovery metadata

## Local packaging

```bash
bash scripts/release/package-policy-bundles.sh --version 2026.03
bash scripts/release/package-policy-bundles.sh --json
```

## Release workflow

Use the `Policy Bundle Release` workflow.

Release controls:

- source ref must be signed
- governance JSON must validate with `jq`
- bundle archive gets a SHA-256 checksum
- bundle archive gets GitHub provenance attestation

Signed commits remain mandatory for any policy change.
