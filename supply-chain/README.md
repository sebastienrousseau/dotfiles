<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<!-- Copyright (c) 2015-2026 Sebastien Rousseau -->

# `supply-chain/` — dependency provenance policy and state

In a Rust project this directory holds `cargo-vet` audits and
`cargo-deny` state. This project is mostly bash, Go-template and Lua
(with small Go and Rust components): there is no `cargo-vet`
equivalent for shell, and inventing a tool that no
CI job runs would be worse than having none — an unenforced policy
file is a claim, not a control.

So this directory documents the provenance policy that **is** enforced,
names the job that enforces each rule, and holds the allowlists those
jobs read.

## The policy

Every external input to a build or CI run must be immutable and
verifiable at the point of use. Five categories, five controls:

| # | Category | Rule | Enforced by |
|---|---|---|---|
| 1 | Third-party GitHub Actions | Pinned to a 40-hex commit SHA, with the human-readable version in a trailing comment | OpenSSF Scorecard `Pinned-Dependencies`; reviewed on every PR that touches a workflow |
| 2 | Reusable workflows | Same-repository workflows use the local form (`uses: ./.github/workflows/<file>.yml`), so a PR runs the workflow code under test; external reusable workflows are pinned to a 40-hex commit SHA | [`tools/ci/lint-reusable-pins.sh`](../tools/ci/lint-reusable-pins.sh), run by `ci.yml` job *Lint / Reusable Workflow Pins* |
| 3 | Container base images | `FROM image:tag@sha256:<digest>` | Reviewed on PR; Checkov (`security-enhanced.yml`, `ci-enforced.yml`). Not yet universal: `fuzz/oss-fuzz/Dockerfile` uses an unpinned OSS-Fuzz base, and images that workflows start with `docker run` (hadolint, Grype, the distro test matrix) are pinned by tag only |
| 4 | Binaries fetched at build time | Downloaded then checked against a committed SHA256 | [`../security/remote-installers.sha256`](../security/remote-installers.sha256) via [`tools/ci/check-remote-installers.sh`](../tools/ci/check-remote-installers.sh) |
| 5 | Package dependencies (npm, PyPI, Actions) | Locked, and screened against advisory data on every PR | `dependency-review.yml`, `deps-dev-validation.yml` ([`tools/ci/check-deps-dev.sh`](../tools/ci/check-deps-dev.sh)), `sbom-diff.yml` (Grype) |

There is exactly one documented exception, and it is structural rather
than a lapse: the SLSA generic generator
(`slsa-framework/slsa-github-generator`) refuses to run when invoked
by commit SHA — it validates that its caller reference is a
`refs/tags/vX.Y.Z` — so it is pinned to the exact release tag
`v2.1.0`. OpenSSF Scorecard exempts it for the same reason. Rationale
and the verification step before any tag bump:
[`../docs/security/CI_PINNING.md`](../docs/security/CI_PINNING.md).

## Lockfiles

| File | Covers | `--locked` in CI |
|---|---|---|
| `mise.lock`, `mise-versions.lock.json` | The local development toolchain | No: no CI job runs `mise install` |
| `requirements-contracts.txt` | Contract tests (Python), hash-pinned, compiled from `requirements-contracts.in` | Yes: `core-contracts.yml` installs with `pip install --require-hashes` |
| `package.json` | Node dev tooling | No: there is no lockfile, so versions are not locked |
| `flake.lock`, `nix/flake.lock` | Nix dev shell and package outputs | Yes |
| `go.sum` files (`fuzz/`, `core/`, the Go modules under `defaults/dot_local/share/`) | Go dependencies | Yes: `go test` / `go build` verify checksums |
| `lib/wasm-tools/Cargo.lock` | Rust components | Yes: `rust.yml` runs `cargo --locked` |

## Allowlists and exception registers

Time-bounded exceptions live in files, not in reviewers' heads:

| File | What it allows | Expiry policy |
|---|---|---|
| [`../docs/security/DEPS_DEV_EXCEPTIONS.md`](../docs/security/DEPS_DEV_EXCEPTIONS.md) | One `(ecosystem, package)` advisory suppression each | Every entry carries an expiry date |
| [`../docs/security/CI_EGRESS_ALLOWLIST.md`](../docs/security/CI_EGRESS_ALLOWLIST.md) | Network endpoints reachable under `harden-runner` block mode | Reviewed when a job moves to block mode |
| [`../docs/security/SHELL_EXEMPTIONS.md`](../docs/security/SHELL_EXEMPTIONS.md) | Files exempt from the `set -euo pipefail` preamble rule | Each needs a stated justification |
| [`../.gitleaksignore`](../.gitleaksignore), [`../.secrets.baseline`](../.secrets.baseline) | Known non-secrets | Regenerated when the tree changes |
| [`../config/trivyignore`](../config/trivyignore) | Accepted container findings | Reviewed per release |

A blanket suppression is never acceptable. An exception names one
thing, says why, and expires.

## Outputs

What the pipeline produces so that *consumers* can do their own
verification, rather than trusting this document:

| Artefact | Format | Workflow |
|---|---|---|
| SBOM | CycloneDX 1.6 JSON | `release-package-dot.yml` |
| SBOM | SPDX 2.3 JSON | `security-release.yml` |
| Build provenance | SLSA / in-toto, `gh attestation verify` | `release-package-dot.yml` |
| Signatures | sigstore keyless (Fulcio + Rekor) | `release-package-dot.yml`, `security-release.yml` |
| Checksums | `dot-<version>.SHA256SUMS`, signed `ALL_SHA256SUMS` | `release-package-dot.yml`, `security-release.yml` |

Consumer-side recipes: [`../pkg/VERIFY.md`](../pkg/VERIFY.md).

## What this policy does not cover

Stated plainly, because the gaps matter more than the coverage:

- **No human audit of transitive dependency source.** There is no
  `cargo-vet`-style register of "someone read this code". The controls
  above establish *immutability and provenance*, not trustworthiness
  of the upstream author.
- **No reproducible-builds verification.** Release archives are built
  deterministically, but no diffoscope comparison of two independent
  rebuilds runs in CI, so this is not a reproducible-builds claim.
- **No runtime dependency pinning for the user's machine.** `dot`
  invokes chezmoi, git and optional tools from the user's `PATH`. The
  floors are documented in
  [`../docs/MINIMUM-TOOLCHAIN.md`](../docs/MINIMUM-TOOLCHAIN.md); their
  provenance is the user's package manager's problem, not this
  repository's.

Threat model behind these choices:
[`../docs/security/THREAT_MODEL.md`](../docs/security/THREAT_MODEL.md).
