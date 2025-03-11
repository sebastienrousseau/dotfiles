#!/usr/bin/env bash
################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: list.sh
# Version: 0.2.470
# Author: Sebastien Rousseau (Sebastien Rousseau)
# License: MIT
#
# Description:
#   This script sets a set of aliases for file listing using `eza`.
#   If `eza` is not found, it falls back to `ls` with approximate equivalents.
#
# Requested Aliases:
#   alias ls='eza'                            # Basic replacement for ls
#   alias l='eza'                             # 'l' should be the same as ls/eza
#   alias ll='eza --long -a'                  # Long format, including hidden files
#   alias llm='eza --long -a --sort=modified'# Long format, hidden files, sorted by mod date
#   alias la='eza -a --group-directories-first' # Show all files, dirs first
#   alias lx='eza -a --group-directories-first --extended' # All files, dirs first, extended attrs
#   alias tree='eza --tree'                   # Tree view
#   alias lS='eza --oneline'                  # One entry per line
#
# Additionally, 'l' is now identical to 'ls' rather than a custom format.
################################################################################

if command -v eza >/dev/null 2>&1; then
    # eza is available

    # @name ls
    # @brief Basic replacement for ls using eza
    # @description If eza is installed, ls calls eza.
    # @example ls
    alias ls='eza'

    # @name l
    # @brief Identical to ls/eza
    # @description l should mirror ls exactly when eza is available.
    # @example l
    alias l='eza'

    # @name ll
    # @brief Long format including hidden files
    # @description Uses `--long -a` for details and hidden files.
    # @example ll
    alias ll='eza --long -a'

    # @name llm
    # @brief Long format, including hidden files, sorted by modification date
    # @description Uses `--long -a --sort=modified`.
    # @example llm
    alias llm='eza --long -a --sort=modified'

    # @name la
    # @brief Show all files, directories listed first
    # @description Uses `-a --group-directories-first` to show hidden and group dirs first.
    # @example la
    alias la='eza -a --group-directories-first'

    # @name lx
    # @brief Show all files and extended attributes, directories first
    # @description `-a --group-directories-first --extended`.
    # @example lx
    alias lx='eza -a --group-directories-first --extended'

    # @name tree
    # @brief Tree view
    # @description Uses `--tree` for a tree-like directory listing.
    # @example tree
    alias tree='eza --tree'

    # @name lS
    # @brief One entry per line
    # @description Uses `--oneline` to list files one per line.
    # @example lS
    alias lS='eza --oneline'

else
    # eza not found, fallback to ls approximations
    echo "Note: 'eza' not found. Using 'ls' fallback." >&2
    echo "Install 'eza' for enhanced listing: https://github.com/eza-community/eza" >&2

    # @name ls (fallback)
    # @brief Basic listing using ls
    # @example ls
    alias ls='ls'

    # @name l (fallback)
    # @brief Identical to ls
    # @description l should mirror ls exactly when eza is not available.
    # @example l
    alias l='ls'

    # @name ll (fallback)
    # @brief Long format including hidden files
    # @description `-lA` shows long listing including hidden files.
    # @example ll
    alias ll='ls -lA'

    # @name llm (fallback)
    # @brief Sort by modification time
    # @description `ls -ltA` sorts by modification time, includes hidden with `-A`.
    # @example llm
    alias llm='ls -ltA'

    # @name la (fallback)
    # @brief Show all files
    # @description `-a` shows hidden files. No directories-first in plain ls.
    # @example la
    alias la='ls -a'

    # @name lx (fallback)
    # @brief Show all files; extended attributes are not directly in ls
    # @description `-la` shows long listing including hidden.
    # @example lx
    alias lx='ls -la'

    # @name tree (fallback)
    # @brief Tree view (approx.)
    # @description If `tree` is installed, use it; otherwise `ls -R`.
    # @example tree
    if command -v tree >/dev/null 2>&1; then
        alias tree='tree'
    else
        alias tree='ls -R'
    fi

    # @name lS (fallback)
    # @brief One entry per line
    # @description `-1` lists files one per line.
    # @example lS
    alias lS='ls -1'
fi
