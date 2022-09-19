#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - Options configuration.

## 🅾🅿🆃🅸🅾🅽🆂

umask 022 # Set umask to 022

# Shopt settings
# shopt -s cdspell      # Spell check the path when changing directories.
# shopt -s checkhash    # Check hash table for commands before running them.
# shopt -s checkjobs    # Check for stopped jobs after each command and report them to the user.
# shopt -s checkwinsize # Check the window size after each command and, if necessary, update the values of LINES and COLUMNS.
# shopt -s cmdhist      # Save multi-line commands as one entry in history.
# shopt -s dotglob      # Include dotfiles in globbing.
# shopt -s extglob      # Extended globbing.
# shopt -s globstar     # Allow ** to match multiple directories.
# shopt -s histappend   # Append to the history file, don't overwrite it.
# shopt -s histverify   # Verify commands from history before executing them.
# shopt -s huponexit    # Send SIGHUP to jobs when the shell exits.
# shopt -s no_empty_cmd_completion # Don't complete empty commands.
# shopt -s nocaseglob   # Case insensitive globbing.

# Enable colors in prompt
autoload -Uz colors && colors

# disable ^S and ^Q terminal freezing
unsetopt flowcontrol

# Unset autocorrect
unsetopt correct_all

# Changing Directories
setopt AUTO_PUSHD                     # pushd instead of cd
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT                   # hide stack after cd
setopt PUSHD_TO_HOME                  # go home if no d specified

# Completion
setopt AUTO_LIST                      # list completions
setopt AUTO_MENU                      # TABx2 to start a tab complete menu
setopt NO_COMPLETE_ALIASES            # no expand aliases before completion
setopt LIST_PACKED                    # variable column widths

# Expansion and Globbing
setopt EXTENDED_GLOB                  # like ** for recursive dirs

# History
setopt APPEND_HISTORY                 # append instead of overwrite file
setopt EXTENDED_HISTORY               # extended timestamps
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE              # omit from history if space prefixed
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY                    # verify when using history cmds/params

# Initialisation

# Input/Output
setopt ALIASES                        # autocomplete switches for aliases
setopt AUTO_PARAM_SLASH               # append slash if autocompleting a dir
setopt CORRECT

# Job Control
setopt CHECK_JOBS                     # prompt before exiting shell with bg job
setopt LONGLISTJOBS                   # display PID when suspending bg as well
setopt NO_HUP                         # do not kill bg processes

# Prompting

setopt PROMPT_SUBST                   # allow variables in prompt

# Scripts and Functions

# Shell Emulation
setopt INTERACTIVE_COMMENTS           # allow comments in shell

# Shell State

# Zle
setopt NO_BEEP
setopt VI

# Fix array index for zsh
if [ "$ZSH_NAME" = "zsh" ];then
    setopt localoptions ksharrays
fi
