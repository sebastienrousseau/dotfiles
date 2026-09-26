---
render_with_liquid: false
---

# Appendix A: Platform Support Matrix

## Supported Platforms

This appendix follows the [support matrix](../../reference/SUPPORT_MATRIX.md),
which is the source of truth; minimum versions and their reasons are in
[MINIMUM-TOOLCHAIN.md](../../MINIMUM-TOOLCHAIN.md).

| OS | Version | Architecture | Status | CI |
|:---|:---|:---|:---|:---|
| macOS | 14 (Sonoma) or later | aarch64 (Apple Silicon) | Supported, primary development platform | Yes: `macos-14` and `macos-latest` (macOS 26) |
| macOS | 14 (Sonoma) or later | x86_64 (Intel) | Supported | No Intel runner |
| Ubuntu | 22.04 or later | x86_64 | Supported | Yes: `ubuntu-latest` (24.04) |
| Ubuntu | 22.04 or later | aarch64 | Supported | No |
| Debian | 12 or later | x86_64 | Supported | No |
| WSL2 | Ubuntu 22.04 or later | x86_64 | Supported, with a clipboard bridge | No |
| NixOS | 23.11 or later | x86_64, aarch64 | Supported, via the Nix flake | `nix flake check` when Nix files change |
| Fedora | 41 or later | x86_64 | Community | No |
| Arch Linux | Rolling | x86_64 | Community; AUR package published | No |
| Windows | 10 / 11 | x86_64 | PowerShell 7.5+: managed profile, `dot` wrapper, aliases | Yes: `windows-latest` (PowerShell 7.6) |

## Supported Shells

| Shell | Minimum | Coverage |
|:---|:---|:---|
| Fish | 4.0 | Core CLI; the default login shell |
| Zsh | 5.8 | Full |
| Bash | 5.0 interactive; 3.2 for the `dot` CLI | Full |
| Nushell | 0.98 | Core CLI |
| PowerShell | 7.5+ | Core CLI |

## Supported Architectures

| Arch | Status |
|:---|:---|
| x86_64 | Supported; CI on Linux and Windows |
| aarch64 | Supported; CI on macOS |

## Required Binaries

| Binary | Purpose | Install |
|:---|:---|:---|
| `git` | Version control | System package manager |
| `curl` | Installer | System package manager |
| `chezmoi` | Template engine | Installer downloads verified binary |

## Optional Binaries

Runtimes and some CLI tools are pinned in `mise.toml` and `mise.lock`
(for example node, go, rust, starship, zoxide, sops, nushell and gum).
The rest come from the system package manager during provisioning: the
Homebrew Brewfiles on macOS and the package script on Linux (for example
fzf, atuin, delta, lazygit, neovim, shellcheck and age). `pandoc` and
`shfmt` are only needed to build the manual or lint the repository.

## Tested CI Environments

| Workflow | Platforms | Runs on |
|:---|:---|:---|
| `ci.yml` | `ubuntu-latest`, `macos-latest`, `windows-latest`; an Ubuntu container job | Pull requests that change code, config or workflows; pushes to `main`; scheduled |
| `reliability-gate.yml` | `ubuntu-latest`, `macos-latest`, `macos-14` | Every pull request and push to `main` |
| `cross-platform-test.yml` | `ubuntu-latest`, `macos-latest`, `macos-14` | Pull requests that change code or config; pushes to `main`; scheduled |
| `ci-enforced.yml` | `ubuntu-latest` | Every pull request and push |
| `devcontainer-prebuild.yml` | `ubuntu-latest` | Pre-built Codespaces images |

## Feature Matrix

| Feature | macOS | Linux | WSL2 |
|:---|:---:|:---:|:---:|
| Shell configs (zsh/fish/bash/nu) | ✓ | ✓ | ✓ |
| Terminal emulator configs | ✓ | ✓ | ✗ (host handles) |
| Theme engine (K-Means) | ✓ | ✓ | ✓ |
| Dynamic HEIC dark/light | ✓ native | ⚠ PNG frames from `scripts/theme/extract-heic-frames.sh` | ✗ |
| Neovim + LSP | ✓ | ✓ | ✓ |
| AI tools (Claude, Codex, etc.) | ✓ | ✓ | ✓ |
| MCP policy and registry inspection (`dot mcp`) | ✓ | ✓ | ✓ |
| Attestation | ✓ | ✓ | ✓ |
| Fleet (SSH-based) | ✓ | ✓ | ⚠ |
| Niri (WM) | ✗ | ✓ | ✗ |
| GNOME gsettings | ✗ | ✓ | ⚠ |
| Build artifact redirect (`DOT_BUILD_ROOT`) | ✓ | ✓ | ✓ |
| Self-healing (`dot heal`) | ✓ | ✓ | ✓ |
