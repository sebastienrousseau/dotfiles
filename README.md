# Dotfiles

![Banner representing the Dotfiles Library](/media/dotfiles.svg)

![Codacy grade](https://img.shields.io/codacy/grade/634cfc4de08e492ebcbb341631066241?style=for-the-badge)
[![Contributors][contributors-shield]](https://github.com/sebastienrousseau/dotfiles/graphs/contributors)
[![Forks][forks-shield]](https://github.com/sebastienrousseau/dotfiles/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge\&color=ff69b4)](https://opensource.org/licenses/MIT)
![Made with Love](/media/made-with-love.svg)

## Table of contents

- [Dotfiles](#dotfiles)
  - [Table of contents](#table-of-contents)
  - [About Dotfiles](#about-dotfiles)
    - [Getting Started](#getting-started)
    - [Installation](#installation)
      - [Install from CDN](#install-from-cdn)
      - [Install from GitHub](#install-from-github)
      - [Install from NPM](#install-from-npm)
      - [Install the npm command line interface](#install-the-npm-command-line-interface)
        - [Check installation](#check-installation)
      - [Install Dotfiles via Yarn](#install-dotfiles-via-yarn)
  - [In this repository](#in-this-repository)
    - [Git dotfiles](#git-dotfiles)
    - [Bash Shell dotfiles](#bash-shell-dotfiles)
    - [Z Shell dotfiles](#z-shell-dotfiles)
    - [Homebrew dotfiles](#homebrew-dotfiles)
  - [Requirements](#requirements)
  - [Contributing](#contributing)
  - [Code of Conduct](#code-of-conduct)
  - [Our Values](#our-values)
  - [History](#history)
  - [Acknowledgements](#acknowledgements)
  - [License](#license)

## About Dotfiles

The Dotfiles resources aggregate a collection of standalone 'dotfiles' to help you customize your configurations across different computers and operating systems into one cohesive and consistent approach.

The Dotfiles aim to be cross-platform and are designed to work on macOS, Linux, and Windows.

The Dotfiles are optimized for performance and productivity.

### Getting Started

This repository contains the source code for multiple macOS Dotfiles and Shells:

- [Curl dotfiles](#curl-dotfiles)
- [Git dotfiles](#git-dotfiles)
- [Homebrew dotfiles](#homebrew-dotfiles)
- [JSHint dotfiles](#jshint-dotfiles)
- [Shell dotfiles](#shell-dotfiles)
- [Tmux dotfiles](#tmux-dotfiles)
- [Vim dotfiles](#vim-dotfiles)
- [Wget dotfiles](#wget-dotfiles)

### Installation

A few options are available:

#### Install from CDN

A pre-bundled package that contains all dotfiles and components needed to use is available on CDN.

The following table lists alternate CDN locations where Dotfiles is hosted.

#### Install from GitHub

Clone the main repository to get all source files including build scripts:

```bash
https://github.com/sebastienrousseau/dotfiles.git
```

[Download Dotfiles](https://github.com/sebastienrousseau/dotfiles/releases/latest)

#### Install from NPM

To use Dotfiles, you will need the npm JavaScript package manager.

#### Install the npm command line interface
npm is distributed with Node.js which means that when you download Node.js, you automatically get npm installed on your computer.

To install Node.js and the npm command line interface using either a Node version manager or a Node installer.

##### Check installation
To check if you have Node.js installed, run this command in your terminal:

```bash
node --version
```

To confirm that you have npm installed you can run this command in your terminal:

```bash
npm --version
```

#### Install Dotfiles via Yarn
To install Dotfiles, you can use the npm JavaScript package manager as follows:

```bash
npm i @sebastienrousseau/dotfiles
```

## In this repository

Within the release you'll find the following files and folders:

```bash
.
├── .curlrc
├── .eslintrc
├── .gitignore
├── .jshintrc
├── .travis.yml
├── .wgetrc
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── Dotfiles.png
├── ISSUE_TEMPLATE.md
├── Icon
├── LICENSE
├── README.md
├── bash
│   ├── .bash_aliases
│   ├── .bash_exit
│   ├── .bash_functions
│   ├── .bash_load_completion
│   ├── .bash_profile
│   └── .bashrc
├── homebrew
│   ├── brew-cask.sh
│   ├── brew-package.sh
│   ├── brew-tap.sh
│   └── install.sh
├── zsh
│   ├── configurations
│   ├── functions
├── installers
└── package.json

```

### Git dotfiles

```bash
git
├── config
│   └── git
│       └── template
│           └── HEAD
├── gitattributes
├── gitconfig
├── gitignore
└── gitmessage

3 directories, 5 files
```

### Bash Shell dotfiles

### Z Shell dotfiles

### Homebrew dotfiles

## Requirements

Set zsh as your login shell:

```bash
chsh -s $(which zsh)
```

## Contributing

Please read carefully through our [Contributing Guidelines](https://github.com/sebastienrousseau/dotfiles/blob/master/CONTRIBUTING.md) for further details on the process for submitting pull requests to us.

## Code of Conduct

We are committed to preserving and fostering a diverse, welcoming community. Please read our [Code of Conduct](https://github.com/sebastienrousseau/dotfiles/blob/master/CODE_OF_CONDUCT.md).

## Our Values

1.  We believe perfection must consider everything.
2.  We take our passion beyond Code into our daily practices.
3.  We are just obsessed about creating and delivering exceptional solutions.

## History

-   See [Dotfiles Release](https://github.com/sebastienrousseau/dotfiles/releases) list.

## Acknowledgements

[Dotfiles](https://dotfiles.io) is beautifully crafted by these people and a bunch of awesome [contributors](https://github.com/sebastienrousseau/dotfiles/graphs/contributors)

| [![Sebastien Rousseau](https://avatars0.githubusercontent.com/u/1394998?s=117)](http://sebastienrousseau.co.uk) | [![Graham Colgate](https://avatars0.githubusercontent.com/u/35816108?s=117)](https://github.com/gramtech) |
| :-------------------------------------------------------------------------------------------------------------: | :-------------------------------------------------------------------------------------------------------------: |
| [Sebastien Rousseau](https://github.com/sebastienrousseau) | [Graham Colgate](https://github.com/gramtech) |

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/sebastienrousseau/dotfiles/blob/master/LICENSE) file for details

[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Freedia%2Fdotfiles.svg?type=large)](https://app.fossa.io/projects/git%2Bgithub.com%2Freedia%2Fdotfiles?ref=badge_large)

[contributors-shield]: https://img.shields.io/github/contributors/sebastienrousseau/dotfiles.svg?style=for-the-badge
[contributors-url]: https://github.com/sebastienrousseau/dotfiles/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/sebastienrousseau/dotfiles.svg?style=for-the-badge
[forks-url]: https://github.com/sebastienrousseau/dotfiles/network/members


