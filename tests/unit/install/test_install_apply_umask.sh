#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# install.sh runs under umask 077 for the files it writes itself, but
# chezmoi apply must run under the caller's umask: chezmoi derives each
# target's mode from the umask, so an apply under 077 deployed every file
# 0600 and every directory 0700, and the first `chezmoi verify` (dot
# doctor's "chezmoi state") in a normal shell reported the whole tree as
# drifted. Files marked private_ in the source stay 0600 either way.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/stubs"
# chezmoi records the umask it was started with.
printf '#!/bin/sh\numask >"%s/apply-umask"\n' "$SANDBOX" >"$SANDBOX/stubs/chezmoi"
chmod +x "$SANDBOX/stubs/chezmoi"

read -r -d '' CASE <<'EOF'
umask "$CALLER"
source "$INSTALLER" >/dev/null 2>&1
seed_git_identity() { :; }
echo "installer umask $(umask)"
apply_source 0
EOF

# run_apply CALLER_UMASK: apply_source after install.sh was sourced from a
# shell with that umask; prints the umasks seen.
run_apply() {
  rm -f "$SANDBOX/apply-umask"
  env -i HOME="$SANDBOX" PATH="$SANDBOX/stubs:/usr/bin:/bin" CALLER="$1" \
    INSTALLER="$REPO_ROOT/install.sh" "$BASH" --norc --noprofile -c "$CASE" 2>&1
  echo "apply umask $(cat "$SANDBOX/apply-umask" 2>/dev/null)"
}

test_start "apply_runs_under_the_callers_umask"
out="$(run_apply 0022)"
assert_contains "installer umask 0077" "$out" "the installer itself keeps 077"
assert_contains "apply umask 0022" "$out" "chezmoi apply runs under the caller's 022"

test_start "apply_follows_a_stricter_caller"
out="$(run_apply 0027)"
assert_contains "apply umask 0027" "$out" "a caller's 027 is kept, not widened"

print_summary
