#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Auto-generated exercise test for dot_local/bin/executable_git-ai-diff.
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

SCRIPT_FILE="$REPO_ROOT/defaults/dot_local/bin/executable_git-ai-diff"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "dot_local/bin/executable_git-ai-diff must exist"

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

test_start "git_ai_diff_deep_branches_execute"
diff_tmp="$DOTFILES_COV_TMPDIR/git-ai-diff-deep"
mkdir -p "$diff_tmp/bin" "$diff_tmp/work"
cat >"$diff_tmp/bin/git" <<'EOF_GIT'
#!/usr/bin/env bash
case "$*" in
  "diff --cached")
    [[ -n "${DOTFILES_FAKE_EMPTY_DIFF:-}" ]] && exit 0
    printf 'diff --git a/file.txt b/file.txt\n+new\n-old\n'
    ;;
  "diff --cached --stat")
    printf ' file.txt | 2 +-\n'
    ;;
  "diff "*"--stat")
    printf ' file.txt | 2 +-\n'
    ;;
  "diff "*)
    [[ -n "${DOTFILES_FAKE_EMPTY_DIFF:-}" ]] && exit 0
    printf 'diff --git a/file.txt b/file.txt\n+new\n-old\n'
    ;;
  *)
    printf 'git:%s\n' "$*"
    ;;
esac
EOF_GIT
for provider in claude aider agy sgpt ollama; do
  cat >"$diff_tmp/bin/$provider" <<'EOF_PROVIDER'
#!/usr/bin/env bash
case "$(basename "$0")" in
  claude) cat >/dev/null; printf 'claude review\n' ;;
  aider) printf 'aider review\n' ;;
  agy) cat >/dev/null; printf 'agy review\n' ;;
  sgpt) printf 'sgpt review\n' ;;
  ollama) cat >/dev/null; printf 'ollama review\n' ;;
esac
EOF_PROVIDER
  chmod +x "$diff_tmp/bin/$provider"
done
chmod +x "$diff_tmp/bin/git"
(
  set +e
  export PATH="$diff_tmp/bin:$PATH"
  cd "$diff_tmp/work" || exit 1
  bash "$SCRIPT_FILE" --help
  GIT_AI_PROVIDER=claude bash "$SCRIPT_FILE"
  bash "$SCRIPT_FILE" --provider aider HEAD~2
  bash "$SCRIPT_FILE" --provider agy --staged
  bash "$SCRIPT_FILE" --provider sgpt
  OLLAMA_MODEL=test-model bash "$SCRIPT_FILE" --provider ollama
  bash "$SCRIPT_FILE" --provider unknown
  DOTFILES_FAKE_EMPTY_DIFF=1 bash "$SCRIPT_FILE" --provider claude
  bash "$SCRIPT_FILE" --bad
) >/dev/null || true
assert_file_exists "$diff_tmp/bin/git" \
  "git-ai-diff deep branches used sandbox git shim"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
