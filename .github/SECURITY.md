# Security Policy

## Supported Versions

Only the latest version of the dotfiles (main branch) is currently supported with security updates.

| Version | Supported          |
| ------- | ------------------ |
| v0.2.x  | :white_check_mark: |
| < v0.2  | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability within this repository, please report it via GitHub Issues or contact the maintainer directly.

We accept reports for:
- Exposed secrets or credentials.
- Insecure configuration patterns.
- Vulnerabilities in custom scripts.

## Security Measures

This repository employs several automated security measures:

### Static Analysis
- **CodeQL**: Automated security scanning for code vulnerabilities.
- **ShellCheck**: Static analysis for shell scripts to prevent common pitfalls.
- **Codacy**: Automated code quality and security review.

### Permissions
- **Least Privilege**: GitHub Actions workflow permissions are restricted to `contents: read` by default.
- **Secrets Management**: No secrets are stored in plain text. Sensitive data should be managed via a password manager or `chezmoi`'s secret management features.

## Integrity

- All commits are verified.
- Dependency updates are reviewed.
