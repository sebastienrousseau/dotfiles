#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# =============================================================================
# Dotfiles Release Script
# Orchestrates a new release: version bump, changelog, tag, and push
# Usage: ./scripts/ops/release.sh [patch|minor] [--dry-run]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors (respect NO_COLOR)
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
  RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m'
  BLUE='\033[0;34m' BOLD='\033[1m' NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

log_info() { printf '%b\n' "${BLUE}[INFO]${NC} $*"; }
log_success() { printf '%b\n' "${GREEN}[OK]${NC} $*"; }
log_warn() { printf '%b\n' "${YELLOW}[WARN]${NC} $*"; }
log_error() { printf '%b\n' "${RED}[ERROR]${NC} $*" >&2; }
log_step() { printf '%b\n' "\n${BOLD}── $* ──${NC}"; }

usage() {
  cat <<EOF
Dotfiles Release Tool

Usage: $(basename "$0") [BUMP_TYPE] [OPTIONS]

Bump Types:
  patch         Increment patch version (0.2.490 → 0.2.491) [default]
  minor         Increment minor version (0.2.490 → 0.3.0)

Options:
  -n, --dry-run   Show what would be done without making changes
  -h, --help      Show this help message

Steps performed:
  1. Verify clean working tree and up-to-date branch
  2. Bump version in package.json
  3. Run version-sync to update docs
  4. Update CHANGELOG.md with new version header
  5. Create signed commit and tag
  6. Push commit and tag to origin

Examples:
  $(basename "$0")              # Patch release
  $(basename "$0") minor        # Minor release
  $(basename "$0") --dry-run    # Preview patch release

EOF
}

# Get current version from package.json
get_version() {
  grep -o '"version": "[^"]*"' "$PROJECT_ROOT/package.json" | grep -o '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*'
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

  cd "$PROJECT_ROOT"

  local current_version new_version
  current_version=$(get_version)
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

  if [[ "$dry_run" == "1" ]]; then
    log_step "Would perform the following"
    log_info "1. Bump package.json: $current_version → $new_version"
    log_info "2. Run version-sync.sh"
    log_info "3. Add v${new_version} header to CHANGELOG.md"
    log_info "4. Commit: 'chore(release): v${new_version}'"
    log_info "5. Tag: v${new_version} (signed)"
    log_info "6. Push commit and tag to origin"
    echo ""
    log_success "Dry run complete"
    exit 0
  fi

  # ── Step 2: Bump version ──────────────────────────────────────
  log_step "Bump version in package.json"
  sed -i.bak "s/\"version\": \"${current_version}\"/\"version\": \"${new_version}\"/" "$PROJECT_ROOT/package.json" && rm -f "$PROJECT_ROOT/package.json.bak"
  log_success "package.json: $current_version → $new_version"

  # ── Step 3: Sync versions across docs ─────────────────────────
  log_step "Sync version across docs"
  if [[ -x "$SCRIPT_DIR/../version-sync.sh" ]]; then
    bash "$SCRIPT_DIR/../version-sync.sh" --force 2>&1 | tail -3
    log_success "Version sync complete"
  else
    log_warn "version-sync.sh not found, skipping"
  fi

  # ── Step 4: Update CHANGELOG ──────────────────────────────────
  log_step "Update CHANGELOG.md"
  local today
  today=$(date +%Y-%m-%d)
  local changelog="$PROJECT_ROOT/CHANGELOG.md"

  if [[ -f "$changelog" ]]; then
    # Insert new version header after the first "# Changelog" line
    sed -i.bak "/^## v${current_version}/i\\
## v${new_version} (${today})\\
\\
### Changed\\
\\
- Version bump to v${new_version}.\\
" "$changelog" && rm -f "$changelog.bak"
    log_success "Added v${new_version} section to CHANGELOG.md"
  else
    log_warn "CHANGELOG.md not found, skipping"
  fi

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
  log_success "Release v${new_version} complete"
}

main "$@"
