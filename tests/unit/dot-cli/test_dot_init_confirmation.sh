#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The trust prompt and end-of-options handling in cmd_init.
#
# `dot init` clones a stranger's repository and runs its scripts, so it asks
# for confirmation first — but only when stdin is a terminal. Under any test
# harness it is not, so neither the prompt nor the abort had ever run. Both
# are driven here through script(1), which gives the command a real pty.
#
# Nothing is cloned: chezmoi is a stub and CHEZMOI_SOURCE_DIR points into a
# temporary directory this suite owns.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

INIT_MODULE="$REPO_ROOT/scripts/dot/commands/init.sh"

WORK="$(mktemp -d -t dotinit.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$WORK"; cov_teardown_sandbox' EXIT

mkdir -p "$WORK/stubs" "$WORK/src"
dot_fixture_basebin "$WORK/base"
dot_fixture_stub "$WORK/stubs" chezmoi 0

# ── 1. End-of-options marker ───────────────────────────────────────────────
#
# Driven in-process: no terminal is needed for the option parser, and the
# module is sourced from its real path so the run is attributed to it.
(
  export CHEZMOI_SOURCE_DIR="$WORK/not-yet-cloned"
  export PATH="$WORK/stubs:$WORK/base"
  export DOTFILES_NONINTERACTIVE=1
  source "$INIT_MODULE"
  cmd_init alice -- --dry-run
) >"$WORK/endopts.out" 2>&1
IN_RC=$?

test_start "init_stops_parsing_at_a_double_dash"
assert_equals "0" "$IN_RC" "a trailing -- should be accepted, not rejected"
assert_contains "github.com/alice/dotfiles.git" "$(cat "$WORK/endopts.out")" \
  "the user argument before -- should still be resolved"

# ── 2. The trust prompt, on a real terminal ────────────────────────────────
TTY_FORM=""
printf '#!/bin/sh\n[ -t 0 ] && echo TTY_PROBE_OK\n' >"$WORK/tty-probe.sh"
chmod +x "$WORK/tty-probe.sh"
for _attempt in 1 2 3; do
  if script -qec "$WORK/tty-probe.sh" /dev/null </dev/null 2>/dev/null | tr -d '\r' |
    grep -q TTY_PROBE_OK; then
    TTY_FORM="util-linux"
    break
  fi
  if script -q /dev/null "$WORK/tty-probe.sh" </dev/null 2>/dev/null | tr -d '\r' |
    grep -q TTY_PROBE_OK; then
    TTY_FORM="bsd"
    break
  fi
done
unset _attempt

if [[ -z "$TTY_FORM" ]]; then
  echo "SKIP: script(1) cannot allocate a pty here; the prompt cannot be driven"
  print_summary
  exit 0
fi

cat >"$WORK/init-runner.sh" <<RUNNER
#!/usr/bin/env bash
set -uo pipefail
export CHEZMOI_SOURCE_DIR="$WORK/src"
export PATH="$WORK/stubs:$WORK/base"
export NO_COLOR=1 DOTFILES_SHOW_LOGO=0
unset DOTFILES_NONINTERACTIVE
# init.sh sets errexit when sourced, so the status has to be caught rather
# than read from \$? after the fact.
source "$INIT_MODULE"
rc=0
cmd_init alice --force || rc=\$?
printf 'INIT_RC=%s\n' "\$rc"
RUNNER
chmod +x "$WORK/init-runner.sh"

# init_on_tty <answer> — run cmd_init on a pty, feeding <answer> to the prompt.
INIT_OUT=""
init_on_tty() {
  local answer="$1" attempt
  for attempt in 1 2 3; do
    if [[ "$TTY_FORM" == "util-linux" ]]; then
      INIT_OUT="$({
        sleep 1
        printf '%s\n' "$answer"
        sleep 1
      } |
        script -qec "$WORK/init-runner.sh" /dev/null 2>&1 | tr -d '\r')"
    else
      INIT_OUT="$({
        sleep 1
        printf '%s\n' "$answer"
        sleep 1
      } |
        script -q /dev/null "$WORK/init-runner.sh" 2>&1 | tr -d '\r')"
    fi
    [[ -n "$INIT_OUT" ]] && break
  done
}

test_start "init_aborts_when_the_prompt_is_declined"
init_on_tty "n"
assert_contains "aborted by user" "$INIT_OUT" \
  "declining the trust prompt should abort the bootstrap"
assert_contains "INIT_RC=1" "$INIT_OUT" "and report a non-zero status"

test_start "init_proceeds_when_the_prompt_is_accepted"
init_on_tty "y"
assert_contains "INIT_RC=0" "$INIT_OUT" \
  "accepting the trust prompt should let the bootstrap run"
assert_contains "chezmoi init" "$INIT_OUT" \
  "and hand the resolved URL to chezmoi"

print_summary
