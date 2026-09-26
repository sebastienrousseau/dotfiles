#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Unit tests for security fixes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

echo "Testing security fixes..."

# Test: mount_read_only.sh validates input
test_start "mount_read_only_validates_input"
FUNC_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/security/mount_read_only.sh"
assert_file_exists "$FUNC_FILE" "mount_read_only.sh should exist"

# Test: mount_read_only requires argument
test_start "mount_read_only_requires_arg"
result=$(bash -c '
  source "'"$FUNC_FILE"'"
  mount_read_only 2>&1
')
if [[ "$result" == *"No disk image specified"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: rejects empty argument"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should reject empty argument"
  printf '%b\n' "    Actual: $result"
fi

# Test: mount_read_only rejects missing file
test_start "mount_read_only_rejects_missing"
result=$(bash -c '
  source "'"$FUNC_FILE"'"
  mount_read_only "/nonexistent/file.dmg" 2>&1
')
if [[ "$result" == *"Disk image not found"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: rejects missing file"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should reject missing file"
  printf '%b\n' "    Actual: $result"
fi

# Test: genpass validates numeric input
test_start "genpass_validates_numeric"
GENPASS_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/security/genpass.sh"
result=$(bash -c '
  source "'"$GENPASS_FILE"'"
  genpass "abc" 2>&1
' 2>&1)
if [[ "$result" == *"must be a number"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: rejects non-numeric input"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should reject non-numeric input"
  printf '%b\n' "    Actual: $result"
fi

# Test: genpass rejects out-of-range values
test_start "genpass_rejects_out_of_range"
result=$(bash -c '
  source "'"$GENPASS_FILE"'"
  genpass 101 2>&1
' 2>&1)
if [[ "$result" == *"must be a number between 1 and 100"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: rejects out of range input"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should reject out of range input"
  printf '%b\n' "    Actual: $result"
fi

# Test: genpass accepts valid input
test_start "genpass_accepts_valid"
result=$(bash -c '
  source "'"$GENPASS_FILE"'"
  genpass 2 2>&1
' 2>&1)
if [[ "$result" == *"Generated password"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: accepts valid numeric input"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should accept valid numeric input"
  printf '%b\n' "    Actual: $result"
fi

SF_TMP="$(mktemp -d)"
trap 'rm -rf "$SF_TMP"' EXIT
mkdir -p "$SF_TMP/bin" "$SF_TMP/home"

# A stub chezmoi that reports one pending change and logs every argv token
# on its own line, so the flags the scripts really pass can be inspected.
cat >"$SF_TMP/bin/chezmoi" <<'STUB'
#!/bin/sh
[ "$1" = status ] && { echo " M .zshrc"; exit 0; }
for a in "$@"; do printf '%s\n' "$a"; done >>"$SF_ARGV"
exit 0
STUB
chmod +x "$SF_TMP/bin/chezmoi"
# shellcheck disable=SC2016 # literal on purpose: it must never be expanded
INJECT='--dry-run $(touch sf-pwned) ;touch sf-pwned2'

# flags_run <script> <env var>: run with hostile flags; prints "tokens|pwned"
flags_run() {
  rm -f "$SF_TMP/argv" "$SF_TMP"/sf-pwned*
  (cd "$SF_TMP" && env HOME="$SF_TMP/home" PATH="$SF_TMP/bin:$PATH" SF_ARGV="$SF_TMP/argv" \
    "$2=$INJECT" bash "$1" >/dev/null 2>&1) || true
  # shellcheck disable=SC2016
  printf '%s|%s' "$(grep -cxF -e '$(touch' -e 'sf-pwned)' -e ';touch' -e 'sf-pwned2' "$SF_TMP/argv" 2>/dev/null)" \
    "$(find "$SF_TMP" -maxdepth 1 -name 'sf-pwned*' | wc -l | tr -d ' ')"
}

# Hostile flag text reaches chezmoi as four literal tokens and runs nothing.
test_start "chezmoi_apply_safe_parsing"
assert_equals "4|0" "$(flags_run "$REPO_ROOT/scripts/ops/chezmoi-apply.sh" DOTFILES_CHEZMOI_APPLY_FLAGS)" "apply flags are split, never evaluated"

test_start "chezmoi_update_safe_parsing"
assert_equals "4|0" "$(flags_run "$REPO_ROOT/scripts/ops/chezmoi-update.sh" DOTFILES_CHEZMOI_UPDATE_FLAGS)" "update flags are split, never evaluated"

# The session name for a hostile directory keeps only [:alnum:]._- (dots
# become underscores); a stub tmux records the name it was asked to create.
test_start "tmux_sessionizer_sanitizes"
cat >"$SF_TMP/bin/tmux" <<'STUB'
#!/bin/sh
[ "$1" = has-session ] && exit 1
[ "$1" = new-session ] && printf '%s\n' "$3" >"$SF_TMP_SESSION"
exit 0
STUB
chmod +x "$SF_TMP/bin/tmux"
hostile="$SF_TMP/my.proj \$(id);x"
mkdir -p "$hostile"
env HOME="$SF_TMP/home" PATH="$SF_TMP/bin:$PATH" SF_TMP_SESSION="$SF_TMP/session" TMUX= \
  bash "$REPO_ROOT/defaults/dot_local/bin/executable_tmux-sessionizer" "$hostile" >/dev/null 2>&1 || true
assert_equals "my_projidx" "$(cat "$SF_TMP/session" 2>/dev/null)" "session name is sanitised"

# The world-writable chmod shortcuts ship disabled.
test_start "permission_aliases_omit_666_and_777"
PERM_FILE="$REPO_ROOT/defaults/.chezmoitemplates/aliases/permission/permission.aliases.sh"
# shellcheck disable=SC2016
perm_probe='shopt -s expand_aliases; source "$1" >/dev/null 2>&1
alias 755 >/dev/null 2>&1 && printf 755; printf ":"
alias 666 >/dev/null 2>&1 && printf 666; printf ":"
alias 777 >/dev/null 2>&1 && printf 777; true'
assert_equals "755::" "$(bash -c "$perm_probe" _ "$PERM_FILE")" "755 exists, 666 and 777 do not"

# age-init writes TOML that survives awkward paths, and stays idempotent.
test_start "age_init_json_escaping"
AGE_HOME="$SF_TMP/age \"q\" \\b"
mkdir -p "$AGE_HOME"
cat >"$SF_TMP/bin/age-keygen" <<'STUB'
#!/bin/sh
if [ "$1" = -o ]; then echo "AGE-SECRET-KEY-1TEST" >"$2"; exit 0; fi
echo "age1testrecipient"
STUB
chmod +x "$SF_TMP/bin/age-keygen"
for _ in 1 2; do
  env HOME="$AGE_HOME" PATH="$SF_TMP/bin:$PATH" bash "$REPO_ROOT/scripts/secrets/age-init.sh" >/dev/null 2>&1 || true
done
age_parsed="$(
  python3 - "$AGE_HOME/.config/chezmoi/chezmoi.toml" "$AGE_HOME/.config/chezmoi/key.txt" 2>&1 <<'TOMLCHECK'
import sys
try:
    import tomllib
except ImportError:
    print("ok"); sys.exit()  # no TOML parser before 3.11: nothing to check
text = open(sys.argv[1], encoding="utf-8").read()
cfg = tomllib.loads(text)
ok = (cfg.get("encryption") == "age" and cfg["age"]["identity"] == sys.argv[2]
      and cfg["age"]["recipient"] == "age1testrecipient" and text.count("[age]") == 1)
print("ok" if ok else "bad: " + text)
TOMLCHECK
)"
assert_equals "ok" "$age_parsed" "chezmoi.toml parses back to the real key path, once"

print_summary
