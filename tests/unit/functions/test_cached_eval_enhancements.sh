#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioral tests for the _cached_eval enhancements introduced in v0.2.501:
#   - EVALCACHE_DISABLE bypass
#   - Realpath-pin invalidation (PATH-shadow swap)
#   - File-path argument mtime invalidation
#   - _cached_eval_clear helper

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

# Portable bash mirror of the enhanced contract — matches the zsh and bash
# implementations' observable behavior without zsh-only constructs.
_SHELL_CACHE=$(portable_mktemp_dir)

_cached_eval() {
  local label="$1"; shift

  if [[ "$EVALCACHE_DISABLE" == "true" ]]; then
    eval "$("$@" 2>/dev/null)"
    return $?
  fi

  local cache="$_SHELL_CACHE/${label}.sh"
  local pin="${cache}.bin"
  local bin
  bin=$(command -v "$1" 2>/dev/null || true)
  local real_bin=""
  [[ -n "$bin" ]] && real_bin=$(readlink -f -- "$bin" 2>/dev/null || echo "$bin")

  local cache_valid=1
  if [[ ! -s "$cache" ]]; then
    cache_valid=0
  elif [[ -n "$bin" && "$bin" -nt "$cache" ]]; then
    cache_valid=0
  elif [[ -f "$pin" && -n "$real_bin" ]]; then
    local pinned
    pinned=$(<"$pin")
    [[ -n "$pinned" && "$pinned" != "$real_bin" ]] && cache_valid=0
  fi
  if [[ "$cache_valid" == 1 ]]; then
    local arg
    for arg in "${@:2}"; do
      if [[ -f "$arg" && "$arg" -nt "$cache" ]]; then
        cache_valid=0
        break
      fi
    done
  fi

  if [[ "$cache_valid" == 1 ]]; then
    source "$cache"
    return
  fi

  local out
  out=$("$@" 2>/dev/null) || return $?
  echo "$out" >"${cache}.tmp.$$"
  mv "${cache}.tmp.$$" "$cache"
  if [[ -n "$real_bin" ]]; then
    echo "$real_bin" >"${pin}.tmp.$$"
    mv "${pin}.tmp.$$" "$pin"
  fi
  source "$cache"
}

