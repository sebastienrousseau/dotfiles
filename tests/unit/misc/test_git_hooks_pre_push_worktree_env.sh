#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
#
# Git exports GIT_DIR to hooks. Pushing from a linked worktree makes it an
# absolute path into the shared repository, so a test that creates a scratch
# repo during the pre-push audit wrote into the real one (2026-10-14: main
# moved, core.bare=true, user.email=fm@example.invalid). The audit must run
# with git's per-repository variables cleared.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

# This test drives git itself; never inherit a repository from the caller.
while IFS= read -r _var; do unset "$_var"; done < <(git rev-parse --local-env-vars)
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
main="$tmp/main"
wt="$tmp/wt"

mkdir -p "$main/scripts/git-hooks" "$main/scripts/qa"
cp "$REPO_ROOT/scripts/git-hooks/pre-push" "$main/scripts/git-hooks/pre-push"
# The audit does what a scratch-repo test does: init a repo, then configure it.
cat >"$main/scripts/qa/reliability-audit.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
scratch="$(mktemp -d)"
git init -q "$scratch"
git -C "$scratch" config user.email fm@example.invalid
printf 'audit GIT_DIR=%s\n' "${GIT_DIR-unset}"
rm -rf "$scratch"
EOF
printf '#!/usr/bin/env bash\nexit 0\n' >"$main/scripts/qa/check-version-consistency.sh"
git init -q -b main "$main"
git -C "$main" add -A
git -C "$main" -c user.name=t -c user.email=t@example.invalid commit -qm init
git -C "$main" worktree add -q -b topic "$wt"

# Invoke the hook as git does for a push from the linked worktree.
gitdir="$(git -C "$wt" rev-parse --absolute-git-dir)"
output="$(cd "$wt" && GIT_DIR="$gitdir" bash scripts/git-hooks/pre-push </dev/null 2>&1)"
rc=$?

test_start "pre_push_from_worktree_runs_the_audit"
assert_equals "0" "$rc" "hook exits 0 when the audit passes (output: $output)"

test_start "pre_push_audit_sees_no_inherited_git_dir"
assert_contains "audit GIT_DIR=unset" "$output" "the audit runs without the hook's GIT_DIR"

test_start "pre_push_audit_leaves_the_pushing_repo_config_alone"
assert_equals "" "$(git -C "$main" config --local --get user.email || true)" \
  "a scratch repo's config did not land in the real repository"
assert_equals "false" "$(git -C "$main" config --local --get core.bare)" \
  "the real repository is still a non-bare checkout"

print_summary
