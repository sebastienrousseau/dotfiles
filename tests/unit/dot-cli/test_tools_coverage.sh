#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Coverage for the best-effort lockfile step of
# scripts/dot/commands/tools.sh apply_template_security_baseline: npm for a
# node template without a lockfile, uv for python, `go mod tidy` for go.
# npm/uv/go are recording PATH stubs and every project lives in a mktemp
# directory, so no package manager or network is touched.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

REAL_BASH="${BASH:-$(command -v bash)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/tools-cov.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config" NO_COLOR=1 DOTFILES_SHOW_LOGO=0
mkdir -p "$HOME" "$WORK/bin"
CALLS="$WORK/calls"
: >"$CALLS"
for c in npm uv go; do
  printf '#!%s\necho "%s $* (in $PWD)" >>"%s"\n' "$REAL_BASH" "$c" "$CALLS" >"$WORK/bin/$c"
  chmod +x "$WORK/bin/$c"
done

# baseline <dir> <lang> — source tools.sh (help arm, output dropped), then
# run apply_template_security_baseline on <dir>.
baseline() {
  PATH="$WORK/bin:$PATH" "$REAL_BASH" -c '
    dest="$1" lang="$2"
    set -- --help
    source "$0/scripts/dot/commands/tools.sh" >/dev/null 2>&1
    set +e
    apply_template_security_baseline "$dest" "$lang"
  ' "$REPO_ROOT" "$1" "$2" 2>&1
}

test_start "node_template_generates_a_lockfile"
mkdir -p "$WORK/node"
printf '{}\n' >"$WORK/node/package.json"
baseline "$WORK/node" node >/dev/null
assert_file_contains "$CALLS" "npm install --package-lock-only --ignore-scripts --silent" "npm lock-only install"
assert_file_contains "$WORK/node/.gitignore" ".env" "baseline gitignore written"

test_start "python_template_locks_with_uv"
mkdir -p "$WORK/py"
: >"$WORK/py/pyproject.toml"
baseline "$WORK/py" python >/dev/null
assert_file_contains "$CALLS" "uv lock" "uv lock runs"

test_start "go_template_tidies_modules"
mkdir -p "$WORK/go"
printf 'module example.test/x\n' >"$WORK/go/go.mod"
baseline "$WORK/go" go >/dev/null
assert_file_contains "$CALLS" "go mod tidy" "go mod tidy runs"
assert_file_exists "$WORK/go/.editorconfig" "editorconfig written"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
