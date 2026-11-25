#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# test-kind: structural
# shellcheck disable=SC1090,SC1091,SC2034
# standards-sync and defaults/Code. The command is not vendored here: mise
# installs it from PyPI (pipx:standards-sync), and its behaviour is tested
# in the standards repository. This file checks what the dotfiles own: the
# standard files, the pinned install, the removal of the old copy, the
# sentinel's syntax, and, when a standards-sync is installed, the --check
# contract the sentinel relies on.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

MISE_CONF="$REPO_ROOT/defaults/dot_config/mise/conf.d/00-dotfiles.toml"
CHEZMOI_REMOVE="$REPO_ROOT/defaults/.chezmoiremove"
SENTINEL_ZSH="$REPO_ROOT/defaults/dot_config/zsh/rc.d/45-standards.zsh"

STANDARD_FILES=(
  "AGENTS.md"
  "GEMINI.md"
  "PR-TEMPLATE.md"
  "README-TEMPLATE.md"
  "REPO-STANDARD.md"
)

# 1. The standard files are present and non-empty in defaults/Code
for file in "${STANDARD_FILES[@]}"; do
  test_start "standards_${file//./_}_present"
  target="$REPO_ROOT/defaults/Code/$file"
  if [[ -f "$target" && -s "$target" ]]; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defaults/Code/$file exists and is non-empty"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: defaults/Code/$file is missing or empty"
  fi
done

# 2. mise installs it from PyPI at an exact version, never "latest"
test_start "standards_sync_pinned_in_mise"
pin="$(sed -n 's/^"pipx:standards-sync" = "\([^"]*\)".*/\1/p' "$MISE_CONF")"
if [[ "$pin" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: pipx:standards-sync pinned to $pin"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: pipx:standards-sync is not pinned to an exact version (got '$pin')"
fi

# 3. The old vendored copy is gone, and chezmoi removes the installed one
test_start "vendored_copy_removed"
if [[ -e "$REPO_ROOT/defaults/dot_local/bin/executable_standards-sync" ]]; then
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: defaults/dot_local/bin/executable_standards-sync would shadow the mise install"
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi
test_start "chezmoi_removes_old_copy"
if grep -qx '.local/bin/standards-sync' "$CHEZMOI_REMOVE"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: .chezmoiremove does not list .local/bin/standards-sync"
fi

# 4. 45-standards.zsh exists and is valid shell syntax
test_start "standards_sentinel_syntax"
if [[ -f "$SENTINEL_ZSH" ]] && { ! command -v zsh >/dev/null 2>&1 || zsh -n "$SENTINEL_ZSH" 2>/dev/null; }; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: 45-standards.zsh exists and has valid shell syntax"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: 45-standards.zsh is missing or has a syntax error"
fi

# 5. The --check contract the sentinel relies on: 0 when in sync, 1 and a
# "Drift detected" line under --quiet when not. Runs only where installed.
if ! command -v standards-sync >/dev/null 2>&1; then
  printf '%b\n' "  ${YELLOW}∼${NC} standards_sync_check_contract: skipped (standards-sync not installed)"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 0
fi

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/standards-sync-test.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/src" "$SANDBOX/target"
for f in "${STANDARD_FILES[@]}"; do
  printf 'content of %s\n' "$f" >"$SANDBOX/src/$f"
  cp "$SANDBOX/src/$f" "$SANDBOX/target/$f"
done

# sync ARGS...: run the installed command on the sandbox; sets rc and out.
sync() {
  rc=0
  out="$(STANDARDS_REPO="$SANDBOX/src" STANDARDS_TARGETS="$SANDBOX/target" standards-sync "$@" 2>&1)" || rc=$?
}

test_start "standards_sync_check_contract"
sync --check --quiet
assert_equals "0" "$rc" "check exits 0 when the targets match"
printf 'drifted content\n' >"$SANDBOX/target/AGENTS.md"
sync --check --quiet
assert_equals "1" "$rc" "check exits 1 when a target drifted"
assert_contains "Drift detected" "$out" "quiet mode prints the warning the sentinel shows"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
