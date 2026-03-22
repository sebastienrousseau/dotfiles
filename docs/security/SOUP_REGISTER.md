# SOUP Register

## Purpose

Controlled inventory for software of unknown pedigree used by the dotfiles platform.

## Active components

| Component | Source | Version control | Verification path | Owner | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Homebrew installer | `raw.githubusercontent.com/Homebrew/install` | Moving upstream script, gated by `HOMEBREW_INSTALLER_SHA256` | SHA-256 in [package_managers.sh](/home/seb/.dotfiles/install/lib/package_managers.sh) | Repo maintainer | Conditional |
| Chezmoi installer | `get.chezmoi.io` | Pinned by `CHEZMOI_INSTALLER_SHA256` when used | SHA-256 in `install/lib/chezmoi.sh` | Repo maintainer | Controlled |
| GitHub Actions marketplace actions | GitHub Marketplace | Full commit SHA pinning | Workflow `uses:` pins | Repo maintainer | Controlled |
| Grype container | `anchore/grype` | Pinned tag in workflow | Container tag in [security-enhanced.yml](/home/seb/.dotfiles/.github/workflows/security-enhanced.yml) | Repo maintainer | Controlled |
| Trivy container | `aquasec/trivy` | Pinned tag in workflow | Container tag in [security-enhanced.yml](/home/seb/.dotfiles/.github/workflows/security-enhanced.yml) | Repo maintainer | Controlled |
| Checkov action | GitHub Marketplace | Full commit SHA pinning | Workflow `uses:` pin | Repo maintainer | Controlled |
| Nix inputs | GitHub flakes | Locked in [flake.lock](/home/seb/.dotfiles/flake.lock) | `narHash` and revision lock | Repo maintainer | Controlled |
| GitHub release metadata queries | GitHub API | Discovery only, not release validation | `update-deps.yml` query path | Repo maintainer | Monitored |

## Validation record

1. Record version or commit SHA.
2. Record checksum, signature, or attestation method.
3. Record workflow or script that consumes the component.
4. Record owner and review date.
5. Reject moving inputs in production or release paths unless checksum-gated.

## Exit criteria

- No unsigned automation commits.
- No unverified executable download in installer or release path.
- Every SOUP item has owner, version control method, and validation record.
