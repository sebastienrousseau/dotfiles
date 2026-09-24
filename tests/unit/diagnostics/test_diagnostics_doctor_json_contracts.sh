#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Contract tests for `doctor --json` (scripts/diagnostics/doctor.sh).
#
# The feature-matrix row runs --json against the host and can only say
# "it looked like JSON". These runs build a private HOME + shim bin so
# the probe outcomes are known in advance, then pin the document's
# arithmetic exactly:
#
#   * jq parses it, and `.results | length` equals `total`;
#   * passed + warnings + failures == total;
#   * passed / warnings / failures equal the number of pass / warn / fail
#     rows, and the expected failure and warning counts are pinned;
#   * status is "healthy" exactly when failures is 0, across runs whose
#     counts differ;
#   * verdict is the sentence the counts imply, on all three branches.
#
# Each fixture is the same "everything installed" workstation with a
# few tools hidden, so the delta between runs is the hidden tools and
# nothing else.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Keep the coverage runner's xtrace records flowing to the real stderr
# while each child's own stderr is discarded (see the branches suite).
exec 21>&2

DOCTOR_FILE="$REPO_ROOT/scripts/diagnostics/doctor.sh"

# The assertions parse with the host's jq; the doctor child never sees it
# (its PATH is the sandbox only, where a jq shim serves benches/bench.sh).
JQ="$(command -v jq 2>/dev/null || true)"
if [[ -z "$JQ" ]]; then
  test_start "doctor_json_contracts_need_jq"
  assert_equals "jq" "missing" "jq is required to check the --json contract"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 1
fi

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

TMP="$DOTFILES_COV_TMPDIR"

# ── sysbin: the only host binaries doctor may see ──────────────────────
SYSBIN="$TMP/sysbin"
mkdir -p "$SYSBIN"
for tool in awk sed grep tr find date stat wc head tail basename dirname \
  readlink cut sort uniq cat mkdir mktemp printf hostname whoami rm touch ls env \
  python3 timeout locale tput; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$SYSBIN/$tool"
done
ln -sf "$BASH" "$SYSBIN/bash"

S_BIN=""
S_HOME=""

_shim() {
  cat >"$S_BIN/$1"
  chmod +x "$S_BIN/$1"
}

# _fixture <name> <tool>...: a Linux workstation where every probe passes
# when the full tool list is present. Hiding a tool moves exactly one
# probe (or a known few) to warn or fail:
#   fish, nu -> warn                   rg, sops, hyperfine (and the rest) -> fail
#   (hyperfine is in doctor's required Infrastructure set; hiding it also
#   adds a separate "benchmark skipped" warning)
_fixture() {
  local name="$1"
  shift
  S_BIN="$TMP/$name/bin"
  S_HOME="$TMP/$name/home"
  mkdir -p "$S_BIN" "$S_HOME/.config/atuin" "$S_HOME/.config/fish" \
    "$S_HOME/.config/nushell" "$S_HOME/.local/bin" "$S_HOME/.local/share" \
    "$S_HOME/.cache/zsh" "$S_HOME/.cache/bash" "$S_HOME/.cache/fish" \
    "$S_HOME/.local/state"
  local t
  for t in "$@"; do
    printf '#!/usr/bin/env bash\necho "%s 1.0.0"\nexit 0\n' "$t" >"$S_BIN/$t"
    chmod +x "$S_BIN/$t"
    # Binaries older than their init caches keep "shell caches" fresh.
    touch -t 202001010000 "$S_BIN/$t"
    printf '# cached\n' >"$S_HOME/.cache/zsh/${t}-init.zsh"
    printf '# cached\n' >"$S_HOME/.cache/bash/${t}-init.bash"
    printf '# cached\n' >"$S_HOME/.cache/fish/${t}-init.fish"
  done
  _shim uname <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -sr) echo "Linux 6.1.0" ;;
  -m | -p) echo "x86_64" ;;
  *) echo "Linux" ;;
esac
EOF
  _shim zsh <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "zsh 5.9 (x86_64-pc-linux-gnu)" ;;
  -i) echo "1 1" ;;
esac
exit 0
EOF
  _shim uptime <<'EOF'
