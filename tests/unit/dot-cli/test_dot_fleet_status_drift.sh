#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behavioural coverage for `dot fleet status|drift|events` in
# scripts/dot/commands/fleet.sh. Every branch is driven through inputs:
# a writable fake source tree (code symlinked, .chezmoidata.toml owned
# by the test), a scripted `chezmoi status` shim, a curl spy for the
# event-forwarding endpoint, and PATH variants without chezmoi / jq.
# Nothing touches the real repo, $HOME, or the network.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Keep child xtrace flowing to the coverage runner's trace stream even
# when a probe captures `2>&1` or discards stderr.
exec 21>&2
export BASH_XTRACEFD=21

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
TMP="$DOTFILES_COV_TMPDIR"
[[ -n "$TMP" && -d "$TMP" ]] || {
  echo "sandbox tmpdir missing; refusing to run" >&2
  exit 1
}

# ── Fake source tree ────────────────────────────────────────────────
# lib/ scripts/ bin/ are symlinks into the real repo so the traced
# BASH_SOURCE paths resolve to the real files; defaults/ is a private
# copy so the command's config reads/writes never leave the sandbox.
# Under the coverage runner the fake tree must outlive this test's
# sandbox teardown: the aggregator resolves the symlinked BASH_SOURCE
# paths only after every test has finished. COV_TRACE_DIR is wiped by
# the runner at the start of each sweep, so nothing accumulates.
if [[ -n "${COV_TRACE_DIR:-}" && -d "${COV_TRACE_DIR:-}" ]]; then
  FAKE="$(mktemp -d "$COV_TRACE_DIR/fleet-fake.XXXXXX")"
else
  FAKE="$TMP/repo"
fi
mkdir -p "$FAKE/defaults"
ln -s "$REPO_ROOT/lib" "$FAKE/lib"
ln -s "$REPO_ROOT/scripts" "$FAKE/scripts"
ln -s "$REPO_ROOT/bin" "$FAKE/bin"
cp "$REPO_ROOT/package.json" "$FAKE/package.json"
echo defaults >"$FAKE/.chezmoiroot"
FLEET="$FAKE/scripts/dot/commands/fleet.sh"
DATA="$FAKE/defaults/.chezmoidata.toml"

STATE_DIR="$XDG_STATE_HOME/dotfiles/fleet"
EVENTS="$STATE_DIR/events.jsonl"
HISTORY="$STATE_DIR/drift-history.jsonl"

# ── PATH variants ───────────────────────────────────────────────────
# $MINI holds only the coreutils the script needs, so a PATH built
# from it can omit chezmoi / jq deterministically.
MINI="$TMP/mini"
WITHJQ="$TMP/withjq"
mkdir -p "$MINI" "$WITHJQ"
for t in bash sh dirname basename sed head tail hostname date mkdir awk wc tr \
  uname grep realpath readlink sort uniq cat mktemp mv rm cp cut env tput \
  stty ls find diff touch chmod; do
  p="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$MINI/$t"
done
ln -sf "$(command -v jq)" "$WITHJQ/jq"
PATH_FULL="$TMP/bin:$WITHJQ:$MINI"
PATH_NO_CHEZMOI="$WITHJQ:$MINI"
PATH_NO_JQ="$TMP/bin:$MINI"
export PATH="$PATH_FULL"

# chezmoi shim: `status` replays $FAKE_CHEZMOI_STATUS when set.
cat >"$TMP/bin/chezmoi" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  status) [[ -n "${FAKE_CHEZMOI_STATUS:-}" ]] && cat "$FAKE_CHEZMOI_STATUS" ;;
  --version | version) echo "chezmoi version 2.47.1" ;;
  *) : ;;
esac
exit 0
SHIM
chmod +x "$TMP/bin/chezmoi"

# curl spy: records argv so the event-forwarding branch is observable.
CURL_LOG="$TMP/curl.log"
cat >"$TMP/bin/curl" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${CURL_SPY_LOG:?}"
exit 0
SHIM
chmod +x "$TMP/bin/curl"
export CURL_SPY_LOG="$CURL_LOG"

write_data() {
  cat >"$DATA"
}

