# Dotfiles

[![Banner representing the Dotfiles Library][logo]][website-url]

[![Codacy][codacy-grade]][codacy-url]
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![License][license]][license-url]
[![Love][love]][website-url]

**[Website][website-url] • [Documentation][github-url]
• [Report Bug][issues-url]
• [Request Feature][issues-url]
• [Contributing Guidelines][contributing-url]**

## 👋 Welcome to Dotfiles (v0.2.462)

### Simply designed to fit your shell life

Dotfiles are a set of macOS, Linux and Windows configuration files. They are
aimed at making your life easier by providing a set of scripts and configuration
files with new ways to get things done.

[![Getting Started][getting_started]][getting-started-url]
[![Download Dotfiles v0.2.462][download_button]][download-url]

Dotfiles aggregates a collection of standalone configuration files (dotfiles)
combined into a `lib` directory that can be used to customize your development
environment across numerous computers and operating systems (macOS, Windows,
Linux).

The Dotfiles provides modular configuration files (aliases, functions and paths)
built for speed, higher performance, with the aim of helping you have an easy
and centralized way to configure your environment and applications.

![divider][divider]

## 💼 Documentation

To read the documentation for Dotfiles, please visit:

- [Dotfiles website][website-url]
- [Dotfiles Docs GitHub repository][docs-url]

![divider][divider]

## 🚀 Getting Started

We are so delighted that you have decided to try Dotfiles, and are sure that you
will find Dotfiles unique and helpful.

Dotfiles seeks to bring you high quality and easy to use standalone and modular
configuration files that can be used to customize your development environment
across numerous computers and operating systems (macOS, Windows, Linux).

### 🔧 Installation

We understand that you may want to install Dotfiles without reading long manuals
and lengthy documentation. In that respect, we have tried to make the
installation process as easy as possible.

A range of installation methods are available, and we recommend that you choose
the one that best suits your needs.

Before you begin your installation, use this information to ensure that you meet
all the hardware, software, and system requirements for installing Dotfiles.

#### 📋 System Requirements

You need a modern operating system to install Dotfiles. Here's an non-exhaustive
list of the recommended operating systems that we support.

If you don't see your operating system listed, it may still work, but we have
yet been able to test it. If you have any issues, please let us know.

- macOS 10.15 or later
- Windows 10 or later
- A Debian based distribution ([Debian][debian-url], [Ubuntu][ubuntu-url],
[PoP!_OS][pop-url], [Zorin OS][zorin-url], [Q4OS][q4-url],
[Kali Linux][kali-url], [Devuan][devuan-url], [Deepin][deepin-url], etc.)

![divider][divider]

#### ✔️ Software Requirements

The following programs must be installed on your system to install Dotfiles:

- [**Bash**][bash-url] - a shell, or command language interpreter, for the GNU
  operating system.
- Or [**Zsh**][zsh-url] - a shell designed for interactive use, although it is
  also a powerful scripting language.
- [**Git**][git-url] - a free and open source distributed version control system
  designed to handle everything from small to very large projects with speed and
  efficiency.
- [**Curl**][curl-url] - a command line tool for transferring data with URL
  syntax.
- [**Wget**][wget-url] - a free software package for retrieving files using
  HTTP, HTTPS and FTP, the most widely-used Internet protocols.
- [**Make**][make-url] - a tool which controls the generation of executables and
  other non-source files of a program from the program's source files.
- [**Shell**][shell-url] - a shell command line interpreter program for
  Unix-like operating systems.
- [**PnPM**][pnpm-url] - a package manager for JavaScript and Node.js. It is
  fast, disk space efficient and reliable.

#### Font

We recommend using a font such as `Roboto Mono for Powerline` for terminal and
vscode editor.

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

### 1️⃣ Download Dotfiles

You can download the latest version (v0.2.462) with the following options:

- [**Manual download**][releases-url] - **The easiest way to install Dotfiles.**
- [**Install with PnPM**][package-url]
  `pnpm i @sebastienrousseau/dotfiles`.
- [**Install with Npm**][package-url]
  `npm install @sebastienrousseau/dotfiles`.
- [**Install with Yarn**][package-url]
  `yarn add @sebastienrousseau/dotfiles`.
- **Clone the main repository** to get all source files including build scripts:
  `git clone https://github.com/sebastienrousseau/dotfiles.git`. This will clone
  the latest version of the Dotfiles repository.

### 2️⃣ Back Up Your Existing Data

