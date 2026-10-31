---
title: "Release Pipeline"
date: 2026-05-24
---

# Release Pipeline

End-to-end flow from a signed release tag to a fully signed,
distributed release on GitHub, npm, Homebrew, Scoop and the AUR.

Pushing a tag does not create a GitHub Release. The maintainer cuts a
release in two steps:

```sh
# 1. Signed annotated tag, pushed (scripts/ops/release.sh does both)
git tag -s vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z

# 2. Create the Release from that tag. --verify-tag aborts if the tag
#    is not already on the remote, so gh never creates a tag itself.
gh release create vX.Y.Z --verify-tag --title vX.Y.Z --notes-file NOTES.md
```

The tag push runs `verify-tag-signature.yml`, which fails if the tag is
lightweight or unsigned. `gh release create` without `--draft` creates
the Release already published, so GitHub fires `release.created` and
`release.published` together. Packaging starts at creation; publishing,
distribution and the security chain start at publication and run in
parallel where dependencies allow.

```
   git tag -s + git push origin <tag>                (you)
                  │
                  ├── on: push tags v*  → verify-tag-signature.yml
                  ▼
   gh release create <tag> --verify-tag               (you)
                  │
         ├── on: release.created
         │       └── release-package-dot.yml
         │           → dot-VERSION.{tar.gz,zip} + installer,
         │             sigstore bundles, CycloneDX SBOM, checksums
         │
         └── on: release.published
                 │
                 ├──────────────────────┬───────────────────────────┐
                 ▼                      ▼                           ▼
   ┌───────────────────────────┐ ┌──────────────────────┐ ┌───────────────────────┐
   │ release-distribute-*.yml  │ │ security-release.yml │ │ manual-publish.yml    │
   │  homebrew → tap PR        │ │ → SPDX SBOM + sig    │ │ → manual bundle +     │
   │  scoop    → bucket PR     │ │ → SLSA provenance    │ │   SHA256SUMS          │
   │  aur      → AUR push      │ │ → ALL_SHA256SUMS     │ ├───────────────────────┤
   ├───────────────────────────┤ │   + sig + cert       │ │ npm-publish.yml       │
   │ release-install-smoke.yml │ │ → verify full bundle │ │ → npm + GitHub        │
   │  clean install, Linux+mac │ └──────────────────────┘ │   Packages            │
   └───────────────────────────┘                          └───────────────────────┘
                 │
                 ▼
        ┌─────────────────────────────┐
        │  release-attestation-check  │ (Mondays + on demand)
        │  → opens issue if missing   │
        └─────────────────────────────┘
```

## Workflows

