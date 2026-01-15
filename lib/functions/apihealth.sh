#!/usr/bin/env bash
################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - apihealth
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# apihealth - API Health Check Script
#
# This script checks the health/status of one or multiple APIs by sending HTTP
# requests to specified endpoints. It supports different HTTP methods, allows
# specifying expected HTTP status codes, and accepts custom HTTP headers.
#
# Usage:
#   apihealth [OPTIONS] URL [URL ...]
#
# Options:
#   -h, --help            Show this help message and exit
#   -v, --version         Show script version and exit
#   -m, --method METHOD   Specify HTTP method (default: GET)
#   -e, --expect STATUS   Specify expected HTTP status code (default: 200)
#   -H, --header HEADER   Specify HTTP header (can be used multiple times)
#   -t, --timeout SECONDS Specify request timeout in seconds (default: 10)
#
# Examples:
#   apihealth https://api.example.com/health
#   apihealth -m POST -e 201 https://api.example.com/create
#   apihealth --method GET --expect 204 https://api.example.com/status1 https://api.example.com/status2
#   apihealth -H "Authorization: Bearer token123" -H "Content-Type: application/json" https://api.example.com/secure
#   apihealth -t 5 https://api.example.com/health
#
################################################################################

# Constants
APIHEALTH_SCRIPT_NAME="apihealth"
APIHEALTH_VERSION="0.1"

# Default values
DEFAULT_METHOD="GET"
DEFAULT_EXPECT_STATUS=200
DEFAULT_TIMEOUT=10

# Initialize headers array
HEADERS=()

#######################################
# Print usage information.
# Returns:
#   0 if help was shown
#######################################
print_help() {
    cat << EOF
Usage: $APIHEALTH_SCRIPT_NAME [OPTIONS] URL [URL ...]

Options:
  -h, --help                Show this help message and exit
  -v, --version             Show script version and exit
  -m, --method METHOD       Specify HTTP method (default: GET)
  -e, --expect STATUS       Specify expected HTTP status code (default: 200)
  -H, --header HEADER       Specify HTTP header (can be used multiple times)
  -t, --timeout SECONDS     Specify request timeout in seconds (default: 10)

Examples:
  $APIHEALTH_SCRIPT_NAME https://api.example.com/health
  $APIHEALTH_SCRIPT_NAME -m POST -e 201 https://api.example.com/create
  $APIHEALTH_SCRIPT_NAME -H "Authorization: Bearer token123" https://api.example.com/secure
  $APIHEALTH_SCRIPT_NAME -t 5 https://api.example.com/health
EOF
    return 0
}


#######################################
# Print version information.
# Returns:
#   0 if version was shown
#######################################
print_version() {
    echo "$APIHEALTH_SCRIPT_NAME version $APIHEALTH_VERSION"
    return 0
}

#######################################
# Check if required dependencies are installed.
# Returns:
#   1 if dependencies are missing
#######################################
check_dependencies() {
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "\e[31m[ERROR]\e[0m Required command 'curl' is not installed."
        return 1
    fi
    return 0
}

