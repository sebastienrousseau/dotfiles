# shellcheck shell=bash
# CD Navigation - Main loader
# Loads all CD navigation submodules in dependency order

[[ -n "${_CD_ALIASES_LOADED:-}" ]] && :
_CD_ALIASES_LOADED=1

# Get the directory containing this script
_CD_ALIASES_DIR="${BASH_SOURCE[0]%/*}"

# Load submodules in dependency order
# 1. Configuration (required by all others)
# shellcheck source=/dev/null
[[ -f "${_CD_ALIASES_DIR}/cd-config.aliases.sh" ]] && source "${_CD_ALIASES_DIR}/cd-config.aliases.sh"

# 2. Utility functions (required by core and bookmarks)
# shellcheck source=/dev/null
[[ -f "${_CD_ALIASES_DIR}/cd-utils.aliases.sh" ]] && source "${_CD_ALIASES_DIR}/cd-utils.aliases.sh"

# 3. Core functions (cd_with_history, mkcd - required by bookmarks, navigation)
# shellcheck source=/dev/null
[[ -f "${_CD_ALIASES_DIR}/cd-core.aliases.sh" ]] && source "${_CD_ALIASES_DIR}/cd-core.aliases.sh"

# 4. Bookmarks (uses cd_with_history)
# shellcheck source=/dev/null
[[ -f "${_CD_ALIASES_DIR}/cd-bookmarks.aliases.sh" ]] && source "${_CD_ALIASES_DIR}/cd-bookmarks.aliases.sh"

# 5. History (uses cd_with_history)
# shellcheck source=/dev/null
[[ -f "${_CD_ALIASES_DIR}/cd-history.aliases.sh" ]] && source "${_CD_ALIASES_DIR}/cd-history.aliases.sh"

# 6. Navigation (proj, lwd - uses cd_with_history)
# shellcheck source=/dev/null
[[ -f "${_CD_ALIASES_DIR}/cd-navigation.aliases.sh" ]] && source "${_CD_ALIASES_DIR}/cd-navigation.aliases.sh"

# 7. Shortcuts (parent dir aliases, location aliases)
# shellcheck source=/dev/null
[[ -f "${_CD_ALIASES_DIR}/cd-shortcuts.aliases.sh" ]] && source "${_CD_ALIASES_DIR}/cd-shortcuts.aliases.sh"

# 8. Directory stack management
# shellcheck source=/dev/null
[[ -f "${_CD_ALIASES_DIR}/cd-stack.aliases.sh" ]] && source "${_CD_ALIASES_DIR}/cd-stack.aliases.sh"

# 9. Tab completion (uses bookmark functions)
# shellcheck source=/dev/null
[[ -f "${_CD_ALIASES_DIR}/cd-completion.aliases.sh" ]] && source "${_CD_ALIASES_DIR}/cd-completion.aliases.sh"

# 10. Initialization (short aliases, restore last dir)
# shellcheck source=/dev/null
[[ -f "${_CD_ALIASES_DIR}/cd-init.aliases.sh" ]] && source "${_CD_ALIASES_DIR}/cd-init.aliases.sh"

# 11. Help functions
# shellcheck source=/dev/null
[[ -f "${_CD_ALIASES_DIR}/cd-help.aliases.sh" ]] && source "${_CD_ALIASES_DIR}/cd-help.aliases.sh"

unset _CD_ALIASES_DIR
