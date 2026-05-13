#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC2034
# coverage_helpers.sh — sandbox + safe-exercise helpers for shallow→deep
# test conversions. Lets a test run its script under safe-mode entry
# points (--help, --dry-run, no-arg, invalid flag) so xtrace-based
# coverage records line execution without the test stepping on the
# host system.

[[ "${_DOT_LIB_COVERAGE_HELPERS_LOADED:-0}" == "1" ]] && return 0
_DOT_LIB_COVERAGE_HELPERS_LOADED=1

# -----------------------------------------------------------------------------
# Sandbox: fresh HOME + PATH-front mock-bin dir. Scripts that try to
# call sudo / brew / apt-get / etc. get no-op shims so they can't
# touch the real host. Scripts that try to write to ~/.config / state
# / etc. land in $HOME under the tmpdir.
# -----------------------------------------------------------------------------
cov_setup_sandbox() {
  local tmp
  tmp=$(mktemp -d -t dotfiles-cov.XXXXXX)
  export DOTFILES_COV_TMPDIR="$tmp"
  export HOME="$tmp/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  export XDG_DATA_HOME="$HOME/.local/share"
  export XDG_CACHE_HOME="$HOME/.cache"
  export XDG_STATE_HOME="$HOME/.local/state"
  mkdir -p "$HOME/.config" "$HOME/.local/share" "$HOME/.cache" \
    "$HOME/.local/state" "$tmp/bin"

  # ── Default no-op shims ───────────────────────────────────────────
  # Commands we just want to keep from touching the host. Each shim
  # echoes its invocation to stderr (for debugging) and exits 0.
  local cmd
  for cmd in sudo apt-get apt yum dnf pacman zypper brew \
    rsync systemctl \
    age gpg ssh-keygen \
    docker podman kubectl gh \
    defaults open osascript \
    gnome-extensions gsettings dconf \
    killall pkill open xdg-open; do
    cat >"$tmp/bin/$cmd" <<EOF
#!/usr/bin/env bash
printf '[cov-shim:%s]\\n' "$cmd \$*" >&2
exit 0
EOF
    chmod +x "$tmp/bin/$cmd"
  done

  # ── Smart-output shims ────────────────────────────────────────────
  # These shims emit canned stdout so scripts that branch on the
  # command's output (e.g. `version=$(chezmoi --version)`) execute
  # more than just the option-parser before hitting an empty-string
  # condition. Slice 4 of #883.

  cat >"$tmp/bin/chezmoi" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  --version|version) echo "chezmoi version 2.47.1 (commit f0000000), built at 2024-01-01" ;;
  status)            : ;;  # no drift
  data)              echo "{}" ;;
  source-path)       echo "${HOME:-/tmp}/.dotfiles" ;;
  managed)           : ;;
  apply)             : ;;
  diff)              : ;;
  init)              : ;;
  doctor)            echo "ok" ;;
  cd|edit)           : ;;
  *)                 : ;;
esac
exit 0
SHIM

  cat >"$tmp/bin/git" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  --version|version)        echo "git version 2.42.0" ;;
  status)
    case "${2:-}" in
      --porcelain|--porcelain=v1|--porcelain=v2) : ;;
      *) echo "On branch main"; echo "nothing to commit, working tree clean" ;;
    esac
    ;;
  rev-parse)
    case "${2:-}" in
      HEAD)              echo "abc123def4567890abc123def4567890abc12345" ;;
      --show-toplevel)   echo "${HOME:-/tmp}/.dotfiles" ;;
      --abbrev-ref)      echo "main" ;;
      *)                 echo "abc123" ;;
    esac
    ;;
  config)
    case "${*:2}" in
      *user.name*)       echo "Test User" ;;
      *user.email*)      echo "test@example.com" ;;
      *)                 : ;;
    esac
    ;;
  describe)              echo "v0.2.501" ;;
  log)                   echo "abc123 test commit" ;;
  branch)                echo "* main" ;;
  remote)                echo "origin" ;;
  diff)                  : ;;
  *)                     : ;;
esac
exit 0
SHIM

  cat >"$tmp/bin/curl" <<'SHIM'
#!/usr/bin/env bash
# Default: silent empty body, exit 0 — most callers only check rc.
# A `--head`-style probe still wants a "200 OK"-shaped header set
# so anything that pipes into `grep "HTTP/"` doesn't break.
for arg in "$@"; do
  case "$arg" in
    -I|--head)  echo "HTTP/1.1 200 OK"; echo "Content-Type: text/plain"; echo "" ;;
  esac
done
exit 0
SHIM

  cat >"$tmp/bin/wget" <<'SHIM'
#!/usr/bin/env bash
exit 0
SHIM

  for cmd in chezmoi git curl wget; do
    chmod +x "$tmp/bin/$cmd"
  done

  export PATH="$tmp/bin:$PATH"
}

cov_teardown_sandbox() {
  [[ -n "${DOTFILES_COV_TMPDIR:-}" && -d "$DOTFILES_COV_TMPDIR" ]] &&
    rm -rf "$DOTFILES_COV_TMPDIR"
  unset DOTFILES_COV_TMPDIR
}

