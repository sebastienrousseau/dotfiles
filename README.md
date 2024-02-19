<!-- markdownlint-disable MD033 MD041 MD043 -->

<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="261"
  align="right"
/>

<!-- markdownlint-enable MD033 MD041 -->

# Dotfiles (v0.2.468)

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

Dotfiles are a powerful set of configuration files for macOS, Linux, and
Windows providing scripts and customized settings to streamline your
workflow. These files are an essential tool for developers and users who
want to modify their environment and applications to their exact needs.

The Dotfiles library are combined into a single `lib` directory. This
directory allows you to easily setup your development environment across
numerous computers and operating systems, ensuring consistency and
productivity no matter where you work.

<!-- markdownlint-disable MD033 MD041 MD043 -->
<br>
<center>
<!-- markdownlint-enable MD033 MD041 -->

[![Getting Started][getting_started]][getting-started-url]
[![Download Dotfiles v0.2.468][download_button]][12]

<!-- markdownlint-disable MD033 MD041 MD043 -->
</center>
<br />
<!-- markdownlint-enable MD033 MD041 -->

## Features ✨

- A familiar feel and comforts across environments.
- A unified set of aliases and useful commands for macOS, Linux, and
  Windows.
- Coloured multiplexer tmux prompt, customizable, and easy to use.
- Fast and flexible configuration files for Bash, Zsh, and more.
- Fully documented and translated into several languages (English,
  French, and more).
- Supports Apple Silicon (M1) and Intel chips (x86_64).
- Uses Roboto Mono for Powerline font for enhanced terminal experience.

![divider][divider]

## Getting Started 🚀

We are so delighted that you have decided to try Dotfiles, and are sure
that you will find Dotfiles unique and helpful.

To get started, please follow the instructions below. If you have any
questions, please feel free to contact us.

### Installation

We understand that you may want to install Dotfiles without reading long
manuals and lengthy documentation. In that respect, we have tried to
make the installation process as easy and automated as possible.

A range of installation methods are available, and we recommend that you
choose the one that best suits your needs.

Before you begin your installation, use this information to ensure that
you meet all the hardware, software, and system requirements for
installing Dotfiles.

#### 1) System Requirements

You need a modern operating system to install Dotfiles. Here's an non-
exhaustive list of the recommended operating systems that we support.

If you don't see your operating system listed, it may still work, but we
have yet been able to test it. If you have any issues, please let us
know.

- macOS 10.15 or later
- Windows 10 or later
- A Debian based distribution ([Debian][08], [Ubuntu][27],
  [PoP!_OS][22], [Zorin OS][29], [Q4OS][23], [Kali Linux][18],
  [Devuan][10], [Deepin][09], etc.)

#### 2) Software Requirements

The following programs must be installed on your system to install
Dotfiles:

- [**Bash**][03] - a shell, or command language interpreter, for the GNU
  operating system.
- Or [**Zsh**][30] - a shell designed for interactive use, although it
  is also a powerful scripting language.
- [**Git**][15] - a free and open source distributed version control
  system designed to handle everything from small to very large projects
  with speed and efficiency.
- [**Curl**][07] - a command line tool for transferring data with URL
  syntax.
- [**Wget**][28] - a free software package for retrieving files using
  HTTP, HTTPS and FTP, the most widely-used Internet protocols.
- [**Make**][19] - a tool which controls the generation of executables
  and other non-source files of a program from the program's source
  files.
- [**Shell**][26] - a shell command line interpreter program for Unix-
  like operating systems.
- [**PnPM**][21] - a package manager for JavaScript and Node.js. It is
  fast, disk space efficient and reliable.

#### 3) Font Requirements

We recommend using a font such as `Roboto Mono for Powerline` for
terminal and vscode editor.

On macOS, you can install the font using the following command:

```bash
brew tap homebrew/cask-fonts
```

```bash
brew install --cask font-roboto-mono-for-powerline
```

On Linux, you can install the font using the following command:

```bash
sudo apt install fonts-roboto-mono-for-powerline
```

### Documentation

To read the documentation for Dotfiles, please visit:

- [Dotfiles website][00]
- [Dotfiles Docs GitHub repository][11]

![divider][divider]

## Usage 📖

### 1️⃣ Download Dotfiles

You can download the latest version (v0.2.468) with the following
options:

- [**Manual download**][24] - **The easiest way to install Dotfiles.**
- [**Install with PnPM**][20] `pnpm i @sebastienrousseau/dotfiles`.
- [**Install with Npm**][20] `npm install @sebastienrousseau/dotfiles`.
- [**Install with Yarn**][20] `yarn add @sebastienrousseau/dotfiles`.
- **Clone the main repository** to get all source files including build
  scripts: `git clone https://github.com/sebastienrousseau/dotfiles.git`
  . This will clone the latest version of the Dotfiles repository.

### 2️⃣ Back Up Your Existing Data

Before installing Dotfiles, we strongly recommend that you back up your
existing data. The Dotfiles installer will try to automatically backup
any previous installation of known dotfiles into a backup directory
`$HOME/dotfiles_backup`.

The backup files are the following:

```bash
.alias
.bash_aliases
.bash_profile
.bash_prompt
.bashrc
.curlrc
.dir_colors
.exports
.functions
.gitattributes
.gitconfig
.gitignore
.gitmessage
.inputrc
.npmrc
.path
.profile
.tmux.conf
.vimrc
.wgetrc
.yarnrc
.zshenv
.zshrc
cacert.pem
```

It is always a good idea to backup as there might be situations in which
you could be required to restore your previous installation.

### 3️⃣ Try it out and let us know what you think

To install the latest version of the dotfiles, run the following
command:

#### Using make (easiest and recommended)

The easiest way to install Dotfiles is to use the `make` command. This
will install the latest version of the dotfiles and will automatically
backup any existing dotfiles you may have into a backup directory
`$HOME/dotfiles_backup`.

The installer will check if you have PnPM installed to switch to the
PnPM installation method. If not, it will fallback to equivalent shell
scripts.

Switch to the `dist` directory and run:

```bash
make build
```

You can also just check the installer options available, by simply
running:

```bash
make help
```

#### Using Node.js (advanced)

If you want to install Dotfiles using Node.js, you can run the following
command in the `dist` directory located in your
`node_modules/@sebastienrousseau/dotfiles/dist` directory:

```bash
node .
```

This will install the latest version of the dotfiles and will
automatically backup any existing dotfiles you may have into a backup
directory `$HOME/dotfiles_backup`.

#### Using PnPM (highly recommended if you have PnPM installed)

PnPM is a key dependency of the dotfiles package. It will help you
install the dotfiles rapidly and very efficiently.

Switch to the `dist` directory and run:

```bash
pnpm run build
```

This will install the latest version of the dotfiles and will
automatically backup any existing dotfiles you may have into a backup
directory `$HOME/dotfiles_backup`.

### Post installation

Following the installation, you can verify that the dotfiles package is
installed in the following directory `$HOME/dotfiles_backup`.

Just quit your terminal and restart it. If the installation is
successful, you should be able to see a new interface of your terminal
and be able to start using the dotfiles aliases and other
configurations.

Please refer to the [documentation][11] for more information.

![divider][divider]

## Releases 🔗

Releases are available on the [GitHub releases page][24].

![divider][divider]

## Semantic versioning policy 🚥

For transparency into our release cycle and in striving to maintain
backward compatibility, `Dotfiles` follows
[Semantic Versioning][25].

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
[12]: https://github.com/sebastienrousseau/dotfiles/archive/refs/tags/v0.2.468.tar.gz "Download Dotfiles v0.2.468"
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
