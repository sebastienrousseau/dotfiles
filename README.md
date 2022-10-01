# Dotfiles

![Banner representing the Dotfiles Library](https://github.com/sebastienrousseau/dotfiles/raw/master/assets/dotfiles.svg)

[![Codacy][codacy-grade]][codacy-url]
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![License][license]][license-url]
[![Love][love]][project-url]

## 👋 Welcome to Dotfiles

*Simply designed to fit your shell life.*

Dotfiles - A set of macOS / Linux and Windows configuration files.

Dotfiles aggregates a collection of standalone configuration files (dotfiles)
combined into a `shell` directory that can be used to customize your development
environment across numerous computers and operating systems (macOS, Windows,
Linux).

The Dotfiles provides modular configuration files (aliases, functions and paths)
built for speed, higher performance, with the aim of helping you have an easy
and centralized way to configure your environment and applications.

![divider][divider]

## 💼 Documentation

To read the documentation for Dotfiles, please visit:

- [Dotfiles website][project-url]
- [Dotfiles GitHub repository](https://github.com/sebastienrousseau/dotfiles)

![divider][divider]

## 🔧 Installation

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

![divider][divider]

### ✔️ Requirements

- [**Bash**](https://www.gnu.org/software/bash/) is required to install Dotfiles.
  Bash is the shell, or command language interpreter, for the GNU operating
  system. The name is an acronym for the ‘Bourne-Again SHell’, a pun on Stephen
  Bourne, the author of the direct ancestor of the current Unix shell sh, which
  appeared in the Seventh Edition Bell Labs Research version of Unix.
- [**Git**](https://git-scm.com) is required to install Dotfiles. Git is a free
  and open source distributed version control system designed to handle
  everything from small to very large projects with speed and efficiency.
- [**Curl**](https://curl.se) is required to install Dotfiles.
  Curl is a command line tool for transferring data with URL syntax, supporting
  DICT, FILE, FTP, FTPS, GOPHER, HTTP, HTTPS, IMAP, IMAPS, LDAP, LDAPS, MQTT,
  POP3, POP3S, RTMP, RTSP, SCP, SFTP, SMB, SMBS, SMTP, SMTPS, TELNET and TFTP.
- [**Zsh**](https://www.zsh.org) is required to install Dotfiles. Zsh is a
  shell designed for interactive use, although it is also a powerful scripting
  language. Zsh is an extended Bourne shell with many improvements, including
  some features of Bash, ksh, and tcsh.
- [**PnPM**](https://pnpm.io) is currently required to install Dotfiles. PnPM is
  a package manager for JavaScript and Node.js. It is fast, disk space efficient
  and reliable. This is recommended for installing Dotfiles with ease and speed.

### 1️⃣ Download Dotfiles v0.2.452

You can download the latest version (v0.2.452) with the following options:

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

### 2️⃣ Back Up Your Existing Data

Before installing Dotfiles, we recommend that you back up your existing data.
The Dotfiles installer will try to automatically backup any previous
installation. After installation, you will find the backup files in the
`~/dotfiles_backup` directory.

Even though this is normally not mandatory, it is always a good idea to backup
as there might be situations in which you could be required to restore your
previous installation.

### 3️⃣ What's included

Dotfiles contains key elements that are used to configure your terminal, shell,
and other components for your development environment.

Within the download you'll find all the Dotfiles source files grouped into the
dist folder.

You'll see something like this:

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

### 4️⃣ Try it out and let us know what you think

![divider][divider]

## 🔗 Releases

Releases are available on the [GitHub releases page][releases-url].

![divider][divider]

## 🚥 Semantic versioning policy

For transparency into our release cycle and in striving to maintain backward
compatibility, `Dotfiles` follows [Semantic Versioning][semver-url]
(SemVer) and [ESLint's Semantic Versioning Policy][eslint-semantic-url].

![divider][divider]

## History

- See [Dotfiles Release](https://github.com/sebastienrousseau/dotfiles/releases) list.

## ✅ Changelog

- [GitHub Releases](https://github.com/sebastienrousseau/dotfiles/releases)

![divider][divider]

## 📖 Code of Conduct

We are committed to preserving and fostering a diverse, welcoming community.
Please read our [Code of Conduct](https://github.com/sebastienrousseau/dotfiles/blob/master/.github/CODE-OF-CONDUCT.md).

![divider][divider]

## ⭐️ Our Values

- We believe perfection must consider everything.
- We take our passion beyond code into our daily practices.
- We are just obsessed about creating and delivering exceptional solutions.

![divider][divider]

## ❤️ Contributing

Thank you for using Dotfiles! If you like the library, it would be
great if you can give it a star ⭐ on [GitHub][01].

There are also many ways in which you can participate in this project, for
example:

- [Submit bugs and feature requests](https://github.com/sebastienrousseau/dotfiles/issues/new), and help us verify as they are checked in,
- Review [source code changes](https://github.com/sebastienrousseau/dotfiles/pulls), and help us improve our code quality,
- Review the [documentation](https://github.com/sebastienrousseau/dotfiles/docs) and make pull requests for anything from typos to additional and new content.

Please read carefully through our
[Contributing Guidelines](https://github.com/sebastienrousseau/dotfiles/blob/master/.github/CONTRIBUTING.md)
for further details on the process for submitting pull requests to us.

![divider][divider]

## 🥂 License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/sebastienrousseau/dotfiles/blob/master/LICENSE) file for details.

[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Freedia%2Fdotfiles.svg?type=large)](https://app.fossa.io/projects/git%2Bgithub.com%2Freedia%2Fdotfiles?ref=badge_large)

![divider][divider]

## 🏢 Acknowledgements

[Dotfiles][project-url] is beautifully crafted by these people and a
bunch of awesome [contributors](https://github.com/sebastienrousseau/dotfiles/graphs/contributors)

| [![Sebastien Rousseau](https://avatars0.githubusercontent.com/u/1394998?s=117)](http://sebastienrousseau.co.uk) | [![Graham Colgate](https://avatars0.githubusercontent.com/u/35816108?s=117)](https://github.com/gramtech) |
| :-------------------------------------------------------------------------------------------------------------: | :-------------------------------------------------------------------------------------------------------------: |
| [Sebastien Rousseau](https://github.com/sebastienrousseau) | [Graham Colgate](https://github.com/gramtech) |

[01]: https://github.com/sebastienrousseau/dotfiles
[codacy-grade]: https://img.shields.io/codacy/grade/634cfc4de08e492ebcbb341631066241?style=for-the-badge
[codacy-url]:https://www.codacy.com/gh/sebastienrousseau/dotfiles/dashboard
[contributors-shield]: https://img.shields.io/github/contributors/sebastienrousseau/dotfiles.svg?style=for-the-badge
[contributors-url]: https://github.com/sebastienrousseau/dotfiles/graphs/contributors
[divider]: https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/assets/divider.svg "divider"
[forks-shield]: https://img.shields.io/github/forks/sebastienrousseau/dotfiles.svg?style=for-the-badge
[forks-url]: https://github.com/sebastienrousseau/dotfiles/network/members
[license-url]: https://opensource.org/licenses/MIT
[license]: https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge\&color=ff69b4
[love]: https://github.com/sebastienrousseau/dotfiles/raw/master/assets/made-with-love.svg
[project-url]: https://dotfiles.io/
[releases-url]: https://github.com/sebastienrousseau/dotfiles/releases
[semver-url]: http://semver.org/
[eslint-semantic-url]: https://github.com/eslint/eslint#semantic-versioning-policy
