#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.

set -euo pipefail

# =============================================================================
# Kiro CLI Installation Script
# =============================================================================

# Configuration
BINARY_NAME="kiro-cli"
CHAT_BINARY_NAME="kiro-cli-chat"
LINUX_PACKAGE_NAME="kirocli"
CLI_NAME="Kiro CLI"
COMMAND_NAME="kiro-cli"
Q_COMMAND="q"
Q_COMMAND_PATH="$HOME/.local/bin/q"
SCRIPT_URL="https://cli.kiro.dev/install"
BASE_URL="https://desktop-release.q.us-east-1.amazonaws.com"
MANIFEST_URL="${BASE_URL}/latest/manifest.json"
MACOS_FILENAME="Kiro CLI.dmg"
MACOS_FILENAME_ESCAPED="Kiro%20CLI.dmg"

# Installation directories
MACOS_APP_DIR="/Applications"
LINUX_INSTALL_DIR="$HOME/.local/bin"
DOWNLOAD_DIR=""  # Will be set using mktemp in main()

# Global variables
use_musl=false
mounted_dmg=""
SUCCESS=false
force_install=false

# Set color codes if outputting to a terminal
GREEN='' BOLD='' PURPLE='' ORANGE='' NC=''
if [[ -t 1 ]]; then
    GREEN=$(printf '\033[0;32m')
    BOLD=$(printf '\033[1m')
    PURPLE=$(printf '\033[0;95m')
    ORANGE=$(printf '\033[38;5;214m')
    NC=$(printf '\033[0m')
fi

# =============================================================================
# Utility Functions
# =============================================================================

log_info() {
    printf "%s\n" "$1" >&2
}

log() {
    printf "%s✓%s %s\n" "$GREEN" "$NC" "$1" >&2
}

print_header() {
    echo "Kiro CLI installer:" >&2
    echo >&2
}

success() {
    echo >&2
    printf "🎉 %sInstallation complete!%s Happy coding!\n" "$BOLD" "$NC" >&2
    echo >&2
    echo "Next steps:"
    printf "Use the command \"%s%s%s\" to get started!\n" "$PURPLE" "$COMMAND_NAME" "$NC" >&2
    echo >&2
}

success_without_path() {
    echo >&2
    printf "🎉 %sInstallation complete!%s Happy coding!\n" "$BOLD" "$NC" >&2
    echo >&2
    printf "1. %sImportant!%s Before you can continue, you must update your PATH to include:\n" "$ORANGE" "$NC" >&2
    printf "   %s\n" "$HOME/.local/bin" >&2
    echo >&2
    echo "Add it to your PATH by adding this line to your shell configuration file:" >&2
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\"" >&2
    echo >&2
    printf "2. Use the command \"%s%s%s\" to get started!\n" "$PURPLE" "$COMMAND_NAME" "$NC" >&2
    echo >&2
}

error() {
    echo "❌ $1" >&2
    exit 1
}

warning() {
    echo "⚠️ $1" >&2
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --force|-f)
                force_install=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
}

show_help() {
    cat << EOF
$CLI_NAME Installation Script

Usage: $0 [OPTIONS]

Options:
    --help, -h     Show this help message

This script will:
1. Detect your platform and architecture
2. Download the appropriate $CLI_NAME package
3. Verify checksums
4. Install $CLI_NAME on your system
5. If Amazon Q CLI is already installed, automatically update it to Kiro CLI

For more information, visit: https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-installing.html
EOF
}

# Check for required dependencies
check_dependencies() {

    local missing_deps=()

    # Check for downloader
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        missing_deps+=("curl or wget")
    fi

    # Check for unzip on Linux
    if [[ "$os" == "linux" ]] && ! command -v unzip >/dev/null 2>&1; then
        missing_deps+=("unzip")
    fi

    # Check for shasum/sha256sum
    if [[ "$os" == "darwin" ]] && ! command -v shasum >/dev/null 2>&1; then
        missing_deps+=("shasum")
    elif [[ "$os" == "linux" ]] && ! command -v sha256sum >/dev/null 2>&1; then
        missing_deps+=("sha256sum")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing required dependencies: ${missing_deps[*]}"
    fi
}

