#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The terminal-only half of lib/dot/utils.sh's banner.
#
# ui_logo_once and dot_ui_command_banner both return early unless stdout is a
# terminal, so under any ordinary test harness — and under the coverage
# runner, which hands every test /dev/null for stdout — the product banner,
# the once-per-process guard and the whole version/command/summary block are
# unreachable. The only way to reach them is to give the command a real pty,
# which is what script(1) is for.
#
# script(1) has two incompatible calling conventions (util-linux takes -c with
# the command as a string; the BSD one takes the command as argv after the
# typescript file), so both are probed and the suite skips cleanly if neither
# answers.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

cov_setup_sandbox
trap cov_teardown_sandbox EXIT

FX="$(dot_fixture_new utils-tty)"
mkdir -p "$FX/home" "$FX/stubs"
dot_fixture_basebin "$FX/basebin"
dot_fixture_stub "$FX/stubs" chezmoi 0

# The module needs a package.json to report a version, and the banner is what
# reads it.
printf '{\n  "version": "9.8.7"\n}\n' >"$FX/package.json"

# Which spelling of script(1), if any, this host understands — decided by
# running a probe that reports whether its stdout really is a terminal, not
# merely by whether the invocation exits 0. Allocating a pty can also fail
# transiently on a loaded machine, so the probe is retried before the suite
# gives up.
TTY_FORM=""
printf '#!/bin/sh\n[ -t 1 ] && echo TTY_PROBE_OK\n' >"$FX/tty-probe.sh"
chmod +x "$FX/tty-probe.sh"
for _attempt in 1 2 3; do
  if script -qec "$FX/tty-probe.sh" /dev/null 2>/dev/null | tr -d '\r' |
    grep -q TTY_PROBE_OK; then
    TTY_FORM="util-linux"
    break
  fi
  if script -q /dev/null "$FX/tty-probe.sh" 2>/dev/null | tr -d '\r' |
    grep -q TTY_PROBE_OK; then
    TTY_FORM="bsd"
    break
  fi
done
unset _attempt

if [[ -z "$TTY_FORM" ]]; then
  echo "SKIP: script(1) cannot allocate a pty here"
  echo "RESULTS:0:0:0"
  exit 0
fi

# tty_run <extra-env-assignments...> — run `core.sh status` on a pty and
# capture what the banner printed. The command is staged as a small runner
# script so neither script(1) convention has to quote an environment.
TTY_OUT=""
tty_run() {
  local runner="$FX/run-on-tty.sh"
  {
    printf '#!/bin/sh\n'
    printf 'cd "%s" || exit 1\n' "$FX"
    printf 'export HOME="%s/home" PATH="%s/stubs:%s/basebin"\n' "$FX" "$FX" "$FX"
    printf 'export NO_COLOR=1 DOTFILES_SHOW_LOGO=1\n'
    local assignment
    for assignment in "$@"; do
      printf 'export %s\n' "$assignment"
    done
    printf 'exec "%s" scripts/dot/commands/core.sh status\n' "${BASH:-bash}"
  } >"$runner"
  chmod +x "$runner"
  # Retried for the same reason the probe is: pty allocation is the one part
  # of this that can fail for reasons having nothing to do with the code
  # under test.
  local attempt
  for attempt in 1 2 3; do
    if [[ "$TTY_FORM" == "util-linux" ]]; then
      TTY_OUT="$(script -qec "$runner" /dev/null 2>&1 | tr -d '\r')"
    else
      TTY_OUT="$(script -q /dev/null "$runner" 2>&1 | tr -d '\r')"
    fi
    [[ -n "$TTY_OUT" ]] && break
  done
}

# ── 1. On a terminal the banner block runs ─────────────────────────────────
test_start "utils_banner_prints_the_version_on_a_terminal"
tty_run
assert_contains "9.8.7" "$TTY_OUT" \
  "the banner should report the version read from package.json"

test_start "utils_banner_names_the_command"
assert_contains "status" "$TTY_OUT" "the banner should name the command it fronts"

test_start "utils_banner_prints_a_summary"
assert_contains "drift" "$TTY_OUT" \
  "the banner should carry the command's one-line summary"

# ── 2. The logo prints once per process, not once per banner ───────────────
test_start "utils_logo_is_suppressed_once_printed"
tty_run "DOTFILES_LOGO_PRINTED=1"
assert_contains "9.8.7" "$TTY_OUT" \
  "the rest of the banner should still print when the logo is suppressed"

# ── 3. Opting out of the logo skips the banner entirely ────────────────────
test_start "utils_banner_respects_the_logo_opt_out"
tty_run "DOTFILES_SHOW_LOGO=0"
assert_contains "chezmoi status" "$TTY_OUT" \
  "the command itself should still run with the banner opted out"
assert_false "[[ \"\$TTY_OUT\" == *'9.8.7'* ]]" \
  "DOTFILES_SHOW_LOGO=0 should suppress the whole banner, terminal or not"

print_summary
