#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioral tests for the _cached_eval pattern (bash variant).
#
# The _cached_eval implementation from dot_config/zsh/dot_zshrc.tmpl uses
# zsh-specific constructs (zcompile, ${commands[...]}, &!). This test
# file verifies the core caching contract using a portable bash-equivalent
# implementation, closely mirroring the real pattern's observable behavior:
#   - First call: execute command and write cache file.
#   - Second call: read from cache file (command not re-executed).
#   - Cache invalidation: re-execute when binary is newer than cache.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

# ──────────────────────────────────────────────────────────────────────────────
# Portable bash implementation of the _cached_eval contract.
# Matches the zsh version's logic without zsh-only constructs.
#
#   _cached_eval <label> <command> [args...]
#     - cache dir: $_SHELL_CACHE
#     - cache file: $_SHELL_CACHE/<label>.sh
#     - invalidated when command binary is newer than cache file
# ──────────────────────────────────────────────────────────────────────────────
_SHELL_CACHE=$(portable_mktemp_dir)

_cached_eval() {
  local label="$1"
  shift
  local cache="$_SHELL_CACHE/${label}.sh"
  local bin
  bin=$(command -v "$1" 2>/dev/null || true)
  # Use cache if it exists and is not older than the binary (or binary unknown)
  if [[ -f "$cache" ]] && { [[ -z "$bin" ]] || [[ ! "$bin" -nt "$cache" ]]; }; then
    # shellcheck source=/dev/null
    source "$cache"
  else
    "$@" >"$cache" 2>/dev/null
    # shellcheck source=/dev/null
    source "$cache"
  fi
}

mock_init

# ──────────────────────────────────────────────────────────────────────────────
# 1. First call creates the cache file
# ──────────────────────────────────────────────────────────────────────────────
test_start "cached_eval_creates_cache_on_first_call"
mock_command_spy "mycmd1" "export CACHED_EVAL_VAR1=first_run"
_cached_eval "test_label1" mycmd1
assert_file_exists "$_SHELL_CACHE/test_label1.sh" "cache file should be created after first call"

# ──────────────────────────────────────────────────────────────────────────────
# 2. First call sources the command output (side-effect is visible)
# ──────────────────────────────────────────────────────────────────────────────
test_start "cached_eval_sources_output_first_call"
assert_equals "first_run" "${CACHED_EVAL_VAR1:-}" "variable from command output should be set after first call"

# ──────────────────────────────────────────────────────────────────────────────
# 3. Second call does NOT re-execute the command (uses cache)
# ──────────────────────────────────────────────────────────────────────────────
test_start "cached_eval_uses_cache_second_call"
# Override the spy output so re-execution would be detectable.
cat >"$MOCK_BIN_DIR/mycmd1" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_BIN_DIR/mycmd1.spy"
echo "export CACHED_EVAL_VAR1=second_run"
exit 0
EOF
chmod +x "$MOCK_BIN_DIR/mycmd1"
# The cache was created above; it should be at least as new as the binary.
touch "$_SHELL_CACHE/test_label1.sh" # ensure cache is fresh
_cached_eval "test_label1" mycmd1
# Variable should still reflect the cached (first_run) content, not second_run
assert_equals "first_run" "${CACHED_EVAL_VAR1:-}" "second call should read from cache, not re-execute"

# ──────────────────────────────────────────────────────────────────────────────
# 4. Command is not called again on second invocation (spy count check)
# ──────────────────────────────────────────────────────────────────────────────
test_start "cached_eval_command_not_called_twice"
call_count=$(mock_call_count "mycmd1")
# Should be 1: the first call above. The second call should have hit cache.
assert_equals "1" "$call_count" "mock command should have been called exactly once"

# ──────────────────────────────────────────────────────────────────────────────
# 5. Cache invalidation: when binary is newer than cache, command re-runs
# ──────────────────────────────────────────────────────────────────────────────
test_start "cached_eval_invalidates_when_binary_newer"
mock_command_spy "mycmd2" "export CACHED_EVAL_VAR2=old_cached"
# First call: build cache.
_cached_eval "test_label2" mycmd2

# Simulate binary being updated with deterministic mtimes.
touch -t 200001010000 "$_SHELL_CACHE/test_label2.sh"
# Update the spy output to reflect new binary behavior.
cat >"$MOCK_BIN_DIR/mycmd2" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_BIN_DIR/mycmd2.spy"
echo "export CACHED_EVAL_VAR2=new_binary"
exit 0
EOF
chmod +x "$MOCK_BIN_DIR/mycmd2"
touch -t 203001010000 "$MOCK_BIN_DIR/mycmd2"

# Reset the variable so we can detect re-execution.
unset CACHED_EVAL_VAR2
_cached_eval "test_label2" mycmd2
assert_equals "new_binary" "${CACHED_EVAL_VAR2:-}" "stale cache should be invalidated when binary is newer"

# ──────────────────────────────────────────────────────────────────────────────
# 6. Cache content matches the command's actual stdout
# ──────────────────────────────────────────────────────────────────────────────
test_start "cached_eval_cache_content_matches_command_output"
mock_command_spy "mycmd3" "# cache content marker"
_cached_eval "test_label3" mycmd3
assert_file_contains "$_SHELL_CACHE/test_label3.sh" "# cache content marker" "cache file should contain command output"

# ──────────────────────────────────────────────────────────────────────────────
# 7. Different labels produce separate cache files
# ──────────────────────────────────────────────────────────────────────────────
test_start "cached_eval_separate_labels_separate_files"
mock_command "mycmd_a" "export _CE_A=alpha"
mock_command "mycmd_b" "export _CE_B=beta"
_cached_eval "label_a" mycmd_a
_cached_eval "label_b" mycmd_b
assert_file_exists "$_SHELL_CACHE/label_a.sh" "label_a cache file should exist"
assert_file_exists "$_SHELL_CACHE/label_b.sh" "label_b cache file should exist"

# ──────────────────────────────────────────────────────────────────────────────
# 8. Cache variables are isolated: label_a and label_b set distinct vars
# ──────────────────────────────────────────────────────────────────────────────
test_start "cached_eval_separate_labels_separate_vars"
assert_equals "alpha" "${_CE_A:-}" "label_a should have set _CE_A=alpha"
assert_equals "beta" "${_CE_B:-}" "label_b should have set _CE_B=beta"

# Cleanup
rm -rf "$_SHELL_CACHE"
mock_cleanup

echo ""
echo "_cached_eval behavioral tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
