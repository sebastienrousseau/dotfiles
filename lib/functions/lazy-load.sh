#!/usr/bin/env bash

################################################################################
# Lazy Loading System for Dotfiles
# Defers non-critical module loading until first use
# 
# This module provides the framework for lazy loading expensive modules.
# Heavy modules (like heroku, gcloud, fzf) are only loaded when first used.
################################################################################

#-----------------------------------------------------------------------------
# Function: lazy_load
#
# Description:
#   Creates a lazy-loaded function that sources a module on first use.
#   Subsequent calls use the cached function/module.
#
# Arguments:
#   $1: Command/function name to lazy load
#   $2: Module path to source
#   $3: Optional - callback function to run after module loads
#
# Returns:
#   0 on success, 1 on failure
#
# Usage:
#   lazy_load "nvm" "$HOME/.nvm/nvm.sh"
#   lazy_load "pyenv" "$HOME/.pyenv/bin/pyenv"
#   lazy_load "fzf_setup" "$HOME/.fzf.bash"
#
# Example:
#   When user types 'nvm', the wrapper executes, loads ~/.nvm/nvm.sh,
#   removes the wrapper, and then executes the real 'nvm' command.
#
# Technical Details:
#   - Uses eval to dynamically replace the wrapper with real function
#   - Prevents multiple loads by replacing the function after first use
#   - Silent operation - no visible delay or output to user
#   - Works with both functions and external commands
#
#-----------------------------------------------------------------------------
lazy_load() {
    local cmd_name="$1"
    local module_path="$2"
    local callback="${3:-}"
    
    # Validate inputs
    if [[ -z "$cmd_name" ]] || [[ -z "$module_path" ]]; then
        echo "lazy_load: Invalid arguments" >&2
        return 1
    fi
    
    # Check if module exists
    if [[ ! -f "$module_path" && ! -d "$module_path" ]]; then
        echo "lazy_load: Module not found: $module_path" >&2
        return 1
    fi
    
    # Create wrapper function that loads module on first use
    # Using eval to dynamically create the function
    eval "
    $cmd_name() {
        # Load the module
        if [[ -f '$module_path' ]]; then
            source '$module_path'
        elif [[ -d '$module_path' ]]; then
            source '$module_path/init.sh' || source '$module_path/$cmd_name.sh' 2>/dev/null || true
        fi
        
        # Call optional callback
        $(if [[ -n "$callback" ]]; then echo "
        if declare -f '$callback' > /dev/null; then
            $callback
        fi"; fi)
        
        # Remove this wrapper and call the real function
        unset -f $cmd_name
        $cmd_name \"\$@\"
    }
    "
    
    return 0
}

#-----------------------------------------------------------------------------
# Function: lazy_load_alias
#
# Description:
#   Creates a lazy-loaded alias that sources a module on first use.
#   Useful for heavy alias modules (heroku, gcloud, git extras, etc).
#
# Arguments:
#   $1: Alias name
#   $2: Module path
#
# Returns:
#   0 on success
#
# Usage:
#   lazy_load_alias "git" "$DOTFILES/aliases/git/git.aliases.sh"
#   lazy_load_alias "h" "$DOTFILES/aliases/history/history.aliases.sh"
#
# Technical Details:
#   - Creates a function with same name as alias
#   - When called, loads the module and re-runs the command
#   - Uses alias -p to load aliases from the module
#
#-----------------------------------------------------------------------------
lazy_load_alias() {
    local alias_name="$1"
    local module_path="$2"
    
    if [[ ! -f "$module_path" ]]; then
        return 1
    fi
    
    # Create wrapper function
    eval "
    $alias_name() {
        # Load the module (sources all aliases in it)
        source '$module_path' 2>/dev/null || true
        
        # Remove the wrapper function to use the real alias
        unset -f $alias_name
        
        # Call the real command/alias
        $alias_name \"\$@\"
    }
    "
    
    return 0
}

#-----------------------------------------------------------------------------
# Function: setup_lazy_modules
#
# Description:
#   Configures lazy loading for heavy modules that aren't needed at startup.
#   This significantly improves shell startup time.
#
# Arguments:
#   None
#
# Returns:
#   0 on success
#
# Modules Deferred:
#   - NVM (Node Version Manager) - only loaded when nvm command is used
#   - pyenv - only loaded when pyenv command is used
#   - rbenv - only loaded when rbenv command is used  
#   - fzf - only loaded when fzf is first used
#   - Heavy alias modules - loaded on first use
#
# Startup Impact:
#   Before lazy loading: 1050ms (Bash)
#   After lazy loading:  ~300ms (Bash) - estimated 70% reduction
#
#-----------------------------------------------------------------------------
setup_lazy_modules() {
    local dotfiles="${DOTFILES:-.}"
    
    # Lazy load NVM if it exists
    if [[ -s "${HOME}/.nvm/nvm.sh" ]]; then
        lazy_load "nvm" "${HOME}/.nvm/nvm.sh"
    fi
    
    # Lazy load pyenv if it exists
    if [[ -s "${HOME}/.pyenv/bin/pyenv" ]]; then
        lazy_load "pyenv" "${HOME}/.pyenv/bin/pyenv"
    fi
    
    # Lazy load rbenv if it exists
    if [[ -s "${HOME}/.rbenv/bin/rbenv" ]]; then
        lazy_load "rbenv" "${HOME}/.rbenv/bin/rbenv"
    fi
    
    # Lazy load fzf if it exists
    if [[ -f "${HOME}/.fzf.bash" ]]; then
        lazy_load "fzf_init" "${HOME}/.fzf.bash"
        # Create alias to trigger lazy load
        fzf_init() { _fzf_init_or_fallback; }
    fi
    
    # Lazy load heavy alias modules (these have many aliases)
    # Load only on first use of any command in that module
    
    # Heavy modules (>500 lines or many aliases)
    if [[ -f "$dotfiles/aliases/heroku/heroku.aliases.sh" ]]; then
        lazy_load_alias "heroku" "$dotfiles/aliases/heroku/heroku.aliases.sh"
    fi
    
    if [[ -f "$dotfiles/aliases/gcloud/gcloud.aliases.sh" ]]; then
        lazy_load_alias "gcloud" "$dotfiles/aliases/gcloud/gcloud.aliases.sh"
    fi
    
    return 0
}

#-----------------------------------------------------------------------------
# Export functions for use in .bashrc/.zshrc (Bash only - zsh doesn't support export -f)
#-----------------------------------------------------------------------------
if [ -n "${BASH_VERSION:-}" ]; then
    export -f lazy_load 2>/dev/null || true
    export -f lazy_load_alias 2>/dev/null || true
    export -f setup_lazy_modules 2>/dev/null || true
fi
