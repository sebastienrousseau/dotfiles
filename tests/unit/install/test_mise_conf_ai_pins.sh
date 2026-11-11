#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# test-kind: structural
# [ai_tools] in .chezmoidata.toml pins each AI CLI (decision D3), and dot
# doctor warns when an installed agent is off its pin. The mise conf.d the
# dotfiles deploy installed the same tools at "latest", so `mise upgrade`
# (run by `dot system update`) moved them off their pins on every update.
# Every conf.d entry for a pinned tool must name its pin. A tool conf.d
# installs under another name (the native `codex`) is matched through the
# roster entry whose binary it is. Structural: it parses the two TOML files.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CONF="$REPO_ROOT/defaults/dot_config/mise/conf.d/00-dotfiles.toml"
DATA="$REPO_ROOT/defaults/.chezmoidata.toml"
ROSTER="$REPO_ROOT/plugins/ai/roster.toml"

# pin_drift CONF DATA ROSTER: one "<tool> conf.d=<version> pin=<pin>" line
# per conf.d entry whose version is not its tool's pin.
pin_drift() {
  python3 - "$@" <<'PY'
import sys, tomllib
conf, data, roster = (tomllib.load(open(p, "rb")) for p in sys.argv[1:4])
pins = data["ai_tools"]
by_bin = {t["bin"]: t.get("package") for t in roster["tool"]}
for name, spec in conf["tools"].items():
    key = name if name in pins else by_bin.get(name)
    if key not in pins:
        continue
    version = spec.get("version") if isinstance(spec, dict) else spec
    if version != pins[key]:
        print(f"{name} conf.d={version} pin={pins[key]}")
PY
}

test_start "every_pinned_ai_tool_in_mise_conf_d_names_its_pin"
drift="$(pin_drift "$CONF" "$DATA" "$ROSTER")"
assert_equals "" "$drift" "no conf.d entry floats off its [ai_tools] pin"

test_start "the_check_reports_a_tool_that_floats"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/conf-pins.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
printf '[tools]\n"npm:example-cli" = "latest"\nexample-bin = "2.0.0"\nunpinned = "latest"\n' >"$WORK/conf.toml"
printf '[ai_tools]\n"npm:example-cli" = "1.0.0"\n"npm:example-pkg" = "2.0.0"\n' >"$WORK/data.toml"
printf '[[tool]]\nname = "example"\nbin = "example-bin"\npackage = "npm:example-pkg"\n' >"$WORK/roster.toml"
drift="$(pin_drift "$WORK/conf.toml" "$WORK/data.toml" "$WORK/roster.toml")"
assert_equals "npm:example-cli conf.d=latest pin=1.0.0" "$drift" \
  "a floating pinned tool is named; a matching one through the roster and an unpinned one are not"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
