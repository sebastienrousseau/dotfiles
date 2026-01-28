# shellcheck shell=bash
# Description:
#   environment is a function that detects the current operating system
#   environment. It identifies whether the system is macOS, Linux, or Windows
#   (including Cygwin and MING environments).
#
# Usage:
#   environment
#   environment --help
#
# Arguments:
#   --help      Displays this help menu and exits.
#
# Examples:
#   environment
#       # Detects and displays the current operating system environment.
#
#   environment --help
#       # Displays the help menu.
#
################################################################################

# Function to detect the current environment
environment() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    echo "environment: Environment Detector"
    echo
    echo "Usage:"
    echo "  environment"
    echo "  environment --help"
    echo
    echo "Arguments:"
    echo "  --help      Displays this help menu and exits."
    echo
    echo "Examples:"
    echo "  environment"
    echo "      # Detects and displays the current operating system environment."
    echo
    echo "  environment --help"
    echo "      # Displays the help menu."
    echo
    return 0
  fi

  # Detect the environment (single uname call)
  local os_name
  os_name="$(uname -s)"
  case "$os_name" in
    Darwin)          LOCAL_OS="mac" ;;
    Linux)           LOCAL_OS="linux" ;;
    MINGW*|MSYS*)    LOCAL_OS="win" ;;
    Cygwin|CYGWIN*)  LOCAL_OS="win" ;;
    *)               LOCAL_OS="other" ;;
  esac

  # Output the result
  echo "${LOCAL_OS}"
}
