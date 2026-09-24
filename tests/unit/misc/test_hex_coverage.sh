#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for dot_local/bin/hex: option parsing, encode/decode
# from arguments and stdin, file and stdin viewing, bat colouring and the
# hexdump / od / nothing fallbacks. Converters are sandboxed stubs so the
# test controls exactly which ones are on PATH.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

HEX="$REPO_ROOT/defaults/dot_local/bin/executable_hex"
BASH_BIN="$(command -v bash)"

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/hex-cov.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME"

BASE="$SANDBOX/base"
mkdir -p "$BASE"
for t in bash cat tr env; do
  p="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$BASE/$t"
done

_stub() { # <dir> <name> <body>
  mkdir -p "$1"
  printf '#!/usr/bin/env bash\n%s\n' "$3" >"$1/$2"
  chmod +x "$1/$2"
}

# A deterministic xxd: -p encodes via od-free printf, -r -p decodes,
# anything else echoes its argv so the view arms can be asserted.
XXD="$SANDBOX/xxd"
_stub "$XXD" xxd '
if [[ "$1" == "-p" ]]; then
  s="$(cat)"; for ((i = 0; i < ${#s}; i++)); do printf "%02x" "'"'"'${s:i:1}"; done; echo
elif [[ "$1" == "-r" ]]; then
  s="$(cat)"; for ((i = 0; i < ${#s}; i += 2)); do printf "\\x${s:i:2}"; done
else
  echo "xxd:$*"
fi'

SAMPLE="$SANDBOX/sample.bin"
printf 'hi' >"$SAMPLE"

_hex() { # <PATH> [args…]
  local path="$1"
  shift
  PATH="$path" "$BASH_BIN" "$HEX" "$@" 2>&1
}

test_start "help"
out="$(_hex "$BASE" --help)"
assert_equals "0" "$?" "help exits 0"
assert_contains "Usage: hex [OPTIONS] [INPUT]" "$out" "usage printed"

test_start "unknown_option"
out="$(_hex "$BASE" --nope)"
assert_equals "1" "$?" "unknown option exits 1"
assert_contains "Unknown option: --nope" "$out" "names option"
assert_contains "Usage:" "$out" "prints usage"

test_start "encode_argument"
out="$(_hex "$XXD:$BASE" -e hello)"
assert_equals "0" "$?" "encode exits 0"
assert_equals "68656c6c6f" "$out" "hello encoded"

test_start "encode_stdin"
out="$(printf 'AB\n' | _hex "$XXD:$BASE" --encode)"
assert_equals "4142" "$out" "stdin encoded"

test_start "decode_argument"
out="$(_hex "$XXD:$BASE" -d '68 69')"
assert_equals "0" "$?" "decode exits 0"
assert_equals "hi" "$out" "spaces stripped and decoded"

test_start "decode_stdin"
out="$(printf '6869\n' | _hex "$XXD:$BASE" --decode)"
assert_equals "hi" "$out" "stdin decoded"

test_start "view_file_with_length"
out="$(_hex "$XXD:$BASE" -n 8 "$SAMPLE")"
assert_equals "0" "$?" "view exits 0"
assert_equals "xxd:-c 8 $SAMPLE" "$out" "xxd gets width and file"

test_start "view_stdin"
out="$(printf 'x' | _hex "$XXD:$BASE" --length 4)"
assert_equals "xxd:-c 4 -" "$out" "stdin read via -"

test_start "color_with_bat"
d="$SANDBOX/bat"
_stub "$d" bat 'echo "bat:$*"; cat'
out="$(_hex "$d:$XXD:$BASE" -c "$SAMPLE")"
assert_contains "bat:--language=xxd --style=plain" "$out" "piped through bat"
assert_contains "xxd:-c 16 $SAMPLE" "$out" "default width 16"

test_start "color_without_bat"
out="$(_hex "$XXD:$BASE" --color "$SAMPLE")"
assert_equals "xxd:-c 16 $SAMPLE" "$out" "plain xxd when bat missing"

test_start "hexdump_fallback"
d="$SANDBOX/hd"
_stub "$d" hexdump 'echo "hexdump:$*"'
out="$(_hex "$d:$BASE" "$SAMPLE")"
assert_equals "hexdump:-C $SAMPLE" "$out" "hexdump -C used"

test_start "od_fallback"
d="$SANDBOX/od"
_stub "$d" od 'echo "od:$*"'
out="$(_hex "$d:$BASE" "$SAMPLE")"
assert_equals "od:-A x -t x1z -v $SAMPLE" "$out" "od used"

test_start "no_converter"
out="$(_hex "$BASE" "$SAMPLE")"
assert_equals "1" "$?" "exits 1"
assert_contains "xxd, hexdump, or od required" "$out" "requirement explained"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
