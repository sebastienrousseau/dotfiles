#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2030,SC2031,SC2034
# Auto-generated function-exercise test for lib/dot/log.sh.
# AUTO-GENERATED: true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/lib/dot/log.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "lib/dot/log.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "log_deep_branches_execute"
log_tmp="$DOTFILES_COV_TMPDIR/log-deep"
mkdir -p "$log_tmp/state" "$log_tmp/bin"
cat >"$log_tmp/bin/jq" <<'EOF_JQ'
#!/usr/bin/env bash
if [[ "${1:-}" == "-R" ]]; then
  while IFS= read -r line; do
    printf '"%s"\n' "$line"
  done
elif [[ "${1:-}" == "-s" ]]; then
  printf '["arg-one","arg-two"]\n'
elif [[ "${1:-}" == "-n" ]]; then
  printf '{"id":"checkpoint-with-jq","status":"ready"}\n'
else
  cat
fi
EOF_JQ
chmod +x "$log_tmp/bin/jq"
(
  set +e
  export HOME="$log_tmp/home"
  export XDG_STATE_HOME="$log_tmp/state"
  export DOTFILES_JSON_LOG=1
  export DOT_COMMAND="log-test"
  export DOT_TRACE_ID="trace-test"
  export DOT_AGENT_CHECKPOINT_ID="checkpoint-test"
  export DOT_AGENT_APPROVAL="never"
  export DOT_AGENT_FILESYSTEM="workspace-write"
  export DOT_AGENT_NETWORK="restricted"
  export DOT_AGENT_MCP_PROFILE="strict"
  export DOT_AGENT_MAX_STEPS="3"
  export PATH="$log_tmp/bin:$PATH"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/dot/ui.sh"
  # shellcheck disable=SC1090
  source "$SCRIPT_FILE"
  dot_agent_checkpoint_dir
  dot_jsonl_append "custom.jsonl" '{"event":"custom"}'
  dot_log_file info event_a key=value
  dot_log warn event_b alpha=beta
  dot_metric shell_startup 12 ms
  dot_metrics_summary 5
  dot_agent_session_log run_start ask ok argv=bash
  dot_agent_session_tail 5
  dot_agent_checkpoint_create ask ready arg-one arg-two
  dot_agent_checkpoint_tail 5
  log_info "info message"
  log_warn "warn message"
  log_error "error message"
  log_success "success message"
) >/dev/null || true
(
  set +e
  export HOME="$log_tmp/home-nojq"
  export XDG_STATE_HOME="$log_tmp/state-nojq"
  export DOT_TRACE_ID="trace-nojq"
  export DOT_AGENT_CHECKPOINT_ID="checkpoint-nojq"
  export PATH="/usr/bin:/bin"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/dot/ui.sh"
  # shellcheck disable=SC1090
  source "$SCRIPT_FILE"
  dot_metrics_summary 2
  dot_agent_session_tail 2
  dot_agent_checkpoint_create plan ready
  dot_agent_checkpoint_tail 2
) >/dev/null || true
assert_file_exists "$log_tmp/state/dotfiles/checkpoints/checkpoint-test.json" \
  "log deep branches created jq checkpoint"
assert_file_exists "$log_tmp/state-nojq/dotfiles/checkpoints/checkpoint-nojq.json" \
  "log deep branches created fallback checkpoint"

cov_exercise_functions_file "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
