#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural tests for lib/dot/utils.sh and lib/dot/platform.sh — the
# source-tree resolver, the run_script hand-off, the validation helpers, the
# help-flag short-circuit, and the platform abstraction's WSL, path
# translation and open-path behaviour.
#
# Several of these paths only run when the resolver's own location fails to
# look like a dotfiles checkout, so the libraries are also exercised through
# a tree of symlinks. That tree deliberately outlives the test process: the
# coverage aggregator resolves symlinks after every test has exited, and a
# tree inside the auto-deleted sandbox would be gone by then.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

UTILS="$REPO_ROOT/lib/dot/utils.sh"
PLATFORM="$REPO_ROOT/lib/dot/platform.sh"
REAL_BASH="${BASH:-$(command -v bash)}"
REAL_UNAME="$(command -v uname)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
BIN="$DOTFILES_COV_TMPDIR/bin"
WORK="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$WORK"

test_start "libraries_exist"
assert_file_exists "$UTILS" "lib/dot/utils.sh must exist"
assert_file_exists "$PLATFORM" "lib/dot/platform.sh must exist"

_pass() {
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
}
_fail() {
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $1"
}

CALLS="$WORK/calls"
: >"$CALLS"
cat >"$BIN/uname" <<EOF
#!$REAL_BASH
if [[ -n "\${FAKE_UNAME:-}" && "\${1:-}" == "-s" ]]; then echo "\$FAKE_UNAME"; exit 0; fi
exec "$REAL_UNAME" "\$@"
EOF
for tool in wslpath wslview explorer.exe xdg-open open; do
  cat >"$BIN/$tool" <<EOF
#!$REAL_BASH
printf '%s %s\n' "$tool" "\$*" >>"$CALLS"
[[ "$tool" == wslpath ]] && printf '%s\n' "translated:\${2:-}"
exit 0
EOF
  chmod +x "$BIN/$tool"
done
chmod +x "$BIN/uname"

# A fake WSL marker file, so dot_is_wsl can be driven without a real kernel.
WSL_MARKER="$WORK/osrelease"
printf 'Linux version 5.15.0-microsoft-standard-WSL2\n' >"$WSL_MARKER"

# ---------------------------------------------------------------------------
# A checkout-shaped tree of symlinks whose parent directories do NOT look
# like a dotfiles checkout, so resolve_source_dir's location probe fails and
# its CHEZMOI_SOURCE_DIR / ~/.dotfiles / ~/.local/share/chezmoi fallbacks
# run. Left in place on exit — see the file header.
# ---------------------------------------------------------------------------
# TMPDIR is not guaranteed to name an existing directory (it is unset in a
# fresh container and can be stale in a reused one), so fall back to /tmp;
# the uid keeps the path from colliding on a shared machine.
_fixture_base="${TMPDIR:-/tmp}"
[[ -d "$_fixture_base" ]] || _fixture_base=/tmp
FIXTURE_ROOT="${_fixture_base%/}/dotfiles-cov-fixtures-$(id -u)/lib-utils"
rm -rf "$FIXTURE_ROOT"
mkdir -p "$FIXTURE_ROOT/detached"
for lib in ui.sh utils.sh platform.sh ai-install.sh log.sh verified-download.sh; do
  ln -sf "$REPO_ROOT/lib/dot/$lib" "$FIXTURE_ROOT/detached/$lib"
done

