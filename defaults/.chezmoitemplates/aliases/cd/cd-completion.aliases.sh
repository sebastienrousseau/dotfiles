# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
if [[ -n "${BASH_VERSION:-}" ]]; then
  # CD Navigation - Tab Completion
  [[ -n "${_CD_COMPLETION_LOADED:-}" ]] && :
  _CD_COMPLETION_LOADED=1

  # Helper to list all bookmark names
  _get_bookmarks() {
    if [[ -f "${BOOKMARK_FILE}" ]]; then
      cut -d':' -f1 "${BOOKMARK_FILE}"
    fi
  }

  # Completion for bookmarks
  _bookmark_complete() {
    local curr_arg
    curr_arg=${COMP_WORDS[COMP_CWORD]}

    if [[ $COMP_CWORD -eq 1 ]]; then
      if type mapfile &>/dev/null; then
        mapfile -t COMPREPLY < <(compgen -W "$(_get_bookmarks)" -- "$curr_arg")
      else
        # Fallback for older bash versions
        # shellcheck disable=SC2207
        COMPREPLY=($(compgen -W "$(_get_bookmarks)" -- "$curr_arg"))
      fi
    fi
  }

  # Set up completions
  if type complete &>/dev/null; then
    complete -F _bookmark_complete goto
    complete -F _bookmark_complete bookmark_update
    complete -F _bookmark_complete bookmark_remove
    complete -F _bookmark_complete bmg
    complete -F _bookmark_complete bmu
    complete -F _bookmark_complete bmr
  fi
fi

if [[ -n "${ZSH_VERSION:-}" ]]; then
  # CD Navigation - Tab Completion (zsh)
  [[ -n "${_CD_COMPLETION_LOADED_ZSH:-}" ]] && :
  _CD_COMPLETION_LOADED_ZSH=1

  # compdef is only available after compinit. Guard the registration with
  # a positive check instead of an early `return`: this fragment is inlined
  # into the single concatenated 90-ux-aliases.sh, so a file-scope `return`
  # here aborts the WHOLE file and drops every alias defined afterwards
  # (reload, r, mkcd, quit, …). Skipping only this block is the safe form.
  if command -v compdef >/dev/null 2>&1; then
    _get_bookmarks() {
      if [[ -f "${BOOKMARK_FILE}" ]]; then
        cut -d':' -f1 "${BOOKMARK_FILE}"
      fi
    }

    _bookmark_complete_zsh() {
      local -a bookmarks
      local line
      while IFS= read -r line; do
        bookmarks+=("$line")
      done < <(_get_bookmarks)
      compadd -Q -- "${bookmarks[@]}"
    }

    compdef _bookmark_complete_zsh goto
    compdef _bookmark_complete_zsh bookmark_update
    compdef _bookmark_complete_zsh bookmark_remove
    compdef _bookmark_complete_zsh bmg
    compdef _bookmark_complete_zsh bmu
    compdef _bookmark_complete_zsh bmr
  fi
fi
