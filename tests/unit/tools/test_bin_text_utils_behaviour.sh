#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for the text/encoding utilities in
# defaults/dot_local/bin: lorem, hex, hashsum, jwt, regex and yamlv. Each is
# run as a real command inside the coverage sandbox and asserted on its
# output and exit code — no host state is read or written.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

BIN_DIR="$REPO_ROOT/defaults/dot_local/bin"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

OUTF="$DOTFILES_COV_TMPDIR/out.txt"
WORK="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$WORK"
STDIN_FILE=/dev/null

# util <name> <args…> — run one utility, stdout to $OUTF, status in RC.
util() {
  local name="$1"
  shift
  # stderr stays attached so the child's xtrace reaches the coverage trace.
  bash "$BIN_DIR/executable_$name" "$@" >"$OUTF" <"$STDIN_FILE"
  RC=$?
  return 0
}
out_has() { assert_file_contains "$OUTF" "$1" "${2:-output contains $1}"; }

# ── lorem ───────────────────────────────────────────────────────────────
test_start "lorem_help_lists_the_types"
util lorem --help
assert_equals 0 "$RC" "rc"
out_has "Usage: lorem [type] [count]" "usage"
out_has "paragraphs, p" "types listed"

test_start "lorem_rejects_an_unknown_type"
util lorem sonnets
assert_equals 1 "$RC" "rc"
out_has "Unknown type: sonnets" "error"

test_start "lorem_generates_the_requested_number_of_words"
util lorem words 5
assert_equals 0 "$RC" "rc"
assert_equals "5" "$(wc -w <"$OUTF" | tr -d ' ')" "word count"
assert_true "grep -qE '^[A-Z]' '$OUTF'" "first word is capitalised"

test_start "lorem_generates_sentences"
util lorem s 3
assert_equals 0 "$RC" "rc"
assert_equals "3" "$(wc -l <"$OUTF" | tr -d ' ')" "one sentence per line"
assert_true "grep -qE '\\.$' '$OUTF'" "sentences end with a full stop"

test_start "lorem_defaults_to_one_paragraph"
util lorem
assert_equals 0 "$RC" "rc"
assert_equals "1" "$(grep -c . "$OUTF")" "a single non-empty paragraph"

test_start "lorem_separates_multiple_paragraphs_with_a_blank_line"
util lorem p 3
assert_equals 0 "$RC" "rc"
assert_equals "3" "$(grep -c . "$OUTF")" "three paragraphs"
assert_equals "2" "$(grep -c '^$' "$OUTF")" "two separators"

# ── hex ─────────────────────────────────────────────────────────────────
test_start "hex_help_lists_the_modes"
util hex --help
assert_equals 0 "$RC" "rc"
out_has "Usage: hex [OPTIONS] [INPUT]" "usage"

test_start "hex_rejects_an_unknown_option"
util hex --nope
assert_equals 1 "$RC" "rc"
out_has "Unknown option: --nope" "error"

test_start "hex_encodes_a_string"
util hex -e hello
assert_equals 0 "$RC" "rc"
out_has "68656c6c6f" "hex of 'hello'"

test_start "hex_decodes_a_hex_string"
util hex --decode "68656c6c6f"
assert_equals 0 "$RC" "rc"
out_has "hello" "round trip"

test_start "hex_encodes_stdin_when_no_argument_is_given"
printf 'hi\n' >"$WORK/in.txt"
STDIN_FILE="$WORK/in.txt" util hex -e
assert_equals 0 "$RC" "rc"
out_has "6869" "hex of 'hi'"

test_start "hex_views_a_file"
printf 'AB' >"$WORK/bin.dat"
util hex "$WORK/bin.dat"
assert_equals 0 "$RC" "rc"
out_has "4142" "file bytes"

test_start "hex_honours_the_bytes_per_line_flag"
printf 'ABCD' >"$WORK/bin2.dat"
util hex -n 2 "$WORK/bin2.dat"
assert_equals 0 "$RC" "rc"
assert_equals "2" "$(wc -l <"$OUTF" | tr -d ' ')" "two lines of two bytes"

