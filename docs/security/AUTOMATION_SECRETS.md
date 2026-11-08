---
render_with_liquid: false
---

# Automation Secrets

## Required secrets

| Secret | Scope | Purpose |
| :--- | :--- | :--- |
| `TAP_PUSH_TOKEN` | GitHub Actions | Commits the release formula and manifest to the Homebrew tap and Scoop bucket repositories through the API, and opens their PRs |
| `AUR_SSH_KEY` | GitHub Actions | SSH key for pushing the `dot-cli-git` package to the AUR |
| `GITHUB_TOKEN` | GitHub Actions | GitHub API access for PRs, attestations, and scans (provided per run) |
| `SCORECARD_TOKEN` (optional, not set today) | GitHub Actions | Fine-grained PAT with `Administration: read` so `scorecard.yml` can read branch protection; the workflow falls back to `GITHUB_TOKEN` (see [SCORECARD.md](SCORECARD.md)) |

npm publishing needs no secret: `npm-publish.yml` uses npm trusted
publishing (GitHub OIDC), so no long-lived npm token is stored.

## Installer checksums

These are pinned in the repository, not stored as secrets or set by hand.

| Pin | Where | Purpose |
| :--- | :--- | :--- |
| Remote installer scripts (`get.chezmoi.io`, Homebrew's `install.sh` at a fixed commit) | [`security/remote-installers.sha256`](https://github.com/sebastienrousseau/dotfiles/blob/main/security/remote-installers.sha256) | `download_verified_script` refuses a script whose SHA-256 does not match |
| Release archives (chezmoi and the provisioned tools) | `defaults/dot_config/dotfiles/versions.env`, `install.sh` and `tools/ci/install-chezmoi-verified.sh` | Each archive is checked against its pinned SHA-256; the release's own checksum file is only a cross-check |
| `CHEZMOI_SHA256` (optional override) | Environment | Supplies the reviewed SHA-256 for a chezmoi version that has no pin yet |

## Provisioning notes

1. No workflow signs commits in the runner. Version sync, dependency
   updates and the Homebrew and Scoop bumps commit through the API
   (`tools/ci/commit-via-api.sh`, `tools/ci/bump-branch-via-api.sh`), and
   GitHub signs each commit, so it passes the rules that require signed
   commits here, on the tap and on the bucket.
2. Rotate `TAP_PUSH_TOKEN` and `AUR_SSH_KEY` on personnel or workstation change.
3. Fail closed when secrets are absent.
