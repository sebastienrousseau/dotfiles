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

test_start "repository_readme_has_both_blocks"
out="$(bash "$DRILL" --print)"
assert_contains "bash \"\$installer_dir/dotfiles-install.sh\"" "$out" "the verified installer runs"
assert_contains "dot doctor" "$out" "then the Quick Start commands"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
