#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for four small dot_local/bin CLIs:
#
#   b64       — base64 transcoder: encode/decode, URL-safe mode and its
#               padding fix-up, argument vs stdin input, help.
#   jsonv     — JSON validator: jq path, python3 fallback, --format,
#               --quiet, unknown option, file vs stdin.
#   dtags     — Docker Hub tag lister: prerequisite check, usage, and
#               the buffered sort with a fake registry response.
#   rec-start — history disabling: nothing to do, backup, already
#               backed up, and an unwritable history file.
#
# Network and clipboard access are impossible here: `curl` is a PATH
# shim serving canned JSON and every history file lives under the
# sandbox HOME.
#
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Hand children a copy of the real stderr so their xtrace still reaches
# the coverage runner even though the probes capture output with 2>&1.
exec 21>&2
export BASH_XTRACEFD=21

BIN="$REPO_ROOT/defaults/dot_local/bin"
# Same bash as the harness: a /bin/bash 3.2 stub would change behaviour
# and truncate the xtrace the coverage runner reads.
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

_run() { # <script> [args…]
  local script="$1"
  shift
  "$BASH_BIN" "$script" "$@" 2>&1
}

# ── b64 ──────────────────────────────────────────────────────────────
B64="$BIN/executable_b64"

test_start "b64_encodes_and_decodes_an_argument"
_out="$(_run "$B64" "Hello World")"
assert_equals 0 "$?" "encode exits 0"
assert_equals "SGVsbG8gV29ybGQ=" "$(printf '%s' "$_out" | tr -d '\n')" "argument encoded"
_out="$(_run "$B64" --decode "SGVsbG8gV29ybGQ=")"
assert_equals "Hello World" "$(printf '%s' "$_out" | tr -d '\n')" "argument decoded"

test_start "b64_reads_stdin_when_no_argument_is_given"
_out="$(printf 'piped' | _run "$B64")"
assert_equals 0 "$?" "stdin encode exits 0"
assert_equals "cGlwZWQ=" "$(printf '%s' "$_out" | tr -d '\n')" "stdin encoded"

test_start "b64_url_safe_mode_round_trips_without_padding"
# 0xFB 0xFF 0xBE encodes to "+/++" in standard base64, so the URL-safe
# form exercises BOTH substitutions: + → - and / → _.
_out="$(printf '\373\377\276' | _run "$B64" --url)"
_enc="$(printf '%s' "$_out" | tr -d '\n')"
assert_equals "-_--" "$_enc" "URL-safe alphabet used (both + and / mapped)"
# Decoding re-pads and maps back. A leading `-` in tr's first set is an
# option to BSD tr, which broke this path on macOS until it was quoted
# with `--`; assert on the decoded bytes, not just the exit code.
_out="$(_run "$B64" -d -u "$_enc" | od -An -tx1 | tr -s ' ')"
assert_equals 0 "$?" "URL-safe decode exits 0 after re-padding"
assert_contains "fb ff be" "$_out" "URL-safe decode returns the original bytes"

test_start "b64_help_on_demand_and_on_an_empty_tty_less_invocation"
_out="$(_run "$B64" --help)"
assert_equals 0 "$?" "--help exits 0"
assert_contains "Usage: b64 [options] [string]" "$_out" "usage printed"
assert_contains "Base64 Transcoder" "$_out" "non-tty header printed"
_out="$(_run "$B64" -e -u --help)"
assert_contains "URL-safe mode" "$_out" "help still reachable after other flags"

# ── jsonv ────────────────────────────────────────────────────────────
JSONV="$BIN/executable_jsonv"
_json="$DOTFILES_COV_TMPDIR/good.json"
printf '{"a":[1,2],"b":"x"}\n' >"$_json"
_bad="$DOTFILES_COV_TMPDIR/bad.json"
printf '{"a":\n' >"$_bad"

test_start "jsonv_validates_a_file_and_reports_the_source"
_out="$(_run "$JSONV" "$_json")"
assert_equals 0 "$?" "valid JSON exits 0"
assert_contains "Valid JSON ($_json)" "$_out" "file named in the report"

test_start "jsonv_rejects_invalid_json"
_out="$(_run "$JSONV" "$_bad")"
assert_equals 1 "$?" "invalid JSON exits 1"
assert_contains "Invalid JSON" "$_out" "invalid report printed"

test_start "jsonv_reads_stdin_and_labels_it"
_out="$(printf '{"ok":true}' | _run "$JSONV")"
assert_equals 0 "$?" "stdin validation exits 0"
assert_contains "Valid JSON (stdin)" "$_out" "stdin labelled"

test_start "jsonv_format_pretty_prints"
_out="$(_run "$JSONV" --format "$_json")"
assert_equals 0 "$?" "--format exits 0"
assert_contains '"a"' "$_out" "formatted body printed"
assert_contains "Valid JSON" "$_out" "still reports validity"

test_start "jsonv_quiet_suppresses_the_success_line"
_out="$(_run "$JSONV" --quiet "$_json")"
assert_equals 0 "$?" "--quiet exits 0"
assert_equals "" "$_out" "no output in quiet mode"

test_start "jsonv_unknown_option_exits_1"
_out="$(_run "$JSONV" --nope "$_json")"
assert_equals 1 "$?" "unknown option exits 1"
assert_contains "Unknown option: --nope" "$_out" "option named"

test_start "jsonv_falls_back_to_python3_without_jq"
# PATH without jq — python3 must carry both the validate and the
# --format branch.
_nojq="$DOTFILES_COV_TMPDIR/nojq"
mkdir -p "$_nojq"
for t in bash cat printf echo python3; do
  p="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$_nojq/$t"
