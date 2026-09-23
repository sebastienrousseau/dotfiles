#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# The mutation gate (tools/ci/mutation-test.py) must fail a weak suite,
# not only pass a strong one. Each case builds a throwaway git repo with
# one script and a chosen set of tests, then checks the exact verdicts
# and the exit status.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$REPO_ROOT/tests/framework/assertions.sh"

ENGINE="$REPO_ROOT/tools/ci/mutation-test.py"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/mut-engine.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# fixture <name> <test files...>: repo with scripts/check.sh plus the
# named tests copied from $WORK/lib.
mkdir -p "$WORK/lib"
cat >"$WORK/lib/check.sh" <<'EOF'
#!/usr/bin/env bash
# valid_name: letters only.
valid_name() {
  [[ "$1" =~ ^[a-z]+$ ]] || return 1
  return 0
}
cat <<DOC
text with -gt and exit 1 inside a heredoc is never mutated
DOC
EOF
cat >"$WORK/lib/test_strong.sh" <<'EOF'
#!/usr/bin/env bash
source "$REPO_ROOT/scripts/check.sh" >/dev/null
valid_name abc || exit 1
valid_name 'a;b' && exit 1
valid_name 'x1' && exit 1
exit 0
EOF
cat >"$WORK/lib/test_weak.sh" <<'EOF'
#!/usr/bin/env bash
# Only the happy path: the anchor and the failure return are unprotected.
source "$REPO_ROOT/scripts/check.sh" >/dev/null
valid_name abc || exit 1
exit 0
EOF
cat >"$WORK/lib/test_grep.sh" <<'EOF'
#!/usr/bin/env bash
# Structural: fails on any edit to the source text of scripts/check.sh.
grep -qF '[[ "$1" =~ ^[a-z]+$ ]] || return 1' "$REPO_ROOT/scripts/check.sh" || exit 1
grep -qF '  return 0' "$REPO_ROOT/scripts/check.sh" || exit 1
EOF
cat >"$WORK/lib/test_broken.sh" <<'EOF'
#!/usr/bin/env bash
# Fails on the clean tree: must be dropped, never counted as a kill.
echo scripts/check.sh >/dev/null
exit 1
EOF

fixture() {
  local name="$1"
  shift
  local d="$WORK/$name"
  mkdir -p "$d/scripts" "$d/tests/unit" "$d/tools/ci"
  cp "$WORK/lib/check.sh" "$d/scripts/check.sh"
  local t
  for t in "$@"; do cp "$WORK/lib/$t" "$d/tests/unit/$t"; done
  printf 'tests/unit/test_grep.sh\n' >"$d/tools/ci/mutation-structural.txt"
  git -C "$d" init -q
  git -C "$d" add -A
  git -C "$d" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -qm init
  printf '%s' "$d"
}

run_engine() {
  python3 "$ENGINE" --root "$1" --full --jobs 2 --timeout 30 --json "$1/report.json" "${@:2}" >"$1/out" 2>&1
}

status_of() { # status_of <dir> <line>
  python3 -c 'import json,sys; r=json.load(open(sys.argv[1]))
print(next(m["status"] for m in r["mutants"] if m["line"]==int(sys.argv[2])))' "$1/report.json" "$2"
}

test_start "mutation_generates_one_mutant_per_line_outside_heredocs"
d="$(fixture list test_strong.sh)"
out="$(python3 "$ENGINE" --root "$d" --full --list-mutants)"
assert_equals "2" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "lines 4 and 5, none of the heredoc"
assert_contains 'scripts/check.sh:4	anchor	[[ "$1" =~ [a-z]+$ ]] || return 1' "$out" "anchor has priority on line 4"
assert_contains 'scripts/check.sh:5	success	return 1' "$out" "success return mutated on line 5"

test_start "mutation_strong_suite_kills_everything"
d="$(fixture strong test_strong.sh)"
run_engine "$d" --min-score 100
assert_equals "0" "$?" "a strong suite passes a 100% gate"
assert_equals "killed" "$(status_of "$d" 4)" "anchor mutant killed"
assert_equals "killed" "$(status_of "$d" 5)" "success-return mutant killed"

test_start "mutation_weak_suite_fails_the_gate"
d="$(fixture weak test_weak.sh)"
run_engine "$d" --min-score 80
assert_equals "1" "$?" "a weak suite fails an 80% gate"
assert_equals "survived" "$(status_of "$d" 4)" "anchor mutant survives the happy-path test"
assert_contains "SURVIVED scripts/check.sh:4 [anchor]" "$(cat "$d/out")" "survivor reported with location"

test_start "mutation_structural_kills_do_not_count"
d="$(fixture structural test_weak.sh test_grep.sh)"
run_engine "$d" --min-score 80
assert_equals "1" "$?" "a source-grep test cannot rescue the score"
assert_equals "survived" "$(status_of "$d" 4)" "grep test excluded from kills"

test_start "mutation_baseline_failures_are_dropped"
d="$(fixture broken test_weak.sh test_broken.sh)"
run_engine "$d"
assert_contains "dropped tests/unit/test_broken.sh: fail on the unmutated tree" "$(cat "$d/out")" "failing test dropped"
assert_equals "survived" "$(status_of "$d" 4)" "a test failing on the clean tree kills nothing"

test_start "mutation_no_related_tests_counts_as_survived"
d="$(fixture none)"
run_engine "$d" --min-score 1
assert_equals "1" "$?" "untested code fails the gate"
assert_equals "no-tests" "$(status_of "$d" 4)" "reported as no-tests"

test_start "mutation_changed_lines_only"
d="$(fixture changed test_strong.sh)"
sed -i.bak 's/^  return 0$/  return 0 # touched/' "$d/scripts/check.sh" && rm "$d/scripts/check.sh.bak"
git -C "$d" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -qam touch
out="$(python3 "$ENGINE" --root "$d" --base HEAD~1 --list-mutants)"
assert_equals "scripts/check.sh:5	success	return 1 # touched" "$out" "only the changed line is mutated"

test_start "mutation_ignore_needs_a_reason"
d="$(fixture ignore test_strong.sh)"
sed -i.bak 's/^  return 0$/  return 0 # mutation: ignore/' "$d/scripts/check.sh" && rm "$d/scripts/check.sh.bak"
python3 "$ENGINE" --root "$d" --full --list-mutants >"$d/out" 2>&1
assert_equals "2" "$?" "a bare ignore is rejected"
sed -i.bak 's/# mutation: ignore$/# mutation: ignore equivalent: last statement/' "$d/scripts/check.sh" && rm "$d/scripts/check.sh.bak"
out="$(python3 "$ENGINE" --root "$d" --full --list-mutants)"
assert_equals "1" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "an ignore with a reason skips the line"

test_start "mutation_noop_or_true_is_not_mutated"
out="$(
  printf '%s\n' 'x || true' 'y && :' 'z || echo fallback' >"$WORK/noop.sh"
  python3 - "$ENGINE" "$WORK/noop.sh" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("m", sys.argv[1]); m = importlib.util.module_from_spec(spec)
sys.modules["m"] = m; spec.loader.exec_module(m)
for ln in open(sys.argv[2]).read().splitlines():
    r = m.mutate_line(ln); print(r[2] if r else "-")
PY
)"
assert_equals $'-\n-\nz && echo fallback' "$out" "only the meaningful fallback is mutated"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
