#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Runs the new utility scripts in defaults/dot_local/bin the way they are
# deployed: copied under their target name with +x and executed directly, so
# the kernel resolves the shebang. Every external program a script reaches
# for (fzf, delta, niri, tmux, btop, nvtop, cb, curl, the launched app) is a
# recording stub on a controlled PATH; git runs for real in a scratch repo.
#
# Per script:
#   _runs         executed directly through its shebang, exit status checked
#   _strict_mode  a BASH_ENV probe records the shell options in force when
#                 the script exits: errexit, nounset and pipefail
# and the project's copyright validator is run over all of them,
# plus behavioural cases for each script's features.
#
# Everything runs inside a mktemp sandbox with HOME and XDG_* pointed at it.
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BIN_DIR="$REPO_ROOT/defaults/dot_local/bin"
REAL_BASH="${BASH:-$(command -v bash)}"

WORK="$(mktemp -d -t dot-new-scripts.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache" XDG_STATE_HOME="$HOME/.local/state"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$WORK/gitconfig"
export GIT_CEILING_DIRECTORIES="$WORK"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"
printf '[user]\n\tname = Test\n\temail = test@example.invalid\n[init]\n\tdefaultBranch = main\n' \
  >"$GIT_CONFIG_GLOBAL"

skip_case() { # <name> <reason>
  printf '  - SKIP %s: %s\n' "$1" "$2"
}

# All new scripts created in this session
SCRIPTS=(
  executable_gl
  executable_gd
  executable_gbd
  executable_dot-launch-or-focus
  executable_monitor
  executable_pw
  executable_dtags
  executable_mkscript
  executable_rec-start
  executable_rec-stop
)

# Deploy: copy each script under its target name and mark it executable, as
# chezmoi does for the executable_ prefix.
DEPLOY="$WORK/deploy"
mkdir -p "$DEPLOY"
for script in "${SCRIPTS[@]}"; do
  if [[ -f "$BIN_DIR/$script" ]]; then
    cp "$BIN_DIR/$script" "$DEPLOY/${script#executable_}"
    chmod +x "$DEPLOY/${script#executable_}"
  fi
done

# TOOLS: the host programs the scripts may use, linked one by one so no
# other host command (pwgen, a real fzf, niri …) leaks onto PATH.
TOOLS="$WORK/tools"
mkdir -p "$TOOLS"
ln -s "$REAL_BASH" "$TOOLS/bash"
for tool in git jq openssl; do
  if path="$(command -v "$tool" 2>/dev/null)"; then
    ln -s "$path" "$TOOLS/$tool"
  fi
done

# STUBS: recording stand-ins. Each logs "<name> <args>" to $CALLS and, when
# given, runs a body.
STUBS="$WORK/stubs"
CALLS="$WORK/calls"
mkdir -p "$STUBS"
stub() { # <name> [body]
  cat >"$STUBS/$1" <<EOF
#!$REAL_BASH
printf '%s %s\n' "$1" "\$*" >>"$CALLS"
${2:-exit 0}
EOF
  chmod +x "$STUBS/$1"
}
unstub() { rm -f "$STUBS/$1"; }

