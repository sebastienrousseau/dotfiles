#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Fuzz test for scripts/dot/commands/init.sh::_init_resolve_url.
#
# Covers the URL-resolution logic that turns user input (bare name,
# owner/repo, or full URL) into a chezmoi-init clone URL. The R2
# round-2 audit hardened this against shell-metachar injection;
# this test enumerates ~50 representative inputs (clean + adversarial)
# to lock the contract in place.
#
# Behavior matrix:
#   ✓ accept   bare [A-Za-z0-9._-]+
#   ✓ accept   owner/repo where each segment matches [A-Za-z0-9._-]+
#   ✓ accept   https:// URLs as-is
#   ✓ accept   git@host:path SSH URLs as-is
#   ✗ refuse   http:// (no transit integrity)
#   ✗ refuse   any input containing ;, |, &, $, `, (, ), <, >, \, space, tab, newline
#
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

DOT_BIN="$REPO_ROOT/bin/dot"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

_init_accepts() {
  local label="$1" arg="$2"
  test_start "init_accepts_${label}"
  if bash "$DOT_BIN" init "$arg" --dry-run >/dev/null 2>&1; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: refused valid input '$arg'"
  fi
}

_init_refuses() {
  local label="$1" arg="$2"
  test_start "init_refuses_${label}"
  if bash "$DOT_BIN" init "$arg" --dry-run >/dev/null 2>&1; then
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: accepted adversarial input '$arg'"
  else
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  fi
}

# ─── Accept matrix — clean inputs in each shape ───
_init_accepts "bare_user_alpha"     "alice"
_init_accepts "bare_user_digits"    "user42"
_init_accepts "bare_user_dot"       "user.name"
_init_accepts "bare_user_dash"      "user-name"
_init_accepts "bare_user_under"     "user_name"
_init_accepts "owner_repo_simple"   "alice/cfg"
_init_accepts "owner_repo_dots"     "a.b/c.d"
_init_accepts "owner_repo_dashes"   "alpha-1/beta-2"
_init_accepts "https_github"        "https://github.com/alice/dotfiles.git"
_init_accepts "https_gitlab"        "https://gitlab.com/alice/dotfiles.git"
_init_accepts "https_codeberg"      "https://codeberg.org/alice/cfg.git"
_init_accepts "https_self_hosted"   "https://git.example.com/alice/cfg"
_init_accepts "ssh_github"          "git@github.com:alice/dotfiles.git"
_init_accepts "ssh_self_hosted"     "git@git.example.com:alice/cfg.git"

# ─── Refuse matrix — adversarial inputs that must be rejected ───
_init_refuses "plain_http"          "http://example.com/repo.git"
_init_refuses "ftp"                 "ftp://example.com/repo.git"
_init_refuses "file"                "file:///etc/passwd"
_init_refuses "shell_semi"          "alice;rm -rf /"
_init_refuses "shell_pipe"          "alice|cat"
_init_refuses "shell_amp"           "alice&background"
_init_refuses "shell_dollar"        "alice\$VAR"
# shellcheck disable=SC2016
# Single quotes are INTENTIONAL — the test injects the literal backtick
# string to verify it's rejected. Double quotes would execute `whoami`.
_init_refuses "shell_backtick"      'alice`whoami`'
_init_refuses "shell_paren"         "alice(payload)"
_init_refuses "shell_redirect_out"  "alice>file"
_init_refuses "shell_redirect_in"   "alice<file"
_init_refuses "shell_backslash"     "alice\\evil"
_init_refuses "shell_space"         "alice evil"
_init_refuses "shell_tab"           $'alice\tevil'
_init_refuses "shell_newline"       $'alice\nevil'
_init_refuses "ownerrepo_inject"    "alice;rm/cfg"
_init_refuses "ownerrepo_double"    "alice//cfg"
_init_refuses "ownerrepo_triple"    "a/b/c"
_init_refuses "empty"               ""
_init_refuses "only_slash"          "/"
_init_refuses "leading_slash"       "/alice"
_init_refuses "trailing_slash"      "alice/"
_init_refuses "path_traversal"      "../etc/passwd"
_init_refuses "absolute_path"       "/etc/passwd"

# Note: HTTPS URLs with embedded credentials (`https://user:pass@host/`)
# are accepted by the resolver because they match the full-URL
# case-arm. That's a deliberate trust decision — when a user
# passes an explicit URL we trust their intent. Tightening to
# refuse those would need a separate behavior-change PR.

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
