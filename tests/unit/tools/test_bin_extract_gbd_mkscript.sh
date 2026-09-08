#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural tests for the small deployed CLI utilities in
# defaults/dot_local/bin:
#
#   executable_extract        universal archive extractor
#   executable_mkscript       scaffold a new shell script
#   executable_gbd            bulk-delete local git branches
#   executable_dot-ai         retrieval-augmented query over the dotfiles
#
# and for scripts/tools/figlet-banner.sh.
#
# Every external tool each script reaches for (tar, unzip, git, rg, nix,
# figlet, toilet, dot) is a PATH-shadowed recording stub, so no archive is
# unpacked, no branch is deleted and no AI call is made.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

BINDIR="$REPO_ROOT/defaults/dot_local/bin"
EXTRACT="$BINDIR/executable_extract"
MKSCRIPT="$BINDIR/executable_mkscript"
GBD="$BINDIR/executable_gbd"
DOT_AI="$BINDIR/executable_dot-ai"
FIGLET_BANNER="$REPO_ROOT/scripts/tools/figlet-banner.sh"
REAL_BASH="${BASH:-$(command -v bash)}"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
BIN="$DOTFILES_COV_TMPDIR/bin"
WORK="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$WORK"

test_start "scripts_exist"
for f in "$EXTRACT" "$MKSCRIPT" "$GBD" "$DOT_AI" "$FIGLET_BANNER"; do
  assert_file_exists "$f" "$(basename "$f") must exist"
done

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
mkstub() {
  cat >"$BIN/$1" <<EOF
#!$REAL_BASH
printf '%s %s\n' "$1" "\$*" >>"$CALLS"
${2:-:}
exit ${3:-0}
EOF
  chmod +x "$BIN/$1"
}

OUT="$WORK/out.txt"
ERR="$WORK/err.txt"
# run <script> <args…> — run with only the stub dir plus the system dirs on
# PATH. Stdout is captured; stderr is replayed so the coverage runner keeps
# its xtrace records. Echoes the exit status.
run() {
  local script="$1" rc=0
  shift
  PATH="$BIN:/usr/bin:/bin" HOME="$HOME" \
    "$REAL_BASH" "$script" "$@" </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}
# run_bare <path-dir> <script> <args…> — same, with a caller-chosen PATH.
run_bare() {
  local path="$1" script="$2" rc=0
  shift 2
  PATH="$path" "$REAL_BASH" "$script" "$@" </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}

# ===========================================================================
# executable_extract
# ===========================================================================
mkstub tar
mkstub unzip
mkstub unrar
mkstub 7z
mkstub nix

test_start "extract_usage_and_argument_validation"
rc="$(run "$EXTRACT" --help)"
assert_equals "0" "$rc" "--help exits 0"
assert_file_contains "$OUT" "Usage: extract <archive>" "usage is printed"
rc="$(run "$EXTRACT" -h)"
assert_equals "0" "$rc" "-h exits 0"
rc="$(run "$EXTRACT")"
assert_equals "1" "$rc" "no argument is a usage error"
rc="$(run "$EXTRACT" --bogus)"
assert_equals "2" "$rc" "an unknown option exits 2"
assert_file_contains "$ERR" "Unknown option: --bogus" "the error names the option"

test_start "extract_dispatches_each_archive_type_to_its_tool"
while IFS='|' read -r file tool args; do
  [[ -n "$file" ]] || continue
  : >"$CALLS"
  rc="$(run "$EXTRACT" "$file")"
  assert_equals "0" "$rc" "$file extracts cleanly"
  # `args` is empty for unzip, so build the expected line without a stray
  # double space.
  expect="$tool ${args:+$args }$file"
  assert_file_contains "$CALLS" "$expect" "$file is handed to $tool"
done <<'ARCHIVES'
sample.tar.bz2|tar|xvjf
sample.tar.gz|tar|xvzf
sample.tar.xz|tar|xvf
sample.tar.zst|tar|xvf
sample.zip|unzip|
sample.rar|unrar|x
sample.7z|7z|a
ARCHIVES

test_start "extract_rejects_an_unknown_archive_type"
rc="$(run "$EXTRACT" mystery.bin)"
assert_equals "1" "$rc" "an unrecognised extension fails"
assert_file_contains "$ERR" "cannot be extracted" "the error explains the refusal"

