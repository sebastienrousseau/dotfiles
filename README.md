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

[ 704]  ./
├── [ 160]  assets/
│   ├── [ 583]  README.md
│   ├── [ 41K]  dotfiles.svg
│   └── [1.4K]  made-with-love.svg
├── [  96]  bin/
│   └── [1.1K]  dotfiles.sh
├── [ 320]  installer/
│   ├── [ 224]  en/
│   │   ├── [ 192]  configuration/
│   │   │   ├── [1.9K]  deploy.sh*
│   │   │   ├── [1.7K]  menu.sh
│   │   │   ├── [ 635]  setup.sh*
│   │   │   └── [1.6K]  symlinks-en.sh*
│   │   ├── [ 256]  git/
│   │   │   ├── [  96]  config/
│   │   │   │   └── [  96]  git/
│   │   │   │       └── [  96]  template/
│   │   │   │           └── [  20]  HEAD
│   │   │   ├── [  86]  README.md
│   │   │   ├── [ 182]  gitattributes
│   │   │   ├── [5.8K]  gitconfig
│   │   │   ├── [1.4K]  gitignore
│   │   │   └── [ 288]  gitmessage
│   │   ├── [ 224]  homebrew/
│   │   │   ├── [ 836]  01-install.sh*
│   │   │   ├── [1.4K]  02-brew-tap.sh
│   │   │   ├── [ 13K]  03-brew-package.sh
│   │   │   ├── [6.7K]  04-brew-cask.sh
│   │   │   └── [  86]  README.md
│   │   └── [  86]  README.md
│   ├── [  86]  README.md
│   ├── [2.7K]  colors.sh*
│   ├── [5.0K]  functions.sh*
│   ├── [ 232]  install.sh*
│   ├── [1.0K]  utilities.sh*
│   └── [ 687]  variables.sh*
├── [ 544]  shell/
│   ├── [ 352]  aliases/
│   │   ├── [ 128]  default/
│   │   │   ├── [   0]  README.md
│   │   │   └── [ 14K]  aliases.plugin.sh
│   │   ├── [ 128]  gcloud/
│   │   │   ├── [8.2K]  README.md
│   │   │   └── [7.5K]  gcloud.plugin.sh
│   │   ├── [ 128]  git/
│   │   │   ├── [ 22K]  README.md
│   │   │   └── [ 20K]  git.plugin.shold
│   │   ├── [ 128]  heroku/
│   │   │   ├── [ 41K]  README.md
│   │   │   └── [ 31K]  heroku.plugin.sh
│   │   ├── [ 128]  jekyll/
│   │   │   ├── [1.7K]  README.md
│   │   │   └── [1.9K]  jekyll.plugin.sh
│   │   ├── [ 128]  subversion/
│   │   │   ├── [4.1K]  README.md
│   │   │   └── [3.7K]  subversion.plugin.sh
│   │   ├── [ 128]  tmux/
│   │   │   ├── [   0]  README.md
│   │   │   └── [ 619]  tmux.plugin.sh
│   │   └── [ 22K]  README.md
│   ├── [  96]  bash/
│   │   └── [1.9K]  bashrc
│   ├── [ 224]  configurations/
│   │   ├── [  86]  README.md
│   │   ├── [ 437]  color.sh
│   │   ├── [ 279]  editor.sh
│   │   ├── [2.9K]  options.old
│   │   └── [1.0K]  prompt.sh
│   ├── [1.4K]  functions/
│   │   ├── [  86]  README.md
│   │   ├── [ 422]  cdls.sh
│   │   ├── [ 390]  changediskpwd.sh
│   │   ├── [ 377]  code.sh
│   │   ├── [ 701]  countdown.sh
│   │   ├── [ 666]  curlheader.sh
│   │   ├── [1.1K]  curltime.sh
│   │   ├── [ 929]  environment.sh
│   │   ├── [ 894]  extract.sh
│   │   ├── [ 130]  filehead.sh
│   │   ├── [ 638]  genpwd.sh
│   │   ├── [ 440]  goto.sh
│   │   ├── [ 247]  headers.sh
│   │   ├── [ 501]  hidehiddenfiles.sh
│   │   ├── [ 377]  history-all.sh
│   │   ├── [ 762]  hostinfo.sh
│   │   ├── [ 511]  hstats.sh
│   │   ├── [ 540]  httpdebug.sh
│   │   ├── [ 645]  keygen.sh
│   │   ├── [ 109]  last.sh
│   │   ├── [ 411]  logout.sh
│   │   ├── [ 914]  lowercase.sh
│   │   ├── [ 763]  matrix.sh
│   │   ├── [ 587]  mcd.sh
│   │   ├── [ 419]  mount_read_only.sh
│   │   ├── [ 397]  myproc.sh
│   │   ├── [ 921]  prependpath.sh
│   │   ├── [ 434]  print.sh
│   │   ├── [ 364]  ql.sh
│   │   ├── [ 529]  rd.sh
│   │   ├── [ 346]  remove_disk.sh
│   │   ├── [ 415]  ren.sh
│   │   ├── [ 451]  rm.sh
│   │   ├── [2.2K]  rps.sh*
│   │   ├── [ 502]  showhiddenfiles.sh
│   │   ├── [ 467]  size.sh
│   │   ├── [ 451]  stopwatch.sh
│   │   ├── [ 436]  trash.sh
│   │   ├── [ 496]  tree.sh
│   │   ├── [ 929]  uppercase.sh
│   │   ├── [ 456]  uuidgen.sh
│   │   ├── [ 197]  view-source.sh
│   │   ├── [ 264]  whoisport.sh
│   │   └── [ 510]  zipf.sh
│   ├── [ 224]  paths/
│   │   ├── [  96]  default/
│   │   │   └── [ 746]  default.path.sh
│   │   ├── [  96]  homebrew/
│   │   │   └── [ 714]  homebrew.path.sh
│   │   ├── [  96]  java/
│   │   │   └── [ 530]  java.path.sh
│   │   ├── [  96]  pnpm/
│   │   │   └── [ 351]  pnpm.path.sh
│   │   └── [  96]  tmux/
│   │       └── [ 261]  tmux.path.sh
│   ├── [ 416]  plugins/
│   │   ├── [ 128]  curl/
│   │   │   ├── [217K]  cacert.pem
│   │   │   └── [ 374]  curlrc
│   │   ├── [ 128]  encode64/
│   │   │   ├── [ 963]  README.md
│   │   │   └── [ 448]  encode64.plugin.sh
│   │   ├── [  96]  jshint/
│   │   │   └── [ 642]  jshintrc
│   │   ├── [  96]  macos/
│   │   │   └── [2.3K]  macos.plugin.sh
│   │   ├── [  96]  profile/
│   │   │   └── [ 930]  profile
│   │   ├── [  96]  tmux/
│   │   │   └── [7.4K]  tmux
│   │   ├── [  96]  vim/
│   │   │   └── [4.1K]  vimrc
│   │   ├── [ 128]  vscode/
│   │   │   ├── [1.6K]  README.md
│   │   │   └── [3.2K]  vscode.plugin.sh
│   │   ├── [  96]  wget/
│   │   │   └── [1.2K]  wgetrc
│   │   └── [  96]  zsh/
│   │       └── [1.9K]  zshrc
│   ├── [  86]  README.md
│   ├── [ 254]  aliases.sh
│   ├── [ 254]  configurations.sh
│   ├── [ 193]  exit.sh
│   ├── [ 228]  functions.sh
│   ├── [3.8K]  history.sh
│   ├── [ 241]  paths.sh
│   └── [ 226]  plugins.sh
├── [  28]  CODEOWNERS
├── [ 150]  COPYRIGHT
├── [ 67K]  LICENSE
├── [ 817]  Makefile
├── [6.2K]  README.md
└── [ 297]  pnpm-lock.yaml

39 directories, 123 files


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


