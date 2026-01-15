#!/usr/bin/env bash
################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - apilatency
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# apilatency - API Latency / Response Time Monitor
#
# This script monitors the response time of an API endpoint over a specified
# number of requests and interval.
#
# Usage:
#   apilatency URL [COUNT] [INTERVAL]
#
# Options:
#   -h, --help            Show this help message and exit
#   -v, --version         Show script version and exit
#
# Examples:
#   apilatency https://api.example.com 10 1
#   apilatency https://api.example.com 20 0.5
#
################################################################################

# Constants
APILATENCY_SCRIPT_NAME="apilatency"
APILATENCY_VERSION="0.0.1"

#######################################
# Print usage information.
#######################################
apilatency_print_help() {
    cat << EOF
Usage: $APILATENCY_SCRIPT_NAME URL [COUNT] [INTERVAL]

Arguments:
  URL                 The API endpoint to monitor
  COUNT               Number of requests to perform (default: 10)
  INTERVAL            Delay between requests in seconds (default: 1)

Options:
  -h, --help            Show this help message and exit
  -v, --version         Show script version and exit

Examples:
  $APILATENCY_SCRIPT_NAME https://api.example.com 10 1
  $APILATENCY_SCRIPT_NAME https://api.example.com 20 0.5
EOF
}

#######################################
# Print version information.
#######################################
apilatency_print_version() {
    echo "$APILATENCY_SCRIPT_NAME version $APILATENCY_VERSION"
}

#######################################
# Monitor API response time.
#######################################
apilatency_monitor() {
    local url="$1"
    local count="${2:-10}"
    local interval="${3:-1}"
    
    echo -e "[INFO] Monitoring API latency for $url"
    echo -e "[INFO] Total Requests: $count, Delay Between Requests: $interval seconds"
    echo "Time,Response_Time"
    
    for ((i = 1; i <= count; i++)); do
        local start=$(date +%s.%N)
        curl -s -o /dev/null "$url"
        local end=$(date +%s.%N)
        local latency=$(echo "$end - $start" | bc)
        echo "$(date '+%H:%M:%S'),$latency"
        sleep "$interval"
    done
    
    echo -e "\e[32m[SUCCESS]\e[0m Latency monitoring completed."
}

#######################################
# Parse command-line arguments.
#######################################
apilatency_parse_arguments() {
    # First argument handling
    case "${1:-}" in
        -h|--help)
            apilatency_print_help
            return 2
            ;;
        -v|--version)
            apilatency_print_version
            return 2
            ;;
        "")
            echo -e "\e[31m[ERROR]\e[0m Missing required URL argument."
            apilatency_print_help
            return 1
            ;;
    esac

    # Store arguments
    local url="$1"
    local count="${2:-10}"
    local interval="${3:-1}"

    # Validate URL
    if [[ ! "$url" =~ ^https?:// ]]; then
        echo -e "\e[31m[ERROR]\e[0m Invalid URL format. Must start with http:// or https://"
        return 1
    fi

    # Validate count
    if ! [[ "$count" =~ ^[0-9]+$ ]]; then
        echo -e "\e[31m[ERROR]\e[0m COUNT must be a positive integer."
        return 1
    fi

    # Validate interval
    if ! [[ "$interval" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo -e "\e[31m[ERROR]\e[0m INTERVAL must be a positive number."
        return 1
    fi

    # Export variables for use in main function
    URL="$url"
    COUNT="$count"
    INTERVAL="$interval"
    
    return 0
}

#######################################
# Main function.
#######################################
apilatency_main() {
    apilatency_parse_arguments "$@"
    local parse_result=$?
    
    case $parse_result in
        0)  # Normal operation
            apilatency_monitor "$URL" "$COUNT" "$INTERVAL"
            ;;
        2)  # Help or version was displayed
            return 0
            ;;
        *)  # Error occurred
            return 1
            ;;
    esac
}

# The main function that gets exported for use
apilatency() {
    apilatency_main "$@"
}