#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# scripts/uninstall.sh, run against a throwaway HOME. The script deletes
# whatever it finds under $HOME, so every run is guarded: HOME must be a
# fresh mktemp directory that is not the real home (on 2026-09-24 an
# uninstall run outside a sandbox purged the real ~/.dotfiles).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

UNINSTALL_SCRIPT="$REPO_ROOT/scripts/uninstall.sh"
REAL_HOME="$HOME"
WORK="$(mktemp -d -t dot-uninstall.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

MANAGED=(
  .dotfiles/README.md .config/chezmoi/chezmoi.toml .local/share/chezmoi/README.md
  .local/bin/dot .local/bin/dot-ai .local/bin/dot-theme-sync .local/bin/tour
  .local/bin/ai_core .local/bin/ai-update .local/bin/antigravity
  .local/bin/git-ai-commit .local/bin/git-ai-diff
  .cache/dotfiles/x .cache/zsh/x .cache/bash/x
  .local/state/dotfiles/x .local/share/dotfiles.log
  .local/share/zsh/completions/_dot .local/share/bash-completion/completions/dot
)
KEPT=(.config/keep/me.conf .local/bin/not-ours .cache/other/x)

# uninstall <home> <stdin> [args…] — run the script with HOME=<home>, a
# recording chezmoi stub first on PATH, and <stdin> as the answer to its
# prompt. Refuses (exit 97) unless <home> is inside this test's mktemp dir.
uninstall() {
  local home="$1" answer="$2"
  shift 2
  case "$(cd "$home" && pwd -P)/" in
    "$(cd "$WORK" && pwd -P)"/*) ;;
    *)
      echo "refusing: $home is not inside the test sandbox" >&2
      exit 97
      ;;
  esac
  [[ "$(cd "$home" && pwd -P)" != "$(cd "$REAL_HOME" && pwd -P)" ]] || exit 97
  RC=0
  OUT="$(printf '%s\n' "$answer" | env -i PATH="$WORK/bin:/usr/bin:/bin" HOME="$home" \
    XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share" \
    XDG_CACHE_HOME="$home/.cache" XDG_STATE_HOME="$home/.local/state" \
    bash "$UNINSTALL_SCRIPT" "$@" 2>&1)" || RC=$?
}

# fresh_home <name> — a HOME holding every managed path and some that are not.
fresh_home() {
  local home="$WORK/$1" f
  for f in "${MANAGED[@]}" "${KEPT[@]}"; do
    mkdir -p "$home/$(dirname "$f")"
    printf 'planted\n' >"$home/$f"
  done
  printf '%s\n' "$home"
}

mkdir -p "$WORK/bin"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >>"%s/chezmoi.calls"\n' "$WORK" >"$WORK/bin/chezmoi"
chmod +x "$WORK/bin/chezmoi"

test_start "declining_the_prompt_removes_nothing"
H="$(fresh_home declined)"
uninstall "$H" n
assert_equals "0" "$RC" "declining exits 0"
assert_contains "Aborted." "$OUT" "and says so"
left=0
for f in "${MANAGED[@]}"; do [[ -e "$H/$f" ]] && left=$((left + 1)); done
assert_equals "${#MANAGED[@]}" "$left" "every managed path is still there"
assert_file_not_exists "$WORK/chezmoi.calls" "chezmoi was never asked to purge"

test_start "yes_at_the_prompt_uninstalls"
H="$(fresh_home accepted)"
uninstall "$H" y
assert_equals "0" "$RC" "answering y exits 0"
assert_contains "Uninstall complete." "$OUT" "and completes"
assert_file_not_exists "$H/.dotfiles" "the source checkout is removed"

test_start "force_removes_every_managed_path_and_nothing_else"
H="$(fresh_home forced)"
rm -f "$WORK/chezmoi.calls"
uninstall "$H" "" --force
assert_equals "0" "$RC" "--force exits 0 without asking"
assert_equals "0" "$(grep -c 'Continue?' <<<"$OUT")" "no prompt with --force"
assert_equals "purge --force" "$(cat "$WORK/chezmoi.calls" 2>/dev/null)" "chezmoi purges the managed files"
left=""
for f in "${MANAGED[@]}"; do [[ -e "$H/$f" ]] && left="$left $f"; done
assert_equals "" "$left" "every managed path is removed"
kept=0
for f in "${KEPT[@]}"; do [[ -f "$H/$f" ]] && kept=$((kept + 1)); done
assert_equals "${#KEPT[@]}" "$kept" "files dotfiles does not own are kept"

test_start "the_real_home_is_untouched"
assert_file_exists "$REPO_ROOT/scripts/uninstall.sh" "the checkout under test is intact"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
