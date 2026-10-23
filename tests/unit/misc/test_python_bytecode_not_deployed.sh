#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Python bytecode in the source tree is build output: a test importing a
# deployed script (dot-ai-serve's) writes a __pycache__ beside it. git ignores
# it, but chezmoi used to manage it and deploy it to ~/.local/bin. Checked by
# listing what the real chezmoi manages from a source tree that holds some.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DEFAULTS="$REPO_ROOT/defaults"
if ! command -v chezmoi >/dev/null 2>&1; then
  test_start "python_bytecode_needs_chezmoi"
  printf '  %s (skipped: chezmoi not installed)\n' "$CURRENT_TEST"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/py-bytecode.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config" XDG_CACHE_HOME="$WORK/home/.cache"
mkdir -p "$HOME"
cz() {
  chezmoi --config /dev/null --config-format toml --persistent-state "$WORK/state.boltdb" \
    --cache "$WORK/cache" "$@"
}

# A source tree with the real ignore rules and data, one script, one config
# file, and bytecode in the two shapes a stray import leaves behind.
SRC="$WORK/src"
mkdir -p "$SRC/dot_local/bin/__pycache__" "$SRC/dot_config/x"
cp "$DEFAULTS/.chezmoiignore.tmpl" "$SRC/.chezmoiignore.tmpl"
cp "$DEFAULTS/.chezmoidata.toml" "$SRC/.chezmoidata.toml"
for d in .chezmoidata .chezmoitemplates .theme-manifest; do
  [[ -d "$DEFAULTS/$d" ]] && cp -R "$DEFAULTS/$d" "$SRC/$d"
done
printf '#!/usr/bin/env python3\n' >"$SRC/dot_local/bin/executable_tool"
printf 'x' >"$SRC/dot_local/bin/__pycache__/executable_tool.cpython-314.pyc"
printf 'x' >"$SRC/dot_config/x/stray.pyc"
printf 'a = 1\n' >"$SRC/dot_config/x/settings.toml"
managed="$(cz --source "$SRC" --destination "$HOME" managed --include files 2>"$WORK/managed.err")"

test_start "python_source_and_config_are_still_managed"
assert_contains ".local/bin/tool" "$managed" "the script is managed: $(head -2 "$WORK/managed.err")"
assert_contains ".config/x/settings.toml" "$managed" "a config file beside bytecode is managed"

test_start "python_bytecode_is_not_deployed"
assert_equals "0" "$(grep -cE '__pycache__|\.pyc$' <<<"$managed")" "no __pycache__ or .pyc target is managed"

test_start "test_runner_stops_writing_bytecode"
assert_true "grep -qE '^export PYTHONDONTWRITEBYTECODE=1$' '$REPO_ROOT/tests/framework/test_runner.sh'" \
  "the runner sets PYTHONDONTWRITEBYTECODE=1 for every suite"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
