<p align="center">
  <img src="Dotfiles.png" alt="Dotfiles Logo" title="Dotfiles Logo">
</p>


[![NPM](https://nodei.co/npm/reedia-dotfiles.png)](https://nodei.co/npm/reedia-dotfiles/)


[![npm version](https://badge.fury.io/js/reedia-dotfiles.svg)](https://badge.fury.io/js/reedia-dotfiles)
[![Build Status](https://travis-ci.org/reedia/dotfiles.svg?branch=master)](https://travis-ci.org/reedia/dotfiles)
[![Packagist](https://img.shields.io/badge/license-MIT-blue.svg)](https://skeletonic.github.io/license)

# Dotfiles
## Mac OS X Dotfiles

Simply designed to fit your shell life.

<a href="https://github.com/reedia/dotfiles/releases/latest">Download Dotfiles</a>

## Table of contents

-   [Getting Started](#getting-started)
-   [What's in the box](#whats-in-the-box)
-   [Terminal Cheatsheet](#terminal-cheatsheet)
-   [Contributing](#contributing)
-   [Code of Conduct](#code-of-conduct)
-   [Our Values](#our-values)
-   [History](#history)
-   [License](#license)
-   [Acknowledgements](#acknowledgements)

## Getting Started

A few options are available:

-   Download the latest [release](https://github.com/reedia/dotfiles/releases/latest)
-   Or simply clone the main repository: `git clone https://github.com/reedia/dotfiles.git`

## What's in the box

Within the release you'll find the following files and folders:

```
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
├── installers
└── package.json

```

## Terminal Cheatsheet

The Terminal on macOS offers quite an amount of functionality, but most of it is hard to discover unless you already know what you’re looking for. So here’s a quick cheat sheet explaining unique functions with their corresponding key combos:

### Marks

Marks allow you to mark certain lines in the output, and allow you to jump between different parts of the output.

By default, every time you hit enter on your prompt, Terminal will automatically insert a mark for you. You can configure this in the `Edit` menu, under `Marks` with the option `Automatically Mark Prompt Lines`.

Marks are visualised in the Terminal window as light grey square brackets (They are not, however, part of the output).

*   `Cmd-⬆`: Jump to previous mark
*   `Cmd-⬇`: Jump to next mark
*   `Cmd-Shift-A`: Selects the output between the current marks
*   `Cmd-Enter`: `Enter`, and will always create a mark
*   `Cmd-Shift-Enter`: `Enter`, but will never create a mark
*   `Cmd-U`: Create mark
*   `Cmd-Shift-U`: Remove mark
*   `Cmd-L`: Clear screen to previous mark

### Bookmarks

Similar to marks, they can optionally be named, and are more useful to denote larger sections of the output. They are denoted by light grey bars.

*   `Cmd-Shift-M`: Insert Bookmark
*   `Cmd-Option-U`: Mark current line as bookmark
*   `Cmd-Shift-Option-M`: Insert named bookmark
*   `Cmd-Option-⬆`: Jump to previous bookmark
*   `Cmd-Option-⬇`: Jump to next bookmark
*   `Cmd-Option-L`: Clear to previous bookmark

### Panes

View different parts of the scrollback buffer of the same terminal.

*   `Cmd-D`: Split window into panes
*   `Cmd-Shift-D`: close split pane

## Miscellaneous

*   `Cmd-K`: Clear everything
*   `Cmd-Option-K`: Clear scroll back (everything except what you see on the screen)
*   `Cmd-Option-O`: Toggle use of option as meta key
*   `Cmd-Ctrl-V`: Paste escaped text. Useful for pasting e.g. paths containing whitespace.
*   `Cmd-Shift-Option-C`: Copy as plain text
*   `Cmd-Option-PageUp` or `PageDown`: Scroll one line up/down
*   `Cmd-[` or `]`: Switch between windows
*   `Cmd-Shift-[` or `]`: Switch between tabs

(Some of this I learned from mjtsai’s post [Mac Terminal Tips](http://mjtsai.com/blog/2016/09/26/mac-terminal-tips/), which is a great jumping off point for further interesting things the Terminal can do)

## Contributing

Please read carefully through our [Contributing Guidelines](https://github.com/reedia/dotfiles/blob/master/CONTRIBUTING.md) for further details on the process for submitting pull requests to us.

## Code of Conduct
We are committed to preserving and fostering a diverse, welcoming community. Please read our [Code of Conduct](https://github.com/reedia/dotfiles/blob/master/CODE_OF_CONDUCT.md).

## Our Values
1.  We believe perfection must consider everything.
2.  We take our passion beyond Code into our daily practices.
3.  We are just obsessed about creating and delivering exceptional solutions.

## History

*   See [Dotfiles Release](https://github.com/reedia/dotfiles/releases) list.

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/reedia/dotfiles/blob/master/LICENSE) file for details


[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Freedia%2Fdotfiles.svg?type=large)](https://app.fossa.io/projects/git%2Bgithub.com%2Freedia%2Fdotfiles?ref=badge_large)

## Acknowledgements

[Dotfiles](https://dotfiles.io) is beautifully crafted by these people and a bunch of awesome [contributors](https://github.com/reedia/dotfiles/graphs/contributors)

| [![Sebastien Rousseau](https://avatars0.githubusercontent.com/u/1394998?s=117)](http://sebastienrousseau.co.uk) | [![Graham Colgate](https://avatars0.githubusercontent.com/u/35816108?s=117)](https://github.com/gramtech) |
| :-------------------------------------------------------------------------------------------------------------: | :-------------------------------------------------------------------------------------------------------------: |
| [Sebastien Rousseau](https://github.com/sebastienrousseau) | [Graham Colgate](https://github.com/gramtech) |

## About Reedia

![Reedia](https://avatars0.githubusercontent.com/u/488747?s=200)
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Freedia%2Fdotfiles.svg?type=shield)](https://app.fossa.io/projects/git%2Bgithub.com%2Freedia%2Fdotfiles?ref=badge_shield)