# assert_not_contains <needle> <haystack> [msg] — string-level negative.
assert_not_contains() {
  local needle="$1" actual="$2" msg="${3:-string should not contain substring}"
  if [[ "$actual" != *"$needle"* ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $msg"
    printf '%b\n' "    Should not contain: '$needle'"
  fi
}

fleet() {
  bash "$FLEET" fleet "$@"
}

# ── status ──────────────────────────────────────────────────────────
write_data <<'TOML'
node_id = "node-a"
namespace = "team"
TOML

test_start "fleet_status_json_reports_configured_identity"
out="$(fleet status --json 2>&1)"
rc=$?
assert_equals 0 "$rc" "status --json exits 0"
assert_contains '"node_id":"node-a"' "$out" "json carries node_id from data file"
assert_contains '"namespace":"team"' "$out" "json carries namespace from data file"
assert_contains '"drift":"clean"' "$out" "no chezmoi output means clean"

test_start "fleet_status_short_flag_is_json"
out="$(fleet status -j 2>&1)"
assert_contains '{"node_id"' "$out" "-j selects json mode"

test_start "fleet_status_human_reports_drift_and_last_apply"
printf ' M .zshrc\n' >"$TMP/drift.txt"
mkdir -p "$XDG_STATE_HOME/dotfiles"
printf '[2026-01-02T03:04:05Z] apply completed\n' >"$XDG_STATE_HOME/dotfiles/dot.log"
out="$(FAKE_CHEZMOI_STATUS="$TMP/drift.txt" fleet status 2>&1)"
rc=$?
assert_equals 0 "$rc" "human status exits 0"
assert_contains "drifted" "$out" "chezmoi status output flips drift to drifted"
assert_contains "Last Apply" "$out" "state log timestamp is surfaced"
assert_contains "2026-01-02T03:04:05Z" "$out" "timestamp parsed from the log line"
assert_file_exists "$EVENTS" "status emits a fleet event"
assert_file_contains "$EVENTS" '"event":"status"' "event records the subcommand"
assert_file_contains "$EVENTS" '"drift":"drifted"' "event carries the drift kv"

test_start "fleet_status_human_clean_without_state_log"
rm -f "$XDG_STATE_HOME/dotfiles/dot.log"
out="$(fleet status 2>&1)"
assert_contains "clean" "$out" "clean drift line rendered"
assert_not_contains "Last Apply" "$out" "no Last Apply line without a state log"

test_start "fleet_status_falls_back_to_hostname_and_default_namespace"
write_data <<'TOML'
profile = "laptop"
TOML
out="$(fleet status --json 2>&1)"
assert_contains "\"node_id\":\"$(hostname -s)\"" "$out" "node_id falls back to hostname -s"
assert_contains '"namespace":"default"' "$out" "namespace falls back to default"

test_start "fleet_status_forwards_event_to_https_endpoint"
write_data <<'TOML'
node_id = "node-b"
endpoint = "https://fleet.example.invalid/hook"
TOML
: >"$CURL_LOG"
fleet status >/dev/null 2>&1
assert_file_contains "$CURL_LOG" "https://fleet.example.invalid/hook" "curl POSTs to the configured endpoint"
assert_file_contains "$CURL_LOG" '"node_id":"node-b"' "payload is sent as the request body"

test_start "fleet_status_ignores_non_https_endpoint"
write_data <<'TOML'
endpoint = "http://plain.example.invalid/hook"
TOML
: >"$CURL_LOG"
fleet status >/dev/null 2>&1
assert_equals "" "$(cat "$CURL_LOG")" "plain-http endpoint is never called"

test_start "fleet_status_survives_unwritable_state_dir"
touch "$TMP/not-a-dir-file"
out="$(XDG_STATE_HOME="$TMP/not-a-dir-file" fleet status --json 2>&1)"
rc=$?
assert_equals 0 "$rc" "mkdir failure for the state dir is non-fatal"
assert_contains '{"node_id"' "$out" "status still renders"

# ── _fleet_enabled (no CLI surface; sourced in a subshell) ──────────
test_start "fleet_enabled_reads_enabled_flag"
write_data <<'TOML'
enabled = true
TOML
out="$(
  cd "$TMP" && set +e
  source "$FLEET" fleet status --json >/dev/null 2>&1
  if _fleet_enabled; then echo enabled; else echo disabled; fi
)"
assert_equals "enabled" "$out" "enabled = true is detected"
write_data <<'TOML'
enabled = false
TOML
out="$(
  cd "$TMP" && set +e
  source "$FLEET" fleet status --json >/dev/null 2>&1
  if _fleet_enabled; then echo enabled; else echo disabled; fi
)"
assert_equals "disabled" "$out" "anything else is disabled"

# ── drift check ─────────────────────────────────────────────────────
write_data <<'TOML'
node_id = "node-a"
TOML
rm -rf "$STATE_DIR"

test_start "fleet_drift_check_clean"
out="$(fleet drift check 2>&1)"
rc=$?
assert_equals 0 "$rc" "clean drift exits 0"
assert_contains "No drift detected" "$out" "clean message"
assert_file_contains "$HISTORY" '"status":"clean"' "clean entry appended to history"
assert_file_contains "$EVENTS" '"event":"drift_check"' "drift_check event emitted"

test_start "fleet_drift_check_reports_changed_files"
printf 'MM .zshrc\n M .bashrc\nA  .vimrc\nD  .gone\n' >"$TMP/drift4.txt"
out="$(FAKE_CHEZMOI_STATUS="$TMP/drift4.txt" fleet drift check 2>&1)"
rc=$?
assert_equals 0 "$rc" "drifted check still exits 0"
assert_contains "Configuration drift detected" "$out" "drift banner"
assert_contains ".zshrc" "$out" "MM file listed"
assert_contains ".gone" "$out" "other change types listed via info"
assert_file_contains "$HISTORY" '"status":"drifted"' "drifted entry appended"
assert_file_contains "$HISTORY" '.vimrc' "file names captured in history"
assert_file_contains "$EVENTS" '"count":"4"' "event carries the drift count"

