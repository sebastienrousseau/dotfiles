# Dotfiles aliases

![Banner representing the Dotfiles Library](/media/dotfiles.svg)

The `heroku.plugin.zsh` file creates helpful shortcut aliases for many commonly
[Heroku](https://www.heroku.com/) commands.

## Table of Contents

- [Dotfiles aliases](#dotfiles-aliases)
  - [Table of Contents](#table-of-contents)
      - [1.0 Homebrew Core aliases](#10-homebrew-core-aliases)
      - [1.1 Homebrew Access aliases](#11-homebrew-access-aliases)
      - [1.2 Control Homebrew's anonymous aggregate user behaviour analytics](#12-control-homebrews-anonymous-aggregate-user-behaviour-analytics)
      - [1.3 Uninstall formulae that were only installed as a dependency of another formula and are now no longer needed](#13-uninstall-formulae-that-were-only-installed-as-a-dependency-of-another-formula-and-are-now-no-longer-needed)
      - [1.4 Remove stale lock files and outdated downloads for all formulae and casks, and remove old versions of installed formulae](#14-remove-stale-lock-files-and-outdated-downloads-for-all-formulae-and-casks-and-remove-old-versions-of-installed-formulae)
      - [1.5 Show lists of built-in and external commands](#15-show-lists-of-built-in-and-external-commands)
      - [1.6 Control whether Homebrew automatically links external tap shell completion files](#16-control-whether-homebrew-automatically-links-external-tap-shell-completion-files)
      - [1.7 Show Homebrew and system configuration info useful for debugging](#17-show-homebrew-and-system-configuration-info-useful-for-debugging)
      - [1.8 Show dependencies for formula](#18-show-dependencies-for-formula)

#### 1.0 Homebrew Core aliases

#### 1.1 Homebrew Access aliases

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| br    | `brew`                                   | The Missing Package Manager for macOS (or Linux).  |

#### 1.2 Control Homebrew's anonymous aggregate user behaviour analytics

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| bra      | `brew analytics`                                     | Display the current state of Homebrew's analytics.  |
| braon    | `brew analytics on`                                  | Turn Homebrew's analytics on.  |
| braoff   | `brew analytics off`                                 | Turn Homebrew's analytics off.  |
| brareg   | `brew analytics regenerate-uuid`                     | Regenerate the UUID used for Homebrew's analytics.  |

#### 1.3 Uninstall formulae that were only installed as a dependency of another formula and are now no longer needed
| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brx     | `brew autoremove`                        | Uninstall formulae that were only installed as a dependency of another formula and are now no longer needed.  |
| brxdry  | `brew autoremove -n`                     | List what would be uninstalled, but do not actually uninstall anything (--dry-run).  |

#### 1.4 Remove stale lock files and outdated downloads for all formulae and casks, and remove old versions of installed formulae

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brc       | `brew cleanup`                            | Cleans Homebrew's cache.  |
| brcdry    | `brew cleanup -n`                         | Show what would be removed, but do not actually remove anything (--dry-run).  |
| brcp      | `brew cleanup --prune "$1"`               | Remove all cache files older than specified days.  |
| brcpp     | `brew cleanup --prune-prefix "$1"`        | Only prune the symlinks and directories from the prefix and remove no other files.  |
| brcs      | `brew cleanup -s`                         |  Scrub the cache, including downloads for even the latest versions.  |

#### 1.5 Show lists of built-in and external commands

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brcom     | `brew command "$1"`                         | Display the path to the file being used when invoking brew cmd.  |
| brcoms    | `brew commands`                             | Show lists of built-in and external commands.  |
| brcomsa   | `brew commands --include-aliases`           | Include aliases of internal commands. (--include-aliases).  |
| brcomsq   | `brew commands --quiet`                     | List only the names of commands without category headers. (--quiet).  |

#### 1.6 Control whether Homebrew automatically links external tap shell completion files

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brcomp          | `brew completions "$1"`                         | Display the current state of Homebrew's completions.  |
| brcomplink      | `brew completions link`                         |  Link Homebrew's completions.  |
| brcompunlink    | `brew completions unlink`                       |  Unlink Homebrew's completions.  |

#### 1.7 Show Homebrew and system configuration info useful for debugging

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brconf     | `brew config`                       | Show Homebrew and system configuration info useful for debugging.  |

#### 1.8 Show dependencies for formula

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brdei      | `brew deps --installed`            | List dependencies for formulae that are currently installed. If formula is specified, list only its dependencies that are currently installed. |
| brdep      | `brew deps`                        | Show dependencies for formula. |
| brdep1     | `brew deps --1`                    | Only show dependencies one level down, instead of recursing. |
| brdepall   | `brew deps --all`                  | List dependencies for all available formulae. |
| brdepan    | `brew deps --annotate`             | Mark any build, test, optional, or recommended dependencies as such in the output. |
| brdepb     | `brew deps --include-build`        | Include :build dependencies for formula. |
| brdepcask  | `brew deps --cask`                 | Treat all named arguments as casks. |
| brdepfe    | `brew deps --for-each`             | Switch into the mode used by the --all option, but only list dependencies for each provided formula, one formula per line. |
| brdepfm    | `brew deps --formula`              | Treat all named arguments as formulae. |
| brdepfn    | `brew deps --full-name`            | List dependencies by their full name. |
| brdepo     | `brew deps --include-optional`     | Include :optional dependencies for formula. |
| brdepr     | `brew deps --include-requirements` | Include requirements in addition to dependencies for formula. |
| brdepskip  | `brew deps --skip-recommended`     | Skip :recommended dependencies for formula. |
| brdept     | `brew deps -n`                     | Sort dependencies in topological order. |
| brdeptest  | `brew deps --include-test`         | Include :test dependencies for formula (non-recursive). |
| brdeptree  | `brew deps --tree`                 | Show dependencies as a tree. When given multiple formula arguments, show individual trees for each formula. |
| brdepu     | `brew deps --union`                | Show the union of dependencies for multiple formula, instead of the intersection. |
