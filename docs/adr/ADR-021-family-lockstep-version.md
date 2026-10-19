# ADR-021: One version for the whole dot family

Status: Accepted 2026-10-18; the family release driver is pending (plan v3, R0).

## Context

Plan v2 gave each `dot-*` repository its own semantic version and a
`dot_api` range for compatibility. With eighteen command repositories, one
distro and one maintainer, independent versions would mean a compatibility
matrix of every plugin against every host release, and users would have to
read it to know whether an update is safe.

## Decision

Every `dot-*` repository, the `dot-cli` host and `dotfiles` carry the same
version and release together.

- A release is a family release (`~/Code/AGENTS.md` §3, Family Release
  Integration). `feat/v<next>` opens in every member, and each member's
  branch carries its own CHANGELOG section for that version.
- The family releases weekly on Fridays. Security fixes ship on any day as
  an extra family release.
- A new member first ships at the family's current version (0.2.5xx), not
  at 0.0.1.
- First-party compatibility means the same family version. `dot_api`
  remains only for third-party plugins.
- A deprecated command name (ADR-020) lives for one family release.

## Consequences

- A release driver opens the branches, bumps the one version source in each
  member, runs each member's gates and drafts the release PRs.
- A version-sync check blocks a family release when any member disagrees.
- A member with no changes still releases, with a CHANGELOG line saying so.

Related: [ADR-020](ADR-020-command-naming-system.md), [ADR-022](ADR-022-family-language-go.md).
