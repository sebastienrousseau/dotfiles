---
render_with_liquid: false
title: "Dot Module Registry"
description: "How to publish and consume reusable dotfile modules."
---

# Dot Module Registry

The `dot registry` command discovers reusable dotfile modules from a JSON index published over HTTPS. The default registry is hosted by this repo at:

```
https://doc.dotfiles.io/registry.json
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

The registry index is cached locally under `${XDG_CACHE_HOME:-~/.cache}/dotfiles/registry/` with a 6 hour TTL, in a file named for the URL it was fetched from (`index-v2-<digest>.json`) so changing the registry URL never serves the previous registry's index. When a fetch fails, a cached index is used only while it is younger than 7 days. Override the URL one-off via `DOTFILES_REGISTRY_URL=<url> dot registry list`.

Every fetched index must carry a minisign signature at `<url>.minisig` that verifies against `security/registry.pub` in this repository; an index without one is refused. `DOTFILES_REGISTRY_PUBKEY=<file>` verifies against another key (a private registry). For local development only, `DOTFILES_REGISTRY_UNSIGNED=1` lets a `file://` index skip verification, with a warning; it never applies to `https://`.

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

1. Build a gzip-compressed tar archive containing a chezmoi-source-compatible directory of plain files. Templates (`*.tmpl`), scripts (`run_*`), `.chezmoi*` files and the `exact_`, `remove_`, `create_`, `modify_`, `symlink_`, `encrypted_` and `external_` attributes are refused anywhere in the tree, as are links and absolute or `..` paths. Publish it at an immutable HTTPS URL, such as a versioned GitHub release asset.
2. Open a PR against `sebastienrousseau/dotfiles` adding one entry to `docs/registry.json` (alphabetical by `name`).
3. The PR runs CI checks for:
   - Runtime contract validity and unique, sorted module names.
   - Valid JSON for both the index and its published JSON Schema.
   - A pinned SHA-256 digest for every archive.
4. The maintainer re-signs the index offline (`minisign -Sm docs/registry.json -s <offline key>`) and commits `docs/registry.json.minisig`. CI (`tools/ci/check-registry.sh`) fails when the committed signature does not match the index.
5. Once merged, the GitHub Pages workflow re-deploys the registry; `dot registry list` picks it up within 6 hours (or immediately if the consumer purges the cache).

## Install pipeline

`dot registry install <name>` is preview-first and does not mutate the workstation. Pass `--yes` only after reviewing the preview. The installer:

1. Verify the index signature, schema and freshness, then resolve the module entry.
2. Download the versioned archive using HTTPS and TLS 1.2 or newer (an `https://` index may only name `https://` archives).
3. Verify the archive against the registry's SHA-256 digest.
4. Reject absolute paths, parent traversal, symbolic links, hard links and every chezmoi-active name before extraction.
5. Preview without chezmoi: the archive listing, then `diff -u` against each file that already exists in `$HOME`.
6. With `--yes`, persist it at `${XDG_DATA_HOME:-~/.local/share}/dotfiles/modules/<name>/<version>` and apply that exact verified source with `chezmoi apply --config /dev/null --config-format toml` and a throwaway persistent state and cache, so your chezmoi config, hooks, data and script history are never involved. `installed.json` records every target path the module wrote.

## Security model

- Modules never execute: only plain files are accepted, and they are written with your user privileges. Review the preview and publisher before passing `--yes`.
- The SHA-256 pin binds installation to the reviewed archive bytes, even if the hosting release later changes.
- The index is signed with an offline minisign key; its public half is `security/registry.pub`. HTTPS adds transport confidentiality, not trust.
- Rollback: the newest `updated` timestamp ever accepted per registry URL is kept under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/registry/`, and an older (or undated) index is refused.
- Registry text (descriptions, maintainers, tags) is stripped of control characters before it is printed.

## Why this lives in this repo (for now)

A vendor-neutral registry would be ideal but adds operations cost. Hosting `registry.json` under this repo's `docs/` directory and serving it via GitHub Pages keeps the maintenance burden near zero while the registry is small. If/when the registry outgrows GitHub Pages, the JSON contract is stable and the index can move to a dedicated subdomain.
