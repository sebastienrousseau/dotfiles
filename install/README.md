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
| `homebrew/dot.rb` | scaffold | Homebrew formula for the `dot` CLI. Publication blocked on v0.3.0 standalone-CLI tarball. |
| `scoop/dot.json` | scaffold | Scoop manifest for Windows. Same blocker as Homebrew. |
| `aur/PKGBUILD` | scaffold | Arch User Repository package definition. Same blocker. |

## Bootstrap entrypoint

The canonical install path is `install.sh` at the repo root —
**not** anything in this directory. `install.sh`:

1. Verifies `git` and `curl` are present.
2. SHA256-pins chezmoi via `scripts/ci/install-chezmoi-verified.sh`.
3. Clones the repo (or uses an existing checkout).
4. Runs `chezmoi init --apply --source <repo>`.

## Distribution scaffolds

The three manifests under `homebrew/`, `scoop/`, and `aur/` are
**scaffolds**. They will work once v0.3.0 ships a standalone-CLI
tarball that doesn't require chezmoi to render. The scaffolds are
checked in now so:

- The shape is documented before publication.
- Contributors can see what the publication checklist needs to
  cover.
- CI can validate manifest syntax on every PR (planned: add
  `taplo`/`jq` validation hooks).

### Publication checklist (per channel, v0.3.0+)

1. **Build the standalone tarball** with `scripts/release/build-dist.sh` (v0.3.0).
2. **Sign + SBOM** via the existing `security-release.yml` pipeline.
3. **Publish to each channel**:
   - Homebrew: PR to `sebastienrousseau/homebrew-tap` (separate repo) with the updated `dot.rb` + fresh SHA256.
   - Scoop: PR to `sebastienrousseau/scoop-bucket` (separate repo) with the updated `dot.json`.
   - AUR: `makepkg` + `git push` to `aur.archlinux.org/packages/dotfiles-git`.
4. **Verify locally** before announcing:

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
