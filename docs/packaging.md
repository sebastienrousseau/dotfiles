---
render_with_liquid: false
---

<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<!-- Copyright (c) 2015-2026 Sebastien Rousseau -->

# Packaging guide

**Audience: distribution maintainers.** If you are packaging `dot` for
Debian, Fedora, Arch, Homebrew, nixpkgs, Scoop, or anything else, this
page is written for you. Everything a packager normally has to
reverse-engineer — the licence grant, the toolchain floor, how the
dependencies are pinned, how to build and test offline, and how to
verify what you downloaded — is here.

Existing packaging inputs live in [`pkg/`](https://github.com/sebastienrousseau/dotfiles/tree/main/pkg),
one directory per format.

## What this software is

A shell framework, not a compiled program. The shipped artefact is:

- `bin/dot` — the CLI dispatcher (bash)
- `lib/dot/`, `scripts/` — sourced bash libraries and subcommands
- `share/man/man1/dot.1` — the man page, **generated** from the CLI's
  command registry at build time
- `share/{bash-completion,zsh,fish}/…` — completions, also generated
- `defaults/` — the chezmoi source tree the CLI applies to `$HOME`

There is nothing to compile and no architecture-specific output. The
release archive is `noarch`/`any`.

## Licence grant

**`Apache-2.0 OR MIT`** — the SPDX expression declared in
`package.json` and in `REUSE.toml`. Both full texts ship in the
repository and in the release archive as `LICENSE-APACHE` and
`LICENSE-MIT`, and `make install` places both under
`$(PREFIX)/share/doc/dotfiles/`.

This is a dual grant, not a conjunction: a downstream recipient may
comply with **either** licence, at their option. For distributions
that require a single choice, MIT is the permissive default; choose
Apache-2.0 if you want the explicit patent grant.

Per-file licensing is machine-readable via [REUSE](https://reuse.software/):
`REUSE.toml` at the repository root annotates the tree, and
`reuse lint` runs in CI. Vendored third-party material, where present,
is annotated separately and keeps its own licence.

## Minimum toolchain

Full policy, per-distro mapping, and the rules for when a floor may
rise: [`MINIMUM-TOOLCHAIN.md`](MINIMUM-TOOLCHAIN.md). The short form
for a packaging recipe:

| Dependency | Minimum | Kind |
|---|---|---|
| `bash` | 3.2 | **required at runtime** |
| `git` | 2.34 | required at runtime |
| `curl` | any | required by the bootstrap path only |
| `chezmoi` | 2.47.1 | **required at runtime** — the CLI is a control plane over chezmoi |
| `zsh` / `fish` / `nushell` | 5.8 / 4.0 / 0.98 | optional; only if the user wants that shell's integration |
| `jq`, `gum`, `starship`, `fzf` | any | optional; enable JSON output, rich prompts, and interactive pickers |
| `go` | 1.23 | **build/test only** — fuzz harnesses and the two Go TUIs. Not needed to build or run the package. |

Suggested dependency split for a distro package: `Depends: bash (>= 3.2),
git (>= 2.34), chezmoi (>= 2.47.1)`; `Recommends: jq, zsh`;
`Suggests: fish, nushell, gum, starship, fzf`.

## Dependency pin model

Every dependency this project *builds and tests against* is pinned,
and every pin is committed:

| Surface | Pinned by | Notes |
|---|---|---|
| Development toolchain (node, go, rust, and ~20 CLI tools) | `mise.toml` + `mise.lock` + `mise-versions.lock.json` | mise is the package manager; the lock carries checksums |
| Documentation build (Python) | `requirements-docs.txt` | Hash-pinned (`--require-hashes`-compatible), compiled from `requirements-docs.in` |
| Node tooling | `package.json` | Dev-only |
| Nix | `flake.lock`, `nix/flake.lock` | Root flake provides the dev shell; `nix/flake.nix` provides `packages.default` |
| GitHub Actions | 40-hex commit SHA on every `uses:` | Enforced by `tools/ci/lint-reusable-pins.sh` and OpenSSF Scorecard |
| Container bases | `FROM image:tag@sha256:<digest>` | Policy in [`security/CI_PINNING.md`](security/CI_PINNING.md) |
| Binaries fetched during CI | `sha256sum -c` against a committed manifest | `security/remote-installers.sha256` |

None of these are needed to *build the package*: the release archive
is self-contained and its build has no network step. They exist so
that the tests you may want to run are reproducible.

Full provenance policy: [`supply-chain/README.md`](https://github.com/sebastienrousseau/dotfiles/blob/main/supply-chain/README.md).

## Building the package

From a release tarball (recommended — it is the attested artefact):

```sh
tar -xzf dot-0.2.520.tar.gz
cd dot-0.2.520
make install PREFIX=/usr DESTDIR="$pkgdir"
```

From a git checkout:

```sh
make                                   # generates man page + completions into build/
make install PREFIX=/usr DESTDIR="$pkgdir"
```

Both honour `PREFIX` (default `/usr/local`) and `DESTDIR`, and install
to FHS paths:

```
$(DESTDIR)$(PREFIX)/bin/dot                                  -> symlink into libexec
$(DESTDIR)$(PREFIX)/lib/dotfiles/                            program tree
$(DESTDIR)$(PREFIX)/share/man/man1/dot.1
$(DESTDIR)$(PREFIX)/share/bash-completion/completions/dot
$(DESTDIR)$(PREFIX)/share/zsh/site-functions/_dot
$(DESTDIR)$(PREFIX)/share/fish/vendor_completions.d/dot.fish
$(DESTDIR)$(PREFIX)/share/doc/dotfiles/{LICENSE-APACHE,LICENSE-MIT,README.md,CHANGELOG.md}
```

Every directory is individually overridable — `BINDIR`, `MANDIR`,
`DOCDIR`, `LIBEXECDIR`, `BASHCOMPDIR`, `ZSHCOMPDIR`, `FISHCOMPDIR` —
for distributions whose layout differs. If your `BINDIR` and
`LIBEXECDIR` are not siblings under `PREFIX`, also set `DOT_LINK` to
the correct relative or absolute symlink target; `make install` fails
loudly rather than leaving a dangling link.

`make uninstall` removes exactly what `make install` placed.

## Testing offline

There are no vendored build dependencies to unbundle, and the checks a
packager cares about need no network:

```sh
make installcheck DESTDIR="$pkgdir"    # asserts the installed tree is complete and runs
make -C "$pkgdir" smoke                # from a release tarball: run the CLI in place
```

`installcheck` verifies the `bin` symlink resolves, the man page and
all three completions are present, the licences are installed, and the
installed binary reports the expected version and renders help — from
a sandboxed `HOME`, with no source checkout and no network.

The full suite also runs offline:

```sh
make test           # unit + regression; no network
make examples       # every example under examples/ executed
```

`make test-integration` and anything under `install/provision/` **do**
touch the network and modify `$HOME`; do not run them in a build
chroot.

## Verifying what you downloaded

Do not package an unverified tarball. Every release carries four
independent attestations, and the consumer-side recipe with copy-paste
commands is in
[`pkg/VERIFY.md`](https://github.com/sebastienrousseau/dotfiles/blob/main/pkg/VERIFY.md)
and [`security/VERIFY_RELEASE.md`](security/VERIFY_RELEASE.md).

Minimum a packager should do:

```sh
TAG=v0.2.520
REPO=sebastienrousseau/dotfiles

# SLSA build provenance on the tarball itself
gh attestation verify "dot-${TAG#v}.tar.gz" --repo "$REPO"

# Or, without the gh CLI: the signed manifest covering every asset
gh release download "$TAG" --repo "$REPO" \
  --pattern ALL_SHA256SUMS --pattern 'ALL_SHA256SUMS.*'
cosign verify-blob \
  --certificate ALL_SHA256SUMS.pem --signature ALL_SHA256SUMS.sig \
  --certificate-identity-regexp "^https://github.com/$REPO/" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ALL_SHA256SUMS
sha256sum -c ALL_SHA256SUMS
```

Tags are signed with an SSH ed25519 key published in
[`KEYS.asc`](https://github.com/sebastienrousseau/dotfiles/blob/main/KEYS.asc),
which is itself a `git allowed_signers` file:

```sh
git -c gpg.ssh.allowedSignersFile=KEYS.asc tag -v v0.2.520
```

An SBOM ships with every release in both CycloneDX and SPDX JSON.

## Reproducibility

The release archives are built deterministically — `tar --sort=name
--mtime='1970-01-01' --owner=0 --group=0 --numeric-owner`, and
`zip -X -D` over a normalised tree — so two builds of the same tag
produce identical bytes.

This is a statement about the *archive build*, which is exercised by
CI on every release. It is **not** a verified end-to-end
reproducible-builds claim: no diffoscope comparison of two independent
rebuilds runs in CI today. Treat it as "deterministic archiving",
not as a reproducible-builds certification.

## Channel notes

| Channel | File | How it is produced |
|---|---|---|
| Homebrew | `pkg/brew/dot.rb` | `release-distribute-homebrew.yml` rewrites `url` + `sha256`, opens a PR on `sebastienrousseau/homebrew-tap` |
| Scoop | `pkg/scoop/dot.json` | `release-distribute-scoop.yml` rewrites version + hashes via `jq`, opens a PR on `sebastienrousseau/scoop-bucket` |
| AUR | `pkg/aur/PKGBUILD` | `release-distribute-aur.yml` rewrites `pkgver` + `sha256sums`, regenerates `.SRCINFO`, pushes to the AUR |
| Nix | `pkg/nix/` → `nix/flake.nix` | `packages.default` in `nix/flake.nix` |
| deb / rpm | *not yet provided* | Contributions welcome; `make install` already produces a correct `DESTDIR` tree, so a recipe is thin |

If you are packaging for a distribution not listed here, please open
an issue — a link to your package will be added, and the `pkg/`
directory is the right place for the recipe to live so it stays in
lockstep with the release build.