#!/usr/bin/env bash
echo "up 1 hour"
EOF
  # verify: synchronised; managed: nothing under ~/.config to scan.
  _shim chezmoi <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  if [[ -f "$S_BIN/hyperfine" ]]; then
    _shim hyperfine <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    # bench.sh reads the min from jq; 10ms sits under every threshold.
    _shim jq <<'EOF'
#!/usr/bin/env bash
echo "10"
EOF
  fi
  printf 'ID=fixturelinux\nPRETTY_NAME="Fixture Linux 2026"\n' >"$S_HOME/os-release"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$S_HOME/.local/bin/dot"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$S_HOME/.local/bin/antigravity"
  chmod +x "$S_HOME/.local/bin/dot" "$S_HOME/.local/bin/antigravity"
  printf '# zshrc\n' >"$S_HOME/.zshrc"
  {
    echo 'history_filter = ['
    for t in token secret password apikey api_key bearer private_key ssh-rsa aws_access_key npm_ ghp_; do
      printf '  "%s",\n' "$t"
    done
    echo ']'
  } >"$S_HOME/.config/atuin/config.toml"
  printf 'jorgebucaran/fisher\n' >"$S_HOME/.config/fish/fish_plugins"
  printf '# nu cache\n' >"$S_HOME/.config/nushell/cached_eval.nu"
}

# _run_json: run `doctor --json` in the fixture. Sets JSON_OUT (stdout
# only, the document) and JSON_RC.
JSON_OUT=""
JSON_RC=0
_run_json() {
  JSON_RC=0
  JSON_OUT="$(
    cd "$S_HOME" &&
      env BASH_XTRACEFD=21 PATH="$S_BIN:$SYSBIN" \
        HOME="$S_HOME" \
        XDG_CONFIG_HOME="$S_HOME/.config" \
        XDG_DATA_HOME="$S_HOME/.local/share" \
        XDG_CACHE_HOME="$S_HOME/.cache" \
        XDG_STATE_HOME="$S_HOME/.local/state" \
        SHELL="$S_BIN/zsh" \
        PIPX_HOME="$S_HOME/.local/pipx" \
        TERM_PROGRAM=FixtureTerm \
        DOTFILES_ACCESSIBILITY=1 \
        DOT_DOCTOR_OS_RELEASE="$S_HOME/os-release" \
        DOT_DOCTOR_PROC_ROOT="$S_HOME/proc" \
        DOT_DOCTOR_SYS_ROOT="$S_HOME/sys" \
        "$BASH" "$DOCTOR_FILE" --json 2>/dev/null
  )" || JSON_RC=$?
}

# _jq <filter>: evaluate a jq filter over JSON_OUT (raw output).
_jq() {
  printf '%s' "$JSON_OUT" | "$JQ" -r "$1" 2>/dev/null
}

