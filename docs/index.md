---
title: .dotfiles — dark, signed, cross-platform
description: Cross-platform, signed, local-first dotfiles for macOS, Linux, and WSL.
hide:
  - navigation
  - toc
render_with_liquid: false
---

<section class="dot-hero" markdown>

# .dotfiles

<p class="tagline">Cross-platform, signed, local-first dotfiles for macOS, Linux, and WSL — multi-shell parity (bash/zsh/fish/nushell), a fast <code>dot</code> CLI, wallpaper-driven themes, SLSA-signed releases, and AI/MCP-aware tooling.</p>

<div class="buttons">
  <a class="primary" href="guides/INSTALL/">Install →</a>
  <a href="https://github.com/sebastienrousseau/dotfiles">GitHub</a>
  <a href="reference/UTILS/">Utilities</a>
  <a href="architecture/ARCHITECTURE/">Architecture</a>
</div>

</section>

## What's inside

<div class="grid cards" markdown>

- :material-console:{ .lg .middle } **Multi-shell parity**

    ---

    Bash, Zsh, Fish, Nushell — same aliases, functions, prompt, and completions. Cross-shell env parity from `.chezmoidata.toml`.

    [→ Shell hub](reference/UTILS.md)

- :material-lock-check:{ .lg .middle } **Signed & attested**

    ---

    Every commit SSH-signed, DCO enforced, SLSA-signed releases, SBOM + CVE gate, secret encryption via age.

    [→ Security](operations/ATTESTATION.md)

- :material-palette:{ .lg .middle } **190 wallpaper-driven themes**

    ---

    K-Means CIELAB color extraction. Terminal, editor, DE — all follow the wallpaper. `dot theme rebuild --force` regenerates from `~/Pictures/Wallpapers/`.

    [→ Theme system](reference/UTILS.md)

- :material-rocket-launch:{ .lg .middle } **Fast `dot` CLI**

    ---

    142+ subcommands: apply, health, doctor, heal, ai, agent, fleet, secrets, teleport, uninstall — with fzf pickers and a Bubble Tea cockpit.

    [→ CLI reference](reference/UTILS.md)

- :material-check-decagram:{ .lg .middle } **CI you can trust**

    ---

    35+ checks — shellcheck, shfmt, luacheck, stylua, CodeQL, Snyk, grype/SBOM, deps.dev, doc-drift gate, examples contract at 100%.

    [→ Operations](operations/OPERATIONS.md)

- :material-earth:{ .lg .middle } **Cross-platform**

    ---

    macOS (Intel & Apple Silicon), Linux (Ubuntu, Fedora, Arch, Alpine, openSUSE), WSL, PowerShell 7.5+, real BSDs.

    [→ Support matrix](reference/SUPPORT_MATRIX.md)

- :material-brain:{ .lg .middle } **AI & MCP aware**

    ---

    18-agent fleet cockpit (`dot ai`), local Claude gateway, MCP registry, context patterns, provider secrets — first-class support, not bolted on.

    [→ AI operations](AI.md)

- :material-account-cog:{ .lg .middle } **Chezmoi under the hood**

    ---

    Deterministic templates, feature flags, profiles, `run_onchange_` hooks. Everything lives in `defaults/` and applies to `$HOME` on-demand.

    [→ Architecture](architecture/ARCHITECTURE.md)

</div>

## Quick start

Install onto a fresh machine:

=== "macOS / Linux / WSL"

    ```bash
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh)"
    ```

=== "Windows (PowerShell 7+)"

    ```powershell
    iwr -useb https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.ps1 | iex
    ```

Once installed:

    dot doctor      # verify state
    dot health      # dashboard with actionable warnings
    dot ai          # launch the AI cockpit (Bubble Tea TUI)
    dot theme       # pick a wallpaper-driven theme
    dot help all    # full CLI reference

## Where to next

- [**Install guide**](guides/INSTALL.md) — full bootstrap walkthrough, per-platform.
- [**Utilities & `dot` CLI**](reference/UTILS.md) — every subcommand with examples.
- [**Architecture**](architecture/ARCHITECTURE.md) — how the layers fit together.
- [**Trusted agent workstation**](operations/TRUSTED_AGENT_WORKSTATION.md) — hardening + attestation runbook.
- [**Troubleshooting**](guides/TROUBLESHOOTING.md) — the common gotchas.
- [**Support matrix**](reference/SUPPORT_MATRIX.md) — OS × shell × package-manager grid.
- [**Security overview**](security/SECURITY.md) — signing, attestation, secret handling, threat model.

## Current release

- Release feed: [GitHub releases](https://github.com/sebastienrousseau/dotfiles/releases/latest)
- Source: [sebastienrousseau/dotfiles](https://github.com/sebastienrousseau/dotfiles)
