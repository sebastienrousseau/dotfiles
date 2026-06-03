---
title: "Release Pipeline"
date: 2026-05-24
---

# Release Pipeline

End-to-end flow from `git tag v0.2.503 && git push --tags` to a fully
signed, distributed release on GitHub + Homebrew + Scoop + AUR.

Five workflows are involved, each scoped to one job and triggered off
either `release.created` or `release.published`. They run in parallel
where dependencies allow.

```
            git push --tags                       (you)
                  │
                  ▼
       ┌────────────────────────────┐
       │  GitHub creates Release    │ (auto, from tag)
       └─┬──────────────────────────┘
         │ on: release.created
         ▼
   ┌─────────────────────────────┐   ┌─────────────────────────────┐
   │  release-package-dot.yml    │   │  security-release.yml (sbom)│
   │  → dot-VERSION.tar.gz       │   │  → SBOM + cosign sig + cert │
   │  → dot-VERSION.zip          │   │  → SLSA L3 provenance       │
   └─────────────┬───────────────┘   └──────────────┬──────────────┘
                 │ uploaded to release              │
                 │                                  │
                 │ on: release.published            │ on: release.published
                 │ (after human "publish" click,    │ (same trigger)
                 │  or auto if Release was created  │
                 │  with assets+published in one)   │
                 ▼                                  ▼
   ┌─────────────────────────────┐   ┌─────────────────────────────┐
   │  release-distribute-*.yml   │   │  security-release.yml       │
   │  ┌─────────────────────┐    │   │  (manifest job)             │
   │  │ homebrew → tap PR   │    │   │  → ALL_SHA256SUMS           │
   │  │ scoop    → bucket PR│    │   │  → cosign sig + cert        │
   │  │ aur      → AUR push │    │   │                             │
   │  └─────────────────────┘    │   └─────────────────────────────┘
   └─────────────────────────────┘
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
| `release-package-dot.yml` | `release.created`, dispatch | Build deterministic `dot-VERSION.{tar.gz,zip}` from `bin/`, `lib/`, `share/`, completions. | Two release assets. |
| `security-release.yml` (sbom job) | `release.created`, dispatch | Generate SPDX SBOM via anchore/sbom-action. Cosign keyless sign the SBOM. | `dotfiles-sbom.spdx.json` + `.sig` + `.pem`. |
| `security-release.yml` (provenance job) | needs sbom | SLSA L3 provenance via slsa-framework/slsa-github-generator. | `dotfiles-sbom.spdx.json.intoto.jsonl`. |
| `security-release.yml` (manifest job) | `release.published`, dispatch | Build `ALL_SHA256SUMS` over every release asset, Cosign-sign it. | `ALL_SHA256SUMS` + `.sig` + `.pem`. |
| `release-distribute-homebrew.yml` | `release.published`, dispatch | Hash `dot-VERSION.tar.gz`, regenerate `install/homebrew/dot.rb`, push branch + PR to `sebastienrousseau/homebrew-tap`. | One PR on the tap repo. |
| `release-distribute-scoop.yml` | `release.published`, dispatch | Hash `dot-VERSION.zip`, rewrite `install/scoop/dot.json` via jq (both 64bit + arm64 point at same zip), PR to `sebastienrousseau/scoop-bucket`. | One PR on the bucket repo. |
| `release-distribute-aur.yml` | `release.published`, dispatch | Hash `dot-VERSION.tar.gz`, rewrite `pkgver` + `sha256sums` in `install/aur/PKGBUILD`, regenerate `.SRCINFO` via dockerised `makepkg`, push to `ssh://aur@aur.archlinux.org/dot-cli-git.git`. | One commit on AUR. |
| `release-attestation-check.yml` | weekly cron + dispatch | Verify the latest release carries the full attestation bundle (SBOM + sig + cert + intoto + manifest + sig + cert). | Opens or comments on a tracking issue. |

## Why `created` vs `published`

GitHub fires `release.created` the moment a Release record exists.
That covers SBOM + SLSA + the packaging step: those depend only on
source bytes at the tag and don't need other assets to be present.

`release.published` fires later, when a human flips the Release from
draft to public (or when a Release is created already-public, the
events fire together). The manifest job and the three distribution
jobs wait for that because they enumerate *all* assets on the release;
running them earlier would miss the manual / docs artefacts uploaded
by `manual-publish.yml` and the packaging step's tarball + zip.

Both arms of `security-release.yml` are idempotent: re-running the
manifest job after late asset uploads picks up the new state and the
`--clobber` flag overwrites the previous manifest sig + cert.

## Secrets used

| Secret | Used by | Setup |
|---|---|---|
| `GITHUB_TOKEN` | every workflow (auto) | n/a |
| `ACTIONS_BOT_SIGNING_KEY` | distribute-* (signed commits on tap repos), `bump-reusable-pins.yml`, `update-deps.yml` | See `docs/security/AUTOMATION_SECRETS.md`. |
| `AUR_SSH_KEY` | `release-distribute-aur.yml` only | SSH ED25519 keypair; public key on the `srousseau` AUR profile, private key in this secret. See `memory/reference_aur_account.md` for the AUR Edit-Account form quirk that bit us during setup. |

## Distribution targets

| Target | Repo | First-run prereq |
|---|---|---|
| Homebrew | `sebastienrousseau/homebrew-tap` | Tap repo exists (currently bare README + LICENSE). Workflow creates the `Formula/dot.rb` path on first publish. |
| Scoop | `sebastienrousseau/scoop-bucket` | Bucket repo exists (currently bare). Workflow creates `bucket/dot.json` on first publish. |
| AUR | `ssh://aur@aur.archlinux.org/dot-cli-git.git` | **Manual one-time step**: the maintainer must create the package entry via the AUR web UI before the workflow's `git clone` can succeed. The workflow exits with a clear error message on the first run if the repo doesn't exist. |

## Verifying a release

See `docs/security/VERIFY_RELEASE.md` for the consumer-facing
verification recipe. The pipeline produces four orthogonal
attestations (SBOM, Cosign signature on SBOM, SLSA provenance,
unified Cosign-signed manifest) and a verifier can check any of them
independently.

## Known caveats

- **AUR `pkgname=dot-cli-git`**: AUR's `-git` convention means
  "tracks git HEAD", but the workflow publishes tagged stable
  releases. Either rename to plain `dotfiles` in
  `install/aur/PKGBUILD` and register that package, or accept the
  misnomer. Documented in the v0.2.503 PR (#895).
- **Signed-Releases retroactive**: the unified manifest landed in
  v0.2.503. Releases v0.2.500-502 carry the SBOM bundle only.
  We do not re-tag older releases (would break consumer pins). The
  OSSF Scorecard score climbs naturally as new releases land.
- **First-tag rehearsal**: tag a `v0.2.503-rc1` once before the real
  v0.2.503 to live-test the full pipeline without burning the final
  release tag. The workflows are idempotent so a real v0.2.503 still
  works after the rc.

## See also

- `docs/security/VERIFY_RELEASE.md` — consumer-facing verification.
- `docs/security/CI_PINNING.md` — reusable workflow pin policy + the
  `bump-reusable-pins.yml` auto-bump bot.
- `docs/security/AUTOMATION_SECRETS.md` — how each automation secret
  is generated, scoped, and rotated.
- `docs/operations/ROADMAP_V0_2_503.md` — the 7-workstream plan this
  pipeline executed.
