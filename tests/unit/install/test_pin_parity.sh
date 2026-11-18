#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# test-kind: structural
# One tool version, everywhere it is written. defaults/dot_config/mise/conf.d/
# 00-dotfiles.toml is the source; every other pin must agree with it:
#   - [ai_tools] in defaults/.chezmoidata.toml (exactly; a tool conf.d
#     installs under another name is matched through the roster's binary);
#   - the repository's own mise.toml (exactly, or inside a fuzzy conf.d
#     version such as node "26");
#   - what scripts/ops/heal-tools.sh installs (_mise_tool_specs, run);
#   - the wasmtime CI installs in .github/workflows/rust.yml and the version
#     lib/wasm-tools/README.md documents.
# A "latest" in conf.d accepts any version. Before this test six sources
# drifted apart (node 24 vs 26, wasmtime 47.0.3 vs 50.0.2, ...), and a
# heal-tools run downgraded a host and pinned it there. Structural: it
# parses the files, and runs heal-tools' spec function.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pin-parity.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# heal_specs <repo>: "<tool>@<version>" for every tool heal-tools installs
# through mise, from its own spec function.
heal_specs() {
  bash -c 'source "$1/scripts/ops/heal-tools.sh" >/dev/null 2>&1
    for t in nushell pueue wasmtime sops yazi zellij; do _mise_tool_specs "$t"; done' _ "$1" 2>/dev/null
}

# pin_drift <repo> <heal-specs-file>: one line per pin that disagrees with
# conf.d, naming the source, the tool and both versions.
pin_drift() {
  python3 - "$1" "$2" <<'PY'
import pathlib, re, sys, tomllib

repo, heal_file = pathlib.Path(sys.argv[1]), sys.argv[2]
conf = tomllib.loads((repo / "defaults/dot_config/mise/conf.d/00-dotfiles.toml").read_text())["tools"]
data = tomllib.loads((repo / "defaults/.chezmoidata.toml").read_text())["ai_tools"]
roster = tomllib.loads((repo / "plugins/ai/roster.toml").read_text())["tool"]
root = tomllib.loads((repo / "mise.toml").read_text())["tools"]

def version(spec):
    return str(spec.get("version") if isinstance(spec, dict) else spec)

def agrees(name, got, exact):
    if name not in conf:
        return False
    want = version(conf[name])
    if want == "latest":
        return True
    return got == want or (not exact and got.startswith(want + "."))

def check(source, name, got, exact=False):
    if not agrees(name, got, exact):
        want = version(conf[name]) if name in conf else "absent"
        print(f"{source}: {name} {got} != conf.d {want}")

by_bin = {t["bin"]: t.get("package") for t in roster}
pkg_to_conf = {pkg: b for b, pkg in by_bin.items() if pkg}
for pkg, pin in data.items():
    name = pkg if pkg in conf else pkg_to_conf.get(pkg)
    if name in conf:
        check("[ai_tools]", name, pin, exact=True)
for name, spec in root.items():
    check("mise.toml", name, version(spec))
for line in pathlib.Path(heal_file).read_text().split():
    name, _, got = line.rpartition("@")
    check("heal-tools", name, got, exact=True)
workflow = (repo / ".github/workflows/rust.yml").read_text()
for got in re.findall(r"tool:\s*wasmtime@([0-9.]+)", workflow):
    check("rust.yml", "wasmtime", got, exact=True)
readme = (repo / "lib/wasm-tools/README.md").read_text()
for got in re.findall(r"wasmtime ([0-9]+\.[0-9]+\.[0-9]+)", readme):
    check("wasm-tools README", "wasmtime", got, exact=True)
PY
}

test_start "every_pin_source_agrees_with_mise_conf_d"
heal_specs "$REPO_ROOT" >"$WORK/heal.txt"
drift="$(pin_drift "$REPO_ROOT" "$WORK/heal.txt" 2>&1)"
assert_equals "" "$drift" "conf.d, [ai_tools], mise.toml, heal-tools, rust.yml and the README name one version per tool"

test_start "heal_tools_installs_every_tool_it_maps"
assert_equals "7" "$(grep -c '@' "$WORK/heal.txt")" "six tools, seven specs (pueue + pueued), each with a version"

# The checker itself: a fixture tree with one drifted pin per source.
test_start "the_check_names_each_drifted_source"
FX="$WORK/fx"
mkdir -p "$FX/defaults/dot_config/mise/conf.d" "$FX/plugins/ai" "$FX/.github/workflows" "$FX/lib/wasm-tools"
cat >"$FX/defaults/dot_config/mise/conf.d/00-dotfiles.toml" <<'TOML'
[tools]
node = "26"
go = "latest"
wasmtime = "50.0.2"
codex = "1.0.0"
"github:me/tool" = { version = "0.0.2", minimum_release_age = "0s" }
TOML
printf '[ai_tools]\n"npm:codex" = "0.9.0"\n"github:me/tool" = "0.0.2"\n"npm:other" = "1.0.0"\n' >"$FX/defaults/.chezmoidata.toml"
printf '[[tool]]\nname = "codex"\nbin = "codex"\npackage = "npm:codex"\n' >"$FX/plugins/ai/roster.toml"
printf '[tools]\nnode = "24.14.0"\ngo = "1.26.11"\nwasmtime = "50.0.2"\nyazi = "1.0.0"\n' >"$FX/mise.toml"
printf 'tool: wasmtime@47.0.3\n' >"$FX/.github/workflows/rust.yml"
printf 'stable + wasmtime 50.0.2\n' >"$FX/lib/wasm-tools/README.md"
printf 'wasmtime@49.0.0\nnode@26.1.0\n' >"$FX/heal.txt"
assert_equals "[ai_tools]: codex 0.9.0 != conf.d 1.0.0
mise.toml: node 24.14.0 != conf.d 26
mise.toml: yazi 1.0.0 != conf.d absent
heal-tools: wasmtime 49.0.0 != conf.d 50.0.2
heal-tools: node 26.1.0 != conf.d 26
rust.yml: wasmtime 47.0.3 != conf.d 50.0.2" "$(pin_drift "$FX" "$FX/heal.txt" 2>&1)" \
  "each drifted pin is named; latest, a fuzzy match and an exact match pass"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
