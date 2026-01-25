<!-- markdownlint-disable MD033 MD041 MD043 -->

<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>

<!-- markdownlint-enable MD033 MD041 -->

# Dotfiles (v0.2.473)

Simply designed to fit your shell life 🐚

<!-- markdownlint-disable MD033 MD041 MD043 -->
<center>
<!-- markdownlint-enable MD033 MD041 -->

![Dotfiles banner][banner]

[![Codacy][codacy-grade]][06]
[![Contributors][contributors-shield]][14]
[![Forks][forks-shield]][13]
[![License][license]][02]
[![Love][love]][00]

• [Website][00] • [Documentation][16]
• [Report Bug][17] • [Request Feature][17]
• [Contributing Guidelines][05]

<!-- markdownlint-disable MD033 MD041 MD043 -->
</center>
<!-- markdownlint-enable MD033 MD041 -->

![divider][divider]

## Overview 📖

Dotfiles v0.2.473 transforms your shell into a **Trusted Platform**. It is a curated, high-performance distribution of configurations, managed by `chezmoi`.

This project aims to provide a reproducible and optimized development environment for macOS, Linux, and Windows (via WSL).

<!-- markdownlint-disable MD033 MD041 MD043 -->
<br>
<center>
<!-- markdownlint-enable MD033 MD041 -->

[![Getting Started][getting_started]][getting-started-url]
[![Download Dotfiles v0.2.473][download_button]][12]

<!-- markdownlint-disable MD033 MD041 MD043 -->
</center>
<br />
<!-- markdownlint-enable MD033 MD041 -->

## Features ✨

- **Shell:**
    - **`zsh`** configuration with a rich set of plugins managed by **`zinit`** (recommended default shell).
    - **`starship`** for a modern, fast, and customizable prompt.
    - **`fzf`** for fuzzy finding files, commands, and more.
    - **`zoxide`** for a smarter `cd` command that remembers your frequently used directories.
    - **`atuin`** for a powerful shell history with synchronization and search capabilities.
- **Terminal:**
    - **`zellij`** as a terminal workspace and multiplexer (manual install on Linux).
    - **`ghostty`** as a fast, GPU-accelerated terminal emulator (manual install on Linux).
- **Development:**
    - **Neovim (Nightly)** as the primary text editor, with a modern Lua-based configuration using `lazy.nvim`.
    - **Go**, **Rust**, and **Python** development environments supported (Go/Rust require manual install on Linux; macOS via Brewfile).
    - A comprehensive set of LSPs, linters, and formatters managed by `mason.nvim`.
- **CLI Tools:**
    - Modern replacements for core Unix utilities: `eza` (ls), `bat` (cat), `fd` (find), `ripgrep` (grep).
    - **`lazygit`** and **`delta`** for an enhanced Git experience.
    - A rich set of other CLI tools for networking, system monitoring, and more.
- **AI Integration:**
    - **`ollama`** for running large language models locally.
    - **`fabric`** for augmenting humans using AI.
- **System Tuning:**
    - Performance tuning for the kernel and browser optimization for a better developer experience.

![divider][divider]

## Prerequisites

Before you begin, ensure you have the following dependencies installed on your system.

<details>
<summary><strong>macOS</strong></summary>

The `Brewfile.cli` and `Brewfile.cask` files in this repository are the source of truth for dependencies on macOS. The `install/provision/run_onchange_10-darwin-packages.sh.tmpl` script will automatically install all CLI and GUI packages using `brew bundle`.

Optional macOS extras:
- **Mac App Store apps** via `mas` using `~/.config/mas/masapps.txt`.
- **Default app bindings** via `duti` using `~/.config/duti/defaults.duti`.

Apply changes with `chezmoi apply` after editing these files.

</details>

<details>
<summary><strong>Debian / Ubuntu</strong></summary>

The `install/provision/run_onchange_10-linux-packages.sh.tmpl` script will attempt to install most of the dependencies using `apt-get`, `curl`, and verified GitHub release downloads. `cargo` is required for `delta`.

```bash
# Update package list and install base dependencies
sudo apt-get update
sudo apt-get install -y git curl zsh build-essential ripgrep fd-find bat jq yq

# Install Rust to get cargo (required for delta)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

The following tools will be installed by the script (Linux):
- `starship`, `zoxide`, `fzf`, `neovim` (nightly), `lazygit`, `atuin`, `zellij`, `delta` (via cargo), `uv`.

The following tools need to be installed manually (Linux):
- `ghostty`, `yazi`, `ollama`, `fabric`, `go`, `rustup` (if not already installed).

</details>

<details>
<summary><strong>Arch Linux</strong></summary>

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.473/install.sh)"

# Install a Nerd Font
sudo pacman -S ttf-fira-code
```
</details>

<details>
<summary><strong>Windows (WSL)</strong></summary>

