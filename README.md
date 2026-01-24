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

Unlike traditional "dotfile repos" that sprawl across your home directory, this project:
1.  **Centralizes Truth**: All config lives in `~/.local/share/chezmoi` (XDG-compliant).
2.  **Guarantees Reproducibility**: Binary-pinned installers and lockfiles ensure identical setups across machines.
3.  **Prioritizes Security**: Default settings are hardened (`set -euo pipefail`), audits are logged, and secrets are strictly separated.

<!-- markdownlint-disable MD033 MD041 MD043 -->
<br>
<center>
<!-- markdownlint-enable MD033 MD041 -->

[![Getting Started][getting_started]][getting-started-url]
[![Download Dotfiles v0.2.472][download_button]][12]

<!-- markdownlint-disable MD033 MD041 MD043 -->
</center>
<br />
<!-- markdownlint-enable MD033 MD041 -->

## Features ✨

- **Universal Support**: One codebase for macOS, Linux (Ubuntu/Debian), and Windows (WSL).
- **Instant Startup**: Zsh startup time reduced to <20ms (Verified via `hyperfine`).
- **Modern Tooling**: Replaces legacy Unix tools with Rust-based alternatives for better performance and UX.
- **Security**: Hardened configurations with audit logging and strict error handling.
- **Predictive Shell**: AI-powered context autosuggestions, error analysis, and local LLM integration.
- **Modular Design**: Powered by `chezmoi` for seamless management and updates.

![divider][divider]

## Modern Tooling 🛠️

We have replaced traditional Unix commands with modern, faster, and feature-rich alternatives:

| Legacy Tool | Modern Replacement | Description |
|:---:|:---:|---|
| `ls` | **[eza](https://eza.rocks/)** | A modern, maintained replacement for `ls` with icons and git integration. |
| `cat` | **[bat](https://github.com/sharkdp/bat)** | A `cat` clone with syntax highlighting and Git integration. |
| `grep` | **[ripgrep (rg)](https://github.com/BurntSushi/ripgrep)** | Line-oriented search tool that recursively searches your current directory. |
| `cd` | **[zoxide](https://github.com/ajeetdsouza/zoxide)** | A smarter `cd` command that remembers your frequently used directories. |
| `find` | **[fd](https://github.com/sharkdp/fd)** | A simple, fast and user-friendly alternative to `find`. |
| `history` | **[atuin](https://atuin.sh)** | Sync, search and backup shell history with E2E encryption. |
| `ranger` | **[yazi](https://yazi-rs.github.io)** | Blazing fast terminal file manager written in Rust, based on async I/O. |
| `tmux` | **[zellij](https://zellij.dev)** | A terminal workspace with batteries included (layout engine, floating panes). |
| `vim` | **[NeoVim](https://neovim.io/)** | Hyperextensible Vim-based text editor (optional, config supports both). |

*Note: The installation scripts will automatically attempt to install these tools via Homebrew (macOS) or Apt (Linux).*

![divider][divider]

## Getting Started 🚀

### 1) Requirements

To install and use these dotfiles, you need:

- **Git**: To clone the repository.
- **[Chezmoi](https://www.chezmoi.io/)**: The dotfile manager used to apply configurations.
- **Nerd Font**: We recommend `Roboto Mono for Powerline` or any [Nerd Font](https://www.nerdfonts.com/) for proper icon rendering in the terminal.

### 2) Installation

We use `chezmoi` for a one-line installation process. This will:
1. Install `chezmoi`.
2. Clone this repository.
3. **Automatically** install required packages (via Homebrew on macOS or Apt on Linux).
4. Apply configurations to your home directory.

**Run the following command:**

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.472/install.sh)"
```

*Note: This will verify your system and prompt you for any necessary inputs.*

### 3) Post-Installation

After installation:
1. **Restart your terminal.**
2. You should see the `starship` prompt and have access to new aliases (e.g., try `l` for `eza`).
3. View the **[Operational Guide](docs/OPERATIONS.md)** for daily usage instructions.

![divider][divider]

## Structure 📂

The configuration is managed in `~/.local/share/chezmoi`. This is your "source" of truth.

```
~/.local/share/chezmoi/
├── dot_zshenv              # Shell entry point (XDG Bootloader)
├── dot_config/             # XDG Base Config (Mapped to ~/.config)
│   ├── atuin/              # Shell History (config.toml)
│   ├── ghostty/            # Terminal Emulator (config)
│   ├── git/                # Git Config (config)
│   ├── yazi/               # File Manager (yazi.toml)
│   ├── zellij/             # Multiplexer (config.kdl)
│   ├── zsh/                # Zsh config (.zshrc)
│   └── shell/              # Shared shell config (aliases, paths)
├── provision/              # Lifecycle scripts (install packages, fonts)
├── install.sh              # Universal Installer
├── README.md               # Documentation
└── docs/                   # Detailed documentation
```

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

### Updates
To pull the latest changes from this repository:

```bash
chezmoi update
```

![divider][divider]

## Releases 🔗

Releases are available on the [GitHub releases page][24].

![divider][divider]

## Semantic versioning policy 🚥

For transparency into our release cycle and in striving to maintain backward compatibility, `Dotfiles` follows [Semantic Versioning][25].

![divider][divider]

## History

- See [Dotfiles Release][24] for a list of changes.

## Changelog ✅

- [GitHub Releases][24] are used for changelogs.

![divider][divider]

## 📖 Code of Conduct

We are committed to preserving and fostering a diverse, welcoming
community. Please read our [Code of Conduct][04].

![divider][divider]

## ⭐️ Our Values

- We believe perfection must consider everything.
- We take our passion beyond code into our daily practices.
- We are just obsessed about creating and delivering exceptional
  solutions.

![divider][divider]

## Contribution 🤝

We welcome contributions to `Dotfiles`. Please see the
[contributing guidelines][05] for more information.

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
[20]:https://www.npmjs.com/package/@sebastienrousseau/dotfiles "Dotfiles on NPM"
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
