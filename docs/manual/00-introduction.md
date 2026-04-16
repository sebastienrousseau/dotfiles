# Introduction

This manual describes `.dotfiles` v0.2.500 — a trusted agent workstation baseline for macOS, Linux, and WSL.

The repository is more than a personal dotfiles collection. It ships as workstation infrastructure: signed, attested, multi-platform, AI-aware, and self-healing. Chezmoi handles templating and platform differences. The `dot` CLI sits on top and coordinates lifecycle operations.

## Who This Manual Is For

- **Developers** who want a reproducible, signed development environment across machines
- **Security engineers** who require cryptographic attestation, SBOM, and policy gates
- **AI agent operators** running Claude Code, Codex, GitHub Copilot, or MCP-aware tooling
- **Team leads** deploying standardized workstations across a fleet

The content assumes basic familiarity with Git, shell environments, and chezmoi. No prior knowledge of the specific tools used (Mise, Nix, Age, SOPS, MCP) is required.

## What the Manual Covers

- **Concepts** — the mental model behind the theme engine, trust model, fleet architecture, and self-healing
- **Tutorials** — step-by-step walkthroughs for common tasks
- **Reference** — every `dot` command, every config file, every template variable, every feature flag
- **Cookbook** — 30+ specific recipes for day-to-day tasks and troubleshooting
- **Appendices** — platform support matrix, security checklist, glossary, bibliography

## Getting the Manual

The manual is published in nine formats — all generated from the same Markdown source on every release:

| Format | Size | Use case |
|:---|---:|:---|
| HTML (single page) | ~200K | Offline browsing |
| HTML (multi-page) | — | Web reading |
| HTML gzipped (single) | ~50K | Fast download |
| EPUB | ~150K | E-readers |
| PDF | ~400K | Printing |
| ASCII text | ~120K | Terminal pagers |
| Markdown source | ~80K | Re-processing |

Published at: `https://sebastienrousseau.github.io/dotfiles/manual/`

Fetch from the CLI:

```sh
dot manual           # open in browser
dot manual pdf       # download and open PDF
dot manual text      # pipe plain text to pager
```

## Quick Install

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/install.sh)"
dot doctor
```

Requires `git` and `curl`. Supported on macOS 14+, Ubuntu/Debian, Arch, Fedora, openSUSE, and WSL2.

## Conventions Used in This Manual

| Convention | Meaning |
|:---|:---|
| `fixed-width` | Commands, file paths, environment variables |
| **Bold** | Important terms introduced for the first time |
| > Note: | Supplementary information |
| > Warning: | Actions with potentially destructive effects |

Command placeholders use `<angle-brackets>`. Optional arguments use `[brackets]`. Repeated arguments end with `...`.

## How to Read This Manual

- **First-time users** — read [Introduction](#introduction), [First Install](02-tutorials/01-first-install.md), then browse the [Cookbook](04-cookbook/01-recipes.md).
- **Upgrading** — read the [Migration section](../operations/MIGRATION.md) for your version delta.
- **Deep diving** — the [Concepts](01-concepts/) chapters explain the architecture and rationale.
- **Looking something up** — use the [Command Index](command-index.md) or [Concept Index](concept-index.md).

## Licensing

The `.dotfiles` repository is licensed under the MIT License. See [Appendix E](05-appendices/E-license.md) for the full text.

Individual tools packaged, referenced, or templated by this repository retain their original licenses.

## Reporting Issues

- **Bugs and feature requests** — <https://github.com/sebastienrousseau/dotfiles/issues>
- **Security vulnerabilities** — see [Security Policy](../security/SECURITY.md); do not open public issues for unpatched vulnerabilities
- **Documentation corrections** — open a pull request against `docs/manual/` on the `master` branch
