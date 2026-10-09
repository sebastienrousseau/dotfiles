---
render_with_liquid: false
---

# Automation Secrets

## Required secrets

| Secret | Scope | Purpose |
| :--- | :--- | :--- |
| `ACTIONS_BOT_SIGNING_KEY` | GitHub Actions | SSH private key used for signed automation commits (version sync, dependency updates, Homebrew and Scoop distribution) |
| `TAP_PUSH_TOKEN` | GitHub Actions | Pushes the release formula and manifest to the Homebrew tap and Scoop bucket repositories |
| `AUR_SSH_KEY` | GitHub Actions | SSH key for pushing the `dot-cli-git` package to the AUR |
| `GITHUB_TOKEN` | GitHub Actions | GitHub API access for PRs, attestations, and scans (provided per run) |

npm publishing needs no secret: `npm-publish.yml` uses npm trusted
publishing (GitHub OIDC), so no long-lived npm token is stored.

## Installer checksums

These are pinned in the repository, not stored as secrets or set by hand.

| Pin | Where | Purpose |
| :--- | :--- | :--- |
| Remote installer scripts (`get.chezmoi.io`, Homebrew's `install.sh` at a fixed commit) | [`security/remote-installers.sha256`](https://github.com/sebastienrousseau/dotfiles/blob/main/security/remote-installers.sha256) | `download_verified_script` refuses a script whose SHA-256 does not match |
| Release archives (chezmoi and the provisioned tools) | `versions.env`, `install.sh` and `tools/ci/install-chezmoi-verified.sh` | Each archive is checked against its pinned SHA-256; the release's own checksum file is only a cross-check |
| `CHEZMOI_SHA256` (optional override) | Environment | Supplies the reviewed SHA-256 for a chezmoi version that has no pin yet |

## Provisioning notes

1. Store the SSH signing private key in GitHub Actions as `ACTIONS_BOT_SIGNING_KEY`.
2. Store the matching public key in [allowed_signers](https://github.com/sebastienrousseau/dotfiles/blob/main/defaults/dot_config/git/allowed_signers.tmpl).
3. Rotate the key on personnel or workstation change.
4. Fail closed when secrets are absent.
