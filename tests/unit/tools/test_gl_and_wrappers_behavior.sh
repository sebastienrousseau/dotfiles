#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034,SC2016
#
# Behaviour tests for the interactive-adjacent tools whose logic can
# still be checked without a terminal:
#
#   gl                    — prerequisite checks, the not-a-repo guard,
#                           --side mode, and the commit-URL normaliser
#                           its Ctrl+O binding calls (GitHub, GitLab,
#                           Bitbucket, SSH and HTTPS remotes).
#   lolcat-wrap.sh        — colouriser present vs absent, file args vs
#                           stdin.
#   install-file-icons.sh — macOS with and without `fileicon`, Linux
#                           with and without `gsettings`, other OSes.
#   check-shell-preamble  — the compat shim delegates to tools/ci/.
#
# `fzf`, `delta`, `git`, `open`, `lolcat`, `fileicon` and `gsettings`
# are PATH shims that record what they were asked to do; nothing here
# opens a browser, touches the desktop settings or needs a TTY.
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

GL="$REPO_ROOT/defaults/dot_local/bin/executable_gl"
LOLCAT_WRAP="$REPO_ROOT/scripts/tools/lolcat-wrap.sh"
ICONS="$REPO_ROOT/scripts/theme/install-file-icons.sh"
PREAMBLE_SHIM="$REPO_ROOT/scripts/ci/check-shell-preamble.sh"
# Same bash as the harness — a /bin/bash 3.2 stub would truncate the
# xtrace records the coverage runner reads.
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

LOG="$DOTFILES_COV_TMPDIR/tool.log"
: >"$LOG"

_record_shim() { # <dir> <name> [extra body…]
  local dir="$1" name="$2"
  shift 2
  mkdir -p "$dir"
  {
    echo '#!/usr/bin/env bash'
    printf 'printf "%s %%s\\n" "$*" >>"%s"\n' "$name" "$LOG"
    printf '%s\n' "$@"
  } >"$dir/$name"
  chmod +x "$dir/$name"
}

_base_tools() { # <dir> — link the real coreutils the scripts need
  local dir="$1" t p
  mkdir -p "$dir"
  for t in bash cat printf echo sed tr cut sort head env dirname basename \
    uname command ls wc grep; do
    p="$(command -v "$t" 2>/dev/null || true)"
    [[ -n "$p" ]] && ln -sf "$p" "$dir/$t"
  done
}

BASE="$DOTFILES_COV_TMPDIR/base"
_base_tools "$BASE"

# ── gl: prerequisites ────────────────────────────────────────────────
test_start "gl_reports_each_missing_prerequisite"
_out="$(PATH="$BASE" "$BASH_BIN" "$GL" 2>&1)"
_rc=$?
assert_equals 1 "$_rc" "missing fzf exits 1"
assert_contains "gl requires fzf" "$_out" "names the first missing tool"

_d="$DOTFILES_COV_TMPDIR/gl-nodelta"
_record_shim "$_d" fzf
_record_shim "$_d" git
_out="$(PATH="$_d:$BASE" "$BASH_BIN" "$GL" 2>&1)"
_rc=$?
assert_equals 1 "$_rc" "missing delta exits 1"
assert_contains "gl requires delta" "$_out" "names delta"

test_start "gl_refuses_outside_a_git_work_tree"
_d="$DOTFILES_COV_TMPDIR/gl-norepo"
_record_shim "$_d" fzf
_record_shim "$_d" delta
_record_shim "$_d" git 'exit 128'
_out="$(PATH="$_d:$BASE" "$BASH_BIN" "$GL" 2>&1)"
_rc=$?
assert_equals 1 "$_rc" "outside a repo exits 1"
assert_contains "gl: not a git repository" "$_out" "explains the refusal"

# ── gl: --side and the fzf hand-off ──────────────────────────────────
_glbin="$DOTFILES_COV_TMPDIR/gl-ok"
_record_shim "$_glbin" delta
_record_shim "$_glbin" open
_record_shim "$_glbin" fzf 'printf "DELTA_FEATURES=%s\n" "${DELTA_FEATURES:-unset}"'
cat >"$_glbin/git" <<EOF
#!/usr/bin/env bash
printf 'git %s\n' "\$*" >>"$LOG"
case "\$*" in
  "rev-parse --is-inside-work-tree") exit 0 ;;
  "branch --show-current") echo "main" ;;
  "config --get branch.main.remote") echo "origin" ;;
  "remote get-url origin") echo "\${GL_TEST_REMOTE-git@github.com:owner/repo.git}" ;;
  *) : ;;
