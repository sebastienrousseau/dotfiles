# cd Aliases

Manage directory navigation aliases and functions. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `cd-bookmarks.aliases.sh`, `cd-completion.aliases.sh`, `cd-config.aliases.sh`, `cd-core.aliases.sh`, `cd-help.aliases.sh`, `cd-history.aliases.sh`, `cd-init.aliases.sh`, `cd-navigation.aliases.sh`, `cd-shortcuts.aliases.sh`, `cd-stack.aliases.sh`, `cd-utils.aliases.sh` and `cd.aliases.sh`. Loaded by the eager alias layer `~/.config/shell/90-ux-aliases.sh` (a core category).

`cd.aliases.sh` repeats the functions and shortcuts of the split `cd-*.aliases.sh` files. It loads after them (the files load in name order, and `cd-` sorts before `cd.`), so where both define a name its copy is the one in effect. `cd-config.aliases.sh` sets the directory variables (`APP_DIR=~/Applications`, `CODE_DIR=~/Code`, `DESK_DIR=~/Desktop`, `DOCS_DIR=~/Documents`, `DOTF_DIR=~/.dotfiles`, `DOWN_DIR=~/Downloads`, `MUSIC_DIR=~/Music`, `PICS_DIR=~/Pictures`, `VIDS_DIR=~/Videos`, `HOME_DIR=~`) and defines no aliases.

`cd` itself is replaced by `cd_with_history` only when `DOTFILES_ENABLE_CD_ALIAS=1`; otherwise the enhanced `cd` is available as `cdh`. The `up` calls in `cd-shortcuts.aliases.sh` use the `up` script in `~/.local/bin`.

There are two bookmark stores. The `bm*` aliases call the `bm` script in `~/.local/bin`, which keeps bookmarks in `~/.config/shell/bookmarks`. The `bookmark*` and `goto` functions keep theirs in `~/.dir_bookmarks`.

## Aliases

### `cd-bookmarks.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `bookmark_list` | function |  |
| `bookmark` | function |  |
| `bookmark_update` | function |  |
| `bookmark_remove` | function |  |
| `goto` | function | In zsh, the function layer later replaces `goto` with the directory helper from `functions/nav/goto.sh`. |

### `cd-config.aliases.sh`

Sets the variables listed above; defines no aliases or functions.

### `cd-core.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `cd_with_history` | function | Enhanced cd function with directory history tracking. |
| `mkcd` | function | Create directory and navigate to it. |

### `cd-help.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `cdhelp` | `cd_aliases_help` |  |
| `cdversion` | `cd_aliases_version` |  |

### `cd-history.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `dirhistory` | function |  |

### `cd-init.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `cd` | `cd_with_history` | Override default cd command. Only when `DOTFILES_ENABLE_CD_ALIAS=1`. |
| `cdh` | `cd_with_history` | Explicit enhanced cd helper. Only when not `DOTFILES_ENABLE_CD_ALIAS=1`. |
| `mcd` | function |  |
| `bm` | `bm add` | Create bookmark. |
| `bmu` | `bm update` | Update bookmark. |
| `bmr` | `bm remove` | Remove bookmark. |
| `bml` | `bm list` | List bookmarks. |
| `bmg` | function |  |
| `dh` | `dirhistory` | Show directory history. |
| `pr` | `proj` | Navigate to project root. |
| `ld` | `lwd` | Return to last directory. |

### `cd-navigation.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `proj` | function | Find and navigate to project root (git, npm, etc.) |
| `lwd` | function | Restore last working directory. |

### `cd-shortcuts.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `-` | `cd -` | Go to the previous directory. |
| `..` | `up 1` | Go up one level. Replaced by the `cd.aliases.sh` definition, which loads later. |
| `...` | `up 2` | Go up two levels. Replaced by the `cd.aliases.sh` definition, which loads later. |
| `....` | `up 3` | Go up three levels. Replaced by the `cd.aliases.sh` definition, which loads later. |
| `.....` | `up 4` | Go up four levels. Replaced by the `cd.aliases.sh` definition, which loads later. |
| `......` | `up 5` | Go up five levels. |
| `app` | `cd_with_history "${APP_DIR}"` | Applications. Only when directory `${APP_DIR}` exists. |
| `cod` | `cd_with_history "${CODE_DIR}"` | Code. Only when directory `${CODE_DIR}` exists. Replaced by `cod='codex'` from `ai.aliases.sh` (lazy layer) when `codex` is on PATH. |
| `dsk` | `cd_with_history "${DESK_DIR}"` | Desktop. Only when directory `${DESK_DIR}` exists. |
| `doc` | `cd_with_history "${DOCS_DIR}"` | Documents. Only when directory `${DOCS_DIR}` exists. |
| `dotf` | `cd_with_history "${DOTF_DIR}"` | Dotfiles. Only when directory `${DOTF_DIR}` exists. |
| `dwn` | `cd_with_history "${DOWN_DIR}"` | Downloads. Only when directory `${DOWN_DIR}` exists. |
| `hom` | `cd_with_history "${HOME_DIR}"` | Home Directory. Only when directory `${DOWN_DIR}` exists. The test checks `${DOWN_DIR}`, not `${HOME_DIR}`. |
| `mus` | `cd_with_history "${MUSIC_DIR}"` | Music. Only when directory `${MUSIC_DIR}` exists. |
| `pic` | `cd_with_history "${PICS_DIR}"` | Pictures. Only when directory `${PICS_DIR}` exists. |
| `vid` | `cd_with_history "${VIDS_DIR}"` | Videos. Only when directory `${VIDS_DIR}` exists. |
| `etc` | `cd_with_history /etc` | System configuration. Only when directory `/etc` exists. |
| `var` | `cd_with_history /var` | Variable data. Only when directory `/var` exists. |
| `tmp` | `cd_with_history /tmp` | Temporary files. Only when directory `/tmp` exists. |
| `usr` | `cd_with_history /usr` | User programs. Only when directory `/usr` exists. |

