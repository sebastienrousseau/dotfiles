#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Host Information Viewer (hostinfo)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   hostinfo is a utility function to display detailed information about the
#   current host in a structured table format. This includes system stats,
#   network configuration, and public-facing IP address.
#
# Usage:
#   hostinfo
#   hostinfo --help
#
# Arguments:
#   --help      Displays this help menu and exits.
#
# Examples:
#   hostinfo
#       # Displays detailed host information in a table format.
#
#   hostinfo --help
#       # Displays the help menu.
#
################################################################################

hostinfo() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    echo "hostinfo: Host Information Viewer"
    echo
    echo "Usage:"
    echo "  hostinfo"
    echo "  hostinfo --help"
    echo
    echo "Arguments:"
    echo "  --help      Displays this help menu and exits."
    echo
    echo "Examples:"
    echo "  hostinfo"
    echo "      # Displays detailed host information in a table format."
    echo
    echo "  hostinfo --help"
    echo "      # Displays the help menu."
    echo
    return 0
  fi

  # Fetch host information
  local username
  local hostname
  local system_info
  local users_logged_on
  local current_date
  local machine_stats
  local network_location="Not available"
  local public_ip="Not available"
  local dns_config="Not available"

  username=$(whoami)
  hostname=$(hostname)
  system_info=$(uname -a)
  users_logged_on=$(w -h | awk '{print $1}' | sort | uniq | paste -sd ", " -)
  current_date=$(date)
  machine_stats=$(uptime | sed 's/^ *//')

  # Check if scselect is available (macOS specific)
  if command -v scselect &>/dev/null; then
    network_location=$(scselect | grep '^ *\*' | sed 's/^ *\* //')
  fi

  # Fetch public IP address using a reliable service
  if command -v curl &>/dev/null; then
    public_ip=$(curl -s https://api.ipify.org || echo "Not available")
  elif command -v wget &>/dev/null; then
    public_ip=$(wget -qO- https://api.ipify.org || echo "Not available")
  fi

  # Fetch DNS configuration (macOS specific)
  if command -v scutil &>/dev/null; then
    dns_config=$(scutil --dns | awk '/nameserver/ {print $3}' | paste -sd ", " -)
  fi

  # Display information in a table format
  echo "====================================="
  printf "%-25s : %s\n" "Username" "$username"
  printf "%-25s : %s\n" "Hostname" "$hostname"
  printf "%-25s : %s\n" "System Information" "$system_info"
  printf "%-25s : %s\n" "Users Logged On" "${users_logged_on:-None}"
  printf "%-25s : %s\n" "Current Date" "$current_date"
  printf "%-25s : %s\n" "Machine Stats" "$machine_stats"
  printf "%-25s : %s\n" "Network Location" "$network_location"
  printf "%-25s : %s\n" "Public IP Address" "$public_ip"
  printf "%-25s : %s\n" "DNS Servers" "${dns_config:-None}"
  echo "====================================="
}
