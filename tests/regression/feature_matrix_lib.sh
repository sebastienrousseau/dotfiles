#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash disable=SC1090,SC1091,SC2034
#
# feature_matrix_lib.sh — shared harness for the FEATURE-MATRIX regression
# suite (tests/regression/test_feature_matrix_*.sh).
#
# NOT a test file: the runner discovers `test_*.sh` only, so this name is
# deliberately outside that glob.
#
# Every row of docs/reference/FEATURE-MATRIX.md names a test function that
# lives in one of the test_feature_matrix_*.sh files and is verified to exist
# by scripts/qa/check-feature-matrix.sh. This library gives those functions a
# uniform way to run the real `dot` CLI against a sandboxed HOME/XDG and
# assert on exit code and output.
#
# Safety model
# ------------
#   * HOME and all four XDG dirs point inside a mktemp -d sandbox.
#   * $HOME/.dotfiles symlinks to the repo so source-dir probes resolve.
#   * A stub `chezmoi` (and other host-mutating binaries) shadow the real
#     ones on PATH, so nothing reaches the user's machine.
#   * No network: commands that would egress are recorded "unmeasurable" in
#     the matrix and covered by a --help smoke test instead.
#
# Three commands resolve their WRITE target from the location of the sourced
# library rather than from $HOME, so a sandboxed HOME does not protect the
# checkout from them:
#
#     dot profile set              -> <repo>/defaults/.chezmoidata.toml
#     dot fleet namespace set      -> <repo>/defaults/.chezmoidata.toml
#     dot fleet enforce set        -> <repo>/defaults/dot_config/.../agent-profiles.json
#     dot theme set / toggle / …   -> <repo>/defaults/.chezmoidata.toml (+ the OS appearance)
#     dot aliases cheatsheet       -> <repo>/docs/ALIASES_CHEATSHEET.md
#
# `fm_repo_copy` exists for the first three: it materialises a ~1 MB subset of
# the repo in the sandbox so the write lands there. `theme set` additionally
# drives the real OS appearance, so it stays a smoke row.

[[ "${_DOT_LIB_FEATURE_MATRIX_LOADED:-0}" == "1" ]] && return 0
_DOT_LIB_FEATURE_MATRIX_LOADED=1

FM_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$FM_LIB_DIR/../.." && pwd)}"
source "$FM_LIB_DIR/../framework/assertions.sh"

FM_DOT="$REPO_ROOT/bin/dot"

# Per-invocation results, refreshed by fm_run.
FM_RC=0
FM_OUT=""
FM_ERR=""

# Default wall-clock budget for one `dot` invocation. Generous: the reliability
# suite runs files in parallel on contended CI runners, and this is a hang
# guard, not a performance gate (tests/performance owns those).
FM_TIMEOUT="${FM_TIMEOUT:-120}"

# ---------------------------------------------------------------------------
# Sandbox
# ---------------------------------------------------------------------------

# fm_sandbox_setup — build the sandboxed HOME and export the environment.
# Call once near the top of a test file, with `trap fm_sandbox_teardown EXIT`.
fm_sandbox_setup() {
  FM_SANDBOX="$(mktemp -d -t dot-fm.XXXXXX)"
  export FM_SANDBOX

  mkdir -p \
    "$FM_SANDBOX/.config" \
    "$FM_SANDBOX/.local/share" \
    "$FM_SANDBOX/.local/state" \
    "$FM_SANDBOX/.cache" \
    "$FM_SANDBOX/bin" \
    "$FM_SANDBOX/work"

  ln -sfn "$REPO_ROOT" "$FM_SANDBOX/.dotfiles"

  export HOME="$FM_SANDBOX"
  export XDG_CONFIG_HOME="$FM_SANDBOX/.config"
  export XDG_DATA_HOME="$FM_SANDBOX/.local/share"
  export XDG_STATE_HOME="$FM_SANDBOX/.local/state"
  export XDG_CACHE_HOME="$FM_SANDBOX/.cache"
  export CHEZMOI_SOURCE_DIR="$REPO_ROOT"

  # Deterministic, non-interactive, machine-readable output.
  export NO_COLOR=1
  export DOTFILES_SHOW_LOGO=0
  export DOTFILES_NO_TUI=1
  export DOTFILES_NONINTERACTIVE=1
  export EDITOR=true
  export PAGER=cat
  # Keep git out of the developer's real config (dot keys sign-check reads it).
  export GIT_CONFIG_GLOBAL="$FM_SANDBOX/.gitconfig"
  export GIT_CONFIG_NOSYSTEM=1
  : >"$FM_SANDBOX/.gitconfig"

  # Host-mutating binaries are shadowed before anything else on PATH. `chezmoi`
  # is a no-op success so read-only chezmoi wrappers (status/diff/apply
  # --dry-run) exercise our code rather than the real tool.
  fm_stub chezmoi 'exit 0'
  fm_stub sudo 'exit 0'
  fm_stub osascript 'exit 0'
  fm_stub defaults 'exit 0'
  fm_stub gsettings 'exit 0'
  fm_stub systemctl 'exit 0'
  fm_stub gum 'exit 1'

  export PATH="$FM_SANDBOX/bin:$PATH"

  cd "$FM_SANDBOX/work" || return 1
}

