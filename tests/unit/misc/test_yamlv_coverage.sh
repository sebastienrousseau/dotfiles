#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for dot_local/bin/yamlv: file and stdin input, quiet
# mode, invalid YAML, and each validator backend (yq, python3, ruby,
# none). Backends are sandboxed stubs that accept input unless it
# contains the word BROKEN, so no real YAML library is required.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

YAMLV="$REPO_ROOT/defaults/dot_local/bin/executable_yamlv"
BASH_BIN="$(command -v bash)"

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/yamlv-cov.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME"

BASE="$SANDBOX/base"
mkdir -p "$BASE"
for t in bash cat env grep; do
  p="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$BASE/$t"
done

_stub() { # <dir> <name> <body>
  mkdir -p "$1"
  printf '#!/usr/bin/env bash\n%s\n' "$3" >"$1/$2"
  chmod +x "$1/$2"
}

LOG="$SANDBOX/calls.log"
YQ="$SANDBOX/yq"
_stub "$YQ" yq "echo \"yq \$*\" >>'$LOG'; ! grep -q BROKEN"
PY="$SANDBOX/py"
_stub "$PY" python3 "echo \"python3 \$1\" >>'$LOG'; [[ \"\$2\" != *BROKEN* ]]"
RB="$SANDBOX/rb"
_stub "$RB" ruby "echo \"ruby \$*\" >>'$LOG'; ! grep -q BROKEN"

GOOD="$SANDBOX/good.yaml"
BAD="$SANDBOX/bad.yaml"
printf 'key: value\n' >"$GOOD"
printf 'key: BROKEN\n' >"$BAD"

_yamlv() { # <PATH> [args…]
  local path="$1"
  shift
  PATH="$path" "$BASH_BIN" "$YAMLV" "$@" 2>&1
}

test_start "yq_valid_file"
: >"$LOG"
out="$(_yamlv "$YQ:$BASE" "$GOOD")"
assert_equals "0" "$?" "exits 0"
assert_equals "Valid YAML ($GOOD)" "$out" "reports valid file"
assert_equals "yq -e ." "$(cat "$LOG")" "yq used"

test_start "yq_invalid_file"
out="$(_yamlv "$YQ:$BASE" "$BAD")"
assert_equals "1" "$?" "exits 1"
assert_equals "Invalid YAML ($BAD)" "$out" "reports invalid file"

test_start "quiet_mode"
out="$(_yamlv "$YQ:$BASE" -q "$GOOD")"
assert_equals "0" "$?" "exits 0"
assert_equals "" "$out" "silent on success"
out="$(_yamlv "$YQ:$BASE" --quiet "$BAD")"
assert_equals "1" "$?" "quiet still fails on invalid"

test_start "stdin_input"
out="$(printf 'a: 1\n' | _yamlv "$YQ:$BASE")"
assert_equals "0" "$?" "exits 0"
assert_equals "Valid YAML (stdin)" "$out" "labels stdin"

test_start "python_fallback"
: >"$LOG"
out="$(_yamlv "$PY:$BASE" "$GOOD")"
assert_equals "0" "$?" "exits 0"
assert_equals "python3 -c" "$(cat "$LOG")" "python3 used"
out="$(_yamlv "$PY:$BASE" "$BAD")"
assert_equals "1" "$?" "python3 rejects invalid"

test_start "ruby_fallback"
: >"$LOG"
out="$(_yamlv "$RB:$BASE" "$GOOD")"
assert_equals "0" "$?" "exits 0"
assert_equals "ruby -ryaml -e YAML.safe_load(STDIN.read)" "$(cat "$LOG")" "ruby used"

test_start "no_validator"
out="$(_yamlv "$BASE" "$GOOD")"
assert_equals "1" "$?" "exits 1"
assert_contains "yq, python3+pyyaml, or ruby required" "$out" "requirement explained"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
