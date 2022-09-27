# Dotfiles

![Banner representing the Dotfiles Library](/assets/dotfiles.svg)

![Codacy grade](https://img.shields.io/codacy/grade/634cfc4de08e492ebcbb341631066241?style=for-the-badge)
[![Contributors][contributors-shield]](https://github.com/sebastienrousseau/dotfiles/graphs/contributors)
[![Forks][forks-shield]](https://github.com/sebastienrousseau/dotfiles/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge\&color=ff69b4)](https://opensource.org/licenses/MIT)
![Made with Love](/assets/made-with-love.svg)

## Table of contents

- [Dotfiles](#dotfiles)
  - [Table of contents](#table-of-contents)
  - [About Dotfiles](#about-dotfiles)
    - [Getting Started](#getting-started)
    - [Installation](#installation)
      - [Installation Methods](#installation-methods)
        - [1. Installing from a Content Delivery Network (CDN)](#1-installing-from-a-content-delivery-network-cdn)
        - [2. Installing from GitHub](#2-installing-from-github)
        - [3. Install from NPM](#3-install-from-npm)
        - [4. Install the npm command line interface](#4-install-the-npm-command-line-interface)
        - [Check installation](#check-installation)
      - [Install Dotfiles via Yarn](#install-dotfiles-via-yarn)
  - [In this repository](#in-this-repository)
    - [Directory Structure](#directory-structure)
  - [Requirements](#requirements)
  - [Contributing](#contributing)
  - [Code of Conduct](#code-of-conduct)
  - [Our Values](#our-values)
  - [History](#history)
  - [Acknowledgements](#acknowledgements)
  - [License](#license)

## About Dotfiles

Dotfiles aggregates a collection of standalone configuration files (dotfiles) that can be used to customize your development environment across
numerous computers and operating systems into one cohesive and consistent approach.

### Getting Started

This repository contains the source code for multiple dotfiles and shell/terminal configurations.

These configurations consist of the following files:

- [Curl dotfiles](./shell/plugins/curl/curlrc) - The curl configuration file.
- [JSHint dotfiles](./shell/plugins/jshint/jshintrc) - The JSHint configuration file.
- [TMUX dotfiles](./shell/plugins/tmux/tmux) - The TMUX configuration file.
- [Vim dotfiles](./shell/plugins/vim/vimrc) - The vim configuration file.
- [Wget dotfiles](./shell/plugins/wget/wgetrc) - The wget configuration file.

### Installation

A few different installation methods are available:

#### Installation Methods

##### 1. Installing from a Content Delivery Network (CDN)

The most widely used installation method is from a Content Delivery Network (CDN). This method is the easiest and fastest way to install Dotfiles and the recommended method for most users.

##### 2. Installing from GitHub

Clone the main repository to get all source files including build scripts:

```bash
https://github.com/sebastienrousseau/dotfiles.git
```

[Download Dotfiles](https://github.com/sebastienrousseau/dotfiles/releases/latest)

##### 3. Install from NPM

To use Dotfiles, you will need the npm JavaScript package manager.

##### 4. Install the npm command line interface

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

### Directory Structure

```bash

./
├── assets/ # Contains the assets for the README.md file.
│   ├── README.md # The README.md file.
│   ├── dotfiles.svg # The Dotfiles logo.
│   └── made-with-love.svg # The made with love icon.
├── bin/ # The bin directory contains executable files.
│   └── dotfiles.sh # The dotfiles executable file.
├── installer/ # The installer directory contains the installation scripts.
│   ├── en/ # The en directory contains the English installation scripts.
│   │   ├── configuration/ # The configuration directory contains the configuration scripts.
│   │   │   ├── deploy.sh* # The deploy script.
│   │   │   ├── menu.sh # The menu script.
│   │   │   ├── setup.sh* # The setup script.
│   │   │   └── symlinks-en.sh* # The symlinks script.
│   │   ├── git/ # The git directory contains the git scripts.
│   │   │   ├── config/ # The config directory contains the git configuration scripts.
│   │   │   │   └── git/
│   │   │   │       └── template/
│   │   │   │           └── HEAD
│   │   │   ├── README.md
│   │   │   ├── gitattributes
│   │   │   ├── gitconfig
│   │   │   ├── gitignore
│   │   │   └── gitmessage
│   │   ├── homebrew/
│   │   │   ├── 01-install.sh*
│   │   │   ├── 02-brew-tap.sh
│   │   │   ├── 03-brew-package.sh
│   │   │   ├── 04-brew-cask.sh
│   │   │   └── README.md
│   │   └── README.md
│   ├── README.md
│   ├── colors.sh* # The colors script.
│   ├── functions.sh* # The functions script.
│   ├── install.sh* # The install script.
│   ├── utilities.sh* # The utilities script.
│   └── variables.sh* # The variables script.
├── shell/
│   ├── aliases/
│   │   ├── default/
│   │   │   ├── README.md
│   │   │   └── aliases.plugin.sh # The default aliases plugin.
│   │   ├── gcloud/
│   │   │   ├── README.md
│   │   │   └── gcloud.plugin.sh # The gcloud aliases plugin.
│   │   ├── git/
│   │   │   ├── README.md
│   │   │   └── git.plugin.sh # The git aliases plugin.
│   │   ├── heroku/
│   │   │   ├── README.md
│   │   │   └── heroku.plugin.sh # The heroku aliases plugin.
│   │   ├── jekyll/
│   │   │   ├── README.md
│   │   │   └── jekyll.plugin.sh # The jekyll aliases plugin.
│   │   ├── subversion/
│   │   │   ├── README.md
│   │   │   └── subversion.plugin.sh # The subversion aliases plugin.
│   │   ├── tmux/
│   │   │   ├── README.md
│   │   │   └── tmux.plugin.sh # The tmux aliases plugin.
│   │   └── README.md
│   ├── bash/
│   │   └── bashrc # The bashrc file.
│   ├── configurations/
│   │   ├── README.md
│   │   ├── color.sh
│   │   ├── editor.sh
│   │   ├── options.old
│   │   └── prompt.sh
│   ├── functions/
│   │   ├── README.md
│   │   ├── cdls.sh # The cdls function.
│   │   ├── changediskpwd.sh # The changediskpwd function.
│   │   ├── code.sh # The code function.
│   │   ├── countdown.sh # The countdown function.
│   │   ├── curlheader.sh # The curlheader function.
│   │   ├── curltime.sh # The curltime function.
│   │   ├── environment.sh # The environment function.
│   │   ├── extract.sh # The extract function.
│   │   ├── filehead.sh # The filehead function.
│   │   ├── genpwd.sh # The genpwd function.
│   │   ├── goto.sh # The goto function.
│   │   ├── headers.sh # The headers function.
│   │   ├── hidehiddenfiles.sh # The hidehiddenfiles function.
│   │   ├── history-all.sh # The history-all function.
│   │   ├── hostinfo.sh # The hostinfo function.
│   │   ├── hstats.sh # The hstats function.
│   │   ├── httpdebug.sh # The httpdebug function.
│   │   ├── keygen.sh # The keygen function.
│   │   ├── last.sh # The last function.
│   │   ├── logout.sh # The logout function.
│   │   ├── lowercase.sh # The lowercase function.
│   │   ├── matrix.sh # The matrix function.
│   │   ├── mcd.sh # The mcd function.
│   │   ├── mount_read_only.sh # The mount_read_only function.
│   │   ├── myproc.sh # The myproc function.
│   │   ├── prependpath.sh # The prependpath function.
│   │   ├── print.sh # The print function.
│   │   ├── ql.sh # The ql function.
│   │   ├── rd.sh # The rd function.
│   │   ├── remove_disk.sh # The remove_disk function.
│   │   ├── ren.sh # The ren function.
│   │   ├── rm.sh # The rm function.
│   │   ├── rps.sh # The rps function.
│   │   ├── showhiddenfiles.sh # The showhiddenfiles function.
│   │   ├── size.sh # The size function.
│   │   ├── stopwatch.sh # The stopwatch function.
│   │   ├── trash.sh # The trash function.
│   │   ├── tree.sh # The tree function.
│   │   ├── uppercase.sh # The uppercase function.
│   │   ├── uuidgen.sh # The uuidgen function.
│   │   ├── view-source.sh # The view-source function.
│   │   ├── whoisport.sh # The whoisport function.
│   │   └── zipf.sh # The zipf function.
│   ├── paths/
│   │   ├── default/
│   │   │   └── default.path.sh # The default paths.
│   │   ├── homebrew/
│   │   │   └── homebrew.path.sh # The homebrew paths.
│   │   ├── java/
│   │   │   └── java.path.sh # The java paths.
│   │   ├── pnpm/
│   │   │   └── pnpm.path.sh # The pnpm paths.
│   │   └── tmux/
│   │       └── tmux.path.sh # The tmux paths.
│   ├── plugins/
│   │   ├── curl/
│   │   │   ├── cacert.pem # The cacert.pem file.
│   │   │   └── curlrc # The curlrc file.
│   │   ├── encode64/
│   │   │   ├── README.md
│   │   │   └── encode64.plugin.sh # The encode64 aliases plugin.
│   │   ├── jshint/
│   │   │   └── jshintrc # The jshintrc file.
│   │   ├── macos/
│   │   │   └── macos.plugin.sh # The macos plugin.
│   │   ├── profile/
│   │   │   └── profile # The profile file.
│   │   ├── tmux/
│   │   │   └── tmux # The tmux plugin.
│   │   ├── vim/
│   │   │   └── vimrc # The vimrc plugin.
│   │   ├── vscode/
│   │   │   ├── README.md
│   │   │   └── vscode.plugin.sh
│   │   ├── wget/
│   │   │   └── wgetrc
│   │   └── zsh/
│   │       └── zshrc
│   ├── README.md
│   ├── aliases.sh
│   ├── configurations.sh
│   ├── exit.sh
│   ├── functions.sh
│   ├── history.sh
│   ├── paths.sh
│   └── plugins.sh
├── CODEOWNERS
├── COPYRIGHT
├── LICENSE
├── Makefile
├── README.md
└── pnpm-lock.yaml

39 directories, 123 files


```

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

1. We believe perfection must consider everything.
2. We take our passion beyond Code into our daily practices.
3. We are just obsessed about creating and delivering exceptional solutions.

## History

- See [Dotfiles Release](https://github.com/sebastienrousseau/dotfiles/releases) list.

## Acknowledgements

[Dotfiles](https://dotfiles.io) is beautifully crafted by these people and a bunch of awesome [contributors](https://github.com/sebastienrousseau/dotfiles/graphs/contributors)

| [![Sebastien Rousseau](https://avatars0.githubusercontent.com/u/1394998?s=117)](http://sebastienrousseau.co.uk) | [![Graham Colgate](https://avatars0.githubusercontent.com/u/35816108?s=117)](https://github.com/gramtech) |
| :-------------------------------------------------------------------------------------------------------------: | :-------------------------------------------------------------------------------------------------------------: |
| [Sebastien Rousseau](https://github.com/sebastienrousseau) | [Graham Colgate](https://github.com/gramtech) |

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/sebastienrousseau/dotfiles/blob/master/LICENSE) file for details

[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Freedia%2Fdotfiles.svg?type=large)](https://app.fossa.io/projects/git%2Bgithub.com%2Freedia%2Fdotfiles?ref=badge_large)

