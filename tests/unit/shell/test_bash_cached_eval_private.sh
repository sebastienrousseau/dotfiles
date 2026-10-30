#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# bash's _cached_eval writes its cache like zsh's: through mktemp, so the
# file is private (0600) whatever the umask, where it used to be written
# through `${cache}.tmp.$$` with the umask (0644 under the usual 022).
# defaults/dot_bashrc is sourced in a sandboxed interactive bash (it
# returns early otherwise) and its deferred hydration run, which defines
# _cached_eval_impl, against a stub tool.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-bash-cache.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home" "$WORK/bin" "$WORK/xdg-cache"
printf '#!/usr/bin/env bash\necho "export ZZ_INIT_RAN=1"\n' >"$WORK/bin/zztool"
chmod +x "$WORK/bin/zztool"
CACHE="$WORK/xdg-cache/bash"

# mode FILE: its permission bits, on GNU or BSD stat.
mode() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"; }

out="$(env -i ${BASH_ENV:+BASH_ENV="$BASH_ENV"} ${PS4:+PS4="$PS4"} HOME="$WORK/home" \
  PATH="$WORK/bin:/usr/bin:/bin" XDG_CACHE_HOME="$WORK/xdg-cache" TERM=dumb \
  bash -i -c '
    umask 022
    source "$1" >/dev/null 2>&1
    _deferred_hydration >/dev/null 2>&1
    declare -F _cached_eval_impl >/dev/null && echo defined
    _cached_eval_impl zztool zztool >/dev/null 2>&1
    echo "ran=${ZZ_INIT_RAN:-0}"
  ' _ "$REPO_ROOT/defaults/dot_bashrc" </dev/null 2>/dev/null)"

test_start "hydration_defines_the_cache_function"
assert_contains "defined" "$out" "_deferred_hydration defines _cached_eval_impl"

test_start "the_cache_is_private_under_a_permissive_umask"
assert_contains "ran=1" "$out" "the tool's init output is sourced"
assert_file_exists "$CACHE/zztool.bash" "and cached"
assert_equals "600" "$(mode "$CACHE/zztool.bash")" "the cache file is 0600"
assert_equals "" "$(find "$CACHE" -name '*.tmp.*' -o -name '*.bash.??????' | head -1)" "no temporary file is left"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
