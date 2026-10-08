#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# tools/ci/check-workflow-hardening.py must flag `${{ }}` expressions an
# attacker can steer when they are expanded inside a run: script, let the
# same values through env:, hold legacy findings to the baseline, and flag a
# read-only job's checkout that keeps the token in git config. The last
# cases run it on the release workflows themselves.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

LINT="$REPO_ROOT/tools/ci/check-workflow-hardening.py"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/wf-harden.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# lint_case <name>: run the lint in a fresh fixture repo whose only
# workflow is stdin. Sets rc and leaves the output in $WORK/<name>.out.
lint_case() {
  local name="$1"
  shift
  local repo="$WORK/$name"
  mkdir -p "$repo/.github/workflows"
  cat >"$repo/.github/workflows/w.yml"
  rc=0
  (cd "$repo" && python3 "$LINT" --allowlist "$repo/allow" --baseline "$repo/base" "$@") \
    >"$WORK/$name.out" 2>&1 || rc=$?
  out="$(cat "$WORK/$name.out")"
}

# refute_contains <needle> <msg>: the last lint output lacks <needle>.
refute_contains() {
  if [[ "$out" == *"$1"* ]]; then
    assert_equals "absent" "present" "$2 ($1)"
  else
    assert_equals "absent" "absent" "$2"
  fi
}

# expect <want rc> <want substring, or empty for "no findings">
expect() {
  assert_equals "$1" "$rc" "exit code"
  if [[ -n "$2" ]]; then
    assert_contains "$2" "$out" "reports $2"
  else
    refute_contains "w.yml:" "no findings"
  fi
}

test_start "flags_release_tag_in_block_run"
lint_case "$CURRENT_TEST" <<'EOF'
jobs:
  a:
    steps:
      - name: Resolve
        run: |
          set -euo pipefail
          TAG="${{ github.event.release.tag_name || inputs.release_tag }}"
EOF
expect 1 ".github/workflows/w.yml:7: github.event.release.tag_name"
assert_contains ".github/workflows/w.yml:7: inputs.release_tag" "$out" "second operand of || reported"

test_start "flags_inline_run"
lint_case "$CURRENT_TEST" <<'EOF'
jobs:
  a:
    steps:
      - run: echo "${{ github.head_ref }}"
EOF
expect 1 "w.yml:4: github.head_ref"

test_start "flags_step_output_ref_name_and_secret"
lint_case "$CURRENT_TEST" <<'EOF'
jobs:
  a:
    steps:
      - id: v
        run: echo "x=1" >> "$GITHUB_OUTPUT"
      - run: |
          V="${{ steps.v.outputs.x }}"
          git push origin "${{ github.ref_name }}"
          git clone "https://${{ secrets.TAP_PUSH_TOKEN }}@github.com/o/r.git"
          gh api -H "Authorization: ${{ github.token }}" /user
EOF
expect 1 "w.yml:7: steps.v.outputs.x"
assert_contains "w.yml:8: github.ref_name" "$out" "ref_name reported"
assert_contains "w.yml:9: secrets.TAP_PUSH_TOKEN" "$out" "secret in URL reported"
assert_contains "w.yml:10: github.token" "$out" "github.token reported"

# The same values through env:, numeric/SHA event fields, unrelated
# contexts, and an expression in the key that follows a run: block.
test_start "allows_env_safe_fields_and_block_end"
lint_case "$CURRENT_TEST" <<'EOF'
jobs:
  a:
    steps:
      - name: Safe
        env:
          TAG: ${{ github.event.release.tag_name }}
          OUT: ${{ steps.v.outputs.x }}
        run: |
          echo "$TAG $OUT ${{ github.event_name }} ${{ github.sha }}"
          echo "${{ github.event.pull_request.number }} ${{ github.event.pull_request.head.sha }}"
      - name: After
        run: echo done
        with:
          ref: ${{ github.head_ref }}
      - uses: x/y@0123456789012345678901234567890123456789
        with:
          tag: ${{ inputs.tag }}
EOF
expect 0 ""

test_start "allowlist_admits_named_numeric_output_only"
mkdir -p "$WORK/$CURRENT_TEST"
printf '%s\n' '.github/workflows/w.yml v.count   # wc -l' >"$WORK/$CURRENT_TEST/allow"
lint_case "$CURRENT_TEST" <<'EOF'
jobs:
  a:
    steps:
      - run: |
          echo "${{ steps.v.outputs.count }}"
          echo "${{ steps.v.outputs.name }}"
EOF
expect 1 "w.yml:6: steps.v.outputs.name"
refute_contains "steps.v.outputs.count" "allowlisted output passes"

test_start "baseline_holds_count_and_fails_above_it"
mkdir -p "$WORK/$CURRENT_TEST"
printf '%s\n' '# <file> <expression> <count>' '.github/workflows/w.yml inputs.x 1   # legacy, see #1' >"$WORK/$CURRENT_TEST/base"
lint_case "$CURRENT_TEST" <<'EOF'
jobs:
  a:
    steps:
      - run: echo "${{ inputs.x }}"
      - run: echo "${{ inputs.x }}"
EOF
expect 1 "w.yml:5: inputs.x"
refute_contains "w.yml:4:" "first occurrence covered by the baseline"

