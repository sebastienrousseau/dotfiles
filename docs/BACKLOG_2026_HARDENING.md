# 2026 Hardening Backlog

This backlog tracks repo-level security and platform hardening work aligned with 2026 engineering trends.

## P0 (Do Now)

- [x] Add `merge_group` support to required workflows so merge queue executes mandatory checks.
  - Implemented in:
    - `.github/workflows/ci.yml`
    - `.github/workflows/codeql.yml`
    - `.github/workflows/security-enhanced.yml`
    - `.github/workflows/compliance-guard.yml`
    - `.github/workflows/cross-platform-test.yml`
- [x] Expand Dependabot coverage beyond GitHub Actions to include `npm` and `docker`.
  - Implemented in `.github/dependabot.yml` with grouped updates and limits.
- [x] Add release integrity verification for SBOM + provenance asset presence.
  - Implemented in `.github/workflows/security-release.yml` (`verify-release-integrity` job).

## P1 (Next)

- [x] Pin third-party GitHub Actions to full commit SHAs in core required workflows.
  - Implemented in:
    - `.github/workflows/ci.yml`
    - `.github/workflows/security-enhanced.yml`
    - `.github/workflows/security-release.yml`
    - `.github/workflows/codeql.yml`
    - `.github/workflows/compliance-guard.yml`
    - `.github/workflows/cross-platform-test.yml`
- [ ] Pin remaining workflows to full commit SHAs.
  - Scope:
    - `.github/workflows/nightly.yml`
    - `.github/workflows/update-deps.yml`
    - `.github/workflows/sync-versions.yml`
    - `.github/workflows/npm-publish.yml`
- [x] Enforce cryptographic signature policy for commits in CI (move from advisory to blocking).
  - Implemented in `.github/workflows/compliance-guard.yml`.
- [ ] Replace `curl | sh` bootstrap patterns in CI/docs with checksum/signature-verified installers.
  - Scope:
    - `.github/workflows/ci.yml`
    - `.github/workflows/nightly.yml`
    - `docs/INSTALL.md`
    - `scripts/dot/commands/tools.sh`

## P2 (Planned)

- [ ] Add a reusable workflow layer to reduce duplicated security/test logic across workflows.
- [ ] Pin devcontainer base image by digest and add prebuild automation for Codespaces.
- [ ] Add attestation verification against release assets as a required status check.
- [ ] Extend template security baselines for `dot new` (lockfiles, CI defaults, scanning).
- [ ] Add MCP operations hardening (`dot mcp doctor`, scoped server policies, token checks).