test_start "hex_views_stdin_when_the_path_is_not_a_file"
STDIN_FILE="$WORK/in.txt" util hex
assert_equals 0 "$RC" "rc"
out_has "6869" "stdin viewed"

test_start "hex_falls_back_to_hexdump_then_od_then_errors"
# The viewer prefers xxd, then hexdump, then od; hide them one at a time.
HEXPATH="$DOTFILES_COV_TMPDIR/hexpath"
mkdir -p "$HEXPATH"
ln -sf "$(command -v bash)" "$HEXPATH/bash"
for c in printf echo cat tr sed grep; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$HEXPATH/$c"
done
for c in hexdump od; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$HEXPATH/$c"
done
PATH="$HEXPATH" util hex "$WORK/bin.dat"
assert_equals 0 "$RC" "rc"
out_has "41 42" "hexdump rendered the bytes"
rm -f "$HEXPATH/hexdump"
PATH="$HEXPATH" util hex "$WORK/bin.dat"
# The od arm passes `-t x1z`. GNU od accepts the `z` format character and
# renders the dump; BSD od (macOS) rejects it, so the arm surfaces od's own
# failure. Assert whichever this platform's od actually does — and in both
# cases that it is the od arm, not the no-tool error.
if od -A x -t x1z -v /dev/null >/dev/null 2>&1; then
  assert_equals 0 "$RC" "the od fallback rendered the dump"
  # GNU od spaces the byte columns: "41 42".
  out_has "41 42" "od rendered the bytes"
else
  assert_true "[[ $RC -ne 0 ]]" "the od fallback ran and surfaced od's failure"
fi
assert_true "! grep -q 'required' '$OUTF'" "and it is not the no-tool error"
rm -f "$HEXPATH/od"
PATH="$HEXPATH" util hex "$WORK/bin.dat"
assert_equals 1 "$RC" "rc"
out_has "xxd, hexdump, or od required" "error names every option"

test_start "hex_colour_mode_pipes_through_bat"
cat >"$DOTFILES_COV_TMPDIR/bin/bat" <<STUB
#!$(command -v bash)
printf 'bat %s\n' "\$*"
cat
STUB
chmod +x "$DOTFILES_COV_TMPDIR/bin/bat"
util hex -c "$WORK/bin.dat"
assert_equals 0 "$RC" "rc"
out_has "bat --language=xxd --style=plain" "colouriser invoked"
out_has "4142" "bytes still rendered"

# ── hashsum ─────────────────────────────────────────────────────────────
KNOWN_SHA256="2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824" # "hello"
KNOWN_MD5="5d41402abc4b2a76b9719d911017c592"

test_start "hashsum_help_documents_the_rename"
util hashsum --help
assert_equals 0 "$RC" "rc"
out_has "renamed from 'hash'" "note"

test_start "hashsum_rejects_an_unknown_option"
util hashsum --nope
assert_equals 1 "$RC" "rc"
out_has "Unknown option: --nope" "error"

test_start "hashsum_defaults_to_sha256"
util hashsum hello
assert_equals 0 "$RC" "rc"
out_has "$KNOWN_SHA256" "sha256 of 'hello'"

test_start "hashsum_supports_every_algorithm_flag"
util hashsum -m hello
out_has "$KNOWN_MD5" "md5"
util hashsum --sha1 hello
out_has "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d" "sha1"
util hashsum -5 hello
out_has "9b71d224bd62f3785d96d46ad3ea3d73319bfbc2890caadae2dff72519673ca7" "sha512"
util hashsum -2 hello
out_has "$KNOWN_SHA256" "sha256"

test_start "hashsum_all_mode_prints_every_algorithm"
util hashsum -a hello
assert_equals 0 "$RC" "rc"
assert_equals "4" "$(grep -c . "$OUTF")" "four rows"
out_has "$KNOWN_MD5" "md5 row"
out_has "$KNOWN_SHA256" "sha256 row"

test_start "hashsum_hashes_a_file"
printf 'hello' >"$WORK/hello.txt"
util hashsum -f "$WORK/hello.txt"
assert_equals 0 "$RC" "rc"
out_has "$KNOWN_SHA256" "same digest as the string"

