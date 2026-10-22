# ADR-023: The personal account owns the dot family

Status: Accepted 2026-10-18.

## Context

Plan v3 splits the monorepo into one repository per domain, plus
`dotfiles`, `.github`, `plugin-template`, `homebrew-tap` and
`scoop-bucket`. Before the first release signer is pinned, the family needs
one GitHub owner: repository URLs, Go module paths, package names and the
identities that verify releases are all derived from it, and changing the
owner after release breaks every one of them.

The choice was between the personal account `sebastienrousseau`, which
already owns `dotfiles`, the Homebrew tap and the Scoop bucket, and a new
organisation.

## Decision

- Every family repository lives under the personal account:
  `github.com/sebastienrousseau/dot-<domain>`, `dotfiles`, `.github`,
  `plugin-template`, `homebrew-tap` and `scoop-bucket`.
- Go modules are `github.com/sebastienrousseau/dot-<domain>` (ADR-020 N13).
- Release signatures are verified against keyless Sigstore identities
  pinned to this owner: the release workflow of the named repository under
  `https://github.com/sebastienrousseau/`, issued by
  `https://token.actions.githubusercontent.com`. `dot cli` refuses a plugin
  whose signature names any other identity (plan v3, P2.3).

## Consequences

- No organisation to create or administer; the existing tap, bucket and
  AUR package keep their names.
- Pinned identities, module paths and install URLs are stable for as long
  as the owner is. Moving the family to an organisation later means
  re-pinning every signer and republishing every module, so it needs its
  own ADR and a family release that carries both identities for one
  release.

Related: [ADR-020](ADR-020-command-naming-system.md), [ADR-021](ADR-021-family-lockstep-version.md), [ADR-022](ADR-022-family-language-go.md).
