#!/usr/bin/env bash
# Version Synchronization Script
# Synchronizes version numbers across all markdown files with package.json
# Used by CI/CD and available for local testing

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION_PATTERN='[0-9]+\.[0-9]+\.[0-9]+'
BACKUP_DIR="$PROJECT_ROOT/.version-sync-backup"
EXCLUDE_FILES=(
  "CHANGELOG.md"
  "docs/COMPLIANCE.md"
  "docs/FONTS.md"
  "docs/LEGACY_ROADMAP.md"
  "docs/PLAN.md"
  "docs/VERSION_SYNC.md"
  "docs/WALKTHROUGH.md"
  "docs/WSL2_NIX_TROUBLESHOOTING.md"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

show_help() {
  cat << EOF
Version Synchronization Script

USAGE:
  $0 [OPTIONS] [VERSION]

OPTIONS:
  -h, --help        Show this help message
  -d, --dry-run     Show what would be changed without making changes
  -v, --verify      Verify version consistency without updating
  -b, --backup      Create backup before changes (default: true)
  --no-backup       Skip creating backup
  -f, --force       Force sync even if no changes detected

ARGUMENTS:
  VERSION          Target version to sync to (defaults to package.json version)

EXAMPLES:
  $0                    # Sync to current package.json version
  $0 1.2.3             # Sync all files to version 1.2.3
  $0 --dry-run         # Preview changes without applying
  $0 --verify          # Check current version consistency

DESCRIPTION:
  This script synchronizes version numbers across all markdown files in the
  repository with the version specified in package.json. It updates various
  version reference patterns including badges, documentation headers, and
  feature version stamps.

EOF
}

is_excluded_file() {
  local file="$1"
  local excluded
  for excluded in "${EXCLUDE_FILES[@]}"; do
    if [[ "$file" == "$excluded" ]]; then
      return 0
    fi
  done
  return 1
}

get_package_version() {
  local package_file="$PROJECT_ROOT/package.json"
  if [[ ! -f "$package_file" ]]; then
    log_error "package.json not found at $package_file"
    exit 1
  fi

  local version
  version=$(jq -r '.version' "$package_file" 2>/dev/null)
  if [[ "$version" == "null" || -z "$version" ]]; then
    log_error "Could not extract version from package.json"
    exit 1
  fi

  echo "$version"
}

validate_version() {
  local version="$1"
  if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid version format: $version (expected: x.y.z)"
    exit 1
  fi
}

find_version_files() {
  local temp_file
  temp_file=$(mktemp)

  log_info "Scanning for markdown files with version references..."

  # Find all markdown files with version patterns
  cd "$PROJECT_ROOT"
  rg -l "v?$VERSION_PATTERN" --type md > "$temp_file" 2>/dev/null || true

  # Add known files that should be checked even if they don't have versions yet
  echo "README.md" >> "$temp_file"
  echo "docs/FEATURES.md" >> "$temp_file"

  # Remove duplicates and filter existing files
  sort -u "$temp_file" | while IFS= read -r file; do
    if [[ -f "$file" ]]; then
      if is_excluded_file "$file"; then
        continue
      fi
      echo "$file"
    fi
  done

  rm -f "$temp_file"
}

create_backup() {
  local files=("$@")

  if [[ ${#files[@]} -eq 0 ]]; then
    log_warning "No files to backup"
    return
  fi

  log_info "Creating backup in $BACKUP_DIR"
  rm -rf "$BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"

  local backup_count=0
  for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
      local backup_name
      backup_name="$(basename "$file").$(date +%Y%m%d_%H%M%S).backup"
      cp "$file" "$BACKUP_DIR/$backup_name"
      backup_count=$((backup_count + 1))
    fi
  done

  log_success "Backed up $backup_count files"
}

update_version_references() {
  local target_version="$1"
  local dry_run="$2"
  local files=("${@:3}")

  local changes_made=0
  local files_processed=0

  for file in "${files[@]}"; do
    if [[ ! -f "$file" ]]; then
      log_warning "File not found: $file"
      continue
    fi

    files_processed=$((files_processed + 1))
    log_info "Processing: $file"

    # Create temporary file for changes
    local temp_file
    temp_file=$(mktemp)
    cp "$file" "$temp_file"

    # Update various version reference patterns
    case "$(basename "$file")" in
      "README.md")
        # Update version badge specifically
        sed -i "s|Version-v$VERSION_PATTERN|Version-v$target_version|g" "$temp_file"
        ;;
      *)
        # Update general patterns in other files
        sed -i \
          -e "s|Version.*v$VERSION_PATTERN|Version**: v$target_version|g" \
          -e "s|Dotfiles Version.*v$VERSION_PATTERN|Dotfiles Version**: v$target_version|g" \
          -e "s|\*\*Version\*\*:.*v$VERSION_PATTERN|**Version**: v$target_version|g" \
          -e "s|version.*$VERSION_PATTERN|version $target_version|g" \
          "$temp_file"
        ;;
    esac

    # Check if file was changed
    if ! cmp -s "$file" "$temp_file"; then
      if [[ "$dry_run" == "true" ]]; then
        log_info "Would update: $file"
        # Show diff preview
        diff -u "$file" "$temp_file" | head -20 || true
      else
        mv "$temp_file" "$file"
        log_success "Updated: $file"
      fi
      changes_made=$((changes_made + 1))
    else
      log_info "No changes needed: $file"
      rm -f "$temp_file"
    fi
  done

  if [[ "$dry_run" == "true" ]]; then
    log_info "Dry run complete - $changes_made files would be updated out of $files_processed processed"
  else
    log_success "Updated $changes_made files out of $files_processed processed"
  fi

  return $changes_made
}

verify_version_consistency() {
  local expected_version="$1"
  local files=("${@:2}")

  log_info "Verifying version consistency (expected: v$expected_version)"

  local inconsistencies=0
  local total_checked=0

  for file in "${files[@]}"; do
    if [[ ! -f "$file" ]]; then
      continue
    fi

    total_checked=$((total_checked + 1))

    # Extract all version references from the file
    local versions_in_file
    mapfile -t versions_in_file < <(rg -o "v?$VERSION_PATTERN" "$file" | sort -u)

    for version in "${versions_in_file[@]}"; do
      # Remove 'v' prefix if present for comparison
      local clean_version="${version#v}"
      if [[ "$clean_version" != "$expected_version" ]]; then
        log_error "Inconsistent version in $file: $version (expected: v$expected_version)"
        inconsistencies=$((inconsistencies + 1))
      fi
    done
  done

  if [[ $inconsistencies -eq 0 ]]; then
    log_success "All version references are consistent: v$expected_version (checked $total_checked files)"
    return 0
  else
    log_error "Found $inconsistencies inconsistent version references"
    return 1
  fi
}

main() {
  local target_version=""
  local dry_run="false"
  local verify_only="false"
  local create_backup_flag="true"
  local force_sync="false"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_help
        exit 0
        ;;
      -d|--dry-run)
        dry_run="true"
        shift
        ;;
      -v|--verify)
        verify_only="true"
        shift
        ;;
      -b|--backup)
        create_backup_flag="true"
        shift
        ;;
      --no-backup)
        create_backup_flag="false"
        shift
        ;;
      -f|--force)
        force_sync="true"
        shift
        ;;
      -*)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
      *)
        target_version="$1"
        shift
        ;;
    esac
  done

  # Change to project root
  cd "$PROJECT_ROOT"

  # Determine target version
  if [[ -z "$target_version" ]]; then
    target_version=$(get_package_version)
    log_info "Using package.json version: $target_version"
  else
    validate_version "$target_version"
    log_info "Using specified version: $target_version"
  fi

  # Find files with version references
  local version_files
  readarray -t version_files < <(find_version_files)

  if [[ ${#version_files[@]} -eq 0 ]]; then
    log_warning "No files with version references found"
    exit 0
  fi

  log_info "Found ${#version_files[@]} files with version references"

  # Verify mode - just check consistency
  if [[ "$verify_only" == "true" ]]; then
    if verify_version_consistency "$target_version" "${version_files[@]}"; then
      exit 0
    else
      exit 1
    fi
  fi

  # Create backup if requested and not dry run
  if [[ "$create_backup_flag" == "true" && "$dry_run" == "false" ]]; then
    create_backup "${version_files[@]}"
  fi

  # Update version references
  if update_version_references "$target_version" "$dry_run" "${version_files[@]}"; then
    local changes_made=$?

    if [[ $changes_made -gt 0 || "$force_sync" == "true" ]]; then
      if [[ "$dry_run" == "false" ]]; then
        # Verify the changes
        if verify_version_consistency "$target_version" "${version_files[@]}"; then
          log_success "Version synchronization completed successfully"

          # Show summary
          cat << EOF

═══════════════════════════════════════
Version Sync Summary
═══════════════════════════════════════
Target Version: v$target_version
Files Updated:  $changes_made
Backup Created: $create_backup_flag
Verification:   ✅ Passed

EOF
        else
          log_error "Version synchronization failed verification"
          exit 1
        fi
      fi
    else
      log_info "No changes needed - all versions are already synchronized"
    fi
  else
    log_error "Version synchronization failed"
    exit 1
  fi
}

# Ensure we have required tools
if ! command -v jq &> /dev/null; then
  log_error "jq is required but not installed"
  exit 1
fi

if ! command -v rg &> /dev/null; then
  log_error "ripgrep (rg) is required but not installed"
  exit 1
fi

# Run main function
main "$@"
