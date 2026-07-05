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

Under the hood the plugin invokes `dot init <owner/repo>` so every install runs through the framework's signed-bootstrap pipeline (see [HARD_AUDIT_2026 §H6](https://github.com/sebastienrousseau/dotfiles/blob/main/docs/operations/HARD_AUDIT_2026.md)). No unverified `curl | sh`.

## Status

**Scaffold.** This is a vendored copy of the upcoming `jdx/mise-plugin-dot` external repo. Once the maintainer extracts it to its own GitHub repo and submits a PR to [`mise-en-place/registry`](https://github.com/mise-en-place/registry), `mise install dot@<spec>` becomes a one-line install for any user on any platform mise supports.

This vendored copy exists so:

1. The plugin code lives under version control alongside the framework it bootstraps.
2. Anyone can adopt the plugin locally before the registry PR lands: `mise plugin add dot /path/to/dotfiles/examples/mise-plugin-dot`.
3. The plugin's contract (binary downloads, version detection, env exports) is reviewable in the same PR as the framework changes that need it.

## Plugin contract

`bin/list-all` — echo every installable version, newest first. Reads the upstream GitHub releases API.

`bin/install` — install a given version to `$ASDF_INSTALL_PATH` / `$MISE_INSTALL_PATH`. Two paths:

- **Tagged release** (`mise install dot@v0.2.502`) — downloads the SHA256-verified release tarball + cosign signature.
- **owner/repo shorthand** (`mise install dot@alice/cfg`) — runs `dot init alice/cfg --no-apply` and copies the resulting `dot` binary into the install path. Skips the framework's `chezmoi apply` so mise installs are isolated from user state.

`bin/exec-env` — export `DOT_PROFILE`, `DOT_AGENT_PROFILE`, `DOTFILES_FLEET_HOSTS` if a per-project `.dot.toml` declares them. Lets mise users keep agent/fleet config per-project the same way they keep node/python versions per-project.

`bin/uninstall` — `rm -rf $ASDF_INSTALL_PATH`. No global state to revert because this plugin only ever writes to its own install path.

## Adoption path (the section worth reading)

1. Maintainer extracts this directory to `github.com/sebastienrousseau/mise-plugin-dot`.
2. Maintainer opens a PR to [`mise-en-place/registry`](https://github.com/mise-en-place/registry) adding the plugin entry.
3. Once merged, `mise install dot@latest` works for every mise user globally.
4. devtools.fm episode pitch sent to Jeff Dickey (per [ROADMAP_2026 §E1](https://github.com/sebastienrousseau/dotfiles/blob/main/docs/operations/ROADMAP_2026.md)).

Expected timeline: ~1 week from extraction to merged registry PR. Plugin code is here today so the extraction is purely a `git filter-branch` + a new remote.

## License

Same as the parent repo: MIT.
