# Governance

This file is the root-level entry point required by standard
community-profile tooling. The **canonical governance document** —
including decision classes, contribution flow, release policy, and
escalation paths — lives at [`docs/GOVERNANCE.md`](docs/GOVERNANCE.md).

## Summary

- **Model**: Single-maintainer steward.
- **Owner**: Sebastien Rousseau (see [`MAINTAINERS.md`](MAINTAINERS.md)).
- **Contribution flow**: Issue → branch → signed PR → maintainer review
  and merge. See [`CONTRIBUTING.md`](CONTRIBUTING.md).
- **Release cadence**: Signed annotated tags, Cosign-signed SBOM, SLSA
  L3 provenance. See
  [`docs/security/POLICY_RELEASES.md`](docs/security/POLICY_RELEASES.md).
- **Breaking changes**: RFC in `docs/operations/RFC_<topic>.md`,
  2-week public comment window, migration script, and at least one
  minor-version deprecation cycle.

For anything beyond the summary above, read
[`docs/GOVERNANCE.md`](docs/GOVERNANCE.md).