test_start "extract_falls_back_to_nix_when_the_tool_is_missing"
NIXONLY="$WORK/nix-only"
mkdir -p "$NIXONLY"
for tool in bash sh printf echo; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$NIXONLY/$tool"
done
ln -sf "$BIN/nix" "$NIXONLY/nix"
: >"$CALLS"
rc="$(run_bare "$NIXONLY" "$EXTRACT" sample.zip)"
assert_equals "0" "$rc" "the nix fallback exits 0"
assert_file_contains "$ERR" "Using Nix fallback" "the fallback is announced"
assert_file_contains "$CALLS" "nix shell nixpkgs#unzip -c unzip sample.zip" "nix runs the missing tool"

test_start "extract_fails_when_neither_the_tool_nor_nix_is_available"
BAREPATH="$WORK/bare-path"
mkdir -p "$BAREPATH"
for tool in bash sh; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$BAREPATH/$tool"
done
rc="$(run_bare "$BAREPATH" "$EXTRACT" sample.zip)"
assert_equals "1" "$rc" "no tool and no nix is an error"
assert_file_contains "$ERR" "not found and Nix not available" "the error explains both misses"

# ===========================================================================
# executable_mkscript
# ===========================================================================
test_start "mkscript_usage_and_argument_validation"
rc="$(run "$MKSCRIPT" --help)"
assert_equals "0" "$rc" "--help exits 0"
assert_file_contains "$ERR" "Usage: mkscript <path>" "usage is printed"
rc="$(run "$MKSCRIPT")"
assert_equals "1" "$rc" "no argument is a usage error"
rc="$(run "$MKSCRIPT" --bogus)"
assert_equals "2" "$rc" "an unknown option exits 2"
assert_file_contains "$ERR" "Unknown option: --bogus" "the error names the option"

test_start "mkscript_scaffolds_an_executable_script"
target="$WORK/new/dir/hello"
rc="$(run "$MKSCRIPT" "$target")"
assert_equals "0" "$rc" "mkscript exits 0"
assert_file_exists "$target" "the script is created, parent directories and all"
assert_file_contains "$target" "#!/usr/bin/env bash" "the scaffold has a shebang"
assert_file_contains "$target" "set -euo pipefail" "the scaffold sets the strict options"
assert_file_contains "$OUT" "Created $target" "the creation is reported"
if [[ -x "$target" ]]; then _pass; else _fail "the scaffold is not executable"; fi

test_start "mkscript_refuses_to_overwrite"
rc="$(run "$MKSCRIPT" "$target")"
assert_equals "1" "$rc" "an existing file is not overwritten"
assert_file_contains "$ERR" "already exists, aborting" "the refusal explains why"

# ===========================================================================
# executable_gbd
# ===========================================================================
test_start "gbd_usage_and_argument_validation"
mkstub git 'case "${1:-}" in
  rev-parse) exit 0 ;;
  branch)
    case "${2:-}" in
      --show-current) echo main ;;
      -D) exit 0 ;;
      *) printf "  feature-a\n  feature-b\n* main\n" ;;
    esac
    ;;
esac'
rc="$(run "$GBD" --help)"
assert_equals "0" "$rc" "--help exits 0"
assert_file_contains "$OUT" "Usage: gbd" "usage is printed"
rc="$(run "$GBD" --bogus)"
assert_equals "2" "$rc" "an unknown option exits 2"

test_start "gbd_dry_run_lists_without_deleting"
: >"$CALLS"
rc="$(run "$GBD" --dry-run)"
assert_equals "0" "$rc" "--dry-run exits 0"
assert_file_contains "$OUT" "Would delete" "the dry run announces itself"
assert_file_contains "$OUT" "feature-a" "the branches that would go are listed"
assert_output_not_contains "branch -D" "cat '$CALLS'"

test_start "gbd_deletes_when_not_dry_running"
: >"$CALLS"
rc="$(run "$GBD")"
assert_equals "0" "$rc" "gbd exits 0"
assert_file_contains "$CALLS" "branch -D" "branches are deleted"

test_start "gbd_accepts_a_custom_whitelist"
: >"$CALLS"
rc="$(run "$GBD" "(main|feature-a)" --dry-run)"
assert_equals "0" "$rc" "a custom whitelist exits 0"
assert_file_contains "$OUT" "feature-b" "a non-whitelisted branch is listed"
assert_output_not_contains "feature-a" "cat '$OUT'"

