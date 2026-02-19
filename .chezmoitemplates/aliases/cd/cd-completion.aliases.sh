# shellcheck shell=bash
# CD Navigation - Tab Completion
[[ -n "${_CD_COMPLETION_LOADED:-}" ]] && return 0
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
