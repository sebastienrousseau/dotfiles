---
render_with_liquid: false
---

# Install Verification

This page documents what gets verified during `install.sh` execution,
why those checks matter, and how to obtain the per-release expected
hashes used by the verified-install path in the README.

Managed under
[#858](https://github.com/sebastienrousseau/dotfiles/issues/858).

## What is verified

`install.sh` performs three classes of verification before doing
anything destructive:

### 1. The installer itself (verified path)

The README's **Verified release installer** snippet pins to a release asset,
downloads the installer, and asks `shasum -a 256
-c` (or `sha256sum -c`) to check the contents against an expected
hash. If the hash doesn't match, the verify step exits non-zero and
the install never starts.

### 2. The `chezmoi` binary (always verified when possible)

`install.sh` prefers the bundled checksum-verified installer at
`tools/ci/install-chezmoi-verified.sh`. A release-pinned standalone copy uses
the same verification algorithm embedded in `install.sh`, so the secure path
does not depend on another unverified download. Both implementations:

- Resolves the platform (`uname -s` + `uname -m`).
- Downloads `chezmoi_<version>_<os>_<arch>.tar.gz` AND the matching
  `chezmoi_<version>_checksums.txt` from the official
  `twpayne/chezmoi` GitHub release.
- Greps the checksum file for the asset's expected SHA256.
- Verifies the downloaded tarball against that SHA256 using
  `shasum -a 256 -c` / `sha256sum -c`.
- Aborts with a clear error if the asset isn't in the checksum file
  or the verification fails.

No path pipes `get.chezmoi.io` or another moving remote script into a shell.
If the upstream checksum manifest is absent, the requested archive is absent,
or the digest differs, installation fails closed.

### 3. The chezmoi source tree

After chezmoi is installed, `install.sh` clones the dotfiles repo
itself. This isn't currently cryptographically verified beyond Git's
own object integrity, but commits in the repo are SSH-signed and
branch protection on `main` requires signed commits (see #853).

## How to obtain per-release hashes

The release workflow copies `install.sh` to
`dotfiles-install-<version>.sh`, publishes a `.sha256` sibling, generates a
keyless Sigstore bundle, and includes the installer in the build-provenance
attestation and release-wide signed manifest. To update the README before a
release:

```bash
git switch main
git pull
NEW_TAG="v0.2.521"   # adjust

# Compute the hash:
shasum -a 256 install.sh

# Update README.md's verified-install snippet with the new hash + version.
```

## What to do if the hash doesn't match

If you run the verified install and `shasum -a 256 -c` reports
`FAILED`:

1. **Don't run the installer.** The hash mismatch means either the
   release was retagged (rare) or someone is MITM-ing your download.
2. Check the [Releases page](https://github.com/sebastienrousseau/dotfiles/releases)
   for the matching tag. The per-release `install.sh` SHA is
   embedded in the README at the time of that release; you can also
   recover it from the git history of `README.md`.
3. Release tags are immutable. If the README hash is stale, do not retag;
   correct the release process and publish a new patch version.

## What is NOT verified (yet)

- **deps.dev attestation lookup** for npm/Python deps used during
  install — tracked under #877.
- **Reproducible-build guarantee** for the chezmoi binary itself —
  out of scope; rely on the upstream project's release engineering.

## Negative-test coverage

`tests/unit/install/test_install_chezmoi_verified.sh` exercises the
verification path with a deliberately tampered checksum to confirm
the installer aborts. The test ships with the repo and runs on every
PR.

## References

- `install.sh` — the entry point.
- `tools/ci/install-chezmoi-verified.sh` — the SHA256-pinned
  chezmoi installer.
- `tests/unit/install/test_install_chezmoi_verified.sh` — the
  negative test.
- Issue [#858](https://github.com/sebastienrousseau/dotfiles/issues/858).
