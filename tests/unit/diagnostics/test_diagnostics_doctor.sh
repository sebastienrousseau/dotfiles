#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for doctor diagnostic script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

DOCTOR_FILE="$REPO_ROOT/scripts/diagnostics/doctor.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# Test: doctor.sh file exists
test_start "doctor_file_exists"
assert_file_exists "$DOCTOR_FILE" "doctor.sh should exist"

# Test: doctor.sh is valid shell syntax
test_start "doctor_syntax_valid"
if bash -n "$DOCTOR_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: doctor.sh has valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: doctor.sh has syntax errors"
fi

# Test: defines diagnostic functions
test_start "doctor_defines_diagnostics"
if grep -qE 'check_|command -v|chezmoi status|ui_header' "$DOCTOR_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines diagnostic functions"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define diagnostic functions"
fi

# Test: checks system configuration
test_start "doctor_checks_config"
if grep -qE 'config|chezmoi|\$HOME' "$DOCTOR_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: checks system configuration"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should check system configuration"
fi

# Test: provides remediation suggestions
test_start "doctor_provides_remediation"
if grep -qE 'fix|suggest|recommend|try|run' "$DOCTOR_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: provides remediation suggestions"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should provide remediation suggestions"
fi

# Test: shellcheck compliance
test_start "doctor_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$DOCTOR_FILE" 2>&1 | wc -l)
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
echo "Doctor diagnostic tests completed."
# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$DOCTOR_FILE"

test_start "doctor_linux_platform_fixture_branch"
fixture_dir="$DOTFILES_COV_TMPDIR/doctor-linux"
mkdir -p "$fixture_dir/proc" \
  "$fixture_dir/sys/devices/virtual/dmi/id" \
  "$HOME/.config/fish" \
  "$HOME/.config/atuin" \
  "$HOME/.local/bin"
cat >"$fixture_dir/os-release" <<'EOF'
ID=fixturelinux
PRETTY_NAME="Fixture Linux 2026"
EOF
cat >"$fixture_dir/proc/version" <<'EOF'
Linux version 6.10.0-microsoft-standard-WSL2
EOF
cat >"$fixture_dir/proc/cpuinfo" <<'EOF'
processor	: 0
model name	: Fixture CPU
processor	: 1
model name	: Fixture CPU
EOF
cat >"$fixture_dir/proc/meminfo" <<'EOF'
MemTotal:        8388608 kB
MemAvailable:    4194304 kB
EOF
printf '%s\n' "FixtureBook" >"$fixture_dir/sys/devices/virtual/dmi/id/product_name"
printf '%s\n' "jorgebucaran/fisher" >"$HOME/.config/fish/fish_plugins"
cat >"$HOME/.config/atuin/config.toml" <<'EOF'
history_filter = [
  "token", "secret", "password", "apikey", "api_key",
  "bearer", "BEGIN PRIVATE KEY", "ssh-rsa", "aws_access_key", "npm_"
]
EOF
printf '# test zshrc\n' >"$HOME/.zshrc"
printf '#!/usr/bin/env bash\nexit 0\n' >"$HOME/.local/bin/dot"
chmod +x "$HOME/.local/bin/dot"
cat >"$DOTFILES_COV_TMPDIR/bin/uname" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  -s) echo "Linux" ;;
  -sr) echo "Linux 6.10.0" ;;
  -m) echo "x86_64" ;;
  -p) echo "x86_64" ;;
  *) echo "Linux" ;;
esac
SHIM
cat >"$DOTFILES_COV_TMPDIR/bin/lscpu" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "CPU(s): 2" "Model name: Fixture CPU"
SHIM
cat >"$DOTFILES_COV_TMPDIR/bin/free" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "              total        used        free" "Mem:     8589934592  4294967296  4294967296"
SHIM
cat >"$DOTFILES_COV_TMPDIR/bin/wlr-randr" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "HDMI-A-1 current 1920x1080"
SHIM
cat >"$DOTFILES_COV_TMPDIR/bin/dpkg" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  --get-selections) printf '%s\n' "bash install" "zsh install" ;;
  *) : ;;
esac
SHIM
cat >"$DOTFILES_COV_TMPDIR/bin/wslpath" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "/mnt/c/Users/test"
SHIM
chmod +x "$DOTFILES_COV_TMPDIR/bin/uname" \
  "$DOTFILES_COV_TMPDIR/bin/lscpu" \
  "$DOTFILES_COV_TMPDIR/bin/free" \
  "$DOTFILES_COV_TMPDIR/bin/wlr-randr" \
  "$DOTFILES_COV_TMPDIR/bin/dpkg" \
  "$DOTFILES_COV_TMPDIR/bin/wslpath"
output="$(
  DOTFILES_ACCESSIBILITY=1 \
    DOT_DOCTOR_OS_RELEASE="$fixture_dir/os-release" \
    DOT_DOCTOR_PROC_ROOT="$fixture_dir/proc" \
    DOT_DOCTOR_SYS_ROOT="$fixture_dir/sys" \
    bash "$DOCTOR_FILE"
)" || true
if [[ "$output" == *"Fixture Linux 2026 (WSL)"* ]] &&
  [[ "$output" == *"FixtureBook"* ]] &&
  [[ "$output" == *"Fixture CPU"* ]] &&
  [[ "$output" == *"WSL bridge"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: Linux and WSL branches execute"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected Linux/WSL fixture details"
  # Name the missing markers and dump the tail of the report rather
  # than a 500-char head. When doctor.sh aborts mid-run the head is
  # identical to a healthy run and tells us nothing; the tail shows
  # exactly which section it died in.
  for marker in "Fixture Linux 2026 (WSL)" "FixtureBook" "Fixture CPU" "WSL bridge"; do
    [[ "$output" == *"$marker"* ]] || printf '%b\n' "    missing marker: $marker"
  done
  printf '%b\n' "    Report tail:"
  printf '%s\n' "$output" | tail -25 | sed 's/^/      /'
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
