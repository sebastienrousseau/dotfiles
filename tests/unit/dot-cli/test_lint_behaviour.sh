#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# `dot lint` end to end on a small copy of the tree (--fix rewrites it),
# with stub shellcheck/shfmt: shellcheck reports files containing BADSC,
# shfmt -l lists files containing BADFMT and -w deletes those lines.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

REAL_BASH="$(command -v bash)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
N=0

# The system tools minus shellcheck/shfmt, so a case that removes a stub
# really has no such tool (CI runners ship shellcheck in /usr/bin).
SYS="$WORK/sys"
mkdir -p "$SYS"
for _f in /usr/bin/* /bin/*; do
  case "${_f##*/}" in shellcheck | shfmt) continue ;; esac
  [[ -e "$SYS/${_f##*/}" ]] || ln -s "$_f" "$SYS/${_f##*/}"
done

# setup [SC] [FMT]: a fresh tree in $W/t and stubs in $W/stubs.
setup() {
  W="$WORK/c$((++N))"
  mkdir -p "$W/t/scripts/dot/commands" "$W/t/scripts/ops" "$W/t/defaults/dot_local/bin" "$W/stubs"
  cp -R "$REPO_ROOT/lib" "$W/t/lib"
  cp "$REPO_ROOT/scripts/dot/commands/lint.sh" "$W/t/scripts/dot/commands/"
  echo defaults >"$W/t/.chezmoiroot"
  printf '#!/usr/bin/env bash\necho a\n' >"$W/t/scripts/ops/a.sh"
  printf '#!/usr/bin/env bash\necho b\n' >"$W/t/scripts/ops/b.sh"
  printf '#!/bin/sh\necho i\n' >"$W/t/install.sh"
  printf '#!/bin/bash\n' >"$W/t/defaults/dot_local/bin/executable_one"
  printf '#!/usr/bin/env python3\n' >"$W/t/defaults/dot_local/bin/executable_py"
  local f
  for f in "$@"; do
    case "$f" in
      SC) echo BADSC >>"$W/t/scripts/ops/a.sh" ;;
      FMT) echo BADFMT >>"$W/t/scripts/ops/b.sh" && echo BADFMT >>"$W/t/install.sh" ;;
    esac
  done
  cat >"$W/stubs/shellcheck" <<SH
#!$REAL_BASH
for a in "\$@"; do [ -f "\$a" ] && grep -q BADSC "\$a" && echo "\$a:2:1: error: bad [SC1000]"; done; exit 1
SH
  cat >"$W/stubs/shfmt" <<SH
#!$REAL_BASH
case " \$* " in *" -w "*) for a in "\$@"; do [ -f "\$a" ] && sed -i.bak '/BADFMT/d' "\$a" && rm -f "\$a.bak"; done; exit 0 ;; esac
for a in "\$@"; do [ -f "\$a" ] && grep -q BADFMT "\$a" && echo "\$a"; done; exit 0
SH
  chmod +x "$W/stubs/"*
}

lint() {
  OUT="$(cd "$W" && env -i HOME="$W" PATH="$W/stubs:$SYS" TERM=dumb NO_COLOR=1 \
    "$REAL_BASH" t/scripts/dot/commands/lint.sh "$@" </dev/null 2>&1)"
  RC=$?
}
has() { if [[ "$OUT" == *"$1"* ]]; then echo yes; else echo no; fi; }

test_start "lint_clean_tree_passes"
setup
lint --check
assert_equals "0:yes:yes" "$RC:$(has 'All checks passed'):$(has 'Files scanned                       5')" \
  "four scripts plus one shell executable (python skipped), all clean"

test_start "lint_check_fails_on_shellcheck_errors"
setup SC
lint --check
assert_equals "1:yes" "$RC:$(has '1 file(s) with errors')" "check mode exits 1"

test_start "lint_default_mode_reports_but_passes"
lint
assert_equals "0:yes" "$RC:$(has 'ShellCheck errors')" "the default mode reports without failing"

test_start "lint_check_fails_on_format_errors"
setup FMT
lint -c
assert_equals "1:yes" "$RC:$(has '2 file(s) need formatting')" "two files need formatting"

test_start "lint_fix_reformats_and_counts"
lint --fix
assert_equals "0:yes:no" "$RC:$(has '2 file(s) reformatted'):$(grep -rq BADFMT "$W/t" && echo yes || echo no)" \
  "both files fixed, nothing left"

test_start "lint_fix_with_nothing_to_do"
lint -f
assert_contains "All files already formatted" "$OUT" "a second fix finds nothing"

test_start "lint_without_shfmt_skips_it_and_still_summarises"
setup FMT
rm "$W/stubs/shfmt"
lint --check
assert_equals "0:yes:yes" "$RC:$(has 'shfmt                               not installed, skipping'):$(has 'Files scanned')" \
  "a missing shfmt is a skip, not an abort"

test_start "lint_without_shellcheck_skips_it"
setup SC
rm "$W/stubs/shellcheck"
lint --check
assert_equals "0:yes" "$RC:$(has 'shellcheck                          not installed')" "a missing shellcheck is a skip"

test_start "lint_fix_without_shfmt_fails"
setup FMT
rm "$W/stubs/shfmt"
lint --fix
assert_equals "1:yes" "$RC:$(has 'cannot auto-fix')" "--fix needs shfmt"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
