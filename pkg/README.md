<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<!-- Copyright (c) 2015-2026 Sebastien Rousseau -->

# `pkg/` — packaging inputs, one directory per format

Each directory holds the template the release pipeline rewrites for a
tag. None of them is edited by hand at release time; the workflows
listed below hash the published artefact and substitute the version
and digest.

| Directory | Format | Rendered by | Published to |
|---|---|---|---|
| [`brew/`](brew/dot.rb) | Homebrew formula | `release-distribute-homebrew.yml` | PR to `sebastienrousseau/homebrew-tap` |
| [`scoop/`](scoop/dot.json) | Scoop manifest | `release-distribute-scoop.yml` | PR to `sebastienrousseau/scoop-bucket` |
| [`aur/`](aur/PKGBUILD) | Arch PKGBUILD | `release-distribute-aur.yml` | push to `aur.archlinux.org` |
| [`nix/`](nix/README.md) | Nix flake (pointer) | — | `nix/flake.nix` in-repo |
| [`docker/`](docker/README.md) | Container (none published, and why) | — | — |

- **Verifying an artefact:** [`VERIFY.md`](VERIFY.md)
- **Packaging for a new distro:** [`../docs/packaging.md`](../docs/packaging.md)
- **Release pipeline:** [`../docs/operations/RELEASE_PIPELINE.md`](../docs/operations/RELEASE_PIPELINE.md)

deb and rpm recipes are not provided yet. `make install` already
produces a correct `DESTDIR` tree, so a recipe would be thin —
contributions welcome.
