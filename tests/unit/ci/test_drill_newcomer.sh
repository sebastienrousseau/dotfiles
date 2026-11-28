#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# tools/ci/drill-newcomer.sh --print: the commands drill A1 runs are the
# README's Install block then its Quick Start block, exactly, and nothing
# else. The drill itself installs into $HOME, so it runs only in CI.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DRILL="$REPO_ROOT/tools/ci/drill-newcomer.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/drill-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

cat >"$WORK/README.md" <<'EOF'
## Install

Text.

```bash
echo install-one
echo install-two
```

```bash
echo not-the-first-block
```

## Requirements

```bash
echo requirements
```

## Quick Start

```bash
echo quick-one
```

## Later

```bash
echo later
```
EOF

test_start "prints_install_then_quick_start"
out="$(DRILL_README="$WORK/README.md" bash "$DRILL" --print)"
assert_equals $'echo install-one\necho install-two\necho quick-one' "$out" \
  "the first bash block of each section, in order, nothing else"

test_start "a_missing_block_fails"
cat >"$WORK/no-quick.md" <<'EOF'
## Install

```bash
echo x
```
EOF
rc=0
out="$(DRILL_README="$WORK/no-quick.md" bash "$DRILL" --print 2>&1)" || rc=$?
assert_equals "1" "$rc" "no Quick Start block fails"
assert_contains "no bash block" "$out" "and says why"

# DRILL_INSTALLER: a release pull request's README pins an installer that
# is not published yet; the drill copies the branch's file in place of the
# download, and the README's digest check still runs.
cat >"$WORK/pinned.md" <<'EOF'
## Install

```bash
installer_dir="$(mktemp -d)" && curl -fsSLo "$installer_dir/dotfiles-install.sh" https://github.com/o/r/releases/download/v9.9.9/dotfiles-install-9.9.9.sh
echo "abc  $installer_dir/dotfiles-install.sh" | sha256sum -c - && bash "$installer_dir/dotfiles-install.sh"
```

## Quick Start

```bash
dot doctor
```
EOF

test_start "local_installer_replaces_only_the_download"
out="$(DRILL_INSTALLER=/repo/install.sh DRILL_README="$WORK/pinned.md" bash "$DRILL" --print)"
assert_contains "cp \"/repo/install.sh\" \"\$installer_dir/dotfiles-install.sh\"" "$out" "the download becomes a copy"
assert_contains "echo \"abc  \$installer_dir/dotfiles-install.sh\" | sha256sum -c -" "$out" "the digest check stays"
assert_equals "" "$(grep curl <<<"$out" || true)" "nothing is downloaded"

test_start "local_installer_refuses_a_block_without_a_download"
rc=0
out="$(DRILL_INSTALLER=/repo/install.sh DRILL_README="$WORK/README.md" bash "$DRILL" --print 2>&1)" || rc=$?
assert_equals "1" "$rc" "nothing to replace fails rather than running the README unchanged"
assert_contains "no installer download to replace" "$out" "and says why"

test_start "repository_readme_has_both_blocks"
out="$(bash "$DRILL" --print)"
assert_contains "bash \"\$installer_dir/dotfiles-install.sh\"" "$out" "the verified installer runs"
assert_contains "dot doctor" "$out" "then the Quick Start commands"

# --judge ELAPSED: the verdict on a `dot doctor --json` report.
judge() {
  rc=0
  out="$(printf '%s' "$2" | DRILL_BUDGET=300 bash "$DRILL" --judge "$1" 2>&1)" || rc=$?
}
CLEAN='{"status":"healthy","failures":0,"warnings":1,"results":[]}'
FAILED='{"status":"degraded","failures":2,"results":[{"name":"zsh","status":"fail"},{"name":"git","status":"ok"},{"name":"mise","status":"error"}]}'

test_start "judge_passes_a_clean_report_in_budget"
judge 120 "$CLEAN"
assert_equals "0" "$rc" "no failures within 300s passes"
assert_contains "drill: passed" "$out" "and says so"

test_start "judge_fails_a_report_with_failures"
judge 120 "$FAILED"
assert_equals "1" "$rc" "doctor failures fail the drill"
assert_contains "failed: zsh" "$out" "each failed check is named"
assert_contains "failed: mise" "$out" "errors count as failures"
assert_equals "" "$(grep -F 'failed: git' <<<"$out")" "a passing check is not listed"

test_start "judge_fails_over_budget"
judge 301 "$CLEAN"
assert_equals "1" "$rc" "a clean report past the budget fails"
assert_contains "over the 300s budget" "$out" "and says why"

test_start "judge_passes_at_the_budget"
judge 300 "$CLEAN"
assert_equals "0" "$rc" "exactly the budget passes"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
