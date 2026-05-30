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

The README's **Verified install** snippet pins to a release tag
(e.g. `v0.2.501`), downloads the installer, and asks `shasum -a 256
-c` (or `sha256sum -c`) to check the contents against an expected
hash. If the hash doesn't match, the verify step exits non-zero and
the install never starts.

### 2. The `chezmoi` binary (always verified when possible)

`install.sh` prefers the bundled checksum-verified installer at
`tools/ci/install-chezmoi-verified.sh`, which:

- Resolves the platform (`uname -s` + `uname -m`).
- Downloads `chezmoi_<version>_<os>_<arch>.tar.gz` AND the matching
  `chezmoi_<version>_checksums.txt` from the official
  `twpayne/chezmoi` GitHub release.
- Greps the checksum file for the asset's expected SHA256.
- Verifies the downloaded tarball against that SHA256 using
  `shasum -a 256 -c` / `sha256sum -c`.
- Aborts with a clear error if the asset isn't in the checksum file
  or the verification fails.

When the verified installer isn't available (e.g. the curl one-liner
mode where `install.sh` is fetched in isolation), the code falls back
to `get.chezmoi.io` with two defense-in-depth checks:

- The downloaded installer must be smaller than 100 KiB (sanity
  guard against a CDN serving an arbitrary binary).
- The first line must start with `#!/` (must look like a shell
  script).

These are weaker than a SHA256 check, but they catch the obvious
"installer got replaced with a 50 MB malicious binary" failure mode.

### 3. The chezmoi source tree

After chezmoi is installed, `install.sh` clones the dotfiles repo
itself. This isn't currently cryptographically verified beyond Git's
own object integrity, but commits in the repo are SSH-signed and
branch protection on `master` requires signed commits (see #853).

## How to obtain per-release hashes

The verified-install snippet uses the SHA256 of the `install.sh`
file *as it exists at the release tag*. To regenerate after a release:

```bash
git switch master
git pull
NEW_TAG="v0.2.502"   # adjust
git tag -s "$NEW_TAG" -m "..."
git push origin "$NEW_TAG"

# Compute the hash:
shasum -a 256 install.sh

# Update README.md's verified-install snippet with the new hash + tag.
```

A follow-up automation (tracked at the bottom of this page) will
publish a `.sha256` sibling next to the install.sh asset in GitHub
Releases so the README snippet can reference a stable URL instead
of a hardcoded value.

## What to do if the hash doesn't match

If you run the verified install and `shasum -a 256 -c` reports
`FAILED`:

1. **Don't run the installer.** The hash mismatch means either the
   release was retagged (rare) or someone is MITM-ing your download.
2. Check the [Releases page](https://github.com/sebastienrousseau/dotfiles/releases)
   for the matching tag. The per-release `install.sh` SHA is
   embedded in the README at the time of that release; you can also
   recover it from the git history of `README.md`.
3. If the README hash is stale (release was retagged for legitimate
   reasons), `git log` on `install.sh` will show the change. Inspect
   the diff before trusting a new hash.

## What is NOT verified (yet)

- **Cosign keyless signature** on `install.sh` — tracked separately
  under #876.
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
