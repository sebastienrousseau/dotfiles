#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# The shell and config plugins' entries and libexec modules (P2.1): what
# `dot shell` and `dot config` do at their edges. Each module is sourced in
# a child bash with the source dir and chezmoi stubbed, so nothing here
# touches the checkout or the user's caches.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SHELL_ENTRY="$REPO_ROOT/plugins/shell/dot-shell"
SHELL_MOD="$REPO_ROOT/plugins/shell/libexec/shell.sh"
CONFIG_ENTRY="$REPO_ROOT/plugins/config/dot-config"
CONFIG_MOD="$REPO_ROOT/plugins/config/libexec/config.sh"
REAL_BASH="$(command -v bash)"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-shell-config.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/home"
OUT="$WORK/out"
export HOME="$WORK/home" NO_COLOR=1 DOTFILES_NONINTERACTIVE=1 DOTFILES_SHOW_LOGO=0

# in_module MODULE SRC FUNCTION ARGS…: call FUNCTION from MODULE, sourced,
# with the dotfiles source dir resolving to SRC (empty: not found).
in_module() {
  local module="$1" src="$2"
  shift 2
  "$REAL_BASH" -c 'source "$1"; src="$2"; shift 2
    resolve_source_dir() { printf "%s" "$src"; }
    "$@"' _ "$module" "$src" "$@" >"$OUT" 2>&1 </dev/null
  RC=$?
}

# ── entries: a word neither takes is not a command (exit 127) ────────────
test_start "dot_shell_refuses_an_unknown_word"
"$REAL_BASH" "$SHELL_ENTRY" frobnicate >"$OUT" 2>&1 </dev/null && RC=0 || RC=$?
assert_equals 127 "$RC" "rc"
assert_file_contains "$OUT" "'dot shell frobnicate' is not a command" "message"

test_start "dot_config_refuses_an_unknown_word"
"$REAL_BASH" "$CONFIG_ENTRY" frobnicate >"$OUT" 2>&1 </dev/null && RC=0 || RC=$?
assert_equals 127 "$RC" "rc"
assert_file_contains "$OUT" "'dot config frobnicate' is not a command" "message"

# ── shell.sh: prewarm clears each shell's init caches, and only those ────
test_start "prewarm_clears_every_shell_init_cache"
cache="$WORK/cache"
mkdir -p "$cache/zsh" "$cache/bash" "$cache/fish" "$cache/nushell"
touch "$cache/zsh/starship-init.zsh" "$cache/zsh/x.zwc" "$cache/zsh/keep.txt" \
  "$cache/bash/starship-init.bash" "$cache/bash/keep.txt" \
  "$cache/fish/starship-init.fish" "$cache/fish/keep.txt" \
  "$cache/nushell/starship.nu" "$cache/nushell/keep.txt"
XDG_CACHE_HOME="$cache" in_module "$SHELL_MOD" "" cmd_prewarm
assert_equals 0 "$RC" "rc"
for f in zsh/starship-init.zsh zsh/x.zwc bash/starship-init.bash fish/starship-init.fish nushell/starship.nu; do
  assert_file_not_exists "$cache/$f" "$f is cleared"
done
for d in zsh bash fish nushell; do
  assert_file_exists "$cache/$d/keep.txt" "$d keeps files that are not init caches"
done

test_start "prewarm_without_a_prewarm_script_succeeds"
bare="$WORK/bare-src"
mkdir -p "$bare"
XDG_CACHE_HOME="$WORK/no-cache" in_module "$SHELL_MOD" "$bare" cmd_prewarm
assert_equals 0 "$RC" "rc: nothing to regenerate is not a failure"

test_start "prewarm_runs_the_source_prewarm_script"
with="$WORK/with-src"
mkdir -p "$with/scripts/ops"
printf 'echo prewarm-ran\n' >"$with/scripts/ops/prewarm.sh"
XDG_CACHE_HOME="$WORK/no-cache" in_module "$SHELL_MOD" "$with" cmd_prewarm
assert_equals 0 "$RC" "rc"
assert_file_contains "$OUT" "prewarm-ran" "the source's prewarm.sh runs"

# The command must be one whole word of the list.
test_start "shell_main_refuses_unknown_and_two_word_commands"
for sub in frobnicate "history prewarm"; do
  in_module "$SHELL_MOD" "" shell_main "$sub"
  assert_equals 1 "$RC" "'$sub' exits 1"
  assert_file_contains "$OUT" "Unknown shell command: $sub" "'$sub' is refused"
done

# ── config.sh ────────────────────────────────────────────────────────────
test_start "config_status_shows_why_chezmoi_failed"
cat >"$WORK/bin/chezmoi" <<'EOF'
#!/usr/bin/env bash
echo "chezmoi: source state is broken"
exit 2
EOF
chmod +x "$WORK/bin/chezmoi"
PATH="$WORK/bin:$PATH" in_module "$CONFIG_MOD" "" cmd_status
assert_equals 2 "$RC" "rc is chezmoi's"
assert_file_contains "$OUT" "chezmoi: source state is broken" "chezmoi's own message is shown"

test_start "config_cd_without_a_source_fails"
in_module "$CONFIG_MOD" "" cmd_cd
assert_equals 1 "$RC" "rc"
assert_file_contains "$OUT" "Dotfiles source not found." "message"

test_start "config_main_refuses_unknown_and_two_word_commands"
for sub in frobnicate "status remove"; do
  in_module "$CONFIG_MOD" "" config_main "$sub"
  assert_equals 1 "$RC" "'$sub' exits 1"
  assert_file_contains "$OUT" "Unknown config command: $sub" "'$sub' is refused"
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
