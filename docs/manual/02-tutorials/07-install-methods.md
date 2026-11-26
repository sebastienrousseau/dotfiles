---
render_with_liquid: false
---

<!-- Moved from the README (wave 2, R2.3); the text is unchanged. -->

# Install methods

## Pre-built release archive (`dot` CLI only)

Every tag publishes `dot-<version>.tar.gz` and `.zip` with the
dispatcher, `lib/dot`, the bundled plugins and runtime scripts, the
man page, zsh / bash / fish completions,
and a `Makefile` honouring the usual install prefix and staging
directory. The archive
carries SLSA build provenance (keyless, via Fulcio + Rekor):

```bash
gh release download v0.2.555 --repo sebastienrousseau/dotfiles --pattern 'dot-*.tar.gz'
gh attestation verify dot-0.2.554.tar.gz --repo sebastienrousseau/dotfiles
tar -xzf dot-0.2.554.tar.gz
make -C dot-0.2.554 install PREFIX=/usr/local
```

[`release-install-smoke.yml`](../../../.github/workflows/release-install-smoke.yml)
repeats exactly this sequence on a clean Ubuntu and macOS runner
after every release: verify provenance, `make install` into an
empty staging directory, run `dot version`, `make uninstall`, assert
nothing is left behind.

## Package managers

| Channel | Install |
|---|---|
| Homebrew (macOS / Linux) | `brew install sebastienrousseau/tap/dot` |
| Scoop (Windows) | `scoop bucket add sebastienrousseau https://github.com/sebastienrousseau/scoop-bucket && scoop install dot` |
| AUR (Arch) | `paru -S dot-cli-git` |
| npm | `npx -p @sebastienrousseau/dotfiles dotfiles-install` (runs the same `install.sh`) |
| Nix | `nix profile install ~/.dotfiles/nix#dot-utils` after cloning; `nix develop ~/.dotfiles/nix` for the dev shell |

The Homebrew formula and Scoop manifest are regenerated per tag by
[`release-distribute-homebrew.yml`](../../../.github/workflows/release-distribute-homebrew.yml)
and
[`release-distribute-scoop.yml`](../../../.github/workflows/release-distribute-scoop.yml)
from the templates under [`pkg/`](../../../pkg/README.md); the AUR
package is pushed by
[`release-distribute-aur.yml`](../../../.github/workflows/release-distribute-aur.yml).
The per-channel templates and the maintainer runbook are in
[`pkg/README.md`](../../../pkg/README.md); the end-to-end pipeline is
[`docs/operations/RELEASE_PIPELINE.md`](../../../docs/operations/RELEASE_PIPELINE.md).

## With chezmoi directly

The repository is a chezmoi source tree (`.chezmoiroot` points at
`defaults/`), so chezmoi's own bootstrap works:

```bash
chezmoi init --apply sebastienrousseau
```

`install.sh` does the equivalent after its preflight checks: it
clones the pinned release tag to `~/.dotfiles`, points chezmoi's
`sourceDir` at it, and applies. Going direct, you give up the verified
`chezmoi` download, the pinned tag, and the `git` / `curl` checks.

## Build from source

```bash
git clone https://github.com/sebastienrousseau/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh                  # full install from the local checkout
make install PREFIX=~/.local  # or: stage only the dot CLI
```

`./install.sh --minimal` selects the `minimal` profile (written to this
host's chezmoi config) and skips `--provision`.
`dot config export ~/Downloads` builds an offline `.tar.zst` for an
air-gapped host; unpack it and run `./install.sh --force`.

<details>
<summary>CI/CD and Docker options</summary>

Silent install (no prompts):

```bash
# After downloading and verifying the installer as shown above:
DOTFILES_SILENT=1 DOTFILES_NONINTERACTIVE=1 \
  bash "$installer_dir/dotfiles-install.sh" --force
```

Docker sandbox:

```bash
docker run --rm -e DOTFILES_NONINTERACTIVE=1 ubuntu:24.04 bash -c \
  'apt-get update -qq && apt-get install -y -qq git curl sudo >/dev/null 2>&1 \
  && git clone --depth 1 https://github.com/sebastienrousseau/dotfiles.git ~/.dotfiles \
  && bash ~/.dotfiles/install.sh \
  && export PATH="$HOME/.local/bin:$PATH" \
  && dot doctor'
```

`dot config apply --sandbox` launches the same preview through Docker or Podman
from an installed machine.

</details>

## Profiles and session flags

Everything heavy is off, deferred, or cached by default. Pick a
profile per machine and flip session flags when you need less.

| Switch | Where | Effect | Documented in |
| :--- | :--- | :--- | :--- |
| `profile = "laptop"` *(default)* | `~/.config/chezmoi/chezmoi.toml` | zsh runs `compinit` by default; the OS tuning scripts use the laptop set | [`docs/reference/PROFILES.md`](../../../docs/reference/PROFILES.md) |
| `profile = "minimal"` | same | zsh skips `compinit` unless `DOTFILES_ENABLE_COMPINIT=1` | same |
| `profile = "server"` | same | As `minimal` in zsh; the OS tuning scripts use the server set | same |
| `[features]` flags | `defaults/.chezmoidata.toml` | `alias_wrapper`, `dms`, `ai_theme_sync`, `zellij`, `linux_desktop`, `niri`, `waybar`, `fuzzel`, `mako`, `foot`, `kanshi`, `touch`, `t2`, `surface`, `corral_gitea_mirror`; CI checks each is a boolean | [`docs/reference/FEATURES.md`](../../../docs/reference/FEATURES.md) |
| `DOTFILES_FAST=1` | environment | Skip heavy layers (zinit, completions, lazy runtime managers) | [Configuration](../../../README.md#configuration) |
| `DOTFILES_ULTRA_FAST=1` | environment | Bare minimum shell: paths, aliases, prompt | [`docs/ARCHITECTURE.md`](../../../docs/ARCHITECTURE.md) |
| `DOTFILES_DEFER_TOOLS=1` *(default)* | environment | Resolve heavy binaries asynchronously after the first prompt | `defaults/dot_config/zsh/dot_zshrc.tmpl` |
| `DOTFILES_AI=1` *(default)* | environment | `1` loads the zsh AI helper scripts; `1` also lets apply build `dot-ai-tui` (`0` is off) | [`docs/reference/PROFILES.md`](../../../docs/reference/PROFILES.md) |
| `DOTFILES_ARTIFACT_MODE=1` | environment | Minimal prompt plus the async Bento dashboard | [`docs/ARCHITECTURE.md`](../../../docs/ARCHITECTURE.md) |
| `DOTFILES_DEBUG=1` / `DOTFILES_TRACE=1` | environment | Per-stage startup timing / full trace to stderr | [`docs/manual/03-reference/03-environment.md`](../../../docs/manual/03-reference/03-environment.md) |
| `EVALCACHE_DISABLE=true` | environment | Bypass `_cached_eval` for debugging | [Features](../../../README.md#features) |