### `cd-stack.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `dirs` | `dirs -v` | List directory stack with indices. |
| `pd` | `pushd` | Push directory to stack. |
| `popd` | `popd && ls -lh` | Pop directory from stack and list contents. |

### `cd-utils.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `safe_write_file` | function | Safely create or modify files. |
| `count_dir_items` | function | Count items in directory (for performance optimization) |

### `cd.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `safe_write_file` | function | Safely create or modify files. |
| `count_dir_items` | function | Count items in directory (for performance optimization) |
| `cd_with_history` | function | Enhanced cd function with directory history tracking. |
| `mkcd` | function | Create directory and navigate to it. |
| `bookmark_list` | function |  |
| `bookmark` | function |  |
| `bookmark_update` | function |  |
| `bookmark_remove` | function |  |
| `goto` | function | In zsh, the function layer later replaces `goto` with the directory helper from `functions/nav/goto.sh`. |
| `dirhistory` | function |  |
| `proj` | function | Find and navigate to project root (git, npm, etc.) |
| `lwd` | function | Restore last working directory. |
| `-` | `cd -` | Go to the previous directory. |
| `..` | `cd_with_history ..` | Go up one level. |
| `...` | `cd_with_history ../..` | Go up two levels. |
| `....` | `cd_with_history ../../..` | Go up three levels. |
| `.....` | `cd_with_history ../../../..` | Go up four levels. |
| `app` | `cd_with_history "${APP_DIR}"` | Applications. Only when directory `${APP_DIR}` exists. |
| `cod` | `cd_with_history "${CODE_DIR}"` | Code. Only when directory `${CODE_DIR}` exists. Replaced by `cod='codex'` from `ai.aliases.sh` (lazy layer) when `codex` is on PATH. |
| `dsk` | `cd_with_history "${DESK_DIR}"` | Desktop. Only when directory `${DESK_DIR}` exists. |
| `doc` | `cd_with_history "${DOCS_DIR}"` | Documents. Only when directory `${DOCS_DIR}` exists. |
| `dotd` | `cd_with_history "${DOTF_DIR}"` | Dotfiles dir. Only when directory `${DOTF_DIR}` exists. |
| `dwn` | `cd_with_history "${DOWN_DIR}"` | Downloads. Only when directory `${DOWN_DIR}` exists. |
| `hom` | `cd_with_history "${HOME_DIR}"` | Home Directory. Only when directory `${DOWN_DIR}` exists. The test checks `${DOWN_DIR}`, not `${HOME_DIR}`. |
| `mus` | `cd_with_history "${MUSIC_DIR}"` | Music. Only when directory `${MUSIC_DIR}` exists. |
| `pic` | `cd_with_history "${PICS_DIR}"` | Pictures. Only when directory `${PICS_DIR}` exists. |
| `vid` | `cd_with_history "${VIDS_DIR}"` | Videos. Only when directory `${VIDS_DIR}` exists. |
| `etc` | `cd_with_history /etc` | System configuration. Only when directory `/etc` exists. |
| `var` | `cd_with_history /var` | Variable data. Only when directory `/var` exists. |
| `tmp` | `cd_with_history /tmp` | Temporary files. Only when directory `/tmp` exists. |
| `usr` | `cd_with_history /usr` | User programs. Only when directory `/usr` exists. |

### Settings

The files give these variables a default when they load and keep any value already set:

| Variable | Default | Effect |
| --- | --- | --- |
| `SHOW_HIDDEN_FILES` | `false` | Include hidden files in the listing after `cd` |
| `ENABLE_COLOR_OUTPUT` | `true` | Colour that listing |
| `ENABLE_DIR_GROUPING` | `true` | Group directories first (Linux `ls`) |
| `AUTO_LIST_AFTER_CD` | `true` | List the directory after `cd_with_history` |
| `LARGE_DIR_THRESHOLD` | `1000` | Skip that listing above this many entries |
| `MAX_RECENT_DIRS` | `10` | Entries kept for `dirhistory` |
| `RESTORE_LAST_DIR` | `false` | Return to the last directory (`lwd`) when a shell starts |

The last directory is kept in `~/.last_working_dir`. Run `cdhelp` for the built-in help.

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
