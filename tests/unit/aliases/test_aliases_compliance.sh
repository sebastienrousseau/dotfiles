#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ALIASES_DIR="$REPO_ROOT/defaults/.chezmoitemplates/aliases/compliance"

test_start "alias_dir_exists"
assert_dir_exists "$ALIASES_DIR" "aliases directory should exist"

test_start "alias_files_valid"
invalid=0
shopt -s nullglob
for f in "$ALIASES_DIR"/*.sh; do
  [[ -f "$f" ]] && ! bash -n "$f" 2>/dev/null && ((invalid++))
done
if [[ "$invalid" -eq 0 ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all valid"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $invalid invalid"
fi

test_start "alias_no_hardcoded_paths"
if grep -rqE '"/home/[a-z]+' "$ALIASES_DIR" 2>/dev/null; then
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

# audit_fn (dot-audit, aliases/compliance/compliance.aliases.sh) shows the
# logs dot actually writes, every domain's
# $XDG_STATE_HOME/dot/<domain>/log.jsonl (log.v1) merged in time order, and
# falls back to git history.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/state/dot/config" "$WORK/state/dot/theme" "$WORK/state/dotfiles" "$WORK/home/.local/share"
printf '{"schema":"cli/log.v1","time":"2026-01-02T03:04:05Z","event":"apply_completed"}\n' >"$WORK/state/dot/config/log.jsonl"
printf '{"schema":"cli/log.v1","time":"2026-01-01T00:00:00Z","event":"theme_set"}\n' >"$WORK/state/dot/theme/log.jsonl"
printf '[2026-01-02T03:04:05Z] [info] [t1] old format\n' >"$WORK/state/dotfiles/dot.log"
printf 'legacy line\n' >"$WORK/home/.local/share/dotfiles.log"
# audit_run: source the aliases and run audit_fn in the sandbox.
audit_run() {
  env -i ${BASH_ENV:+BASH_ENV="$BASH_ENV"} ${PS4:+PS4="$PS4"} \
    HOME="$WORK/home" XDG_STATE_HOME="$WORK/state" PATH="$PATH" \
    bash -c 'source "$1" && audit_fn' _ "$ALIASES_DIR/compliance.aliases.sh" 2>&1
}

test_start "audit_fn_shows_the_dot_logs"
out="$(audit_run)"
assert_contains "apply_completed" "$out" "the config log is shown"
assert_equals "theme_set apply_completed" "$(grep -o '"event":"[a-z_]*"' <<<"$out" | cut -d'"' -f4 | tr '\n' ' ' | sed 's/ $//')" \
  "every domain's log, oldest first"
assert_false '[[ "$out" == *"legacy line"* || "$out" == *"old format"* ]]' "logs dot no longer writes are not read"

test_start "audit_fn_falls_back_to_git_history"
rm -rf "$WORK/state/dot"
mkdir -p "$WORK/home/.dotfiles"
git -C "$WORK/home/.dotfiles" init -q
git -C "$WORK/home/.dotfiles" -c user.name=t -c user.email=t@example.invalid \
  -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q --allow-empty -m "fallback commit"
out="$(audit_run)"
assert_contains "fallback commit" "$out" "git log is shown without a dot log"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
