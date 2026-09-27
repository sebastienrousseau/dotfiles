#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# tools/ci/complexity.py: the measures on hand-counted fixtures, and the
# ratchet run end to end in a scratch git repo holding a copy of the tool
# (the tool measures the repo it lives in).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TOOL="$REPO_ROOT/tools/ci/complexity.py"
CX_TMP="$(mktemp -d)"
trap 'rm -rf "$CX_TMP"' EXIT

if ! command -v shfmt >/dev/null 2>&1; then
  test_start "complexity_needs_shfmt"
  assert_true "true" "shfmt not installed; skipped"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 0
fi

# measure <file> <function>: "cc cog nloc" for one function.
measure() {
  python3 "$TOOL" --json --files "$1" | python3 -c '
import json, sys
for u in json.load(sys.stdin):
    if u["unit"].endswith("::" + sys.argv[1]):
        print(u["cc"], u["cog"], u["nloc"])' "$2"
}

cat >"$CX_TMP/sample.sh" <<'EOF'
#!/usr/bin/env bash
nested() {
  if [[ -n "$1" ]] && [[ -z "$2" ]]; then
    for x in a b; do
      if [[ "$x" == a ]]; then echo hi; fi
    done
  elif [[ "$1" == y ]]; then
    :
  else
    case "$1" in
      a | b) echo ab ;;
      c) echo c ;;
      *) echo other ;;
    esac
  fi
  a && b || c
}
same_ops() {
  a && b && c
}
mixed_ops() {
  a && b || c && d
}
test_chain() {
  [[ -n $a && -n $b && -n $c ]]
}
flat() {
  # a comment is not a line of code

  echo one
}
EOF

# cc = 1 + if + && + for + inner if + elif + two non-default arms + && + ||
# cog = if 1 + && run 1 + for (1+1) + inner if (1+2) + elif 1 + else 1
#       + case (1+1) + `a && b || c` 2
test_start "complexity_counts_nested_control_flow"
assert_equals "10 13 16" "$(measure "$CX_TMP/sample.sh" nested)" "cc/cog/nloc of the nested fixture"

test_start "complexity_one_run_of_like_operators_costs_one"
assert_equals "3 1" "$(measure "$CX_TMP/sample.sh" same_ops | cut -d' ' -f1-2)" "a && b && c"

test_start "complexity_each_operator_change_costs_one"
assert_equals "4 3" "$(measure "$CX_TMP/sample.sh" mixed_ops | cut -d' ' -f1-2)" "a && b || c && d"

test_start "complexity_counts_test_clause_operators"
assert_equals "3 1" "$(measure "$CX_TMP/sample.sh" test_chain | cut -d' ' -f1-2)" "[[ a && b && c ]]"

test_start "complexity_nloc_skips_blank_and_comment_lines"
assert_equals "1 0 3" "$(measure "$CX_TMP/sample.sh" flat)" "flat(): header, echo, closing brace"

# ── the ratchet, in a scratch repo ────────────────────────────────────
REPO="$CX_TMP/repo"
mkdir -p "$REPO/tools/ci" "$REPO/scripts"
cp "$TOOL" "$REPO/tools/ci/complexity.py"
# big(): 16 if-arms, over the cc limit of 10.
{
  echo '#!/usr/bin/env bash'
  echo 'big() {'
  for i in $(seq 1 16); do echo "  if [[ \$1 == $i ]]; then echo $i; fi"; done
  echo '}'
  printf 'small() {\n  echo ok\n}\n'
} >"$REPO/scripts/code.sh"
git -C "$REPO" init -q && git -C "$REPO" add -A

ratchet() {
  out=$(cd "$REPO" && python3 tools/ci/complexity.py "$@" 2>&1)
  rc=$?
}

test_start "ratchet_fails_on_a_new_complex_unit"
ratchet
assert_equals "1" "$rc" "big() is complex and not in the (absent) baseline"

test_start "ratchet_names_the_new_unit_and_limit"
assert_contains "scripts/code.sh::big: new complex unit (cc=17>10" "$out" "the report names unit and limit"

test_start "ratchet_passes_once_baselined"
ratchet --write-baseline
ratchet
assert_equals "0" "$rc" "the baselined unit at its ceiling passes"

test_start "ratchet_fails_when_a_baselined_unit_worsens"
python3 - "$REPO/scripts/code.sh" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace("  if [[ $1 == 16 ]]; then echo 16; fi\n", "  if [[ $1 == 16 ]]; then echo 16; fi\n  if [[ $1 == 17 ]]; then echo 17; fi\n", 1)
open(p, "w").write(s)
PY
ratchet
assert_equals "1" "$rc" "one more branch in big() fails the check"

test_start "ratchet_reports_the_worse_measure"
assert_contains "worse on cc 17->18" "$out" "the old and new cc are shown"

test_start "ratchet_notices_improvement"
python3 - "$REPO/scripts/code.sh" <<'PY'
import sys
p = sys.argv[1]
lines = [l for l in open(p) if "== 17 ]]" not in l and "== 16 ]]" not in l]
open(p, "w").write("".join(lines))
PY
ratchet
assert_contains "1 baselined unit(s) improved" "$out" "a refactor below the ceiling is reported"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
