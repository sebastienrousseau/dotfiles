#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# install/migrate/migrate-v0_2-to-v0_2_503.sh end to end in a sandbox
# HOME, with a recording chezmoi stub. Asserts which paths it asks
# chezmoi to forget, what it prints, and the state it leaves behind.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

MIGRATE="$REPO_ROOT/install/migrate/migrate-v0_2-to-v0_2_503.sh"
REAL_BASH="$(command -v bash)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
cat >"$WORK/bin/chezmoi" <<'STUB'
#!/bin/sh
echo "chezmoi $*" >>"$CALLS"
case "$1" in
  source-path) [ -n "${SRC:-}" ] && echo "$SRC"; exit 0 ;;
  forget)
    case "$3" in *"${FAIL_FORGET:-@none@}") echo "forget error" >&2; exit 1 ;; esac
    echo "forgot $3"
    ;;
esac
exit 0
STUB
chmod +x "$WORK/bin/chezmoi"
for t in date mkdir; do ln -s "$(PATH=/usr/bin:/bin command -v "$t")" "$WORK/bin/$t"; done
N=0

# migrate "<setup words>" [FAIL_FORGET=suffix] -- [args...]: build a sandbox
# HOME from the setup words, run the migration, set OUT, RC, H and
# FORGETS (the paths chezmoi was asked to forget, relative to H).
migrate() {
  local setup="$1" fail="" src s
  shift
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    case "$1" in FAIL_FORGET=*) fail="${1#*=}" ;; esac
    shift
  done
  [[ $# -gt 0 ]] && shift
  H="$WORK/h$((++N))"
  mkdir -p "$H/src"
  src="$H/src"
  for s in $setup; do
    case "$s" in
      nosrc) src="" ;;
      prior) mkdir -p "$H/.local/bin" && : >"$H/.local/bin/dot" ;;
      bins) mkdir -p "$H/.local/bin" && : >"$H/.local/bin/dot" && : >"$H/.local/bin/dot-theme-sync" ;;
      binsrc) mkdir -p "$H/src/bin" && : >"$H/src/bin/dot" ;;
      man) mkdir -p "$H/.local/share/man/man1" && : >"$H/.local/share/man/man1/dot.1" ;;
      mansrc) mkdir -p "$H/src/share/man/man1" && : >"$H/src/share/man/man1/dot.1" ;;
      root) echo defaults >"$H/src/.chezmoiroot" ;;
      done) mkdir -p "$STATE" && : >"$STATE/.complete" ;;
    esac
  done
  : >"$H/calls"
  OUT="$(env -i HOME="$H" PATH="$WORK/bin" CALLS="$H/calls" SRC="$src" FAIL_FORGET="$fail" \
    "$REAL_BASH" "$MIGRATE" "$@" 2>&1)"
  RC=$?
  FORGETS="$(sed -n "s|^chezmoi forget --force $H/||p" "$H/calls" | tr '\n' ' ')"
}
# STATE is relative to the H of the call being set up.
state_dir() { printf '%s' "$H/.local/state/dotfiles/v0_2_503-migration"; }
completed() { if [[ -f "$(state_dir)/.complete" ]]; then echo yes; else echo no; fi; }

test_start "migrate_fresh_install_needs_nothing"
migrate "" -- -v
assert_equals "0:yes:" "$RC:$(completed):$FORGETS" "no prior dot: marked complete, nothing forgotten"
assert_contains "no prior install detected" "$OUT" "says why"

test_start "migrate_without_a_chezmoi_source_needs_nothing"
migrate "nosrc prior" -- -v
assert_equals "0:yes:" "$RC:$(completed):$FORGETS" "no source: marked complete"
assert_contains "chezmoi source not configured" "$OUT" "says why"

test_start "migrate_phase2_forgets_the_old_bin_entries"
migrate "bins binsrc" -- -v
assert_equals "0:yes" "$RC:$(completed)" "succeeds and records completion"
assert_equals ".local/bin/dot .local/bin/dot-theme-sync " "$FORGETS" "only paths that exist are forgotten"
assert_contains "forgot: $H/.local/bin/dot-theme-sync" "$OUT" "verbose names each path"
assert_contains "forgot $H/.local/bin/dot" "$(cat "$(state_dir)"/snapshot-*)" "chezmoi's output goes to the snapshot"

test_start "migrate_phase2_needs_bin_dot_in_the_source"
migrate "bins" -- -v
assert_equals "" "$FORGETS" "no source bin/dot, no phase 2"
assert_contains "no migration required" "$OUT" "nothing to do is reported"

test_start "migrate_dry_run_forgets_nothing_and_stays_repeatable"
migrate "bins binsrc man mansrc" -- --dry-run
assert_equals ":no" "$FORGETS:$(completed)" "no forgets, no state file"
assert_contains "[dry-run] would forget: $H/.local/share/man/man1/dot.1" "$OUT" "phase 3 is previewed"
assert_contains "[dry-run] would forget: $H/.local/bin/dot-theme-sync" "$OUT" "phase 2 is previewed"

test_start "migrate_phase3_forgets_the_man_page"
migrate "prior man mansrc"
assert_equals ".local/share/man/man1/dot.1 " "$FORGETS" "the man page is forgotten"
assert_contains "Phase 3" "$OUT" "phase announced"

test_start "migrate_reports_a_failed_forget"
migrate "bins binsrc" FAIL_FORGET=dot-theme-sync
assert_equals "0" "$RC" "a failed forget does not fail the migration"
assert_contains "WARN   forget failed: $H/.local/bin/dot-theme-sync" "$OUT" "the failure is reported"

test_start "migrate_phase4_notes_chezmoiroot"
migrate "prior root" -- -v
assert_contains "Phase 4: .chezmoiroot detected" "$OUT" "phase 4 announced"
assert_equals "0" "$(printf '%s\n' "$OUT" | grep -c 'no migration required' || true)" "phase 4 counts as work"

test_start "migrate_runs_once_unless_forced"
H="$WORK/h$((N + 1))"
STATE="$(state_dir)"
migrate "bins binsrc done"
assert_equals "0:" "$RC:$FORGETS" "a completed host is skipped"
H="$WORK/h$((N + 1))"
STATE="$(state_dir)"
migrate "bins binsrc done" -- --force
assert_equals ".local/bin/dot .local/bin/dot-theme-sync " "$FORGETS" "--force runs it again"

test_start "migrate_rejects_an_unknown_flag"
migrate "prior" -- --bogus
assert_equals "1" "$RC" "unknown flag fails"
assert_contains "unknown flag: --bogus" "$OUT" "names it"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
