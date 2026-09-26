#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# test-kind: structural
# aider supports Python 3.9-3.12 and crashes at import on 3.13+ (pydub
# imports the stdlib audioop module, removed in 3.13). The mise config must
# build aider's environment on Python 3.12. Structural: it parses the mise
# TOML (installing aider needs the network and a Python download).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CONF="$REPO_ROOT/defaults/dot_config/mise/conf.d/00-dotfiles.toml"

test_start "mise_aider_pins_python_3_12"
assert_equals "--python 3.12" \
  "$(python3 -c 'import sys, tomllib
t = tomllib.load(open(sys.argv[1], "rb"))["tools"]["pipx:aider-chat"]
print(t.get("uvx_args", "") if isinstance(t, dict) else "")' "$CONF")" \
  "aider is installed on Python 3.12 (uvx_args)"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