esac
exit 0
EOF
chmod +x "$_glbin/git"

test_start "gl_side_mode_exports_delta_side_by_side"
_out="$(PATH="$_glbin:$BASE" "$BASH_BIN" "$GL" --side 2>&1)"
_rc=$?
assert_equals 0 "$_rc" "gl exits 0 once fzf returns"
assert_contains "DELTA_FEATURES= side-by-side" "$_out" "--side reaches delta through the environment"
assert_file_contains "$LOG" "fzf --border" "fzf was invoked with the browser bindings"

test_start "gl_passes_git_log_flags_through_to_the_reload_binding"
: >"$LOG"
_out="$(PATH="$_glbin:$BASE" "$BASH_BIN" "$GL" --author=nobody 2>&1)"
assert_equals 0 "$?" "gl exits 0 with extra git flags"
assert_file_contains "$LOG" -- "--author=nobody" "the flag is embedded in the reload command"

# ── gl: commit-URL normalisation (the Ctrl+O binding) ────────────────
# The binding runs `bash -c 'source <gl>; open_commit_url <sha>'`, so
# drive exactly that: source the script (fzf shim returns at once) and
# call the function.
_open_url() { # <remote-url> → the URL handed to `open`
  : >"$LOG"
  PATH="$_glbin:$BASE" GL_TEST_REMOTE="$1" "$BASH_BIN" -c \
    'source "$1" >/dev/null 2>&1; open_commit_url deadbee' _ "$GL" >/dev/null 2>&1
  grep '^open ' "$LOG" | tail -1
}

test_start "gl_normalises_a_github_ssh_remote"
assert_equals "open https://github.com/owner/repo/commit/deadbee" \
  "$(_open_url 'git@github.com:owner/repo.git')" "SSH remote becomes an https commit URL"

test_start "gl_normalises_an_https_remote"
assert_equals "open https://github.com/owner/repo/commit/deadbee" \
  "$(_open_url 'https://github.com/owner/repo.git')" "HTTPS remote keeps its host"

test_start "gl_uses_the_gitlab_commit_path"
assert_equals "open https://gitlab.com/group/proj/-/commit/deadbee" \
  "$(_open_url 'git@gitlab.com:group/proj.git')" "GitLab uses the /-/commit/ path"

test_start "gl_uses_the_bitbucket_commit_path"
assert_equals "open https://bitbucket.org/team/proj/commits/deadbee" \
  "$(_open_url 'git@bitbucket.org:team/proj.git')" "Bitbucket uses the /commits/ path"

test_start "gl_open_commit_url_is_a_no_op_without_a_commit_or_remote"
: >"$LOG"
PATH="$_glbin:$BASE" "$BASH_BIN" -c \
  'source "$1" >/dev/null 2>&1; open_commit_url ""' _ "$GL" >/dev/null 2>&1
assert_output_not_contains "open http" cat "$LOG"
: >"$LOG"
PATH="$_glbin:$BASE" GL_TEST_REMOTE="" "$BASH_BIN" -c \
  'source "$1" >/dev/null 2>&1; open_commit_url deadbee' _ "$GL" >/dev/null 2>&1
assert_output_not_contains "open http" cat "$LOG"

test_start "gl_sourcing_does_not_launch_a_second_picker"
# The Ctrl+O binding sources this file to reuse open_commit_url; that
# must not re-enter the picker.
: >"$LOG"
PATH="$_glbin:$BASE" "$BASH_BIN" -c \
  'source "$1" >/dev/null 2>&1; open_commit_url deadbee' _ "$GL" >/dev/null 2>&1
assert_output_not_contains "fzf " cat "$LOG"
assert_output_contains "open https://github.com/owner/repo/commit/deadbee" cat "$LOG"

# ── lolcat-wrap.sh ───────────────────────────────────────────────────
_sample="$DOTFILES_COV_TMPDIR/sample.txt"
printf 'line one\nline two\n' >"$_sample"

test_start "lolcat_wrap_pipes_files_through_lolcat_when_present"
_d="$DOTFILES_COV_TMPDIR/lol-yes"
_record_shim "$_d" lolcat 'sed "s/^/rainbow: /"'
_out="$(PATH="$_d:$BASE" "$BASH_BIN" "$LOLCAT_WRAP" "$_sample" 2>&1)"
_rc=$?
assert_equals 0 "$_rc" "file mode exits 0"
assert_contains "rainbow: line one" "$_out" "file content went through lolcat"