Follow the instructions for your chosen Linux distribution within WSL.
</details>

![divider][divider]

## Getting Started 🚀

### 1. One-line Installation (Recommended)

This command will install `chezmoi` and apply the dotfiles. The installation script will also attempt to install all the necessary dependencies for your platform.

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.473/install.sh)"
```

### 2. Manual Installation

<details>
<summary><strong>Manual installation steps</strong></summary>

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/sebastienrousseau/dotfiles.git ~/.dotfiles
    ```

2.  **Run the provisioning scripts:**
    ```bash
    chezmoi apply
    ```
</details>

### Post-Installation

After installation, restart your terminal to apply the changes.

![divider][divider]

## Usage 📖

### Applying Changes

After editing any file in `~/.dotfiles`, run:

```bash
chezmoi apply
```

To see what will change before applying:

```bash
chezmoi diff
```

### VS Code Extensions

List extensions in `~/.config/vscode/extensions.txt` and run:

```bash
chezmoi apply
```

### Dot CLI

Common commands:

```bash
dot sync      # Apply dotfiles (chezmoi apply)
dot update    # Pull latest changes and apply
dot tools     # Show dot utils
dot keys      # Show keybindings
dot tune      # Apply OS tuning (opt-in)
dot theme     # Switch terminal theme (dark/light)
dot secrets   # Edit encrypted secrets (age)
dot upgrade   # Update flake, plugins, and dotfiles
dot new       # Scaffold a project template (python/go/node)
dot log-rotate # Rotate ~/.local/share/dotfiles.log
dot
dot
dot doctor
dot sandbox
dot benchmark
dot wallpaper
dot ssh-key
dot secrets-create
dot fonts
dot firewall
dot telemetry
dot dns-doh
dot encrypt-check
dot backup
dot lock-screen
dot usb-safety
dot secrets-init
dot edit
dot docs
dot learn
dot help```

### Optional Nix Toolchain

If you want reproducible binaries without changing the `chezmoi` workflow:

```bash
cd ~/.dotfiles
nix develop
```

### Secrets (age)

```bash
dot secrets-init
dot secrets
```

### Profiles & Features

You can customize what gets applied per host using `.chezmoidata.toml`:

```toml
profile = "laptop"
theme = "tokyonight-night"
terminal_font_family = "JetBrains Mono"
terminal_font_size = 12

[features]
zsh = true
nvim = true
tmux = true
gui = true
secrets = true
```

### Theme Switching

```bash
dot theme list
dot theme set catppuccin-latte
dot theme toggle
```

Available themes:
- `tokyonight-night` (best dark default)
- `tokyonight-day` (best light default)
- `tokyonight-storm`
- `tokyonight-moon`
- `dracula`
- `gruvbox-dark`
- `gruvbox-light`
- `nord`
- `onedark`
- `onelight`
- `solarized-dark`
- `solarized-light`
- `catppuccin-mocha`
- `catppuccin-latte`
- `rose-pine`
- `rose-pine-moon`
- `rose-pine-dawn`
- `everforest-dark`
- `everforest-light`
- `kanagawa-wave`
- `kanagawa-dragon`
- `kanagawa-lotus`

### Theme Gallery

Screenshots live in `docs/themes/README.md` with a capture checklist.


### Wallpapers

```bash
dot wallpaper
```

Set a wallpaper from `~/Pictures/Wallpapers` (override with `DOTFILES_WALLPAPER_DIR`).

### Fonts

```bash
dot fonts
```

Installs Nerd Fonts and refreshes the font cache on Linux.

To install fonts during upgrades:

```bash
DOTFILES_FONTS=1 dot upgrade
```

### Flatpak (Linux)

Populate `~/.config/flatpak/flatpak.list` and re-run `chezmoi apply`.

### Containers (Docker/Podman)

Docker config template is managed at `~/.config/docker/config.json`.
Podman defaults are managed at `~/.config/containers/containers.conf`.

### Security Hardening

```bash
DOTFILES_FIREWALL=1 dot firewall
```

GPG agent defaults live in `~/.config/gnupg/gpg-agent.conf`.

```bash
DOTFILES_TELEMETRY=1 dot telemetry
DOTFILES_DOH=1 dot dns-doh
dot encrypt-check
dot backup
DOTFILES_LOCK=1 dot lock-screen
DOTFILES_USB_SAFETY=1 dot usb-safety
```

### Secrets

```bash
dot secrets-create
dot secrets
```

### Personal Details (Git)

This repo ships a `.chezmoi.toml.tmpl` with safe placeholders. Set your values
locally (not committed) and re-apply:

```bash
chezmoi init --apply --promptDefaults
```

Or edit the config directly:

```bash
${EDITOR:-nano} ~/.config/chezmoi/chezmoi.toml
```