Before installing Dotfiles, we strongly recommend that you back up your existing
data. The Dotfiles installer will try to automatically backup any previous
installation of known dotfiles into a backup directory
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

It is always a good idea to backup as there might be situations in which you
could be required to restore your previous installation.

### 3️⃣ Try it out and let us know what you think

To install the latest version of the dotfiles, run the following command:

#### Using make (easiest)

The easiest way to install Dotfiles is to use the `make` command. This will
install the latest version of the dotfiles and will automatically backup
any existing dotfiles you may have into a backup directory
`$HOME/dotfiles_backup`.

The installer will check if you have PnPM installed to switch to the PnPM
installation method. If not, it will fallback to equivalent shell scripts.

Switch to the `dist` directory and run:

```bash
make build
```

You can also just check the installer options available, by simply running:

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

This will install the latest version of the dotfiles and will automatically
backup any existing dotfiles you may have into a backup directory
`$HOME/dotfiles_backup`.

#### Using PnPM (highly recommended if you have PnPM installed)

PnPM is a key dependency of the dotfiles package. It will help you install the
dotfiles rapidly and very efficiently.

Switch to the `dist` directory and run:

```bash
pnpm run build
```

This will install the latest version of the dotfiles and will automatically
backup any existing dotfiles you may have into a backup directory
`$HOME/dotfiles_backup`.

### Post installation

Following the installation, you can verify that the dotfiles package is
installed in the following directory `$HOME/dotfiles_backup`.

Just quit your terminal and restart it. If the installation is successful, you
should be able to see a new interface of your terminal and be able to start
using the dotfiles aliases and other configurations.

Please refer to the [documentation][docs-url] for more information.

![divider][divider]

### 4️⃣ What's included

Dotfiles contains core elements that are used to configure your shell, and
other components catered for your environment setup.

Within the download you'll find all the Dotfiles source files grouped within
the `dist` folder.

You'll see something like this:

