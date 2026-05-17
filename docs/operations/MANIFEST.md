---
title: "Workstation Environment Manifest"
date: 2026-05-17
---

# Workstation Environment Manifest

`dot env emit` produces a portable, schema-validated record of
"what is installed on this machine" — the canonical input that
downstream tooling consumes.

## Schema

[`docs/schema/dot-env-v1.json`](../schema/dot-env-v1.json) is a
JSON Schema 2020-12 file. Validate any manifest against it with:

```sh
dot env emit | jsonschema -i /dev/stdin docs/schema/dot-env-v1.json
# or
dot env emit | check-jsonschema --schemafile docs/schema/dot-env-v1.json /dev/stdin
```

(`jsonschema` from the `jsonschema` PyPI package; `check-jsonschema`
from `python-jsonschema/check-jsonschema`. Either works.)

## Quick reference

```sh
dot env emit                              # canonical JSON to stdout
dot env emit --format ndjson              # one tool per line, greppable
dot env emit --output /tmp/env.json       # atomic file write
dot env emit --compact                    # one-line JSON
dot env emit --help                       # flags + examples
```

Example output (truncated):

```json
{
  "schema_version": "https://sebastienrousseau.github.io/dotfiles/schema/dot-env-v1.json",
  "manifest_version": "1.0.0",
  "emitted_at": "2026-05-17T10:22:46Z",
  "emitter": {
    "name": "dot env emit",
    "version": "0.2.503",
    "repo": "github.com/sebastienrousseau/dotfiles"
  },
  "host": {
    "hostname": "rousseau-mbp-m1",
    "os": "Darwin",
    "arch": "arm64"
  },
  "tools": [
    {
      "name": "node",
      "version": "24.14.0",
      "source": "/Users/seb/.dotfiles/mise.toml",
      "source_type": "mise.toml",
      "requested_version": "24.14.0",
      "install_path": "/Users/seb/.local/share/mise/installs/node/24.14.0",
      "active": true
    },
    ...
  ]
}
```

## Why this exists

R3 §7.4 strategic-reversal call: **ship `dot env emit` BEFORE
`dot fleet apply --attest`**. Three independent forces converge on
a 2026-09-17 / 2026-09-11 window:

1. **AgentSpec / AAIF** public deadline at AGNTCon Amsterdam
   2026-09-17. First-mover with the canonical "one signed
   manifest → AGENTS.md + agent.yaml + devcontainer-feature.json
   + mise.toml + Brewfile + flake.nix + in-toto subject list"
   generator owns the reference implementation.
2. **EU CRA SBOM reporting** binding 2026-09-11. A v1 manifest
   per workstation feeds the "demonstrate vulnerability response"
   story for any EU procurement team.
3. **dotbot v3.5.0's `workflow.yaml`** is 80% of the way to
   AgentEnv parity. The window before they generate the same
   manifest is measured in weeks.

## Downstream consumers (planned)

The v1 manifest is the source-of-truth that subsequent emitters
will re-render. Each emitter is a single jq filter from the v1
shape:

| Target format | Use case | Status |
|---|---|---|
| `AGENTS.md` | Cross-harness AI agent context | shipped (`dot agents render`); will be re-pointed at the v1 manifest in v0.2.504 |
| `devcontainer-feature.json` | Reproducible cloud-IDE setup | planned (v0.2.504) |
| `mise.toml` | Round-trip: re-create the same install set on a fresh host | planned |
| `Brewfile` | Hand off to a Homebrew-managed Mac | planned |
| `flake.nix` | Nix reproducibility | planned (input to nix-shell) |
| `in-toto subject list` | SLSA attestation subject array | planned (`dot fleet apply --attest`) |
| `CycloneDX SBOM` | Compliance reporting (EU CRA) | planned (v0.2.504; per-artifact attestation closes R3-N7) |

The schema is intentionally minimal — `dot env emit` records *what
is installed*, not *what is desired* or *what is approved*. Downstream
emitters add policy / approval / risk-score columns as they need
them.

## CI usage

```yaml
- name: Snapshot environment manifest
  run: |
    dot env emit --output env.json
    # Attest the manifest as part of the next release
    cosign sign-blob --yes --output-signature env.json.sig \
      --output-certificate env.json.pem env.json
```

The signed manifest goes into the release alongside the SBOM —
together they let any consumer answer "what software was on the
runner that produced this release" and verify it cryptographically.

## See also

- `docs/schema/dot-env-v1.json` — the JSON Schema authoritative spec.
- `docs/security/VERIFY_RELEASE.md` — three-attestation verification flow this manifest plugs into.
- `docs/operations/HARD_AUDIT_2026.md` §7.4 — strategic-reversal record.
- `docs/operations/ROADMAP_V0_2_503.md` — `dot env emit` was originally deferred to v0.2.504; pulled forward in this PR per user request.
