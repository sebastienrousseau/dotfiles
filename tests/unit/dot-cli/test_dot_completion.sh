#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016 # the quoted scripts run in another shell
# Shell completion for dot (ADR-020, N0.4). The five scripts are generated
# from the plugin manifests by tools/docs/gen_completions.py; these cases
# check the committed files are current, that `dot cli completion show
# <shell>` prints them, and that each shell completes the same names: the
# domains and shortcuts first, then objects and verbs, then a command's flags
# and argument values. Each shell's own completion engine (or its completer
# functions) answers the queries; a shell that is not installed is skipped.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BASH_FILE="$REPO_ROOT/defaults/dot_local/share/bash-completion/completions/dot"
ZSH_FILE="$REPO_ROOT/share/completions/zsh/_dot"
FISH_FILE="$REPO_ROOT/defaults/dot_config/fish/completions/dot.fish"
NU_FILE="$REPO_ROOT/defaults/dot_config/nushell/completions.nu"
PS_FILE="$REPO_ROOT/share/completions/powershell/dot.ps1"
BASH_BIN="$(command -v bash)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-completion.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# One AI pattern, so `--pattern` has something to offer.
export XDG_CONFIG_HOME="$WORK/config"
mkdir -p "$XDG_CONFIG_HOME/ai/patterns"
touch "$XDG_CONFIG_HOME/ai/patterns/architect.md"