```bash
.
├── bin
│   ├── backup.d.ts
│   ├── backup.d.ts.map
│   ├── backup.js
│   ├── backup.js.map
│   ├── constants.d.ts
│   ├── constants.d.ts.map
│   ├── constants.js
│   ├── constants.js.map
│   ├── copy.d.ts
│   ├── copy.d.ts.map
│   ├── copy.js
│   ├── copy.js.map
│   ├── dotfiles.d.ts
│   ├── dotfiles.d.ts.map
│   ├── dotfiles.js
│   ├── dotfiles.js.map
│   ├── download.d.ts
│   ├── download.d.ts.map
│   ├── download.js
│   ├── download.js.map
│   ├── index.d.ts
│   ├── index.d.ts.map
│   ├── index.js
│   ├── index.js.map
│   ├── transfer.d.ts
│   ├── transfer.d.ts.map
│   ├── transfer.js
│   ├── transfer.js.map
│   ├── unpack.d.ts
│   ├── unpack.d.ts.map
│   ├── unpack.js
│   └── unpack.js.map
├── lib
│   ├── aliases
│   │   ├── default
│   │   │   └── default.aliases.sh
│   │   ├── gcloud
│   │   │   └── gcloud.aliases.sh
│   │   ├── git
│   │   │   └── git.aliases.sh
│   │   ├── heroku
│   │   │   └── heroku.aliases.sh
│   │   ├── jekyll
│   │   │   └── jekyll.aliases.sh
│   │   ├── pnpm
│   │   │   └── pnpm.aliases.sh
│   │   ├── subversion
│   │   │   └── subversion.aliases.sh
│   │   └── tmux
│   │       └── tmux.aliases.sh
│   ├── configurations
│   │   ├── bash
│   │   │   └── bashrc
│   │   ├── curl
│   │   │   ├── cacert.pem
│   │   │   └── curlrc
│   │   ├── default
│   │   │   ├── color.sh
│   │   │   ├── constants.sh
│   │   │   ├── editor.sh
│   │   │   └── prompt.sh
│   │   ├── gem
│   │   │   └── gemrc
│   │   ├── input
│   │   │   └── inputrc
│   │   ├── jshint
│   │   │   └── jshintrc
│   │   ├── nano
│   │   │   └── nanorc
│   │   ├── profile
│   │   │   └── profile
│   │   ├── tmux
│   │   │   ├── default
│   │   │   ├── display
│   │   │   ├── linux
│   │   │   ├── navigation
│   │   │   ├── panes
│   │   │   ├── theme
│   │   │   ├── tmux
│   │   │   └── vi
│   │   ├── vim
│   │   │   └── vimrc
│   │   ├── wget
│   │   │   └── wgetrc
│   │   ├── zsh
│   │   │   └── zshrc
│   │   └── README.md
│   ├── functions
│   │   ├── README.md
│   │   ├── cdls.sh
│   │   ├── changediskpwd.tmp
│   │   ├── code.tmp
│   │   ├── countdown.tmp
│   │   ├── curlheader.sh
│   │   ├── curltime.sh
│   │   ├── encode64.sh
│   │   ├── environment.sh
│   │   ├── extract.sh
│   │   ├── filehead.sh
│   │   ├── genpwd.sh
│   │   ├── goto.sh
│   │   ├── headers.tmp
│   │   ├── hidehiddenfiles.sh
│   │   ├── history-all.tmp
│   │   ├── hostinfo.sh
│   │   ├── hstats.sh
│   │   ├── httpdebug.sh
│   │   ├── keygen.sh
│   │   ├── last.sh
│   │   ├── logout.sh
│   │   ├── lowercase.sh
│   │   ├── macos.sh
│   │   ├── matrix.sh
│   │   ├── mcd.sh
│   │   ├── mount_read_only.sh
│   │   ├── myproc.sh
│   │   ├── prependpath.sh
│   │   ├── print.tmp
│   │   ├── ql.sh
│   │   ├── rd.sh
│   │   ├── remove_disk.sh
│   │   ├── ren.sh
│   │   ├── rm.tmp
│   │   ├── rps.tmp
│   │   ├── showhiddenfiles.sh
│   │   ├── size.sh
│   │   ├── stopwatch.sh
│   │   ├── trash.tmp
│   │   ├── tree.tmp
│   │   ├── uppercase.sh
│   │   ├── uuidgen.tmp
│   │   ├── view-source.sh
│   │   ├── vscode.sh
│   │   ├── whoisport.sh
│   │   └── zipf.sh
│   ├── paths
│   │   ├── ant
│   │   │   └── ant.paths.sh
│   │   ├── default
│   │   │   └── default.paths.sh
│   │   ├── homebrew
│   │   │   └── homebrew.paths.sh
│   │   ├── java
│   │   │   └── java.paths.sh
│   │   ├── maven
│   │   │   └── maven.paths.sh
│   │   ├── node
│   │   │   └── node.paths.sh
│   │   ├── nvm
│   │   │   └── nvm.paths.sh
│   │   ├── pnpm
│   │   │   └── pnpm.paths.sh
│   │   ├── python
│   │   │   └── python.paths.sh
│   │   ├── ruby
│   │   │   └── ruby.paths.sh
│   │   └── tmux
│   │       └── tmux.paths.sh
│   ├── README.md
│   ├── aliases.sh
│   ├── configurations.sh
│   ├── exit.sh
│   ├── functions.sh
│   ├── history.sh
│   └── paths.sh
├── scripts
│   ├── backup.sh
│   ├── banner.sh
│   ├── build.sh
│   ├── clean.sh
│   ├── compile.sh
│   ├── copy.sh
│   ├── dotfiles.sh
│   ├── download.sh
│   ├── help.sh
│   └── unpack.sh
├── Makefile
└── filesizes.txt

38 directories, 141 files

```

## 🔗 Releases

Releases are available on the [GitHub releases page][releases-url].

![divider][divider]

## 🚥 Semantic versioning policy

For transparency into our release cycle and in striving to maintain backward
compatibility, `Dotfiles` follows [Semantic Versioning][semver-url].

![divider][divider]

## History

- See [Dotfiles Release][releases-url] for a list of changes.

## ✅ Changelog

- [GitHub Releases][releases-url] are used for changelogs.

![divider][divider]

## 📖 Code of Conduct

We are committed to preserving and fostering a diverse, welcoming community.
Please read our [Code of Conduct][code-of-conduct-url].

![divider][divider]

## ⭐️ Our Values

- We believe perfection must consider everything.
- We take our passion beyond code into our daily practices.
- We are just obsessed about creating and delivering exceptional solutions.

![divider][divider]

## ❤️ Contributing

Thank you for using Dotfiles! If you like the library, it would be
great if you can give it a star ⭐ on [Github][github-url].

There are also many ways in which you can participate in this project, for
example:

- [Submit bugs and feature requests][issues-url], and help us verify as they are
checked in,
- Review [source code changes][download-url], and help us improve our code quality,
- Review the [documentation][docs-url] and make pull requests for anything from
typos to additional and new content.

