#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# tools/docs/gen_ci_gates.py renders docs/ci-gates.toml and the workflows
# into DEVELOPMENT.md's table: one row per job, with the command that
# reproduces it, its egress policy and the secrets it reads. --check fails
# when a workflow has no entry, a command names a missing make target or
# script, or the table was edited by hand.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

GEN="$REPO_ROOT/tools/docs/gen_ci_gates.py"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/gen-ci-gates-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/.github/workflows" "$WORK/docs" "$WORK/scripts"
printf 'lint:\n\techo lint\n' >"$WORK/Makefile"
: >"$WORK/scripts/check.sh"
cat >"$WORK/.github/workflows/lint.yml" <<'EOF'
name: Lint
on: push
jobs:
  shell:
    name: Lint / Shell
    runs-on: ubuntu-latest
    steps:
      - uses: step-security/harden-runner@abc
        with:
          egress-policy: block
      - run: make lint
  links:
    name: Lint / Links
    runs-on: ubuntu-latest
    steps:
      - uses: step-security/harden-runner@abc
        with:
          egress-policy: block
          allowed-endpoints: >
            github.com:443
      - run: bash scripts/check.sh
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: step-security/harden-runner@abc
        with:
          egress-policy: audit
      - run: echo "${{ secrets.NPM_TOKEN }} ${{ secrets.GITHUB_TOKEN }}"
  shared:
    uses: ./.github/workflows/other.yml
EOF
cat >"$WORK/docs/ci-gates.toml" <<'EOF'
[workflows."lint.yml"]
local = "make lint"
jobs.links = "bash scripts/check.sh"
jobs.publish = "none: publishes on release"
EOF
printf '# Development\n\nIntro.\n\n<!-- BEGIN GENERATED: docs/ci-gates.toml -->\nold\n<!-- END GENERATED -->\n\nAfter.\n' \
  >"$WORK/DEVELOPMENT.md"

# gen ARGS...: run the generator against the fixture; sets rc and out.
gen() {
  rc=0
  out="$(python3 "$GEN" --root "$WORK" "$@" 2>&1)" || rc=$?
}

test_start "stale_table_fails_check"
gen --check
assert_equals "1" "$rc" "the placeholder is stale"

test_start "every_job_gets_a_row"
gen
assert_equals "0" "$rc" "generation succeeds"
doc="$(cat "$WORK/DEVELOPMENT.md")"
assert_contains '| `lint.yml` | Lint / Shell | `make lint` | blocked | — |' "$doc" "a blocked job with the workflow's command"
assert_contains '| `lint.yml` | Lint / Links | `bash scripts/check.sh` | allow-listed | — |' "$doc" "a job's own command and an allow-list"
assert_contains '| `lint.yml` | publish | none: publishes on release | unrestricted | `NPM_TOKEN` |' "$doc" "an unnamed job, no local run, its secret but not GITHUB_TOKEN"
assert_contains '| `lint.yml` | shared | `make lint` | reusable | — |' "$doc" "a reusable-workflow job"
assert_contains "Intro." "$doc" "text before the markers is kept"
assert_contains "After." "$doc" "and after"

test_start "fresh_table_passes_check"
gen --check
assert_equals "0" "$rc" "a regenerated table is current"

test_start "hand_edit_fails_check"
sed -i.bak 's/| blocked |/| unrestricted |/' "$WORK/DEVELOPMENT.md"
gen --check
assert_equals "1" "$rc" "a hand edit fails"
gen

test_start "workflow_without_entry_fails"
printf 'name: New\non: push\njobs:\n  x:\n    runs-on: ubuntu-latest\n    steps:\n      - run: true\n' \
  >"$WORK/.github/workflows/new.yml"
gen --check
assert_equals "1" "$rc" "a workflow with no entry in docs/ci-gates.toml fails"
assert_contains "new.yml" "$out" "and is named"
rm "$WORK/.github/workflows/new.yml"

test_start "missing_make_target_fails"
sed -i.bak 's/local = "make lint"/local = "make lnt"/' "$WORK/docs/ci-gates.toml"
gen --check
assert_equals "1" "$rc" "a command naming a make target that does not exist fails"
assert_contains "make lnt" "$out" "the target is named"
sed -i.bak 's/local = "make lnt"/local = "make lint"/' "$WORK/docs/ci-gates.toml"

test_start "missing_script_fails"
sed -i.bak 's|scripts/check.sh|scripts/gone.sh|' "$WORK/docs/ci-gates.toml"
gen --check
assert_equals "1" "$rc" "a command naming a script that does not exist fails"
assert_contains "scripts/gone.sh" "$out" "the script is named"

test_start "repository_table_is_current"
rc=0
out="$(python3 "$GEN" --check 2>&1)" || rc=$?
assert_equals "0" "$rc" "DEVELOPMENT.md matches docs/ci-gates.toml and the workflows"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
