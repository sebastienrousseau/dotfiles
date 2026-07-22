#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot CLI tools commands
# Tests: packages, tools, tools install, new, sandbox

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

TOOLS_FILE="$REPO_ROOT/scripts/dot/commands/tools.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# Test: tools.sh file exists
test_start "tools_cmd_file_exists"
assert_file_exists "$TOOLS_FILE" "tools.sh should exist"

# Test: tools.sh is valid shell syntax
test_start "tools_cmd_syntax_valid"
if bash -n "$TOOLS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: tools.sh has valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: tools.sh has syntax errors"
fi

# Test: defines packages command
test_start "tools_cmd_defines_packages"
if grep -q "cmd_packages\|_packages\|packages" "$TOOLS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines packages command"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define packages command"
fi

# Test: defines tools command
test_start "tools_cmd_defines_tools"
if grep -q "cmd_tools\|_tools" "$TOOLS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines tools command"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define tools command"
fi

# Test: defines new command (project scaffolding)
test_start "tools_cmd_defines_new"
if grep -q "cmd_new\|_new\|dot_new" "$TOOLS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines new command"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define new command"
fi

# Test: defines sandbox command
test_start "tools_cmd_defines_sandbox"
if grep -q "sandbox" "$REPO_ROOT/scripts/dot/commands/meta.sh" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: sandbox command is defined in meta module"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: sandbox command should exist in meta module"
fi

# Test: no hardcoded paths
test_start "tools_cmd_no_hardcoded_paths"
if grep -qE '"/home/[a-z]+' "$TOOLS_FILE" 2>/dev/null; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should not have hardcoded paths"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no hardcoded paths"
fi

# Test: uses XDG directories
test_start "tools_cmd_uses_xdg"
if grep -qE 'PWD|HOME|resolve_source_dir|require_source_dir' "$TOOLS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: uses XDG/HOME variables"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should use XDG directories"
fi

# Test: shellcheck compliance
test_start "tools_cmd_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$TOOLS_FILE" 2>&1 | wc -l)
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
echo "Tools commands tests completed."

test_start "tools_cmd_deep_branches_execute"
tools_tmp="$DOTFILES_COV_TMPDIR/tools-deep"
mkdir -p "$tools_tmp/bin" "$tools_tmp/repo/templates/projects/python/__PROJECT_NAME__" \
  "$tools_tmp/repo/defaults" "$tools_tmp/work"
cat >"$tools_tmp/repo/defaults/.chezmoidata.toml" <<'EOF'
profile = "default"

[features]
ai = true
desktop = false
fleet = true
EOF
printf 'defaults\n' >"$tools_tmp/repo/.chezmoiroot"
cat >"$tools_tmp/repo/templates/projects/python/pyproject.toml" <<'EOF'
[project]
name = "__PROJECT_NAME__"
version = "0.1.0"
EOF
cat >"$tools_tmp/repo/templates/projects/python/__PROJECT_NAME__/__init__.py" <<'EOF'
"""__PROJECT_NAME__ package."""
EOF
cat >"$tools_tmp/bin/brew" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "Homebrew 9.9.9" ;;
  list) echo "pkg-one"; echo "pkg-two" ;;
esac
SHIM
cat >"$tools_tmp/bin/apt" <<'SHIM'
#!/usr/bin/env bash
echo "apt 9.9.9"
SHIM
cat >"$tools_tmp/bin/dpkg" <<'SHIM'
#!/usr/bin/env bash
echo "ii  one"; echo "ii  two"; echo "rc  old"
SHIM
cat >"$tools_tmp/bin/dnf" <<'SHIM'
#!/usr/bin/env bash
echo "9.9.9"
SHIM
cat >"$tools_tmp/bin/pacman" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  -Q) echo "one"; echo "two" ;;
  --version) echo "Pacman v9.9.9" ;;
esac
SHIM
cat >"$tools_tmp/bin/nix" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "nix 9.9.9" ;;
  develop) exit 0 ;;
esac
SHIM
cat >"$tools_tmp/bin/npm" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "9.9.9" ;;
  list) echo "├── one"; echo "└── two" ;;
  install) exit 0 ;;
esac
SHIM
cat >"$tools_tmp/bin/pnpm" <<'SHIM'
#!/usr/bin/env bash
echo "9.9.9"
SHIM
cat >"$tools_tmp/bin/bun" <<'SHIM'
#!/usr/bin/env bash
echo "9.9.9"
SHIM
cat >"$tools_tmp/bin/cargo" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  install) echo "tool-a:"; echo "tool-b:" ;;
  --version) echo "cargo 9.9.9" ;;
esac
SHIM
cat >"$tools_tmp/bin/pip3" <<'SHIM'
#!/usr/bin/env bash
echo "pip 9.9.9 from /tmp"
SHIM
cat >"$tools_tmp/bin/pipx" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  list) echo "one"; echo "two" ;;
  --version) echo "9.9.9" ;;
esac
SHIM
cat >"$tools_tmp/bin/gem" <<'SHIM'
#!/usr/bin/env bash
echo "9.9.9"
SHIM
cat >"$tools_tmp/bin/go" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  version) echo "go version go9.9.9 darwin/arm64" ;;
  mod) exit 0 ;;
esac
SHIM
cat >"$tools_tmp/bin/mise" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  ls)
    if [[ "${2:-}" == "--json" ]]; then
      printf '{"node":[{"version":"24.0.0","source":{"path":"%s/.tool-versions"},"requested_version":"24"}]}\n' "${HOME:-/tmp}"
    else
      echo "node 24.0.0 ~/.tool-versions 24"
    fi
    ;;
  prune)
    if [[ "${2:-}" == "--dry-run-code" ]]; then exit 1; fi
    echo "prune ${*:2}"
    ;;
  install|use) echo "$1 ${*:2}" ;;
  *) echo "mise ${*}" ;;
esac
SHIM
chmod +x "$tools_tmp/bin/"*

(
  set +e
  export PATH="$tools_tmp/bin:$PATH"
  export HOME="$tools_tmp/home"
  mkdir -p "$HOME"
  cd "$tools_tmp/work" || exit 1
  set -- tools
  # shellcheck disable=SC1091
  source "$TOOLS_FILE"
  _DOT_SOURCE_DIR_CACHE="$tools_tmp/repo"
  cmd_packages
  cmd_tools
  cmd_env_mise list
  cmd_env_mise prune
  cmd_env_mise prune --yes
  cmd_env_mise install node
  cmd_env_mise use node
  cmd_env_mise unknown
  cmd_profile show
  cmd_profile set workstation
  cmd_new python demo_project
) >/dev/null || true
assert_dir_exists "$tools_tmp/work/demo_project" "tools deep branches created sandbox project"

(
  set +e
  export PATH="$tools_tmp/bin:$PATH"
  export HOME="$tools_tmp/home"
  cd "$tools_tmp/work" || exit 1
  bash "$TOOLS_FILE" tools install node >/dev/null
) || true

# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$TOOLS_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
