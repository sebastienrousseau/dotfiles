# shellcheck shell=bash
# Description:
#   curltime is a function that measures and displays various timing metrics for
#   an HTTP request made to a given URL using `curl`. It provides detailed
#   information on DNS resolution time, connection time, and total transfer time.
#
# Usage:
#   curltime [url]
#   curltime --help
#
# Arguments:
#   url         The URL for which to fetch timing metrics.
#   --help      Displays this help menu and exits.
#
# Examples:
#   curltime https://example.com
#       # Displays the timing metrics for the given URL.
#
#   curltime --help
#       # Displays the help menu.
#
################################################################################

# Function to display timing metrics for a given URL
curltime() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    echo "curltime: Curl Timing Viewer"
    echo
    echo "Usage:"
    echo "  curltime [url]"
    echo "  curltime --help"
    echo
    echo "Arguments:"
    echo "  url         The URL for which to fetch timing metrics."
    echo "  --help      Displays this help menu and exits."
    echo
    echo "Examples:"
    echo "  curltime https://example.com"
    echo "      # Displays the timing metrics for the given URL."
    echo
    echo "  curltime --help"
    echo "      # Displays the help menu."
    echo
    return 0
  fi

  # Check if a URL is provided
  if [[ -z "$1" ]]; then
    echo "[ERROR] No URL provided. Use 'curltime --help' for usage information." >&2
    return 1
  fi

  # Fetch and display timing metrics for the URL
  curl --connect-timeout 10 --max-time 30 -w "\n\
┌──────────────────────────────┐\n\
│Time appconnect:    %{time_appconnect}s │\n\
│Time connect:       %{time_connect}s │\n\
│Time namelookup:    %{time_namelookup}s │\n\
│Time pretransfer:   %{time_pretransfer}s │\n\
│Time redirect:      %{time_redirect}s │\n\
│Time starttransfer: %{time_starttransfer}s │\n\
└──────────────────────────────┘\n\
Time total:  %{time_total}s\n\n" -o /dev/null -s "$1"
}

# Aliases for convenience
alias cht="curltime" # Alias for curltime
