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

## 👋 Welcome to Dotfiles (v0.2.455)

### Simply designed to fit your shell life

Dotfiles are a set of macOS, Linux and Windows configuration files. They are
aimed at making your life easier by providing a set of scripts and configuration
files with new ways to get things done.

[![Getting Started][getting_started]][getting-started]
[![Download Dotfiles v0.2.455][download_button]][download]

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
- A Debian based distribution (Debian, Ubuntu, PoP!_OS, Zorin OS, Q4OS, Kali Linux, Devuan, Deepin, etc.)

![divider][divider]

#### ✔️ Software Requirements

The following programs must be installed on your system to install Dotfiles:

- [**Bash**][bash] - a shell, or command language interpreter, for the GNU
  operating system.
- Or [**Zsh**][zsh] - a shell designed for interactive use, although it is also a
  powerful scripting language.
- [**Git**][git] - a free and open source distributed version control system
  designed to handle everything from small to very large projects with speed and efficiency.
- [**Curl**][curl] - a command line tool for transferring data with URL syntax.
- [**Wget**][wget] - a free software package for retrieving files using HTTP,
  HTTPS and FTP, the most widely-used Internet protocols.
- [**Make**][make] - a tool which controls the generation of executables and other
  non-source files of a program from the program's source files.
- [**Shell**][shell] - a shell command line interpreter program for Unix-like
  operating systems.
- [**PnPM**][pnpm] - a package manager for JavaScript and Node.js. It is fast,
  disk space efficient and reliable.

### 1️⃣ Download Dotfiles

You can download the latest version (v0.2.455) with the following options:

