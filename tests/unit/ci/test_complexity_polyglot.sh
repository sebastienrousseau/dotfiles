#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# tools/ci/complexity_polyglot.py: the Python (ruff) and Go (golangci-lint)
# ratchets run end to end in a scratch git repo holding a copy of the tool,
# its ruff.toml and golangci config (the tool measures the repo it lives
# in), plus tools/ci/check-baseline-shrink.py against a base commit.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CX_TMP="$(mktemp -d)"
trap 'rm -rf "$CX_TMP"' EXIT
REPO="$CX_TMP/repo"
TOOL=tools/ci/complexity_polyglot.py

out="" rc=0
run_tool() {
  out=$(cd "$REPO" && python3 "$TOOL" "$@" 2>&1)
  rc=$?
}

# py_branches <n>: a Python function with n `if` arms (cc = n + 1).
py_branches() {
  echo "def big(x):"
  for i in $(seq 1 "$1"); do printf '    if x == %s:\n        return %s\n' "$i" "$i"; done
  printf '    return 0\n\n\ndef small():\n    return 1\n'
}

# go_branches <n> [directive]: a Go function with n `if` arms.
go_branches() {
  printf 'package demo\n\nfunc Big(x int) int {%s\n' "${2:+ $2}"
  for i in $(seq 1 "$1"); do printf '\tif x == %s {\n\t\treturn %s\n\t}\n' "$i" "$i"; done
  printf '\treturn 0\n}\n'
}

setup_repo() {
  mkdir -p "$REPO/tools/ci" "$REPO/py" "$REPO/mod"
  cp "$REPO_ROOT/$TOOL" "$REPO_ROOT/tools/ci/golangci-complexity.yml" \
    "$REPO_ROOT/tools/ci/check-baseline-shrink.py" "$REPO/tools/ci/"
  cp "$REPO_ROOT/ruff.toml" "$REPO/ruff.toml"
  # The module config: the limits and the generated block, as in the repo.
  cp "$REPO_ROOT/fuzz/.golangci.yml" "$REPO/mod/.golangci.yml"
  python3 - "$REPO/mod/.golangci.yml" "$REPO/tools/ci" <<'PY'
import re, sys
sys.path.insert(0, sys.argv[2])
import complexity_polyglot as cx

p = sys.argv[1]
s = open(p).read()
block = re.compile(r"^ *# BEGIN complexity baseline.*?# END complexity baseline$", re.S | re.M)
open(p, "w").write(block.sub(lambda _: cx.render_block("mod", []), s))
PY
  printf 'module example.com/demo\n\ngo 1.22\n' >"$REPO/mod/go.mod"
  py_branches 3 >"$REPO/py/code.py"
  go_branches 3 >"$REPO/mod/demo.go"
  git -C "$REPO" init -q
  git -C "$REPO" add -A
  git -C "$REPO" -c user.name=t -c user.email=t@t commit -q -m init --no-gpg-sign
}

if ! command -v ruff >/dev/null 2>&1; then
  test_start "complexity_polyglot_needs_ruff"
  assert_true "true" "ruff not installed; skipped"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 0
fi
setup_repo

# ── python ─────────────────────────────────────────────────────────────
test_start "python_under_limits_passes"
run_tool --lang python
assert_equals "0" "$rc" "cc 4 is under the limit of 10: $out"

test_start "python_new_complex_function_fails"
py_branches 12 >"$REPO/py/code.py"
run_tool --lang python
assert_equals "1" "$rc" "cc 13 with no baseline row fails"
assert_contains "py/code.py::big: new complex function (cc=13>10" "$out" "names the function and limit"

test_start "python_noqa_does_not_hide_a_function"
sed -i.bak 's/^def big(x):/def big(x):  # noqa: C901/' "$REPO/py/code.py"
run_tool --lang python
assert_equals "1" "$rc" "a noqa comment does not exempt the function"

test_start "python_baselined_function_passes"
run_tool --lang python --write-baseline
run_tool --lang python
assert_equals "0" "$rc" "at its ceiling: $out"
assert_contains "  13   12   12 py/code.py::big" "$(cat "$REPO/tools/ci/complexity-baseline-python.txt")" \
  "the baseline row has the shell layout: measures, then path::function"

test_start "python_baselined_function_worsens_fails"
py_branches 13 >"$REPO/py/code.py"
run_tool --lang python
assert_equals "1" "$rc" "one more branch fails"
assert_contains "py/code.py::big: worse on cc 13->14" "$out" "old and new cc are shown"

test_start "python_improvement_is_reported"
py_branches 11 >"$REPO/py/code.py"
run_tool --lang python
assert_equals "0" "$rc" "below the ceiling passes"
assert_contains "1 baselined python function(s) improved" "$out" "the refactor is noticed"

