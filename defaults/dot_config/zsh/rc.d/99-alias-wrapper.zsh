# Smart Alias Function (High-Fidelity TUI)
alias_wrapper() {
  if [[ $# -eq 0 ]]; then
    # Find gum cmd dynamically if needed
    local gum_cmd
    gum_cmd=$(command -v gum 2>/dev/null || (command -v mise >/dev/null && mise which "aqua:charmbracelet/gum" 2>/dev/null))

    if [[ -n "$gum_cmd" ]]; then
      # Use printf to get a literal tab
      local tab=$'\t'

      # Extract aliases, format as Tab separated, ensure only 2 columns, and pipe to gum table
      builtin alias | sed -E "s/^([^=]+)='?([^']*)'?$/\1${tab}\2/" |
        while IFS=$tab read -r alias_name cmd_body; do
          if [[ -n "$alias_name" && -n "$cmd_body" ]]; then
            # Ensure no extra tabs in body and exactly one tab total
            local clean_cmd="${cmd_body//$tab/ }"
            printf "%s\t%s\n" "$alias_name" "$clean_cmd"
          fi
        done |
        "$gum_cmd" table --separator "${tab}" --print --columns "Alias,Command" --widths 15,60 \
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
