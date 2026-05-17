#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

assert_python_parses() {
  local path="$1"
  local cache_file="/tmp/$(basename "$path").pyc"
  assert_exit_code 0 "python3 -c \"import py_compile; py_compile.compile(r'$path', cfile=r'$cache_file', doraise=True)\""
}

test_start "bin_public_entrypoints_exist_and_parse"
# Post-v0.2.503 reorg: the core `dot` CLI family (dot, dot-bootstrap,
# dot-theme-sync, dot-load-benchmark-pty) lives at bin/<name>. The
# remaining utility binaries stay at dot_local/bin/executable_<name>
# (chezmoi-deployed user utilities, not framework distribution targets).
#
# macOS bash 3.2 has no `declare -A` (associative arrays). Use a
# case-based resolver instead so the test runs everywhere.
_bin_path() {
  case "$1" in
    dot | dot-bootstrap | dot-theme-sync | dot-load-benchmark-pty)
      printf "%s/bin/%s\n" "$REPO_ROOT" "$1"
      ;;
    *)
      printf "%s/dot_local/bin/executable_%s\n" "$REPO_ROOT" "$1"
      ;;
  esac
}

for name in \
  ai-update antigravity b64 dot-bootstrap dot-load-benchmark dot-load-benchmark-pty epoch git-ai-commit \
  git-ai-diff hashsum jsonv jwt kill-port lorem myip tour yamlv start-niri dot-ai ai_core; do
  path="$(_bin_path "$name")"
  assert_file_exists "$path" "bin_${name//-/_}_exists"
  case "$name" in
    dot-load-benchmark)
      assert_exit_code 0 "bash -n '$path'"
      ;;
    *)
      if head -n 1 "$path" | grep -q 'python'; then
        assert_python_parses "$path"
      else
        assert_exit_code 0 "bash -n '$path'"
      fi
      ;;
  esac
done

test_start "functions_utils_yazi_exists_and_parses"
assert_file_exists "$REPO_ROOT/.chezmoitemplates/functions/utils/yazi.sh" "functions_utils_yazi_exists"
assert_exit_code 0 "bash -n '$REPO_ROOT/.chezmoitemplates/functions/utils/yazi.sh'"