- [**Manual download**][releases] - **The easiest way to install Dotfiles.**
- [**Install with PnPM**](https://www.npmjs.com/package/@sebastienrousseau/dotfiles)
  `pnpm i -g @sebastienrousseau/dotfiles`.
- [**Install with Npm**](https://www.npmjs.com/package/@sebastienrousseau/dotfiles)
  `npm install -g @sebastienrousseau/dotfiles`.
- [**Install with Yarn**](https://yarnpkg.com/package/@sebastienrousseau/dotfiles)
  `yarn global add @sebastienrousseau/dotfiles`.
- **Clone the main repository** to get all source files including build scripts:
  `git clone https://github.com/sebastienrousseau/dotfiles.git`. This will clone
  the latest version of the Dotfiles repository.

### 2️⃣ Back Up Your Existing Data

Before installing Dotfiles, we strongly recommend that you back up your existing
data. The Dotfiles installer will try to automatically backup any previous
installation of known dotfiles into a backup directory
`$HOME/.dotfiles_backup`.

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

It is always a good idea to backup as there might be situations in which you could be required to restore your previous installation.

### 3️⃣ Try it out and let us know what you think

To install the latest version of the dotfiles, run the following command:

#### Using make (easiest)

The easiest way to install Dotfiles is to use the `make` command. This will
install the latest version of the dotfiles and will automatically backup
any existing dotfiles you may have into a backup directory
`$HOME/dotfiles_backup`.

The installer will check if you have PnPM installed to switch to the PnPM installation method. If not, it will fallback to equivalent shell scripts.

Switch to the `dist` directory and run:

```bash
make assemble
```

You can also just check the installer options available, by simply running:

```bash
make help
```

#### Using PnPM (highly recommended if you have PnPM installed)

PnPM is a key dependency of the dotfiles package. It will help you install the
dotfiles rapidly and very efficiently.

Switch to the `dist` directory and run:

```bash
pnpm run assemble
```

### Post installation

Following the installation, you can verify that the dotfiles package is installed
in the following directory `$HOME/.dotfiles_backup`.

Just quit your terminal and restart it. If the installation is successful, you
should be able to see a new interface of your terminal and be able to start
using the dotfiles aliases and other configurations.

Please refer to the [documentation][docs] for more information.

![divider][divider]

### 4️⃣ What's included

Dotfiles contains core elements that are used to configure your shell, and other components catered for your environment setup.

Within the download you'll find all the Dotfiles source files grouped within the
`dist` folder.

You'll see something like this:

```bash
.
├── bin
│   └── dotfiles.sh
├── shell
│   ├── aliases
│   │   ├── default
│   │   │   ├── README.md
│   │   │   └── default.aliases.sh    # Default aliases.
│   │   ├── gcloud
│   │   │   └── gcloud.aliases.sh     # GCloud aliases.
│   │   ├── git
│   │   ├── heroku
│   │   │   └── heroku.aliases.sh     # Heroku aliases.
│   │   ├── jekyll
│   │   │   └── jekyll.aliases.sh     # Jekyll aliases.
│   │   ├── pnpm
│   │   │   └── pnpm.aliases.sh       # Pnpm aliases.
│   │   ├── subversion
│   │   │   └── subversion.aliases.sh # Subversion aliases.
│   │   └── tmux
│   │       └── tmux.aliases.sh       # Tmux aliases.
│   ├── configurations
│   │   ├── bash
│   │   │   └── bashrc                # Bashrc configuration file.
│   │   ├── curl
│   │   │   ├── cacert.pem            # CA Certificates.
│   │   │   └── curlrc                # Curlrc configuration file.
│   │   ├── default
│   │   │   ├── color.sh              # Color definitions.
│   │   │   ├── editor.sh             # Editor definitions.
│   │   │   └── prompt.sh             # Prompt definitions.
│   │   ├── inputrc
│   │   │   └── inputrc               # Inputrc configuration file.
│   │   ├── jshint
│   │   │   └── jshintrc              # Jshintrc configuration file.
│   │   ├── profile
│   │   │   └── profile               # Profile configuration file.
│   │   ├── tmux
│   │   │   └── tmux                  # Tmux configuration file.
│   │   ├── vim
│   │   │   └── vimrc                 # Vimrc configuration file.
│   │   ├── wget
│   │   │   └── wgetrc                # Wgetrc configuration file.
│   │   ├── zsh
│   │   │   └── zshrc                 # Zshrc configuration file.
│   │   └── README.md
│   ├── functions
│   │   ├── README.md                 # Functions documentation.
│   │   ├── cdls.sh                   # cdls function.
│   │   ├── curlheader.sh             # curlheader function.
│   │   ├── curltime.sh               # curltime function.
│   │   ├── encode64.sh               # encode64 function.
│   │   ├── environment.sh            # environment function.
│   │   ├── extract.sh                # extract function.
│   │   ├── filehead.sh               # filehead function.
│   │   ├── genpwd.sh                 # genpwd function.
│   │   ├── goto.sh                   # goto function.
│   │   ├── hidehiddenfiles.sh        # hidehiddenfiles function.
│   │   ├── hostinfo.sh               # hostinfo function.
│   │   ├── hstats.sh                 # hstats function.
│   │   ├── httpdebug.sh              # httpdebug function.
│   │   ├── keygen.sh                 # keygen function.
│   │   ├── last.sh                   # last function.
│   │   ├── logout.sh                 # logout function.
│   │   ├── lowercase.sh              # lowercase function.
│   │   ├── macos.sh                  # macos function.
│   │   ├── matrix.sh                 # matrix function.
│   │   ├── mcd.sh                    # mcd function.
│   │   ├── mount_read_only.sh        # mount_read_only function.
│   │   ├── myproc.sh                 # myproc function.
│   │   ├── prependpath.sh            # prependpath function.
│   │   ├── ql.sh                     # ql function.
│   │   ├── rd.sh                     # rd function.
│   │   ├── remove_disk.sh            # remove_disk function.
│   │   ├── ren.sh                    # ren function.
│   │   ├── showhiddenfiles.sh        # showhiddenfiles function.
│   │   ├── size.sh                   # size function.
│   │   ├── stopwatch.sh              # stopwatch function.
│   │   ├── uppercase.sh              # uppercase function.
│   │   ├── view-source.sh            # view-source function.
│   │   ├── vscode.sh                 # vscode function.
│   │   ├── whoisport.sh              # whoisport function.
│   │   └── zipf.sh                   # zipf function.
│   ├── paths
│   │   ├── ant
│   │   │   └── ant.paths.sh          # Ant paths.
│   │   ├── default
│   │   │   └── default.paths.sh      # Default paths.
│   │   ├── homebrew
│   │   │   └── homebrew.paths.sh     # Homebrew paths.
│   │   ├── java
│   │   │   └── java.paths.sh         # Java paths.
│   │   ├── maven
│   │   │   └── maven.paths.sh        # Maven paths.
│   │   ├── node
│   │   │   └── node.paths.sh         # Node paths.
│   │   ├── nvm
│   │   │   └── nvm.paths.sh          # NVM paths.
│   │   ├── pnpm
│   │   │   └── pnpm.paths.sh         # Pnpm paths.
│   │   ├── python
│   │   │   └── python.paths.sh       # Python paths.
│   │   ├── ruby
│   │   │   └── ruby.paths.sh         # Ruby paths.
│   │   └── tmux
│   │       └── tmux.paths.sh         # Tmux paths.
│   ├── README.md                     # Dotfiles documentation.
│   ├── aliases.sh                    # Aliases loader file.
│   ├── configurations.sh             # Configurations loader file.
│   ├── exit.sh                       # Exit loader file.
│   ├── functions.sh                  # Functions loader file.
│   ├── history.sh                    # History loader file.
│   ├── index.d.ts                    # Typescript type information.
│   ├── index.d.ts.map                # Typescript type map information.
│   ├── index.js                      # Dotfiles main JS file.
│   ├── index.js.map                  # Dotfiles main JS map file.
│   └── paths.sh                      # Paths loader file.
├── Makefile                          # Makefile.
└── filesizes.txt                     # Filesizes in the `dist` directory.

35 directories, 83 files
```

## 🔗 Releases

Releases are available on the [GitHub releases page][releases].

![divider][divider]

## 🚥 Semantic versioning policy

For transparency into our release cycle and in striving to maintain backward
compatibility, `Dotfiles` follows [Semantic Versioning][semver-url]
(SemVer) and [ESLint's Semantic Versioning Policy][eslint-semantic-url].

![divider][divider]

## History

- See [Dotfiles Release](https://github.com/sebastienrousseau/dotfiles/releases)
  list.

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
great if you can give it a star ⭐ on [GitHub][github].

There are also many ways in which you can participate in this project, for
example:

- [Submit bugs and feature requests](https://github.com/sebastienrousseau/dotfiles/issues/new), and help us verify as they are checked in,
- Review [source code changes](https://github.com/sebastienrousseau/dotfiles/pulls), and help us improve our code quality,
- Review the [documentation](https://github.com/sebastienrousseau/dotfiles/docs) and make pull requests for anything from typos to additional and new content.

Please read carefully through our
[Contributing Guidelines][contributing]
for further details on the process for submitting pull requests to us.

![divider][divider]

## 🥂 License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/sebastienrousseau/dotfiles/blob/master/LICENSE) file for details.

[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Freedia%2Fdotfiles.svg?type=large)](https://app.fossa.io/projects/git%2Bgithub.com%2Freedia%2Fdotfiles?ref=badge_large)

![divider][divider]

## 🏢 Acknowledgements

[Dotfiles][website] is beautifully crafted by these people and a
bunch of awesome [contributors](https://github.com/sebastienrousseau/dotfiles/graphs/contributors)

| [![Sebastien Rousseau](https://avatars0.githubusercontent.com/u/1394998?s=117)](http://sebastienrousseau.co.uk) | [![Graham Colgate](https://avatars0.githubusercontent.com/u/35816108?s=117)](https://github.com/gramtech) |
| :-------------------------------------------------------------------------------------------------------------: | :-------------------------------------------------------------------------------------------------------------: |
| [Sebastien Rousseau](https://github.com/sebastienrousseau) | [Graham Colgate](https://github.com/gramtech) |

[bash]: https://www.gnu.org/software/bash/
[contributing]: https://github.com/sebastienrousseau/dotfiles/blob/master/.github/CONTRIBUTING.md
[curl]: https://curl.se/
[docs]: https://github.com/sebastienrousseau/dotfiles/docs
[download]: https://github.com/sebastienrousseau/dotfiles/archive/refs/tags/v0.2.455.tar.gz
[getting-started]: https://github.com/sebastienrousseau/dotfiles#getting-started
[git]: https://git-scm.com/
[github]: https://github.com/sebastienrousseau/dotfiles
[issues]: https://github.com/sebastienrousseau/dotfiles/issues
[make]: https://www.gnu.org/software/make/
[pnpm]: https://pnpm.io
[releases]: https://github.com/sebastienrousseau/dotfiles/releases
[shell]: https://www.gnu.org/software/shell/
[website]: https://dotfiles.io
[wget]: https://www.gnu.org/software/wget/
[zsh]: https://www.zsh.org/

[logo]: https://github.com/sebastienrousseau/dotfiles/raw/master/assets/dotfiles.svg
[download_button]: https://github.com/sebastienrousseau/dotfiles/raw/master/assets/button-secondary.svg
[getting_started]: https://github.com/sebastienrousseau/dotfiles/raw/master/assets/button-primary.svg
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
[semver-url]: http://semver.org/
[eslint-semantic-url]: https://github.com/eslint/eslint#semantic-versioning-policy
