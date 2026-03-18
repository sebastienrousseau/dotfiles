# Automation Secrets

## Required secrets

| Secret | Scope | Purpose |
| :--- | :--- | :--- |
| `ACTIONS_BOT_SIGNING_KEY` | GitHub Actions | SSH private key used for signed automation commits |
| `GITHUB_TOKEN` | GitHub Actions | GitHub API access for PRs, attestations, and scans |

## Required local variables

| Variable | Scope | Purpose |
| :--- | :--- | :--- |
| `HOMEBREW_INSTALLER_SHA256` | macOS bootstrap | Verifies the Homebrew installer before execution |
| `CHEZMOI_INSTALLER_SHA256` | Installer | Verifies the Chezmoi installer before execution |

## Provisioning notes

1. Store the SSH signing private key in GitHub Actions as `ACTIONS_BOT_SIGNING_KEY`.
2. Store the matching public key in [allowed_signers](/home/seb/.dotfiles/dot_config/git/allowed_signers).
3. Rotate the key on personnel or workstation change.
4. Fail closed when secrets are absent.
