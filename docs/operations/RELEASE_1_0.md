---
render_with_liquid: false
---

# Release 1.0 — Definition of Done

The project has shipped 500+ patch releases under the `0.2.x` line
because every change has been additive, migration-scripted, and
tested — but "0.2" doesn't signal stability to downstream consumers.
This document defines the concrete criteria for cutting `v1.0.0`,
so the version signal accurately reflects what the codebase already
is: production-grade for the maintainer's personal workstation
fleet, and extension-grade for anyone building on top of it.

## 1.0 promises

Cutting `v1.0.0` will commit to the following, backed by semver:

| Promise | Concrete meaning |
|---|---|
| **Stable CLI surface** | Every `dot <subcommand>` in `share/completions/dot` at 1.0 keeps its argv contract until 2.0. New subcommands land as minors; breaking argv changes require a major. |
| **Stable install contract** | `install.sh <flags>` behaves as documented in `docs/guides/INSTALL.md`. The bootstrap flag matrix is frozen; new flags are additive. |
| **Stable chezmoi data schema** | The keys in `defaults/.chezmoidata.toml` are versioned. Renaming or removing a key is a major; adding one is a minor. Templates use `hasKey` guards for backward compatibility with pre-1.0 sources. |
| **Migration contract** | Every 1.x → 1.(x+1) upgrade ships an idempotent `install/migrate/migrate-1_(x)-to-1_(x+1).sh` script. Skipping releases stays supported for up to 4 minors. |
| **Deprecation contract** | Anything removed in 2.0 must have been deprecated in ≥1 prior minor with a runtime warning. |
| **Release attestation** | Every tag ships with a Cosign-signed SBOM, SLSA L3 provenance, and a signed advisory diff (already in place — 1.0 formalises the SLA). |

## Concrete gate to cut 1.0

Every item below must be `[x]` before tagging `v1.0.0`.

### Code

- [ ] Every `# TODO: extract` in `scripts/qa/shell-surface-allowlist` is either extracted or has an explicit "won't fix" justification.
- [ ] Shell surface ceiling (`--max-total`) in `.github/workflows/reliability-gate.yml` is at or below the 1.0 target (initial target: 950; decrease as consolidations land).
- [ ] `dot doctor` returns 0 on all supported OSes (Ubuntu-latest, macOS-latest, macOS-14) in CI with no warnings above `INFO`.
- [ ] Every `dot <subcommand>` has a completion entry in `share/completions/dot`.
- [ ] Every `dot <subcommand>` has a man-page under `share/man/man1/`.

### Tests

- [ ] Unit-test line coverage ≥ 80 % for `lib/dot/`, `scripts/dot/commands/`, `scripts/ops/`, `scripts/security/`.
- [ ] Regression suite runs against **all** supported platforms in CI, not a subset.
- [ ] Fuzz corpus (`tests/fuzz/`) has ≥ 1 hour of clean runtime per corpus in the last nightly.

### Docs

- [ ] Every subcommand appears in `docs/reference/` with a fixed URL that will not change.
- [ ] Every ADR is one of: **Accepted**, **Superseded**, **Deprecated** — no `Draft`.
- [ ] `docs/GOVERNANCE.md` sections on decision classes and release policy are versioned + dated.
- [ ] `docs/security/POLICY_RELEASES.md` documents the exact support window: 1.x LTS lifespan, security-only maintenance period.

### Release engineering

- [ ] Homebrew, Scoop, AUR, and npm distributions have been validated on a fresh install for the current version.
- [ ] `SECURITY.md` disclosure key has ≥ 12 months until expiry at cut time.
- [ ] All CI workflows use SHA-pinned actions (dependabot alerts clean).
- [ ] OpenSSF Scorecard ≥ 9.0.
- [ ] OpenSSF Best Practices assessment moved from "in progress" to "passing" or higher.

### Compliance / attestation

- [ ] SBOM diff (`sbom-diff.yml`) has run cleanly against the previous release with all changes justified.
- [ ] `docs/security/COMPLIANCE.md` reviewed and current-dated.
- [ ] `.well-known/security.txt` `Expires:` field is > 6 months in the future.

## Sequencing

Roughly:

1. **Now → v0.3.0**: rename current `0.2.x` cadence to a *pre-1.0 stabilisation* line. Freeze CLI surface additions except for closing 1.0 gate items.
2. **v0.3.x**: burn down the "Code" and "Tests" gate items above.
3. **v0.4.0**: docs freeze — every subcommand documented, every ADR resolved.
4. **v0.9.0**: release-engineering freeze — 30-day soak period on all four distribution channels.
5. **v1.0.0**: cut when the gate is `[x]` all the way down.

No timeline is committed here — this is a *definition* of done, not a
schedule. Milestones will be tracked in
[`docs/operations/ROADMAP.md`](ROADMAP.md).

## After 1.0

The `1.x` line is expected to be long-lived (multi-year). Breaking
changes (`2.0.0`) require an RFC in `docs/operations/RFC_v2_0.md`
with at least a 6-month public comment window and a working
migration script committed before the RFC closes.
