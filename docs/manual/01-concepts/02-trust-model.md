# Trust Model

The trust model combines cryptographic signing, local-first secrets, policy-gated agent operations, and machine-verifiable attestation.

## Threat Model Summary

| Threat | Mitigation |
|:---|:---|
| Unauthorized code execution on the workstation | Signed commits, shellcheck gates, no `curl | sh` in install path |
| Secret leakage into Git history | Age/SOPS encryption, gitleaks in CI, `detect-secrets` baseline |
| Tampered upstream tool | SHA256-pinned chezmoi installer, SBOM + Grype CVE scan |
| Malicious agent behavior | MCP policy enforcement, agent profile allowlists, attestation logs |
| Compromised fleet host | Per-host signing keys, attestation comparison, `dot chaos` self-tests |
| Downgrade attacks | Version-sync enforcement, signed release tags |

## Identity and Signing

### SSH ED25519 for Git

Every commit on `master` is signed with SSH ED25519:

```sh
git verify-commit HEAD
# Good "git" signature for you@example.com with ED25519 key SHA256:...
```

The trust anchor is the signer's public key published in `~/.ssh/allowed_signers`. CI enforces signature verification on every PR.

### Verified Chezmoi Installer

The `install.sh` script prefers `scripts/ci/install-chezmoi-verified.sh`, which:

1. Downloads chezmoi from the upstream release URL
2. Verifies the SHA256 checksum against a hardcoded, version-pinned value
3. Falls back to `get.chezmoi.io` only if the verified path is unavailable

No unverified binary is ever executed.

## Secrets

### Three Layers

1. **Repository-managed config** (`dot_config/**/*.tmpl`) — checked into Git, no secrets
2. **Local-only config** (`~/.config/*.local`) — gitignored, user-edited
3. **Encrypted secrets** (Age-encrypted `private_*` files, SOPS YAML) — checked in, decrypted on apply

Example encrypted file:

```
dot_config/api-keys.yaml.sops.yaml  # SOPS-encrypted, safe to commit
```

Decryption uses the user's Age private key at `~/.config/age/keys.txt`. Chezmoi invokes `age` or `sops` automatically during apply.

### Secret Scanning

CI runs three independent scanners:

| Scanner | Purpose | Threshold |
|:---|:---|:---|
| `gitleaks` | Pattern-based secret detection | Zero leaks on `master` |
| `detect-secrets` | Baseline-comparing scanner | Zero new secrets vs `.secrets.baseline` |
| `trufflehog` | Verified-secret scanner (API-tested) | Zero verified secrets |

All three must pass for a commit to be merged.

## Agent Policy Enforcement

AI agent operations (Claude Code, Codex, Copilot, Gemini, etc.) are governed by the **Model Context Protocol (MCP)** policy in `dot_config/dotfiles/mcp.json` and validated by `dot mcp`.

### Policy Structure

```json
{
  "policy_version": "2026-01",
  "allowed_servers": ["fs", "shell", "github"],
  "denied_tools": ["network.raw", "fs.write:/etc"],
  "attestation_required": true,
  "signature": "<ed25519-signature>"
}
```

### Enforcement Points

1. **On agent start** — `dot mcp --strict` validates the registry matches the policy hash
2. **Per-tool call** — MCP-aware agents check the policy before invoking a tool
3. **On commit** — `dot attest` records the active policy hash in the attestation log

Violations are logged to `~/.local/state/dotfiles/mcp-violations.log` and reported by `dot doctor`.

## Attestation

`dot attest` generates a signed JSON document containing:

```json
{
  "version": "0.2.500",
  "timestamp": "2026-04-16T09:00:00Z",
  "host": {
    "hostname_sha256": "...",
    "kernel": "Darwin 25.4.0",
    "arch": "arm64"
  },
  "identity": {
    "ssh_key_sha256": "...",
    "git_signer": "you@example.com"
  },
  "policy": {
    "mcp_policy_sha256": "...",
    "agent_profile": "architect"
  },
  "tools": {
    "chezmoi": "2.47.1",
    "mise": "2026.4.0"
  },
  "git": {
    "head": "abc123...",
    "branch": "master",
    "signed": true,
    "verified": true
  }
}
```

The document is:

- Signed with the user's SSH ED25519 key
- Stored at `~/.local/state/dotfiles/attestation/YYYY-MM-DD-HHMMSS.json`
- Optionally published to `~/.dotfiles/docs/attestations/` for team review

### Verifying Someone Else's Attestation

```sh
dot verify --attestation <path>
# ✓ Signature valid (ED25519)
# ✓ Policy hash matches repository
# ✓ Tool versions within supported range
```

## Fleet Trust Propagation

Across multiple hosts, trust is established by:

1. Each host generates its own SSH key pair
2. Each host's public key is added to `~/.ssh/allowed_signers` on every other host
3. Attestations from any host can be verified by any other host
4. `dot fleet` compares attestations across the fleet and flags drift

See [Fleet Architecture](04-fleet.md) for the full model.

## CI-Level Gates

| Gate | Workflow | Blocks Merge |
|:---|:---|:---|
| Signed commits | `ci-enforced.yml` | Yes |
| Shellcheck zero-warnings | `ci.yml` | Yes |
| Gitleaks scan | `ci.yml` | Yes |
| Copyright headers | `ci-enforced.yml` | Yes |
| 100% unit test coverage | `ci-enforced.yml` | Yes |
| Reliability (macOS + Linux) | `ci-enforced.yml` | Yes |
| Checkov infrastructure scan | `ci-enforced.yml` | On severity MEDIUM+ |
| SBOM (CycloneDX) | `ci.yml` | No (informational) |
| Grype CVE scan | `ci.yml` | On severity CRITICAL |
| Lychee link check | `ci.yml` (nightly) | No |

## Principles

- **Local-first** — nothing leaves the workstation unless the user opts in
- **Zero trust in transit** — every network-fetched artifact is checksum-verified
- **Machine-readable evidence** — human-readable summaries are backed by signed JSON
- **Reversible** — `dot rollback` undoes any change with a single command

## See Also

- [Security Policy](../../security/SECURITY.md)
- [Threat Model](../../security/THREAT_MODEL.md)
- [MCP Policy Reference](../../security/MCP_POLICY.md)
- [Attestation Operations](../../operations/ATTESTATION.md)
