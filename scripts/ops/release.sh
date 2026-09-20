#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# =============================================================================
# Dotfiles Release Script
# Orchestrates a new release: version bump, changelog, tag, and push
# Usage: ./scripts/ops/release.sh [patch|minor] [--dry-run]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../lib/dot/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/ui.sh"
# shellcheck source=../../lib/dot/log.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/log.sh"
export DOT_COMMAND="release"
ui_init
BOLD="${BOLD:-}"
NC="${NC:-}"

log_info() { ui_info "$@"; }
log_success() { ui_ok "$@"; }
log_warn() { ui_warn "$@"; }
log_error() { ui_err "$@"; }
log_step() {
  echo ""
  ui_section "$*"
}

# Cross-platform sed in-place (BSD vs GNU)
sed_in_place() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@" # GNU
  else
    sed -i '' "$@" # BSD (macOS)
  fi
}

usage() {
  local current
  current=$(get_version)
  local next_patch
  next_patch=$(bump_version "$current" "patch")
  local next_minor
  next_minor=$(bump_version "$current" "minor")

  cat <<EOF
Dotfiles Release Tool

Usage: $(basename "$0") [BUMP_TYPE] [OPTIONS]

Bump Types:
  patch         Increment patch version ($current → $next_patch) [default]
  minor         Increment minor version ($current → $next_minor)

Options:
  -n, --dry-run   Show what would be done without making changes
  -h, --help      Show this help message

Steps performed:
  1. Verify clean working tree and up-to-date branch
  2. Update the canonical dotfiles_version and regenerate version surfaces
  3. Update CHANGELOG.md with new version header
  4. Create signed commit and tag
  5. Push commit and tag to origin

Examples:
  $(basename "$0")              # Patch release
  $(basename "$0") minor        # Minor release
  $(basename "$0") --dry-run    # Preview patch release

EOF
}

# Get the current version from the canonical chezmoi data manifest.
get_version() {
  sed -nE 's/^[[:space:]]*dotfiles_version[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' \
    "$PROJECT_ROOT/defaults/.chezmoidata.toml" | head -n 1
}

# Bump version string
bump_version() {
  local current="$1" bump_type="$2"
  local major minor patch
  IFS='.' read -r major minor patch <<<"$current"

  case "$bump_type" in
    patch) patch=$((patch + 1)) ;;
    minor)
      minor=$((minor + 1))
      patch=0
      ;;
    *)
      log_error "Unknown bump type: $bump_type"
      exit 1
      ;;
  esac

  echo "${major}.${minor}.${patch}"
}

