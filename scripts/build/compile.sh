#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# Script directory detection for relative path resolution
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default variables
DIST_DIR="./dist"
JS_FILES=(
  "./bin/backup.js"
  "./bin/constants.js"
  "./bin/copy.js"
  "./bin/dotfiles.js"
  "./bin/download.js"
  "./bin/index.js"
  "./bin/transfer.js"
  "./bin/unpack.js"
)

# Check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check required dependencies
check_dependencies() {
  local missing_deps=()

  if ! command_exists jsmin; then
    missing_deps+=("jsmin")
  fi

  if ! command_exists rimraf; then
    missing_deps+=("rimraf")
  fi

  if ! command_exists filesizes; then
    missing_deps+=("filesizes")
  fi

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo -e "${RED}Error: Missing required dependencies:${NC}"
    for dep in "${missing_deps[@]}"; do
      echo -e "  - ${dep}"
    done
    echo ""
    echo -e "Please install the missing dependencies and try again."
    return 1
  fi

  return 0
}

# Copy directory and show status
copy_dir() {
  local src="$1"
  local dest="$2"
  local name="$3"

  echo -e "${GREEN}  ✔${NC} Copying ${name}."
  if [[ ! -d "$src" ]]; then
    echo -e "${YELLOW}  ⚠${NC} Source directory not found: ${src}"
    return 1
  fi

  mkdir -p "${dest%/*}" # Ensure parent directory exists
  cp -R "$src" "$dest"

  if [[ $? -ne 0 ]]; then
    echo -e "${RED}  ✘${NC} Failed to copy ${name}."
    return 1
  fi

  return 0
}

# Copy file and show status
copy_file() {
  local src="$1"
  local dest="$2"
  local name="$3"

  echo -e "${GREEN}  ✔${NC} Copying ${name}."
  if [[ ! -f "$src" ]]; then
    echo -e "${YELLOW}  ⚠${NC} Source file not found: ${src}"
    return 1
  fi

  mkdir -p "${dest%/*}" # Ensure parent directory exists
  cp -f "$src" "$dest"

  if [[ $? -ne 0 ]]; then
    echo -e "${RED}  ✘${NC} Failed to copy ${name}."
    return 1
  fi

  return 0
}

# Compress JavaScript files
compress_js() {
  echo -e "${GREEN}  ✔${NC} Compressing JavaScript files."

  local success_count=0
  local fail_count=0

  for js_file in "${JS_FILES[@]}"; do
    local basename=$(basename "$js_file")
    local dest_file="${DIST_DIR}/bin/${basename}"

    if [[ ! -f "$js_file" ]]; then
      echo -e "${YELLOW}  ⚠${NC} JavaScript file not found: ${js_file}"
      ((fail_count++))
      continue
    fi

    echo -e "${CYAN}    → ${NC} Compressing ${basename}"
    jsmin "$js_file" > "$dest_file"

    if [[ $? -eq 0 ]]; then
      ((success_count++))
    else
      echo -e "${RED}  ✘${NC} Failed to compress: ${js_file}"
      ((fail_count++))
    fi
  done

  echo -e "${GREEN}    ✔${NC} Compressed ${success_count} JavaScript files."
  if [[ $fail_count -gt 0 ]]; then
    echo -e "${YELLOW}    ⚠${NC} Failed to compress ${fail_count} JavaScript files."
  fi

  return $fail_count
}

## 🅲🅾🅼🅿🅸🅻🅴 🅳🅾🆃🅵🅸🅻🅴🆂 - Compile dotfiles.
compile() {
  echo ""
  echo -e "${RED}❭${NC} Starting Compilation."
  echo ""

  # Try to import constants if they exist
  if [[ -f "${SCRIPT_DIR}/lib/configurations/default/constants.sh" ]]; then
    # shellcheck disable=SC1090
    source "${SCRIPT_DIR}/lib/configurations/default/constants.sh" 2>/dev/null
  fi

  # Check for required dependencies
  if ! check_dependencies; then
    return 1
  fi

  # Ensure dist directory exists
  mkdir -p "$DIST_DIR"
  if [[ $? -ne 0 ]]; then
    echo -e "${RED}  ✘${NC} Failed to create distribution directory."
    return 1
  fi

  # Copy directories
  copy_dir "./lib" "${DIST_DIR}/lib" "libraries" || { echo -e "${RED}  ✘${NC} Compilation aborted."; return 1; }
  copy_dir "./scripts" "${DIST_DIR}/scripts" "scripts" || { echo -e "${RED}  ✘${NC} Compilation aborted."; return 1; }
  copy_dir "./bin" "${DIST_DIR}/bin" "JavaScript binaries" || { echo -e "${RED}  ✘${NC} Compilation aborted."; return 1; }

  # Copy files
  copy_file "./Makefile" "${DIST_DIR}/Makefile" "Makefile" || { echo -e "${RED}  ✘${NC} Compilation aborted."; return 1; }

  # Remove temporary files
  echo -e "${GREEN}  ✔${NC} Removing temporary files."
  rimraf "${DIST_DIR}/lib/**/*.tmp"
  if [[ $? -ne 0 ]]; then
    echo -e "${YELLOW}  ⚠${NC} Failed to remove some temporary files."
  fi

  # Compress JavaScript files
  compress_js
  local compress_result=$?

  # Generate file sizes
  echo -e "${GREEN}  ✔${NC} Determining the file sizes."
  filesizes "${DIST_DIR}/" > "${DIST_DIR}/filesizes.txt"
  if [[ $? -ne 0 ]]; then
    echo -e "${YELLOW}  ⚠${NC} Failed to generate file sizes."
  fi

  echo ""
  if [[ $compress_result -eq 0 ]]; then
    echo -e "${GREEN}❭${NC} Compilation completed successfully."
  else
    echo -e "${YELLOW}❭${NC} Compilation completed with some warnings."
  fi
  echo ""

  return $compress_result
}

# Process command line arguments
case "$1" in
  compile)
    compile
    exit $?
    ;;
  help|--help|-h)
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  compile    Compile the dotfiles distribution package"
    echo "  help       Display this help message"
    echo ""
    ;;
  "")
    echo "No command specified. Use '$0 help' for usage information."
    ;;
  *)
    echo "Unknown command: $1"
    echo "Use '$0 help' for usage information."
    ;;
esac
