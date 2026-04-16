#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/ci/check-copyright-headers.sh"

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "check-copyright-headers.sh must exist"

test_start "script_is_executable"
if [[ -x "$SCRIPT_FILE" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: script must be executable"
fi

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: invalid bash syntax"
fi

test_start "uses_set_euo_pipefail"
assert_file_contains "$SCRIPT_FILE" "set -euo pipefail" "must use strict mode"

test_start "accepts_extensions_flag"
assert_file_contains "$SCRIPT_FILE" -- "--extensions=" "must accept --extensions=<list>"

test_start "accepts_excludes_flag"
assert_file_contains "$SCRIPT_FILE" -- "--excludes=" "must accept --excludes=<regex>"

test_start "narrow_patterns_drop_bare_c_parens"
# The bare "(c) " pattern is intentionally NOT in the list — it matches
# ordinary C-language comments. Verify it isn't present as a standalone
# array entry (a line that is just whitespace + "(c) " + end-of-line).
if grep -qE '^[[:space:]]+"\(c\) "$' "$SCRIPT_FILE"; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: '(c) ' must not be a standalone pattern"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

test_start "matches_copyright_paren_c"
assert_file_contains "$SCRIPT_FILE" "Copyright (c)" "must match Copyright (c) pattern"

test_start "matches_spdx"
assert_file_contains "$SCRIPT_FILE" "SPDX-License-Identifier:" "must match SPDX header"

# ---------------------------------------------------------------------------
# End-to-end: run the script in a temp dir with a known-good and known-bad file
# ---------------------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# File WITH a valid header
cat >"$TMP/good.sh" <<'EOF'
#!/usr/bin/env bash
# Copyright (c) 2026 Dotfiles. All rights reserved.
echo hi
EOF

# File WITHOUT any recognised header
cat >"$TMP/bad.sh" <<'EOF'
#!/usr/bin/env bash
echo nope
EOF

test_start "passes_on_clean_tree"
pushd "$TMP" >/dev/null
if command -v rg >/dev/null 2>&1; then
  # Remove bad file for the "clean" run
  rm -f "$TMP/bad.sh"
  if bash "$SCRIPT_FILE" --extensions=sh >/dev/null 2>&1; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected exit 0 on clean tree"
  fi
else
  printf '%b\n' "  ${YELLOW}∼${NC} $CURRENT_TEST: skipped (ripgrep unavailable)"
fi
popd >/dev/null

test_start "fails_on_missing_header"
pushd "$TMP" >/dev/null
if command -v rg >/dev/null 2>&1; then
  # Restore bad file
  cat >"$TMP/bad.sh" <<'EOF'
#!/usr/bin/env bash
echo nope
EOF
  set +e
  bash "$SCRIPT_FILE" --extensions=sh >/dev/null 2>&1
  ec=$?
  set -e
  if [[ "$ec" -eq 1 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected exit 1, got $ec"
  fi
else
  printf '%b\n' "  ${YELLOW}∼${NC} $CURRENT_TEST: skipped (ripgrep unavailable)"
fi
popd >/dev/null

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
