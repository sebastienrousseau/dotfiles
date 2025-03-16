#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Cross-Platform Caffeine Utility (caffeine)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   caffeine is a cross-platform utility to prevent the system from going to
#   sleep or displaying a screensaver. It supports macOS, Linux, and Windows.
#
# Usage:
#   caffeine daemon      Start the caffeine daemon (creates a lockfile)
#   caffeine status      Check if the daemon is running and active
#   caffeine query       Same as status, but returns exit code instead of printing
#   caffeine start       Start keeping the screen awake
#   caffeine stop        Stop keeping the screen awake
#   caffeine toggle      Toggle keeping the screen awake
#   caffeine shutdown    Completely shut down the caffeine daemon
#   caffeine diagnostic  Show diagnostic information
#   caffeine version     Show version information
#   caffeine help        Show this help message
#
################################################################################

# Constants
CAFFEINE_VERSION="0.1.0"
CAFFEINE_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/caffeine"
CAFFEINE_LOCKFILE="${CAFFEINE_CONFIG_DIR}/caffeine.lock"
CAFFEINE_STATEFILE="${CAFFEINE_CONFIG_DIR}/caffeine.state"

# Detect OS
caffeine_detect_os() {
  case "$(uname -s)" in
    Darwin*)
      echo "macos"
      ;;
    Linux*)
      echo "linux"
      ;;
    CYGWIN*|MINGW*|MSYS*)
      echo "windows"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

OS=$(caffeine_detect_os)

# Ensure config directory exists
caffeine_ensure_config_dir() {
  if [[ ! -d "$CAFFEINE_CONFIG_DIR" ]]; then
    mkdir -p "$CAFFEINE_CONFIG_DIR"
  fi
}

# Log messages
caffeine_log_info() {
  echo "[INFO] $*"
}

caffeine_log_error() {
  echo "[ERROR] $*" >&2
}

caffeine_log_warning() {
  echo "[WARNING] $*" >&2
}

# Check if daemon is running
caffeine_check_daemon() {
  if [[ ! -f "$CAFFEINE_LOCKFILE" ]]; then
    return 1
  fi

  local pid
  pid=$(cat "$CAFFEINE_LOCKFILE" 2>/dev/null)

  if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
    caffeine_log_warning "Stale lockfile found. Removing..."
    rm -f "$CAFFEINE_LOCKFILE"
    return 1
  fi

  return 0
}

# Start caffeine daemon specific to OS
caffeine_start_daemon() {
  caffeine_ensure_config_dir

  # Check if daemon is already running
  if [[ -f "$CAFFEINE_LOCKFILE" ]]; then
    local pid
    pid=$(cat "$CAFFEINE_LOCKFILE" 2>/dev/null)

    if kill -0 "$pid" 2>/dev/null; then
      caffeine_log_info "Caffeine daemon is already running (PID: $pid)"
      return 0
    else
      caffeine_log_warning "Stale lockfile found. Removing..."
      rm -f "$CAFFEINE_LOCKFILE"
    fi
  fi

  # Start daemon based on OS
  case "$OS" in
    macos)
      # Daemon isn't needed on macOS as we can use caffeinate directly
      caffeine_log_info "Using native caffeinate on macOS - no separate daemon needed"
      touch "$CAFFEINE_LOCKFILE"
      echo "$$" > "$CAFFEINE_LOCKFILE"
      ;;
    linux)
      (
        # Fork a background process
        touch "$CAFFEINE_LOCKFILE"
        echo "$$" > "$CAFFEINE_LOCKFILE"
        touch "$CAFFEINE_STATEFILE"
        echo "inactive" > "$CAFFEINE_STATEFILE"

        # Monitor for state changes
        while true; do
          if [[ -f "$CAFFEINE_STATEFILE" ]]; then
            current_state=$(cat "$CAFFEINE_STATEFILE")
            if [[ "$current_state" == "active" ]]; then
              # Keep inhibiting screen sleep while in active state
              if command -v xdg-screensaver &>/dev/null; then
                xdg-screensaver reset
              fi
              if command -v xset &>/dev/null; then
                xset s reset
              fi
              sleep 30  # Reset every 30 seconds
            else
              # Just wait for state to change
              sleep 5
            fi
          else
            # Statefile was removed, exit
            break
          fi
        done

        # Clean up if daemon is stopped
        rm -f "$CAFFEINE_LOCKFILE" "$CAFFEINE_STATEFILE"
      ) &
      disown
      caffeine_log_info "Caffeine daemon started (PID: $!)"
      ;;
    windows)
      (
        # Fork a background PowerShell script
        touch "$CAFFEINE_LOCKFILE"
        echo "$$" > "$CAFFEINE_LOCKFILE"
        touch "$CAFFEINE_STATEFILE"
        echo "inactive" > "$CAFFEINE_STATEFILE"

        # Monitor for state changes using PowerShell in the background
        while true; do
          if [[ -f "$CAFFEINE_STATEFILE" ]]; then
            current_state=$(cat "$CAFFEINE_STATEFILE")
            if [[ "$current_state" == "active" ]]; then
              # Send a keypress to prevent sleep (F15 is typically unused)
              powershell.exe -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('{F15}')" &>/dev/null
              sleep 60  # Send key every 60 seconds
            else
              # Just wait for state to change
              sleep 5
            fi
          else
            # Statefile was removed, exit
            break
          fi
        done

        # Clean up if daemon is stopped
        rm -f "$CAFFEINE_LOCKFILE" "$CAFFEINE_STATEFILE"
      ) &
      disown
      caffeine_log_info "Caffeine daemon started (PID: $!)"
      ;;
    *)
      caffeine_log_error "Unsupported operating system"
      return 1
      ;;
  esac

  return 0
}