test_start "hashsum_reports_a_missing_file"
util hashsum --file "$WORK/absent.txt"
assert_equals 1 "$RC" "rc"
out_has "File not found" "error"

test_start "hashsum_check_mode_accepts_a_matching_digest"
util hashsum -c "$KNOWN_SHA256" hello
assert_equals 0 "$RC" "rc"
out_has "Hash matches" "verdict"

test_start "hashsum_check_mode_is_case_insensitive"
util hashsum -c "$(printf '%s' "$KNOWN_SHA256" | tr 'a-z' 'A-Z')" hello
assert_equals 0 "$RC" "rc"
out_has "Hash matches" "verdict"

test_start "hashsum_check_mode_rejects_a_mismatch"
util hashsum -c "$KNOWN_MD5" hello
assert_equals 1 "$RC" "rc"
out_has "Hash mismatch" "verdict"
out_has "Expected: $KNOWN_MD5" "expected digest echoed"

test_start "hashsum_reads_stdin_when_given_no_input"
printf 'hello\n' >"$WORK/hello-stdin.txt"
STDIN_FILE="$WORK/hello-stdin.txt" util hashsum
assert_equals 0 "$RC" "rc"
out_has "$KNOWN_SHA256" "digest of the piped string"

# ── jwt ─────────────────────────────────────────────────────────────────
b64url() { printf '%s' "$1" | base64 | tr '+/' '-_' | tr -d '=\n'; }
HDR="$(b64url '{"alg":"HS256","typ":"JWT"}')"
PAST="$(b64url '{"sub":"tester","exp":1000000000,"iat":999999999}')"
FUTURE="$(b64url '{"sub":"tester","exp":4102444800}')"

test_start "jwt_rejects_a_token_without_a_payload"
util jwt "onlyonepart"
assert_equals 1 "$RC" "rc"
out_has "Invalid JWT format" "error"

test_start "jwt_decodes_header_and_payload"
util jwt "$HDR.$PAST.signature"
assert_equals 0 "$RC" "rc"
out_has "=== Header ===" "header section"
out_has "HS256" "alg decoded"
out_has "tester" "payload decoded"
out_has "=== Signature ===" "signature section"
out_has "9 characters" "signature length reported"

test_start "jwt_flags_an_expired_token"
util jwt "$HDR.$PAST.sig"
assert_equals 0 "$RC" "rc"
out_has "Token EXPIRED at" "expiry verdict"
out_has "Issued at" "iat rendered"

test_start "jwt_reports_a_future_expiry"
util jwt "$HDR.$FUTURE.sig"
assert_equals 0 "$RC" "rc"
out_has "Token expires at" "expiry verdict"

test_start "jwt_strips_a_bearer_prefix_and_reads_stdin"
printf 'Bearer %s.%s.sig\n' "$HDR" "$FUTURE" >"$WORK/token.txt"
STDIN_FILE="$WORK/token.txt" util jwt
assert_equals 0 "$RC" "rc"
out_has "tester" "payload decoded from stdin"

# ── regex ───────────────────────────────────────────────────────────────
test_start "regex_help_and_missing_pattern"
util regex --help
assert_equals 0 "$RC" "rc"
out_has "Usage: regex [OPTIONS]" "usage"
util regex
assert_equals 1 "$RC" "rc"
out_has "Usage: regex [OPTIONS]" "usage on no args"

test_start "regex_rejects_an_unknown_option"
util regex --nope
assert_equals 1 "$RC" "rc"
out_has "Unknown option: --nope" "error"

test_start "regex_reports_a_match"
util regex --no-color '[0-9]+' 'abc123def'
assert_equals 0 "$RC" "rc"
out_has "Pattern: [0-9]+" "pattern echoed"
out_has "Pattern matches" "verdict"

test_start "regex_reports_a_miss_with_exit_1"
util regex --no-color '[0-9]+' 'abcdef'
assert_equals 1 "$RC" "rc"
out_has "Pattern does not match" "verdict"