# _assert_contract <label> <expected rc> <expected failures> <expected warnings>
# <expected status> <expected verdict>
_assert_contract() {
  local label="$1" want_rc="$2" want_fail="$3" want_warn="$4" want_status="$5" want_verdict="$6"
  local parses total len passed warnings failures pass_rows warn_rows fail_rows status verdict

  test_start "${label}_exit_code"
  assert_equals "$want_rc" "$JSON_RC" "doctor --json exits $want_rc"

  test_start "${label}_parses_as_json"
  parses=0
  printf '%s' "$JSON_OUT" | "$JQ" -e . >/dev/null 2>&1 || parses=$?
  assert_equals 0 "$parses" "jq parses the document (results array well formed, no stray comma)"

  total="$(_jq '.total')"
  len="$(_jq '.results | length')"
  passed="$(_jq '.passed')"
  warnings="$(_jq '.warnings')"
  failures="$(_jq '.failures')"
  pass_rows="$(_jq '[.results[] | select(.status == "pass")] | length')"
  warn_rows="$(_jq '[.results[] | select(.status == "warn")] | length')"
  fail_rows="$(_jq '[.results[] | select(.status == "fail")] | length')"
  status="$(_jq '.status')"
  verdict="$(_jq '.verdict')"

  test_start "${label}_results_is_array_of_objects"
  assert_equals "true" "$(_jq '(.results | type == "array") and all(.results[]; type == "object" and has("check") and has("status") and has("message"))')" \
    "every results row is a {check,status,message} object"

  test_start "${label}_total_is_results_length"
  assert_equals "$len" "$total" "total ($total) == results length ($len)"

  test_start "${label}_total_is_nonzero"
  assert_equals "true" "$(_jq '.total > 1')" "the run recorded more than one probe (total=$total)"

  test_start "${label}_counts_sum_to_total"
  assert_equals "$total" "$((passed + warnings + failures))" \
    "passed ($passed) + warnings ($warnings) + failures ($failures) == total ($total)"

  test_start "${label}_passed_counts_pass_rows"
  assert_equals "$pass_rows" "$passed" "passed equals the number of pass rows"

  test_start "${label}_warnings_count_warn_rows"
  assert_equals "$warn_rows" "$warnings" "warnings equals the number of warn rows"

  test_start "${label}_failures_count_fail_rows"
  assert_equals "$fail_rows" "$failures" "failures equals the number of fail rows"

  test_start "${label}_failures_pinned"
  assert_equals "$want_fail" "$failures" "failures is exactly $want_fail"

  test_start "${label}_warnings_pinned"
  assert_equals "$want_warn" "$warnings" "warnings is exactly $want_warn"

  test_start "${label}_status_pinned"
  assert_equals "$want_status" "$status" "status is $want_status"

  test_start "${label}_status_follows_failures"
  if [[ "$failures" -eq 0 ]]; then
    assert_equals "healthy" "$status" "failures=0 means healthy"
  else
    assert_equals "unhealthy" "$status" "failures=$failures means unhealthy"
  fi

  test_start "${label}_verdict_pinned"
  assert_equals "$want_verdict" "$verdict" "verdict states the counts"
  # Consumers index results by check name; a repeated name (the chezmoi
  # binary and the chezmoi drift row were both "chezmoi") silently drops one.
  test_start "${label}_check_names_unique"
  assert_equals "" "$(_jq '[.results[].check] | group_by(.) | map(select(length > 1) | .[0]) | join(",")')" \
    "every check name is unique"
  test_start "${label}_drift_row_named"
  assert_equals "1" "$(_jq '[.results[] | select(.check == "chezmoi state")] | length')" \
    "the drift row is reported as 'chezmoi state'"
}

FULL_TOOLS="fish starship nu rg bat fzf zoxide atuin yazi zellij \
  pueue wasmtime nix sops age hyperfine"

# ── R1: everything installed — all pass, no warnings ────────────────────
# shellcheck disable=SC2086
_fixture r1 $FULL_TOOLS
_run_json
_assert_contract "json_all_pass" 0 0 0 "healthy" "All checks passed."
test_start "json_all_pass_passed_is_total"
assert_equals "$(_jq '.total')" "$(_jq '.passed')" "with no warnings or failures, passed == total"
test_start "json_all_pass_named_rows"
assert_equals "pass pass pass" \
  "$(_jq '[.results[] | select(.check == "zsh" or .check == "rg" or .check == "sops") | .status] | join(" ")')" \
  "zsh, rg and sops rows are pass"

# ── R2: fish and nu hidden — two warnings, still healthy ──────────────
# shellcheck disable=SC2086
_fixture r2 $(printf '%s\n' $FULL_TOOLS | grep -vx -e fish -e nu)
_run_json
_assert_contract "json_warned" 0 0 2 "healthy" "2 warning(s)."
test_start "json_warned_rows_named"
assert_equals "fish nu" \
  "$(_jq '[.results[] | select(.status == "warn") | .check] | sort | join(" ")')" \
  "the two warn rows are the hidden optional tools"

# ── R3: rg and sops hidden too — two failures, unhealthy ────────────────
# shellcheck disable=SC2086
_fixture r3 $(printf '%s\n' $FULL_TOOLS | grep -vx -e fish -e nu -e rg -e sops)
_run_json
_assert_contract "json_failed" 1 2 2 "unhealthy" "2 error(s), 2 warning(s). Run 'dot heal' to repair."
test_start "json_failed_rows_named"
assert_equals "rg sops" \
  "$(_jq '[.results[] | select(.status == "fail") | .check] | sort | join(" ")')" \
  "the two fail rows are the hidden required tools"

# ── Cross-run: hiding tools moves rows, never adds or drops them ────────
test_start "json_runs_differ_only_by_status"
assert_equals "$(_jq '.total')" "$(_jq '.passed + .warnings + .failures')" \
  "the third run's counts still reconcile after two more probes flipped to fail"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
