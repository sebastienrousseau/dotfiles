<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<!-- Copyright (c) 2015-2026 Sebastien Rousseau -->

# Verifying a release artefact

Copy-paste recipes for checking that what you downloaded is what CI
produced. Written for packagers and for anyone installing outside a
package manager.

The four attestations are orthogonal — each rules out a different
class of attack — and you do not need all four. If you only run one
command, run the first.

```sh
TAG=v0.2.519
REPO=sebastienrousseau/dotfiles
VERSION="${TAG#v}"
```

## 1. Build provenance (fastest, one command)

Proves the archive was built by this repository's CI, from this tag,
by the workflow that claims to have built it. Keyless (Fulcio +
Rekor); nothing to import.

```sh
gh release download "$TAG" --repo "$REPO" --pattern "dot-${VERSION}.tar.gz"
gh attestation verify "dot-${VERSION}.tar.gz" --repo "$REPO"
```

Expected: `✓ Verification succeeded!` naming
`.github/workflows/release-package-dot.yml` and the tag's commit SHA.

## 2. Checksums

Three checksum files exist and they cover different things:

- `dot-<version>.SHA256SUMS` — the two release archives, written by
  the packaging workflow alongside them.
- `SHA256SUMS` — the **documentation** bundle, written by
  `manual-publish.yml`. Different assets; do not confuse the two.
- `ALL_SHA256SUMS` — **every** asset on the release, including both of
  the above, written and signed afterwards by `security-release.yml`.
  This is the one to prefer, because it is the only signed one.

```sh
gh release download "$TAG" --repo "$REPO" \
  --pattern ALL_SHA256SUMS --pattern 'ALL_SHA256SUMS.*'

# Verify the manifest's own signature first — an unsigned manifest
# proves nothing.
cosign verify-blob \
  --certificate ALL_SHA256SUMS.pem \
  --signature   ALL_SHA256SUMS.sig \
  --certificate-identity-regexp "^https://github.com/$REPO/" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ALL_SHA256SUMS

# Then check every asset against it.
gh release download "$TAG" --repo "$REPO" --dir .
sha256sum -c ALL_SHA256SUMS
```

## 3. Sigstore signature on the archive

The packaging workflow also emits a standalone sigstore bundle for the
tarball and zip, so you can verify without the `gh` CLI:

```sh
gh release download "$TAG" --repo "$REPO" \
  --pattern "dot-${VERSION}.tar.gz" \
  --pattern "dot-${VERSION}.tar.gz.sigstore.json"

cosign verify-blob \
  --bundle "dot-${VERSION}.tar.gz.sigstore.json" \
  --certificate-identity-regexp "^https://github.com/$REPO/" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  "dot-${VERSION}.tar.gz"
```

## 4. SLSA provenance

```sh
gh release download "$TAG" --repo "$REPO" \
  --pattern dotfiles-sbom.spdx.json \
  --pattern dotfiles-sbom.spdx.json.intoto.jsonl

slsa-verifier verify-artifact dotfiles-sbom.spdx.json \
  --provenance-path dotfiles-sbom.spdx.json.intoto.jsonl \
  --source-uri "github.com/$REPO" \
  --source-tag "$TAG"
```

## 5. SBOM

Two formats are attached to every release:

| Asset | Format | Produced by |
|---|---|---|
| `dot-<version>.cyclonedx.json` | CycloneDX 1.6 JSON | `release-package-dot.yml` |
| `dotfiles-sbom.spdx.json` | SPDX 2.3 JSON | `security-release.yml` |

Both are consumable by `grype`, `trivy`, `osv-scanner`, and any SBOM
viewer:

```sh
grype "sbom:dot-${VERSION}.cyclonedx.json"
```

## 6. The git tag itself

Tags are signed with an SSH ed25519 key, published in
[`../KEYS.asc`](../KEYS.asc) in `git allowed_signers` format:

```sh
git clone https://github.com/sebastienrousseau/dotfiles
cd dotfiles
git -c gpg.ssh.allowedSignersFile=KEYS.asc tag -v "$TAG"
```

Expected: `Good "git" signature for sebastian.rousseau@gmail.com with
ED25519 key SHA256:f6FG+guRNtT3R36oQFS4oWCx1d10nm+BoaIL3Tkh1r4`.

Without the allowed-signers file you get `No principal matched` — the
signature is still cryptographically valid, but nothing binds it to a
known identity. Cross-check the fingerprint against GitHub's API, which
is served independently of this repository:

```sh
curl -s https://api.github.com/users/sebastienrousseau/ssh_signing_keys
```

## Installing the tools

| Tool | macOS | Linux | Windows |
|---|---|---|---|
| `gh` | `brew install gh` | distro package or [releases](https://github.com/cli/cli/releases) | `scoop install gh` |
| `cosign` | `brew install cosign` | [releases](https://github.com/sigstore/cosign/releases) | `scoop install cosign` |
| `slsa-verifier` | `brew install slsa-verifier` | [releases](https://github.com/slsa-framework/slsa-verifier/releases) | `scoop install slsa-verifier` |
| `grype` | `brew install grype` | [releases](https://github.com/anchore/grype/releases) | `scoop install grype` |

## If verification fails

Do **not** install. Open an issue at
<https://github.com/sebastienrousseau/dotfiles/issues>, or — if you
believe the artefact was tampered with rather than merely built wrong —
report it privately per [`../SECURITY.md`](../SECURITY.md).

## Coverage by release

| Attestation | Since |
|---|---|
| SPDX SBOM + cosign signature | v0.2.500 |
| Signed `ALL_SHA256SUMS` manifest | v0.2.503 |
| SLSA build provenance (`gh attestation verify`) | v0.2.503 |
| `dot-<version>.SHA256SUMS`, CycloneDX SBOM, standalone sigstore bundles | **next release after v0.2.519** |

Earlier releases carry only what the table says; the additions are
forward-only, because re-tagging would break consumers pinned to
existing digests. Weekly, `release-attestation-check.yml` verifies the
latest release still carries the full bundle and opens an issue if
not.