test_start "lolcat_wrap_pipes_stdin_through_lolcat_when_present"
_out="$(printf 'piped\n' | PATH="$_d:$BASE" "$BASH_BIN" "$LOLCAT_WRAP" 2>&1)"
assert_equals 0 "$?" "stdin mode exits 0"
assert_contains "rainbow: piped" "$_out" "stdin went through lolcat"

test_start "lolcat_wrap_falls_back_to_plain_output"
_out="$(PATH="$BASE" "$BASH_BIN" "$LOLCAT_WRAP" "$_sample" 2>&1)"
assert_equals 0 "$?" "plain file mode exits 0"
assert_equals "line one
line two" "$_out" "file content passed through untouched"
_out="$(printf 'plain\n' | PATH="$BASE" "$BASH_BIN" "$LOLCAT_WRAP" 2>&1)"
assert_equals "plain" "$_out" "stdin passed through untouched"

# ── install-file-icons.sh ────────────────────────────────────────────
_uname_shim() { # <dir> <value>
  mkdir -p "$1"
  printf '#!/usr/bin/env bash\necho "%s"\n' "$2" >"$1/uname"
  chmod +x "$1/uname"
}

test_start "install_file_icons_macos_paths"
_d="$DOTFILES_COV_TMPDIR/icons-mac"
_uname_shim "$_d" Darwin
_record_shim "$_d" fileicon
_out="$(PATH="$_d:$BASE" "$BASH_BIN" "$ICONS" 2>&1)"
assert_equals 0 "$?" "macOS with fileicon exits 0"
assert_contains "fileicon set <path>" "$_out" "usage hint printed"

_d="$DOTFILES_COV_TMPDIR/icons-mac-bare"
_uname_shim "$_d" Darwin
_out="$(PATH="$_d:$BASE" "$BASH_BIN" "$ICONS" 2>&1)"
assert_contains "brew install fileicon" "$_out" "install hint printed when fileicon is missing"

test_start "install_file_icons_linux_sets_the_gnome_theme"
_d="$DOTFILES_COV_TMPDIR/icons-linux"
_uname_shim "$_d" Linux
_record_shim "$_d" gsettings
: >"$LOG"
_out="$(PATH="$_d:$BASE" DOTFILES_ICON_THEME=Numix "$BASH_BIN" "$ICONS" 2>&1)"
assert_equals 0 "$?" "Linux with gsettings exits 0"
assert_contains "Set GNOME icon theme to Numix." "$_out" "confirms the theme it set"
assert_file_contains "$LOG" "gsettings set org.gnome.desktop.interface icon-theme Numix" \
  "gsettings received the override theme"

_d="$DOTFILES_COV_TMPDIR/icons-linux-bare"
_uname_shim "$_d" Linux
_out="$(PATH="$_d:$BASE" "$BASH_BIN" "$ICONS" 2>&1)"
assert_contains "gsettings not found" "$_out" "falls back to a DE hint"

test_start "install_file_icons_other_os_is_reported_unsupported"
_d="$DOTFILES_COV_TMPDIR/icons-other"
_uname_shim "$_d" FreeBSD
_out="$(PATH="$_d:$BASE" "$BASH_BIN" "$ICONS" 2>&1)"
assert_equals 0 "$?" "unsupported OS still exits 0"
assert_contains "Unsupported OS for icon theming." "$_out" "says so"

# ── scripts/ci/check-shell-preamble.sh (compat shim) ─────────────────
test_start "check_shell_preamble_shim_delegates_to_tools_ci"
_good="$DOTFILES_COV_TMPDIR/good-preamble.sh"
printf '#!/usr/bin/env bash\nset -euo pipefail\necho ok\n' >"$_good"
_out="$("$BASH_BIN" "$PREAMBLE_SHIM" "$_good" 2>&1)"
_rc=$?
assert_equals 0 "$_rc" "compliant file passes through the shim"

_bad="$DOTFILES_COV_TMPDIR/bad-preamble.sh"
printf '#!/usr/bin/env bash\necho no-strict-mode\n' >"$_bad"
_out="$("$BASH_BIN" "$PREAMBLE_SHIM" "$_bad" 2>&1)"
_rc=$?
assert_equals 1 "$_rc" "non-compliant file is rejected through the shim"
assert_contains "$_bad" "$_out" "the offending file is named"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
