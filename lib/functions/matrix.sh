#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Matrix Effect Generator (matrix)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   matrix is a utility function to generate Matrix-style effects in the terminal
#   with customizable colors. It supports multiple color themes and a rainbow
#   effect option.
#
################################################################################

# Define colors
MATRIX_GREEN='\033[38;5;46m'    # Green (#00FF00)
MATRIX_PURPLE='\033[38;5;55m'   # Purple (#2D1681)
MATRIX_RED='\033[38;5;196m'     # Red (#EB0000)
MATRIX_BLUE='\033[38;5;33m'     # Blue (#007ACC)
MATRIX_WHITE='\033[38;5;15m'    # White (#FFFFFF)
MATRIX_YELLOW='\033[38;5;226m'  # Yellow
RESET_COLOR='\033[0m'

VERSION="1.0.0"

# Logging functions
log_info() {
  echo "[INFO] $*"
}

log_warning() {
  echo "[WARNING] $*" >&2
}

log_error() {
  echo "[ERROR] $*" >&2
  exit 1
}

show_help() {
  cat << 'EOH'
🅳🅾🆃🅵🅸🅻🅴🆂 - Matrix Effect Generator (matrix)

Description:
  Generate Matrix-style effects in the terminal with customizable colors.
  Supports multiple color themes and a rainbow effect option.

Usage:
  matrix [options]
  matrix --help

Options:
  --color <name>       Select color theme:
                        green   - Classic green (default)
                        purple  - Purple (#2D1681)
                        red     - Red (#EB0000)
                        blue    - Blue (#007ACC)
                        white   - White (#FFFFFF)
                        yellow  - Yellow
  --rainbow            Enable rainbow color effect
  --slow               Reduce animation speed
  --fast               Increase animation speed
  --help               Display this help menu and exit
  --version            Display version information and exit

Examples:
  matrix
      # Classic green Matrix effect

  matrix --color purple
      # Purple Matrix effect

  matrix --rainbow
      # Rainbow color effect

  matrix --color blue --slow
      # Slow blue Matrix effect

Notes:
  - Press Ctrl+C to exit
  - Animation speed can be adjusted with --slow or --fast
  - Terminal size is automatically detected
  - Minimum terminal size required: 20x10
  - Colors can be customized by modifying the color variables
EOH
}

show_version() {
  echo "Matrix Effect Generator v${VERSION}"
}

cleanup() {
  printf '\e[?25h'  # Show cursor
  tput rmcup        # Restore screen
  tput cnorm        # Show cursor
  clear
  exit 0
}

matrix() {
  # Check for help and version flags before parsing options
  if [[ "$1" == "--help" ]]; then
    show_help
    return 0
  elif [[ "$1" == "--version" ]]; then
    show_version
    return 0
  fi

  # Check terminal size
  if [[ "${LINES:-0}" -lt 10 || "${COLUMNS:-0}" -lt 20 ]]; then
    log_error "Terminal window too small. Minimum size: 20x10"
  fi

  # Default settings
  local color="$MATRIX_GREEN"
  local speed=0.05
  local rainbow=false

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --color)
        case "$2" in
          green) color="$MATRIX_GREEN" ;;
          purple) color="$MATRIX_PURPLE" ;;
          red) color="$MATRIX_RED" ;;
          blue) color="$MATRIX_BLUE" ;;
          white) color="$MATRIX_WHITE" ;;
          yellow) color="$MATRIX_YELLOW" ;;
          *) log_error "Invalid color: '$2'. Use 'matrix --help' for available colors." ;;
        esac
        shift 2
        ;;
      --rainbow)
        rainbow=true
        shift
        ;;
      --slow)
        speed=0.1
        shift
        ;;
      --fast)
        speed=0.02
        shift
        ;;
      --help)
        show_help
        return 0
        ;;
      --version)
        show_version
        return 0
        ;;
      *)
        log_error "Unknown option: '$1'. Use 'matrix --help' for usage information."
        ;;
    esac
  done

  # Save screen state and hide cursor
  tput smcup
  printf '\e[?25l'
  printf '\e[1;40m'
  clear

  # Trap cleanup for exit signals
  trap cleanup INT TERM EXIT

  if $rainbow; then
    # Rainbow effect
    while true; do
      echo "${LINES:-40} ${COLUMNS:-80} $((RANDOM % COLUMNS)) $((RANDOM % 72))"
      sleep "$speed"
    done | awk -v reset="$RESET_COLOR" '
    {
      letters="日ﾊﾐﾋｰｳｼﾅﾐﾆｻﾜﾂｵﾘｱﾎﾃﾏｹﾒｴｶｷﾑﾕﾗｾﾈｽﾀﾇﾍ";
      c=$4;
      if (c <= 0 || c > length(letters)) next;
      letter=substr(letters, c, 1);
      a[$3] = 0;
      for (x in a) {
        o = a[x];
        a[x] = a[x] + 1;
        random_color = "\033[38;5;" int(rand() * 255) "m";
        if (o > 0 && x > 0) {
          printf "\033[%s;%sH%s%s%s", o, x, random_color, letter, reset;
          printf "\033[%s;%sH%s%s%s", a[x], x, reset, letter, reset;
        }
        if (a[x] >= $1) a[x] = 0;
      }
    }'
  else
    # Single color effect
    while true; do
      echo "${LINES:-40} ${COLUMNS:-80} $((RANDOM % COLUMNS)) $((RANDOM % 72))"
      sleep "$speed"
    done | awk -v color="$color" -v reset="$RESET_COLOR" '
    {
      letters="日ﾊﾐﾋｰｳｼﾅﾐﾆｻﾜﾂｵﾘｱﾎﾃﾏｹﾒｴｶｷﾑﾕﾗｾﾈｽﾀﾇﾍ";
      c=$4;
      if (c <= 0 || c > length(letters)) next;
      letter=substr(letters, c, 1);
      a[$3] = 0;
      for (x in a) {
        o = a[x];
        a[x] = a[x] + 1;
        if (o > 0 && x > 0) {
          printf "\033[%s;%sH%s%s%s", o, x, color, letter, reset;
          printf "\033[%s;%sH%s%s%s", a[x], x, reset, letter, reset;
        }
        if (a[x] >= $1) a[x] = 0;
      }
    }'
  fi
}
