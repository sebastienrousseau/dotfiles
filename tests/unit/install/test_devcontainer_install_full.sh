#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for devcontainer install-full.sh bootstrap script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

FULL_FILE="$REPO_ROOT/.devcontainer/install-full.sh"
LITE_FILE="$REPO_ROOT/.devcontainer/install-lite.sh"
DC_FILE="$REPO_ROOT/.devcontainer/devcontainer.json"
DF_FILE="$REPO_ROOT/.devcontainer/Dockerfile"

# Test: install-full.sh file exists
test_start "devcontainer_full_file_exists"
assert_file_exists "$FULL_FILE" "install-full.sh should exist"

# Test: install-full.sh is executable
test_start "devcontainer_full_is_executable"
if [[ -x "$FULL_FILE" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: install-full.sh is executable"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: install-full.sh should be executable"
fi

# Test: install-full.sh is valid shell syntax
test_start "devcontainer_full_syntax_valid"
if bash -n "$FULL_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: install-full.sh has valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: install-full.sh has syntax errors"
fi

# Test: uses strict mode
test_start "devcontainer_full_strict_mode"
if grep -q 'set -euo pipefail' "$FULL_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: uses set -euo pipefail"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should use set -euo pipefail"
fi

# Test: has proper shebang
test_start "devcontainer_full_shebang"
if head -1 "$FULL_FILE" | grep -q '#!/usr/bin/env bash'; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: has proper shebang"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have #!/usr/bin/env bash shebang"
fi

# Test: detects Codespaces workspace
test_start "devcontainer_full_detects_codespaces"
if grep -q '/workspaces/dotfiles' "$FULL_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: detects Codespaces workspace"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should detect Codespaces workspace"
fi

# Test: calls chezmoi init
test_start "devcontainer_full_chezmoi_init"
if grep -q 'chezmoi init' "$FULL_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: calls chezmoi init"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should call chezmoi init"
fi

# Test: calls chezmoi apply
test_start "devcontainer_full_chezmoi_apply"
if grep -q 'chezmoi apply' "$FULL_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: calls chezmoi apply"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should call chezmoi apply"
fi

# Test: uses --no-tty for non-interactive
test_start "devcontainer_full_no_tty"
if grep -q -- '--no-tty' "$FULL_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: uses --no-tty for non-interactive mode"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should use --no-tty"
fi

# Test: sets server profile
test_start "devcontainer_full_server_profile"
if grep -q 'server' "$FULL_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: configures server profile"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should configure server profile"
fi

# Test: detects mise
test_start "devcontainer_full_mise_detection"
if grep -q 'mise' "$FULL_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: detects and uses mise"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should detect mise"
fi

# Test: no hardcoded user paths
test_start "devcontainer_full_no_hardcoded_paths"
if grep -qE '"/home/[a-z]+|/Users/[a-z]+' "$FULL_FILE" 2>/dev/null; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: has hardcoded user paths"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no hardcoded user paths"
fi

# Test: install-lite.sh still exists (backward compat)
test_start "devcontainer_lite_still_exists"
assert_file_exists "$LITE_FILE" "install-lite.sh should still exist"

# Test: devcontainer.json exists
test_start "devcontainer_json_exists"
assert_file_exists "$DC_FILE" "devcontainer.json should exist"

# Test: devcontainer.json is valid JSON
test_start "devcontainer_json_valid"
if command -v jq &>/dev/null; then
  if jq . "$DC_FILE" >/dev/null 2>&1; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: devcontainer.json is valid JSON"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: devcontainer.json has JSON errors"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: jq not available, skipped"
fi

# Test: Dockerfile exists
test_start "devcontainer_dockerfile_exists"
assert_file_exists "$DF_FILE" "Dockerfile should exist"

# Test: Dockerfile installs chezmoi
test_start "devcontainer_dockerfile_chezmoi"
if grep -q 'chezmoi' "$DF_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: Dockerfile installs chezmoi"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: Dockerfile should install chezmoi"
fi

# Test: Dockerfile installs mise
test_start "devcontainer_dockerfile_mise"
if grep -q 'mise' "$DF_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: Dockerfile installs mise"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: Dockerfile should install mise"
fi

# Test: shellcheck compliance
test_start "devcontainer_full_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error -e SC1091 "$FULL_FILE" 2>&1 | wc -l)
  if [[ "$errors" -eq 0 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: passes shellcheck"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: has shellcheck errors"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: shellcheck not available, skipped"
fi

echo ""
echo "DevContainer install-full tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