test_start "fleet_drift_default_subcommand_is_check"
out="$(fleet drift 2>&1)"
assert_contains "Fleet Drift Report" "$out" "bare drift runs check"
out="$(fleet drift --verbose 2>&1)"
assert_contains "Fleet Drift Report" "$out" "flag-only argv runs check"

test_start "fleet_drift_check_without_chezmoi_fails"
out="$(PATH="$PATH_NO_CHEZMOI" fleet drift check 2>&1)"
rc=$?
assert_equals 1 "$rc" "missing chezmoi exits 1"
assert_contains "not installed" "$out" "explains what is missing"

# ── drift history ───────────────────────────────────────────────────
test_start "fleet_drift_history_empty"
rm -f "$HISTORY"
out="$(fleet drift history 2>&1)"
rc=$?
assert_equals 0 "$rc" "empty history exits 0"
assert_contains "No drift history recorded yet" "$out" "empty-history message"

test_start "fleet_drift_history_renders_entries"
mkdir -p "$STATE_DIR"
cat >"$HISTORY" <<'JSONL'
{"time":"2026-01-01T00:00:00Z","status":"clean","files":[]}
{"time":"2026-01-02T00:00:00Z","status":"drifted","files":[".zshrc",".bashrc"]}
not json at all
JSONL
out="$(fleet drift history 2>&1)"
rc=$?
assert_equals 0 "$rc" "history exits 0"
assert_contains "2026-01-01T00:00:00Z" "$out" "clean entry time shown"
assert_contains "drifted (2 files)" "$out" "drifted entry shows file count"
assert_contains "?" "$out" "unparsable line falls back to ? instead of aborting"

test_start "fleet_drift_history_honours_count"
out="$(fleet drift history 1 2>&1)"
assert_not_contains "2026-01-01T00:00:00Z" "$out" "only the last entry is shown"

# ── drift predict ───────────────────────────────────────────────────
test_start "fleet_drift_predict_without_history"
rm -f "$HISTORY"
out="$(fleet drift predict 2>&1)"
rc=$?
assert_equals 0 "$rc" "predict without history exits 0"
assert_contains "Not enough history" "$out" "explains the missing history"

test_start "fleet_drift_predict_flags_frequent_files"
mkdir -p "$STATE_DIR"
: >"$HISTORY"
for _ in 1 2 3 4 5 6; do
  echo '{"time":"t","status":"drifted","files":[".zshrc"]}' >>"$HISTORY"
done
echo '{"time":"t","status":"drifted","files":[".rare"]}' >>"$HISTORY"
out="$(fleet drift predict 2>&1)"
rc=$?
assert_equals 0 "$rc" "predict exits 0"
assert_contains "Likely to drift" "$out" "frequent file flagged"
assert_contains ".zshrc (drifted 6 times recently)" "$out" "count reported"
assert_not_contains ".rare (drifted" "$out" "below-threshold file not flagged"
assert_contains "7 checks recorded" "$out" "total checks reported"

test_start "fleet_drift_unknown_subcommand"
out="$(fleet drift bogus 2>&1)"
rc=$?
assert_equals 1 "$rc" "unknown drift subcommand exits 1"
assert_contains "Usage: dot fleet drift" "$out" "usage printed"

# ── events ──────────────────────────────────────────────────────────
test_start "fleet_events_without_log"
rm -f "$EVENTS"
out="$(fleet events 2>&1)"
rc=$?
assert_equals 0 "$rc" "no events exits 0"
assert_contains "No fleet events recorded yet" "$out" "empty message"
assert_contains "events.jsonl" "$out" "points at the events file"

mkdir -p "$STATE_DIR"
cat >"$EVENTS" <<'JSONL'
{"time":"2026-01-01T00:00:00Z","event":"status","status":"ok","node_id":"n1","namespace":"default","trace_id":"t"}
{"time":"2026-01-02T00:00:00Z","event":"drift_check","status":"clean","node_id":"n1","namespace":"default","trace_id":"t"}
{"time":"2026-01-03T00:00:00Z","event":"apply","status":"fail 7","node_id":"n2","namespace":"default","trace_id":"t"}
JSONL

test_start "fleet_events_with_jq"
out="$(fleet events 2>&1)"
rc=$?
assert_equals 0 "$rc" "events exits 0"
assert_contains "Fleet Events (last 20)" "$out" "default count in header"
assert_contains "drift_check" "$out" "clean event rendered"
assert_contains "apply" "$out" "failed event rendered"
assert_contains "(n2)" "$out" "node id shown per event"

test_start "fleet_events_count_argument"
out="$(fleet events 1 2>&1)"
assert_contains "Fleet Events (last 1)" "$out" "count reflected in header"
assert_not_contains "drift_check" "$out" "older events trimmed by count"

test_start "fleet_events_without_jq_prints_raw"
out="$(PATH="$PATH_NO_JQ" fleet events 2 2>&1)"
rc=$?
assert_equals 0 "$rc" "raw fallback exits 0"
assert_contains '{"time":"2026-01-03T00:00:00Z"' "$out" "raw jsonl lines printed"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
