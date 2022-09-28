# Dotfiles

![Banner representing the Dotfiles Library](/assets/dotfiles.svg)

![Codacy grade](https://img.shields.io/codacy/grade/634cfc4de08e492ebcbb341631066241?style=for-the-badge)
[![Contributors][contributors-shield]](https://github.com/sebastienrousseau/dotfiles/graphs/contributors)
[![Forks][forks-shield]](https://github.com/sebastienrousseau/dotfiles/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge\&color=ff69b4)](https://opensource.org/licenses/MIT)
![Made with Love](/assets/made-with-love.svg)

## About Dotfiles

Dotfiles aggregates a collection of standalone configuration files (dotfiles)
combined into a `shell` directory that can be used to customize your development
environment across numerous computers and operating systems (macOS, Windows,
Linux).

The Dotfiles provides modular configuration files (aliases, functions and paths)
built for speed, higher performance, with the aim of helping you have an easy
and centralized way to configure your environment and applications.

### Documentation

To read the documentation for Dotfiles, please visit:

- [Dotfiles website](https://dotfiles.io/)
- [Dotfiles GitHub repository](https://github.com/sebastienrousseau/dotfiles)

### Pre-Installation

- [**PnPM**](https://pnpm.io) is currently required to install Dotfiles. PnPM is
  a package manager for JavaScript and Node.js. It is fast, disk space efficient
  and reliable. This is recommended for installing Dotfiles with ease and speed.

## Installation Guide

We are so delighted that you have decided to try Dotfiles, and are sure that you
will find Dotfiles unique and helpful.

Dotfiles aims to bring high quality and easy to use configuration files to your
development environments.

We understand that you may want to install Dotfiles without reading long manuals
and documentation. So we have tried to make the installation process as easy as
we can.

However, we recommend that you read the below guidelines before installing
Dotfiles. A few different installation methods are available to you, depending
on your needs and preferences.

### Download Dotfiles v0.2.451

You can download the latest version (v0.2.451) with the following options:

- [**Manual download**](https://github.com/sebastienrousseau/dotfiles/archive/refs/tags/v0.2.450.zip)
  Download the latest release of the Dotfiles and extract the archive in your
  home directory. This is the easiest way to install Dotfiles.
- [**Install with PnPM**](https://www.npmjs.com/package/@sebastienrousseau/dotfiles)
  `pnpm i -g @sebastienrousseau/dotfiles`. This will install the latest version
  of the Dotfiles package globally on your system.
- [**Install with Npm**](https://www.npmjs.com/package/@sebastienrousseau/dotfiles)
  `npm install -g @sebastienrousseau/dotfiles`. This will install the latest version
  of the Dotfiles package globally on your system.
- [**Install with Yarn**](https://yarnpkg.com/package/@sebastienrousseau/dotfiles)
  `yarn global add @sebastienrousseau/dotfiles`. This will install the latest version
  of the Dotfiles package globally on your system.
- **Clone the main repository** to get all source files including build scripts:
  `git clone https://github.com/sebastienrousseau/dotfiles.git`. This will clone
  the latest version of the Dotfiles repository.

### Back Up Your Existing Data

Before installing Dotfiles, we recommend that you back up your existing data.
The Dotfiles installer will try to automatically backup any previous
installation. After installation, you will find the backup files in the
`~/dotfiles_backup` directory.

Even though this is normally not mandatory, it is always a good idea to backup
as there might be situations in which you could be required to restore your
previous installation.

### Getting Started

Dotfiles contains key elements that are used to configure your terminal, shell,
and other components for your development environment.

These components are grouped into the `shell/configurations` directory:

```bash
.
├── bash
│   └── bashrc # Bash configuration file
├── curl
│   ├── cacert.pem # CA certificates
│   └── curlrc # Curl configuration file
├── default
│   ├── color.sh # Color definitions for the terminal.
│   ├── editor.sh # Editor configuration.
│   ├── options.old # In work in progress (WIP).
│   └── prompt.sh # Prompt configuration.
├── jshint
│   └── jshintrc # JSHint configuration file.
├── macos
│   └── macos.plugin.sh # macOS configuration file.
├── profile
│   └── profile # Profile configuration file.
├── tmux
│   └── tmux # Tmux configuration file.
├── vim
│   └── vimrc # In work in progress (WIP).
├── vscode
│   ├── README.md
│   └── vscode.plugin.sh # Visual Studio Code configuration file.
├── wget
│   └── wgetrc # Wget configuration file.
├── zsh
│   └── zshrc # Zsh configuration file.
└── README.md

11 directories, 17 files
```

## Contributing

Please read carefully through our [Contributing Guidelines](https://github.com/sebastienrousseau/dotfiles/blob/master/CONTRIBUTING.md) for further details on the process for submitting pull
requests to us.

## Code of Conduct

We are committed to preserving and fostering a diverse, welcoming community.
Please read our [Code of Conduct](https://github.com/sebastienrousseau/dotfiles/blob/master/CODE_OF_CONDUCT.md).

## Our Values

1. We believe perfection must consider everything.
2. We take our passion beyond Code into our daily practices.
3. We are just obsessed about creating and delivering exceptional solutions.

## History

- See [Dotfiles Release](https://github.com/sebastienrousseau/dotfiles/releases) list.

## Acknowledgements

[Dotfiles](https://dotfiles.io) is beautifully crafted by these people and a
bunch of awesome [contributors](https://github.com/sebastienrousseau/dotfiles/graphs/contributors)

| [![Sebastien Rousseau](https://avatars0.githubusercontent.com/u/1394998?s=117)](http://sebastienrousseau.co.uk) | [![Graham Colgate](https://avatars0.githubusercontent.com/u/35816108?s=117)](https://github.com/gramtech) |
| :-------------------------------------------------------------------------------------------------------------: | :-------------------------------------------------------------------------------------------------------------: |
| [Sebastien Rousseau](https://github.com/sebastienrousseau) | [Graham Colgate](https://github.com/gramtech) |

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/sebastienrousseau/dotfiles/blob/master/LICENSE) file for details.

[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Freedia%2Fdotfiles.svg?type=large)](https://app.fossa.io/projects/git%2Bgithub.com%2Freedia%2Fdotfiles?ref=badge_large)

[contributors-shield]: https://img.shields.io/github/contributors/sebastienrousseau/dotfiles.svg?style=for-the-badge
[contributors-url]: https://github.com/sebastienrousseau/dotfiles/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/sebastienrousseau/dotfiles.svg?style=for-the-badge
[forks-url]: https://github.com/sebastienrousseau/dotfiles/network/members



