# `install/`: bootstrap helpers, provisioning and migration

This directory holds the pieces `install.sh` (at the repo root) calls
on: opt-in toolchain provisioning, shared helpers, and the 0.2.503
layout migration. The packaging templates for downstream package
managers live in [`../pkg/`](../pkg/README.md).

## Layout

| Path | Status | Purpose |
|------|--------|---------|
| `provision/` | opt-in | Toolchain provisioning: `run_once_install_{zsh,fish}.sh.tmpl`, then the numbered `run_onchange_*` scripts (`10-darwin-packages`, `10-linux-packages`, `12-tmux-plugins`, `15-ai-cli-tools`, `20-darwin-defaults`, `20-linux-flatpak`, `25-python-tools`, `26-rust-tools`, `27-go-tools`, `30-darwin-mas`, `30-vscode-extensions`, `40-darwin-default-apps`, `50-install-fonts`), plus `run_before_00-audit.sh` and `run_before_00-migrate-v0_2_503.sh.tmpl`. The directory sits outside `.chezmoiroot` (`defaults`), so `chezmoi apply` never runs any of it. `install.sh --provision` (or `DOTFILES_PROVISION=1`) runs the `run_once_install_*` and `run_onchange_*` scripts in sorted order, rendering `.tmpl` files with `chezmoi execute-template`; the two `run_before_*` scripts are not run by anything. |
| `lib/` | active | Shared helpers sourced by the provisioning scripts. |
| `migrate/` | active | The 0.2.503 layout migration, run by `install.sh` before apply. See [`migrate/README.md`](migrate/README.md). |
| `run_before_cleanup.sh` | unused | Removes a few legacy files from `$HOME`. It is outside `.chezmoiroot` and nothing calls it, so it never runs. |

## Bootstrap entrypoint

The canonical install path is `install.sh` at the repo root —
**not** anything in this directory. `install.sh`:

1. Installs chezmoi if it is missing: with Homebrew when `brew` is on
   `PATH`; otherwise into `~/.local/bin` through
   `tools/ci/install-chezmoi-verified.sh` (SHA-256 pinned) when run
   from a checkout, or through the same pinned verifier embedded in
   `install.sh` when run as the standalone release installer. It never
   falls back to an unverified script. `gum` is bootstrapped in
   parallel for the UI, and its failure is ignored.
2. Backs up every file `chezmoi managed` lists to
   `~/.dotfiles.bak.<ts>`. This only happens when a chezmoi config
   exists at this point: an existing `~/.dotfiles` or
   `~/.local/share/chezmoi` git checkout gets one written for it, and
   an earlier chezmoi setup may have one. A first install from the
   release installer has neither, so nothing is backed up.
3. Runs `install/migrate/migrate-v0_2-to-v0_2_503.sh` from whichever
   of those two checkouts has it.
4. Picks the source: `~/.dotfiles` if it is a git checkout; else moves
   a git checkout at `~/.local/share/chezmoi` to `~/.dotfiles`; else
   clones the requested tag (default: the release the installer
   belongs to; `install.sh --help` names it) into `~/.dotfiles`.
5. Writes `sourceDir` into `~/.config/chezmoi/chezmoi.toml`, keeping
   the rest of an existing config, and seeds `name`, `email` and
   `signingkey` from `git config --global` when the file has no
   `[data]` table.
6. Runs `chezmoi apply` (with `--force --no-tty` under `--force`).
7. With `--provision`, runs `install/provision/` as described above;
   without it, prints how to.

`--minimal` writes `profile = "minimal"` into the host's chezmoi
config and skips provisioning. A container (`/.dockerenv`,
Codespaces, Dev Containers) gets the minimal profile too, but still
provisions if asked. Run `install.sh --help` for every option.

## Distribution templates

The Homebrew formula, Scoop manifest and AUR PKGBUILD are in
`pkg/brew/`, `pkg/scoop/` and `pkg/aur/`. They are **templates** the
release pipeline rewrites per tag. End-to-end flow: signed tag pushed,
then `gh release create <tag> --verify-tag` → `release-package-dot.yml`
produces the `dot-VERSION.{tar.gz,zip}` artefacts on
`release.created` → on `release.published`, `security-release.yml`
signs SBOM + unified manifest while the three
`release-distribute-*.yml` workflows hash the new artefacts, rewrite
the per-channel template, and publish.

See `docs/operations/RELEASE_PIPELINE.md` for the full pipeline.

### Publication checklist (per channel, v0.2.503+)

The pipeline runs automatically once the Release exists. Each
workflow also takes `workflow_dispatch` with a `release_tag` input if
you need to re-run a single channel out-of-band.

1. **Tag and create the release**:
   `git tag -s vX.Y.Z -m "Release vX.Y.Z" && git push origin vX.Y.Z`,
   then `gh release create vX.Y.Z --verify-tag`. A tag push alone
   creates no Release and starts none of the steps below.
2. **`release-package-dot.yml`** produces `dot-VERSION.tar.gz` + `.zip` on `release.created`.
3. **`security-release.yml`** generates SBOM + Cosign sig + SLSA provenance + unified `ALL_SHA256SUMS` manifest.
4. **`release-distribute-*.yml`** fan out:
   - Homebrew: PR to `sebastienrousseau/homebrew-tap` with the regenerated `dot.rb`.
   - Scoop: PR to `sebastienrousseau/scoop-bucket` with the regenerated `dot.json` (both 64bit + arm64 point at the same zip).
   - AUR: direct push to `ssh://aur@aur.archlinux.org/dot-cli-git.git` (requires `AUR_SSH_KEY` secret and a pre-existing AUR package entry).
5. **Verify from the published channels** before announcing, once the
   tap and bucket PRs are merged. The in-repo `pkg/` files are
   templates with stale or placeholder digests, so do not install
   from them directly.

   ```sh
   # macOS / Linux
   brew install sebastienrousseau/tap/dot && dot version

   # Windows
   scoop bucket add sebastienrousseau https://github.com/sebastienrousseau/scoop-bucket
   scoop install dot; dot version

   # Arch
   paru -S dot-cli-git; dot version
   ```

## See also

- `docs/operations/RELEASE_PIPELINE.md`: the release pipeline.
- [`../pkg/README.md`](../pkg/README.md) and
  [`../pkg/VERIFY.md`](../pkg/VERIFY.md): packaging templates and
  artefact verification.
