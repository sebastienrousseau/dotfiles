#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Unit coverage for scripts/qa/check-feature-matrix.sh, the drift gate over
# docs/reference/FEATURE-MATRIX.md.
#
# Follows the shape of its siblings here (test_qa_traceability_coverage.sh,
# test_qa_docs_coverage.sh): assert the script and its document exist, that
# the contract passes as shipped, and — the part that matters — that the gate
# actually FAILS on each class of drift it claims to catch. A gate nobody has
# watched fail is only decoration.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck source=../../../tests/framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

GATE="$REPO_ROOT/scripts/qa/check-feature-matrix.sh"
MATRIX="$REPO_ROOT/docs/reference/FEATURE-MATRIX.md"

test_start "check_feature_matrix_script_exists"
assert_file_exists "$GATE" "feature matrix gate should exist"

test_start "check_feature_matrix_script_syntax"
assert_exit_code 0 "bash -n '$GATE'"

test_start "feature_matrix_doc_exists"
assert_file_exists "$MATRIX" "FEATURE-MATRIX.md should exist"

test_start "feature_matrix_doc_has_rows"
assert_file_contains "$MATRIX" "| \`dot " "matrix should carry per-command rows"

test_start "check_feature_matrix_passes"
assert_exit_code 0 "bash '$GATE' --quiet"

# ── Drift detection ────────────────────────────────────────────────────────
#
# Each case copies the repo into a scratch dir, breaks exactly one thing, and
# requires the gate to notice. A copy rather than an edit in place: the gate
# reads the real tree, and a test must never leave the checkout mutated.

fm_gate_scratch() {
  local dest
  dest="$(mktemp -d -t fmgate.XXXXXX)"
  mkdir -p "$dest/docs/reference" "$dest/docs/manual" "$dest/scripts/qa" \
    "$dest/tests/regression" "$dest/benches" "$dest/bin" \
    "$dest/scripts/dot/commands" "$dest/examples"
  cp "$GATE" "$dest/scripts/qa/"
  cp "$MATRIX" "$dest/docs/reference/"
  cp "$REPO_ROOT/docs/manual/command-index.md" "$dest/docs/manual/"
  cp "$REPO_ROOT/bin/dot" "$dest/bin/"
  cp "$REPO_ROOT/benches/dot_command_bench.sh" "$dest/benches/"
  cp "$REPO_ROOT"/tests/regression/test_feature_matrix_*.sh "$dest/tests/regression/" 2>/dev/null
  cp "$REPO_ROOT"/scripts/dot/commands/*.sh "$dest/scripts/dot/commands/" 2>/dev/null
  cp "$REPO_ROOT"/examples/*.sh "$dest/examples/" 2>/dev/null
  printf '%s\n' "$dest"
}

# The scratch copy must itself be clean, or the drift cases below prove nothing.
scratch="$(fm_gate_scratch)"
test_start "check_feature_matrix_passes_on_a_faithful_copy"
assert_exit_code 0 "cd '$scratch' && REPO_ROOT='$scratch' bash '$scratch/scripts/qa/check-feature-matrix.sh' --quiet"

# 1. A routable command whose rows have been deleted.
test_start "check_feature_matrix_detects_a_command_with_no_row"
grep -v '^| `dot locks`' "$MATRIX" >"$scratch/docs/reference/FEATURE-MATRIX.md"
assert_exit_code 1 "cd '$scratch' && REPO_ROOT='$scratch' bash '$scratch/scripts/qa/check-feature-matrix.sh' --quiet"

# 2. A row naming a test function that does not exist.
test_start "check_feature_matrix_detects_a_missing_test_function"
sed 's/`test_fm_cd`/`test_fm_no_such_function`/' "$MATRIX" \
  >"$scratch/docs/reference/FEATURE-MATRIX.md"
assert_exit_code 1 "cd '$scratch' && REPO_ROOT='$scratch' bash '$scratch/scripts/qa/check-feature-matrix.sh' --quiet"

# 3. A row naming a benchmark id the harness does not produce.
test_start "check_feature_matrix_detects_a_missing_benchmark_id"
sed 's/`run:cd`/`run:no-such-benchmark`/' "$MATRIX" \
  >"$scratch/docs/reference/FEATURE-MATRIX.md"
assert_exit_code 1 "cd '$scratch' && REPO_ROOT='$scratch' bash '$scratch/scripts/qa/check-feature-matrix.sh' --quiet"

# 4. A row naming an example that does not exist.
test_start "check_feature_matrix_detects_a_missing_example"
sed 's|`examples/example-dot-core.sh`|`examples/example-dot-gone.sh`|' "$MATRIX" \
  >"$scratch/docs/reference/FEATURE-MATRIX.md"
assert_exit_code 1 "cd '$scratch' && REPO_ROOT='$scratch' bash '$scratch/scripts/qa/check-feature-matrix.sh' --quiet"

rm -rf "$scratch"

test_start "check_feature_matrix_left_the_checkout_clean"
assert_exit_code 0 "bash '$GATE' --quiet"

print_summary
