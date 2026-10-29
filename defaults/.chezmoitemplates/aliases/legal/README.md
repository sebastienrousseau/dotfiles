# Legal & Licensing Aliases

Tools for license scanning, copyright headers and attribution. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `legal.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `fossology-start` | function | Only when `docker` is on PATH. |
| `fossology-stop` | `docker stop fossology && docker rm fossology` | Only when `docker` is on PATH. |
| `scan-licenses` | `scan_licenses_fn` | Scan the current directory for licenses with `trivy`. |
| `add-headers` | `add_headers_fn` | Add license headers with `google/addlicense`, run through Docker. |
| `gen-notice` | `gen_notice_fn` | Generate attribution report for Go projects (expandable to others) |
| `check-cla` | `check_cla_fn` | Check CLA status for the current branch's PR. |

## Requirements

- **Docker** for `fossology-start`, `add-headers` and `gen-notice`.
- **GitHub CLI (`gh`)** for `check-cla`.
- **Trivy** for `scan-licenses` (on macOS it is installed with Homebrew when missing).

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