Fields to update:
- `git_name`
- `git_email`
- `git_signingkey`
- `git_signingformat` (ssh/gpg)

### DevContainer / Codespaces

If you use VS Code or Codespaces, a minimal devcontainer is available:

```
.devcontainer/devcontainer.json
```

### Updating

To pull the latest changes from this repository:

```bash
chezmoi update
```

![divider][divider]

## Troubleshooting

<details>
<summary><strong>Icons are not rendering correctly</strong></summary>
This is likely an issue with your terminal font. Ensure you have installed a Nerd Font and configured your terminal to use it.
</details>

<details>
<summary><strong>`chezmoi` command not found</strong></summary>
If the `chezmoi` command is not found after installation, you may need to add `~/.local/bin` to your `PATH`. Add the following line to your `.zshrc` or `.bashrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```
</details>

![divider][divider]

## Releases 🔗

Releases are available on the [GitHub releases page][24].

![divider][divider]

## Contribution 🤝

We welcome contributions to `Dotfiles`. Please see the
[contributing guidelines](.github/CONTRIBUTING.md) for more information.

Unless you explicitly state otherwise, any contribution intentionally
submitted for inclusion in the work by you, as defined in the
Apache-2.0 license, shall be dual licensed as above, without any
additional terms or conditions.

![divider][divider]

## License 📝

The project is licensed under the terms of both the MIT license and the
Apache License (Version 2.0).

- [Apache License, Version 2.0][01]
- [MIT license][02]

![divider][divider]

[00]: https://dotfiles.io
[01]: https://opensource.org/license/apache-2-0/ "Apache License, Version 2.0"
[02]: https://opensource.org/licenses/MIT "The MIT License"
[03]: https://www.gnu.org/software/bash/ "GNU Bash"
[04]: https://github.com/sebastienrousseau/dotfiles/blob/master/.github/CODE-OF-CONDUCT.md "Code of Conduct"
[05]: https://github.com/sebastienrousseau/dotfiles/blob/master/.github/CONTRIBUTING.md "Contributing Guidelines"
[06]:https://www.codacy.com/gh/sebastienrousseau/dotfiles/dashboard "Codacy"
[07]: https://curl.se/ "cURL"
[08]: https://www.debian.org/ "Debian"
[09]: https://www.deepin.org/en/ "Deepin"
[10]: https://devuan.org/ "Devuan"
[11]: https://github.com/sebastienrousseau/dotfiles/docs "Documentation"
[12]: https://github.com/sebastienrousseau/dotfiles/archive/refs/tags/v0.2.473.tar.gz "Download Dotfiles v0.2.473"
[13]: https://github.com/sebastienrousseau/dotfiles/network/members "List of members"
[14]: https://github.com/sebastienrousseau/dotfiles/graphs/contributors "List of contributors"
[15]: https://git-scm.com/ "Git"
[16]: https://github.com/sebastienrousseau/dotfiles "Dotfiles"
[17]: https://github.com/sebastienrousseau/dotfiles/issues "Issues"
[18]: https://www.kali.org/ "Kali Linux"
[19]: https://www.gnu.org/software/make/ "GNU Make"
[20]: https://www.npmjs.com/package/@sebastienrousseau/dotfiles "Dotfiles on NPM"
[21]: https://pnpm.io "PnPM"
[22]: https://pop.system76.com/ "Pop!_OS"
[23]: https://q4os.org/ "Q4OS"
[24]: https://github.com/sebastienrousseau/dotfiles/releases "Dotfiles Releases"
[25]: http://semver.org/ "Semantic Versioning"
[26]: https://www.gnu.org/software/shell/ "GNU Shell"
[27]: https://ubuntu.com/ "Ubuntu"
[28]: https://www.gnu.org/software/wget/ "GNU Wget"
[29]: https://zorinos.com/ "Zorin OS"
[30]: https://www.zsh.org/ "Zsh"

[getting-started-url]: #getting-started-

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg "Banner of Dotfiles"
[codacy-grade]: https://img.shields.io/codacy/grade/634cfc4de08e492ebcbb341631066241?style=for-the-badge "Codacy grade"
[contributors-shield]: https://img.shields.io/github/contributors/sebastienrousseau/dotfiles.svg?style=for-the-badge "Contributors"

[divider]: https://kura.pro/common/images/elements/divider.svg "Divider"
[download_button]: https://kura.pro/common/images/buttons/button-secondary.svg "Download"
[forks-shield]: https://img.shields.io/github/forks/sebastienrousseau/dotfiles.svg?style=for-the-badge "Forks"
[getting_started]: https://kura.pro/common/images/buttons/button-primary.svg "Getting Started"
[license]: https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge\&color=ff69b4 "License"
[love]: https://kura.pro/common/images/shields/made-with-love.svg "Made with Love"