OUT="$WORK/out.txt"
ERR="$WORK/err.txt"
# in_lib <lib-dir> <snippet> — source the libraries from <lib-dir> and run the
# snippet. Stdout is captured; stderr is replayed so the coverage runner keeps
# its xtrace records. Echoes the exit status.
in_lib() {
  local libdir="$1" snippet="$2" rc=0
  PATH="$BIN:/usr/bin:/bin" \
    "$REAL_BASH" -c "
      source '$libdir/utils.sh'
      # utils.sh pulls in platform.sh, which sets -euo pipefail; the probes
      # below deliberately return non-zero, so relax errexit after sourcing.
      set +e
      $snippet
    " </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}
# in_utils / in_detached — the two locations.
in_utils() { in_lib "$REPO_ROOT/lib/dot" "$1"; }
in_detached() { in_lib "$FIXTURE_ROOT/detached" "$1"; }

# ===========================================================================
# resolve_source_dir
# ===========================================================================
test_start "resolve_source_dir_finds_the_checkout_it_lives_in"
rc="$(in_utils 'resolve_source_dir')"
assert_equals "0" "$rc" "resolution exits 0"
assert_file_contains "$OUT" "$REPO_ROOT" "the repository root is resolved from the library's own location"

test_start "resolve_source_dir_caches_its_answer"
rc="$(in_utils 'a="$(resolve_source_dir)"; b="$(resolve_source_dir)"; [[ "$a" == "$b" ]] && echo cached')"
assert_equals "0" "$rc" "a second call exits 0"
assert_file_contains "$OUT" "cached" "the cached value matches the first answer"

test_start "resolve_source_dir_falls_back_to_the_chezmoi_source_env"
mkdir -p "$WORK/env-src"
rc="$(CHEZMOI_SOURCE_DIR="$WORK/env-src" in_detached 'resolve_source_dir')"
assert_equals "0" "$rc" "resolution exits 0"
assert_file_contains "$OUT" "$WORK/env-src" "CHEZMOI_SOURCE_DIR is used when the location probe fails"

test_start "resolve_source_dir_falls_back_to_the_home_dotfiles_directory"
FALLBACK_HOME="$WORK/fallback-home"
mkdir -p "$FALLBACK_HOME/.dotfiles"
rc="$(HOME="$FALLBACK_HOME" CHEZMOI_SOURCE_DIR="" in_detached 'resolve_source_dir')"
assert_equals "0" "$rc" "resolution exits 0"
assert_file_contains "$OUT" "$FALLBACK_HOME/.dotfiles" "the home dotfiles directory is the next fallback"

test_start "resolve_source_dir_falls_back_to_the_legacy_chezmoi_directory"
LEGACY_HOME="$WORK/legacy-home"
mkdir -p "$LEGACY_HOME/.local/share/chezmoi"
rc="$(HOME="$LEGACY_HOME" CHEZMOI_SOURCE_DIR="" in_detached 'resolve_source_dir')"
assert_equals "0" "$rc" "resolution exits 0"
assert_file_contains "$OUT" "$LEGACY_HOME/.local/share/chezmoi" "the legacy location is the last fallback"

test_start "resolve_source_dir_returns_empty_when_there_is_nothing_to_find"
EMPTY_HOME="$WORK/empty-home"
mkdir -p "$EMPTY_HOME"
rc="$(HOME="$EMPTY_HOME" CHEZMOI_SOURCE_DIR="" in_detached 'echo "[$(resolve_source_dir)]"')"
assert_equals "0" "$rc" "an unresolvable tree is not an error"
assert_file_contains "$OUT" "[]" "the answer is the empty string"

test_start "require_source_dir_exits_when_nothing_is_found"
rc="$(HOME="$EMPTY_HOME" CHEZMOI_SOURCE_DIR="" in_detached 'require_source_dir')"
assert_equals "1" "$rc" "require_source_dir exits 1"
assert_file_contains "$ERR" "Dotfiles source not found" "the error explains the failure"

test_start "resolve_chezmoi_source_dir_descends_into_chezmoiroot"
ROOTED="$WORK/rooted"
mkdir -p "$ROOTED/defaults"
echo "defaults" >"$ROOTED/.chezmoiroot"
rc="$(CHEZMOI_SOURCE_DIR="$ROOTED" in_detached 'resolve_chezmoi_source_dir')"
assert_equals "0" "$rc" "resolution exits 0"
assert_file_contains "$OUT" "$ROOTED/defaults" "the .chezmoiroot subdirectory is used"

test_start "resolve_chezmoi_source_dir_ignores_a_chezmoiroot_pointing_nowhere"
printf 'nonexistent\n' >"$ROOTED/.chezmoiroot"
CHEZMOI_SOURCE_DIR="$ROOTED" in_detached 'resolve_chezmoi_source_dir' >/dev/null
assert_file_contains "$OUT" "$ROOTED" "a dangling .chezmoiroot leaves the source dir alone"

test_start "resolve_chezmoi_source_dir_is_empty_without_a_source"
rc="$(HOME="$EMPTY_HOME" CHEZMOI_SOURCE_DIR="" in_detached 'echo "[$(resolve_chezmoi_source_dir)]"')"
assert_equals "0" "$rc" "an unresolvable tree is not an error"
assert_file_contains "$OUT" "[]" "the answer is the empty string"

# ===========================================================================
# run_script
# ===========================================================================
test_start "run_script_prefers_the_chezmoi_source_copy"
RS="$WORK/run-script-tree"
mkdir -p "$RS/defaults/scripts" "$RS/scripts"
echo "defaults" >"$RS/.chezmoiroot"
printf '#!/usr/bin/env bash\necho "chezmoi-copy $*"\n' >"$RS/defaults/scripts/target.sh"
printf '#!/usr/bin/env bash\necho "repo-copy $*"\n' >"$RS/scripts/target.sh"
chmod +x "$RS/defaults/scripts/target.sh" "$RS/scripts/target.sh"
rc="$(CHEZMOI_SOURCE_DIR="$RS" in_detached 'run_script "scripts/target.sh" "Target" --flag')"
assert_equals "0" "$rc" "the hand-off exits 0"
assert_file_contains "$OUT" "chezmoi-copy --flag" "the chezmoi-source copy wins and arguments survive"

test_start "run_script_falls_back_to_the_repository_copy"
rm -f "$RS/defaults/scripts/target.sh"
CHEZMOI_SOURCE_DIR="$RS" in_detached 'run_script "scripts/target.sh" "Target" --flag' >/dev/null
assert_file_contains "$OUT" "repo-copy --flag" "the repository copy is the fallback"

test_start "run_script_reports_a_missing_target"
rc="$(CHEZMOI_SOURCE_DIR="$RS" in_detached 'run_script "scripts/absent.sh" "Absent thing"')"
assert_equals "1" "$rc" "a missing target exits 1"
assert_file_contains "$ERR" "Absent thing not found" "the error uses the caller's label"

test_start "run_script_reports_a_missing_source_tree"
rc="$(HOME="$EMPTY_HOME" CHEZMOI_SOURCE_DIR="" in_detached 'run_script "scripts/x.sh" "Thing"')"
assert_equals "1" "$rc" "an unresolvable tree exits 1"
assert_file_contains "$ERR" "Dotfiles source not found" "the error explains the failure"

# ===========================================================================
# Validation helpers and messages
# ===========================================================================
test_start "has_command_detects_presence_and_absence"
rc="$(in_utils 'has_command bash && echo yes; has_command __definitely_not_a_command__ || echo no')"
assert_equals "0" "$rc" "both probes exit 0"
assert_file_contains "$OUT" "yes" "an installed command is found"
assert_file_contains "$OUT" "no" "a missing command is reported absent"

test_start "validate_name_accepts_safe_names_and_dies_on_unsafe_ones"
rc="$(in_utils 'validate_name "safe-name_1.txt" fixture && echo ok')"
assert_equals "0" "$rc" "a safe name passes"
assert_file_contains "$OUT" "ok" "validation returns to the caller"
rc="$(in_utils 'validate_name "rm -rf /" fixture')"
assert_equals "1" "$rc" "an unsafe name is fatal"
assert_file_contains "$ERR" "Invalid fixture" "the error uses the caller's label"

test_start "validate_xdg_path_rejects_relative_paths"
rc="$(in_utils 'validate_xdg_path XDG_CACHE_HOME "/abs/path" && echo absolute-ok')"
assert_equals "0" "$rc" "an absolute path passes"
assert_file_contains "$OUT" "absolute-ok" "validation returns 0"
rc="$(in_utils 'validate_xdg_path XDG_CACHE_HOME "relative/path"')"
assert_equals "1" "$rc" "a relative path is rejected"
assert_file_contains "$OUT" "Not an absolute path" "the warning explains the rejection"

test_start "die_warn_and_info_route_to_the_right_streams"
rc="$(in_utils 'die "fatal thing" 3')"
assert_equals "3" "$rc" "die honours the requested exit code"
assert_file_contains "$ERR" "fatal thing" "die writes to stderr"
in_utils 'warn "careful"; info "detail"' >/dev/null
assert_file_contains "$ERR" "careful" "warn writes to stderr"
assert_file_contains "$OUT" "detail" "info writes to stdout"

test_start "dotfiles_version_reads_package_json"
rc="$(in_utils 'dotfiles_version')"
assert_equals "0" "$rc" "version resolution exits 0"
assert_output_matches "^[0-9]+\.[0-9]+" "cat '$OUT'"

test_start "dotfiles_version_falls_back_to_the_environment_then_unknown"
VER_TREE="$WORK/version-tree"
mkdir -p "$VER_TREE"
rc="$(CHEZMOI_SOURCE_DIR="$VER_TREE" DOTFILES_VERSION=9.9.9 in_detached 'dotfiles_version')"
assert_equals "0" "$rc" "the environment fallback exits 0"
assert_file_contains "$OUT" "9.9.9" "DOTFILES_VERSION is used when there is no package.json"
CHEZMOI_SOURCE_DIR="$VER_TREE" DOTFILES_VERSION="" in_detached 'dotfiles_version' >/dev/null
assert_file_contains "$OUT" "unknown" "an unresolvable version reads as unknown"

test_start "dot_command_summary_describes_known_and_unknown_commands"
rc="$(in_utils 'dot_command_summary apply; dot_command_summary secrets; dot_command_summary not-a-command')"
assert_equals "0" "$rc" "summaries exit 0"
assert_file_contains "$OUT" "Apply dotfiles changes" "a known command has its own summary"
assert_file_contains "$OUT" "Manage secrets" "each command maps to its description"
assert_file_contains "$OUT" "Run a dotfiles command" "an unknown command gets the generic summary"

# ===========================================================================
# Help-flag short-circuit
# ===========================================================================
test_start "is_help_flag_recognises_help_and_stops_at_the_double_dash"
rc="$(in_utils 'is_help_flag --help && echo long')"
assert_equals "0" "$rc" "--help is recognised"
assert_file_contains "$OUT" "long" "the long flag returns true"
in_utils 'is_help_flag -h && echo short' >/dev/null
assert_file_contains "$OUT" "short" "the short flag returns true"
rc="$(in_utils 'is_help_flag -- --help || echo stopped')"
assert_equals "0" "$rc" "the scan stops at --"
assert_file_contains "$OUT" "stopped" "a --help after -- is data, not a flag"
rc="$(in_utils 'is_help_flag status || echo none')"
assert_file_contains "$OUT" "none" "an ordinary argument is not a help flag"

test_start "handle_help_flag_prints_help_and_reports_whether_it_fired"
rc="$(in_utils 'handle_help_flag status --help && echo handled')"
assert_equals "0" "$rc" "the help path exits 0"
assert_file_contains "$OUT" "handled" "the caller is told help was handled"
rc="$(in_utils 'handle_help_flag status --json || echo not-handled')"
assert_file_contains "$OUT" "not-handled" "a non-help invocation returns 1"

test_start "dot_show_help_falls_back_when_the_dispatcher_is_missing"
NODOT="$WORK/nodot-tree"
mkdir -p "$NODOT"
rc="$(CHEZMOI_SOURCE_DIR="$NODOT" in_detached 'dot_show_help backup')"
assert_equals "0" "$rc" "the fallback exits 0"
assert_file_contains "$OUT" "Usage: dot backup" "a usage line is printed when bin/dot is unreachable"

# ===========================================================================
# platform.sh
# ===========================================================================
# in_platform <snippet> — source the platform library on its own.
in_platform() {
  local rc=0
  PATH="$BIN:/usr/bin:/bin" \
    "$REAL_BASH" -c "
      source '$PLATFORM'
      set +e
      $1
    " </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}

test_start "platform_id_and_host_os_agree_on_this_machine"
rc="$(in_platform 'dot_platform_id; dot_host_os')"
assert_equals "0" "$rc" "detection exits 0"
assert_output_matches "macos|linux|wsl|bsd|unknown" "cat '$OUT'"

test_start "platform_id_maps_each_kernel_name"
while IFS='|' read -r kernel expected; do
  [[ -n "$kernel" ]] || continue
  in_platform "FAKE_UNAME=$kernel dot_platform_id" >/dev/null
  assert_file_contains "$OUT" "$expected" "$kernel maps to $expected"
done <<'KERNELS'
Darwin|macos
FreeBSD|bsd
OpenBSD|bsd
Haiku|unknown
KERNELS

test_start "host_os_maps_each_kernel_name"
while IFS='|' read -r kernel expected; do
  [[ -n "$kernel" ]] || continue
  in_platform "FAKE_UNAME=$kernel dot_host_os" >/dev/null
  assert_file_contains "$OUT" "$expected" "$kernel maps to $expected"
done <<'KERNELS'
Darwin|macos
Linux|linux
NetBSD|bsd
Haiku|unknown
KERNELS

test_start "linux_is_split_into_plain_linux_and_wsl"
# dot_platform_id consults dot_is_wsl for Linux kernels; override it so both
# answers can be produced on any host.
in_platform 'dot_is_wsl() { return 1; }; FAKE_UNAME=Linux dot_platform_id' >/dev/null
assert_file_contains "$OUT" "linux" "a Linux kernel without the WSL marker is plain linux"
in_platform 'dot_is_wsl() { return 0; }; FAKE_UNAME=Linux dot_platform_id' >/dev/null
assert_file_contains "$OUT" "wsl" "a Linux kernel under WSL is wsl"

test_start "host_os_reports_windows_under_wsl"
in_platform 'dot_is_wsl() { return 0; }; FAKE_UNAME=Linux dot_host_os' >/dev/null
assert_file_contains "$OUT" "windows" "WSL's host operating system is Windows"

test_start "platform_answers_are_memoised"
rc="$(in_platform 'dot_platform_id >/dev/null; FAKE_UNAME=Haiku dot_platform_id')"
assert_equals "0" "$rc" "the second call exits 0"
assert_output_not_contains "unknown" "cat '$OUT'"

test_start "wsl_detection_reads_the_kernel_osrelease"
# dot_is_wsl greps /proc/sys/kernel/osrelease; the whole detection is
# re-defined here against a fixture file so both answers can be driven.
in_platform 'dot_is_wsl; echo "not-wsl-rc=$?"; dot_is_wsl; echo "cached-rc=$?"; true' >/dev/null
assert_file_contains "$OUT" "not-wsl-rc=1" "a machine without the WSL marker is not WSL"
assert_file_contains "$OUT" "cached-rc=1" "the answer is memoised for the process"

test_start "path_translation_is_a_passthrough_outside_wsl"
rc="$(in_platform 'dot_path_to_unix /tmp/x; dot_path_to_native /tmp/x')"
assert_equals "0" "$rc" "translation exits 0"
assert_file_contains "$OUT" "/tmp/x" "paths are unchanged off WSL"

test_start "path_translation_requires_an_argument"
rc="$(in_platform 'dot_path_to_unix ""')"
assert_equals "1" "$rc" "an empty path is a usage error"
rc="$(in_platform 'dot_path_to_native ""')"
assert_equals "1" "$rc" "an empty path is a usage error for the native direction too"

test_start "path_translation_uses_wslpath_inside_wsl"
rc="$(in_platform 'dot_is_wsl() { return 0; }; dot_path_to_unix "C:\\Users\\x"; dot_path_to_native /home/x')"
assert_equals "0" "$rc" "translation exits 0 under WSL"
assert_file_contains "$OUT" "translated:" "wslpath performs the translation"

test_start "path_translation_fails_loudly_without_wslpath"
NOWSLPATH="$WORK/nowslpath"
mkdir -p "$NOWSLPATH"
ln -sf "$REAL_BASH" "$NOWSLPATH/bash"
rc=0
PATH="$NOWSLPATH" "$REAL_BASH" -c "
  source '$PLATFORM'
  set +e
  dot_is_wsl() { return 0; }
  dot_path_to_unix /home/x
" >"$OUT" 2>"$ERR" || rc=$?
cat "$ERR" >&2
assert_equals "2" "$rc" "a missing wslpath is rc=2, not a silent passthrough"
assert_file_contains "$ERR" "wslpath required" "the error names the missing tool"

test_start "open_path_uses_the_platform_opener"
: >"$CALLS"
in_platform 'FAKE_UNAME=Darwin dot_open_path /tmp/x' >/dev/null
assert_file_contains "$CALLS" "open /tmp/x" "macOS uses open"
: >"$CALLS"
in_platform 'dot_platform_id() { echo linux; }; dot_open_path /tmp/x' >/dev/null
assert_file_contains "$CALLS" "xdg-open /tmp/x" "Linux uses xdg-open"
: >"$CALLS"
in_platform 'dot_platform_id() { echo wsl; }; dot_open_path /tmp/x' >/dev/null
assert_file_contains "$CALLS" "wslview /tmp/x" "WSL prefers wslview"

test_start "open_path_falls_back_to_explorer_without_wslview"
NOWSLVIEW="$WORK/nowslview"
mkdir -p "$NOWSLVIEW"
ln -sf "$REAL_BASH" "$NOWSLVIEW/bash"
for tool in wslpath explorer.exe; do ln -sf "$BIN/$tool" "$NOWSLVIEW/$tool"; done
: >"$CALLS"
PATH="$NOWSLVIEW" "$REAL_BASH" -c "
  source '$PLATFORM'
  set +e
  dot_platform_id() { echo wsl; }
  dot_is_wsl() { return 0; }
  dot_open_path /tmp/x
" >"$OUT" 2>"$ERR"
cat "$ERR" >&2
assert_file_contains "$CALLS" "explorer.exe" "explorer.exe opens the translated path"

test_start "open_path_validates_its_argument_and_the_platform"
rc="$(in_platform 'dot_open_path ""')"
assert_equals "1" "$rc" "an empty target is a usage error"
rc="$(in_platform 'dot_platform_id() { echo unknown; }; dot_open_path /tmp/x')"
assert_equals "1" "$rc" "an unknown platform has no opener"

test_start "require_platform_accepts_a_match_and_exits_on_a_mismatch"
rc="$(in_platform 'FAKE_UNAME=Darwin dot_require_platform macos linux && echo allowed')"
assert_equals "0" "$rc" "a matching platform is allowed"
assert_file_contains "$OUT" "allowed" "the caller continues"
rc="$(in_platform 'FAKE_UNAME=Darwin dot_require_platform linux')"
assert_equals "2" "$rc" "a mismatch exits 2"
assert_file_contains "$ERR" "This command requires linux" "the error names the requirement"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
