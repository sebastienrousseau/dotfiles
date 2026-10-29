---
render_with_liquid: false
---

# Trust Model

The trust model combines cryptographic signing, local-first secrets, policy-gated agent operations, and machine-verifiable attestation.

## Threat Model Summary

| Threat | Mitigation |
|:---|:---|
| Unauthorized code execution on the workstation | Signed commits, shellcheck gates, no `curl \| sh` in install path |
| Secret leakage into Git history | Age/SOPS encryption, gitleaks and TruffleHog in CI, `detect-secrets` baseline in pre-commit |
| Tampered upstream tool | SHA256-pinned chezmoi installer, SBOM + Grype CVE scan |
| Malicious agent behavior | MCP policy checks (`dot mcp check`), agent profile allowlists, attestation evidence |
| Compromised fleet host | Per-host signing keys, per-host attestation records, chaos self-tests (`scripts/ops/chaos.sh`) |
| Downgrade attacks | Version-sync enforcement, signed release tags |

## Identity and Signing

### SSH ED25519 for Git

Commits are signed with SSH ED25519, and branch protection on `main` requires a verified signature on every commit. A pull request merged on GitHub lands as a commit signed by GitHub's own key:

```sh
git verify-commit HEAD
# gpg: Signature made Thu 29 Oct 2026 07:03:43 GMT
# gpg:                using RSA key B5690EEEBB952194
# gpg: Good signature from "GitHub <noreply@github.com>" [ultimate]
```

For SSH signatures, the trust anchor is the signer's public key in `~/.config/git/allowed_signers` (the managed `gpg.ssh.allowedSignersFile`). On pull requests, `compliance-guard.yml` lists unsigned commits as a warning; the merge block comes from branch protection.

### Verified Chezmoi Installer

When chezmoi is missing and Homebrew is not available, `install.sh` installs it with `tools/ci/install-chezmoi-verified.sh` (or an embedded copy of the same verifier), which:

1. Downloads chezmoi from the upstream release URL
2. Verifies the SHA256 checksum against a hardcoded, version-pinned value
3. Refuses to continue if verification fails: there is no `get.chezmoi.io` fallback

No unverified binary is ever executed.

## Secrets

### Three Layers

1. **Repository-managed config** (`defaults/dot_config/**/*.tmpl`) — checked into Git, no secrets
2. **Local-only config** (`~/.config/*.local`) — gitignored, user-edited
3. **Encrypted secrets** (chezmoi `encrypted_` files, SOPS YAML) — checked in, decrypted on use

Example encrypted file, as `chezmoi add --encrypt ~/.config/api-keys.yaml` names it:

```
defaults/dot_config/encrypted_api-keys.yaml.age  # age-encrypted, safe to commit
```

chezmoi decrypts `encrypted_` files during apply with the age identity at `~/.config/chezmoi/key.txt`. SOPS files are decrypted by `sops`, which reads `~/.config/sops/age/keys.txt`.

### Secret Scanning

Three independent scanners run:

| Scanner | Where | Threshold |
|:---|:---|:---|
| `gitleaks` | `ci.yml` and `ci-enforced.yml` (full history) | Zero leaks |
| `detect-secrets` | local pre-commit hook (`config/pre-commit-config.yaml`) | Zero new secrets vs `.secrets.baseline` |
| `trufflehog` | `ci.yml` (`--only-verified`) | Zero verified secrets |

Only the gitleaks job in `ci-enforced.yml` feeds the required Merge Gate. `detect-secrets` runs on your machine before each commit, not in CI.

## Agent Policy Enforcement

AI agent operations (Claude Code, Codex, Copilot, Antigravity CLI, etc.) have their **Model Context Protocol (MCP)** servers governed by the policy in `defaults/dot_config/dotfiles/mcp-policy.json`, the server registry in `mcp-registry.json` and the package pins in `mcp-lock.json` (deployed under `~/.config/dotfiles/`), and checked by `dot mcp check`.

### Policy Structure

An excerpt of the shipped `strict-local` profile:

```json
{
  "policyVersion": "2026.03",
  "defaultProfile": "strict-local",
  "profiles": {
    "strict-local": {
      "allowedLaunchers": ["npx", "node", "uvx"],
      "trustedTransports": ["stdio", "http"],
      "blockedFilesystemRoots": ["/", "/home", "/Users"],
      "warnOnUnpinnedNpx": true,
      "requireApprovedPackageLock": true,
      "requireRegistryEntry": true,
      "requireHttpsForHttpTransports": true
    }
  }
}
```

### Enforcement Points

1. **On demand**: `dot mcp check` checks the configured servers against the policy, the registry and the pins; `--strict` turns policy warnings into errors
2. **In the evidence**: `dot attest show` embeds the MCP policy, the registry and the `mcp-doctor` summary in the attestation record

