#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Coverage for scripts/ops/post-apply-repair.sh branches the other suites
# leave dark: stale read-only .zwc caches (removed, and removal failing),
# the legacy `dot` alias collision, a `dot` resolving elsewhere and a `dot`
# that a login shell cannot find at all.
#
# A read-only file is only "not writable" for an unprivileged user; root
# can write anything. Under root (the coverage container) the script is
# therefore run as `nobody` via setpriv, handing it the already-open xtrace
# descriptor so coverage still records it.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

REPAIR="$REPO_ROOT/scripts/ops/post-apply-repair.sh"
WORK="$(mktemp -d -t pa-cov.XXXXXX)"
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT

dot_fixture_basebin "$WORK/base"
mkdir -p "$WORK/home/.local/bin" "$WORK/stubs" "$WORK/cache"
printf '#!/bin/sh\nexit 0\n' >"$WORK/home/.local/bin/dot"
chmod +x "$WORK/home/.local/bin/dot"
DOT_BIN="$WORK/home/.local/bin/dot"

UNPRIV=()
if [[ "$(id -u)" == "0" ]]; then
  if ! command -v setpriv >/dev/null 2>&1; then
    echo "SKIP: running as root without setpriv; read-only branches unreachable"
    echo "RESULTS:0:0:0"
    exit 0
  fi
  UNPRIV=("$(command -v setpriv)" --reuid=65534 --regid=65534 --clear-groups)
  chmod 755 "$WORK"
  chmod -R a+rwX "$WORK/home" "$WORK/cache" "$WORK/stubs"
fi

# write_zsh <stdout-body>: a zsh stub that prints the given two lines.
write_zsh() {
  printf '#!/bin/sh\nprintf "%%s\\n" %s\n' "$1" >"$WORK/stubs/zsh"
  chmod 755 "$WORK/stubs/zsh"
}

OUT=""
RC=0
pa_run() {
  RC=0
  OUT="$(
    BASH_XTRACEFD="${BASH_XTRACEFD:-}" HOME="$WORK/home" \
      PATH="$WORK/stubs:$WORK/base" NO_COLOR=1 \
      DOTFILES_ZWC_CACHE_DIRS="$WORK/cache" DOTFILES_ZSH_BIN="$WORK/stubs/zsh" \
      ${UNPRIV[@]+"${UNPRIV[@]}"} "${BASH:-bash}" "$REPAIR" 2>&1 </dev/null
  )" || RC=$?
}

stale_zwc() {
  : >"$WORK/cache/$1.zwc"
  chmod 444 "$WORK/cache/$1.zwc"
}

test_start "post_apply_repair_removes_stale_readonly_zwc"
stale_zwc a
write_zsh "'' '$DOT_BIN'"
pa_run
assert_equals 0 "$RC" "exits 0"
assert_contains "removed 1 stale read-only .zwc" "$OUT" "stale cache removed"
assert_file_not_exists "$WORK/cache/a.zwc" "read-only .zwc deleted"
assert_contains "$DOT_BIN" "$OUT" "expected dot path reported ok"

test_start "post_apply_repair_reports_failed_zwc_removal"
stale_zwc b
printf '#!/bin/sh\nexit 1\n' >"$WORK/stubs/rm"
chmod 755 "$WORK/stubs/rm"
pa_run
/bin/rm -f "$WORK/stubs/rm"
assert_contains "failed to remove 1 stale .zwc" "$OUT" "removal failure reported"
assert_file_exists "$WORK/cache/b.zwc" "file left in place"
chmod 644 "$WORK/cache/b.zwc"
rm -f "$WORK/cache/b.zwc"

test_start "post_apply_repair_warns_on_alias_collision_and_foreign_dot"
write_zsh "\"dot='cd_with_history ..'\" /opt/elsewhere/dot"
pa_run
assert_contains "legacy sessions may still map dot" "$OUT" "alias collision warned"
assert_contains "resolved to /opt/elsewhere/dot" "$OUT" "foreign dot path warned"

test_start "post_apply_repair_reports_unresolvable_dot"
write_zsh "''"
pa_run
assert_contains "dot not found in a fresh zsh login shell" "$OUT" "missing dot reported"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" == 0 ]]