fm_sandbox_teardown() {
  [[ -n "${FM_SANDBOX:-}" && -d "$FM_SANDBOX" ]] || return 0
  cd /tmp || true
  rm -rf "$FM_SANDBOX"
}

# fm_stub <name> <body> — put an executable shim named <name> at the front of
# PATH. The body is bash, and receives the real argv.
fm_stub() {
  local name="$1" body="$2"
  {
    printf '#!/usr/bin/env bash\n'
    printf '%s\n' "$body"
  } >"$FM_SANDBOX/bin/$name"
  chmod +x "$FM_SANDBOX/bin/$name"
}

# fm_repo_copy — materialise a minimal writable copy of the repo inside the
# sandbox and echo its path. For the handful of subcommands that write into
# the source tree (see the header). Only the subset those commands read is
# copied, so this stays about 1 MB rather than the whole checkout.
fm_repo_copy() {
  local dest="${1:-$FM_SANDBOX/repo}"
  [[ -d "$dest" ]] && {
    printf '%s\n' "$dest"
    return 0
  }
  mkdir -p "$dest/defaults/dot_config" "$dest/scripts"
  cp -R "$REPO_ROOT/bin" "$dest/bin"
  cp -R "$REPO_ROOT/lib" "$dest/lib"
  cp -R "$REPO_ROOT/scripts/dot" "$dest/scripts/dot"
  cp -R "$REPO_ROOT/scripts/lib" "$dest/scripts/lib" 2>/dev/null || true
  cp -R "$REPO_ROOT/defaults/dot_config/dotfiles" "$dest/defaults/dot_config/dotfiles"
  cp "$REPO_ROOT/defaults/.chezmoidata.toml" "$dest/defaults/.chezmoidata.toml"
  cp "$REPO_ROOT/.chezmoiroot" "$dest/.chezmoiroot"
  cp "$REPO_ROOT/CLAUDE.md" "$dest/CLAUDE.md" 2>/dev/null || true
  if [[ -d "$REPO_ROOT/.well-known" ]]; then
    cp -R "$REPO_ROOT/.well-known" "$dest/.well-known"
  fi
  printf '%s\n' "$dest"
}

# ---------------------------------------------------------------------------
# Invocation
# ---------------------------------------------------------------------------

# fm_run <args…> — run `dot <args…>` under the sandbox. Populates FM_RC,
# FM_OUT (stdout) and FM_ERR (stderr). Never fails the caller, so a test can
# assert on a non-zero exit code.
fm_run() {
  fm_run_bin "$FM_DOT" "$@"
}

# fm_run_bin <dot-path> <args…> — same, against a specific dispatcher (used
# with fm_repo_copy so writes land in the sandbox copy).
fm_run_bin() {
  local bin="$1"
  shift
  local out_file err_file
  out_file="$(mktemp)"
  err_file="$(mktemp)"
  FM_RC=0
  run_with_timeout "$FM_TIMEOUT" bash "$bin" "$@" \
    >"$out_file" 2>"$err_file" </dev/null || FM_RC=$?
  FM_OUT="$(cat "$out_file")"
  FM_ERR="$(cat "$err_file")"
  rm -f "$out_file" "$err_file"
  return 0
}

# ---------------------------------------------------------------------------
# Assertions
#
# Each helper starts its own test case, so one matrix row's function body
# reads as a short list of expectations.
# ---------------------------------------------------------------------------

fm_pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf '  \033[0;32m✓\033[0m %s%s\n' "$CURRENT_TEST" "${1:+: $1}"
}

