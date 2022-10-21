# Dotfiles

[![Banner representing the Dotfiles Library][logo]][website]

[![Codacy][codacy-grade]][codacy-url]
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![License][license]][license-url]
[![Love][love]][website]

**[Website][website] • [Documentation][github]
• [Report Bug][issues]
• [Request Feature][issues]
• [Contributing Guidelines][contributing]**

## 👋 Welcome to Dotfiles (v0.2.461)

### Simply designed to fit your shell life

Dotfiles are a set of macOS, Linux and Windows configuration files. They are
aimed at making your life easier by providing a set of scripts and configuration
files with new ways to get things done.

[![Getting Started][getting_started]][getting-started]
[![Download Dotfiles v0.2.461][download_button]][download]

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

- [Dotfiles website][website]
- [Dotfiles Docs GitHub repository][docs]

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
- A Debian based distribution ([Debian][debian], [Ubuntu][ubuntu],
[PoP!_OS][pop], [Zorin OS][zorin], [Q4OS][q4], [Kali Linux][kali],
[Devuan][devuan], [Deepin][deepin], etc.)

![divider][divider]

#### ✔️ Software Requirements

The following programs must be installed on your system to install Dotfiles:

- [**Bash**][bash] - a shell, or command language interpreter, for the GNU
  operating system.
- Or [**Zsh**][zsh] - a shell designed for interactive use, although it is also
  a powerful scripting language.
- [**Git**][git] - a free and open source distributed version control system
  designed to handle everything from small to very large projects with speed and
  efficiency.
- [**Curl**][curl] - a command line tool for transferring data with URL syntax.
- [**Wget**][wget] - a free software package for retrieving files using HTTP,
  HTTPS and FTP, the most widely-used Internet protocols.
- [**Make**][make] - a tool which controls the generation of executables and
  other non-source files of a program from the program's source files.
- [**Shell**][shell] - a shell command line interpreter program for Unix-like
  operating systems.
- [**PnPM**][pnpm] - a package manager for JavaScript and Node.js. It is fast,
  disk space efficient and reliable.

#### Font

We recommend using a font such as `Roboto Mono for Powerline` for terminal and
vscode editor.

On macOS, you can install the font using the following command:

```bash
brew tap homebrew/cask-fonts
```

```bash
brew cask install font-roboto-mono-for-powerline
```

On Linux, you can install the font using the following command:

```bash
sudo apt install fonts-roboto-mono-for-powerline
```

### 1️⃣ Download Dotfiles

You can download the latest version (v0.2.461) with the following options:

- [**Manual download**][releases] - **The easiest way to install Dotfiles.**
- [**Install with PnPM**][package]
  `pnpm i @sebastienrousseau/dotfiles`.
- [**Install with Npm**][package]
  `npm install @sebastienrousseau/dotfiles`.
- [**Install with Yarn**][package]
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
make assemble
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

Please refer to the [documentation][docs] for more information.

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

Releases are available on the [GitHub releases page][releases].

![divider][divider]

## 🚥 Semantic versioning policy

For transparency into our release cycle and in striving to maintain backward
compatibility, `Dotfiles` follows [Semantic Versioning][semver-url].

![divider][divider]

## History

- See [Dotfiles Release][releases] for a list of changes.

## ✅ Changelog

- [GitHub Releases][releases] are used for changelogs.

![divider][divider]

## 📖 Code of Conduct

We are committed to preserving and fostering a diverse, welcoming community.
Please read our [Code of Conduct][code-of-conduct].

![divider][divider]

## ⭐️ Our Values

- We believe perfection must consider everything.
- We take our passion beyond code into our daily practices.
- We are just obsessed about creating and delivering exceptional solutions.

![divider][divider]

## ❤️ Contributing

Thank you for using Dotfiles! If you like the library, it would be
great if you can give it a star ⭐ on [GitHub][github].

There are also many ways in which you can participate in this project, for
example:

- [Submit bugs and feature requests][issues], and help us verify as they are
checked in,
- Review [source code changes][download], and help us improve our code quality,
- Review the [documentation][docs] and make pull requests for anything from
typos to additional and new content.

Please read carefully through our
[Contributing Guidelines][contributing]
for further details on the process for submitting pull requests to us.

