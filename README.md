<!-- markdownlint-disable MD033 MD041 MD043 -->

<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>

<!-- markdownlint-enable MD033 MD041 -->

# Dotfiles (v0.2.472)

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

Dotfiles v0.2.472 transforms your shell into a **Trusted Platform**. It is a curated, high-performance distribution of configurations, managed by `chezmoi`.

This project aims to provide a reproducible and optimized development environment for macOS, Linux, and Windows (via WSL).

![divider][divider]

## Features ✨

- **Shell:**
    - **`zsh`** as the default shell, with a rich set of plugins managed by **`zinit`**.
    - **`starship`** for a modern, fast, and customizable prompt.
    - **`fzf`** for fuzzy finding files, commands, and more.
    - **`zoxide`** for a smarter `cd` command that remembers your frequently used directories.
    - **`atuin`** for a powerful shell history with synchronization and search capabilities.
- **Terminal:**
    - **`zellij`** as a terminal workspace and multiplexer.
    - **`ghostty`** as a fast, GPU-accelerated terminal emulator.
- **Development:**
    - **Neovim (Nightly)** as the primary text editor, with a modern Lua-based configuration using `lazy.nvim`.
    - **Go**, **Rust**, **Node.js**, and **Python** development environments managed by `go`, `rustup`, `fnm`, and `uv` respectively.
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

```bash
# Install Homebrew if you don't have it already
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install git curl zsh go starship zoxide fzf atuin zellij ghostty neovim lazygit delta tldr dust duf gping procs bottom hyperfine hexyl jq yq gum glow gh glab ollama fabric-cli uv
brew tap homebrew/cask-fonts
brew install --cask font-fira-code-nerd-font
```
</details>

<details>
<summary><strong>Debian / Ubuntu</strong></summary>

```bash
# Update package list and install dependencies
sudo apt-get update
sudo apt-get install -y git curl zsh golang-go build-essential

# Install Starship
curl -sS https://starship.rs/install.sh | sh

# Install other tools (manual steps)
echo "Please install the following tools manually:"
echo "zoxide, fzf, atuin, zellij, ghostty, neovim (nightly), lazygit, delta, tldr, dust, duf, gping, procs, bottom, hyperfine, hexyl, jq, yq, gum, glow, gh, glab, ollama, fabric, uv"
echo "You can find installation instructions on their respective websites."

# Install a Nerd Font (manual steps)
echo "Please install a Nerd Font manually from https://www.nerdfonts.com/font-downloads"
```
</details>

<details>
<summary><strong>Arch Linux</strong></summary>

```bash
# Update package list and install dependencies
sudo pacman -Syu git curl zsh go starship zoxide fzf atuin zellij neovim lazygit python-pipx
pipx install git+https://github.com/dandavison/delta.git

# Install other tools from AUR or other sources
echo "Please install ghostty and other tools from the AUR or other sources."

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

This command will install `chezmoi` and apply the dotfiles.

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.472/install.sh)"
```

### 2. Manual Installation

<details>
<summary><strong>Manual installation steps</strong></summary>

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/sebastienrousseau/dotfiles.git ~/.local/share/chezmoi
    ```

2.  **Initialize `chezmoi`:**
    ```bash
    chezmoi init
    ```

3.  **Apply the dotfiles:**
    ```bash
    chezmoi apply
    ```
</details>

### Post-Installation

After installation, restart your terminal to apply the changes.

![divider][divider]

## Usage 📖

### Applying Changes

After editing any file in `~/.local/share/chezmoi`, run:

```bash
chezmoi apply
```

To see what will change before applying:

```bash
chezmoi diff
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
[12]: https://github.com/sebastienrousseau/dotfiles/archive/refs/tags/v0.2.472.tar.gz "Download Dotfiles v0.2.472"
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

[getting-started-url]: https://github.com/sebastienrousseau/dotfiles#getting-started

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg "Banner of Dotfiles"
[codacy-grade]: https://img.shields.io/codacy/grade/634cfc4de08e492ebcbb341631066241?style=for-the-badge "Codacy grade"
[contributors-shield]: https://img.shields.io/github/contributors/sebastienrousseau/dotfiles.svg?style=for-the-badge "Contributors"

[divider]: https://kura.pro/common/images/elements/divider.svg "Divider"
[download_button]: https://kura.pro/common/images/buttons/button-secondary.svg "Download"
[forks-shield]: https://img.shields.io/github/forks/sebastienrousseau/dotfiles.svg?style=for-the-badge "Forks"
[getting_started]: https://kura.pro/common/images/buttons/button-primary.svg "Getting Started"
[license]: https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge\&color=ff69b4 "License"
[love]: https://kura.pro/common/images/shields/made-with-love.svg "Made with Love"


