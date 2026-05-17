# Maintainers

This project is maintained by a single primary maintainer with an
explicit, documented governance model (see `GOVERNANCE.md`).

## Primary maintainer

- **Sebastien Rousseau** — <sebastian.rousseau@gmail.com>
  - GitHub: [@sebastienrousseau](https://github.com/sebastienrousseau)
  - Role: project owner, release manager, security disclosure contact
  - Commit signing: SSH ED25519 (`SHA256:kIOPAavp1TCEauTr1tTIN3cv+tSs6F9m/4lZjuM9tqk`)
  - GPG disclosure key fingerprint: `55AFAD364FD9DB3819E61F0C8D688FAFA9144693` (ed25519 + cv25519, expires 2029-05-15, published via WKD at `security@sebastienrousseau.com`)

## Active contributors

This is a solo-maintained project. Contributions are welcomed via
pull request (see `CONTRIBUTING.md`); the maintainer reviews and
merges. When the project gains additional regular committers their
names will land here with role and contact.

## Security contact

For coordinated vulnerability disclosure, follow `.github/SECURITY.md`.
TL;DR: encrypt your report to the WKD-published GPG key above and
email `security@sebastienrousseau.com`. Acknowledgement SLA: 72 hours.

## Backup / continuity

In the event the primary maintainer becomes unable to maintain the
project, the repository is published under the MIT license and may
be forked. The `chezmoi`-based architecture means existing user
installs continue to work indefinitely without upstream activity.

## Releases

| Release author | Cadence | Signing |
|---|---|---|
| Primary maintainer | ~weekly | Signed annotated git tag + Cosign-signed SBOM + SLSA L3 provenance |

See `docs/operations/HARD_AUDIT_2026.md` Part 7 for the
disclosure-key generation + WKD publication record.
