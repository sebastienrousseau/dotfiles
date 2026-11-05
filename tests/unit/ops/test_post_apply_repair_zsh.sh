#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# zsh resolution in scripts/ops/post-apply-repair.sh.
#
# resolve_zsh_bin has three answers — an explicit DOTFILES_ZSH_BIN, whatever
# is on the PATH, and nothing — and only the first had ever been exercised,
# because the function is reached only once ~/.local/bin/dot exists. Every
# case here stages its own HOME with that binary in it and decides, through
# the PATH, whether a zsh exists at all.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

REPAIR="$REPO_ROOT/scripts/ops/post-apply-repair.sh"

WORK="$(mktemp -d -t postapply.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$WORK"; cov_teardown_sandbox' EXIT

mkdir -p "$WORK/home/.local/bin" "$WORK/stubs"
dot_fixture_basebin "$WORK/base"
printf '#!/bin/sh\nexit 0\n' >"$WORK/home/.local/bin/dot"
chmod +x "$WORK/home/.local/bin/dot"

PA_OUT=""
PA_RC=0
pa_run() {
  PA_RC=0
  PA_OUT="$(
    HOME="$WORK/home" PATH="$WORK/stubs:$WORK/base" NO_COLOR=1 \
      "${BASH:-bash}" "$REPAIR" 2>&1 </dev/null
  )" || PA_RC=$?
}

# ── 1. No zsh anywhere ─────────────────────────────────────────────────────
test_start "post_apply_repair_skips_validation_without_zsh"
pa_run
assert_equals "0" "$PA_RC" "a host with no zsh should still exit 0"
assert_contains "zsh not available" "$PA_OUT" \
  "the skipped validation should say why it was skipped"

# ── 2. zsh discovered on the PATH ──────────────────────────────────────────
#
# The stub answers the `alias dot` / `whence -p dot` probe with the path the
# script expects, so the resolution is reported as correct.
test_start "post_apply_repair_finds_zsh_on_the_path"
cat >"$WORK/stubs/zsh" <<STUB
#!/bin/sh
printf '\n%s\n' "$WORK/home/.local/bin/dot"
exit 0
STUB
chmod +x "$WORK/stubs/zsh"
pa_run
assert_equals "0" "$PA_RC" "a host with zsh should exit 0"
assert_contains "dot CLI resolution" "$PA_OUT" \
  "the resolution result should be reported"

# ── 3. An explicit override wins over the PATH ─────────────────────────────
test_start "post_apply_repair_honours_an_explicit_zsh"
cat >"$WORK/stubs/other-zsh" <<STUB
#!/bin/sh
printf '\n%s\n' "$WORK/home/.local/bin/dot"
exit 0
STUB
chmod +x "$WORK/stubs/other-zsh"
PA_RC=0
PA_OUT="$(
  HOME="$WORK/home" PATH="$WORK/stubs:$WORK/base" NO_COLOR=1 \
    DOTFILES_ZSH_BIN="$WORK/stubs/other-zsh" \
    "${BASH:-bash}" "$REPAIR" 2>&1 </dev/null
)" || PA_RC=$?
assert_equals "0" "$PA_RC" "an explicit zsh should exit 0"
assert_contains "dot CLI resolution" "$PA_OUT" \
  "the explicit interpreter should still produce a resolution result"

# ── 3b. A login shell that prints a banner ─────────────────────────────────
#
# `zsh -lic` runs the user's startup files, which may print anything before
# the probe's two lines. Picking the first and last line through
# `printf | head -n 1` under pipefail died with "printf: write error: Broken
# pipe" (exit 141) once the output outgrew what head reads before it exits:
# certain here, a timing race even with two lines (a CI flake, 2026-11-04).
test_start "post_apply_repair_survives_a_chatty_login_shell"
cat >"$WORK/stubs/zsh" <<STUB
#!/bin/sh
i=0
while [ \$i -lt 20000 ]; do
  echo "Welcome to the banner, line \$i"
  i=\$((i + 1))
done
printf '%s\n' "$WORK/home/.local/bin/dot"
exit 0
STUB
chmod +x "$WORK/stubs/zsh"
pa_run
assert_equals "0" "$PA_RC" "a banner before the probe output should not abort the checks"
assert_contains "dot CLI resolution" "$PA_OUT" \
  "the last line still decides the resolution"

# ── 4. No dot binary at all ────────────────────────────────────────────────
test_start "post_apply_repair_reports_a_missing_dot_binary"
rm -f "$WORK/home/.local/bin/dot"
pa_run
assert_contains "missing executable" "$PA_OUT" \
  "a missing dot binary should be reported before anything else is tried"

print_summary
