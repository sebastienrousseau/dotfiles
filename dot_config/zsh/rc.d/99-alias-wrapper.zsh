# Smart Alias Function (High-Fidelity TUI)
alias_wrapper() {
  if [[ $# -eq 0 ]]; then
    if command -v gum >/dev/null 2>&1; then
      # Extract aliases, format as | separated, and pipe to gum table
      builtin alias | sed -E "s/^([^=]+)='?([^']*)'?$/\1|\2/" | 
        gum table --separator "|" --columns "Alias,Command" --widths 15,60 
        --border rounded --border.foreground 212 --header.foreground 212
    elif command -v bat >/dev/null 2>&1; then
      builtin alias | bat -l sh --style=plain
    else
      builtin alias
    fi
  else
    builtin alias "$@"
  fi
}
alias alias=alias_wrapper
