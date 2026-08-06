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
dot registry install rust-dev-setup # verify and preview changes
dot registry install rust-dev-setup --yes # verify, persist, and apply
dot registry installed              # list locally installed modules
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
      "archive_url": "https://example.com/rust-dev-setup-1.2.0.tar.gz",
      "sha256": "f9a2c1b0a8d27c41b99c8c93641a0d476a0e54b23161847c47c780025ac7c4a1",
      "license": "MIT"
    }
  ]
}
```

Required keys: `name` (kebab-case, no more than 32 characters), `description` (no more than 200 characters), `version` (semver), `archive_url` (immutable HTTPS archive), and `sha256` (64 lowercase hexadecimal characters).

Optional keys: `repo` (HTTPS project URL), `tags` (lower-case array), `maintainer`, and `license` (SPDX identifier). The machine-readable contract is [`docs/schema/dot-registry-v1.json`](../schema/dot-registry-v1.json).

## Contributing a module

1. Build a gzip-compressed tar archive containing a chezmoi-source-compatible directory. Publish it at an immutable HTTPS URL, such as a versioned GitHub release asset.
2. Open a PR against `sebastienrousseau/dotfiles` adding one entry to `docs/registry.json` (alphabetical by `name`).
3. The PR runs CI checks for:
   - Runtime contract validity and unique, sorted module names.
   - Valid JSON for both the index and its published JSON Schema.
   - A pinned SHA-256 digest for every archive.
4. Once merged, the GitHub Pages workflow re-deploys the registry; `dot registry list` picks it up within 6 hours (or immediately if the consumer purges the cache).

## Install pipeline

`dot registry install <name>` is preview-first and does not mutate the workstation. Pass `--yes` only after reviewing the chezmoi dry-run. The installer:

1. Resolve the module entry from the registry index.
2. Download the versioned archive using HTTPS and TLS 1.2 or newer.
3. Verify the archive against the registry's SHA-256 digest.
4. Reject absolute paths, parent traversal, symbolic links, and hard links before extraction.
5. Run `chezmoi apply --dry-run` against the isolated module source.
6. With `--yes`, persist it at `${XDG_DATA_HOME:-~/.local/share}/dotfiles/modules/<name>/<version>` and apply that exact verified source.

## Security model

- Modules execute with the consumer's user privileges via chezmoi scripts. Review the default dry-run and publisher before passing `--yes`.
- The SHA-256 pin binds installation to the reviewed archive bytes, even if the hosting release later changes.
- The registry index itself is fetched over HTTPS; the GitHub Pages cert chain provides transport integrity.

## Why this lives in this repo (for now)

A vendor-neutral registry would be ideal but adds operations cost. Hosting `registry.json` under this repo's `docs/` directory and serving it via GitHub Pages keeps the maintenance burden near zero while the registry is small. If/when the registry outgrows GitHub Pages, the JSON contract is stable and the index can move to a dedicated subdomain.