done
_out="$(PATH="$_nojq" "$BASH_BIN" "$JSONV" "$_json" 2>&1)"
assert_equals 0 "$?" "python3 fallback validates"
assert_contains "Valid JSON" "$_out" "fallback reports validity"
_out="$(PATH="$_nojq" "$BASH_BIN" "$JSONV" --format "$_json" 2>&1)"
assert_contains '"a"' "$_out" "python3 -m json.tool formatted the document"

test_start "jsonv_without_jq_or_python3_reports_the_missing_prerequisite"
_bare="$DOTFILES_COV_TMPDIR/bare-jsonv"
mkdir -p "$_bare"
for t in bash cat printf echo; do
  p="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$_bare/$t"
done
_out="$(PATH="$_bare" "$BASH_BIN" "$JSONV" "$_json" 2>&1)"
_rc=$?
assert_equals 1 "$_rc" "missing prerequisites exit 1"
assert_contains "jq or python3 required" "$_out" "prerequisite named"

# ── dtags ────────────────────────────────────────────────────────────
DTAGS="$BIN/executable_dtags"
_dt="$DOTFILES_COV_TMPDIR/dtags-bin"
mkdir -p "$_dt"
for t in bash cat printf echo sort command; do
  p="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$_dt/$t"
done
cat >"$_dt/curl" <<'SHIM'
#!/usr/bin/env bash
printf '{"results":[{"name":"3.9"},{"name":"3.10"},{"name":"3.11"}]}\n'
SHIM
_realjq="$(command -v jq || true)"
[[ -n "$_realjq" ]] && ln -sf "$_realjq" "$_dt/jq"
chmod +x "$_dt/curl"

test_start "dtags_lists_sorted_tags_from_the_registry"
if [[ -n "$_realjq" ]]; then
  _out="$(PATH="$_dt" "$BASH_BIN" "$DTAGS" python 2>&1)"
  assert_equals 0 "$?" "dtags exits 0"
  assert_contains "3.11" "$_out" "tag from the response listed"
  assert_equals "3.9
3.10
3.11" "$_out" "version sort orders 3.9 before 3.10"
else
  echo "  SKIP: jq unavailable"
fi

test_start "dtags_requires_an_image_argument"
_out="$(PATH="$_dt" "$BASH_BIN" "$DTAGS" 2>&1)"
assert_equals 1 "$?" "no argument exits 1"
assert_contains "Usage: dtags <image>" "$_out" "usage printed"

test_start "dtags_reports_a_missing_prerequisite"
_bare="$DOTFILES_COV_TMPDIR/bare-dtags"
mkdir -p "$_bare"
for t in bash cat printf echo sort; do
  p="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$_bare/$t"
done
_out="$(PATH="$_bare" "$BASH_BIN" "$DTAGS" python 2>&1)"
_rc=$?
assert_equals 1 "$_rc" "missing curl exits 1"
assert_contains "dtags requires curl" "$_out" "missing tool named"

# ── rec-start ────────────────────────────────────────────────────────
REC="$BIN/executable_rec-start"

test_start "rec_start_reports_when_there_is_nothing_to_disable"
_h="$DOTFILES_COV_TMPDIR/rec-empty"
mkdir -p "$_h"
_out="$(HOME="$_h" HISTFILE="" _run "$REC")"
assert_equals 0 "$?" "no history files exits 0"
assert_contains "No history files found" "$_out" "explains there is nothing to do"

test_start "rec_start_backs_up_every_history_file_it_finds"
_h="$DOTFILES_COV_TMPDIR/rec-full"
mkdir -p "$_h/.local/share/fish"
printf 'secret\n' >"$_h/.bash_history"
printf 'fish\n' >"$_h/.local/share/fish/fish_history"
printf 'zsh\n' >"$_h/.zsh_history"
_out="$(HOME="$_h" HISTFILE="$_h/.zsh_history" _run "$REC")"
_rc=$?
assert_equals 0 "$_rc" "backup run exits 0"
assert_contains "Recording mode ON (3 files backed up)" "$_out" "counts every file"
assert_file_exists "$_h/.zsh_history.bak" "HISTFILE backed up"
assert_file_exists "$_h/.bash_history.bak" "bash history backed up"
assert_file_exists "$_h/.local/share/fish/fish_history.bak" "fish history backed up"
assert_file_not_exists "$_h/.zsh_history" "original moved, not copied"

test_start "rec_start_is_idempotent_and_says_so"
printf 'again\n' >"$_h/.zsh_history"
_out="$(HOME="$_h" HISTFILE="$_h/.zsh_history" _run "$REC")"
_rc=$?
assert_equals 1 "$_rc" "second run exits 1"
assert_contains "Already backed up: $_h/.zsh_history" "$_out" "names the file it skipped"
assert_contains "History already disabled. Run rec-stop first." "$_out" "tells the user what to do"

test_start "rec_start_reports_a_history_file_it_cannot_move"
_h="$DOTFILES_COV_TMPDIR/rec-ro"
mkdir -p "$_h/locked"
printf 'x\n' >"$_h/locked/.zsh_history"
chmod 555 "$_h/locked"
_out="$(HOME="$_h" HISTFILE="$_h/locked/.zsh_history" _run "$REC")"
_rc=$?
chmod 755 "$_h/locked"
assert_equals 1 "$_rc" "unmovable history exits 1"
assert_contains "Failed to back up: $_h/locked/.zsh_history" "$_out" "failure reported"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
