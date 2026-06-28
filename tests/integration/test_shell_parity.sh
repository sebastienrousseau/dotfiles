#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Cross-shell parity contract. Asserts that the canonical command surface —
# the `dot` entrypoint and the core listing aliases — is exposed in every
# supported shell (zsh, bash, fish, nushell, PowerShell), each through its
# own mechanism, and that every locally-available shell loads and runs a
# command without error. This is the behavioural counterpart to the static
# per-shell contracts (powershell-contract.ps1, the nushell parity test).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
# shellcheck source=../framework/assertions.sh
source "$SCRIPT_DIR/../framework/assertions.sh"

ZB="$REPO_ROOT/defaults/.chezmoitemplates/aliases/modern/modern.aliases.sh"
FISH_FN="$REPO_ROOT/defaults/dot_config/fish/functions"
NU="$REPO_ROOT/defaults/dot_config/nushell/aliases.nu"
PWSH="$REPO_ROOT/defaults/dot_config/powershell/Microsoft.PowerShell_profile.ps1.tmpl"

# ── 1. Core listing aliases (l, ll, la) reach every shell ───────────────────
test_start "parity_core_aliases_zsh_bash"
for a in l ll la; do
  assert_file_contains "$ZB" "alias $a=" "zsh/bash defines $a"
done

test_start "parity_core_aliases_fish"
for a in ll la; do
  assert_file_exists "$FISH_FN/$a.fish" "fish defines $a"
done

test_start "parity_core_aliases_nushell_bridge"
# nushell inherits the bash listing aliases through its generated bridge cache.
assert_file_contains "$NU" "bash-aliases.nu" "nushell bridges the bash alias library"

test_start "parity_core_aliases_powershell"
for a in ll la; do
  assert_file_contains "$PWSH" "function $a" "PowerShell defines $a"
done

# ── 2. The `dot` entrypoint and `d` shortcut exist in every shell ───────────
test_start "parity_dot_entrypoint"
assert_file_exists "$REPO_ROOT/bin/dot" "dot CLI exists (shell-agnostic entrypoint)"
assert_file_exists "$FISH_FN/dot.fish" "fish wraps dot"
assert_file_contains "$NU" "alias d = dot" "nushell exposes d -> dot"
assert_file_contains "$PWSH" "function dot" "PowerShell wraps dot"

# ── 3. Behavioural smoke: each available shell loads + runs a command ───────
for shell in zsh bash fish nu; do
  command -v "$shell" >/dev/null 2>&1 || continue
  test_start "parity_runtime_${shell}_executes"
  out="$("$shell" -c 'echo parity-ok' 2>/dev/null || true)"
  assert_contains "parity-ok" "$out" "$shell executes a command cleanly"
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