fm_fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  \033[0;31m✗\033[0m %s: %s\n' "$CURRENT_TEST" "${1:-failed}"
  if [[ -n "${FM_ERR:-}" ]]; then
    printf '%s\n' "$FM_ERR" | head -3 | sed 's/^/        stderr: /'
  fi
  if [[ -n "${FM_OUT:-}" ]]; then
    printf '%s\n' "$FM_OUT" | head -3 | sed 's/^/        stdout: /'
  fi
}

# fm_expect_rc <expected> — assert the last fm_run exit code.
fm_expect_rc() {
  local want="$1"
  if [[ "$FM_RC" == "$want" ]]; then
    fm_pass "rc=$FM_RC"
  else
    fm_fail "expected rc=$want, got rc=$FM_RC"
  fi
}

# fm_expect_rc_in <code…> — assert the exit code is one of several. For
# commands whose result legitimately depends on the host (a scorecard that
# signals "not perfect" with rc=1, say).
fm_expect_rc_in() {
  local code
  for code in "$@"; do
    if [[ "$FM_RC" == "$code" ]]; then
      fm_pass "rc=$FM_RC"
      return 0
    fi
  done
  fm_fail "expected rc in [$*], got rc=$FM_RC"
}

# fm_expect_out <substring> — assert stdout contains a literal substring.
fm_expect_out() {
  if [[ "$FM_OUT" == *"$1"* ]]; then
    fm_pass
  else
    fm_fail "stdout does not contain '$1'"
  fi
}

# fm_expect_any <substring…> — assert stdout+stderr contains at least one of
# the given literals. Use when the wording differs by platform or tool
# availability but the command must still say *something* specific.
fm_expect_any() {
  local needle
  for needle in "$@"; do
    if [[ "$FM_OUT$FM_ERR" == *"$needle"* ]]; then
      fm_pass
      return 0
    fi
  done
  fm_fail "neither of [$*] found in output"
}

# fm_expect_err <substring> — assert stderr (or stdout, since the UI helpers
# write errors to both depending on the caller) contains a literal.
fm_expect_err() {
  if [[ "$FM_ERR$FM_OUT" == *"$1"* ]]; then
    fm_pass
  else
    fm_fail "no '$1' on stderr/stdout"
  fi
}

# fm_expect_out_matches <ere> — assert stdout matches an extended regex.
fm_expect_out_matches() {
  if printf '%s' "$FM_OUT" | grep -Eq "$1"; then
    fm_pass
  else
    fm_fail "stdout does not match /$1/"
  fi
}

# fm_expect_nonempty — assert the command printed something on stdout.
fm_expect_nonempty() {
  if [[ -n "${FM_OUT// /}" ]]; then
    fm_pass "$(printf '%s' "$FM_OUT" | wc -l | tr -d ' ') line(s)"
  else
    fm_fail "stdout was empty"
  fi
}

# fm_expect_json — assert stdout is a single valid JSON document. Skips (as a
# pass) when jq is unavailable, since that is a gap in the runner's toolbox
# rather than a regression in the CLI.
fm_expect_json() {
  if ! command -v jq >/dev/null 2>&1; then
    fm_pass "skipped — jq not installed"
    return 0
  fi
  if printf '%s' "$FM_OUT" | jq -e . >/dev/null 2>&1; then
    fm_pass "valid JSON"
  else
    fm_fail "stdout is not valid JSON"
  fi
}

# fm_expect_file <path> — assert a path exists (a command's write landed).
fm_expect_file() {
  if [[ -e "$1" ]]; then
    fm_pass
  else
    fm_fail "expected path to exist: $1"
  fi
}

# fm_expect_no_forbidden — assert stderr carries none of the breakage
# signatures the 2026-07 command audit turned up. Cheap to apply everywhere.
FM_FORBIDDEN=(
  "No such file or directory"
  "unbound variable"
  "command not found"
  "Could not open file"
  "syntax error"
)
fm_expect_no_forbidden() {
  local pattern
  for pattern in "${FM_FORBIDDEN[@]}"; do
    if [[ "$FM_ERR" == *"$pattern"* ]]; then
      # A genuinely absent third-party binary is the runner's toolbox, not a
      # regression: only fail when the named command actually resolves.
      if [[ "$pattern" == "command not found" ]]; then
        local missing
        missing="$(printf '%s' "$FM_ERR" |
          sed -nE 's/.*: ([A-Za-z0-9_.+-]+): command not found.*/\1/p' | head -1)"
        if [[ -n "$missing" ]] && ! command -v "$missing" >/dev/null 2>&1; then
          continue
        fi
      fi
      fm_fail "stderr contains '$pattern'"
      return 0
    fi
  done
  fm_pass
}

# ---------------------------------------------------------------------------
# Smoke coverage for rows the matrix records as unmeasurable
# ---------------------------------------------------------------------------

# fm_smoke <cmd…> — the integration-smoke contract every "unmeasurable" row
# still has to satisfy: `dot <cmd> --help` exits 0 and prints usage for the
# right command, WITHOUT performing the command's real (destructive, network,
# or interactive) work. This is the universal --help intercept in bin/dot, so
# it is safe for every command including `dot uninstall` and `dot chaos`.
fm_smoke() {
  local label
  label="$(printf '%s' "$*" | tr ' /-' '___')"
  test_start "fm_smoke_help_${label}"
  fm_run "$@" --help
  if [[ "$FM_RC" -ne 0 ]]; then
    fm_fail "dot $* --help exited $FM_RC"
    return 0
  fi
  if [[ -z "${FM_OUT// /}" ]]; then
    fm_fail "dot $* --help printed nothing"
    return 0
  fi
  # The help renderer prints "dot <command>" as its heading; the first word of
  # the argv is the command whose help must come back.
  if [[ "$FM_OUT" != *"$1"* ]]; then
    fm_fail "help output does not mention '$1'"
    return 0
  fi
  fm_pass "help ok"
}

# fm_finish — print the machine-readable RESULTS: line the runner parses and
# exit non-zero if anything failed.
fm_finish() {
  echo ""
  echo "  Tests: $TESTS_RUN  Passed: $TESTS_PASSED  Failed: $TESTS_FAILED"
  printf 'RESULTS:%d:%d:%d\n' \
    "$((TESTS_PASSED + TESTS_FAILED))" "$TESTS_PASSED" "$TESTS_FAILED"
  [[ "$TESTS_FAILED" -eq 0 ]]
}
