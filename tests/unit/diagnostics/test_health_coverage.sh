#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# scripts/diagnostics/health.sh: the Zinit warning, which only fires when
# zsh is both the active and the configured default shell (the repo's own
# default is fish, so no other suite reaches it).
#
# The default shell is read relative to the script, so the run uses a
# mktemp tree whose scripts/diagnostics/health.sh is a symlink to the real
# script, invoked by a relative path (the coverage runner maps that onto
# the repository copy). lib/ is copied; defaults/.chezmoidata.toml is the
# fixture's own. HOME is a sandbox without Zinit; zsh is a stub.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d -t health-cov.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

T="$WORK/tree"
H="$WORK/home"
mkdir -p "$T/scripts/diagnostics" "$T/defaults" "$H" "$WORK/stubs"
cp -R "$REPO_ROOT/lib" "$T/lib"
ln -s "$REPO_ROOT/scripts/diagnostics/health.sh" "$T/scripts/diagnostics/health.sh"
printf 'default_shell = "zsh" # fixture\n' >"$T/defaults/.chezmoidata.toml"
printf '#!/bin/sh\nexit 0\n' >"$WORK/stubs/zsh"
chmod +x "$WORK/stubs/zsh"

test_start "health_warns_on_missing_zinit_for_a_zsh_default"
OUT="$(cd "$T" && env -u ZINIT_HOME HOME="$H" SHELL=/bin/zsh NO_COLOR=1 \
  XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
  XDG_STATE_HOME="$H/.local/state" XDG_CACHE_HOME="$H/.cache" \
  PATH="$WORK/stubs:$PATH" "${BASH:-bash}" scripts/diagnostics/health.sh 2>&1 </dev/null)" || true
zinit_line="$(printf '%s\n' "$OUT" | grep 'Zinit plugin manager' || true)"
assert_contains "Zinit plugin manager" "$zinit_line" "zinit check ran"
assert_contains "Not found" "$zinit_line" "missing zinit warned for a zsh default"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" == 0 ]]