# Stop caffeine daemon
caffeine_shutdown_daemon() {
  # First stop any active caffeine process
  caffeine_stop_caffeine

  # Then check if daemon is running
  if ! caffeine_check_daemon; then
    caffeine_log_warning "Caffeine daemon is not running"
    return 1
  fi

  # Get daemon PID
  local pid
  pid=$(cat "$CAFFEINE_LOCKFILE" 2>/dev/null)

  # Kill the daemon process
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
    caffeine_log_info "Caffeine daemon stopped (PID: $pid)"

    # Remove lockfile and statefile
    rm -f "$CAFFEINE_LOCKFILE" "$CAFFEINE_STATEFILE"
    return 0
  else
    caffeine_log_warning "Could not stop daemon process, removing lockfile"
    rm -f "$CAFFEINE_LOCKFILE" "$CAFFEINE_STATEFILE"
    return 1
  fi
}

# Check if caffeine is active
caffeine_check_active() {
  if [[ ! -f "$CAFFEINE_STATEFILE" ]]; then
    return 1
  fi

  # For macOS, check if the process is still running
  if [[ "$OS" == "macos" ]]; then
    local pid
    pid=$(cat "$CAFFEINE_STATEFILE" 2>/dev/null)
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      # Process is running
      return 0
    else
      # Process not running, update state file
      echo "inactive" > "$CAFFEINE_STATEFILE"
      return 1
    fi
  else
    # For other systems, check the state file
    local state
    state=$(cat "$CAFFEINE_STATEFILE" 2>/dev/null)

    if [[ "$state" == "active" ]]; then
      return 0
    else
      return 1
    fi
  fi
}

# Start keeping screen awake
caffeine_start_caffeine() {
  caffeine_ensure_config_dir

  # First make sure daemon is running
  if ! caffeine_check_daemon; then
    caffeine_log_info "Daemon not running. Starting daemon first..."
    caffeine_start_daemon
  fi

  # Start based on OS
  case "$OS" in
    macos)
      # If an existing caffeinate process is running, kill it
      if [[ -f "$CAFFEINE_STATEFILE" ]]; then
        local pid
        pid=$(cat "$CAFFEINE_STATEFILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
          kill "$pid" 2>/dev/null
        fi
      fi

      # Start a new caffeinate process with appropriate flags
      # -d: prevent display from sleeping
      # -i: prevent system from idle sleeping
      # -s: prevent system from sleeping
      /usr/bin/caffeinate -d -i -s &
      local pid="$!"

      # Verify process started successfully
      if kill -0 "$pid" 2>/dev/null; then
        echo "$pid" > "$CAFFEINE_STATEFILE"
        caffeine_log_info "Screen will stay awake (PID: $pid)"
      else
        caffeine_log_error "Failed to start caffeinate process"
        return 1
      fi
      ;;
    linux|windows)
      echo "active" > "$CAFFEINE_STATEFILE"
      caffeine_log_info "Screen will stay awake"
      ;;
    *)
      caffeine_log_error "Unsupported operating system"
      return 1
      ;;
  esac

  return 0
}

# Stop keeping screen awake
caffeine_stop_caffeine() {
  # Check if caffeine is active
  case "$OS" in
    macos)
      if [[ -f "$CAFFEINE_STATEFILE" ]]; then
        local pid
        pid=$(cat "$CAFFEINE_STATEFILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
          kill "$pid" 2>/dev/null
          caffeine_log_info "Screen can now sleep (stopped PID: $pid)"
        else
          caffeine_log_warning "No active caffeinate process found"
        fi
        echo "inactive" > "$CAFFEINE_STATEFILE"
      else
        caffeine_log_warning "Caffeine is not active"
      fi
      ;;
    linux|windows)
      if [[ -f "$CAFFEINE_STATEFILE" ]]; then
        echo "inactive" > "$CAFFEINE_STATEFILE"
        caffeine_log_info "Screen can now sleep"
      else
        caffeine_log_warning "Caffeine is not active"
      fi
      ;;
    *)
      caffeine_log_error "Unsupported operating system"
      return 1
      ;;
  esac

  return 0
}