![divider][divider]

## 🥂 License

This project is licensed under the MIT License - see the [LICENSE][license-url]
file for details.

[![FOSSA Status][fossa]][fossa-url]

![divider][divider]

## 🏢 Acknowledgements

[Dotfiles][website] is beautifully crafted by these people and a bunch of
awesome [contributors][contributors-url]

| [![Sebastien Rousseau](https://avatars0.githubusercontent.com/u/1394998?s=117)](http://sebastienrousseau.co.uk) | [![Graham Colgate](https://avatars0.githubusercontent.com/u/35816108?s=117)](https://github.com/gramtech) |
| :-------------------------------------------------------------------------------------------------------------: | :-------------------------------------------------------------------------------------------------------------: |
| [Sebastien Rousseau](https://github.com/sebastienrousseau) | [Graham Colgate](https://github.com/gramtech) |

[bash]: https://www.gnu.org/software/bash/
[codacy-url]:https://www.codacy.com/gh/sebastienrousseau/dotfiles/dashboard
[code-of-conduct]: https://github.com/sebastienrousseau/dotfiles/blob/master/.github/CODE-OF-CONDUCT.md
[contributing]: https://github.com/sebastienrousseau/dotfiles/blob/master/.github/CONTRIBUTING.md
[curl]: https://curl.se/
[debian]: https://www.debian.org/
[deepin]: https://www.deepin.org/en/
[devuan]: https://devuan.org/
[docs]: https://github.com/sebastienrousseau/dotfiles/docs
[download]: https://github.com/sebastienrousseau/dotfiles/archive/refs/tags/v0.2.461.tar.gz
[fossa-url]: https://app.fossa.io/projects/git%2Bgithub.com%2Freedia%2Fdotfiles?ref=badge_large
[forks-url]: https://github.com/sebastienrousseau/dotfiles/network/members
[getting-started]: https://github.com/sebastienrousseau/dotfiles#getting-started
[git]: https://git-scm.com/
[github]: https://github.com/sebastienrousseau/dotfiles
[issues]: https://github.com/sebastienrousseau/dotfiles/issues
[kali]: https://www.kali.org/
[license]: https://github.com/sebastienrousseau/dotfiles/blob/master/LICENSE
[license-url]: https://opensource.org/licenses/MIT
[make]: https://www.gnu.org/software/make/
[package]:https://www.npmjs.com/package/@sebastienrousseau/dotfiles
[pnpm]: https://pnpm.io
[pop]: https://pop.system76.com/
[q4]: https://q4os.org/
[releases]: https://github.com/sebastienrousseau/dotfiles/releases
[semver-url]: http://semver.org/
[shell]: https://www.gnu.org/software/shell/
[ubuntu]: https://ubuntu.com/
[website]: https://dotfiles.io
[wget]: https://www.gnu.org/software/wget/
[zorin]: https://zorinos.com/
[zsh]: https://www.zsh.org/

[codacy-grade]: https://img.shields.io/codacy/grade/634cfc4de08e492ebcbb341631066241?style=for-the-badge "Codacy grade"
[contributors-shield]: https://img.shields.io/github/contributors/sebastienrousseau/dotfiles.svg?style=for-the-badge "Contributors"
[contributors-url]: https://github.com/sebastienrousseau/dotfiles/graphs/contributors "List of contributors"
[divider]: https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/assets/divider.svg "Divider"
[download_button]: https://github.com/sebastienrousseau/dotfiles/raw/master/assets/button-secondary.svg "Download"
[forks-shield]: https://img.shields.io/github/forks/sebastienrousseau/dotfiles.svg?style=for-the-badge "Forks"
[fossa]: https://app.fossa.io/api/projects/git%2Bgithub.com%2Freedia%2Fdotfiles.svg?type=large "FOSSA"
[getting_started]: https://github.com/sebastienrousseau/dotfiles/raw/master/assets/button-primary.svg "Getting Started"
[logo]: https://github.com/sebastienrousseau/dotfiles/raw/master/assets/dotfiles.svg "Dotfiles"
[love]: https://github.com/sebastienrousseau/dotfiles/raw/master/assets/made-with-love.svg "Made with love"
