# mise-plugin-dot

A [mise](https://mise.jdx.dev) plugin that installs and manages the `dot` CLI from any chezmoi-managed dotfiles repository — including [sebastienrousseau/dotfiles](https://github.com/sebastienrousseau/dotfiles) — through a single one-liner.

## What it does

```sh
mise install dot@latest                          # the maintainer's reference repo
mise install dot@sebastienrousseau/dotfiles      # explicit owner/repo
mise install dot@v0.2.539                        # pinned tag
mise install dot@alice/cfg                       # any user's dotfiles
mise use -g dot@v0.2.539                         # set globally
```

`mise install dot@<tag>` works for releases that ship the `dot-<version>.tar.gz` and `dot-<version>.SHA256SUMS` assets (0.2.520 and later). Older tags fail with a pointer to the supported installers.

## Status

**Vendored, not yet in the mise registry.** This is a copy of the planned `sebastienrousseau/mise-plugin-dot` external repo. Until it is extracted and registered, add it by path: `mise plugin add dot /path/to/dotfiles/examples/mise-plugin-dot`.

There is no `bin/uninstall`. Once the plugin is extracted to its own repo with a PR to [`mise-en-place/registry`](https://mise.jdx.dev/registry.html), `mise install dot@<spec>` becomes a one-line install for any user on any platform mise supports.

This vendored copy exists so:

1. The plugin code lives under version control alongside the framework it bootstraps.
2. Anyone can try the plugin locally before the registry PR lands: `mise plugin add dot /path/to/dotfiles/examples/mise-plugin-dot`.
3. The plugin's contract (binary downloads, version detection, env exports) is reviewable in the same PR as the framework changes that need it.

## Plugin contract

`bin/list-all` — echo every installable version, newest first. Reads the upstream GitHub releases API.

`bin/install`: install a given version to `$ASDF_INSTALL_PATH` / `$MISE_INSTALL_PATH`. It needs `curl`, `tar`, `make` and `sha256sum` or `shasum`. Two paths:

- **Tagged release** (`mise install dot@v0.2.539`): download the `dot-<version>.tar.gz` release asset, verify it against `dot-<version>.SHA256SUMS` (a missing or mismatched checksum stops the install), then run the archive's `make install PREFIX=<install path>`.
- **owner/repo shorthand** (`mise install dot@alice/cfg`): run `dot config init alice/cfg --no-apply` into a private source and chezmoi config directory, then `make install PREFIX=<install path>` from the clone. Nothing is applied, and your own chezmoi source and config are not touched. `dot` must already be on `PATH`, `dot config init` asks you on the terminal to trust the repository, and the repository must carry the `dot` CLI (a `GNUmakefile` with an `install` target); otherwise the install fails and says so.

`bin/exec-env` — export `DOT_PROFILE`, `DOT_AGENT_PROFILE`, `DOTFILES_FLEET_HOSTS` if a per-project `.dot.toml` declares them. Lets mise users keep agent/fleet config per-project the same way they keep node/python versions per-project.

`bin/uninstall`: not written yet. The plan is `rm -rf $ASDF_INSTALL_PATH`: no global state to revert, because the plugin only writes to its own install path.

## Adoption path (the section worth reading)

1. Maintainer extracts this directory to `github.com/sebastienrousseau/mise-plugin-dot`.
2. Maintainer opens a PR to [`mise-en-place/registry`](https://mise.jdx.dev/registry.html) adding the plugin entry.
3. Once merged, `mise install dot@latest` works for every mise user globally.
4. devtools.fm episode pitch sent to Jeff Dickey (per [ROADMAP_2026 §E1](https://github.com/sebastienrousseau/dotfiles/blob/main/docs/operations/ROADMAP_2026.md)).

Expected timeline: ~1 week from extraction to merged registry PR. Plugin code is here today so the extraction is purely a `git filter-branch` + a new remote.

## License

Same as the parent repo: Apache-2.0 OR MIT.
