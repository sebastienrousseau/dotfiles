#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# defaults/dot_local/bin/executable_update (`update`) end to end. Every
# package manager it drives, and sudo, is a recording stub, so the tests
# assert what it asked for and never update anything.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

UPDATE="$REPO_ROOT/defaults/dot_local/bin/executable_update"
REAL_BASH="$(command -v bash)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/stub" "$WORK/base"
cat >"$WORK/stub/tool" <<'STUB'
#!/bin/sh
n=$(basename "$0")
echo "$n $*" >>"$CALLS"
case "$n $*" in
  "pip3 list --outdated --format=json") printf '%s\n' "${PIP_JSON:-[]}" ;;
esac
# FAIL names a tool, or a tool and leading arguments ("pip3 install").
if [ -n "${FAIL:-}" ]; then
  case "$n $* " in "$FAIL "*) echo "$n failed" >&2; exit 1 ;; esac
fi
exit 0
STUB
chmod +x "$WORK/stub/tool"
# Real utilities the script needs; nothing else from the host is on PATH.
for t in basename xargs python3; do ln -s "$(command -v "$t")" "$WORK/base/$t"; done
N=0

# run_update <tools> [FAIL=tool] [PIP_JSON=json] -- [args...]: run `update`
# with only <tools> (comma list) installed. Sets OUT (stdout+stderr), RC
# and CALLS_FILE.
run_update() {
  local tools="$1" fail="" pip="[]" t d
  shift
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    case "$1" in FAIL=*) fail="${1#*=}" ;; PIP_JSON=*) pip="${1#*=}" ;; esac
    shift
  done
  [[ $# -gt 0 ]] && shift
  d="$WORK/c$((++N))"
  mkdir -p "$d/bin"
  for t in ${tools//,/ }; do ln -s "$WORK/stub/tool" "$d/bin/$t"; done
  CALLS_FILE="$d/calls"
  : >"$CALLS_FILE"
  OUT="$(env -i HOME="$d" PATH="$d/bin:$WORK/base" CALLS="$CALLS_FILE" FAIL="$fail" PIP_JSON="$pip" \
    "$REAL_BASH" "$UPDATE" "$@" 2>&1)"
  RC=$?
  # Drop the colour codes so assertions read the text a user sees.
  OUT="$(printf '%s\n' "$OUT" | sed $'s/\x1b\\[[0-9;]*m//g')"
}
calls() { tr '\n' ';' <"$CALLS_FILE"; }
ALL="brew,apt,sudo,npm,cargo,cargo-install-update,rustup,pip3,chezmoi"

test_start "update_help_prints_usage_and_updates_nothing"
run_update "$ALL" -- --help
assert_equals "0:" "$RC:$(calls)" "--help exits 0 without running a package manager"
assert_contains "update --brew" "$OUT" "usage lists the options"

test_start "update_rejects_an_unknown_option"
run_update "$ALL" -- --dry-run
assert_equals "2:" "$RC:$(calls)" "an unknown option is an error, not a full update"
assert_contains "unknown option: --dry-run" "$OUT" "names the bad option"

test_start "update_runs_every_detected_manager_by_default"
run_update "$ALL" PIP_JSON='[{"name":"requests"},{"name":"black"}]'
assert_equals "0" "$RC" "succeeds"
assert_equals "brew update;brew upgrade;brew cleanup;sudo apt update;sudo apt upgrade -y;sudo apt autoremove -y;npm update -g;cargo install-update -a;rustup update stable;pip3 list --outdated --format=json;pip3 install -U requests;pip3 install -U black;chezmoi update --apply=false;" "$(calls)" "each manager, in order"
assert_contains "Update complete!" "$OUT" "final line"

test_start "update_runs_only_the_named_managers"
run_update "$ALL" -- --npm --brew
assert_equals "brew update;brew upgrade;brew cleanup;npm update -g;" "$(calls)" "no apt, cargo, pip or chezmoi"
run_update "$ALL" -- --brew --all
assert_contains "chezmoi update" "$(calls)" "--all after a flag restores everything"

test_start "update_skips_a_named_manager_that_is_missing"
run_update "" -- --brew --apt --npm --cargo --pip
assert_equals "0:" "$RC:$(calls)" "nothing to run"
for m in "Homebrew not installed" "APT not available" "NPM not installed" "Cargo not installed" "Pip not installed"; do
  assert_contains "Skipped: $m" "$OUT" "$m"
done
run_update ""
assert_equals "0" "$(printf '%s\n' "$OUT" | grep -c 'Skipped' || true)" "the default run stays quiet about missing managers"

test_start "update_explains_a_missing_cargo_update"
run_update "cargo,rustup" -- --cargo
assert_equals "rustup update stable;" "$(calls)" "no install-update without cargo-update"
assert_contains "cargo install cargo-update" "$OUT" "suggests installing it"

test_start "update_stops_when_a_package_manager_fails"
run_update "$ALL" FAIL=brew
assert_equals "1:brew update;" "$RC:$(calls)" "errexit stops at the failing command"
assert_equals "0" "$(printf '%s\n' "$OUT" | grep -c 'Update complete' || true)" "no completion line"

test_start "update_reports_a_failed_rustup"
run_update "cargo,cargo-install-update,rustup" FAIL=rustup -- --cargo
assert_equals "0" "$RC" "the run continues"
assert_contains "Warning: rustup update failed" "$OUT" "the failure is reported"
assert_equals "0" "$(printf '%s\n' "$OUT" | grep -c 'Done: Rust toolchain updated' || true)" "no success claim"

test_start "update_reports_failed_pip_packages"
run_update "pip3" PIP_JSON='[{"name":"requests"}]' FAIL=pip3 -- --pip
assert_equals "0" "$RC" "the run continues"
assert_contains "Warning: pip3 could not list outdated packages" "$OUT" "a failed listing is reported"
assert_equals "0" "$(printf '%s\n' "$OUT" | grep -c 'Done: Pip packages updated' || true)" "no success claim"

test_start "update_counts_pip_packages_that_fail_to_install"
run_update "pip3" PIP_JSON='[{"name":"requests"},{"name":"black"}]' FAIL="pip3 install" -- --pip
assert_equals "0" "$RC" "the run continues"
assert_equals "pip3 list --outdated --format=json;pip3 install -U requests;pip3 install -U black;" "$(calls)" "every package is still tried"
assert_contains "Warning: 2 pip package(s) failed to update" "$OUT" "failures are counted"
run_update "pip3" -- --pip
assert_equals "pip3 list --outdated --format=json;" "$(calls)" "nothing outdated, nothing installed"
assert_contains "Done: Pip packages updated" "$OUT" "an empty list is success"

test_start "update_skips_rustup_when_missing"
run_update "cargo,cargo-install-update" -- --cargo
assert_contains "Skipped: rustup not installed" "$OUT" "no toolchain update without rustup"

test_start "update_reports_a_failed_dotfiles_pull"
run_update "chezmoi" FAIL=chezmoi
assert_equals "0" "$RC" "the run continues"
assert_contains "Warning: chezmoi update failed" "$OUT" "the failure is reported"
assert_equals "0" "$(printf '%s\n' "$OUT" | grep -c 'Done: Dotfiles checked' || true)" "no success claim"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