# Each query helper prints the candidates for `dot WORD... CUR`, sorted and
# space-separated; the last argument is the word being completed.
bash_q() {
  "$BASH_BIN" -c 'source "$1"; shift; COMP_WORDS=(dot "$@"); COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
    _dot; printf "%s\n" "${COMPREPLY[@]}"' _ "$BASH_FILE" "$@" | LC_ALL=C sort | paste -sd " " -
}
zsh_q() {
  zsh -f -c 'source "$1"; shift
    _describe() { local -a a; a=("${(@P)4}"); print -rl -- ${a%%:*}; }
    compadd() { shift; print -rl -- "$@"; }
    _files() { print FILES; }
    _message() { :; }
    words=(dot "$@"); CURRENT=${#words}; PREFIX="${words[CURRENT]}"; _dot' _ "$ZSH_FILE" "$@" |
    LC_ALL=C sort | paste -sd " " -
}
fish_q() {
  fish --no-config -c 'source $argv[1]; complete -C "dot $argv[2]"' "$FISH_FILE" "$*" | cut -f1 | LC_ALL=C sort | paste -sd " " -
}
cat >"$WORK/q.ps1" <<'PS'
param([string]$File, [string]$Line)
. $File
$l = "dot $Line"
(TabExpansion2 -inputScript $l -cursorColumn $l.Length).CompletionMatches.CompletionText
PS
ps_q() {
  pwsh -NoProfile -File "$WORK/q.ps1" -File "$PS_FILE" -Line "$*" | LC_ALL=C sort | paste -sd " " -
}
# missing LIST WORD...: the WORDs LIST lacks (empty when it has them all).
missing() {
  local list=" $1 " w out=""
  shift
  for w in "$@"; do [[ "$list" == *" $w "* ]] || out="$out $w"; done
  printf '%s' "$out"
}

test_start "committed_scripts_match_the_manifests"
rc=0
python3 "$REPO_ROOT/tools/docs/gen_completions.py" --root "$REPO_ROOT" --check >"$WORK/check" 2>&1 || rc=$?
assert_equals "0" "$rc" "gen_completions.py --check: $(cat "$WORK/check")"

test_start "show_prints_each_committed_script"
for pair in "bash:$BASH_FILE" "zsh:$ZSH_FILE" "fish:$FISH_FILE" "nu:$NU_FILE" "pwsh:$PS_FILE"; do
  HOME="$WORK" "$BASH_BIN" "$REPO_ROOT/bin/dot" cli completion show "${pair%%:*}" >"$WORK/out" 2>/dev/null
  assert_true "cmp -s '$WORK/out' '${pair#*:}'" "dot cli completion show ${pair%%:*} prints its file"
done
rc=0
HOME="$WORK" "$BASH_BIN" "$REPO_ROOT/bin/dot" cli completion show tcsh >/dev/null 2>"$WORK/err" || rc=$?
assert_equals "1" "$rc" "an unknown shell fails"
assert_file_contains "$WORK/err" "want: bash|zsh|fish|nu|pwsh" "and lists the shells"

test_start "completion_module_prints_files_and_rejects_others"
MODULE="$REPO_ROOT/scripts/dot/commands/completion.sh"
HOME="$WORK" "$BASH_BIN" "$MODULE" completion nushell >"$WORK/out" 2>/dev/null
assert_true "cmp -s '$WORK/out' '$NU_FILE'" "nushell is another name for nu"
rc=0
HOME="$WORK" "$BASH_BIN" "$MODULE" completion csh >"$WORK/out" 2>"$WORK/err" || rc=$?
assert_equals "1" "$rc" "scripts/dot/commands/completion.sh: an unknown shell exits 1"
assert_equals "" "$(cat "$WORK/out")" "and prints no script"
rc=0
HOME="$WORK" "$BASH_BIN" "$MODULE" completion >"$WORK/out" 2>&1 || rc=$?
assert_equals "0" "$rc" "no shell prints the usage"
assert_file_contains "$WORK/out" "Usage: dot cli completion show" "the usage"

test_start "generate_completions_wrapper"
GEN="$REPO_ROOT/tools/docs/generate-completions.sh"
rc=0
"$BASH_BIN" "$GEN" --outdir >/dev/null 2>"$WORK/err" || rc=$?
assert_equals "2" "$rc" "tools/docs/generate-completions.sh: --outdir needs a path"
rc=0
"$BASH_BIN" "$GEN" --bogus >/dev/null 2>"$WORK/err" || rc=$?
assert_equals "2" "$rc" "an unknown flag exits 2"
rc=0
"$BASH_BIN" "$GEN" --outdir "$WORK/gen" >/dev/null 2>&1 || rc=$?
assert_equals "0" "$rc" "--outdir writes"
assert_equals "_dot completions.nu dot dot.fish dot.ps1" "$(ls "$WORK/gen" | LC_ALL=C sort | paste -sd " " -)" "all five scripts"
rc=0
"$BASH_BIN" "$GEN" --check >"$WORK/out" 2>&1 || rc=$?
assert_equals "0" "$rc" "--check passes on the repository"

test_start "a_stale_script_fails_the_check"
# A copy of the generator's inputs and outputs, with one output edited.
for rel in lib/dot/data/commands.txt schemas/cli/domains.json \
  "${BASH_FILE#"$REPO_ROOT"/}" "${ZSH_FILE#"$REPO_ROOT"/}" "${FISH_FILE#"$REPO_ROOT"/}" \
  "${NU_FILE#"$REPO_ROOT"/}" "${PS_FILE#"$REPO_ROOT"/}"; do
  mkdir -p "$WORK/tree/$(dirname "$rel")"
  cp "$REPO_ROOT/$rel" "$WORK/tree/$rel"
done
printf '# edited by hand\n' >>"$WORK/tree/${FISH_FILE#"$REPO_ROOT"/}"
rc=0
python3 "$REPO_ROOT/tools/docs/gen_completions.py" --root "$WORK/tree" --check 2>"$WORK/err" || rc=$?
assert_equals "1" "$rc" "an edited script fails --check"
assert_file_contains "$WORK/err" "dot.fish is stale" "and is named"

test_start "bash_completes_the_command_tree"
top="$(bash_q '')"
assert_equals "" "$(missing "$top" system doctor config ai update apply cd help version)" "domains, shortcuts and built-ins"
assert_equals " upgrade" "$(missing "$top" upgrade)" "a deprecated name is not offered"
assert_equals "clean schedule settings show status update" "$(bash_q system '')" "a domain's objects and verbs"
assert_equals "list run set" "$(bash_q system schedule '')" "an object's verbs"

test_start "bash_completes_flags_and_values"
assert_equals "" "$(missing "$(bash_q doctor perf show -)" --json -j --runs -r --help)" "a command's flags"
assert_equals "" "$(bash_q doctor perf show --runs '')" "a flag that takes a number offers nothing"
assert_equals "architect" "$(bash_q ai run claude --pattern '')" "a pattern flag offers the AI patterns"
assert_equals "" "$(missing "$(bash_q ai run '')" claude codex)" "ai run offers the agents"
assert_equals "go molecule node packer python" "$(bash_q tool new '')" "tool new offers its templates"
assert_equals "--globals --help --yes -y" "$(bash_q update -)" "a shortcut completes as its target"
mkdir -p "$WORK/cwd/somedir"
assert_equals "somedir" "$(cd "$WORK/cwd" && bash_q config add so)" "config add completes files"

for shell in zsh fish nu pwsh; do
  test_start "${shell}_matches_bash"
  if ! command -v "$shell" >/dev/null 2>&1; then
    assert_true "true" "$shell not installed; skipped"
    continue
  fi
  case "$shell" in
    zsh)
      assert_equals "$top" "$(zsh_q '')" "the same top level"
      assert_equals "$(bash_q system schedule '')" "$(zsh_q system schedule '')" "the same object verbs"
      assert_equals "$(bash_q doctor perf show -)" "$(zsh_q doctor perf show -)" "the same flags"
      assert_equals "architect" "$(zsh_q ai run claude --pattern '')" "the AI patterns"
      ;;
    fish)
      assert_equals "$top" "$(fish_q '' | tr " " "\n" | grep -v "^-" | paste -sd " " -)" "the same top level"
      assert_equals "$(bash_q system schedule '')" "$(fish_q system schedule '')" "the same object verbs"
      assert_equals "" "$(missing "$(fish_q doctor perf show -)" --json -j --runs -r)" "the flags"
      assert_equals "architect" "$(fish_q ai run claude --pattern '')" "the AI patterns"
      ;;
    nu)
      nu --no-config-file -c "source $NU_FILE; nu-complete dot system schedule | get value | str join ' '" >"$WORK/nu" 2>&1
      assert_equals "list set run" "$(cat "$WORK/nu")" "an object's completer"
      nu --no-config-file -c "source $NU_FILE; nu-complete dot | get value | sort | str join ' '" >"$WORK/nu" 2>&1
      assert_equals "$top" "$(cat "$WORK/nu")" "the same top level"
      ;;
    pwsh)
      assert_equals "$top" "$(ps_q '')" "the same top level"
      assert_equals "$(bash_q system schedule '')" "$(ps_q system schedule '')" "the same object verbs"
      assert_equals "--help" "$(ps_q doctor -)" "a single flag is not split into characters"
      assert_equals "architect" "$(ps_q ai run claude --pattern '')" "the AI patterns"
      ;;
  esac
done

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