Please read carefully through our
[Contributing Guidelines][contributing-url]
for further details on the process for submitting pull requests to us.

![divider][divider]

## 🥂 License

This project is licensed under the [MIT License][license-url] file for details.

[![FOSSA Status][fossa]][fossa-url]

![divider][divider]

## 🏢 Acknowledgements

[Dotfiles][website-url] is beautifully crafted by these people and a bunch of
awesome [contributors][contributors-url]

| [![sr]][sr-url] | [![gr]][gr-url] |
|:-----------------:|:------------------------------------:|
| [Sebastien Rousseau][sr-url]| [Graham Colgate][gr-url] |

[bash-url]: https://www.gnu.org/software/bash/
[codacy-url]:https://www.codacy.com/gh/sebastienrousseau/dotfiles/dashboard
[code-of-conduct-url]: https://github.com/sebastienrousseau/dotfiles/blob/master/.github/CODE-OF-CONDUCT.md
[contributing-url]: https://github.com/sebastienrousseau/dotfiles/blob/master/.github/CONTRIBUTING.md
[curl-url]: https://curl.se/
[debian-url]: https://www.debian.org/
[deepin-url]: https://www.deepin.org/en/
[devuan-url]: https://devuan.org/
[docs-url]: https://github.com/sebastienrousseau/dotfiles/docs
[download-url]: https://github.com/sebastienrousseau/dotfiles/archive/refs/tags/v0.2.462.tar.gz
[forks-url]: https://github.com/sebastienrousseau/dotfiles/network/members
[fossa-url]: https://app.fossa.io/projects/git%2Bgithub.com%2Freedia%2Fdotfiles?ref=badge_large
[getting-started-url]: https://github.com/sebastienrousseau/dotfiles#getting-started
[git-url]: https://git-scm.com/
[github-url]: https://github.com/sebastienrousseau/dotfiles
[gr-url]: https://github.com/gramtech
[issues-url]: https://github.com/sebastienrousseau/dotfiles/issues
[kali-url]: https://www.kali.org/
[license-url]: https://opensource.org/licenses/MIT
[make-url]: https://www.gnu.org/software/make/
[package-url]:https://www.npmjs.com/package/@sebastienrousseau/dotfiles
[pnpm-url]: https://pnpm.io
[pop-url]: https://pop.system76.com/
[q4-url]: https://q4os.org/
[releases-url]: https://github.com/sebastienrousseau/dotfiles/releases
[semver-url]: http://semver.org/
[shell-url]: https://www.gnu.org/software/shell/
[sr-url]: https://github.com/sebastienrousseau
[ubuntu-url]: https://ubuntu.com/
[website-url]: https://dotfiles.io
[wget-url]: https://www.gnu.org/software/wget/
[zorin-url]: https://zorinos.com/
[zsh-url]: https://www.zsh.org/

[codacy-grade]: https://img.shields.io/codacy/grade/634cfc4de08e492ebcbb341631066241?style=for-the-badge "Codacy grade"
[contributors-shield]: https://img.shields.io/github/contributors/sebastienrousseau/dotfiles.svg?style=for-the-badge "Contributors"
[contributors-url]: https://github.com/sebastienrousseau/dotfiles/graphs/contributors "List of contributors"
[divider]: https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/assets/divider.svg "Divider"
[download_button]: https://github.com/sebastienrousseau/dotfiles/raw/master/assets/button-secondary.svg "Download"
[forks-shield]: https://img.shields.io/github/forks/sebastienrousseau/dotfiles.svg?style=for-the-badge "Forks"
[fossa]: https://app.fossa.io/api/projects/git%2Bgithub.com%2Freedia%2Fdotfiles.svg?type=large "FOSSA"
[getting_started]: https://github.com/sebastienrousseau/dotfiles/raw/master/assets/button-primary.svg "Getting Started"
[gr]: https://avatars0.githubusercontent.com/u/35816108?s=117 "Graham Colgate"
[license]: https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge\&color=ff69b4 "License"
[logo]: https://github.com/sebastienrousseau/dotfiles/raw/master/assets/dotfiles.svg "Dotfiles"
[love]: https://github.com/sebastienrousseau/dotfiles/raw/master/assets/made-with-love.svg "Made with Love"
[sr]: https://avatars0.githubusercontent.com/u/1394998?s=117 "Sebastien Rousseau"
