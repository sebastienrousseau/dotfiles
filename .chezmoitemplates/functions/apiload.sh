# shellcheck shell=bash
# Copyright (c) 2015-2026 . All rights reserved.
#
# This script performs basic load testing on a specified API endpoint using
# default utilities available in macOS, Linux, or Windows environments. It allows
# you to specify the number of total requests and the delay between requests.
#
# Usage:
#   apiload URL [REQUESTS] [DELAY]
#
# Examples:
#   apiload https://api.example.com 100 0.1
#   apiload https://api.example.com 500 0.5
#
################################################################################

# Constants
APILOAD_SCRIPT_NAME="apiload"
APILOAD_VERSION="0.0.1"

#######################################
# Print usage information.
#######################################
apiload_print_help() {
  cat <<EOF
Usage: $APILOAD_SCRIPT_NAME URL [REQUESTS] [DELAY]

Arguments:
  URL                 The API endpoint to load test
  REQUESTS            Number of total requests to perform (default: 100)
  DELAY               Delay between requests in seconds (default: 0.1)

Options:
  -h, --help            Show this help message and exit
  -v, --version         Show script version and exit

Examples:
  $APILOAD_SCRIPT_NAME https://api.example.com 100 0.1
  $APILOAD_SCRIPT_NAME https://api.example.com 500 0.5
EOF
}

#######################################
# Print version information.
#######################################
apiload_print_version() {
  echo "$APILOAD_SCRIPT_NAME version $APILOAD_VERSION"
}

#######################################
# Perform API load testing.
#######################################
apiload_load_test() {
  local url="$1"
  local requests="${2:-100}"
  local delay="${3:-0.1}"

  printf '%b\n' "[INFO] Running load test on $url"
  printf '%b\n' "[INFO] Total Requests: $requests, Delay Between Requests: $delay seconds"

  local success_count=0
  local fail_count=0

  for ((i = 1; i <= requests; i++)); do
    response=$(curl -s --connect-timeout 5 --max-time 30 -o /dev/null -w "%{http_code}" "$url")
    if [[ "$response" -eq 200 ]]; then
      printf '%b\n' "\e[32m[Request $i]\e[0m Success (HTTP 200)"
      ((success_count++))
    else
      printf '%b\n' "\e[31m[Request $i]\e[0m Failed (HTTP $response)"
      ((fail_count++))
    fi
    sleep "$delay"
  done

  printf '%b\n' "\n[SUMMARY]"
  printf '%b\n' "Total Requests: $requests"
  printf '%b\n' "Successful: \e[32m$success_count\e[0m"
  printf '%b\n' "Failed: \e[31m$fail_count\e[0m"
  printf '%b\n' "Success Rate: $(((success_count * 100) / requests))%"

  printf '%b\n' "\n\e[32m[SUCCESS]\e[0m Load test completed."
}

#######################################
# Parse command-line arguments.
#######################################
apiload_parse_arguments() {
  # First argument handling
  case "${1:-}" in
  -h | --help)
    apiload_print_help
    return 2
    ;;
  -v | --version)
    apiload_print_version
    return 2
    ;;
  "")
    printf '%b\n' "\e[31m[ERROR]\e[0m Missing required URL argument."
    apiload_print_help
    return 1
    ;;
  esac

  # Store arguments
  local url="$1"
  local requests="${2:-100}"
  local delay="${3:-0.1}"

  # Validate URL
  if [[ ! "$url" =~ ^https?:// ]]; then
    printf '%b\n' "\e[31m[ERROR]\e[0m Invalid URL format. Must start with http:// or https://"
    return 1
  fi

  # Validate requests
  if ! [[ "$requests" =~ ^[0-9]+$ ]]; then
    printf '%b\n' "\e[31m[ERROR]\e[0m REQUESTS must be a positive integer."
    return 1
  fi

  # Validate delay
  if ! [[ "$delay" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    printf '%b\n' "\e[31m[ERROR]\e[0m DELAY must be a positive number."
    return 1
  fi

  # Export variables for use in main function
  URL="$url"
  REQUESTS="$requests"
  DELAY="$delay"

  return 0
}

#######################################
# Main function.
#######################################
apiload_main() {
  apiload_parse_arguments "$@"
  local parse_result=$?

  case $parse_result in
  0) # Normal operation
    apiload_load_test "$URL" "$REQUESTS" "$DELAY"
    ;;
  2) # Help or version was displayed
    return 0
    ;;
  *) # Error occurred
    return 1
    ;;
  esac
}

# The apiload_main function that gets exported for use
apiload() {
  apiload_main "$@"
}
