#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# bash's _cached_eval writes its cache like zsh's: through mktemp, so the
# file is private (0600) whatever the umask, where it used to be written
# through `${cache}.tmp.$$` with the umask (0644 under the usual 022).
# The real _cached_eval_impl is taken from defaults/dot_bashrc and run
# against a stub tool.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-bash-cache.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/cache"
printf '#!/usr/bin/env bash\necho "export ZZ_INIT_RAN=1"\n' >"$WORK/bin/zztool"
chmod +x "$WORK/bin/zztool"

# The function, as dot_bashrc defines it (indented in its guard block).
awk '/^  _cached_eval_impl\(\) \{/,/^  \}$/' "$REPO_ROOT/defaults/dot_bashrc" >"$WORK/impl.sh"

# mode FILE: its permission bits, on GNU or BSD stat.
mode() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"; }

test_start "the_function_is_found"
assert_contains "_cached_eval_impl()" "$(cat "$WORK/impl.sh")" "dot_bashrc defines _cached_eval_impl"

test_start "the_cache_is_private_under_a_permissive_umask"
out="$(PATH="$WORK/bin:$PATH" _SHELL_CACHE="$WORK/cache" bash -c '
  umask 022
  source "$1"
  _cached_eval_impl zztool zztool >/dev/null 2>&1
  echo "ran=${ZZ_INIT_RAN:-0}"
' _ "$WORK/impl.sh")"
assert_equals "ran=1" "$out" "the tool's init output is sourced"
assert_file_exists "$WORK/cache/zztool.bash" "and cached"
assert_equals "600" "$(mode "$WORK/cache/zztool.bash")" "the cache file is 0600"
assert_equals "" "$(find "$WORK/cache" -name '*.tmp.*' -o -name 'zztool.bash.??????' | head -1)" "no temporary file is left"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
