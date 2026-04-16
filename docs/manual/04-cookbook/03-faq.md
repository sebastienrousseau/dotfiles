# Cookbook: Frequently Asked Questions

## General

### Why should I use this over stow, yadm, or a plain Git repo?

Because it's not just a dotfiles manager. It's a workstation baseline with:

- Cryptographic attestation
- AI/MCP policy enforcement
- Wallpaper-driven theme engine (WCAG AAA)
- Self-healing + chaos testing
- Fleet management
- Per-platform rendering via chezmoi templates

If you only need to symlink `.bashrc`, use stow. If you're operating a fleet of signed, attested, AI-aware workstations, use this.

### Does it work on Windows?

Only via WSL2. Native Windows PowerShell support exists for baseline parity (aliases, prompt), but the full feature set (chezmoi, Mise, theme engine) requires WSL2.

### Is it production-ready?

Yes — it's the author's daily driver across multiple hosts and receives regular releases (see `CHANGELOG.md`). CI enforces 100% test coverage, zero-warning linting, WCAG AAA for themes, SBOM + CVE scanning, and signed commits on every merge.

### Can I fork it and use it without attribution?

Yes — MIT License. Attribution is appreciated but not required.

## Themes

### Why K-Means in CIELAB instead of RGB?

CIELAB distances approximate human perception. A Δ in RGB might look identical to your eye in one part of the color space and very different in another. Clustering in Lab produces palettes where "close" colors actually look close. See [Theme Engine](../01-concepts/03-theme-engine.md).

### Why not pre-built themes like Catppuccin or Rosé Pine?

Two reasons:
1. **Maintenance** — 100+ themes × 20+ applications = thousands of template variables to keep in sync. Generation from wallpapers eliminates that.
2. **User agency** — users bring their own wallpapers. The theme adapts to them, not the other way around.

The engine can still produce Catppuccin-like output: give it a Catppuccin wallpaper and you get Catppuccin-aligned terminal colors.

### Does it ship wallpapers?

No. Apple/Microsoft/distro-vendor wallpapers are copyrighted. The repo discovers wallpapers that are already on the user's system (at `~/Pictures/Wallpapers/` or the OS's system wallpaper directory). Users bring their own images.

### How do I control the accent color?

You don't directly — the accent hue is extracted from the wallpaper. But `_compute_accent()` picks the most chromatic cluster, then darkens it until white text meets 7:1 contrast. If you want a specific accent, choose a wallpaper with that hue dominant.

### Can I use my own theme without a wallpaper?

Not directly — the engine expects a source image. You could:
1. Pick a wallpaper whose palette you want
2. Let the engine generate the theme
3. Lock the generated `.toml` entry by copying to a non-regenerated path

But this defeats the point. If you have a specific palette in mind, generate a solid-color or gradient image with those colors and use that.

## Secrets

### Why Age instead of GPG?

GPG is notoriously complex. Age is simpler, uses modern crypto (X25519 + ChaCha20-Poly1305), and has no legacy baggage. It's the tool [SOPS recommends](https://github.com/getsops/sops#encrypting-using-age).

### Why commit encrypted secrets at all?

- **Traceable** — Git history shows when secrets changed
- **Auditable** — ciphertext is testable without decryption
- **Portable** — clone the repo anywhere, decrypt with your key
- **No external dependency** — no Vault/AWS Secrets Manager/etc.

The alternative (storing secrets outside the repo) creates sync headaches across fleet hosts. Encrypted-at-rest-in-repo is simpler and just as secure if keys are managed correctly.

### What if I lose my Age private key?

You lose access to all secrets encrypted only for that key. Recovery requires another recipient (another host with a valid key) to decrypt and re-encrypt. This is why fleet setups should use multiple recipients — see [Deploy to Fleet](../02-tutorials/05-deploy-fleet.md).

## AI & Agents

### Does this require an API key?

No. The AI tools (Claude Code, Codex, Copilot) are installed but require their own authentication. `dot ai` shows what's present without invoking any remote service.

### What is MCP?

The [Model Context Protocol](https://modelcontextprotocol.io/) is a standard for connecting AI models to tools and data sources. `.dotfiles` includes policy enforcement for MCP-aware agents: allowlists, attestation, and signed registries. See [Trust Model](../01-concepts/02-trust-model.md).

### Can I add my own agent profile?

Yes. Drop a Markdown file in `dot_config/ai/patterns/`. Each file describes a profile (architect, hardener, etc.). `dot mode <name>` switches between them.

## Fleet

### How many hosts can I manage?

No hard limit. The `dot fleet` commands SSH sequentially by default, so large fleets (>20 hosts) benefit from parallel invocation. For industrial scale, pair with Ansible/Nix/Puppet; `.dotfiles` handles the user-level config, not system administration.

### Do I need a central server?

No. Everything is Git-based. No central orchestration service, no daemon. Each host pulls independently.

### Can two hosts have different themes?

Yes. Each host's `~/.config/chezmoi/chezmoi.toml` can set its own `theme`. This is per-host override — not shared in the repo.

## Performance

### Why is my shell startup 800ms when the budget is 500ms?

Check what's loaded:

```sh
DOTFILES_DEBUG=1 zsh -i -c exit 2>&1 | grep -E '\[debug [0-9]+ms\]'
```

Common culprits:
- nvm loading Node on every shell (use lazy loading)
- `mise activate` with aggressive hook-env (set `activate_aggressive = false`)
- Plugin manager scanning for updates

Run `dot benchmark --detailed` to attribute cost.

### Can I disable prewarming?

Yes — but your cold shell startup will be slow. Remove the prewarm invocation from your shell profile or skip `dot prewarm` after apply.

## Troubleshooting Community

### Where do I report bugs?

GitHub issues: <https://github.com/sebastienrousseau/dotfiles/issues>. Include output of `dot doctor --json` and your platform.

### Where do I ask usage questions?

GitHub discussions, or mention in the issue you open. The maintainer responds best to issues with clear repro steps.

### Is there a Discord / Slack?

Not currently.

## Philosophy

### Why so much emphasis on attestation?

Because AI agents operating on your workstation can do anything you can. Attestation is the audit trail — who ran what, when, with which policy. Without it, agent operations are black boxes.

### Why MIT License?

To maximize adoption and contribution. MIT is compatible with commercial use; copyleft alternatives would restrict who can use the code.

### Why no GUI configurator?

Text + Git is the optimal interface for a workstation baseline:
- Versioned (Git history)
- Reproducible (same input → same output)
- Auditable (diff-able)
- Scriptable (any `dot` command can be invoked programmatically)

A GUI adds complexity without benefit over editing `.chezmoidata.toml` directly.

## See Also

- [Troubleshooting](02-troubleshooting.md)
- [Recipes](01-recipes.md)
- [GitHub Discussions](https://github.com/sebastienrousseau/dotfiles/discussions)
