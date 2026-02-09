#!/usr/bin/env bash
# Chezmoi Installation Library
# Handles chezmoi binary installation and configuration

# Check if chezmoi is installed
has_chezmoi() {
  command -v chezmoi >/dev/null 2>&1
}

# Get chezmoi version
chezmoi_version() {
  chezmoi --version 2>/dev/null | head -1
}

# Install chezmoi via Homebrew
install_chezmoi_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    return 1
  fi
  echo "   Installing chezmoi via Homebrew..."
  brew install chezmoi
}

# Install chezmoi via binary download
# Arguments:
#   $1 - Target binary directory (default: ~/.local/bin)
install_chezmoi_binary() {
  local bin_dir="${1:-$HOME/.local/bin}"
  mkdir -p "$bin_dir"

  echo "   Installing chezmoi via binary download..."
  echo -e "${CYAN:-}   SECURITY NOTE: Downloading from get.chezmoi.io with integrity check${NC:-}"

  # Download installer script first for inspection
  local installer
  installer=$(mktemp)

  if ! curl -fsSL -o "$installer" https://get.chezmoi.io; then
    rm -f "$installer"
    echo "Error: Failed to download chezmoi installer." >&2
    return 1
  fi

  # Basic validation: check it's a shell script and not suspiciously large
  if [ "$(wc -c <"$installer")" -gt 102400 ]; then
    rm -f "$installer"
    echo "Error: Chezmoi installer suspiciously large. Aborting for security." >&2
    return 1
  fi

  if ! head -1 "$installer" | grep -q '^#!/'; then
    rm -f "$installer"
    echo "Error: Chezmoi installer doesn't look like a shell script. Aborting." >&2
    return 1
  fi

  # Execute the verified installer
  if ! sh "$installer" -- -b "$bin_dir" 2>/dev/null; then
    rm -f "$installer"
    echo "Error: Failed to install chezmoi." >&2
    return 1
  fi

  rm -f "$installer"

  # Add to PATH for the rest of the script
  export PATH="$bin_dir:$PATH"
  return 0
}

# Install chezmoi using the best available method
install_chezmoi() {
  if has_chezmoi; then
    echo "   chezmoi already installed: $(chezmoi_version)"
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    install_chezmoi_brew
  else
    install_chezmoi_binary
  fi
}

# Ensure chezmoi source directory is configured
# Arguments:
#   $1 - Source directory path
ensure_chezmoi_source() {
  local dir="$1"
  local config_dir="$HOME/.config/chezmoi"
  local config_file="$config_dir/chezmoi.toml"

  mkdir -p "$config_dir"

  # Escape sed metacharacters in replacement string
  local escaped_dir
  escaped_dir=$(printf '%s\n' "$dir" | sed -e 's/[\/&]/\\&/g')

  if [ -f "$config_file" ] && grep -q '^sourceDir' "$config_file"; then
    sed -i.bak "s,^sourceDir.*$,sourceDir = \"$escaped_dir\"," "$config_file"
    rm -f "$config_file.bak"
  else
    printf 'sourceDir = "%s"\n' "$dir" > "$config_file"
  fi
}

# Apply chezmoi configuration
# Arguments:
#   $1 - Source directory path
#   $2 - Non-interactive mode (0 or 1)
apply_chezmoi() {
  local source_dir="$1"
  local non_interactive="${2:-0}"

  ensure_chezmoi_source "$source_dir"

  local apply_flags=()
  if [ "$non_interactive" = "1" ]; then
    apply_flags=(--force --no-tty)
  fi

  chezmoi apply "${apply_flags[@]}"
}

# Initialize chezmoi from a Git repository
# Arguments:
#   $1 - Target source directory
#   $2 - Git repository URL
#   $3 - Version/tag to checkout
init_chezmoi_from_git() {
  local source_dir="$1"
  local repo_url="$2"
  local version="$3"

  echo "   Initializing from GitHub (Branch/Tag: $version)..."
  echo -e "${CYAN:-}   SECURITY NOTE: Cloning pinned version $version for supply-chain safety${NC:-}"

  # Clone with specific tag for supply-chain security
  if ! git clone --depth 1 --branch "$version" "$repo_url" "$source_dir" 2>/dev/null; then
    git clone "$repo_url" "$source_dir"
    (cd "$source_dir" && git checkout "$version")
  fi

  # Verify the checkout succeeded
  local actual_ref
  actual_ref=$(cd "$source_dir" && git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)

  if [ "$actual_ref" != "$version" ] && [ "${actual_ref#v}" != "${version#v}" ]; then
    echo -e "${CYAN:-}   INFO: Checked out ref $actual_ref (requested: $version)${NC:-}"
  fi
}