# Check if Amazon Q CLI is already installed
check_existing_installation() {
    if [[ "$force_install" == "true" ]]; then
        return 0
    fi

    # Check if q command exists anywhere in PATH or in standard locations
    local user_q_location
    user_q_location=$(command -v "$Q_COMMAND" 2>/dev/null || true)

    if [[ -z "$user_q_location" ]]; then
        # q not in PATH, check standard installation locations
        if [[ -x "$Q_COMMAND_PATH" ]]; then
            user_q_location="$Q_COMMAND_PATH"
        fi
    fi

    if [[ -z "$user_q_location" ]]; then
        # q not found, proceed with installation
        return 0
    fi

    log_info "Detected existing Amazon Q CLI installation"
    log_info "Kiro CLI is the new version of Amazon Q CLI. Updating to latest version."
    echo

    # Resolve one level of symlink if it exists
    local user_real_q_location="$user_q_location"
    if [[ -L "$user_q_location" ]]; then
        user_real_q_location=$(readlink "$user_q_location")
    fi

    # Determine if the binary is in an updatable location
    local is_updatable=false

    # Check for Linux: ~/.local/bin/q
    if [[ "$user_real_q_location" == "$Q_COMMAND_PATH" ]]; then
        is_updatable=true
    fi
    # Check for macOS: /Applications
    if [[ "$user_real_q_location" == /Applications/* ]]; then
        is_updatable=true
    fi

    if [[ "$is_updatable" == "true" ]]; then
        if "$user_q_location" update; then
            echo
            success
            SUCCESS=true
            exit 0
        else
            echo
            error "Q CLI update failed. Please run 'q update' manually, or uninstall Q CLI and rerun this script to install $CLI_NAME."
        fi
    else
        echo
        # q exists but not in ~/.local/bin
        warning "Q CLI at $user_real_q_location does not support auto-update. Please uninstall it and rerun this script to install $CLI_NAME."
        exit 1
    fi
}

# Download function that works with both curl and wget
download_file() {
    local url="$1"
    local output="${2:-}"

    if command -v curl >/dev/null 2>&1; then
        if [[ -n "$output" ]]; then
            curl -fsSL -o "$output" "$url" || error "Failed to download $url"
        else
            curl -fsSL "$url" || error "Failed to download $url"
        fi
    elif command -v wget >/dev/null 2>&1; then
        if [[ -n "$output" ]]; then
            wget -q -O "$output" "$url" || error "Failed to download $url"
        else
            wget -q -O - "$url" || error "Failed to download $url"
        fi
    else
        error "No downloader available"
    fi
}

# Get checksum from manifest.json
get_checksum() {
    local json="$1"
    local filename="$2"

    if command -v jq >/dev/null 2>&1; then
        # Use jq to find the package with matching download filename
        echo "$json" | jq -r ".packages[] | select(.download | endswith(\"$filename\")) | .sha256 // empty"
    else
        # Fallback: parse JSON manually
        # Normalize to single line
        local package_obj
        package_obj=$(echo "$json" | tr -d '\n\r' | grep -o '{[^}]*"download"[^}]*'"$filename"'[^}]*}')

        if [[ -n "$package_obj" ]]; then
            if [[ $package_obj =~ \"sha256\"[[:space:]]*:[[:space:]]*\"([a-f0-9]{64})\" ]]; then
                echo "${BASH_REMATCH[1]}"
                return 0
            fi
        fi

        return 1
    fi
}

# =============================================================================
# Platform Detection
# =============================================================================

detect_platform() {
    case "$(uname -s)" in
        Darwin) os="darwin" ;;
        Linux) os="linux" ;;
        *) error "Unsupported operating system: $(uname -s)" ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64) arch="x86_64" ;;
        arm64|aarch64) arch="aarch64" ;;
        *) error "Unsupported architecture: $(uname -m)" ;;
    esac
}

# Minimum required glibc version
GLIBC_MIN_MAJOR=2
GLIBC_MIN_MINOR=34

# Check if a glibc version meets the minimum requirement
is_glibc_version_sufficient() {
    local version="$1"
    local major minor

    IFS='.' read -r major minor <<EOF
$version
EOF
    if [[ -z "$minor" ]]; then
        minor=0
    fi

    if (( major > GLIBC_MIN_MAJOR || (major == GLIBC_MIN_MAJOR && minor >= GLIBC_MIN_MINOR) )); then
        return 0
    else
        return 1
    fi
}

# Check glibc version for Linux
check_glibc() {
    if [[ "$os" != "linux" ]]; then
        return 0
    fi

    local glibc_version

    # Method 1: Try common libc.so.6 locations
    for LIBC_PATH in /lib64/libc.so.6 /lib/libc.so.6 /usr/lib/x86_64-linux-gnu/libc.so.6 \
        /lib/aarch64-linux-gnu/libc.so.6; do
        if [[ -f "$LIBC_PATH" ]]; then
            glibc_version=$("$LIBC_PATH" | sed -n 's/^GNU C Library (.*) stable release version \([0-9]*\)\.\([0-9]*\).*$/\1.\2/p')
            if [[ -n "$glibc_version" ]]; then
                if is_glibc_version_sufficient "$glibc_version"; then
                    return 0
                else
                    use_musl=true
                    return 0
                fi
            fi
        fi
    done

    # Method 2: Try ldd --version as a more reliable alternative
    if command -v ldd >/dev/null 2>&1; then
        glibc_version=$(ldd --version 2>/dev/null | head -n 1 | grep -o '[0-9]\+\.[0-9]\+' | head -n 1)
        if [[ -n "$glibc_version" ]]; then
            if is_glibc_version_sufficient "$glibc_version"; then
                return 0
            else
                use_musl=true
                return 0
            fi
        fi
    fi

    # Method 3: Try getconf as a fallback
    if command -v getconf >/dev/null 2>&1; then
        glibc_version=$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')
        if [[ -n "$glibc_version" ]]; then
            if is_glibc_version_sufficient "$glibc_version"; then
                return 0
            else
                use_musl=true
                return 0
            fi
        fi
    fi

    # Check for musl directly
    if [[ -f /lib/libc.musl-x86_64.so.1 ]] || [[ -f /lib/libc.musl-aarch64.so.1 ]] || \
       ldd /bin/ls 2>&1 | grep -q musl; then
        use_musl=true
        return 0
    fi

    use_musl=true
    return 0
}

# =============================================================================
# Download and Installation Functions
# =============================================================================

# Download and verify file
download_and_verify() {
    local download_url="$1"
    local filename="$2"

    local file_path="$DOWNLOAD_DIR/$filename"

    download_file "$download_url" "$file_path"

    local manifest_json
    manifest_json=$(download_file "$MANIFEST_URL")

    local expected_checksum
    expected_checksum=$(get_checksum "$manifest_json" "$filename")

    if [[ -z "$expected_checksum" ]] || [[ ! "$expected_checksum" =~ ^[a-f0-9]{64}$ ]]; then
        error "Could not find valid checksum for $filename"
    fi

    local actual_checksum
    if [[ "$os" == "darwin" ]]; then
        actual_checksum=$(shasum -a 256 "$file_path" | cut -d' ' -f1)
    else
        actual_checksum=$(sha256sum "$file_path" | cut -d' ' -f1)
    fi

    if [[ "$actual_checksum" != "$expected_checksum" ]]; then
        rm -f "$file_path"
        error "Checksum verification failed. Expected: $expected_checksum, Got: $actual_checksum"
    fi
}


# Install on macOS
install_macos() {
    local dmg_path="$1"
    if [[ ! -f "$dmg_path" ]]; then
        error "DMG file not found: $dmg_path"
    fi

    local mount_path
    mount_path=$(hdiutil attach "$dmg_path" -nobrowse -readonly | grep Volumes | cut -f 3)
    if [[ -z "$mount_path" ]]; then
        error "Failed to mount DMG"
    fi
    mounted_dmg="$mount_path"

    # Find the .app bundle
    local app_bundle
    app_bundle=$(find "$mount_path" -name "*.app" -maxdepth 1 -type d | head -1)

    if [[ -z "$app_bundle" ]]; then
        error "Could not find application bundle in DMG"
    fi

    local app_name
    app_name=$(basename "$app_bundle")

    # Check if app already exists and warn user
    if [[ -d "$MACOS_APP_DIR/$app_name" ]]; then
        warning "Existing $CLI_NAME installation found"
        echo "Do you want to replace it? (y/N): "
        read -r response < /dev/tty
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            error "Installation cancelled by user"
        fi
        rm -rf "$MACOS_APP_DIR/$app_name"
        log "Existing installation removed"
    fi

    # Use ditto instead of cp for better handling of extended attributes and resource forks
    if ! ditto "$app_bundle" "$MACOS_APP_DIR/$app_name"; then
        error "Failed to copy application bundle to $MACOS_APP_DIR"
    fi

    open -g -a "$MACOS_APP_DIR/$app_name" --args --no-dashboard
    sleep 3
}

# Install on Linux
install_linux() {
    local zip_path="$1"
    local extract_dir="$DOWNLOAD_DIR/extract"
    mkdir -p "$extract_dir"

    # Check if binary already exists and warn user
    if [[ -f "$LINUX_INSTALL_DIR/$BINARY_NAME" ]]; then
        warning "Existing $CLI_NAME installation found"
        echo "Do you want to replace it? (y/N): "
        read -r response < /dev/tty
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            error "Installation cancelled by user"
        fi
        rm -f "$LINUX_INSTALL_DIR/$BINARY_NAME"
        rm -f "$LINUX_INSTALL_DIR/$CHAT_BINARY_NAME"
        log "Existing installation removed"
    fi

    unzip -q "$zip_path" -d "$extract_dir"

    # Find and run the install script
    local install_script="$extract_dir/${LINUX_PACKAGE_NAME}/install.sh"

    if [[ ! -f "$install_script" ]]; then
        error "Install script not found in archive"
    fi

    chmod +x "$install_script"
    KIRO_CLI_SKIP_SETUP=1 "$install_script"
}

# Cleanup function - removes temporary download directory
cleanup() {
    if [ "$SUCCESS" = false ]; then
        error "Installation failed. Cleaning up..."
    fi

    # Detach mounted DMG if any
    if [[ -n "$mounted_dmg" ]]; then
        hdiutil detach "$mounted_dmg" -quiet 2>/dev/null || true
    fi

    # Remove entire download directory
    if [[ -n "$DOWNLOAD_DIR" ]] && [[ -d "$DOWNLOAD_DIR" ]]; then
        rm -rf "$DOWNLOAD_DIR"
    fi
}

# =============================================================================
# Main Installation Process
# =============================================================================

main() {
    # Parse command line arguments
    parse_args "$@"

    print_header

    # Check if already installed (unless --force is used)
    check_existing_installation

    # Set up cleanup trap
    trap cleanup EXIT

    # Create temporary download directory
    DOWNLOAD_DIR=$(mktemp -d "${TMPDIR:-/tmp}/${BINARY_NAME}-install-XXXXXX")

    # Platform detection and validation
    detect_platform
    check_dependencies
    check_glibc

    # Get download information
    local download_url filename
    if [[ "$os" == "darwin" ]]; then
        filename="$MACOS_FILENAME"
        download_url="${BASE_URL}/latest/${MACOS_FILENAME_ESCAPED}"
    else
        # Linux
        if [[ "$use_musl" == "true" ]]; then
            filename="${LINUX_PACKAGE_NAME}-${arch}-linux-musl.zip"
        else
            filename="${LINUX_PACKAGE_NAME}-${arch}-linux.zip"
        fi
        download_url="${BASE_URL}/latest/$filename"
    fi

    # Download and verify
    log_info "Downloading package..."
    download_and_verify "$download_url" "$filename"
    local downloaded_file="$DOWNLOAD_DIR/$filename"
    log "Downloaded and extracted"


    # Install based on platform
    if [[ "$os" == "darwin" ]]; then
        install_macos "$downloaded_file"
    else
        install_linux "$downloaded_file"
    fi

    log "Package installed successfully"

    SUCCESS=true


    # Check if ~/.local/bin is on PATH and show appropriate success message
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        success_without_path
    else
        success
    fi
}

# Run main function
main "$@"