test_start "regex_global_mode_counts_matches"
util regex --no-color -g '[a-z]+' 'hello world'
assert_equals 0 "$RC" "rc"
# `wc -l` pads its count on BSD, so match the row rather than an exact string.
assert_true "grep -qE 'Found +2 match\(es\)' '$OUTF'" "count"

test_start "regex_global_mode_reports_no_matches"
util regex --no-color --global '[0-9]+' 'abc'
assert_equals 1 "$RC" "rc"
out_has "No matches found" "verdict"

test_start "regex_case_insensitive_and_colour_flags"
util regex -i -c 'HELLO' 'hello'
assert_equals 0 "$RC" "rc"
out_has "Pattern matches" "verdict"

test_start "regex_file_mode_reads_the_file"
printf '# comment\nplain\n' >"$WORK/config.txt"
util regex --no-color -f '^#' "$WORK/config.txt"
assert_equals 0 "$RC" "rc"
out_has "Pattern matches" "verdict"

test_start "regex_file_mode_requires_a_readable_file"
util regex -f '^#' "$WORK/absent.txt"
assert_equals 1 "$RC" "rc"
out_has "File required for -f mode" "error"

test_start "regex_reads_stdin_when_no_input_is_given"
printf 'from stdin\n' >"$WORK/stdin.txt"
STDIN_FILE="$WORK/stdin.txt" util regex --no-color 'stdin'
assert_equals 0 "$RC" "rc"
out_has "Pattern matches" "verdict"

# ── yamlv ───────────────────────────────────────────────────────────────
test_start "yamlv_accepts_a_valid_file"
printf 'key: value\nlist:\n  - one\n' >"$WORK/good.yaml"
util yamlv "$WORK/good.yaml"
assert_equals 0 "$RC" "rc"
out_has "Valid YAML" "verdict"
out_has "good.yaml" "source named"

test_start "yamlv_rejects_an_invalid_file"
printf 'key: [unclosed\n' >"$WORK/bad.yaml"
util yamlv "$WORK/bad.yaml"
assert_equals 1 "$RC" "rc"
out_has "Invalid YAML" "verdict"

test_start "yamlv_quiet_mode_prints_nothing_on_success"
util yamlv -q "$WORK/good.yaml"
assert_equals 0 "$RC" "rc"
assert_equals "0" "$(wc -c <"$OUTF" | tr -d ' ')" "no output"

test_start "yamlv_validates_stdin"
STDIN_FILE="$WORK/good.yaml" util yamlv
assert_equals 0 "$RC" "rc"
out_has "Valid YAML (stdin)" "source is stdin"

test_start "yamlv_falls_back_to_python_when_yq_is_absent"
NOYQ="$DOTFILES_COV_TMPDIR/noyq"
mkdir -p "$NOYQ"
ln -sf "$(command -v bash)" "$NOYQ/bash"
for c in cat printf echo sed grep tr head; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$NOYQ/$c"
done
# python3 on PATH here is a mise shim, which needs mise itself; link the real
# interpreter so the fallback can actually run. Whether *that* interpreter has
# PyYAML installed is a property of the host, so assert the branch was taken
# (a verdict was reached) rather than which way it went.
ln -sf "$(python3 -c 'import sys; print(sys.executable)')" "$NOYQ/python3"
PATH="$NOYQ" util yamlv "$WORK/good.yaml"
assert_true "grep -qE '(Valid|Invalid) YAML' '$OUTF'" "the python fallback reached a verdict"
assert_true "[[ $RC -eq 0 || $RC -eq 1 ]]" "and exited with a validation status"

test_start "yamlv_reports_when_no_validator_is_available"
NOVAL="$DOTFILES_COV_TMPDIR/noval"
mkdir -p "$NOVAL"
ln -sf "$(command -v bash)" "$NOVAL/bash"
for c in cat printf echo sed grep tr head; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$NOVAL/$c"
done
PATH="$NOVAL" util yamlv "$WORK/good.yaml"
assert_equals 1 "$RC" "rc"
out_has "yq, python3+pyyaml, or ruby required" "error names every option"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
