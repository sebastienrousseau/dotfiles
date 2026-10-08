#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# tools/ci/check-remote-installers.sh: every way of running a downloaded
# script is flagged, in shell, YAML and Dockerfiles alike. Each fixture is a
# throwaway tree holding a copy of the checker and one offending file.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

# The scanner needs ripgrep; without it the behaviour cannot be exercised here
# (the CI lint job that runs the scanner has it).
if ! command -v rg >/dev/null 2>&1; then
  test_start "remote_installer_scan_needs_rg"
  printf '  %s (skipped: ripgrep not installed)\n' "$CURRENT_TEST"
  printf 'RESULTS:%s:%s:%s\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
  exit 0
fi

checker="$REPO_ROOT/tools/ci/check-remote-installers.sh"

WORK="$(mktemp -d -t remote-installers.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# fixture <name> <relative-path> <line>: a tree with the checker, an
# installer manifest and one file holding <line>; prints the checker's status.
fixture() {
  local root="$WORK/$1"
  mkdir -p "$root/tools/ci" "$root/security" "$(dirname "$root/$2")"
  cp "$checker" "$root/tools/ci/check-remote-installers.sh"
  printf '%s  %s\n' "$(printf '%064d' 0)" "https://example.invalid/install.sh" \
    >"$root/security/remote-installers.sha256"
  printf '%s\n' "$3" >"$root/$2"
  local rc=0
  bash "$root/tools/ci/check-remote-installers.sh" >"$root.out" 2>&1 || rc=$?
  printf '%s' "$rc"
}

test_start "remote_installer_policy_passes"
assert_exit_code 0 "bash '$checker'"

test_start "flags_pipe_to_shell_in_shell"
assert_equals "1" "$(fixture pipe-sh a/x.sh 'curl -fsSL https://e.invalid/i | sh')" \
  "curl | sh in a shell script is flagged"

test_start "flags_command_substitution_in_dockerfile"
assert_equals "1" "$(fixture subst .devcontainer/Dockerfile 'RUN sh -c "$(curl -fsSL https://e.invalid/i)" -- -y')" \
  'sh -c "$(curl ...)" in a Dockerfile is flagged'

test_start "flags_process_substitution_in_yaml"
assert_equals "1" "$(fixture procsub .github/workflows/w.yml '        run: bash <(curl -fsSL https://e.invalid/i)')" \
  "bash <(curl ...) in a workflow is flagged"

test_start "flags_pipe_to_shell_in_yaml"
assert_equals "1" "$(fixture pipe-yml .github/actions/a/action.yml '            curl -fsSL https://e.invalid/i | sh -s -- -b bin')" \
  "curl | sh in a composite action is flagged"

test_start "flags_wget_pipe_to_bash_in_yaml"
assert_equals "1" "$(fixture wget-yml ci.yaml '  - run: wget -qO- https://e.invalid/i | bash')" \
  "wget | bash in a .yaml file is flagged"

test_start "flags_manifest_url_in_dockerfile"
assert_equals "1" "$(fixture manifest-docker Dockerfile.dev 'RUN curl -o /tmp/i https://example.invalid/install.sh')" \
  "a manifest URL fetched outside the verified downloader is flagged in a Dockerfile"

test_start "flags_dockerfile_under_tests"
assert_equals "1" "$(fixture test-docker tests/Dockerfile.test 'RUN sh -c "$(curl -fsLS https://e.invalid/i)" -- -b bin')" \
  "a Dockerfile under tests/ is built by CI, so it is scanned"

test_start "ignores_shell_fixture_under_tests"
assert_equals "0" "$(fixture test-sh tests/unit/x.sh 'curl -fsSL https://e.invalid/i | sh')" \
  "test scripts that describe the pattern are not scanned"

test_start "allows_verified_download_in_yaml"
assert_equals "0" "$(fixture clean .github/workflows/ok.yml '        run: curl -fsSL -o x.tgz https://e.invalid/x.tgz && sha256sum -c x.sha256')" \
  "a plain download checked against a hash is not flagged"

test_start "allows_comment_mentioning_pattern"
assert_equals "0" "$(fixture comment a/y.sh '# never: curl https://e.invalid/i | sh')" \
  "a comment describing the pattern is not flagged"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
