---
title: "The .dotfiles Manual"
description: "A trusted agent workstation baseline for macOS, Linux, and WSL."
render_with_liquid: false
---

# The .dotfiles Manual

A trusted agent workstation baseline for macOS, Linux, and WSL. Chezmoi handles templating and platform differences; the `dot` CLI coordinates lifecycle operations on top.

This manual is generated from the Markdown sources in [`docs/manual/`](https://github.com/sebastienrousseau/dotfiles/tree/master/docs/manual) and published in nine formats per release. The HTML edition you are reading is the canonical online version.

## Read it your way

- **Web (multi-page)** — browse the chapters below
- **Single-page HTML, PDF, EPUB, ASCII text** — attached to every [GitHub Release](https://github.com/sebastienrousseau/dotfiles/releases/latest)
- **CLI** — `dot manual` opens the manual locally; `dot manual pdf` downloads the PDF; `dot manual text` pipes the ASCII edition to your pager

## Contents

### [Introduction](00-introduction.md)

The audience, scope, conventions, and where the manual is published.

### Concepts

- [Architecture](01-concepts/01-architecture.md) — repository layout, chezmoi templating, the `dot` dispatcher
- [Trust model](01-concepts/02-trust-model.md) — signing, attestation, SBOM, policy gates
- [Theme engine](01-concepts/03-theme-engine.md) — wallpaper-driven theming across apps
- [Fleet](01-concepts/04-fleet.md) — multi-workstation coordination and drift detection
- [Self-healing](01-concepts/05-self-healing.md) — automatic remediation and rollback

### Tutorials

- [First install](02-tutorials/01-first-install.md)
- [Add a wallpaper-driven theme](02-tutorials/02-add-wallpaper.md)
- [Create an agent profile](02-tutorials/03-create-profile.md)
- [Encrypt a secret](02-tutorials/04-encrypt-secret.md)
- [Deploy to a fleet](02-tutorials/05-deploy-fleet.md)

### Reference

- [`dot` CLI](03-reference/01-dot-cli.md) — every subcommand
- [Config files](03-reference/02-config-files.md) — every `~/.config/dotfiles/*` path
- [Environment](03-reference/03-environment.md) — every variable read by the framework
- [Templates](03-reference/04-templates.md) — every `{{ .var }}` reference
- [Feature flags](03-reference/05-feature-flags.md)

### Cookbook

- [Recipes](04-cookbook/01-recipes.md)
- [Troubleshooting](04-cookbook/02-troubleshooting.md)
- [FAQ](04-cookbook/03-faq.md)

### Appendices

- [A — Platform matrix](05-appendices/A-platform-matrix.md)
- [B — Security checklist](05-appendices/B-security-checklist.md)
- [C — Glossary](05-appendices/C-glossary.md)
- [D — Bibliography](05-appendices/D-bibliography.md)
- [E — License](05-appendices/E-license.md)

### Indexes

- [Concept index](concept-index.md)
- [Command index](command-index.md)
