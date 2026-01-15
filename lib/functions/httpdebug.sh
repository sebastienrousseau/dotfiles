#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - HTTP Debugging Utility (httpdebug)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   httpdebug is a utility function to debug HTTP requests by measuring the
#   timing of various stages of the request process in milliseconds. This
#   includes DNS lookup, connection establishment, SSL handshake, and total
#   request time. It also provides details like the server IP address.
#
# Usage:
#   httpdebug [options] [url]
#   httpdebug --help
#
# Arguments:
#   options     Additional curl options (optional).
#   url         The URL to debug.
#   --help      Displays this help menu and exits.
#
# Examples:
#   httpdebug https://example.com
#       # Debugs the HTTP request to https://example.com and displays timing info.
#
#   httpdebug -v https://example.com
#       # Debugs the HTTP request with verbose output from curl.
#
#   httpdebug --help
#       # Displays the help menu.
#
################################################################################

httpdebug() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    echo "httpdebug: HTTP Debugging Utility"
    echo
    echo "Usage:"
    echo "  httpdebug [options] [url]"
    echo "  httpdebug --help"
    echo
    echo "Arguments:"
    echo "  options     Additional curl options (optional)."
    echo "  url         The URL to debug."
    echo "  --help      Displays this help menu and exits."
    echo
    echo "Examples:"
    echo "  httpdebug https://example.com"
    echo "      # Debugs the HTTP request to https://example.com and displays timing info."
    echo
    echo "  httpdebug -v https://example.com"
    echo "      # Debugs the HTTP request with verbose output from curl."
    echo
    echo "  httpdebug --help"
    echo "      # Displays the help menu."
    echo
    return 0
  fi

  # Ensure curl is available
  if ! command -v curl &>/dev/null; then
    echo "[ERROR] 'curl' command is required but not installed. Please install it and try again." >&2
    return 1
  fi

  # Check if a URL or options are provided
  if [[ -z "$1" ]]; then
    echo "[ERROR] No URL provided. Use 'httpdebug --help' for usage information." >&2
    return 1
  fi

  # Perform HTTP request and measure timing
  echo "[INFO] Debugging HTTP request to: ${*}"
  curl_output=$(/usr/bin/curl "$@" -o /dev/null -s -w "\
IP Address: %{remote_ip}\n\
DNS Lookup: %{time_namelookup}\n\
TCP Connection: %{time_connect}\n\
SSL Handshake: %{time_appconnect}\n\
Server Processing: %{time_pretransfer}\n\
Time to First Byte: %{time_starttransfer}\n\
Total Time: %{time_total}\n")

  # Display results in a clean table format
  printf "%-25s %-25s %-45s\n" "Metric" "Details" "Description"
  printf "%-25s %-25s %-45s\n" "------------------------" "------------------------" "---------------------------------------------"

  echo "$curl_output" | while IFS= read -r line; do
    metric=$(echo "$line" | awk -F: '{print $1}')
    value=$(echo "$line" | awk -F: '{print $2}' | xargs)
    description=""

    case "$metric" in
      "IP Address") description="IP address of the server" ;;
      "DNS Lookup") description="Time to resolve the domain name to an IP address" ;;
      "TCP Connection") description="Time to establish a TCP connection to the server" ;;
      "SSL Handshake") description="Time to complete the SSL/TLS handshake (if applicable)" ;;
      "Server Processing") description="Time from connection to server readiness to transfer data" ;;
      "Time to First Byte") description="Time until the first byte of the response is received" ;;
      "Total Time") description="Total time for the request, including all stages" ;;
    esac

    if [[ "$metric" == "IP Address" ]]; then
      printf "%-25s %-25s %-45s\n" "$metric" "$value" "$description"
    else
      # Convert time values to milliseconds for consistency
      time_in_milliseconds=$(awk "BEGIN {printf \"%.2f\", $value * 1000}")
      printf "%-25s %-25s %-45s\n" "$metric" "$time_in_milliseconds ms" "$description"
    fi
  done
}

