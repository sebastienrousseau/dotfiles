---
render_with_liquid: false
title: "Dot Module Registry"
description: "How to publish and consume reusable dotfile modules."
---

# Dot Module Registry

The `dot registry` command discovers reusable dotfile modules from a JSON index published over HTTPS. The default registry is hosted by this repo at:

```
https://sebastienrousseau.github.io/dotfiles/registry.json
```

This page documents the JSON contract and the contribution flow. It is the §3 / Months 12-18 deliverable from [HARD_AUDIT_2026.md](./HARD_AUDIT_2026.md) — the registry is the network-effect feature that turns the framework into a category, not just one person's setup.

## Quick start (consumer side)

```sh
dot registry list                   # list every published module
dot registry search rust            # filter by keyword
dot registry info rust-dev-setup    # full metadata for one module
dot registry install rust-dev-setup # apply to this workstation (scaffold)
dot registry url                    # show active registry URL
dot registry set-url <url>          # point at a different registry
```

The registry index is cached locally at `${XDG_CACHE_HOME:-~/.cache}/dotfiles/registry/index.json` with a 6 hour TTL. Override the URL one-off via `DOTFILES_REGISTRY_URL=<url> dot registry list`.

## JSON contract

A registry index is a single JSON document:

```json
{
  "version": 1,
  "updated": "2026-05-15T16:30:00Z",
  "registry": "sebastienrousseau/dotfiles",
  "modules": [
    {
      "name": "rust-dev-setup",
      "description": "Rust toolchain + cargo plugins + Helix/Neovim editor config",
      "repo": "https://github.com/example/rust-dev-setup",
      "version": "1.2.0",
      "tags": ["rust", "language", "dev"],
      "maintainer": "alice@example.com",
      "sha256": "f9a2c1b…",
      "license": "MIT"
    }
  ]
}
```

Required keys: `name` (kebab-case, ≤ 32 chars), `description` (≤ 200 chars), `repo` (HTTPS clone URL), `version` (semver).

Recommended keys: `tags` (lower-case array), `maintainer`, `sha256` (pinned at publish time so installers can verify), `license` (SPDX identifier).

## Contributing a module

1. Build your module as a chezmoi-source-compatible directory at `https://github.com/<you>/<module>.git`. The contents are overlaid onto the consumer's chezmoi source dir during install.
2. Open a PR against `sebastienrousseau/dotfiles` adding one entry to `docs/registry.json` (alphabetical by `name`).
3. The PR runs CI checks for:
   - Schema validity (`jq` against the JSON contract).
   - `repo` URL resolves and is a public git repo.
   - `sha256` matches the latest tag at `repo`.
4. Once merged, the GitHub Pages workflow re-deploys the registry; `dot registry list` picks it up within 6 hours (or immediately if the consumer purges the cache).

## Install pipeline (scaffold today, full in Phase 2)

`dot registry install <name>` currently prints what *would* happen. The full pipeline lands as follows:

1. Resolve the module entry from the registry index.
2. Clone the module to `$XDG_DATA_HOME/dotfiles/modules/<name>/<version>`.
3. Verify the clone's HEAD matches `sha256` from the registry.
4. Source the module's `module.toml` (if present) for declared profiles + feature flags.
5. Merge the module's chezmoi source into the consumer's chezmoi source dir under a namespaced subtree (`/registry/<name>/...`).
6. Run `chezmoi apply --include /registry/<name>/**` so only the module's files are written.

The sandboxed apply (point 6) requires changes to `dot sync` to accept an include filter — that is its own roadmap issue and tracked separately.

## Security model

- Modules execute with the consumer's user privileges via chezmoi `run_onchange_*` scripts. The trust contract is identical to consuming any third-party dotfiles repo.
- Pinning `sha256` lets a consumer verify the registry entry hasn't been tampered with between publish and install.
- The registry index itself is fetched over HTTPS; the GitHub Pages cert chain provides transport integrity.

## Why this lives in this repo (for now)

A vendor-neutral registry would be ideal but adds operations cost. Hosting `registry.json` under this repo's `docs/` directory and serving it via GitHub Pages keeps the maintenance burden near zero while the registry is small. If/when the registry outgrows GitHub Pages, the JSON contract is stable and the index can move to a dedicated subdomain.