OUT="$WORK/out"
ERR="$WORK/err"
RC=0
# run <dir> <name> [args...] — execute the deployed script from <dir>.
# Extra environment comes from the RUN_ENV array.
RUN_ENV=()
run() {
  local dir="$1" name="$2"
  shift 2
  : >"$CALLS"
  RC=0
  (cd "$dir" && command env -i HOME="$HOME" PATH="$STUBS:$TOOLS:/usr/bin:/bin" \
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_DATA_HOME="$XDG_DATA_HOME" \
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$GIT_CONFIG_GLOBAL" \
    GIT_CEILING_DIRECTORIES="$GIT_CEILING_DIRECTORIES" CALLS="$CALLS" LC_ALL=C \
    ${RUN_ENV[@]+"${RUN_ENV[@]}"} "$DEPLOY/$name" "$@") </dev/null >"$OUT" 2>"$ERR" || RC=$?
}
out() { cat "$OUT" "$ERR"; }
calls() { cat "$CALLS" 2>/dev/null || true; }

NOREPO="$WORK/norepo"
mkdir -p "$NOREPO"

# A scratch repository with one commit and one unstaged change.
REPO="$WORK/repo"
mkdir -p "$REPO"
(
  cd "$REPO" &&
    git init -q &&
    printf 'one\n' >notes.txt &&
    git add notes.txt &&
    git commit -q -m "initial notes" &&
    printf 'one\ntwo\n' >notes.txt
)

# Stubs every probe invocation needs, so each script gets past its
# dependency checks.
stub fzf
stub delta
stub cb 'cat >"$CALLS.cb"'
stub curl 'printf "%s\n" "{\"results\":[]}"'
stub tmux
stub btop

# ===========================================================================
# Every script: deployed, runs through its shebang, strict mode, copyright
# ===========================================================================
PROBE="$WORK/probe.bash"
cat >"$PROBE" <<'EOF'
trap 'printf "flags=%s pipefail=%s\n" "$-" "$(shopt -qo pipefail && echo on || echo off)" >"$PROBE_OUT"' EXIT
EOF

# name | cwd | expected rc | args — a quick invocation that reaches the end
# of the script's option handling without side effects outside the sandbox.
PROBES="gl|$NOREPO|1|
gd|$NOREPO|1|
gbd|$REPO|0|--help
dot-launch-or-focus|$NOREPO|0|--help
monitor|$NOREPO|0|
pw|$NOREPO|0|12
dtags|$NOREPO|1|
mkscript|$NOREPO|0|--help
rec-start|$NOREPO|0|
rec-stop|$NOREPO|0|"

COPYRIGHT_DIR="$WORK/copyright"
mkdir -p "$COPYRIGHT_DIR"

for script in "${SCRIPTS[@]}"; do
  name="${script#executable_}"

  test_start "${name}_exists"
  assert_file_exists "$BIN_DIR/$script" "$name must exist"

  IFS='|' read -r _ cwd want args < <(printf '%s\n' "$PROBES" | awk -F'|' -v n="$name" '$1 == n')
  args_arr=()
  [[ -n "$args" ]] && args_arr=("$args")

  test_start "${name}_runs"
  RUN_ENV=(BASH_ENV="$PROBE" PROBE_OUT="$WORK/probe-$name")
  run "$cwd" "$name" ${args_arr[@]+"${args_arr[@]}"}
  RUN_ENV=()
  assert_equals "$want" "$RC" "$name ${args:-(no args)} exits $want when executed directly"

  test_start "${name}_strict_mode"
  probe="$(cat "$WORK/probe-$name" 2>/dev/null || echo "no probe output")"
  flags="${probe#flags=}"
  flags="${flags%% *}"
  assert_equals "e u pipefail=on" \
    "$([[ "$flags" == *e* ]] && printf 'e ')$([[ "$flags" == *u* ]] && printf 'u ')${probe##* }" \
    "$name exits with errexit, nounset and pipefail in force"

  cp "$BIN_DIR/$script" "$COPYRIGHT_DIR/$name.sh"
done

# The validator scans every *.sh below its working directory with rg.
test_start "scripts_copyright_headers"
if command -v rg >/dev/null 2>&1; then
  rc=0
  (cd "$COPYRIGHT_DIR" && bash "$REPO_ROOT/tools/ci/check-copyright-headers.sh" \
    --extensions=sh --no-spdx-value) >"$OUT" 2>&1 || rc=$?
  assert_equals "0" "$rc" "the copyright validator accepts every script ($(tail -1 "$OUT"))"
  assert_contains "All ${#SCRIPTS[@]} file(s)" "$(cat "$OUT")" "the validator checked all ${#SCRIPTS[@]} scripts"
else
  skip_case "scripts_copyright_headers" "rg not installed (the validator needs it)"
fi

# ===========================================================================
# gl — fzf + delta git log browser
# ===========================================================================
FZF_ARGS="$WORK/fzf-args"
# fzf stub: record each argument on its own line, the DELTA_FEATURES it
# inherited, and whatever list it was piped.
FZF_STUB='printf "%s\n" "$@" >"'"$FZF_ARGS"'"
printf "DELTA_FEATURES=%s\n" "${DELTA_FEATURES:-}" >>"'"$FZF_ARGS"'"
[[ -t 0 ]] || cat >"'"$FZF_ARGS"'.stdin"'
stub fzf "$FZF_STUB"
# fzf_bind <prefix>: the rest of the argument starting with prefix;
# fzf_after <flag>: the argument following flag.
fzf_bind() { awk -v p="$1" 'index($0, p) == 1 { print substr($0, length(p) + 1); exit }' "$FZF_ARGS"; }
fzf_after() { awk -v f="$1" 'hit { print; exit } $0 == f { hit = 1 }' "$FZF_ARGS"; }
# shell_in_repo <command> — run a command line fzf would run, inside $REPO
shell_in_repo() { (cd "$REPO" && PATH="$STUBS:$TOOLS:/usr/bin:/bin" CALLS="$CALLS" bash -c "$1") 2>&1; }
head_sha="$(git -C "$REPO" rev-parse --short HEAD)"

test_start "gl_uses_fzf"
unstub fzf
run "$REPO" gl
assert_equals "1" "$RC" "gl refuses to start without fzf"
assert_contains "gl requires fzf" "$(out)" "the missing tool is named"
stub fzf "$FZF_STUB"
run "$REPO" gl
assert_equals "0" "$RC" "gl exits 0 when fzf returns"
start_cmd="$(fzf_bind 'start:reload(')"
start_cmd="${start_cmd%)}"
assert_contains "$head_sha" "$(shell_in_repo "$start_cmd")" \
  "fzf's start binding lists the repository's commits"
assert_contains "initial notes" "$(shell_in_repo "$start_cmd")" "with their subjects"

test_start "gl_uses_delta"
unstub delta
run "$REPO" gl
assert_equals "1" "$RC" "gl refuses to start without delta"
assert_contains "gl requires delta" "$(out)" "the missing tool is named"
stub delta 'cat >"$CALLS.delta"'
run "$REPO" gl
preview="$(fzf_after --preview)"
shell_in_repo "FZF_PREVIEW_COLUMNS=80; ${preview//\{1\}/$head_sha}" >/dev/null
assert_contains "delta --width=80" "$(calls)" "the preview pipes the commit through delta"
assert_contains "+one" "$(cat "$CALLS.delta" 2>/dev/null)" "delta receives the commit's diff"
enter="$(fzf_bind 'enter:execute(')"
enter="${enter%)}"
shell_in_repo "${enter//\{1\}/$head_sha}" >/dev/null
assert_contains "delta --paging always" "$(calls)" "Enter shows the commit through a paging delta"

test_start "gl_supports_side_mode"
run "$REPO" gl
assert_contains "DELTA_FEATURES=" "$(cat "$FZF_ARGS")" "fzf runs"
assert_equals "" "$(awk -F= '/^DELTA_FEATURES=/ { print $2 }' "$FZF_ARGS" | tr -d ' ')" \
  "without --side delta keeps its default layout"
run "$REPO" gl --side
assert_equals "side-by-side" "$(awk -F= '/^DELTA_FEATURES=/ { print $2 }' "$FZF_ARGS" | tr -d ' ')" \
  "--side switches delta to side-by-side"
start_cmd="$(fzf_bind 'start:reload(')"
start_cmd="${start_cmd%)}"
assert_contains "$head_sha" "$(shell_in_repo "$start_cmd")" \
  "--side is not forwarded to git log (the listing still works)"

# ===========================================================================
# gd — fzf + delta git diff browser
# ===========================================================================
test_start "gd_uses_fzf"
unstub fzf
run "$REPO" gd
assert_equals "1" "$RC" "gd refuses to start without fzf"
assert_contains "gd requires fzf" "$(out)" "the missing tool is named"
stub fzf "$FZF_STUB"
run "$REPO" gd
assert_equals "0" "$RC" "gd exits 0 when fzf returns"
assert_equals "notes.txt" "$(cat "$FZF_ARGS.stdin" 2>/dev/null)" "fzf is offered the changed file"
: >"$CALLS.delta"
preview="$(fzf_after --preview)"
shell_in_repo "FZF_PREVIEW_COLUMNS=80; ${preview//\{-1\}/notes.txt}" >/dev/null
assert_contains "b/notes.txt" "$(cat "$CALLS.delta" 2>/dev/null)" "the preview pipes the file's diff through delta"
assert_contains "two" "$(cat "$CALLS.delta" 2>/dev/null)" "including the unstaged line"

# ===========================================================================
# gbd — bulk branch delete
# ===========================================================================
BR="$WORK/branches"
mkdir -p "$BR"
(cd "$BR" && git init -q && git commit -q --allow-empty -m base)
branches() { git -C "$BR" for-each-ref --format='%(refname:short)' refs/heads | LC_ALL=C sort | tr '\n' ' '; }
make_branches() { for b in "$@"; do git -C "$BR" branch "$b"; done; }

test_start "gbd_has_dry_run"
make_branches feature-a feature-b master
run "$BR" gbd --dry-run
assert_equals "0" "$RC" "--dry-run exits 0"
assert_contains "Would delete:" "$(out)" "the dry run announces itself"
assert_contains "  feature-a" "$(out)" "feature-a would be deleted"
assert_contains "  feature-b" "$(out)" "feature-b would be deleted"
assert_equals "feature-a feature-b main master " "$(branches)" "nothing is deleted"

test_start "gbd_protects_main"
run "$BR" gbd
assert_equals "0" "$RC" "gbd exits 0"
assert_equals "main master " "$(branches)" "main and master survive, the rest are deleted"
git -C "$BR" checkout -q -b topic
make_branches develop
run "$BR" gbd
assert_equals "0" "$RC" "gbd exits 0 while on a feature branch"
assert_equals "main master topic " "$(branches)" "the current branch is never deleted"
git -C "$BR" checkout -q main

# ===========================================================================
# dot-launch-or-focus — niri IPC
# ===========================================================================
NIRI_WINDOWS="$WORK/windows.json"
stub niri '[[ "$2" == "--json" ]] && cat "'"$NIRI_WINDOWS"'"; exit 0'

test_start "dot_launch_or_focus_uses_niri"
if [[ -x "$TOOLS/jq" ]]; then
  printf '[{"id":3,"app_id":"org.mozilla.firefox"},{"id":7,"app_id":"com.mitchellh.ghostty"}]\n' >"$NIRI_WINDOWS"
  run "$NOREPO" dot-launch-or-focus ghostty
  assert_equals "0" "$RC" "focusing exits 0"
  assert_contains "niri msg action focus-window --id 7" "$(calls)" \
    "a running app is focused by its niri window id"
  run "$NOREPO" dot-launch-or-focus com.example.editor --new-window
  assert_contains "niri msg action spawn -- editor --new-window" "$(calls)" \
    "an app that is not running is spawned through niri by its short name"
else
  skip_case "dot_launch_or_focus_uses_niri" "jq not installed"
fi

test_start "dot_launch_or_focus_falls_back_without_niri"
unstub niri
stub editor
run "$NOREPO" dot-launch-or-focus com.example.editor --new-window file.txt
assert_equals "0" "$RC" "the direct launch exits 0"
assert_contains "requires niri" "$(out)" "the missing compositor is explained"
assert_equals "editor --new-window file.txt" "$(calls)" \
  "the app is launched once, by its short name, with its arguments unchanged"

# ===========================================================================
# monitor — btop + GPU monitor in tmux
# ===========================================================================
# uname answers without logging, so $CALLS holds only the tmux call.
printf '#!%s\necho Linux\n' "$REAL_BASH" >"$STUBS/uname"
chmod +x "$STUBS/uname"
stub nvtop
stub nvidia-smi

test_start "monitor_detects_gpu"
run "$NOREPO" monitor
assert_equals "0" "$RC" "monitor exits 0"
assert_equals "tmux new-session -s monitor btop ; split-window nvtop" "$(calls)" \
  "on Linux nvtop is opened beside btop in a new session"
unstub nvtop
run "$NOREPO" monitor
assert_equals "tmux new-session -s monitor btop ; split-window nvidia-smi" "$(calls)" \
  "without nvtop it falls back to nvidia-smi"
RUN_ENV=("TMUX=/tmp/fake,1,0")
run "$NOREPO" monitor
RUN_ENV=()
assert_equals "tmux new-window -n monitor btop ; split-window nvidia-smi" "$(calls)" \
  "inside tmux it opens a window instead of a session"
unstub uname
unstub nvidia-smi

# ===========================================================================
# pw — password to clipboard
# ===========================================================================
test_start "pw_uses_cb"
if [[ -x "$TOOLS/openssl" ]]; then
  rm -f "$CALLS.cb"
  run "$NOREPO" pw 20
  assert_equals "0" "$RC" "pw exits 0"
  assert_contains "Password (20 chars) copied to clipboard." "$(out)" "the copy is reported"
  pw_value="$(cat "$CALLS.cb" 2>/dev/null)"
  assert_equals "20" "${#pw_value}" "cb receives a 20-character password"
  assert_equals "" "$(printf '%s' "$pw_value" | tr -d 'A-Za-z0-9+/=')" "the password is base64 text"
  assert_equals "no" "$([[ -n "$pw_value" && "$(out)" == *"$pw_value"* ]] && echo yes || echo no)" \
    "the password itself is not printed"
else
  skip_case "pw_uses_cb" "openssl not installed"
fi
rm -f "$CALLS.cb"
run "$NOREPO" pw 0
assert_equals "1" "$RC" "a zero length is rejected"
assert_contains "Usage: pw [length] (1-1024, default 48)" "$(out)" "the valid range is explained"
assert_file_not_exists "$CALLS.cb" "nothing is copied to the clipboard"

# ===========================================================================
# dtags — Docker Hub tag listing
# ===========================================================================
test_start "dtags_queries_docker_hub"
if [[ -x "$TOOLS/jq" ]]; then
  stub curl 'printf "%s\n" "{\"results\":[{\"name\":\"3.10\"},{\"name\":\"3.9\"},{\"name\":\"3.11\"}]}"'
  run "$NOREPO" dtags python
  assert_equals "0" "$RC" "dtags exits 0"
  assert_contains "https://registry.hub.docker.com/v2/repositories/library/python/tags?page_size=1000" \
    "$(calls)" "the Docker Hub tags endpoint for the image is queried"
  assert_equals $'3.9\n3.10\n3.11' "$(cat "$OUT")" "the tags are printed in version order"
else
  skip_case "dtags_queries_docker_hub" "jq not installed"
fi

# ===========================================================================
# mkscript — scaffold an executable script
# ===========================================================================
test_start "mkscript_creates_executable"
NEW="$WORK/made/sub/hello"
run "$NOREPO" mkscript "$NEW"
assert_equals "0" "$RC" "mkscript exits 0"
assert_true "[[ -x '$NEW' ]]" "the new script is executable"
assert_equals "hello world" "$("$NEW" 2>&1)" "the new script runs directly"
run "$NOREPO" mkscript "$NEW"
assert_equals "1" "$RC" "an existing file is not overwritten"

# ===========================================================================
# rec-start / rec-stop — hide and restore shell history
# ===========================================================================
HIST="$HOME/.zsh_history"
FISH_HIST="$HOME/.local/share/fish/fish_history"
mkdir -p "${FISH_HIST%/*}"
printf 'secret-command\n' >"$HIST"
printf -- '- cmd: fish-secret\n' >"$FISH_HIST"

test_start "rec_start_backs_up_histfile"
RUN_ENV=(HISTFILE="$HIST")
run "$NOREPO" rec-start
assert_equals "0" "$RC" "rec-start exits 0"
assert_file_not_exists "$HIST" "the HISTFILE is moved out of the way"
assert_equals "secret-command" "$(cat "$HIST.bak" 2>/dev/null)" "its contents are kept in a backup"
assert_file_not_exists "$FISH_HIST" "the fish history is moved out of the way too"
assert_contains "Recording mode ON (2 files backed up)" "$(out)" "the switch is reported"
run "$NOREPO" rec-start
assert_equals "0" "$RC" "a second rec-start finds nothing to hide"

test_start "rec_stop_restores_histfile"
run "$NOREPO" rec-stop
RUN_ENV=()
assert_equals "0" "$RC" "rec-stop exits 0"
assert_equals "secret-command" "$(cat "$HIST" 2>/dev/null)" "the HISTFILE is restored"
assert_file_not_exists "$HIST.bak" "the backup is consumed"
assert_equals "- cmd: fish-secret" "$(cat "$FISH_HIST" 2>/dev/null)" "the fish history is restored"
assert_contains "Recording mode OFF (2 files restored)" "$(out)" "the switch is reported"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