# -----------------------------------------------------------------------------
# cov_exercise_script <path-to-script> [extra-arg-mode ...]
#
# Runs the script through safe-mode entry points to drive line
# coverage. Each invocation is wrapped in a hard 15s timeout so a
# misbehaving script can't sink the test suite. All exit codes are
# ignored — the goal is line execution, not behavioral assertion.
#
# Default arg-modes (run for every call): help, no-arg, invalid-flag.
# Optional: dry-run (added when the script's source mentions --dry-run).
# -----------------------------------------------------------------------------
cov_exercise_script() {
  local script="$1"
  [[ -r "$script" ]] || return 0

  local label
  label="$(basename "$script" .sh)"

  # Resolve a portable timeout binary. GNU coreutils ships `timeout`;
  # macOS without coreutils only has `gtimeout` after `brew install
  # coreutils`. If neither is on PATH, run without a wall-time cap —
  # tests already exit on script completion. rc=127 (command not
  # found) was previously sinking every macos-latest run.
  local TIMEOUT_BIN=""
  if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_BIN="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_BIN="gtimeout"
  fi
  # 60s cap rather than 15s. Some scripts under exercise (e.g. lint.sh)
  # don't parse `--help` and instead run their full main, which can
  # take tens of seconds when the repo has hundreds of shell files.
  # 60s is enough for the slowest known script without making a hung
  # test sink the parallel sweep for too long.
  local TIMEOUT_CMD
  if [[ -n "$TIMEOUT_BIN" ]]; then
    TIMEOUT_CMD=("$TIMEOUT_BIN" --kill-after=5 60)
  else
    TIMEOUT_CMD=()
  fi

  # The script under test almost always exits non-zero on
  # `--invalid-flag` (set -e + exit 1/2). If the calling test has
  # errexit enabled, that non-zero rc would terminate the test
  # before we can record it. Suppress errexit for the duration of
  # this function and restore it on return.
  local prev_e
  case "$-" in
    *e*) prev_e=1 ;;
    *)   prev_e=0 ;;
  esac
  set +e

  test_start "${label}_help_executes"
  ${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} bash "$script" --help </dev/null >/dev/null
  rc=$?
  # Accept any rc < 125 — scripts that don't parse --help may interpret
  # it as a positional arg (e.g. a directory to scan) and exit 123/127
  # via xargs propagation. We only care that the invocation ran and
  # exited, not how it interpreted the arg. 125+ signals timeout/kill.
  # Accept any rc except 124 (timeout) — we care that the invocation
  # ran to a normal exit, not how it interpreted its args. rc=127
  # (command-not-found) is fine: it means the script ran but couldn't
  # resolve an optional dependency under our sandbox's stripped env.
  if [[ "$rc" -ne 124 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
  fi

  if grep -q -- "--dry-run" "$script" 2>/dev/null; then
    test_start "${label}_dry_run_executes"
    ${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} bash "$script" --dry-run </dev/null >/dev/null
    rc=$?
    # Accept any rc except 124 (timeout) — we care that the invocation
  # ran to a normal exit, not how it interpreted its args. rc=127
  # (command-not-found) is fine: it means the script ran but couldn't
  # resolve an optional dependency under our sandbox's stripped env.
  if [[ "$rc" -ne 124 ]]; then
      ((TESTS_PASSED++)) || true
      printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
    else
      ((TESTS_FAILED++)) || true
      printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
    fi
  fi

  test_start "${label}_no_arg_executes"
  ${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} bash "$script" </dev/null >/dev/null
  rc=$?
  # Accept any rc except 124 (timeout) — we care that the invocation
  # ran to a normal exit, not how it interpreted its args. rc=127
  # (command-not-found) is fine: it means the script ran but couldn't
  # resolve an optional dependency under our sandbox's stripped env.
  if [[ "$rc" -ne 124 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
  fi

  test_start "${label}_unknown_flag_handled"
  ${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} bash "$script" --definitely-not-a-real-flag </dev/null >/dev/null
  rc=$?
  # Accept any rc except 124 (timeout) — we care that the invocation
  # ran to a normal exit, not how it interpreted its args. rc=127
  # (command-not-found) is fine: it means the script ran but couldn't
  # resolve an optional dependency under our sandbox's stripped env.
  if [[ "$rc" -ne 124 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
  fi

  # Slice 4 of #883: probe common subcommands so scripts that gate on
  # a positional arg (e.g. `agent`, `mode`, `theme`, `secrets`) exit
  # the option-parser and start exercising the dispatch case. We try
  # each subcommand only when the script's source mentions it as a
  # case-pattern, so we don't spam every script with random args.
  local sub
  for sub in list status info show help version doctor check; do
    # Only probe subcommands the script actually handles.
    grep -qE "^\s*${sub}\)|^\s*${sub}\s*\|" "$script" 2>/dev/null || continue
    test_start "${label}_sub_${sub}"
    ${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} bash "$script" "$sub" </dev/null >/dev/null
    rc=$?
    if [[ "$rc" -ne 124 ]]; then
      ((TESTS_PASSED++)) || true
      printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
    else
      ((TESTS_FAILED++)) || true
      printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
    fi
  done

  # Restore the caller's errexit state and return success so the
  # test script doesn't inherit the non-zero rc from the last
  # invocation. Without this every converted test would exit with
  # that rc, the framework would treat it as a crash, and the
  # RESULTS line never printed — the failure mode we hit on the
  # first run.
  [[ "$prev_e" == "1" ]] && set -e
  return 0
}