test_start "gbd_rejects_a_bad_second_argument"
rc="$(run "$GBD" "(main)" --nope)"
assert_equals "2" "$rc" "an unknown second argument exits 2"
assert_file_contains "$ERR" "Unknown option: --nope" "the error names the argument"

test_start "gbd_reports_when_there_is_nothing_to_delete"
mkstub git 'case "${1:-}" in
  rev-parse) exit 0 ;;
  branch)
    case "${2:-}" in
      --show-current) echo main ;;
      *) printf "* main\n" ;;
    esac
    ;;
esac'
rc="$(run "$GBD")"
assert_equals "0" "$rc" "nothing to delete is not an error"
assert_file_contains "$OUT" "No branches to delete" "the empty case is reported"

test_start "gbd_requires_a_git_repository"
mkstub git 'case "${1:-}" in rev-parse) exit 128 ;; esac' '' 128
rc="$(run "$GBD")"
assert_equals "1" "$rc" "running outside a repository fails"
assert_file_contains "$ERR" "not a git repository" "the error explains the refusal"

test_start "gbd_requires_git"
rc="$(run_bare "$BAREPATH" "$GBD")"
assert_equals "1" "$rc" "a missing git is an error"
assert_file_contains "$ERR" "gbd requires git" "the error names git"

# ===========================================================================
# scripts/tools/figlet-banner.sh
# ===========================================================================
test_start "figlet_banner_prefers_figlet"
mkstub figlet 'echo "FIGLET-ART"'
mkstub toilet 'echo "TOILET-ART"'
: >"$CALLS"
rc="$(run "$FIGLET_BANNER" hello world)"
assert_equals "0" "$rc" "the banner exits 0"
assert_file_contains "$OUT" "FIGLET-ART" "figlet renders the text"
assert_file_contains "$CALLS" "figlet -f slant hello world" "the default font and text are passed through"

test_start "figlet_banner_falls_back_to_toilet"
TOILETONLY="$WORK/toilet-only"
mkdir -p "$TOILETONLY"
for tool in bash sh echo; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$TOILETONLY/$tool"
done
ln -sf "$BIN/toilet" "$TOILETONLY/toilet"
: >"$CALLS"
rc="$(run_bare "$TOILETONLY" "$FIGLET_BANNER" hi)"
assert_equals "0" "$rc" "the toilet fallback exits 0"
assert_file_contains "$OUT" "TOILET-ART" "toilet renders the text"

test_start "figlet_banner_falls_back_to_plain_text"
rc="$(run_bare "$BAREPATH" "$FIGLET_BANNER" plain-text)"
assert_equals "0" "$rc" "the plain fallback exits 0"
assert_file_contains "$OUT" "plain-text" "the text is echoed verbatim"

test_start "figlet_banner_honours_the_font_override"
: >"$CALLS"
DOTFILES_FIGLET_FONT=big run "$FIGLET_BANNER" x >/dev/null
assert_file_contains "$CALLS" "figlet -f big x" "DOTFILES_FIGLET_FONT selects the font"

# ===========================================================================
# executable_dot-ai
# ===========================================================================
test_start "dot_ai_requires_a_question"
rc="$(run "$DOT_AI")"
assert_equals "1" "$rc" "no question is a usage error"
assert_file_contains "$OUT" "Usage: dot ai-query" "usage is printed"

test_start "dot_ai_retrieves_context_and_asks_the_model"
# dot-ai reads ~/.dotfiles; the sandbox already links that to the repo.
mkstub rg 'echo "docs: the extract function unpacks archives"'
mkstub dot 'echo "model-answer"'
: >"$CALLS"
rc="$(run "$DOT_AI" "how do I extract an archive?")"
assert_equals "0" "$rc" "a question exits 0"
assert_file_contains "$OUT" "Searching dotfiles context" "the retrieval step is announced"
assert_file_contains "$OUT" "Generating context-aware answer" "the generation step is announced"
assert_file_contains "$CALLS" "dot cl --pattern architect" "the question is sent through the architect pattern"
assert_file_contains "$CALLS" "the extract function unpacks archives" "the retrieved context is included"

test_start "dot_ai_handles_an_empty_retrieval"
mkstub rg '' 1
: >"$CALLS"
rc="$(run "$DOT_AI" "nothing matches this")"
assert_equals "0" "$rc" "an empty retrieval still exits 0"
assert_file_contains "$CALLS" "No specific context found" "the placeholder context is sent"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