| Workflow | Trigger | Owns | Outputs |
|---|---|---|---|
| `verify-tag-signature.yml` | push of a `v*` tag | Fail unless the tag is annotated and carries a PGP or SSH signature. | Pass or fail on the tag push. |
| `release-package-dot.yml` | `release.created`, dispatch (`dry_run` defaults to true) | Build deterministic `dot-VERSION.{tar.gz,zip}` from `tools/release/stage-dot.sh`: the CLI tree (`bin/`, `lib/`, `scripts/`, `plugins/`, `defaults/`), man page, completions, licences. Stage `install.sh` as the standalone installer. Sign both archives and the installer with Cosign keyless bundles; attest build provenance with `actions/attest-build-provenance`. | Nine release assets: `dot-VERSION.tar.gz`, `.zip`, `.tar.gz.sigstore.json`, `.zip.sigstore.json`, `.cyclonedx.json`, `.SHA256SUMS`, `dotfiles-install-VERSION.sh`, `.sh.sha256`, `.sh.sigstore.json`. Plus a GitHub build-provenance attestation over the archives and installer. |
| `manual-publish.yml` (attach-release job) | `release.published` (the build also runs on manual changes pushed to `main` and on PRs) | Build the manual in every format and attach it. | `dotfiles.{pdf,epub,html,html.gz,txt,txt.gz}`, `html.tar.gz`, `dotfiles-md.tar.gz`, `search-index.json`, `SHA256SUMS`. |
| `npm-publish.yml` | `release.published`, dispatch | Publish `@sebastienrousseau/dotfiles` to npmjs.com through OIDC Trusted Publishing with `--provenance`, and to GitHub Packages if that version is not there yet. | npm and GitHub Packages versions. |
| `security-release.yml` (sbom job) | `release.published`, dispatch | Generate SPDX SBOM via anchore/sbom-action. Cosign keyless sign the SBOM. | `dotfiles-sbom.spdx.json` + `.sig` + `.pem`. |
| `security-release.yml` (provenance job) | needs sbom | SLSA L3 provenance via slsa-framework/slsa-github-generator. | `dotfiles-sbom.spdx.json.intoto.jsonl`. |
| `security-release.yml` (manifest job) | needs sbom + provenance, then waits for the complete asset set | Build `ALL_SHA256SUMS` over every release asset and Cosign-sign it. | `ALL_SHA256SUMS` + `.sig` + `.pem`. |
| `security-release.yml` (verify-release-integrity job) | needs sbom + provenance + manifest | Check the SBOM hash, the provenance asset, the SBOM signature, the manifest signature and every digest the manifest records. | Pass or fail. |
| `release-distribute-homebrew.yml` | `release.published`, dispatch | Hash `dot-VERSION.tar.gz`, regenerate `pkg/brew/dot.rb`, push branch + PR to `sebastienrousseau/homebrew-tap`. | One PR on the tap repo. |
| `release-distribute-scoop.yml` | `release.published`, dispatch | Hash `dot-VERSION.zip`, rewrite `pkg/scoop/dot.json` via jq (both 64bit + arm64 point at same zip), PR to `sebastienrousseau/scoop-bucket`. | One PR on the bucket repo. |
| `release-distribute-aur.yml` | `release.published`, dispatch | Hash `dot-VERSION.tar.gz`, rewrite `pkgver` + `sha256sums` in `pkg/aur/PKGBUILD`, regenerate `.SRCINFO` via dockerised `makepkg`, push to `ssh://aur@aur.archlinux.org/dot-cli-git.git`. | One commit on AUR. |
| `release-install-smoke.yml` | `release.published`, dispatch | On `ubuntu-latest` and `macos-15`: download `dot-VERSION.tar.gz`, `gh attestation verify` it, then `make smoke`, `make install` into an empty prefix, run `dot version`, and `make uninstall`. | Pass or fail. |
| `release-attestation-check.yml` | weekly cron (Monday 07:00 UTC) + dispatch | Verify the latest (or given) release carries the SBOM bundle and the signed manifest: `dotfiles-sbom.spdx.json` + `.sig` + `.pem` + `.intoto.jsonl`, `ALL_SHA256SUMS` + `.sig` + `.pem`. It does not check the package assets or their sigstore bundles. | Opens or comments on a tracking issue. |

## Event ownership and readiness

GitHub fires `release.created` the moment a Release record exists.
That starts the packaging step, which depends only on source bytes at
the tag and does not need other assets to be present.

`release.published` fires when a Release becomes public. With
`gh release create` (no `--draft`) both events fire together; with a
draft Release it fires later, when a human publishes it. Distribution,
the npm publish, the manual upload and the security chain start from
this event. Publication does not mean independently triggered asset
publishers have finished, so the manifest job polls (20 attempts, 15 s
apart) until all 16 required assets are present before it downloads
or signs the bundle: five package and installer assets
(`dot-VERSION.tar.gz`, `dot-VERSION.zip`, `dotfiles-install-VERSION.sh`
and its `.sha256` and `.sigstore.json`), six manual formats plus their
`SHA256SUMS`, and the four SBOM, signature and provenance assets. A
failed manual build therefore blocks the signed manifest. The final
integrity job then verifies the manifest's Cosign identity and every
recorded digest.

