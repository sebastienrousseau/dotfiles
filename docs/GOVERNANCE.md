# Governance

## Model

**Single-maintainer steward.** The project is owned and decided
by one maintainer (see [`MAINTAINERS.md`](MAINTAINERS.md)). This document exists so
contributors and downstream consumers understand exactly how
decisions are made, how to influence them, and what guarantees
exist.

## Decision-making

| Decision class | Process | Veto |
|---|---|---|
| Bug fix | Open PR, maintainer reviews + merges. Tests required. | Maintainer |
| Feature addition | Open issue first to scope. Then PR. Larger changes need an RFC in `docs/operations/`. | Maintainer |
| Breaking change | RFC in `docs/operations/RFC_<topic>.md` + 2-week comment window + migration script + at least one minor-version deprecation. | Maintainer (with public reasoning) |
| Security policy | `.github/SECURITY.md` is the canonical reference. Disclosure-key rotation follows `docs/security/KEY_ROTATION.md`. | Maintainer + 30-day public notice |
| Dependency change | Pre-commit + CI must stay green. New runtime deps require RFC. | Maintainer |
| Release | Maintainer cuts tags. Convention: signed annotated tag, Cosign-signed SBOM, SLSA L3 provenance. | Maintainer |

## Contribution flow

1. **Issue** for non-trivial work. Confirm scope before coding.
2. **Branch** off `master`: `feat/<scope>`, `fix/<scope>`,
   `docs/<scope>`, etc.
3. **PR** with description following the template:
   - Summary (1–3 bullets)
   - Test plan (checklist)
   - Trailing Euxis signature block (required by
     `pr-signature.yml`)
4. **CI** must pass before merge. Pre-commit hooks must not be
   bypassed (`--no-verify` is rejected by the pre-push hook).
5. **Review** by the maintainer. Squash-merge is the project
   default; merge-commit only for release PRs that need history
   preserved (e.g., `feat/v0.X.YYY` aggregate PRs).
6. **Commit signing** is mandatory: SSH or GPG. Unsigned commits
   are rejected at push.

See `CONTRIBUTING.md` for full code-style + commit-message
requirements.

## RFC process

For breaking changes or substantial new features:

1. Create `docs/operations/RFC_<short-name>.md` with sections:
   - **Summary** (one paragraph)
   - **Motivation** (why now, what's broken without it)
   - **Detailed design** (concrete file paths, API shapes)
   - **Backwards compatibility** (what breaks, migration path)
   - **Alternatives considered** (with reasons rejected)
   - **Unresolved questions**
2. Open a PR labelled `rfc` against `master`.
3. Comment window: 14 days minimum.
4. Maintainer renders a decision (accept / accept-with-changes /
   reject) with public reasoning in the PR.
5. Accepted RFCs are merged as-is to `docs/operations/` and become
   the implementation reference.

Active and historical RFCs are linked from
`docs/operations/README.md`.

## Code of conduct

Standard expectations: be kind, assume good faith, focus on the
work. Discriminatory or harassing behaviour is grounds for
permanent block. Report incidents to the maintainer via the
security disclosure channel (`security@sebastienrousseau.com`,
encrypted to the WKD-published GPG key).

## Forking

The project is MIT-licensed; fork freely. If your fork diverges
substantially and gains its own community, please rename it to
avoid downstream confusion ("dotfiles-X" or similar).

## Sustainability

The single-maintainer model has known weaknesses (bus factor,
review bandwidth, perspective). The project mitigates these by:

- **Comprehensive automation**: 75+ CI checks, pre-commit hooks,
  shellcheck/shfmt/typos enforcement.
- **Documented architecture**: [`STRUCTURE.md`](STRUCTURE.md), `scripts/README.md`,
  `architecture/`, `operations/HARD_AUDIT_2026.md`.
- **Cryptographic supply chain**: Cosign-signed SBOMs, SLSA L3
  provenance, signed commits, WKD-published disclosure key.
- **Permissive license**: MIT — anyone can fork and continue.
- **Active issue triage**: targeted weekly cadence.

When the project gains regular contributors, this document will be
updated to reflect the shared-maintainer model.

## Reference

- [OpenSSF Best Practices criteria](https://www.bestpractices.dev/en/criteria/0) — this governance model is designed to satisfy the "passing" tier.
- [CNCF Project Governance template](https://contribute.cncf.io/maintainers/governance/) — adapted for solo maintainership.