main() {
  local bump_type="patch"
  local dry_run=0

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      patch | minor)
        bump_type="$1"
        shift
        ;;
      -n | --dry-run)
        dry_run=1
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done

  # Concurrency guard
  local lock_dir
  lock_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
  if [[ ! -d "$lock_dir" || ! -w "$lock_dir" ]]; then
    lock_dir="${TMPDIR:-/tmp}"
  fi
  LOCK_FILE="$lock_dir/dotfiles-release.lock"
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
      ui_warn "Already running" "Another release is in progress"
      exit 0
    fi
  fi

  cd "$PROJECT_ROOT"
  dot_log info "release_start" "bump_type=$bump_type"

  local current_version new_version
  current_version=$(get_version)
  if [[ ! "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid or missing canonical dotfiles_version: ${current_version:-<empty>}"
    exit 1
  fi
  new_version=$(bump_version "$current_version" "$bump_type")

  printf '%b\n' "${BOLD}Dotfiles Release${NC}"
  echo "  Current:  v${current_version}"
  echo "  Next:     v${new_version} (${bump_type})"
  echo ""

  if [[ "$dry_run" == "1" ]]; then
    log_warn "DRY-RUN MODE — no changes will be made"
    echo ""
  fi

  # ── Step 1: Preflight checks ─────────────────────────────────
  log_step "Preflight checks"

  if [[ -n "$(git status --porcelain)" ]]; then
    log_error "Working tree is not clean. Commit or stash changes first."
    exit 1
  fi
  log_success "Working tree clean"

  local branch
  branch=$(git branch --show-current)
  if [[ "$branch" != "master" && "$branch" != "main" ]]; then
    log_warn "On branch '$branch' — releases typically happen from master/main"
    read -rp "Continue anyway? [y/N] " response
    [[ "$response" =~ ^[Yy]$ ]] || exit 0
  fi
  log_success "On branch: $branch"

  git fetch origin "$branch" --quiet
  local behind
  behind=$(git rev-list --count "HEAD..origin/$branch" 2>/dev/null || echo "0")
  if [[ "$behind" -gt 0 ]]; then
    log_error "Branch is $behind commit(s) behind origin. Pull first."
    exit 1
  fi
  log_success "Branch is up to date with origin"

  if git show-ref --verify --quiet "refs/tags/v${new_version}"; then
    local existing_release_commit
    existing_release_commit="$(git rev-list -n 1 "v${new_version}")"
    log_error "Tag v${new_version} already exists at ${existing_release_commit}; release tags are immutable."
    exit 1
  fi
  log_success "Tag v${new_version} is available"

  if [[ "$dry_run" == "1" ]]; then
    log_step "Would perform the following"
    log_info "1. Set canonical dotfiles_version: $current_version → $new_version"
    log_info "2. Regenerate version surfaces with version-sync.sh"
    log_info "3. Add v${new_version} header to CHANGELOG.md"
    log_info "4. Commit: 'chore(release): v${new_version}'"
    log_info "5. Tag: v${new_version} (signed)"
    log_info "6. Push commit and tag to origin"
    echo ""
    log_success "Dry run complete"
    exit 0
  fi

  # ── Step 2: Update the canonical version and generated surfaces ─
  log_step "Update canonical version and regenerate release metadata"
  if [[ -x "$SCRIPT_DIR/../version-sync.sh" ]]; then
    bash "$SCRIPT_DIR/../version-sync.sh" --force "$new_version" 2>&1 | tail -3
    log_success "Canonical version and generated surfaces: $current_version → $new_version"
  else
    log_error "version-sync.sh not found"
    exit 1
  fi

  # ── Step 3: Update CHANGELOG ──────────────────────────────────
  log_step "Update CHANGELOG.md"
  local today
  today=$(date +%Y-%m-%d)
  local changelog="$PROJECT_ROOT/CHANGELOG.md"

  if [[ -f "$changelog" ]]; then
    # Insert new version header after the first "# Changelog" line
    sed_in_place "/^## v${current_version}/i\\
## v${new_version} (${today})\\
\\
### Changed\\
\\
- Version bump to v${new_version}.\\
" "$changelog"
    log_success "Added v${new_version} section to CHANGELOG.md"
  else
    log_warn "CHANGELOG.md not found, skipping"
  fi

  # The version and changelog now describe the candidate release. Validate
  # every live surface and fail before committing if this immutable tag has
  # ever been used, even if it currently resolves to HEAD.
  log_step "Validate release identity"
  bash "$SCRIPT_DIR/../release-preflight" --require-untagged
  log_success "Release identity is unique and consistent"

  # ── Step 5: Commit and tag ────────────────────────────────────
  log_step "Create signed commit and tag"
  git add -A
  git commit -S -m "chore(release): v${new_version}"
  git tag -s "v${new_version}" -m "Release v${new_version}"
  log_success "Committed and tagged v${new_version}"

  # ── Step 6: Push ──────────────────────────────────────────────
  log_step "Push to origin"
  read -rp "Push v${new_version} to origin/$branch? [y/N] " response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    git push origin "$branch" --follow-tags
    log_success "Pushed v${new_version} to origin"
  else
    log_warn "Skipped push. Run manually:"
    echo "  git push origin $branch --follow-tags"
  fi

  echo ""
  dot_log info "release_end" "version=$new_version"
  log_success "Release v${new_version} complete"
}

main "$@"
