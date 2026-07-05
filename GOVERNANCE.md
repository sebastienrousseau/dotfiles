# Governance

This document describes how decisions are made for this project and how the
single-maintainer model is kept safe and auditable.

## Model

This is a **maintainer-led** project. [Sebastien Rousseau](https://github.com/sebastienrousseau)
is the primary maintainer and final decision-maker on scope, architecture, and
releases.

A single-maintainer project carries an inherent bus-factor risk. We mitigate it
deliberately, so that correctness does not depend on any one person reviewing
any one change:

- **Automation is the reviewer.** Every change must pass an enforced gate
  before it can merge: `shellcheck`, `shfmt`, `luacheck`/`stylua`, the unit /
  integration / regression test suites, CodeQL, Checkov, Grype, gitleaks, the
  docs-coverage contract, and the cross-shell parity contract. See
  [`docs/operations/`](docs/operations/) and `.github/workflows/`.
- **Signed history.** Commits are signed (SSH ED25519) and `required_signatures`
  is enforced on `main`. See [`docs/security/COMMIT_SIGNING.md`](docs/security/COMMIT_SIGNING.md).
- **Pinned supply chain.** GitHub Actions are SHA-pinned, dependencies are
  lockfile-pinned, and an SBOM is generated per release.
- **Documented decisions.** Significant choices are recorded as ADRs in
  [`docs/adr/`](docs/adr/), so the reasoning survives independently of the
  maintainer.
- **Reproducibility.** The installer is idempotent and the configuration is
  declarative (chezmoi + mise), so the environment can be rebuilt from source
  by anyone.

## Decision making

- **Routine changes** (fixes, docs, dependency bumps) are made directly by the
  maintainer, gated by CI.
- **Architectural changes** are proposed as an ADR in `docs/adr/` before
  implementation.
- **Breaking changes** are called out in [`CHANGELOG.md`](CHANGELOG.md) and,
  where relevant, the migration notes under `docs/operations/`.

## Contributing

Contributions are welcome. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the
workflow and [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) for community
expectations. Pull requests run the full enforced gate; a green pipeline is a
prerequisite for review.

## Succession

Should the primary maintainer become unavailable, the project can be continued
by any contributor with: the documented ADRs, the enforced CI gates, and the
declarative configuration. Forking and continuing under the MIT
[`LICENSE`](LICENSE) is explicitly permitted and supported.
