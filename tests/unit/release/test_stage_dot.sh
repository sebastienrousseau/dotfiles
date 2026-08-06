#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

stage="$REPO_ROOT/tools/release/stage-dot.sh"
tmp="$(mktemp -d -t dot-stage.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT

test_start "stage_script_syntax"
if bash -n "$stage"; then ((TESTS_PASSED++)) || true; else ((TESTS_FAILED++)) || true; fi

test_start "stage_bundle_executes"
if bash "$stage" "$tmp/bundle"; then ((TESTS_PASSED++)) || true; else ((TESTS_FAILED++)) || true; fi

for path in Makefile bin/dot lib/dot/ui.sh scripts/dot/commands/core.sh security/remote-installers.sha256 share/man/man1/dot.1; do
  test_start "stage_contains_${path//\//_}"
  assert_file_exists "$tmp/bundle/$path" "staged bundle must contain $path"
done

test_start "stage_make_install_round_trip"
install_root="$(mktemp -d -t dot-install.XXXXXX)"
if make -C "$tmp/bundle" install PREFIX=/usr/local DESTDIR="$install_root" >/dev/null &&
  CHEZMOI_SOURCE_DIR="$install_root/usr/local/lib/dotfiles" \
    DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 \
    "$install_root/usr/local/bin/dot" version >/dev/null &&
  CHEZMOI_SOURCE_DIR="$install_root/usr/local/lib/dotfiles" \
    DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 \
    "$install_root/usr/local/bin/dot" registry --help >/dev/null &&
  make -C "$tmp/bundle" uninstall PREFIX=/usr/local DESTDIR="$install_root" >/dev/null &&
  [[ ! -e "$install_root/usr/local/bin/dot" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi
rm -rf "$install_root"

test_start "stage_refuses_root"
if bash "$stage" / >/dev/null 2>&1; then ((TESTS_FAILED++)) || true; else ((TESTS_PASSED++)) || true; fi

test_start "stage_refuses_unrelated_directory"
if bash "$stage" "$tmp/unrelated" >/dev/null 2>&1; then ((TESTS_FAILED++)) || true; else ((TESTS_PASSED++)) || true; fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
