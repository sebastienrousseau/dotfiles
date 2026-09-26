---
render_with_liquid: false
---

# Support Matrix

Where the dotfiles run and what CI actually exercises. Minimum versions and
their reasons are kept in [MINIMUM-TOOLCHAIN.md](../MINIMUM-TOOLCHAIN.md);
this page summarises them and must agree with it.

"CI tested" means a GitHub Actions job runs the suite on that platform for
changes to code or configuration (see the table at the end for each
workflow's triggers). Everything else is expected to work but is not
verified by CI.

## Operating Systems

| OS | Version | Architecture | Status | CI |
|----|---------|-------------|--------|----|
| macOS | 14 (Sonoma) or later | aarch64 (Apple Silicon) | Supported, primary development platform | Yes: `macos-14` and `macos-latest` (macOS 26), both Apple Silicon |
| macOS | 14 (Sonoma) or later | x86_64 (Intel) | Supported | No Intel runner; templates handle the `/usr/local` Homebrew prefix |
| Ubuntu | 22.04 or later | x86_64 | Supported | Yes: `ubuntu-latest` (24.04) |
| Ubuntu | 22.04 or later | aarch64 | Supported | No |
| Debian | 12 or later | x86_64 | Supported | No; same package versions as Ubuntu |
| WSL2 | Ubuntu 22.04 or later | x86_64 | Supported, with a clipboard bridge | No |
| NixOS | 23.11 or later | x86_64, aarch64 | Supported, via the Nix flake | `nix flake check` in CI when Nix files change |
| Fedora | 41 or later | x86_64 | Community | No |
| Arch Linux | Rolling | x86_64 | Community; AUR package published | No |
| Windows | 10 / 11 | x86_64 | PowerShell parity surface (see below) | Yes: `windows-latest` (PowerShell 7.6) |

## Shells

| Shell | Minimum | Status | Coverage | Notes |
|-------|---------|--------|----------|-------|
| Fish | 4.0 | Supported | Core CLI | The default login shell (`default_shell` in `.chezmoidata.toml`). Native `dot`, `dm`, `da`, `dmc`, `datt`, and a cached alias bridge |
| Zsh | 5.8 | Supported | Full | All features |
| Bash | 5.0 interactive; 3.2 for the `dot` CLI and scripts | Supported | Full | The shared logic core; the CLI runs on macOS's stock `/bin/bash` 3.2 |
| Nushell | 0.98 | Supported | Core CLI | Native `d`, `dm`, `da`, `dmc`, `datt` for core workflows; complex aliases are skipped |
| PowerShell | 7.4 LTS or 7.5 and later | Supported | Core CLI | Managed profile, `dot` wrapper, listing helpers and attestation aliases. CI runs PowerShell 7.6 on `windows-latest`; 7.4 itself is not exercised in CI |

## Terminal Emulators

| Terminal | Status | Notes |
|----------|--------|-------|
| Ghostty | Supported | Primary; config in `defaults/dot_config/ghostty/` |
| iTerm2 | Supported | macOS only; a Dynamic Profile is installed by `run_onchange_22-iterm2-profile.sh.tmpl` (pick the "dotfiles" profile) |
| Alacritty | Supported | Theme-driven; config in `defaults/dot_config/alacritty/` |
| Kitty | Supported | Theme-driven; config in `defaults/dot_config/kitty/` |
| WezTerm | Supported | Theme-driven; config in `defaults/dot_config/wezterm/` |
| Foot | Supported | Linux/Wayland; off by default, enabled with `features.foot`; config in `defaults/dot_config/foot/` |
| Warp | Supported | Theme-driven; deploys `~/.warp/themes/dotfiles.yaml` (pick "dotfiles" in Settings → Appearance → Themes) |
| Windows Terminal | Supported | WSL2 profile |
| tmux | Supported | Config in `defaults/dot_config/tmux/` |

## Key Tools

| Tool | Minimum | Required | Notes |
|------|---------|----------|-------|
| chezmoi | 2.72.2 | Yes | The pinned, checksum-verified version `install.sh` downloads |
| git | 2.34 | Yes | The first release with SSH commit and tag signing |
| curl | — | Yes | Used by the bootstrap installer |
| Neovim | 0.11.2 | No | Enforced by `init.lua`; the config refuses to load on older versions |
| Starship, mise, fzf, zoxide, atuin, pueue and other CLI tools | pinned | No | Versions are pinned in `mise.toml` and `mise.lock`, not held to a separate floor |
| Nix | — | No | Only for the Nix flake route |

## CI Environments

| Workflow | Platforms | Runs on |
|----------|-----------|---------|
| `ci.yml` | `ubuntu-latest`, `macos-latest`, `windows-latest` | Pull requests that change code, config or workflows; pushes to `main`; scheduled |
| `reliability-gate.yml` | `ubuntu-latest`, `macos-latest`, `macos-14` | Every pull request and push to `main` |
| `cross-platform-test.yml` | `ubuntu-latest`, `macos-latest`, `macos-14` | Pull requests that change code or config; pushes to `main`; scheduled |
| `ci-enforced.yml` | `ubuntu-latest` | Every pull request and push; stricter checks |
| `devcontainer-prebuild.yml` | `ubuntu-latest` | Pre-built development images |

Both macOS labels are Apple Silicon: `macos-14` runs macOS 14 and
`macos-latest` runs macOS 26. There is no Intel macOS runner in CI.

## Known Limitations

| Platform | Limitation | Workaround |
|----------|-----------|------------|
| WSL2 | No native clipboard | `clip.exe` / `powershell.exe` bridge aliases |
| NixOS | System packages can conflict | Use the Nix flake exclusively |
| Fish < 4.0 | No keyboard protocol | Upgrade to Fish 4 |
| Nushell | Complex aliases skipped | The core `dot` workflow remains first-class |
| macOS Intel | Homebrew lives in `/usr/local`, not `/opt/homebrew`; not covered by CI | Templates handle both prefixes |