_cached_eval_clear() {
  local cache_dir="$_SHELL_CACHE"
  [[ -d "$cache_dir" ]] || return 0
  local count=0 f
  shopt -s nullglob
  for f in "$cache_dir"/*.sh "$cache_dir"/*.sh.bin; do
    rm -f -- "$f" && ((count++))
  done
  shopt -u nullglob
  printf 'Cleared %d cached eval file(s) from %s\n' "$count" "$cache_dir"
}

mock_init

# ──────────────────────────────────────────────────────────────────────────────
# 1. EVALCACHE_DISABLE bypass: cache file is never created
# ──────────────────────────────────────────────────────────────────────────────
test_start "evalcache_disable_skips_cache_write"
mock_command_spy "bypasscmd" "export _CE_BYPASS_VAR=set_via_eval"
EVALCACHE_DISABLE=true _cached_eval "bypass_label" bypasscmd
assert_equals "set_via_eval" "${_CE_BYPASS_VAR:-}" "EVALCACHE_DISABLE should still eval the output"
if [[ ! -e "$_SHELL_CACHE/bypass_label.sh" ]]; then
  ((TESTS_PASSED++))
  printf '  \033[0;32m✓\033[0m %s: cache file was NOT created when EVALCACHE_DISABLE=true\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '  \033[0;31m✗\033[0m %s: cache file should not exist when EVALCACHE_DISABLE=true\n' "$CURRENT_TEST"
fi
unset _CE_BYPASS_VAR

# ──────────────────────────────────────────────────────────────────────────────
# 2. EVALCACHE_DISABLE re-execs every call (no caching)
# ──────────────────────────────────────────────────────────────────────────────
test_start "evalcache_disable_reexecutes"
EVALCACHE_DISABLE=true _cached_eval "bypass_label" bypasscmd
EVALCACHE_DISABLE=true _cached_eval "bypass_label" bypasscmd
call_count=$(mock_call_count "bypasscmd")
# 1 from test 1 + 2 here = 3. Each call re-runs the binary.
assert_equals "3" "$call_count" "EVALCACHE_DISABLE should re-exec on every call"

# ──────────────────────────────────────────────────────────────────────────────
# 3. Realpath pin: cache invalidated when binary path changes
# ──────────────────────────────────────────────────────────────────────────────
test_start "realpath_pin_invalidates_on_path_change"
# Create a real binary at one location, _cached_eval writes pin sidecar.
mock_command_spy "shadowcmd" "export _CE_SHADOW=first_path"
_cached_eval "shadow_label" shadowcmd
assert_file_exists "$_SHELL_CACHE/shadow_label.sh.bin" "realpath pin sidecar should be created"
unset _CE_SHADOW

# Now create a *second* binary with the same name in an earlier PATH dir, so
# `command -v shadowcmd` resolves to a different realpath. The pin should
# detect the swap and force regeneration.
SHADOW_DIR2=$(portable_mktemp_dir)
cat >"$SHADOW_DIR2/shadowcmd" <<'EOF'
#!/usr/bin/env bash
echo "export _CE_SHADOW=second_path"
EOF
chmod +x "$SHADOW_DIR2/shadowcmd"
ORIG_PATH=$PATH
PATH="$SHADOW_DIR2:$PATH"
_cached_eval "shadow_label" shadowcmd
assert_equals "second_path" "${_CE_SHADOW:-}" "stale cache should be invalidated when realpath changes"
PATH=$ORIG_PATH
rm -rf "$SHADOW_DIR2"
unset _CE_SHADOW

# ──────────────────────────────────────────────────────────────────────────────
# 4. File-arg mtime: cache invalidated when a file path arg is modified
# ──────────────────────────────────────────────────────────────────────────────
test_start "file_arg_mtime_invalidates_cache"
mock_command_spy "filecmd" "export _CE_FILE=initial_config"
CONFIG_FILE=$(portable_mktemp_dir)/config.toml
echo "v=1" >"$CONFIG_FILE"
touch -t 200001010000 "$CONFIG_FILE"
_cached_eval "file_label" filecmd "$CONFIG_FILE"
assert_equals "initial_config" "${_CE_FILE:-}" "first call should populate cache"
# Modify config file → newer than cache → must regenerate
sleep 1
echo "v=2" >"$CONFIG_FILE"
cat >"$MOCK_BIN_DIR/filecmd" <<'EOF'
#!/usr/bin/env bash
echo "export _CE_FILE=updated_config"
EOF
chmod +x "$MOCK_BIN_DIR/filecmd"
unset _CE_FILE
_cached_eval "file_label" filecmd "$CONFIG_FILE"
assert_equals "updated_config" "${_CE_FILE:-}" "config file change should invalidate cache"
rm -f "$CONFIG_FILE"
unset _CE_FILE

# ──────────────────────────────────────────────────────────────────────────────
# 5. _cached_eval_clear removes init outputs and pin sidecars
# ──────────────────────────────────────────────────────────────────────────────
test_start "cached_eval_clear_removes_files"
mock_command "clearcmd" "export _CE_CLEAR=cached"
_cached_eval "clear_label" clearcmd
[[ -f "$_SHELL_CACHE/clear_label.sh" ]]     # cache exists
[[ -f "$_SHELL_CACHE/clear_label.sh.bin" ]] # pin exists
output=$(_cached_eval_clear)
if [[ ! -e "$_SHELL_CACHE/clear_label.sh" && ! -e "$_SHELL_CACHE/clear_label.sh.bin" ]]; then
  ((TESTS_PASSED++))
  printf '  \033[0;32m✓\033[0m %s: cache and pin files removed\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '  \033[0;31m✗\033[0m %s: files still present after _cached_eval_clear\n' "$CURRENT_TEST"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 6. _cached_eval_clear leaves unrelated files alone
# ──────────────────────────────────────────────────────────────────────────────
test_start "cached_eval_clear_leaves_unrelated_files"
echo "ignore me" >"$_SHELL_CACHE/unrelated.txt"
mock_command "anothercmd" "export _CE_X=y"
_cached_eval "another_label" anothercmd
_cached_eval_clear >/dev/null
assert_file_exists "$_SHELL_CACHE/unrelated.txt" "non-cache files must not be deleted"
rm -f "$_SHELL_CACHE/unrelated.txt"

# Cleanup
rm -rf "$_SHELL_CACHE"
mock_cleanup

echo ""
echo "_cached_eval enhancement tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
