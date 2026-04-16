# Appendix A: Platform Support Matrix

## Supported Platforms

| OS | Version | Support | Notes |
|:---|:---|:---:|:---|
| macOS | 14 (Sonoma) | ✓ full | Primary development platform |
| macOS | 15 (Sequoia) | ✓ full | |
| macOS | 26 (Tahoe) | ✓ full | |
| Ubuntu | 22.04 LTS | ✓ full | |
| Ubuntu | 24.04 LTS | ✓ full | CI reference platform |
| Debian | 12 (Bookworm) | ✓ full | |
| Debian | 13 (Trixie) | ✓ full | |
| Arch Linux | rolling | ✓ full | |
| CachyOS | rolling | ✓ full | Arch-based |
| Fedora | 39 | ✓ | Less tested |
| Fedora | 40, 41 | ✓ | Less tested |
| openSUSE | Tumbleweed | ✓ | Less tested |
| Alpine | 3.20 | ⚠ partial | POSIX shells only; no Fish |
| WSL2 | Ubuntu 22.04+ | ✓ full | Windows 11 host |
| WSL2 | Debian | ✓ full | |
| Windows PowerShell | 7.5+ | ⚠ baseline | Aliases + prompt; no chezmoi |
| FreeBSD | 14 | ✗ untested | |
| Termux (Android) | latest | ✗ untested | |

## Supported Shells

| Shell | Version | Support |
|:---|:---|:---:|
| Fish | 3.6+ | ✓ primary |
| Zsh | 5.9+ | ✓ full |
| Bash | 5.0+ | ✓ full |
| Nushell | 0.90+ | ✓ full |
| PowerShell | 7.5+ | ⚠ baseline |

## Supported Architectures

| Arch | Status |
|:---:|:---:|
| amd64 / x86_64 | ✓ |
| arm64 / aarch64 | ✓ |
| armv7 | ⚠ best-effort |
| riscv64 | ✗ untested |

## Required Binaries

| Binary | Purpose | Install |
|:---|:---|:---|
| `git` | Version control | System package manager |
| `curl` | Installer | System package manager |
| `chezmoi` | Template engine | Installer downloads verified binary |

## Optional Binaries (installed by Mise on first apply)

| Binary | Purpose |
|:---|:---|
| `mise` | Runtime version manager |
| `age` | Secret encryption |
| `sops` | YAML secret encryption |
| `pandoc` | Manual generation |
| `shellcheck` | Shell linting |
| `shfmt` | Shell formatting |
| `starship` | Prompt |
| `fzf` | Fuzzy finder |
| `zoxide` | Smart `cd` |
| `atuin` | Shell history sync |
| `delta` | Git diff pager |
| `lazygit` | TUI Git client |
| `neovim` | Editor |

## Tested CI Environments

| Environment | Workflow |
|:---|:---|
| macOS 14 (GHA) | `ci.yml`, `ci-enforced.yml` |
| Ubuntu 24.04 (GHA) | `ci.yml`, `ci-enforced.yml` |
| GitHub Codespaces | `devcontainer-prebuild.yml` |
| Docker Ubuntu 24.04 | `ci.yml` test-docker job |

## Feature Matrix

| Feature | macOS | Linux | WSL2 |
|:---|:---:|:---:|:---:|
| Shell configs (zsh/fish/bash/nu) | ✓ | ✓ | ✓ |
| Terminal emulator configs | ✓ | ✓ | ✗ (host handles) |
| Theme engine (K-Means) | ✓ | ✓ | ✓ |
| Dynamic HEIC dark/light | ✓ native | ⚠ HEIC→PNG converted | ✗ |
| Neovim + LSP | ✓ | ✓ | ✓ |
| AI tools (Claude, Codex, etc.) | ✓ | ✓ | ✓ |
| MCP policy enforcement | ✓ | ✓ | ✓ |
| Attestation | ✓ | ✓ | ✓ |
| Fleet (SSH-based) | ✓ | ✓ | ⚠ |
| AeroSpace (WM) | ✓ | ✗ | ✗ |
| Niri (WM) | ✗ | ✓ | ✗ |
| GNOME gsettings | ✗ | ✓ | ⚠ |
| Build artifact redirect | ✓ | ✓ | ✓ |
| Self-healing (`dot heal`) | ✓ | ✓ | ✓ |
