#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# scripts/ops/heal.sh summary when a repair is found but declined: the run
# is confirmed interactively, the one broken symlink is kept at its own
# prompt, and heal must report "no fixes could be applied" and point at
# `dot doctor`. (The existing flow suite reaches that line with a read-only
# directory, which root in the coverage container writes through anyway.)
#
# Own sandbox HOME without ~/.dotfiles, every dependency heal probes shimmed
# on PATH, and the lock in a sandbox XDG_RUNTIME_DIR.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

HEAL="$REPO_ROOT/scripts/ops/heal.sh"
WORK="$(mktemp -d -t heal-cov.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

H="$WORK/home"
mkdir -p "$H/.config/shell" "$H/.config/nvim" "$H/.config/git" "$WORK/deps" "$WORK/run"
touch "$H/.zshrc" "$H/.bashrc" "$H/.profile"
ln -s "$WORK/nonexistent-target" "$H/dead-link"

for t in zsh chezmoi starship rg bat fzf zoxide atuin yazi zellij nu pueue pueued \
  wasmtime sops age hyperfine mise direnv; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$WORK/deps/$t"
  chmod +x "$WORK/deps/$t"
done

test_start "heal_declined_fix_reports_no_fixes_applied"
RC=0
OUT="$(printf 'y\nn\n' | env -u DOTFILES_NONINTERACTIVE HOME="$H" \
  XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
  XDG_STATE_HOME="$H/.local/state" XDG_CACHE_HOME="$H/.cache" \
  XDG_RUNTIME_DIR="$WORK/run" PATH="$WORK/deps:$PATH" NO_COLOR=1 \
  "${BASH:-bash}" "$HEAL" 2>&1)" || RC=$?
assert_equals 0 "$RC" "declined repair still exits 0"
assert_contains "This will auto-repair" "$OUT" "run was confirmed interactively"
assert_contains "but no fixes could be applied" "$OUT" "no-fix summary printed"
assert_contains "dot doctor" "$OUT" "doctor hint printed"
assert_true "[[ -L '$H/dead-link' ]]" "declined symlink left in place"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" == 0 ]]
