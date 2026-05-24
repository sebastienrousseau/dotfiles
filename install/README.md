# `install/` — Bootstrap + Distribution

This directory holds everything related to installing the
framework — both the canonical `install.sh` bootstrap path and
the distribution-channel manifests for downstream package
managers.

## Layout

| Path | Status | Purpose |
|------|--------|---------|
| `provision/` | active | Chezmoi `run_onchange_*` hooks that fire on `chezmoi apply` — `00-system-deps.sh.tmpl`, `10-linux-packages.sh.tmpl`, `20-darwin-defaults.sh.tmpl`, `30-darwin-mas.sh`, `40-darwin-default-apps.sh`, `50-install-fonts.sh`. |
| `lib/` | active | Shared helpers for provisioning scripts. |
| `run_before_cleanup.sh` | active | Pre-apply cleanup hook (chezmoi `run_before_` convention). |
| `homebrew/dot.rb` | template | Homebrew formula for the `dot` CLI. Bumped per release by `.github/workflows/release-distribute-homebrew.yml` (PR to `sebastienrousseau/homebrew-tap`). |
| `scoop/dot.json` | template | Scoop manifest for Windows. Bumped per release by `.github/workflows/release-distribute-scoop.yml` (PR to `sebastienrousseau/scoop-bucket`). |
| `aur/PKGBUILD` | template | Arch User Repository package definition. Bumped per release by `.github/workflows/release-distribute-aur.yml` (push to `ssh://aur@aur.archlinux.org/dotfiles-git.git`). First-time publication requires the AUR package entry to exist (manual web-UI step). |

## Bootstrap entrypoint

The canonical install path is `install.sh` at the repo root —
**not** anything in this directory. `install.sh`:

1. Verifies `git` and `curl` are present.
2. SHA256-pins chezmoi via `tools/ci/install-chezmoi-verified.sh`.
3. Clones the repo (or uses an existing checkout).
4. Runs `chezmoi init --apply --source <repo>`.

## Distribution templates

The three manifests under `homebrew/`, `scoop/`, and `aur/` are
**templates** the release pipeline rewrites per tag. End-to-end
flow: tag push → `release-package-dot.yml` produces the
`dot-VERSION.{tar.gz,zip}` artefacts → `security-release.yml` signs
SBOM + unified manifest → the three `release-distribute-*.yml`
workflows hash the new artefacts, rewrite the per-channel template,
and publish.

See `docs/operations/RELEASE_PIPELINE.md` for the full pipeline.

### Publication checklist (per channel, v0.2.503+)

The pipeline runs automatically on `release.published`. The list
below is the manual fallback if you need to publish a hotfix or
re-test a specific channel out-of-band.

1. **Tag the release**: `git tag v0.2.503 && git push --tags`.
2. **`release-package-dot.yml`** produces `dot-VERSION.tar.gz` + `.zip` on `release.created`.
3. **`security-release.yml`** generates SBOM + Cosign sig + SLSA provenance + unified `ALL_SHA256SUMS` manifest.
4. **`release-distribute-*.yml`** fan out:
   - Homebrew: PR to `sebastienrousseau/homebrew-tap` with the regenerated `dot.rb`.
   - Scoop: PR to `sebastienrousseau/scoop-bucket` with the regenerated `dot.json` (both 64bit + arm64 point at the same zip).
   - AUR: direct push to `ssh://aur@aur.archlinux.org/dotfiles-git.git` (requires `AUR_SSH_KEY` secret and a pre-existing AUR package entry).
5. **Verify locally** before announcing:

   ```sh
   # macOS
   brew install --build-from-source install/homebrew/dot.rb && dot version

   # Windows
   scoop install install/scoop/dot.json; dot version

   # Arch
   cd install/aur && makepkg -si; dot version
   ```

## See also

- `docs/operations/ROADMAP_V0_2_503.md` workstream F.
- `docs/operations/HARD_AUDIT_2026.md` §8.5 — Top-5 de-facto-adoption gaps include all three of these.