# Toggle caffeine state
caffeine_toggle_caffeine() {
  if caffeine_check_active; then
    caffeine_stop_caffeine
  else
    caffeine_start_caffeine
  fi
}

# Show status
caffeine_show_status() {
  if ! caffeine_check_daemon; then
    caffeine_log_info "Caffeine daemon is not running"
    return 1
  fi

  if caffeine_check_active; then
    caffeine_log_info "Caffeine daemon is running and keeping the screen awake"
    return 0
  else
    caffeine_log_info "Caffeine daemon is running but not keeping the screen awake"
    return 2
  fi
}

# Query status (exit code only)
caffeine_query_status() {
  if ! caffeine_check_daemon; then
    return 1  # Daemon not running
  fi

  if caffeine_check_active; then
    return 0  # Active
  else
    return 2  # Inactive
  fi
}

# Show diagnostic information
caffeine_show_diagnostic() {
  echo "Caffeine Diagnostic Information"
  echo "==============================="
  echo "Version: $CAFFEINE_VERSION"
  echo "Operating System: $OS"
  echo "Config Directory: $CAFFEINE_CONFIG_DIR"

  echo -n "Daemon Status: "
  if caffeine_check_daemon; then
    local pid
    pid=$(cat "$CAFFEINE_LOCKFILE" 2>/dev/null)
    echo "Running (PID: $pid)"
  else
    echo "Not Running"
  fi

  echo -n "Caffeine State: "
  if caffeine_check_active; then
    case "$OS" in
      macos)
        local pid
        pid=$(cat "$CAFFEINE_STATEFILE" 2>/dev/null)
        echo "Active (PID: $pid)"
        ;;
      *)
        echo "Active"
        ;;
    esac
  else
    echo "Inactive"
  fi

  echo "Dependencies:"
  case "$OS" in
    macos)
      echo "  caffeinate: $(command -v /usr/bin/caffeinate &>/dev/null && echo "Found" || echo "Not Found")"
      ;;
    linux)
      echo "  xdg-screensaver: $(command -v xdg-screensaver &>/dev/null && echo "Found" || echo "Not Found")"
      echo "  xset: $(command -v xset &>/dev/null && echo "Found" || echo "Not Found")"
      ;;
    windows)
      echo "  PowerShell: $(command -v powershell.exe &>/dev/null && echo "Found" || echo "Not Found")"
      ;;
  esac

  echo "==============================="
}

# Show usage/help
caffeine_show_help() {
  cat << EOF
Caffeine - Prevent your system from sleeping

Usage:
  caffeine <command>

Commands:
  daemon      Start the caffeine daemon (creates a lockfile)
  status      Check if the daemon is running and active
  query       Same as status, but returns exit code instead of printing
  start       Start keeping the screen awake
  stop        Stop keeping the screen awake
  toggle      Toggle keeping the screen awake
  shutdown    Completely shut down the caffeine daemon
  diagnostic  Show diagnostic information
  version     Show version information
  help        Show this help message

Exit Codes (for query):
  0   Daemon is running and keeping screen awake
  1   Daemon is not running
  2   Daemon is running but not keeping screen awake
EOF
}

# Show version
caffeine_show_version() {
  echo "Caffeine version $CAFFEINE_VERSION"
}

# Main function
caffeine() {
  # If no arguments provided, show usage
  if [[ $# -eq 0 ]]; then
    caffeine_show_help
    return 0
  fi

  case "$1" in
    daemon|--daemon|-d)
      caffeine_start_daemon
      ;;
    status|--status|-s)
      caffeine_show_status
      ;;
    query|--query|-q)
      caffeine_query_status
      ;;
    start|--start)
      caffeine_start_caffeine
      ;;
    stop|--stop)
      caffeine_stop_caffeine
      ;;
    toggle|--toggle|-t)
      caffeine_toggle_caffeine
      ;;
    shutdown|--shutdown)
      caffeine_shutdown_daemon
      ;;
    diagnostic|--diagnostic|-D)
      caffeine_show_diagnostic
      ;;
    version|--version|-v)
      caffeine_show_version
      ;;
    help|--help|-h)
      caffeine_show_help
      ;;
    *)
      caffeine_log_error "Unknown command: $1"
      caffeine_show_help
      return 1
      ;;
  esac
}

# If script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  caffeine "$@"
fi
