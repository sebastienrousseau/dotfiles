#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# install/migrate/retire-mise-tools.sh: a retired tool declared in mise's
# global config is unregistered, anything else is left alone, and the
# script never fails an apply.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

RETIRE="$REPO_ROOT/install/migrate/retire-mise-tools.sh"
REAL_MISE="$(command -v mise || true)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
N=0

# fresh: a sandbox HOME with a stub mise that logs its arguments to $LOG
# and exits $STUB_RC.
fresh() {
  N=$((N + 1))
  H="$WORK/h$N"
  CFG="$H/.config/mise/config.toml"
  LOG="$H/mise.log"
  mkdir -p "$H/.config/mise" "$H/bin"
  cat >"$H/bin/mise" <<'EOF'
#!/usr/bin/env bash
echo "$MISE_GLOBAL_CONFIG_FILE $*" >>"$STUB_LOG"
exit "${STUB_RC:-0}"
EOF
  chmod +x "$H/bin/mise"
}

# run [PATH]: set OUT (stdout and stderr) and RC.
run() {
  RC=0
  OUT="$(env -u MISE_GLOBAL_CONFIG_FILE -u XDG_CONFIG_HOME HOME="$H" \
    PATH="${1:-$H/bin:/usr/bin:/bin}" STUB_LOG="$LOG" STUB_RC="${STUB_RC:-0}" \
    bash "$RETIRE" 2>&1)" || RC=$?
}

test_start "declared_retired_tool_is_unused"
fresh
printf '[tools]\nnode = "24"\nkiro-cli = "latest"\n' >"$CFG"
run
assert_equals "0" "$RC" "exits 0"
assert_equals "$CFG unuse -g --no-prune kiro-cli" "$(cat "$LOG")" "mise unuse runs on the global config"
assert_contains "removed kiro-cli" "$OUT" "says what it removed"

test_start "quoted_key_is_matched"
fresh
printf '[tools]\n"kiro-cli" = "2.29.1"\n' >"$CFG"
run
assert_equals "$CFG unuse -g --no-prune kiro-cli" "$(cat "$LOG" 2>/dev/null)" "quoted key"

test_start "undeclared_or_prefixed_tool_is_left_alone"
fresh
printf '[tools]\nnode = "24"\n"npm:kiro-cli-x" = "1"\n# kiro-cli = "latest"\n' >"$CFG"
run
assert_equals "0|" "$RC|$OUT" "silent no-op"
assert_false "[[ -e '$LOG' ]]" "mise is not called"

test_start "no_config_or_no_mise_is_a_no_op"
fresh
run
assert_equals "0|" "$RC|$OUT" "no config file"
printf 'kiro-cli = "latest"\n' >"$CFG"
run "/usr/bin:/bin"
assert_equals "0" "$RC" "no mise on PATH"

test_start "a_failing_unuse_never_fails_the_apply"
fresh
printf 'kiro-cli = "latest"\n' >"$CFG"
STUB_RC=1 run
assert_equals "0" "$RC" "exits 0"
assert_contains "could not remove kiro-cli" "$OUT" "asks for a manual edit"

test_start "zai_cli_declared_by_dot_ai_install_is_unused"
fresh
printf '[tools]\nnode = "24"\n"npm:@guizmo-ai/zai-cli" = "0.3.5"\n' >"$CFG"
run
assert_equals "0" "$RC" "exits 0"
assert_equals "$CFG unuse -g --no-prune npm:@guizmo-ai/zai-cli" "$(cat "$LOG" 2>/dev/null)" "mise unuse names the npm tool"
assert_contains "removed npm:@guizmo-ai/zai-cli" "$OUT" "says what it removed"

test_start "real_mise_removes_the_zai_cli_line"
if [[ -n "$REAL_MISE" ]]; then
  fresh
  printf '[tools]\nnode = "24"\n"npm:@guizmo-ai/zai-cli" = "0.3.5"\n' >"$CFG"
  run "$(dirname "$REAL_MISE"):/usr/bin:/bin"
  assert_equals "0" "$RC" "exits 0"
  assert_equals '[tools]|node = "24"' "$(paste -sd'|' "$CFG")" "only the zai-cli line goes"
else
  echo "  - skipped: mise not installed"
fi

test_start "real_mise_removes_the_line"
if [[ -n "$REAL_MISE" ]]; then
  fresh
  printf '[tools]\nnode = "24"\nkiro-cli = "latest"\n' >"$CFG"
  run "$(dirname "$REAL_MISE"):/usr/bin:/bin"
  assert_equals "0" "$RC" "exits 0"
  assert_equals '[tools]|node = "24"' "$(paste -sd'|' "$CFG")" "only the kiro-cli line goes"
else
  echo "  - skipped: mise not installed"
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
