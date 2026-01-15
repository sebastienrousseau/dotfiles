#!/usr/bin/env bash

################################################################################
# Startup Profile System
# Allows configuration of shell startup behavior via DOTFILES_STARTUP_MODE
#
# Usage:
#   DOTFILES_STARTUP_MODE=fast bash      # Fast mode: essentials only (~200ms)
#   DOTFILES_STARTUP_MODE=normal bash    # Normal mode: default (~400-600ms)
#   DOTFILES_STARTUP_MODE=full bash      # Full mode: everything (~1000ms)
#
# Environment Variables:
#   DOTFILES_STARTUP_MODE - Sets startup profile (fast/normal/full)
#   DOTFILES_STARTUP_PROFILE_DEBUG - Show profile info (0/1)
################################################################################

#-----------------------------------------------------------------------------
# Function: get_startup_mode
#
# Description:
#   Returns the current startup mode (fast, normal, or full).
#   Defaults to 'normal' if not set.
#
# Arguments:
#   None
#
# Returns:
#   Echoes the startup mode
#
# Example:
#   mode=$(get_startup_mode)
#   if [[ "$mode" == "fast" ]]; then
#       # Skip heavy modules
#   fi
#
#-----------------------------------------------------------------------------
get_startup_mode() {
    local mode="${DOTFILES_STARTUP_MODE:-normal}"
    
    # Validate mode
    case "$mode" in
        fast|normal|full)
            echo "$mode"
            ;;
        *)
            echo "normal"  # Default to normal on invalid input
            ;;
    esac
}

#-----------------------------------------------------------------------------
# Function: should_load_module
#
# Description:
#   Determines if a module should be loaded based on startup mode and module type.
#   Modules can be: critical, common, heavy, or optional.
#
# Arguments:
#   $1: Module name or path
#   $2: Module type (critical/common/heavy/optional)
#
# Returns:
#   0 if module should be loaded, 1 otherwise
#
# Examples:
#   should_load_module "history.sh" "common" && source "$DOTFILES/history.sh"
#   should_load_module "heroku.aliases.sh" "heavy" && source_heavy_alias
#
# Load Policy by Mode:
#   fast:
#     - critical: YES (system, functions, paths)
#     - common: NO (aliases, configs)
#     - heavy: NO (heroku, gcloud, git extras)
#     - optional: NO (utilities, examples)
#
#   normal (default):
#     - critical: YES
#     - common: YES (most aliases and configs)
#     - heavy: LAZY (defer until first use)
#     - optional: NO
#
#   full:
#     - critical: YES
#     - common: YES
#     - heavy: YES (load immediately)
#     - optional: YES
#
#-----------------------------------------------------------------------------
should_load_module() {
    local module_name="$1"
    local module_type="${2:-optional}"  # Default to optional if not specified
    local startup_mode
    
    startup_mode=$(get_startup_mode)
    
    case "$startup_mode" in
        fast)
            # Fast mode: only load critical modules
            case "$module_type" in
                critical) return 0 ;;
                *)        return 1 ;;
            esac
            ;;
        normal)
            # Normal mode: critical + common modules, defer heavy modules
            case "$module_type" in
                critical) return 0 ;;
                common)   return 0 ;;
                heavy)    return 1 ;;  # Will be lazy loaded
                optional) return 1 ;;
            esac
            ;;
        full)
            # Full mode: load everything
            return 0
            ;;
    esac
    
    return 1  # Default: don't load
}

#-----------------------------------------------------------------------------
# Function: get_startup_info
#
# Description:
#   Returns information about the current startup configuration.
#   Useful for debugging and understanding which modules are being loaded.
#
# Arguments:
#   None
#
# Returns:
#   Prints startup profile information
#
#-----------------------------------------------------------------------------
get_startup_info() {
    local mode
    mode=$(get_startup_mode)
    
    echo "Startup Profile: $mode"
    
    case "$mode" in
        fast)
            echo "  - Loading critical modules only"
            echo "  - Expected startup: ~150-250ms"
            echo "  - Aliases/functions: Lazy-loaded on first use"
            echo "  - Best for: Quick shell startup, scripting"
            ;;
        normal)
            echo "  - Loading critical + common modules"
            echo "  - Heavy modules: Lazy-loaded on first use"
            echo "  - Expected startup: ~400-600ms (with cache)"
            echo "  - Best for: Default interactive use (RECOMMENDED)"
            ;;
        full)
            echo "  - Loading all modules upfront"
            echo "  - Expected startup: ~1000ms+"
            echo "  - Best for: Development, testing, full feature availability"
            ;;
    esac
}

#-----------------------------------------------------------------------------
# Export functions for use in .bashrc/.zshrc (Bash only)
#-----------------------------------------------------------------------------
if [[ -n "${BASH_VERSION:-}" ]]; then
  export -f get_startup_mode 2>/dev/null || true
  export -f should_load_module 2>/dev/null || true
  export -f get_startup_info 2>/dev/null || true
fi