test_start "no_baseline_ignores_baseline_file"
mkdir -p "$WORK/$CURRENT_TEST"
printf '%s\n' '.github/workflows/w.yml inputs.x 5' >"$WORK/$CURRENT_TEST/base"
lint_case "$CURRENT_TEST" --no-baseline <<'EOF'
jobs:
  a:
    steps:
      - run: echo "${{ inputs.x }}"
EOF
expect 1 "w.yml:4: inputs.x"

test_start "write_baseline_records_counts"
lint_case "$CURRENT_TEST" --write-baseline <<'EOF'
jobs:
  a:
    steps:
      - run: echo "${{ inputs.x }} ${{ inputs.x }}"
EOF
assert_equals "0" "$rc" "write exits 0"
assert_equals ".github/workflows/w.yml inputs.x 2" "$(grep -v '^#' "$WORK/$CURRENT_TEST/base")" "count per expression"

test_start "flags_read_only_checkout_keeping_credentials"
lint_case "$CURRENT_TEST" <<'EOF'
jobs:
  lint:
    steps:
      - uses: actions/checkout@0123456789012345678901234567890123456789 # v7
      - name: Checkout again
        uses: actions/checkout@0123456789012345678901234567890123456789 # v7
        with:
          fetch-depth: 0
      - run: make lint
  safe:
    steps:
      - uses: actions/checkout@0123456789012345678901234567890123456789 # v7
        with:
          persist-credentials: false
  pusher:
    steps:
      - uses: actions/checkout@0123456789012345678901234567890123456789 # v7
      - run: git push origin HEAD
EOF
expect 1 "w.yml:4: checkout without persist-credentials: false"
assert_contains "w.yml:6: checkout without persist-credentials: false" "$out" "name/uses form reported"
refute_contains "w.yml:12:" "persist-credentials: false passes"
refute_contains "w.yml:17:" "a job that pushes keeps its credentials"

# A banner comment at column 0 between jobs does not end the jobs: map,
# and a later top-level key does.
test_start "column_zero_comment_keeps_scanning_jobs"
lint_case "$CURRENT_TEST" <<'EOF'
jobs:
  first:
    steps:
      - run: make
# ======================= NIGHTLY =======================
  nightly:
    steps:
      - uses: actions/checkout@0123456789012345678901234567890123456789 # v7
env:
  jobs_like:
    steps:
      - uses: actions/checkout@0123456789012345678901234567890123456789 # v7
EOF
expect 1 "w.yml:8: checkout without persist-credentials: false"
refute_contains "w.yml:12:" "a checkout outside jobs: is not a job step"

test_start "persist_flag_on_a_later_step_does_not_count"
lint_case "$CURRENT_TEST" <<'EOF'
jobs:
  lint:
    steps:
      - uses: actions/checkout@0123456789012345678901234567890123456789 # v7
      - uses: other/action@0123456789012345678901234567890123456789
        with:
          persist-credentials: false
EOF
expect 1 "w.yml:4: checkout without persist-credentials: false"

# ── The real workflows ──────────────────────────────────────────────
# The release, version-sync and nightly workflows run with write tokens
# or signing keys: they must be clean with no baseline at all.
test_start "release_workflows_are_clean_without_baseline"
rc=0
(cd "$REPO_ROOT" && python3 "$LINT" --no-baseline \
  .github/workflows/release-distribute-scoop.yml \
  .github/workflows/release-distribute-homebrew.yml \
  .github/workflows/release-distribute-aur.yml \
  .github/workflows/sync-versions.yml \
  .github/workflows/nightly.yml \
  .github/workflows/install-fuzz.yml) >"$WORK/real.out" 2>&1 || rc=$?
assert_equals "0" "$rc" "no findings: $(head -5 "$WORK/real.out" | tr '\n' ' ')"

test_start "repository_is_within_baseline"
rc=0
(cd "$REPO_ROOT" && python3 "$LINT") >"$WORK/repo.out" 2>&1 || rc=$?
assert_equals "0" "$rc" "repo scan: $(head -5 "$WORK/repo.out" | tr '\n' ' ')"

# Write scopes belong on the one job that uses them, never workflow-wide.
# top_permissions <file>: the top-level permissions: keys, space-separated.
top_permissions() {
  awk '/^permissions:/ { on = 1; next }
    on && /^[^ #]/ { exit }
    on && /^  [a-z-]+:/ { sub(/:.*/, ""); gsub(/ /, ""); printf "%s ", $0 }' "$1" | sed 's/ $//'
}
# jobs_writing <file> <scope>: jobs that grant <scope>: write.
jobs_writing() {
  awk -v want="$2" '/^jobs:/ { on = 1 }
    on && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ { job = $1; sub(/:/, "", job) }
    on && $1 == want ":" && $2 == "write" { print job }' "$1"
}

test_start "nightly_grants_read_only_contents"
assert_equals "contents" "$(top_permissions "$REPO_ROOT/.github/workflows/nightly.yml")" "top-level permissions"
assert_equals "" "$(jobs_writing "$REPO_ROOT/.github/workflows/nightly.yml" issues)" "no job writes issues"

test_start "install_fuzz_scopes_issue_write_to_report_job"
assert_equals "contents" "$(top_permissions "$REPO_ROOT/.github/workflows/install-fuzz.yml")" "top-level permissions"
assert_equals "report-failure" "$(jobs_writing "$REPO_ROOT/.github/workflows/install-fuzz.yml" issues)" "only the failure reporter writes issues"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