The policy is checked, not enforced per tool call: an agent that loads an MCP server outside this flow is not stopped by it.

## Attestation

`dot attest show` generates an unsigned JSON evidence record. An excerpt of `dot attest show --json` (the `agent`, `governance` and `mcp` objects also embed the full agent profiles, agent card, registries and MCP policy):

```json
{
  "generated_at": "2026-10-29T07:37:54Z",
  "dotfiles_version": "0.2.539",
  "platform": {
    "runtime": "linux",
    "host_os": "linux",
    "architecture": "x86_64",
    "hostname": "my-workstation"
  },
  "git_signing": {
    "format": "ssh",
    "signing_key": "~/.ssh/id_ed25519",
    "allowed_signers_file": "~/.config/git/allowed_signers",
    "merge_verify_signatures": true
  },
  "agent": {
    "current_profile": "ask"
  },
  "mcp": {
    "doctor": {
      "status": "healthy"
    }
  }
}
```

The record is:

- Not signed: it is evidence to check, not a signed statement
- Written to `~/.local/state/dotfiles/attestations/workstation-attestation.json` by `dot attest show` (without `--json`), or to a path of your choice with `dot attest export <path>`
- Written per host with `dot attest show --fleet-store <dir> [--fleet-id <id>]`, to `<dir>/<id>/<hostname>/workstation-attestation.json` plus a timestamped copy

### Verifying an Attestation

`dot attest verify` checks a fresh record of this machine, and `dot attest verify <path>` checks a record from a file (from another host, say); `--json` prints the verdict as JSON and `--max-age <secs>` sets the freshness window for `generated_at`.

The verifier is `lib/wasm-tools` built for `wasm32-wasip1` and run under `wasmtime`, with no filesystem, network or environment. It checks the required fields, the allowed values (`git_signing.format`, `agent.current_profile`, and `mcp.doctor.status`, which must be `healthy`), that `git_signing.merge_verify_signatures` is `true`, and the record's age. Exit codes: 0 every check passed, 1 a check failed, 2 unusable input or toolchain. The first run builds the module, which needs the Rust `wasm32-wasip1` target.

## Fleet Trust Propagation

Across multiple hosts, trust is established by:

1. Each host generates its own SSH key pair
2. Each host's public key is added to `~/.config/git/allowed_signers` on every other host
3. Commits signed on any host verify on every other host, and any host can run the verifier on another host's attestation record
4. `dot attest show --fleet-store <dir>` on each host collects the records in one directory tree for review

See [Fleet Architecture](04-fleet.md) for the full model.

## CI-Level Gates

The required status checks on `main` are Merge Gate (`ci-enforced.yml`), Reliability Summary (`reliability-gate.yml`), Pre-Commit (`pre-commit.yml`), Check sign-off (`dco.yml`) and the PR description signature (`pr-signature.yml`). Merge Gate fails when any job it depends on fails.

| Gate | Workflow | Blocks Merge |
|:---|:---|:---|
| Signed commits | Branch protection on `main` | Yes |
| ShellCheck at `error` severity | `ci-enforced.yml` (Merge Gate) | Yes |
| Gitleaks scan | `ci-enforced.yml` (Merge Gate) | Yes |
| Copyright headers | `ci-enforced.yml` (Merge Gate) | Yes |
| Unit tests, test matrix, mutation, complexity ratchet | `ci-enforced.yml` (Merge Gate) | Yes |
| Reliability (Ubuntu + macOS) | `reliability-gate.yml` | Yes |
| Checkov infrastructure scan | `ci-enforced.yml` (Merge Gate) | Yes (`soft_fail: false`) |
| Measured Bash line coverage | `coverage.yml` | Not a required check; ratcheted floor, see `docs/operations/COVERAGE.md` |
| TruffleHog verified secrets | `ci.yml` | No (not a required check) |
| SBOM (CycloneDX) | `ci.yml` | No (informational) |
| Grype CVE scan | `ci.yml` | No (`fail-build: false`, reports CRITICAL) |
| Lychee link check | `ci.yml` (schedule or manual run) | No |

## Principles

- **Local-first** — nothing leaves the workstation unless the user opts in
- **Zero trust in transit** — every network-fetched artifact is checksum-verified
- **Machine-readable evidence** — human-readable summaries are backed by JSON a sandboxed verifier can check
- **Reversible** — `dot doctor rollback rollback` restores the most recent backup of the core dotfiles

## See Also

- [Security Policy](../../security/SECURITY.md)
- [Threat Model](../../security/THREAT_MODEL.md)
- [MCP Policy Reference](../../security/MCP_POLICY.md)
- [Attestation Operations](../../operations/ATTESTATION.md)
