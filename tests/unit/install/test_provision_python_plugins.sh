#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# install/provision/run_onchange_25-python-tools.sh: pytest-cov is a pytest
# plugin with no command of its own, which `uv tool install` and
# `pipx install` refuse ("No apps associated with package"), so it never
# installed (drill A1). It goes into pytest's environment instead.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: chezmoi renders the template"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/python-plugins.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home"
chezmoi --source "$REPO_ROOT/defaults" execute-template \
  <"$REPO_ROOT/install/provision/run_onchange_25-python-tools.sh.tmpl" >"$WORK/run.sh"

# run <installer>: the script with only that stub installer (uv or pipx)
# ahead of the system; prints the installer's calls about pytest.
run() {
  rm -rf "$WORK/path" "$WORK/calls"
  mkdir -p "$WORK/path"
  printf '#!/bin/sh\necho "%s $*" >>"%s/calls"\n' "$1" "$WORK" >"$WORK/path/$1"
  chmod +x "$WORK/path/$1"
  env -i HOME="$WORK/home" PATH="$WORK/path:/usr/bin:/bin" bash "$WORK/run.sh" >/dev/null 2>&1
  grep -E 'pytest' "$WORK/calls" | paste -sd '|' -
}

test_start "uv_installs_pytest_with_its_coverage_plugin"
assert_equals "uv tool install --upgrade pytest|uv tool install --upgrade pytest --with pytest-cov" \
  "$(run uv)" "pytest, then pytest again with pytest-cov in its environment"

test_start "pipx_injects_the_coverage_plugin_into_pytest"
assert_equals "pipx install --force pytest|pipx inject pytest pytest-cov" \
  "$(run pipx)" "pytest, then pytest-cov injected into it"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
