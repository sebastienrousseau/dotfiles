#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Auto-generated function-exercise test for scripts/dot/commands/core.sh.
# AUTO-GENERATED: true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/dot/commands/core.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "scripts/dot/commands/core.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "core_deep_branches_execute"
core_tmp="$DOTFILES_COV_TMPDIR/core-deep"
mkdir -p "$core_tmp/repo/scripts/ops" \
  "$core_tmp/repo/dot_local/bin" \
  "$core_tmp/bin" \
  "$core_tmp/cache/zsh" \
  "$core_tmp/cache/bash" \
  "$core_tmp/cache/fish" \
  "$core_tmp/cache/nushell"
for helper in \
  scripts/ops/chezmoi-apply.sh \
  scripts/ops/chezmoi-update.sh \
  scripts/ops/chezmoi-diff.sh \
  scripts/ops/chezmoi-remove.sh \
  scripts/uninstall.sh \
  dot_local/bin/executable_git-ai-commit; do
  mkdir -p "$core_tmp/repo/$(dirname "$helper")"
  cat >"$core_tmp/repo/$helper" <<'EOF_HELPER'
#!/usr/bin/env bash
printf 'helper:%s\n' "$0"
EOF_HELPER
  chmod +x "$core_tmp/repo/$helper"
done
cat >"$core_tmp/bin/chezmoi" <<'EOF_CHEZMOI'
#!/usr/bin/env bash
case "${1:-}" in
  status) printf 'M changed\n' ;;
  *) printf 'chezmoi:%s\n' "$*" ;;
esac
EOF_CHEZMOI
cat >"$core_tmp/bin/editor" <<'EOF_EDITOR'
#!/usr/bin/env bash
printf 'editor:%s\n' "$1"
EOF_EDITOR
chmod +x "$core_tmp/bin/chezmoi" "$core_tmp/bin/editor"
touch "$core_tmp/cache/zsh/tool-init.zsh" \
  "$core_tmp/cache/zsh/tool.zwc" \
  "$core_tmp/cache/bash/tool-init.bash" \
  "$core_tmp/cache/fish/tool-init.fish" \
  "$core_tmp/cache/nushell/tool.nu"
(
  set +e
  export HOME="$core_tmp/home"
  export XDG_CACHE_HOME="$core_tmp/cache"
  export EDITOR="$core_tmp/bin/editor"
  export PATH="$core_tmp/bin:$PATH"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/dot/utils.sh"
  _DOT_SOURCE_DIR_CACHE="$core_tmp/repo"
  set -- help
  # shellcheck disable=SC1090
  source "$SCRIPT_FILE"
  (cmd_apply --dry-run)
  (cmd_sync --dry-run)
  (cmd_update)
  (cmd_add "$core_tmp/sample")
  (cmd_add)
  (cmd_diff)
  cmd_status
  (cmd_remove "$core_tmp/sample")
  cmd_cd
  (cmd_edit)
  (cmd_commit)
  (cmd_uninstall)
  cmd_clean_cache
) >/dev/null || true
assert_file_not_exists "$core_tmp/cache/zsh/tool-init.zsh" \
  "core deep branches cleared sandbox zsh cache"

cov_exercise_functions_file "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
