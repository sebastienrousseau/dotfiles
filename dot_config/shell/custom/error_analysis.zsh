# shellcheck shell=bash
# error_analysis.zsh
#
# Error Analysis for Predictive Shell
# Uses Local LLM to analyze the last failed command.
#

analyze_last_error() {
    # local exit_code="$?"  <-- unused
    local hist_entry
    
    # Get the last history entry (command that just ran)
    # fc -ln -1 returns the commands from the last 1 event
    hist_entry=$(fc -ln -1)
    
    if [[ -z "$hist_entry" ]]; then
        echo "No history found to analyze."
        return 1
    fi

    echo " Analyzing failure: '$hist_entry'"
    
    local prompt="I ran the command: '$hist_entry' and it failed. Please explain why this might have happened and suggest a fix. Be concise."
    
    # Call the ai_core wrapper
    # We call it directly from the path or rely on PATH if configured
    if [[ -f "${HOME}/.local/bin/ai_core" ]]; then
         "${HOME}/.local/bin/ai_core" query "$prompt"
    else
         local source_dir="${CHEZMOI_SOURCE_DIR:-${HOME}/.dotfiles}"
         if [[ ! -d "$source_dir" && -d "${HOME}/.local/share/chezmoi" ]]; then
             source_dir="${HOME}/.local/share/chezmoi"
         fi

         if [[ -f "${source_dir}/dot_local/bin/ai_core" ]]; then
             # Fallback for dev/testing location before chezmoi apply
             "${source_dir}/dot_local/bin/ai_core" query "$prompt"
         else
             echo "Error: ai_core wrapper not found."
         fi
    fi
}

# Alias '??' to analyze data
alias '??'='analyze_last_error'
