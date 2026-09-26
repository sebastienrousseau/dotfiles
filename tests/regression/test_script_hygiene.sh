#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# test-kind: structural
# Repo-wide hygiene for every shell script meant to be executed: a portable
# shebang (#!/usr/bin/env <interpreter>, or #!/bin/sh), and bash scripts
# must parse (bash -n). This replaces the per-file shebang and `bash -n`
# checks that the behavioural suites used to carry. The CI lint job
# runs shellcheck on every *.sh file; the extensionless bash executables it cannot
# see are shellchecked here at the same severity.
#
# Structural by design: a shebang and parseability are properties of the
# file, not of its behaviour. One assertion per test_start.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

mapfile -t SCRIPTS < <(cd "$REPO_ROOT" && git ls-files 'scripts/*.sh' 'scripts/**/*.sh' 'tools/*.sh' 'tools/**/*.sh' \
  'install.sh' 'install/*.sh' 'install/**/*.sh' 'lib/*.sh' 'lib/**/*.sh' 'bin/*' \
  'defaults/dot_local/bin/executable_*' 2>/dev/null | sort -u)

test_start "hygiene_scripts_found"
assert_true '[[ ${#SCRIPTS[@]} -gt 100 ]]' "the script inventory is non-trivial (${#SCRIPTS[@]} files)"

test_start "hygiene_portable_shebang"
bad=()
for f in "${SCRIPTS[@]}"; do
  IFS= read -r first <"$REPO_ROOT/$f" || first=""
  case "$first" in
    '#!/usr/bin/env '* | '#!/bin/sh') ;;
    *) bad+=("$f: ${first:-<empty>}") ;;
  esac
done
((${#bad[@]})) && printf '    %s\n' "${bad[@]}"
assert_equals "0" "${#bad[@]}" "every executable script starts with #!/usr/bin/env <interpreter> or #!/bin/sh"

test_start "hygiene_bash_scripts_parse"
bad=()
for f in "${SCRIPTS[@]}"; do
  IFS= read -r first <"$REPO_ROOT/$f" || first=""
  [[ "$first" == '#!/usr/bin/env bash' ]] || continue
  bash -n "$REPO_ROOT/$f" 2>/dev/null || bad+=("$f")
done
((${#bad[@]})) && printf '    %s\n' "${bad[@]}"
assert_equals "0" "${#bad[@]}" "every bash script parses (bash -n)"

test_start "hygiene_extensionless_shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  targets=()
  for f in "${SCRIPTS[@]}"; do
    [[ "$f" == *.sh ]] && continue
    IFS= read -r first <"$REPO_ROOT/$f" || first=""
    [[ "$first" == '#!/usr/bin/env bash' ]] && targets+=("$REPO_ROOT/$f")
  done
  out=$(shellcheck -x -S error -e SC1091,SC2030,SC2031 -f gcc "${targets[@]}" 2>&1)
  [[ -n "$out" ]] && printf '    %s\n' "$out"
  assert_equals "" "$out" "extensionless bash executables are shellcheck-clean (${#targets[@]} files)"
else
  assert_true "true" "shellcheck not installed; CI installs it"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
