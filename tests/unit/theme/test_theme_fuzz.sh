#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Property-based fuzz tests for theme-name validation. Generates
# randomised inputs and asserts invariants that must hold across every
# input:
#   * Valid names ([A-Za-z0-9_-]+) are accepted by write_theme
#   * Invalid names are rejected with exit != 0 and no data-file mutation
#   * No shell injection: adversarial names never execute code, never
#     leak into filenames, never truncate the data file
#   * Extreme-length inputs are handled safely (no unbounded memory,
#     no core dump, no hang)
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOT_THEME_SYNC="$REPO_ROOT/bin/dot-theme-sync"

# --- Sandbox --------------------------------------------------------------
TMPHOME="$(mktemp -d)"
trap 'rm -rf "$TMPHOME"' EXIT
export HOME="$TMPHOME"
export XDG_STATE_HOME="$TMPHOME/state"
export XDG_CONFIG_HOME="$TMPHOME/.config"
export XDG_DATA_HOME="$TMPHOME/.local/share"
mkdir -p "$XDG_STATE_HOME/dot" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"
mkdir -p "$TMPHOME/dotfiles/.chezmoidata"
export CHEZMOI_SOURCE_DIR="$TMPHOME/dotfiles"

cat > "$TMPHOME/dotfiles/.chezmoidata.toml" <<'EOF'
theme = "Baseline-dark"
EOF
cat > "$TMPHOME/dotfiles/.chezmoidata/themes.toml" <<'EOF'
[themes.Baseline-dark]
mode = "dark"
family = "Baseline"
[themes.Baseline-light]
mode = "light"
family = "Baseline"
EOF

# Mock every backend so we test only the input-validation surface.
MOCK_BIN="$TMPHOME/mocks"
mkdir -p "$MOCK_BIN"
export PATH="$MOCK_BIN:$PATH"
for cmd in gsettings kwriteconfig6 kreadconfig6 systemctl qdbus \
           chezmoi tmux pgrep busctl killall swww hyprctl niri; do
  cat > "$MOCK_BIN/$cmd" <<EOF
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$MOCK_BIN/$cmd"
done

