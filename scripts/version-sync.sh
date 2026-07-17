#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Version Synchronization Script
# Synchronizes version numbers across all markdown files with package.json
# Used by CI/CD and available for local testing

set -euo pipefail

_cleanup_files=()
trap 'set +u; rm -f "${_cleanup_files[@]}" 2>/dev/null; set -u' EXIT

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION_PATTERN='[0-9]+\.[0-9]+\.[0-9]+'
SED_VERSION_PATTERN='[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*'
BACKUP_DIR="$PROJECT_ROOT/.version-sync-backup"
EXCLUDE_FILES=(
  # Historical / referential docs — version refs inside are intentional
  # pointers at prior versions, not "this is the current version" claims.
  "CHANGELOG.md"
  "docs/security/COMPLIANCE.md"
  "docs/reference/FONTS.md"
  "docs/archive/LEGACY_ROADMAP.md"
  "docs/archive/PLAN.md"

  # Roadmap + audit narratives — describe per-version work; refs to
  # prior versions are intentional and historical.
  "docs/operations/ROADMAP_V0_2_503.md"
  "docs/operations/VERSION_SYNC.md"
  "docs/operations/RFC_v0_2_503_reorganization.md"
  "docs/operations/HARD_AUDIT_2026.md"
  "docs/reference/ALIASES_DEPRECATIONS.md"

  # Security docs — INSTALL_VERIFICATION + CI_PINNING + SCORECARD
  # carry per-release hash tables / closed-cycle logs. The "current"
  # version inside these is tracked by hand, not by version-sync.
  "docs/security/CI_PINNING.md"
  "docs/security/INSTALL_VERIFICATION.md"
  "docs/security/SCORECARD.md"

  # Release-verification recipes use an example pinned tag
  # that intentionally stays at a known-published release.
  "docs/security/VERIFY_RELEASE.md"

  # Example bundles — version refs in README'd examples are illustrative.
  "examples/mise-plugin-dot/README.md"

  # MANIFEST + MIGRATION docs — describe per-version manifests &
  # cross-version migration paths; intentional references to other tags.
  "docs/operations/MANIFEST.md"
  "docs/operations/MIGRATION.md"

  # ADR + architecture + manual + operations narratives — every
  # version reference inside is dated context, not a "current version"
  # claim. The single source-of-truth is .chezmoidata.toml (plus
  # README, package.json — which version-sync DOES rewrite).
  "docs/adr/ADR-007-multi-shell-parity.md"
  "docs/architecture/REPO_LAYOUT.md"
  "docs/manual/01-concepts/04-fleet.md"
  "docs/manual/01-concepts/05-self-healing.md"
  "docs/manual/02-tutorials/05-deploy-fleet.md"
  "docs/manual/05-appendices/D-bibliography.md"
  "docs/operations/MAINTENANCE.md"

  # Release-process / structural docs that reference *historical* dotfiles
  # versions (the repo reorg, past release tags, migration scenarios).
  # Bumping these each release would corrupt accurate history.
  "docs/operations/RELEASE_PIPELINE.md"
  "docs/operations/TESTING.md"
  "docs/STRUCTURE.md"
  "install/migrate/README.md"
  "install/README.md"
  "tools/README.md"
  "defaults/README.md"

  # CI_COMPOSITES.md cites third-party action versions (e.g. v5.0.5),
  # not dotfiles_version. False-positive pattern match.
  "docs/operations/CI_COMPOSITES.md"

  # Living roadmap: references branch names / target versions
  # (e.g. feature-branch names like feat/v0.2.X, phase milestones)
  # that are NOT the current dotfiles_version. Auto-syncing
  # rewrites them incorrectly.
  "docs/operations/ARCHITECTURE_ROADMAP.md"

  # Dated release write-ups: each article records the release it
  # shipped in (e.g. "shipped in vX.Y.Z" + a link to that release
  # tag). Those refs are historical fact, not current-version claims —
  # bumping them would falsify the history.
  "docs/articles/2026-07-05-fish-startup-abbr.md"
  "docs/articles/2026-07-05-master-to-main-rename-runbook.md"
)

# shellcheck source=../lib/dot/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/dot/ui.sh"
ui_init

# Functions — delegate to shared ui.sh (redirect to stderr for script output)
log_info() { ui_info "$@" >&2; }
log_success() { ui_ok "$@" >&2; }
log_warning() { ui_warn "$@" >&2; }
log_error() { ui_err "$@" >&2; }

