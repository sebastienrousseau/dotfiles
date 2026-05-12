#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for scripts/ci/check-shell-preamble.sh — the lint rule
# that enforces `set -euo pipefail` (bash) or `set -eu` (sh) on every
# executable shell script.
#
# Regression for: GH-854
# Why: a missing-preamble file would silently swallow errors at
# runtime (commands fail and the script keeps going), which has bitten
# the project before (see the deliberate fix in commit 970b631d that
# upgraded executable_dot-load-benchmark from `set -e` to the full
# triple).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

CHECKER="$REPO_ROOT/scripts/ci/check-shell-preamble.sh"

# -----------------------------------------------------------------------------
# Structural
# -----------------------------------------------------------------------------

test_start "checker_exists"
assert_file_exists "$CHECKER" "shell preamble checker should exist"

test_start "checker_executable"
[[ -x "$CHECKER" ]] && assert_exit_code 0 "true" || assert_exit_code 0 "false  # checker must be executable"

# -----------------------------------------------------------------------------
# Behavioural: fixtures
# -----------------------------------------------------------------------------

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Fixture 1: bash file WITHOUT preamble — must be REJECTED.
cat > "$tmp/missing_bash.sh" <<'EOF'
#!/usr/bin/env bash
echo "no preamble"
EOF
chmod +x "$tmp/missing_bash.sh"

test_start "rejects_bash_without_preamble"
if "$CHECKER" "$tmp/missing_bash.sh" >/dev/null 2>&1; then
  assert_exit_code 0 "false  # checker accepted a bash file with no preamble"
else
  assert_exit_code 0 "true"
fi

# Fixture 2: bash file WITH preamble — must be ACCEPTED.
cat > "$tmp/ok_bash.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "all good"
EOF
chmod +x "$tmp/ok_bash.sh"

test_start "accepts_bash_with_preamble"
if "$CHECKER" "$tmp/ok_bash.sh" >/dev/null 2>&1; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # checker rejected a bash file with set -euo pipefail"
fi

# Fixture 3: sh file WITH `set -eu` — must be ACCEPTED.
cat > "$tmp/ok_sh.sh" <<'EOF'
#!/bin/sh
set -eu
echo "posix-safe"
EOF
chmod +x "$tmp/ok_sh.sh"

test_start "accepts_sh_with_eu"
if "$CHECKER" "$tmp/ok_sh.sh" >/dev/null 2>&1; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # checker rejected a sh file with set -eu"
fi

# Fixture 4: bash file with `Sourced by` header — must be ACCEPTED
# regardless of preamble.
cat > "$tmp/sourced_lib.sh" <<'EOF'
#!/usr/bin/env bash
# Sourced by parent.sh; inherits set -euo pipefail.
echo "fragment"
EOF

test_start "accepts_sourced_marker"
if "$CHECKER" "$tmp/sourced_lib.sh" >/dev/null 2>&1; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # checker rejected a file with Sourced-by marker"
fi

# Fixture 5: `preamble:skip` marker — must be ACCEPTED.
cat > "$tmp/skip_marker.sh" <<'EOF'
#!/usr/bin/env bash
# preamble:skip — opt-out for completion / init fragments.
echo "intentionally lenient"
EOF

test_start "accepts_skip_marker"
if "$CHECKER" "$tmp/skip_marker.sh" >/dev/null 2>&1; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # checker rejected a file with preamble:skip marker"
fi

# -----------------------------------------------------------------------------
# Repo-level: full-tree scan must pass.
# -----------------------------------------------------------------------------

test_start "repo_scan_passes"
if (cd "$REPO_ROOT" && "$CHECKER" >/dev/null 2>&1); then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # repo-wide preamble scan failed — run scripts/ci/check-shell-preamble.sh"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
