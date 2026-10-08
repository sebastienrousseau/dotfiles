#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Tests for 10-secrets.sh compatibility in bash and zsh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SECRETS_FILE="${SECRETS_FILE:-$REPO_ROOT/defaults/dot_config/shell/10-secrets.sh}"

test_start "secrets_autoload_file_exists"
assert_file_exists "$SECRETS_FILE" "10-secrets script should exist"

WORK="$(mktemp -d -t secrets-autoload.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/tmp"

# A dot stub that records its argv. `dot secrets load <bucket>` answers the
# way the real command does: one `export KEY=%q-quoted-value` line per key.
# Any other command (such as `dot env load`, which is the mise handler)
# prints nothing useful.
cat >"$WORK/bin/dot" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$WORK/dot.log"
if [ "\$1" = secrets ] && [ "\$2" = load ]; then
  case "\$3" in
    ai) printf 'export %s=%q\n' DOT_TEST_AI "it's a \"secret\" \\\$HOME" ;;
    work) printf 'export %s=%q\n' DOT_TEST_WORK 'w1' ;;
    *) echo "No secrets loaded for bucket: \$3" >&2; exit 1 ;;
  esac
fi
exit 0
STUB
chmod +x "$WORK/bin/dot"

# Source the snippet in a clean shell whose temp dir (TMPDIR for bash,
# TMPPREFIX for zsh here-strings) is empty and read-only, so any temp file
# fails, then print what a child process sees: only exports count.
run_snippet() { # shell
  rm -f "$WORK/dot.log"
  rm -rf "$WORK/tmp" && mkdir -p "$WORK/tmp" && chmod 555 "$WORK/tmp"
  OUT=""
  RC=0
  OUT="$(env -i HOME="$WORK" PATH="$WORK/bin:/usr/bin:/bin" TMPDIR="$WORK/tmp" TMPPREFIX="$WORK/tmp/zsh" \
    DOTFILES_SECRETS_AUTO_LOAD=1 DOTFILES_SECRETS_BUCKET_NAMES='ai,,missing,work' \
    "$1" -c 'source "$1" && env | grep "^DOT_TEST_" | sort' _ "$SECRETS_FILE" 2>&1)" || RC=$?
}

check_shell() { # shell
  local sh="$1"
  test_start "secrets_autoload_${sh}_exports_bucket_values"
  run_snippet "$sh"
  assert_equals "0" "$RC" "sourcing under $sh succeeds"
  assert_equals "DOT_TEST_AI=it's a \"secret\" \$HOME
DOT_TEST_WORK=w1" "$OUT" "every bucket's values are exported verbatim"

  test_start "secrets_autoload_${sh}_calls_dot_secrets_load"
  assert_equals "secrets load ai
secrets load missing
secrets load work" "$(cat "$WORK/dot.log" 2>/dev/null)" "each named bucket goes to dot secrets load"

  test_start "secrets_autoload_${sh}_writes_no_temp_files"
  assert_equals "" "$(ls -A "$WORK/tmp")" "TMPDIR stays empty"
}

check_shell bash
if command -v zsh >/dev/null 2>&1; then
  check_shell zsh
else
  test_start "secrets_autoload_zsh"
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: zsh not available, skipped"
fi

test_start "secrets_autoload_off_by_default"
rm -f "$WORK/dot.log"
env -i HOME="$WORK" PATH="$WORK/bin:/usr/bin:/bin" DOTFILES_SECRETS_BUCKET_NAMES=ai \
  bash -c 'source "$1"' _ "$SECRETS_FILE"
assert_false '[[ -e "$WORK/dot.log" ]]' "without DOTFILES_SECRETS_AUTO_LOAD=1 dot is never run"

test_start "secrets_autoload_ignores_non_shell_output"
cat >"$WORK/bin/dot" <<'STUB'
#!/usr/bin/env bash
echo 'touch "$HOME/pwned"'
STUB
env -i HOME="$WORK" PATH="$WORK/bin:/usr/bin:/bin" DOTFILES_SECRETS_AUTO_LOAD=1 \
  DOTFILES_SECRETS_BUCKET_NAMES=ai bash -c 'source "$1"' _ "$SECRETS_FILE"
assert_false '[[ -e "$WORK/pwned" ]]' "output that is not export/typeset/unset is not evaluated"

echo ""
echo "Secrets autoload tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
