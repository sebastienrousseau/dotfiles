# Dotfiles aliases

![Banner representing the Dotfiles Library](/media/dotfiles.svg)

This zsh folder contains helpful shortcut aliases, configurations and plugins for many commonly used commands.

## Table of Contents

- [Dotfiles aliases](#dotfiles-aliases)
  - [Table of Contents](#table-of-contents)
    - [1. .zhrc](#1-zhrc)
    - [2. aliases.zsh](#2-aliaseszsh)
      - [2.1 Sourcing alias plugins.](#21-sourcing-alias-plugins)
        - [2.1.1 Main Aliases location](#211-main-aliases-location)
        - [2.1.2 gCloud Aliases location](#212-gcloud-aliases-location)
        - [2.1.3 Git Aliases location](#213-git-aliases-location)
        - [2.1.4 Heroku Aliases location](#214-heroku-aliases-location)
        - [2.1.5 Homebrew Aliases location](#215-homebrew-aliases-location)
        - [2.1.6 Jekyll Aliases location](#216-jekyll-aliases-location)
        - [2.1.7 Subversions Aliases location](#217-subversions-aliases-location)
    - [3. configurations.zsh](#3-configurationszsh)
      - [3.1 Sourcing configurations plugins.](#31-sourcing-configurations-plugins)
        - [3.1.1 Load custom configurations](#311-load-custom-configurations)
    - [4. exit.zsh](#4-exitzsh)
      - [4.1 Sourcing exit plugins.](#41-sourcing-exit-plugins)
        - [4.1.1 Executed by Ze Shell when login shell exits](#411-executed-by-ze-shell-when-login-shell-exits)
    - [5. functions.zsh](#5-functionszsh)
      - [5.1 Sourcing functions plugins.](#51-sourcing-functions-plugins)
        - [5.1.1 Load custom executable functions](#511-load-custom-executable-functions)
    - [6. history.zsh](#6-historyzsh)
      - [6.1 Sourcing history plugins.](#61-sourcing-history-plugins)
        - [6.1.1 History wrapper](#611-history-wrapper)
        - [6.1.2 Timestamp format](#612-timestamp-format)
        - [6.1.3 Command history configuration](#613-command-history-configuration)
        - [6.1.4 Number of histories saved in a memory](#614-number-of-histories-saved-in-a-memory)
        - [6.1.5 Number of histories saved in a history file](#615-number-of-histories-saved-in-a-history-file)
        - [6.1.6 History command configuration](#616-history-command-configuration)

### 1. .zhrc 
### 2. aliases.zsh

The `aliases.zsh` file contains helpful shortcut aliases (GNU or macOS) in order to help setting up the right
`aliases` environment variables to your Z Shell.

#### 2.1 Sourcing alias plugins.

##### 2.1.1 Main Aliases location

```bash
source $ZSH_HOME/aliases/aliases.plugin.zsh
```

##### 2.1.2 gCloud Aliases location

```bash
source $ZSH_HOME/aliases/gcloud/gcloud.plugin.zsh
```

##### 2.1.3 Git Aliases location

```bash
source $ZSH_HOME/aliases/git/git.plugin.zsh
```

##### 2.1.4 Heroku Aliases location

```bash
source $ZSH_HOME/aliases/heroku/heroku.plugin.zsh
```

##### 2.1.5 Homebrew Aliases location

```bash
source $ZSH_HOME/aliases/homebrew/homebrew.plugin.zsh
```

##### 2.1.6 Jekyll Aliases location

```bash
 source $ZSH_HOME/aliases/jekyll/jekyll.plugin.zsh
```

##### 2.1.7 Subversions Aliases location

```bash
source $ZSH_HOME/aliases/subversion/subversion.plugin.zsh
```
### 3. configurations.zsh

The `configurations.zsh` file contains helpful shortcut configurations (GNU or macOS) in order to help setting up the right
`configurations` environment variables to your Z Shell.

#### 3.1 Sourcing configurations plugins.

##### 3.1.1 Load custom configurations

```bash
for config in $ZSH_HOME/configurations/[^.#]*.zsh; do
  source $config
done
```

### 4. exit.zsh

The `exit.zsh` file contains helpful shortcut exit (GNU or macOS) in order to help setting up the right
`exit` environment variables to your Z Shell.

#### 4.1 Sourcing exit plugins.

##### 4.1.1 Executed by Ze Shell when login shell exits 

```bash
if [[ "$SHLVL" = 1 ]]; then
  clear && printf '\e[3J'
fi
```

### 5. functions.zsh

The `functions.zsh` file contains helpful shortcut functions (GNU or macOS) in order to help setting up the right
`functions` environment variables to your Z Shell.

#### 5.1 Sourcing functions plugins.

##### 5.1.1 Load custom executable functions

```bash
for function in $ZSH_HOME/functions/[^.#]*.zsh; do
  source $function
done
```
### 6. history.zsh

The `history.zsh` file contains helpful shortcut history (GNU or macOS) in order to help setting up the right
`history` environment variables to your Z Shell.

#### 6.1 Sourcing history plugins.

##### 6.1.1 History wrapper

```bash
function dotfiles_history {
  local clear list
  zparseopts -E c=clear l=list

  if [[ -n "$clear" ]]; then
    # if -c provided, clobber the history file
    echo -n >| "$HISTFILE"
    echo >&2 History file deleted. Reload the session to see its effects.
  elif [[ -n "$list" ]]; then
    # if -l provided, run as if calling `fc' directly
    builtin fc "$@"
  else
    # unless a number is provided, show all history events (starting from 1)
    [[ ${@[-1]-} = *[0-9]* ]] && builtin fc -l "$@" || builtin fc -l "$@" 1
  fi
}
```

##### 6.1.2 Timestamp format

```bash
case ${HIST_STAMPS-} in
  "mm/dd/yyyy") alias history='dotfiles_history -f' ;;
  "dd.mm.yyyy") alias history='dotfiles_history -E' ;;
  "yyyy-mm-dd") alias history='dotfiles_history -i' ;;
  "") alias history='dotfiles_history' ;;
  *) alias history="dotfiles_history -t '$HIST_STAMPS'" ;;
esac
```

##### 6.1.3 Command history configuration

```bash
[ -z "$HISTFILE" ] && HISTFILE="$HOME/.zsh_history"
```

##### 6.1.4 Number of histories saved in a memory

```bash
export HISTSIZE=50000 
```

##### 6.1.5 Number of histories saved in a history file

```bash
export SAVEHIST=10000
```

##### 6.1.6 History command configuration

```bash
setopt always_to_end            # Move cursor to the end of a completed word.
setopt append_history           # Sessions will append their history list to the history file, rather than replace it. 
setopt auto_cd                  # cd to a directory if it's given without a command.
setopt auto_list                # Automatically list choices on ambiguous completion.
setopt auto_menu                # Show completion menu on a successive tab press.
setopt auto_param_keys          # Automatically complements parentheses
setopt auto_param_slash         # If completed parameter is a directory, add a trailing slash.
setopt auto_pushd               # Automatically push when cd
setopt auto_resume              # Resume if you execute the same command name as the suspended process
setopt bang_hist                # Perform textual history expansion
setopt complete_in_word         # Complete from both ends of a word.
setopt correct                  # Enable command correction prompts
setopt extended_history         # Save each command’s beginning timestamp (in seconds since the epoch) and the duration (in seconds) to the history file. 
setopt hist_beep                # Beep in ZLE when a widget attempts to access a history entry which isn’t there.
setopt hist_expire_dups_first   # Cause the oldest history event that has a duplicate to be lost before losing a unique event from the list.
setopt hist_ignore_space        # Remove command lines from the history list when the first character on the line is a space, or when one of the expanded aliases contains a leading space.
setopt hist_no_store            # Remove the history (fc -l) command from the history list when invoked.
setopt hist_reduce_blanks       # Remove superfluous blanks from each command line being added to the history list.
setopt hist_save_no_dups        # When writing out the history file, older commands that duplicate newer ones are omitted.
setopt hist_verify              # Whenever the user enters a line with history expansion, don’t execute the line directly; instead, perform history expansion and reload the line into the editing buffer.
setopt list_packed              # Display with complementary candidates packed
setopt list_types               # Mark the file type in the completion candidate list
setopt pushd_ignore_dups        # Don’t push multiple copies of the same directory onto the directory stack.
setopt share_history            # Imports new commands from the history file, and also causes the typed commands to be appended to the history file
```