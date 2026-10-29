# Compliance Aliases

Tools for privacy settings and the configuration audit trail. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `compliance.aliases.sh`. Loaded by the eager alias layer `~/.config/shell/90-ux-aliases.sh` (a core category).

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `privacy-mode` | `privacy_mode_fn` | Export the telemetry opt-out variables of .NET, Homebrew, Azure, Azure Functions, AWS SAM, Stripe, Gatsby and Next.js in the current shell. |
| `dot-audit` | `audit_fn` | Show the last 20 lines of the dot CLI's log, `${XDG_STATE_HOME:-~/.local/state}/dotfiles/dot.log`, or the last 10 commits of `~/.dotfiles` when that log is missing. |

See [COMPLIANCE.md](../../../../docs/security/COMPLIANCE.md) for the controls these support.

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
