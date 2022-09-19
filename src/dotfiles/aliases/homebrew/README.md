# Dotfiles aliases

![Banner representing the Dotfiles Library](/media/dotfiles.svg)

The `heroku.plugin.zsh` file creates helpful shortcut aliases for many commonly
[Heroku](https://www.heroku.com/) commands.

## Table of Contents

- [Dotfiles aliases](#dotfiles-aliases)
  - [Table of Contents](#table-of-contents)
    - [1.0 Homebrew Core aliases](#10-homebrew-core-aliases)
      - [1.1 Homebrew Access aliases](#11-homebrew-access-aliases)
      - [1.2 Control Homebrew anonymous aggregate user behaviour analytics](#12-control-homebrew-anonymous-aggregate-user-behaviour-analytics)
      - [1.3 Uninstall formulae that were only installed as a dependency of another formula and are now no longer needed](#13-uninstall-formulae-that-were-only-installed-as-a-dependency-of-another-formula-and-are-now-no-longer-needed)
      - [1.4 Remove stale lock files and outdated downloads for all formulae and casks, and remove old versions of installed formulae](#14-remove-stale-lock-files-and-outdated-downloads-for-all-formulae-and-casks-and-remove-old-versions-of-installed-formulae)
      - [1.5 Show lists of built-in and external commands](#15-show-lists-of-built-in-and-external-commands)
      - [1.6 Control whether Homebrew automatically links external tap shell completion files](#16-control-whether-homebrew-automatically-links-external-tap-shell-completion-files)
      - [1.7 Show Homebrew and system configuration info useful for debugging](#17-show-homebrew-and-system-configuration-info-useful-for-debugging)
      - [1.8 Show dependencies for formula](#18-show-dependencies-for-formula)
      - [1.9 Display formula's name and one-line description. Formula descriptions are cached; the cache is created on the first search, making that search slower than subsequent ones](#19-display-formulas-name-and-one-line-description-formula-descriptions-are-cached-the-cache-is-created-on-the-first-search-making-that-search-slower-than-subsequent-ones)
      - [2.0 Control Homebrew's developer mode](#20-control-homebrews-developer-mode)
      - [2.1 Check  your  system for potential problems](#21-check--your--system-for-potential-problems)
      - [2.2 Download a bottle (if available) or source packages for formulae and binaries for casks](#22-download-a-bottle-if-available-or-source-packages-for-formulae-and-binaries-for-casks)
      - [2.3 Display brief statistics for your Homebrew installation](#23-display-brief-statistics-for-your-homebrew-installation)
      - [2.4 Install a formula or cask. Additional options specific to a formula may be appended to the command](#24-install-a-formula-or-cask-additional-options-specific-to-a-formula-may-be-appended-to-the-command)
      - [2.5 List installed formulae that are not dependencies of another installed formula](#25-list-installed-formulae-that-are-not-dependencies-of-another-installed-formula)
      - [2.6 Symlink all of formula's installed files into Homebrew's prefix. This is done automatically when you install formulae but can be useful for DIY installations](#26-symlink-all-of-formulas-installed-files-into-homebrews-prefix-this-is-done-automatically-when-you-install-formulae-but-can-be-useful-for-diy-installations)
      - [2.7 List all installed formulae and casks](#27-list-all-installed-formulae-and-casks)
      - [2.8 Show the git log for formula, or show the log for the Homebrew repository if no formula is provided](#28-show-the-git-log-for-formula-or-show-the-log-for-the-homebrew-repository-if-no-formula-is-provided)
      - [2.9 Migrate renamed packages to new names, where formula are old names of packages](#29-migrate-renamed-packages-to-new-names-where-formula-are-old-names-of-packages)
      - [3.0 Check the given formula kegs for missing dependencies](#30-check-the-given-formula-kegs-for-missing-dependencies)
      - [3.1 Show install options specific to formula](#31-show-install-options-specific-to-formula)
      - [3.2 List installed casks and formulae that have an updated version available](#32-list-installed-casks-and-formulae-that-have-an-updated-version-available)
      - [3.3 Pin the specified formula, preventing them from being upgraded when issuing the brew upgrade formula command](#33-pin-the-specified-formula-preventing-them-from-being-upgraded-when-issuing-the-brew-upgrade-formula-command)
      - [3.4 Rerun the post-install steps for formula](#34-rerun-the-post-install-steps-for-formula)
      - [3.5 Import all items from the specified tap, or from all installed taps if none is provided](#35-import-all-items-from-the-specified-tap-or-from-all-installed-taps-if-none-is-provided)
      - [3.6  Uninstall and then reinstall a formula or cask using the same options it was originally installed with, plus any appended options specific to a formula](#36--uninstall-and-then-reinstall-a-formula-or-cask-using-the-same-options-it-was-originally-installed-with-plus-any-appended-options-specific-to-a-formula)
      - [3.7 Perform a substring search of cask tokens and formula names for text. If text is flanked by slashes, it is interpreted as a regular expression](#37-perform-a-substring-search-of-cask-tokens-and-formula-names-for-text-if-text-is-flanked-by-slashes-it-is-interpreted-as-a-regular-expression)
      - [3.8 Tap a formula repository](#38-tap-a-formula-repository)
      - [3.9 Show detailed information about one or more taps](#39-show-detailed-information-about-one-or-more-taps)
      - [4.0 Uninstall a formula or cask](#40-uninstall-a-formula-or-cask)
      - [4.1 Remove symlinks for formula from Homebrew's prefix](#41-remove-symlinks-for-formula-from-homebrews-prefix)
      - [4.2 Fetch the newest version of Homebrew and all formulae from GitHub using git(1) and perform any necessary migrations](#42-fetch-the-newest-version-of-homebrew-and-all-formulae-from-github-using-git1-and-perform-any-necessary-migrations)
      - [4.3 Upgrade outdated casks and outdated, unpinned formulae using the same options they were originally installed with, plus any appended brew formula options](#43-upgrade-outdated-casks-and-outdated-unpinned-formulae-using-the-same-options-they-were-originally-installed-with-plus-any-appended-brew-formula-options)
      - [4.4 Show  formulae  and  casks  that  specify formula as a dependency; that is, show dependents of formula](#44-show--formulae--and--casks--that--specify-formula-as-a-dependency-that-is-show-dependents-of-formula)
      - [4.5 Display Homebrew's download cache. See also HOMEBREW_CACHE](#45-display-homebrews-download-cache-see-also-homebrew_cache)
      - [4.6 Official external commands](#46-official-external-commands)

### 1.0 Homebrew Core aliases

#### 1.1 Homebrew Access aliases

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| br    | `brew`                                   | The Missing Package Manager for macOS (or Linux).  |

#### 1.2 Control Homebrew anonymous aggregate user behaviour analytics

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
| brconf| `brew config`                       | Show Homebrew and system configuration info useful for debugging. |

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

#### 1.9 Display formula's name and one-line description. Formula descriptions are cached; the cache is created on the first search, making that search slower than subsequent ones

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brds | `brew desc -s` | Search both names and descriptions for text. If text is flanked by slashes, it is interpreted as a regular expression. |
| brdn | `brew desc -n` | Search just names for text. If text is flanked by slashes, it is interpreted as a regular expression. |
| brdd | `brew desc -d` | Search just descriptions for text. If text is flanked by slashes, it is interpreted as a regular expression. |

#### 2.0 Control Homebrew's developer mode

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brdev | `brew developer` | Display the current state of Homebrew's developer mode. |
| brdevoff | `brew developer off` | Turn Homebrew's developer mode off. |
| brdevon | `brew developer on` | Turn Homebrew's developer mode on. |

#### 2.1 Check  your  system for potential problems

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brdoc | `brew doctor` | Check  your  system for potential problems. |
| brdocls | `brew doctor --list-checks` | List all audit methods, which can be run individually if provided as arguments. |
| brdocdbg | `brew doctor --audit-debug` | Enable debugging and profiling of audit methods. |

#### 2.2 Download a bottle (if available) or source packages for formulae and binaries for casks

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brfetch | `brew fetch "$1"` | Download a bottle (if available) or source packages for formulae and binaries for casks. For files, also print SHA-256 checksums. |
| brfetchb | `brew fetch --build-from-source "$1"` | Download source packages rather than a bottle. |
| brfetchbb | `brew fetch --build-bottle "$1"` | Download source packages (for eventual bottling) rather than a bottle. |
| brfetchd | `brew fetch --deps "$1"` | Also download dependencies for any listed formula. |
| brfetchf | `brew fetch --force "$1"` | Remove a previously cached version and re-fetch. |
| brfetchfb | `brew fetch --force-bottle "$1"` | Download a bottle if it exists for the current or newest version of macOS, even if it would not be used during installation. |
| brfetchhead | `brew fetch --HEAD "$1"` | Fetch HEAD version instead of stable version. |
| brfetchr | `brew fetch --retry "$1"` | Retry if downloading fails or re-download if the checksum of a previously cached version no longer matches. |
| brfetchtag | `brew fetch --bottle-tag "$1"` | Download a bottle for given tag. |
| brfetchv | `brew fetch --verbose "$1"` | Do a verbose VCS checkout, if the URL represents a VCS. This is useful for seeing if an existing VCS cache has been updated. |

#### 2.3 Display brief statistics for your Homebrew installation

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| bri     | `brew info --formula "$1"` | Treat all named arguments as formulae. |
| bria    | `brew info --analytics "$1"` | List global Homebrew analytics data or, if specified, installation and build error data for formula (provided neither HOMEBREW_NO_ANALYTICS nor HOMEBREW_NO_GITHUB_API). |
| briall  | `brew info --all "$1"` | Print JSON of all available formulae. |
| bric    | `brew info --category "$1"` | Which type of analytics data to retrieve. The value for category must be install, install-on-request or build-error; cask-install or os-version may be specified if a | is not. The default is install. |
| bricask | `brew info --cask "$1"` | Treat all named arguments as casks. |
| brid    | `brew info --days "$1"` | How many days of analytics data to retrieve. The value for days must be 30, 90 or 365. The default is 30. |
| brig    | `brew info --github "$1"` | Open the GitHub source page for formula in a browser. To view formula history locally: brew log -p formula. |
| brii    | `brew info --installed "$1"` | Print JSON of formulae that are currently installed. |
| brij    | `brew info --json "$1"` | Print a JSON representation. Currently the default value for version is v1 for formula. |

#### 2.4 Install a formula or cask. Additional options specific to a formula may be appended to the command

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brin    | `brew install "$1"` | Install a formula or cask.
| brinba  | `brew install --bottle-arch "$1"` | Optimise bottles for the specified architecture rather than the oldest architecture supported by the version of macOS the bottles are built on. |
| brinbb  | `brew install --build-bottle "$1"` | Prepare the formula for eventual bottling during installation, skipping any post-install steps. |
| brinbin | `brew install --binaries "$1"` | Enable linking of helper executables (default: enabled). |
| brinbs  | `brew install --build-from-source "$1"` | Compile formula from source even if a bottle is provided. Dependencies will still be installed from bottles if they are available. |
| brincc  | `brew install --cc "$1"` | Attempt to compile using the specified compiler, which should be the name of the compiler's executable. |
| brinck  | `brew install --cask "$1"` | Treat all named arguments as casks. |
| brindp  | `brew install --only-dependencies "$1"` | Install the dependencies with specified options but do not install the formula itself. |
| brindt  | `brew install --display-times "$1"` | Print install times for each formula at the end of the run. |
| brinfb  | `brew install --force-bottle "$1"` | Install from a bottle if it exists for the current or newest version of macOS, even if it would not normally be used for installation. |
| brinfh  | `brew install --fetch-HEAD "$1"` | Fetch the upstream repository to detect if the HEAD installation of the formula is outdated. Otherwise, the repository's HEAD will only be checked for updates when a new stable or development version has been released. |
| brinform | `brew install --formula "$1"` | Treat all named arguments as formulae. |
| bring    | `brew install --git "$1"` | Create a Git repository, useful for creating patches to the software. |
| brinh    | `brew install --HEAD "$1"` | If formula defines it, install the HEAD version, aka. main, trunk, unstable, master. |
| brinit   | `brew install --include-test "$1"` | Install testing dependencies required to run brew test formula. |
| brinkt   | `brew install --keep-tmp "$1"` | Retain the temporary files created during installation. |
| brinnodp | `brew install --ignore-dependencies "$1"` | An unsupported Homebrew development flag to skip installing any dependencies of any kind. If the dependencies are not already present, the formula will have issues. If you're not developing Homebrew, consider adjusting your PATH rather than using this flag. |
| brinobin | `brew install --no-binaries "$1"` | Disable linking of helper executables (default: enabled). |
| brinoq   | `brew install --no-quarantine "$1"` | Disable quarantining of downloads (default: enabled). |
| brinq    | `brew install --quarantine "$1"` | Enable quarantining of downloads (default: enabled). |
| brinsha  | `brew install --require-sha "$1"` | Require all casks to have a checksum. |
| brinskip | `brew install --skip-cask-deps "$1"` | Skip installing cask dependencies. |

#### 2.5 List installed formulae that are not dependencies of another installed formula

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brl | `brew leaves` | List installed formulae that are not dependencies of another installed formula. |
| brlir | `brew leaves --installed-on-request` | Only list leaves that were manually installed. |
| brlid | `brew leaves --installed-as-dependency` | Only list leaves that were installed as dependencies. |

#### 2.6 Symlink all of formula's installed files into Homebrew's prefix. This is done automatically when you install formulae but can be useful for DIY installations

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brlk | `brew link` | Symlink all of formula's installed files into Homebrew's prefix. |
| brlkdr | `brew link --dry-run` | List files which would be linked or deleted by brew link --overwrite without actually linking or deleting any files. |
| brlkf | `brew link --force` | Allow keg-only formulae to be linked. |
| brlkh | `brew link --HEAD` | Link the HEAD version of the formula if it is installed. |
| brlko | `brew link --overwrite` | Delete files that already exist in the prefix while linking. |

#### 2.7 List all installed formulae and casks

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brls | `brew list` | List all installed formulae and casks. |
| brls1 | `brew list -1` | Force output to be one entry per line. This is the default when output is not to a terminal. |
| brlsc | `brew list --cask` | List only casks, or treat all named arguments as casks. |
| brlsf | `brew list --formula` | List only formulae, or treat all named arguments as formulae. |
| brlsfn | `brew list --full-name` | Print formulae with fully-qualified names. Unless --full-name, --versions or --pinned are passed, other options (i.e. -1, -l, -r and -t) are passed to ls(1) which produces the actual output. |
| brlsl | `brew list -l` | List formulae and/or casks in long format. Has no effect when a formula or cask name is passed as an argument. |
| brlsm | `brew list --multiple` | Only show formulae with multiple versions installed. |
| brlsp | `brew list --pinned` | List only pinned formulae, or only the specified (pinned) formulae if formula are provided. See also pin, unpin. |
| brlsr | `brew list -r` | Reverse the order of the formulae and/or casks sort to list the oldest entries first. Has no effect when a formula or cask name is passed as an argument. |
| brlst | `brew list -t` | Sort formulae and/or casks by time modified, listing most recently modified first. Has no effect when a formula or cask name is passed as an argument. |
| brlsv | `brew list --versions` | Show the version number for installed formulae, or only the specified formulae if formula are provided. |

#### 2.8 Show the git log for formula, or show the log for the Homebrew repository if no formula is provided

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brlg | `brew log` | Show the git log for formula, or show the log for the Homebrew repository if no formula is provided. |
| brlg1c | `brew log -1` | Print only one commit. |
| brlg1l | `brew log --oneline` | Print only one line per commit. |
| brlgn | `brew log --max-count` | Print only a specified number of commits. |
| brlgp | `brew log -p` | Also print patch from commit. |
| brlgs | `brew log --stat` | Also print diffstat from commit. |

#### 2.9 Migrate renamed packages to new names, where formula are old names of packages

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brmig | `brew migrate` | Migrate renamed packages to new names, where formula are old names of packages. |
| brmigf | `brew migrate --force` | Treat installed formula and provided formula as if they are from the same taps and migrate them anyway. |

#### 3.0 Check the given formula kegs for missing dependencies

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brmiss | `brew missing` | Check the given formula kegs for missing dependencies. |
| brmissh | `brew missing --hide` | Act as if none of the specified hidden are installed. hidden should be a comma-separated list of formulae. |

#### 3.1 Show install options specific to formula

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| bro | `brew options` | Show install options specific to formula. |
| broa | `brew options -all` | Show options for all available formulae. |
| broc | `brew options --compact` | Show all options on a single line separated by spaces. |
| brocmd | `brew options --command` | Show options for the specified command. |
| broi | `brew options --installed` | Show options for formulae that are currently installed. |

#### 3.2 List installed casks and formulae that have an updated version available

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brod | `brew outdated` | List installed casks and formulae that have an updated version available. By default, version information is displayed in interactive shells, and suppressed otherwise. |
| brodc | `brew outdated --cask` | List only outdated casks. |
| brodf | `brew outdated --formula` | List only outdated formulae. |
| brodfh | `brew outdated --fetch-HEAD` | Fetch the upstream repository to detect if the HEAD installation of the formula is outdated. Otherwise, the repository's HEAD will only be checked for updates when a new stable or development version has been released. |
| brodg | `brew outdated --greedy` | Print outdated casks with auto_updates true or version :latest. |
| brodgau | `brew outdated --greedy-auto-updates` | Print outdated casks including those with auto_updates true. |
| brodgl | `brew outdated --greedy-latest` | Print outdated casks including those with version :latest. |
| brodj | `brew outdated --json` | Print output in JSON format. There are two versions: v1 and v2. v1 is deprecated and is currently the default if no version is specified. v2 prints outdated formulae and casks. |
| brodq | `brew outdated --quiet` | List only the names of outdated kegs (takes precedence over --verbose). |
| brodv | `brew outdated --verbose` | Include detailed version information. |

#### 3.3 Pin the specified formula, preventing them from being upgraded when issuing the brew upgrade formula command

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brpin | `brew pin "$1"` | Pin the specified formula, preventing them from being upgraded when issuing the brew upgrade formula command. |
| brupin | `brew unpin "$1"` | Unpin formula, allowing them to be upgraded by brew upgrade formula. |

#### 3.4 Rerun the post-install steps for formula

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brposti | `brew postinstall "$1"` | Rerun the post-install steps for formula. |

#### 3.5 Import all items from the specified tap, or from all installed taps if none is provided

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| bread | `brew readall` | Import all items from the specified tap, or from all installed taps if none is provided. This can be useful for debugging issues across all items when making significant changes to formula.rb, testing the performance of loading all items or checking if any current formulae/casks have Ruby issues. |
| breada |temsew readall --aliases` | Verify any | symlinks in each tap. |
| breads | `brew readall --syntax` | Syntax-check all of Homebrew's Ruby files (if no <tap> is passed). |

#### 3.6  Uninstall and then reinstall a formula or cask using the same options it was originally installed with, plus any appended options specific to a formula

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brr | `brew reinstall "$1"` | Uninstall and then reinstall a formula or cask using the same options it was originally installed with, plus any appended options specific to a formula. |
| brrb | `brew reinstall "$1" --binaries` | Enable linking of helper executables (default: enabled). |
| brrc | `brew reinstall "$1" --cask` | Treat all named arguments as casks. |
| brrd | `brew reinstall "$1" --debug` | If brewing fails, open an interactive debugging session with access to IRB or a shell inside the temporary build directory. |
| brrdt | `brew reinstall "$1" --display-times` | Print install times for each formula at the end of the run. |
| brrf | `brew reinstall "$1" --force` | Install without checking for previously installed keg-only or non-migrated versions. |
| brrfb | `brew reinstall "$1" --force-bottle` | Install from a bottle if it exists for the current or newest version of macOS, even if it would not normally be used for installation. |
| brrfm | `brew reinstall "$1" --formula` | Treat all named arguments as formulae. |
| brrfs | `brew reinstall "$1" --build-from-source` | Compile formula from source even if a bottle is available. |
| brri | `brew reinstall "$1" --interactive` | Download and patch formula, then open a shell. This allows the user to run ./configure --help and otherwise determine how to turn the software package into a Homebrew package. |
| brrkt | `brew reinstall "$1" --keep-tmp` | Retain the temporary files created during installation. |
| brrnb | `brew reinstall "$1" --no-binaries` | Disable linking of helper executables (default: enabled). |
| brrnq | `brew reinstall "$1" --no-quarantine` | Disable quarantining of downloads (default: enabled). |
| brrq | `brew reinstall "$1" --quarantine` | Enable quarantining of downloads (default: enabled). |
| brrr | `brew reinstall "$1" --git` | Create a Git repository, useful for creating patches to the software. |
| brrrs | `brew reinstall "$1" --require-sha` | Require all casks to have a checksum. |
| brrscd | `brew reinstall "$1" --skip-cask-deps` | Skip installing cask dependencies. |
| brrv | `brew reinstall "$1" --verbose` | Print the verification and postinstall steps. |

#### 3.7 Perform a substring search of cask tokens and formula names for text. If text is flanked by slashes, it is interpreted as a regular expression

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brs | `brew search "$1"` | Perform a substring search of cask tokens and formula names for text. If text is flanked by slashes, it is interpreted as a regular expression. |
| brsc | `brew search "$1" --cask` | Search online and locally for casks. |
| brsd | `brew search "$1" --desc` | Search for formulae with a description matching text and casks with a name matching text. |
| brsdb | `brew search "$1" --debian` | Search for text in the given database. |
| brsf | `brew search "$1" --formula` | Search online and locally for formulae. |
| brsfed | `brew search "$1" --fedora` | Search for text in the given database. |
| brsfk | `brew search "$1" --fink` | Search for text in the given database. |
| brsmp | `brew search "$1" --macports` | Search for text in the given database. |
| brso | `brew search "$1" --open` | Search for only open GitHub pull requests. |
| brsos | `brew search "$1" --opensuse` | Search for text in the given database. |
| brspr | `brew search "$1" --pull-request` | Search for GitHub pull requests containing text. |
| brsr | `brew search "$1" --repology` | Search for text in the given database. |
| brsub | `brew search "$1" --ubuntu` | Search for text in the given database. |
| brsx | `brew search "$1" --closed` | Search for only closed GitHub pull requests. |

#### 3.8 Tap a formula repository

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brtap | `brew tap "$1"` | Tap a formula repository. |
| brutap | `brew untap "$1"` | Remove a tapped formula repository. |
| brtapf | `brew tap "$1" --full` | Convert a shallow clone to a full clone without untapping. Taps are only cloned as shallow clones if --shallow was originally passed. |
| brtapfau | `brew tap "$1" --force-auto-update` | Auto-update tap even if it is not hosted on GitHub. By default, only taps hosted on GitHub are auto-updated (for performance reasons). |
| brtaplp | `brew tap "$1" --list-pinned` | List all pinned taps. |
| brtapr | `brew tap "$1" --repair` | Migrate tapped formulae from symlink-based to directory-based structure. |
| brtaps | `brew tap "$1" --shallow` | Fetch tap as a shallow clone rather than a full clone. Useful for continuous integration. |

#### 3.9 Show detailed information about one or more taps

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brtapi | `brew tap-info "$1"` | Show detailed information about one or more taps. |
| brtapii | `brew tap-info "$1" --installed` | Show information on each installed tap. |
| brtapij | `brew tap-info "$1" --json` | Print a JSON representation of tap. Currently the default and only accepted value for version is v1. |

#### 4.0 Uninstall a formula or cask

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brtapi | `brew tap-info "$1"` | Uninstall a formula or cask. |
| brtapic | `brew tap-info "$1" --cask` | Treat all named arguments as casks. |
| brtapif | `brew tap-info "$1" --force` | Delete all installed versions of formula. Uninstall even if cask is not installed, overwrite existing files and ignore errors when removing files. |
| brtapif | `brew tap-info "$1" --formula` | Treat all named arguments as formulae. |
| brtapiid | `brew tap-info "$1" --ignore-dependencies` | Don't fail uninstall, even if formula is a dependency of any installed formulae. |
| brtapiz | `brew tap-info "$1" --zap` | Remove all files associated with a cask. May remove files which are shared between applications. |

#### 4.1 Remove symlinks for formula from Homebrew's prefix

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brulk | `brew unlink "$1"` | Remove symlinks for formula from Homebrew's prefix. |
| brulkdr | `brew unlink "$1" --dry-run` | List files which would be unlinked without actually unlinking or deleting any files. |

#### 4.2 Fetch the newest version of Homebrew and all formulae from GitHub using git(1) and perform any necessary migrations

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| bru | `brew update "$1"` | Fetch the newest version of Homebrew and all formulae from GitHub using git(1) and perform any necessary migrations. |
| brum | `brew update "$1" --merge` | Use git merge to apply updates (rather than git rebase). |
| brup | `brew update "$1" --preinstall` | Run on auto-updates (e.g. before brew install). Skips some slower steps. |
| bruf | `brew update "$1" --force` | Always do a slower, full update check (even if unnecessary). |

#### 4.3 Upgrade outdated casks and outdated, unpinned formulae using the same options they were originally installed with, plus any appended brew formula options

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brug | `brew upgrade "$1"` | Upgrade outdated casks and outdated, unpinned formulae using the same options they were originally installed with, plus any appended brew formula options. If cask or formula are specified, upgrade only the given cask or formula kegs (unless they are pinned; see pin, unpin). |
| brugb | `brew upgrade "$1" --binaries` | Enable linking of helper executables (default: enabled). |
| brugbfs | `brew upgrade "$1" --build-from-source` | Compile formula from source even if a bottle is available. |
| brugc | `brew upgrade "$1" --cask` | Treat all named arguments as casks. If no named arguments are specified, upgrade only outdated casks. |
| brugd | `brew upgrade "$1" --debug` | If brewing fails, open an interactive debugging session with access to IRB or a shell inside the temporary build directory. |
| brugdr | `brew upgrade "$1" --dry-run` | Show what would be upgraded, but do not actually upgrade anything. |
| brugdt | `brew upgrade "$1" --display-times` | Print install times for each formula at the end of the run. |
| brugf | `brew upgrade "$1" --force` | Install formulae without checking for previously installed keg-only or non-migrated versions. When installing casks, overwrite existing files (binaries and symlinks are excluded, unless originally from the same cask). |
| brugf | `brew upgrade "$1" --formula` | Treat all named arguments as formulae. If no named arguments are specified, upgrade only outdated formulae. |
| brugfb | `brew upgrade "$1" --force-bottle` | Install from a bottle if it exists for the current or newest version of macOS, even if it would not normally be used for installation. |
| brugfh | `brew upgrade "$1" --fetch-HEAD` | Fetch the upstream repository to detect if the HEAD installation of the formula is outdated. Otherwise, the repository's HEAD will only be checked for updates when a new stable or development version has been released. |
| brugg | `brew upgrade "$1" --greedy` | Also include casks with auto_updates true or version :latest. |
| bruggau | `brew upgrade "$1" --greedy-auto-updates` | Also include casks with auto_updates true. |
| bruggl | `brew upgrade "$1" --greedy-latest` | Also include casks with version :latest. |
| brugi | `brew upgrade "$1" --interactive` | Download and patch formula, then open a shell. This allows the user to run ./configure --help and otherwise determine how to turn the software package into a Homebrew package. |
| brugip | `brew upgrade "$1" --ignore-pinned` | Set a successful exit status even if pinned formulae are not upgraded. |
| brugkt | `brew upgrade "$1" --keep-tmp` | Retain the temporary files created during installation. |
| brugnb | `brew upgrade "$1" --no-binaries` | Disable linking of helper executables (default: enabled). |
| brugnq | `brew upgrade "$1" --no-quarantine` | Disable quarantining of downloads (default: enabled). |
| brugq | `brew upgrade "$1" --quarantine` | # Enable quarantining of downloads (default: enabled). |
| brugrs | `brew upgrade "$1" --require-sha` | Require all casks to have a checksum. |
| brugscd | `brew upgrade "$1" --skip-cask-deps` | Skip installing cask dependencies. |
| brugv | `brew upgrade "$1" --verbose` | Print the verification and postinstall steps. |

#### 4.4 Show  formulae  and  casks  that  specify formula as a dependency; that is, show dependents of formula

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brus | `brew uses "$1"` | Show  formulae  and  casks  that  specify formula as a dependency; that is, show dependents of formula. When given multiple formula arguments, show the intersection of formulae that use formula. By default, uses shows all formulae and casks that specify formula as a required or recommended dependency for their stable builds. |
| brusc | `brew uses "$1" --cask` | Include only casks. |
| brusf | `brew uses "$1" --formula` | Include only formulae. |
| brusi | `brew uses "$1" --installed` | Only list formulae and casks that are currently installed. |
| brusib | `brew uses "$1" --include-build` | Include all formulae that specify formula as :build type dependency. |
| brusio | `brew uses "$1" --include-optional` | Include all formulae that specify formula as :optional type dependency. |
| brusit | `brew uses "$1" --include-test` | Include all formulae that specify formula as :test type dependency. |
| brusr | `brew uses "$1" --recursive` | Resolve more than one level of dependencies. |
| brussr | `brew uses "$1" --skip-recommended` | Skip all formulae that specify formula as :recommended type dependency. |

#### 4.5 Display Homebrew's download cache. See also HOMEBREW_CACHE

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| brcache | `brew cache "$1"` | Display Homebrew's download cache. See also HOMEBREW_CACHE. |
| brcacheb | `brew cache "$1" --force-bottle` | Show the cache file used when pouring a bottle. |
| brcachec | `brew cache "$1" --cask` | Only show cache files for casks. |
| brcachef | `brew cache "$1" --formula` | Only show cache files for formulae. |
| brcacheh | `brew cache "$1" --HEAD` | Show the cache file used when building from HEAD. |
| brcaches | `brew cache "$1" --build-from-source` | Show the cache file used when building from source. |

#### 4.6 Official external commands

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| bral | `brew alias "$1"` | Show existing aliases. if no aliases are given, print the whole list. |
| braus | `brew autoupdate start "$1"` | Start  autoupdating  either once every interval hours or once every 24 hours. please note the interval has to be passed in seconds, so 12 hours would be brew autoupdate start 43200. pass --upgrade or --cleanup to automatically run brew upgrade and/or brew cleanup respectively. pass --enable-notification to send a notification when the autoupdate process has finished successfully. |
| braux | `brew autoupdate stop` | Stop autoupdating, but retain plist & logs. |
| braud | `brew autoupdate delete` | Cancel the autoupdate, delete the plist and logs. |
| braust | `brew autoupdate status` | Prints the current status of this tool. |
| brauv | `brew autoupdate version` | Output this tool's current version, and a short changelog. |
| brausup | `brew autoupdate start "$1" --upgrade` | Automatically upgrade your installed formulae. if the caskroom exists locally casks will be upgraded as well. must be passed with start. |
| brautcl | `brew autoupdate start "$1" --cleanup` | Automatically clean brew's cache and logs. must be passed with start. |
| brauten | `brew autoupdate start "$1" --enable-notification` | Send a notification when the autoupdate process has finished successfully, if terminal-notifier is installed & found. note that currently a new experimental notifier runs automatically on macos catalina and newer, without requiring any external dependencies. must be passed with start. |
| brautim | `brew autoupdate start "$1" --immediate` | Starts the autoupdate command immediately, instead of waiting for one interval (24 hours by default) to pass first. must be passed with start. |
| brbdl | `brew bundle "$1"` | Install and upgrade (by default) all dependencies from the brewfile. |
| brbdld | `brew bundle dump` |  Write all installed casks/formulae/images/taps into a brewfile in the current directory. |
| brbdlcl | `brew bundle cleanup` | Uninstall all dependencies not listed from the brewfile. |
| brbdlch | `brew bundle check` | Check if all dependencies are installed from the brewfile. |
| brbdlls | `brew bundle list` | List all dependencies present in the brewfile. by default, only homebrew dependencies are listed. |
| brbdle | `brew bundle exec` | Run an external command in an isolated build environment based on the brewfile dependencies. |
| brbdlef | `brew bundle exec --file` | Read the brewfile from this location. use --file=- to pipe to stdin/stdout. |
| brbdleg | `brew bundle exec --global` | Read the brewfile from ~/.brewfile. |
| brbdlev | `brew bundle exec --verbose` | Install prints output from commands as they are run. check lists all missing dependencies. |
| brbdlenu | `brew bundle exec --no-upgrade` | Install won't run brew upgrade on outdated dependencies. note they may still be upgraded by brew install if needed. |
| brbdlef | `brew bundle exec --force` | Dump overwrites an existing brewfile. cleanup actually performs its cleanup operations. |
| brbdlcl | `brew bundle exec --cleanup` | Install performs cleanup operation, same as running cleanup --force. |
| brbdleno | `brew bundle exec --no-lock` | Install won't output a brewfile.lock.json. |
| brbdleal | `brew bundle exec --all` | List all dependencies. |