Both release and dispatch paths of `security-release.yml` are
idempotent: re-running the manifest job after late asset uploads picks
up the new state and the `--clobber` flag overwrites the previous
manifest sig + cert.

## Secrets used

| Secret | Used by | Setup |
|---|---|---|
| `GITHUB_TOKEN` | every workflow (auto) | n/a |
| `ACTIONS_BOT_SIGNING_KEY` | `release-distribute-homebrew.yml` and `release-distribute-scoop.yml` (signed commits on the tap and bucket repos), `update-deps.yml`, `sync-versions.yml` | See `docs/security/AUTOMATION_SECRETS.md`. |
| `TAP_PUSH_TOKEN` | `release-distribute-homebrew.yml`, `release-distribute-scoop.yml` (clone, push and open the PR on the tap and bucket repos; falls back to `GITHUB_TOKEN` when unset) | See `docs/security/AUTOMATION_SECRETS.md`. |
| `AUR_SSH_KEY` | `release-distribute-aur.yml` only | SSH ED25519 keypair; public key on the `srousseau` AUR profile, private key in this secret. |

`npm-publish.yml` needs no npm token: npmjs.com trusts the workflow
through OIDC Trusted Publishing.

## Distribution targets

| Target | Repo | First-run prereq |
|---|---|---|
| Homebrew | `sebastienrousseau/homebrew-tap` | Tap repo exists. Workflow creates the `Formula/dot.rb` path on first publish. |
| Scoop | `sebastienrousseau/scoop-bucket` | Bucket repo exists. Workflow creates `bucket/dot.json` on first publish. |
| AUR | `ssh://aur@aur.archlinux.org/dot-cli-git.git` | **Manual one-time step**: the maintainer must create the package entry via the AUR web UI before the workflow's `git clone` can succeed. The workflow retries the clone ten times, 30 s apart, then exits with an error pointing at the AUR package list. |

## Verifying a release

See `docs/security/VERIFY_RELEASE.md` for the consumer-facing
verification recipe. A release carries these attestations, and a
verifier can check any of them independently:

- Cosign keyless sigstore bundles for `dot-VERSION.tar.gz`,
  `dot-VERSION.zip` and `dotfiles-install-VERSION.sh`.
- GitHub build-provenance attestations for the same three files
  (`gh attestation verify`).
- The SPDX SBOM, its Cosign signature, and its SLSA provenance
  (`.intoto.jsonl`).
- The unified Cosign-signed manifest `ALL_SHA256SUMS` over every
  other asset.
- npm provenance on the published npm package.

## Known caveats

- **AUR `pkgname=dot-cli-git`**: AUR's `-git` convention means
  "tracks git HEAD", but the workflow publishes tagged stable
  releases. Either rename to plain `dotfiles` in
  `pkg/aur/PKGBUILD` and register that package, or accept the
  misnomer. Documented in the v0.2.503 PR (#895). Since 0.2.539 the
  PKGBUILD builds the release archive rather than the git head.
- **Signed-Releases retroactive**: the unified manifest landed in
  v0.2.503. Releases v0.2.500-502 carry the SBOM bundle only.
  We do not re-tag older releases (would break consumer pins). The
  OSSF Scorecard score climbs naturally as new releases land.
- **Rehearsal**: run `release-package-dot.yml` by hand with
  `dry_run` left at its default (`true`). It builds, checksums,
  signs and verifies the artefacts, skips attestation and upload, and
  keeps the results as a workflow artifact. A `-rc` tag is not a
  rehearsal path: `release-install-smoke.yml` accepts only `vX.Y.Z`
  tags.

## See also

- `docs/security/VERIFY_RELEASE.md` — consumer-facing verification.
- `docs/security/CI_PINNING.md` — reusable workflow pin policy + the
  same-commit local reusable-workflow references.
- `docs/security/AUTOMATION_SECRETS.md` — how each automation secret
  is generated, scoped, and rotated.
- `docs/operations/ROADMAP_V0_2_503.md` — the 7-workstream plan this
  pipeline executed.
