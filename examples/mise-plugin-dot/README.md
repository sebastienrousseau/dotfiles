# mise-plugin-dot

A [mise](https://mise.jdx.dev) plugin that installs and manages the `dot` CLI from any chezmoi-managed dotfiles repository — including [sebastienrousseau/dotfiles](https://github.com/sebastienrousseau/dotfiles) — through a single one-liner.

## What it does

```sh
mise install dot@latest                          # the maintainer's reference repo
mise install dot@sebastienrousseau/dotfiles      # explicit owner/repo
mise install dot@v0.2.502                        # pinned tag
mise install dot@alice/cfg                       # any user's dotfiles
mise use -g dot@v0.2.502                         # set globally
```

That is the intended interface. **None of it works today**: see Status.

## Status

**Broken scaffold.** This is a vendored copy of the planned `sebastienrousseau/mise-plugin-dot` external repo. `bin/install` predates the v0.2.503 layout and the 0.2.538 command renames, so both of its paths fail on a current release:

- The tagged-release path downloads the GitHub *source* archive (`archive/refs/tags/<tag>.tar.gz`), not the `dot-<version>.tar.gz` release asset, and checks it against a `checksums.txt` asset that releases do not publish, so in practice nothing is verified. It then installs `dot_local/bin/executable_dot`, a path that no longer exists.
- The owner/repo path runs `dot init`, which was removed in 0.2.538 (`dot config init` replaces it), and copies the same missing file from `~/.local/share/chezmoi`.

There is no `bin/uninstall`. Once `bin/install` is fixed and the plugin is extracted to its own repo with a PR to [`mise-en-place/registry`](https://mise.jdx.dev/registry.html), `mise install dot@<spec>` becomes a one-line install for any user on any platform mise supports.

This vendored copy exists so:

1. The plugin code lives under version control alongside the framework it bootstraps.
2. Anyone can try the plugin locally before the registry PR lands (once `bin/install` is fixed): `mise plugin add dot /path/to/dotfiles/examples/mise-plugin-dot`.
3. The plugin's contract (binary downloads, version detection, env exports) is reviewable in the same PR as the framework changes that need it.

## Plugin contract

`bin/list-all` — echo every installable version, newest first. Reads the upstream GitHub releases API.

`bin/install`: install a given version to `$ASDF_INSTALL_PATH` / `$MISE_INSTALL_PATH`. Two paths are intended (both broken today, see Status):

- **Tagged release** (`mise install dot@v0.2.502`): download the release tarball and verify its SHA-256.
- **owner/repo shorthand** (`mise install dot@alice/cfg`): bootstrap the repo without `chezmoi apply` and copy the resulting `dot` into the install path, so mise installs are isolated from user state.

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