show_help() {
  cat <<EOF
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
  temp_file=$(umask 077 && mktemp)

  log_info "Scanning for markdown files with version references..."

  # Find all markdown files with version patterns.
  # The "." path is required: with no path and a non-TTY stdin (CI, pipes,
  # background jobs) rg reads from stdin instead of searching the tree, so
  # the whole script hangs forever. The `sed` strips rg's leading "./" so
  # the paths match the EXCLUDE_FILES entries (which have no "./"),
  # otherwise excluded historical docs get rewritten.
  cd "$PROJECT_ROOT"
  rg -l "v?$VERSION_PATTERN" --type md . 2>/dev/null | sed 's|^\./||' >"$temp_file" || true

  # Add known files that should be checked even if they don't have versions yet
  echo "README.md" >>"$temp_file"
  echo "docs/reference/FEATURES.md" >>"$temp_file"
  echo "docs/COPYRIGHT" >>"$temp_file"

  # Non-markdown and hidden-directory surfaces rg's `--type md` scan above
  # cannot reach: a shell script, and READMEs under the dotfile-hidden
  # `.chezmoitemplates/` tree (rg skips dot-dirs without --hidden). These
  # carry "current version" stamps that check-version-consistency.sh and
  # the test_version_consistency unit test enforce, so keep them in sync.
  echo "scripts/git-hooks/pre-commit-audit.sh" >>"$temp_file"
  echo "defaults/.chezmoitemplates/README.md" >>"$temp_file"
  echo "defaults/.chezmoitemplates/functions/README.md" >>"$temp_file"
  echo "defaults/.chezmoitemplates/aliases/README.md" >>"$temp_file"

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

sed_in_place() {
  local file="$1"
  shift

  if sed --version >/dev/null 2>&1; then
    sed -E -i "$@" "$file"
  else
    sed -E -i '' "$@" "$file"
  fi
}

# LCOV_EXCL_START — rm -rf BACKUP_DIR + cp of real release files;
# only run during a real release flow, not safe under coverage.
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
# LCOV_EXCL_STOP

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

    # Skip milestone and other historical files
    if [[ "$(basename "$file")" == MILESTONE_* ]]; then
      log_info "Skipping historical file: $file"
      continue
    fi

    # Create temporary file for changes
    local temp_file
    temp_file=$(umask 077 && mktemp)
    cp "$file" "$temp_file"

    # Update various version reference patterns. Match on the full repo
    # path (not basename) so the root README's badge rules don't also
    # capture other README.md files (e.g. the .chezmoitemplates READMEs),
    # which carry a `(vX.Y.Z)` stamp handled by the generic case below.
    case "$file" in
      "README.md")
        # Update badge and release link versions.
        sed_in_place "$temp_file" \
          -e "s|Version-v$SED_VERSION_PATTERN|Version-v$target_version|g" \
          -e "s|/releases/tag/v$SED_VERSION_PATTERN|/releases/tag/v$target_version|g" \
          -e "s|/dotfiles/v$SED_VERSION_PATTERN/|/dotfiles/v$target_version/|g"
        ;;
      "scripts/git-hooks/pre-commit-audit.sh")
        # "vX.Y.Z standards maintained" banner. Matched explicitly with a
        # portable pattern — the generic `\bvX.Y.Z\b` rule below relies on
        # GNU `\b`, which BSD/macOS sed does not support, so a local
        # `version-sync` run would otherwise leave this script stale.
        sed_in_place "$temp_file" \
          -e "s|v$SED_VERSION_PATTERN standards maintained|v$target_version standards maintained|g"
        ;;
      *)
        # Update explicit markdown version labels, backticks, and parentheses.
        # Skip lines containing MILESTONE.
        sed_in_place "$temp_file" \
          -e "/MILESTONE/!s|(\*\*Version\*\*:[[:space:]]*)v?$SED_VERSION_PATTERN|\\1v$target_version|g" \
          -e "/MILESTONE/!s|(\*\*Dotfiles Version\*\*:[[:space:]]*)v?$SED_VERSION_PATTERN|\\1v$target_version|g" \
          -e "/MILESTONE/!s|(Version:[[:space:]]*)v?$SED_VERSION_PATTERN|\\1v$target_version|g" \
          -e "/MILESTONE/!s|(Dotfiles Version:[[:space:]]*)v?$SED_VERSION_PATTERN|\\1v$target_version|g" \
          -e "/MILESTONE/!s|Version[[:space:]]*\`v?$SED_VERSION_PATTERN\`|Version \`$target_version\`|g" \
          -e "/MILESTONE/!s|\(v$SED_VERSION_PATTERN\)|\(v$target_version\)|g" \
          -e "/MILESTONE/!s|/v$SED_VERSION_PATTERN/|/v$target_version/|g" \
          -e "/MILESTONE/!s|\bv$SED_VERSION_PATTERN\b|v$target_version|g" \
          -e "/MILESTONE/!s|dotfiles:v?$SED_VERSION_PATTERN|dotfiles:$target_version|g" \
          -e "/MILESTONE/!s|notes — v$SED_VERSION_PATTERN|notes — v$target_version|g"
        ;;
    esac

    # Check if file was changed
    if ! cmp -s "$file" "$temp_file"; then
      if [[ "$dry_run" == "true" ]]; then
        log_info "Would update: $file"
        # Show diff preview
        diff -u "$file" "$temp_file" | head -20 >&2 || true
      else
        # Use cat to preserve permissions and ownership
        cat "$temp_file" >"$file"
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

  echo "$changes_made"
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

    if [[ "$(basename "$file")" == MILESTONE_* ]]; then
      log_info "Skipping historical file: $file"
      continue
    fi

    total_checked=$((total_checked + 1))

    # Extract only dotfiles-targeted version references (ignore unrelated tool versions).
    local versions_in_file=()
    while IFS= read -r match; do
      while IFS= read -r version; do
        versions_in_file+=("$version")
      done < <(printf "%s\n" "$match" | rg -o "v?$VERSION_PATTERN" || true)
    done < <(
      rg -v "MILESTONE" "$file" 2>/dev/null | rg -o \
        -e "Version-v$VERSION_PATTERN" \
        -e "/releases/tag/v$VERSION_PATTERN" \
        -e "/dotfiles/v$VERSION_PATTERN/" \
        -e "\\*\\*Version\\*\\*:[[:space:]]*v?$VERSION_PATTERN" \
        -e "\\*\\*Dotfiles Version\\*\\*:[[:space:]]*v?$VERSION_PATTERN" \
        -e "(^|[[:space:]])Version:[[:space:]]*v?$VERSION_PATTERN" \
        -e "(^|[[:space:]])Dotfiles Version:[[:space:]]*v?$VERSION_PATTERN" \
        -e "Version[[:space:]]*\`v?$VERSION_PATTERN\`" \
        -e "\\(v$VERSION_PATTERN\\)" \
        -e "/v$VERSION_PATTERN/" \
        -e "v$VERSION_PATTERN\\b" \
        -e "dotfiles:v?$VERSION_PATTERN" \
        -e "notes — v$VERSION_PATTERN" || true
    )

    if [[ ${#versions_in_file[@]} -eq 0 ]]; then
      continue
    fi

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
      -h | --help)
        show_help
        exit 0
        ;;
      -d | --dry-run)
        dry_run="true"
        shift
        ;;
      -v | --verify)
        verify_only="true"
        shift
        ;;
      -b | --backup)
        create_backup_flag="true"
        shift
        ;;
      --no-backup)
        create_backup_flag="false"
        shift
        ;;
      -f | --force)
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

  # Sync chezmoidata.toml (single source of truth for template files).
  # Post-Phase-4b lives under defaults/ — kept old root location as a
  # fallback so this script is forward- and backward-compatible.
  local chezmoidata="$PROJECT_ROOT/defaults/.chezmoidata.toml"
  [[ -f "$chezmoidata" ]] || chezmoidata="$PROJECT_ROOT/.chezmoidata.toml"
  if [[ -f "$chezmoidata" ]]; then
    if [[ "$dry_run" == "true" ]]; then
      log_info "Would update ${chezmoidata#"$PROJECT_ROOT/"}: dotfiles_version = \"$target_version\""
    else
      sed_in_place "$chezmoidata" \
        "s|^dotfiles_version = \"$SED_VERSION_PATTERN\"|dotfiles_version = \"$target_version\"|"
      log_success "Updated ${chezmoidata#"$PROJECT_ROOT/"}"
    fi
  fi

  # Sync non-template script files that embed the version
  local script_files=(
    "bin/dot"
    "dot_local/bin/executable_tour"
    "install.sh"
  )
  for script_file in "${script_files[@]}"; do
    local full_path="$PROJECT_ROOT/$script_file"
    if [[ -f "$full_path" ]]; then
      local temp_file
      temp_file=$(umask 077 && mktemp)
      cp "$full_path" "$temp_file"
      sed_in_place "$temp_file" "s|v$SED_VERSION_PATTERN|v$target_version|g"
      sed_in_place "$temp_file" "s|\"$SED_VERSION_PATTERN\"|\"$target_version\"|g"
      if ! cmp -s "$full_path" "$temp_file"; then
        if [[ "$dry_run" == "true" ]]; then
          log_info "Would update: $script_file"
        else
          # Use cat to preserve permissions and ownership
          cat "$temp_file" >"$full_path"
          log_success "Updated: $script_file"
        fi
      else
        rm -f "$temp_file"
      fi
    fi
  done

  # Update version references
  local changes_made
  changes_made="$(update_version_references "$target_version" "$dry_run" "${version_files[@]}")"
  if [[ "$changes_made" =~ ^[0-9]+$ ]]; then

    if [[ $changes_made -gt 0 || "$force_sync" == "true" ]]; then
      if [[ "$dry_run" == "false" ]]; then
        # Verify the changes
        if verify_version_consistency "$target_version" "${version_files[@]}"; then
          log_success "Version synchronization completed successfully"

          # Show summary
          cat <<EOF

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
if ! command -v jq &>/dev/null; then
  log_warning "jq is not installed — skipping version sync"
  exit 0
fi

if ! command -v rg &>/dev/null; then
  log_warning "ripgrep (rg) is not installed — skipping version sync"
  exit 0
fi

# Run main function
main "$@"