test_start "python_ruff_toml_drift_fails"
sed -i.bak 's/^max-complexity = 10/max-complexity = 12/' "$REPO/ruff.toml"
run_tool --lang python
assert_equals "1" "$rc" "ruff.toml and the tool disagree"
assert_contains "ruff.toml: cc limit 12 != 10" "$out" "the drift is named"
sed -i.bak 's/^max-complexity = 12/max-complexity = 10/' "$REPO/ruff.toml"

# ── go ─────────────────────────────────────────────────────────────────
if command -v golangci-lint >/dev/null 2>&1 && command -v go >/dev/null 2>&1; then
  test_start "go_under_limits_passes"
  run_tool --lang go
  assert_equals "0" "$rc" "cc 4 is under the limit of 10: $out"

  test_start "go_new_complex_function_fails"
  go_branches 12 >"$REPO/mod/demo.go"
  run_tool --lang go
  assert_equals "1" "$rc" "cc 13 with no baseline row fails"
  assert_contains "mod/demo.go::Big: new complex function (cc=13>10" "$out" "names the function and limit"

  test_start "go_baseline_writes_the_module_exclusion"
  run_tool --lang go --write-baseline
  run_tool --lang go
  assert_equals "0" "$rc" "at its ceiling: $out"
  assert_contains "source: '^func Big\\b'" "$(cat "$REPO/mod/.golangci.yml")" "the module config excludes Big"

  test_start "go_module_lint_honours_the_generated_block"
  mod_out=$(cd "$REPO/mod" && golangci-lint run --allow-parallel-runners --enable-only gocyclo ./... 2>&1)
  assert_contains "0 issues" "$mod_out" "the module's own lint stays green on a baselined function"

  test_start "go_stale_module_block_fails"
  sed -i.bak "s/'^func Big\\\\b'/'^func Other\\\\b'/" "$REPO/mod/.golangci.yml"
  run_tool --lang go
  assert_equals "1" "$rc" "a hand-edited block is out of date"
  assert_contains "exclusion block out of date" "$out" "the stale block is named"
  run_tool --lang go --write-baseline

  test_start "go_baselined_function_worsens_fails"
  go_branches 13 >"$REPO/mod/demo.go"
  run_tool --lang go
  assert_equals "1" "$rc" "one more branch fails"
  assert_contains "mod/demo.go::Big: worse on cc 13->14" "$out" "old and new cc are shown"

  test_start "go_nolint_for_a_complexity_linter_fails"
  go_branches 12 "//nolint:gocyclo // demo" >"$REPO/mod/demo.go"
  run_tool --lang go
  assert_equals "1" "$rc" "a nolint directive is refused"
  assert_contains "mod/demo.go:3: //nolint hides a complexity linter" "$out" "the directive is located"
else
  test_start "complexity_polyglot_go_needs_golangci_lint"
  assert_true "true" "go or golangci-lint not installed; Go cases skipped"
fi

# ── the shrink guard ───────────────────────────────────────────────────
git -C "$REPO" add -A
git -C "$REPO" -c user.name=t -c user.email=t@t commit -q -m baselines --no-gpg-sign
BASE_FILE="$REPO/tools/ci/complexity-baseline-python.txt"
# set_ceiling <cc>: rewrite the cc ceiling of py/code.py::big in the fixture.
set_ceiling() {
  python3 - "$BASE_FILE" "$1" <<'PY'
import re, sys
path, cc = sys.argv[1], int(sys.argv[2])
text = open(path).read()
open(path, "w").write(re.sub(r"^ *\d+( +12 +12 py/code.py::big)$", f"{cc:4d}\\1", text, flags=re.M))
PY
}
shrink() {
  out=$(cd "$REPO" && python3 tools/ci/check-baseline-shrink.py --base HEAD tools/ci/complexity-baseline-python.txt 2>&1)
  rc=$?
}

test_start "shrink_guard_passes_unchanged"
shrink
assert_equals "0" "$rc" "an unchanged baseline passes: $out"

test_start "shrink_guard_passes_a_lowered_ceiling"
set_ceiling 12
shrink
assert_equals "0" "$rc" "a lower ceiling passes: $out"

test_start "shrink_guard_fails_a_raised_ceiling"
set_ceiling 14
shrink
assert_equals "1" "$rc" "a raised ceiling fails"
assert_contains "py/code.py::big raised (column 1 13->14)" "$out" "the raised column is named"

test_start "shrink_guard_fails_an_added_row"
git -C "$REPO" show HEAD:tools/ci/complexity-baseline-python.txt >"$BASE_FILE"
echo "  11    1    1 py/code.py::other" >>"$BASE_FILE"
shrink
assert_equals "1" "$rc" "a new row fails"
assert_contains "new row py/code.py::other" "$out" "the added row is named"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
