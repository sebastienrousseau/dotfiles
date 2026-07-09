# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
if [[ -n "${BASH_VERSION:-}" && -z "${_CD_COMPLETION_LOADED:-}" ]]; then
  # CD Navigation - Tab Completion

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

  # Set up completions. Mark loaded only once they are actually registered,
  # so a re-source before `complete` is available retries instead of being
  # permanently skipped.
  if type complete &>/dev/null; then
    _CD_COMPLETION_LOADED=1
    complete -F _bookmark_complete goto
    complete -F _bookmark_complete bookmark_update
    complete -F _bookmark_complete bookmark_remove
    complete -F _bookmark_complete bmg
    complete -F _bookmark_complete bmu
    complete -F _bookmark_complete bmr
  fi
fi

if [[ -n "${ZSH_VERSION:-}" && -z "${_CD_COMPLETION_LOADED_ZSH:-}" ]]; then
  # CD Navigation - Tab Completion (zsh)
  #
  # compdef is only available after compinit. Guard registration with a
  # positive check instead of a file-scope `return`: this fragment is inlined
  # into the single concatenated 90-ux-aliases.sh, so a bare `return` here
  # would abort the whole file and drop every alias defined afterwards
  # (reload, r, mkcd, quit, …).
  #
  # Mark loaded only AFTER a successful registration: if compdef is not ready
  # yet (sourced before compinit), leave _CD_COMPLETION_LOADED_ZSH unset so a
  # later re-source retries — otherwise completions are permanently skipped.
  if command -v compdef >/dev/null 2>&1; then
    _CD_COMPLETION_LOADED_ZSH=1

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