#######################################
# Check API health/status endpoints.
# Arguments:
#   $1 - URL
#   $2 - HTTP Method
#   $3 - Expected HTTP Status Code
#   $4 - Timeout in seconds
# Returns:
#   0 if health check passed, 1 if failed
#######################################
apihealthealth() {
    local url="$1"
    local method="${2:-$DEFAULT_METHOD}"
    local expect_status="${3:-$DEFAULT_EXPECT_STATUS}"
    local timeout="${4:-$DEFAULT_TIMEOUT}"
    local curl_headers=()

    echo -e "[INFO] Testing API health: $url"
    echo -e "[INFO] Method: $method, Expected Status: $expect_status, Timeout: ${timeout}s"

    # Build curl headers array
    if [[ ${#HEADERS[@]} -gt 0 ]]; then
        for header in "${HEADERS[@]}"; do
            curl_headers+=(-H "$header")
        done
    fi

    # Perform the HTTP request
    local response
    if [[ ${#curl_headers[@]} -gt 0 ]]; then
        response=$(curl -s -o /dev/null -w "%{http_code}" \
            -X "$method" \
            --max-time "$timeout" \
            "${curl_headers[@]}" \
            "$url" 2>/dev/null || echo "000")
    else
        response=$(curl -s -o /dev/null -w "%{http_code}" \
            -X "$method" \
            --max-time "$timeout" \
            "$url" 2>/dev/null || echo "000")
    fi

    if [[ "$response" -eq "$expect_status" ]]; then
        echo -e "\e[32m[SUCCESS]\e[0m API is healthy (Status: $response)"
        return 0
    elif [[ "$response" -eq "000" ]]; then
        echo -e "\e[31m[ERROR]\e[0m API health check failed (No response)"
        return 1
    else
        echo -e "\e[31m[ERROR]\e[0m API health check failed (Status: $response)"
        return 1
    fi
}

#######################################
# Parse command-line arguments.
# Arguments:
#   Command line arguments
# Returns:
#   0 if parsing successful, 1 if failed
#######################################
parse_arguments() {
    # Initialize variables
    METHOD="$DEFAULT_METHOD"
    EXPECT_STATUS="$DEFAULT_EXPECT_STATUS"
    TIMEOUT="$DEFAULT_TIMEOUT"
    URLS=()
    HEADERS=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                print_help
                return 2  # Special return code for help/version display
                ;;
            -v|--version)
                print_version
                return 2  # Special return code for help/version display
                ;;
            -m|--method)
                if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                    METHOD="$2"
                    shift 2
                else
                    echo -e "\e[31m[ERROR]\e[0m --method requires a non-empty option argument."
                    return 1
                fi
                ;;
            -e|--expect)
                if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                    EXPECT_STATUS="$2"
                    shift 2
                else
                    echo -e "\e[31m[ERROR]\e[0m --expect requires a non-empty option argument."
                    return 1
                fi
                ;;
            -H|--header)
                if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                    if [[ ! "$2" =~ ^[^:]+:[[:space:]]*[^[:space:]]+.*$ ]]; then
                        echo -e "\e[31m[ERROR]\e[0m Invalid header format: '$2'. Expected 'Key: Value'"
                        return 1
                    fi
                    HEADERS+=("$2")
                    shift 2
                else
                    echo -e "\e[31m[ERROR]\e[0m --header requires a non-empty option argument."
                    return 1
                fi
                ;;
            -t|--timeout)
                if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                    if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                        echo -e "\e[31m[ERROR]\e[0m Timeout must be a positive integer."
                        return 1
                    fi
                    TIMEOUT="$2"
                    shift 2
                else
                    echo -e "\e[31m[ERROR]\e[0m --timeout requires a non-empty option argument."
                    return 1
                fi
                ;;
            -*)
                echo -e "\e[31m[ERROR]\e[0m Unknown option: $1"
                print_help
                return 1
                ;;
            *)
                URLS+=("$1")
                shift
                ;;
        esac
    done

    # Validate URLs provided
    if [[ ${#URLS[@]} -eq 0 ]]; then
        echo -e "\e[31m[ERROR]\e[0m No URLs provided."
        print_help
        return 1
    fi

    return 0
}

#######################################
# Main execution function.
# Arguments:
#   Command line arguments
# Returns:
#   0 if all checks passed, 1 if any failed
#######################################
apihealth_main() {
    if ! check_dependencies; then
        return 1
    fi

    if ! parse_arguments "$@"; then
        return 1
    fi

    local overall_status=0

    for url in "${URLS[@]}"; do
        if ! apihealthealth "$url" "$METHOD" "$EXPECT_STATUS" "$TIMEOUT"; then
            overall_status=1
        fi
        echo "----------------------------------------"
    done

    if [[ "$overall_status" -eq 0 ]]; then
        echo -e "\e[32mAll API health checks passed successfully.\e[0m"
    else
        echo -e "\e[31mSome API health checks failed.\e[0m"
    fi

    return "$overall_status"
}

# Define the function for sourcing
apihealth() {
    apihealth_main "$@"
}