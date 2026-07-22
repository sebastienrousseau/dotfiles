#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Auto-generated exercise test for dot_local/bin/executable_gl.
# Slice 3 of #883: backfill coverage by running each managed script
# through safe-mode entry points (--help / no-arg / invalid flag).
# Edit-by-hand to add behavioral assertions; the auto-shell will leave
# this file alone if `# AUTO-GENERATED: false` appears in the first
# 10 lines.
#
# AUTO-GENERATED: true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/defaults/dot_local/bin/executable_gl"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "dot_local/bin/executable_gl must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

cov_exercise_script "$SCRIPT_FILE"
cov_exercise_functions_file "$SCRIPT_FILE"

test_start "gl_deep_branches_execute"
gl_tmp="$DOTFILES_COV_TMPDIR/gl-deep"
mkdir -p "$gl_tmp/bin" "$gl_tmp/work"
cat >"$gl_tmp/bin/git" <<'EOF_GIT'
#!/usr/bin/env bash
case "$*" in
  "rev-parse --is-inside-work-tree")
    exit 0
    ;;
  "branch --show-current")
    printf 'main\n'
    ;;
  "config --get branch.main.remote")
    printf 'origin\n'
    ;;
  "remote get-url origin")
    printf 'git@github.com:owner/repo.git\n'
    ;;
  "log "*)
    printf '1700000000 abc123 2026-01-01 > subject\n'
    ;;
  "show "*)
    printf 'diff --git a/file b/file\n+new\n'
    ;;
  *)
    printf 'git:%s\n' "$*"
    ;;
esac
EOF_GIT
cat >"$gl_tmp/bin/fzf" <<'EOF_FZF'
#!/usr/bin/env bash
printf 'abc123 subject\n'
EOF_FZF
cat >"$gl_tmp/bin/delta" <<'EOF_DELTA'
#!/usr/bin/env bash
cat >/dev/null
EOF_DELTA
cat >"$gl_tmp/bin/open" <<'EOF_OPEN'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${DOTFILES_GL_OPEN_LOG:?}"
EOF_OPEN
cat >"$gl_tmp/bin/xdg-open" <<'EOF_XDG'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${DOTFILES_GL_OPEN_LOG:?}"
EOF_XDG
cat >"$gl_tmp/bin/cb" <<'EOF_CB'
#!/usr/bin/env bash
cat >/dev/null
EOF_CB
chmod +x "$gl_tmp/bin/git" "$gl_tmp/bin/fzf" "$gl_tmp/bin/delta" \
  "$gl_tmp/bin/open" "$gl_tmp/bin/xdg-open" "$gl_tmp/bin/cb"
(
  set +e
  export PATH="$gl_tmp/bin:$PATH"
  export DOTFILES_GL_OPEN_LOG="$gl_tmp/open.log"
  cd "$gl_tmp/work" || exit 1
  bash "$SCRIPT_FILE"
  bash "$SCRIPT_FILE" --side --max-count=5
  # shellcheck disable=SC1090
  source "$SCRIPT_FILE"
  open_commit_url "abc123"
  open_commit_url ""
) >/dev/null || true
assert_file_exists "$gl_tmp/open.log" \
  "gl deep branches opened sandbox commit URL"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
