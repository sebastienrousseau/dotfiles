#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot CLI restore command

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

RESTORE_FILE="$REPO_ROOT/scripts/dot/commands/restore.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# Test: restore.sh file exists
test_start "restore_file_exists"
assert_file_exists "$RESTORE_FILE" "restore.sh should exist"

# Test: restore.sh is valid shell syntax
test_start "restore_syntax_valid"
if bash -n "$RESTORE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

# dot restore, run against a sandboxed XDG_DATA_HOME holding two backups.
RS_HOME="$(mktemp -d -t dot-restore.XXXXXX)"
mkdir -p "$RS_HOME/data/dotfiles/backups/backup_20260101_000000_manual" \
  "$RS_HOME/data/dotfiles/backups/backup_20260202_000000_manual"
rs() {
  RS_RC=0
  RS_OUT="$(env HOME="$RS_HOME" XDG_DATA_HOME="$RS_HOME/data" XDG_STATE_HOME="$RS_HOME/state" \
    DOTFILES_DIR="$RS_HOME/no-checkout" bash "$REPO_ROOT/bin/dot" restore "$@" 2>&1)" || RS_RC=$?
}

test_start "restore_without_an_option_prints_usage"
rs
assert_equals "0" "$RS_RC" "no option exits 0"
for pair in "--list, -l" "--latest, -L" "--git, -g" "--diff, -d" "--dry-run, -n"; do
  assert_contains "$pair" "$RS_OUT" "usage documents $pair"
done

test_start "restore_list_short_and_long_agree"
rs --list
long_out="$RS_OUT"
assert_equals "0" "$RS_RC" "--list exits 0"
assert_contains "backup_20260101_000000_manual" "$long_out" "lists the first backup"
assert_contains "backup_20260202_000000_manual" "$long_out" "lists the second backup"
rs -l
assert_equals "$long_out" "$RS_OUT" "-l prints what --list prints"

test_start "restore_rejects_an_unknown_option"
rs --bogus
assert_equals "1" "$RS_RC" "an unknown option exits 1"
assert_contains "Unknown option: --bogus" "$RS_OUT" "and is named"
rm -rf "$RS_HOME"

test_start "restore_latest_preserves_hidden_paths"
restore_sandbox="$(mktemp -d)"
trap 'rm -rf "$restore_sandbox"' RETURN
mkdir -p "$restore_sandbox/home" "$restore_sandbox/data/dotfiles/backups/backup-20260322_120000/.config/zsh"
printf 'setopt\n' >"$restore_sandbox/data/dotfiles/backups/backup-20260322_120000/.zshrc"
printf 'export TEST=1\n' >"$restore_sandbox/data/dotfiles/backups/backup-20260322_120000/.config/zsh/.zshrc"
restore_output="$(
  HOME="$restore_sandbox/home" \
    XDG_DATA_HOME="$restore_sandbox/data" \
    bash "$RESTORE_FILE" --latest 2>&1
)"
if [[ -f "$restore_sandbox/home/.zshrc" ]] &&
  [[ -f "$restore_sandbox/home/.config/zsh/.zshrc" ]] &&
  grep -q "Restored: .zshrc" <<<"$restore_output" &&
  grep -q "Restored: .config" <<<"$restore_output"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: restore_latest restores hidden files and nested paths"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: restore_latest should restore hidden files and nested paths"
fi

test_start "restore_deep_branches_execute"
restore_deep="$DOTFILES_COV_TMPDIR/restore-deep"
mkdir -p "$restore_deep/home/.dotfiles/.git" \
  "$restore_deep/data/dotfiles/backups/backup-20260722_120000/.config/zsh" \
  "$restore_deep/bin"
printf 'zshrc\n' >"$restore_deep/home/.zshrc"
printf 'gitconfig\n' >"$restore_deep/home/.gitconfig"
printf 'backup zshrc\n' >"$restore_deep/data/dotfiles/backups/backup-20260722_120000/.zshrc"
printf 'backup nested\n' >"$restore_deep/data/dotfiles/backups/backup-20260722_120000/.config/zsh/.zshrc"
cat >"$restore_deep/bin/git" <<'EOF_GIT'
#!/usr/bin/env bash
case "$*" in
  *"log --oneline -10"*) printf 'abc123 latest\n' ;;
  *"diff "*" --stat"*) printf ' files changed\n' ;;
  *"diff "*) printf 'diff --git a/file b/file\n' ;;
  *"checkout "*) printf 'checkout ok\n' ;;
  *) printf 'git:%s\n' "$*" ;;
esac
EOF_GIT
cat >"$restore_deep/bin/chezmoi" <<'EOF_CHEZMOI'
#!/usr/bin/env bash
printf 'chezmoi:%s\n' "$*"
EOF_CHEZMOI
chmod +x "$restore_deep/bin/git" "$restore_deep/bin/chezmoi"
(
  set +e
  export HOME="$restore_deep/home"
  export XDG_DATA_HOME="$restore_deep/data"
  export PATH="$restore_deep/bin:$PATH"
  bash "$RESTORE_FILE" --list
  bash "$RESTORE_FILE" --latest
  bash "$RESTORE_FILE" --dry-run --git HEAD~1
  bash "$RESTORE_FILE" --git HEAD~1
  bash "$RESTORE_FILE" --diff HEAD~1
  bash "$RESTORE_FILE" --help
  bash "$RESTORE_FILE"
  rm -rf "$restore_deep/home/.dotfiles/.git"
  bash "$RESTORE_FILE" --git HEAD~1
  bash "$RESTORE_FILE" --diff HEAD~1
  HOME="$restore_deep/empty-home" XDG_DATA_HOME="$restore_deep/empty-data" \
    bash "$RESTORE_FILE" --latest
  HOME="$restore_deep/empty-home" XDG_DATA_HOME="$restore_deep/empty-data" \
    bash "$RESTORE_FILE" --list
  bash "$RESTORE_FILE" --bad-option
) >/dev/null || true
assert_file_exists "$restore_deep/home/.config/zsh/.zshrc" \
  "restore deep branches restored nested hidden zsh config"

echo ""
echo "Restore command tests completed."
# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$RESTORE_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