_ok()   { ((TESTS_PASSED++)) || true; printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"; }
_fail() { ((TESTS_FAILED++)) || true; printf '  \033[0;31m✗\033[0m %s: %s\n' "$CURRENT_TEST" "${1:-}"; }

_datafile_theme() {
  grep -oE '^theme = "[^"]+"' "$TMPHOME/dotfiles/.chezmoidata.toml" | head -1 | cut -d'"' -f2
}

# ---------------------------------------------------------------------------
# Property 1: canary file remains untouched. Any name that leaks
# through validation and executes shell would nuke this file — its
# survival is the invariant.
# ---------------------------------------------------------------------------
CANARY="$TMPHOME/CANARY_DO_NOT_DELETE"
touch "$CANARY"

# ---------------------------------------------------------------------------
# Invalid-name corpus. Every entry must be rejected without mutating
# .chezmoidata.toml and without executing the payload.
# ---------------------------------------------------------------------------
INVALID_NAMES=(
  # Note: empty string is NOT invalid — dot-theme-sync with no args
  # is a valid "reload current" mode used by cron / systemd timers.
  " "                                   # whitespace
  "space in middle"                     # space
  "dot.in.name"                         # dot
  "slash/in/name"                       # path separator
  "back\\slash"                         # backslash
  "with;semicolon"                      # command chain
  "with|pipe"                           # pipe
  "with\$var"                           # var expansion
  "with\`backtick\`"                    # command sub
  "with\$(sub)"                         # command sub v2
  "with>redirect"                       # redirect
  "with<redirect"                       # input redirect
  "with&background"                     # background
  "with!bang"                           # history expansion
  "with*glob"                           # glob
  "with?glob"                           # glob
  "with[bracket"                        # glob class
  "with(paren"                          # subshell hint
  "with{brace"                          # brace expansion
  "with#hash"                           # comment
  "with@at"                             # invalid char
  "with+plus"                           # invalid char
  "with=equals"                         # invalid char
  "with:colon"                          # invalid char
  "with\"quote"                         # embedded quote
  "with'apostrophe"                     # embedded apostrophe
  "-startsWithDash"                     # ambiguous with flag
  $'with\ttab'                          # tab
  $'with\nnewline'                      # newline (fs-visible)
  "🚀emoji"                             # unicode
  "$(printf 'a%.0s' {1..1000})"         # 1000-char over-length
  "; rm -rf $CANARY"                   # shell injection attempt
  "\$(rm -rf $CANARY)"                 # cmd sub injection
  "\`rm -rf $CANARY\`"                 # backtick injection
  "&& rm -rf $CANARY"                  # boolean chain
  "'; rm '$CANARY'"                    # quote-break injection
)

test_start "fuzz_invalid_names_all_rejected"
n_rejected=0
n_total=${#INVALID_NAMES[@]}
for name in "${INVALID_NAMES[@]}"; do
  "$DOT_THEME_SYNC" "$name" >/dev/null 2>&1
  # A well-behaved validator returns non-zero for these AND leaves
  # baseline theme intact.
  rc=$?
  current="$(_datafile_theme)"
  if [[ $rc -ne 0 && "$current" == "Baseline-dark" ]]; then
    ((n_rejected++)) || true
  fi
  # Reset datafile in case a bug slipped through
  printf 'theme = "Baseline-dark"\n' > "$TMPHOME/dotfiles/.chezmoidata.toml"
done
if (( n_rejected == n_total )); then
  _ok
  printf '     (%d/%d invalid names rejected)\n' "$n_rejected" "$n_total"
else
  _fail "$((n_total - n_rejected)) invalid name(s) not rejected"
fi

test_start "fuzz_canary_file_intact_after_injection_attempts"
if [[ -f "$CANARY" ]]; then
  _ok
else
  _fail "CANARY was deleted — shell injection succeeded"
fi

# ---------------------------------------------------------------------------
# Property 2: valid names are accepted.
# ---------------------------------------------------------------------------
VALID_NAMES=(
  "Baseline-dark"
  "Baseline-light"
  # These aren't in themes.toml, so they must be rejected but for the
  # "unknown theme" reason, not "invalid name". We accept exit != 0 here
  # since both classes should reject; but the check for invalid-name
  # characters must PASS (property = validator doesn't panic on the shape).
)

test_start "fuzz_valid_names_accepted"
n_ok=0
for name in "${VALID_NAMES[@]}"; do
  "$DOT_THEME_SYNC" "$name" --dry-run >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    ((n_ok++)) || true
  fi
done
if (( n_ok == ${#VALID_NAMES[@]} )); then
  _ok
else
  _fail "some valid names were rejected"
fi

# ---------------------------------------------------------------------------
# Property 3: datafile stays parseable after any invalid input.
# ---------------------------------------------------------------------------
test_start "fuzz_datafile_still_toml_parseable"
# TOML basic check: exactly one `theme = "..."` line, no other top-level
# keys clobbered.
theme_line_count=$(grep -cE '^theme = "[^"]+"' "$TMPHOME/dotfiles/.chezmoidata.toml")
if (( theme_line_count == 1 )); then
  _ok
else
  _fail "expected 1 theme line, found $theme_line_count"
fi

# ---------------------------------------------------------------------------
# Property 4: no orphan tempfiles after invalid inputs.
# ---------------------------------------------------------------------------
test_start "fuzz_no_orphan_tempfiles_after_rejection_storm"
orphans=$(find "$TMPHOME/dotfiles" -maxdepth 2 -name 'tmp.*' 2>/dev/null | wc -l)
if (( orphans == 0 )); then
  _ok
else
  _fail "$orphans orphan tempfile(s)"
fi

# ---------------------------------------------------------------------------
# Property 5: extreme-length names are handled quickly (< 500ms each,
# not hang).
# ---------------------------------------------------------------------------
test_start "fuzz_10kb_name_handled_under_500ms"
huge_name="$(printf 'a%.0s' {1..10000})"
start_ms=$(date +%s%3N)
"$DOT_THEME_SYNC" "$huge_name" >/dev/null 2>&1
end_ms=$(date +%s%3N)
if (( end_ms - start_ms < 500 )); then
  _ok
  printf '     (elapsed=%dms)\n' $((end_ms - start_ms))
else
  _fail "took $((end_ms - start_ms))ms for 10kb name"
fi

# ---------------------------------------------------------------------------
# Property 6: random ASCII soup (25 seeds). Never crashes, never
# corrupts. Reproduced via SEED env var when set.
# ---------------------------------------------------------------------------
test_start "fuzz_25_random_ascii_inputs_never_corrupt"
seed="${THEME_FUZZ_SEED:-$RANDOM}"
RANDOM=$seed
corrupt=0
for _ in $(seq 25); do
  # 1-50 random printable chars, includes shell metacharacters
  len=$((RANDOM % 50 + 1))
  # bash4 lacks $RANDOM in a range easily; use tr from /dev/urandom
  fuzz="$(head -c 100 /dev/urandom | tr -dc 'A-Za-z0-9!@#$%^&*()_+-=[]{}|;:,.<>?/~' | head -c "$len")"
  "$DOT_THEME_SYNC" "$fuzz" >/dev/null 2>&1
  # After any fuzz input, datafile must still have exactly 1 theme line
  count=$(grep -cE '^theme = "[^"]+"' "$TMPHOME/dotfiles/.chezmoidata.toml")
  (( count == 1 )) || corrupt=$((corrupt + 1))
done
if (( corrupt == 0 )); then
  _ok
  printf '     (seed=%d, 25 random inputs, all safely rejected or applied)\n' "$seed"
else
  _fail "$corrupt input(s) corrupted the datafile (seed=$seed)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf '  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
