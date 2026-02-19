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
- [x] Pin remaining workflows to full commit SHAs.
  - Implemented in:
    - `.github/workflows/nightly.yml`
    - `.github/workflows/update-deps.yml`
    - `.github/workflows/sync-versions.yml`
    - `.github/workflows/npm-publish.yml`
- [x] Enforce cryptographic signature policy for commits in CI (move from advisory to blocking).
  - Implemented in `.github/workflows/compliance-guard.yml`.
- [x] Replace `curl | sh` bootstrap patterns in CI/docs with checksum/signature-verified installers.
  - Implemented in:
    - `.github/workflows/ci.yml`
    - `.github/workflows/nightly.yml`
    - `scripts/ci/install-chezmoi-verified.sh`
    - `docs/INSTALL.md`
    - `scripts/dot/commands/tools.sh`

## P2 (Planned)

- [ ] Add a reusable workflow layer to reduce duplicated security/test logic across workflows.
  - Progress:
    - Added reusable shell lint workflow: `.github/workflows/reusable-shell-lint.yml`.
    - Added reusable secrets scan workflow: `.github/workflows/reusable-secrets-scan.yml`.
    - Wired as a caller in:
      - `.github/workflows/ci.yml` (`Lint / Shell`)
      - `.github/workflows/compliance-guard.yml` (`Portability Shell Lint`)
      - `.github/workflows/ci.yml` (`Security / Secrets Scan`)
      - `.github/workflows/security-enhanced.yml` (`Security / Secrets Detection`)
    - Added workflow-dispatch guard script to prevent accidental full-history gitleaks scans:
      - `scripts/ci/guard-gitleaks-checkout.sh`
- [ ] Pin devcontainer base image by digest and add prebuild automation for Codespaces.
  - Progress:
    - Pinned `.devcontainer/devcontainer.json` image to immutable digest.
    - Added Dependabot `devcontainers` ecosystem updates in `.github/dependabot.yml`.
    - Added automated prebuild workflow in `.github/workflows/devcontainer-prebuild.yml` (GHCR-backed cached image).
    - Added CI-safe config `.devcontainer/devcontainer.ci.json` for non-interactive prebuild runs.
  - Remaining:
    - Optionally configure native Codespaces prebuild settings in repository UI to complement workflow prebuilds.
- [ ] Add attestation verification against release assets as a required status check.
  - Progress: verification gate implemented in `.github/workflows/security-release.yml`.
  - Remaining: enforce this workflow as a required status check in repository branch/rulesets settings.
- [ ] Extend template security baselines for `dot new` (lockfiles, CI defaults, scanning).
  - Progress:
    - `dot new` now applies baseline files: `.editorconfig`, `.gitattributes`, `SECURITY.md`.
    - `dot new` now creates a pinned secret-scanning workflow: `.github/workflows/security.yml`.
    - `dot new` now performs best-effort lockfile generation for Node/Python/Go when tooling is available.
- [ ] Add MCP operations hardening (`dot mcp doctor`, scoped server policies, token checks).
  - Progress:
    - Added `dot mcp doctor` command routed through `scripts/dot/commands/meta.sh`.
    - Added MCP diagnostics script `scripts/diagnostics/mcp-doctor.sh` with JSON/env/scope checks.
    - Added MCP launcher/arg policy checks and required token checks (`GITHUB_TOKEN`, `BRAVE_API_KEY`).
