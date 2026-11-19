#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

config="$REPO_ROOT/mise.toml"
lock="$REPO_ROOT/mise.lock"
global_config="$REPO_ROOT/defaults/dot_config/mise/conf.d/00-dotfiles.toml"

test_start "mise_lock_exists"
assert_file_exists "$lock" "cross-platform mise lockfile exists"

test_start "mise_lock_enabled"
assert_file_contains "$config" "lockfile = true" "mise consumes the committed lockfile"

test_start "mise_project_config_has_no_mutable_versions"
if grep -En '= "(latest|nightly|lts)"' "$config" >/dev/null; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

# The release-age gate: a floating version resolves to a release at least
# seven days old, and nothing installs behind a shim call. A tool the gate
# cannot guard (an npm, pipx, go or github package, whose registry is the
# only check between publisher and shell) or a trust tool is pinned exactly,
# and first-party tools opt out per tool. mise reads the file itself.
REAL_MISE="$(command -v mise || true)"
mise_get() {
  env -i HOME="$sandbox" PATH="$(dirname "$REAL_MISE"):/usr/bin:/bin" \
    MISE_DATA_DIR="$sandbox/d" MISE_CACHE_DIR="$sandbox/c" MISE_STATE_DIR="$sandbox/s" \
    MISE_CONFIG_DIR="$sandbox/cfg" MISE_OFFLINE=1 \
    mise config get -f "$global_config" "$1" 2>/dev/null
}
if [[ -n "$REAL_MISE" ]]; then
  sandbox="$(mktemp -d)"
  test_start "mise_global_config_gates_floating_releases_for_seven_days"
  assert_equals "7d|false" "$(mise_get settings.minimum_release_age)|$(mise_get settings.auto_install)" \
    "floating versions wait seven days; missing tools install only on request" || true
  test_start "mise_global_config_exempts_first_party_tools_from_the_gate"
  assert_equals "0s" "$(mise_get 'tools."github:sebastienrousseau/corralctl".minimum_release_age')" \
    "a first-party release is seen at once" || true
  rm -rf "$sandbox"
else
  echo "  - skipped: mise not installed"
fi

test_start "mise_global_config_pins_ungated_and_trust_tools_exactly"
floating="$(
  python3 - "$global_config" <<'PY'
import re, sys, tomllib
tools = tomllib.load(open(sys.argv[1], "rb"))["tools"]
must_pin = re.compile(r"^(npm|pipx|go|github|cargo):|^(aqua:FiloSottile/age|minisign|uv)$")
for name, spec in tools.items():
    version = spec.get("version") if isinstance(spec, dict) else spec
    if must_pin.search(name) and not re.fullmatch(r"\d+(\.\d+)+", str(version)):
        print(name, version)
PY
)"
assert_equals "" "$floating" "npm/pipx/go/github packages and age, minisign, uv name an exact version" || true

test_start "mise_global_config_does_not_export_github_token"
if grep -Eq '^[[:space:]]*GITHUB_TOKEN[[:space:]]*=' "$global_config"; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: global child processes would inherit GitHub credentials"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: GitHub credentials remain task-scoped"
fi

# Print the body of one top-level TOML table ([env], [settings], ...).
toml_table() {
  awk -v want="[$2]" '/^\[/ { on = ($0 == want); next } on' "$1"
}

# [env] values are exported to every process mise launches, so a gh token
# must never be resolved there. [settings] is read by mise alone.
test_start "mise_global_config_env_table_is_parsed"
assert_output_contains 'MISE_EXPERIMENTAL' "toml_table '$global_config' env"

test_start "mise_global_config_does_not_materialize_gh_token"
assert_output_not_contains "gh auth token" "toml_table '$global_config' env"

test_start "mise_global_config_authenticates_mise_in_process"
assert_output_contains 'github.credential_command = "gh auth token"' \
  "toml_table '$global_config' settings"

# Neither config may give mise a rust: mise's rust exports RUSTUP_TOOLCHAIN,
# which outranks every project's rust-toolchain.toml, and a toolchain pinned
# this way breaks rustc in the whole tree when its install is damaged
# ("missing manifest in toolchain"). rustup and each project's pin decide.
# mise itself reads each file, in a sandbox with no other config.
REAL_MISE="$(command -v mise || true)"
if [[ -n "$REAL_MISE" ]]; then
  sandbox="$(mktemp -d)"
  for cfg in "$config" "$global_config"; do
    test_start "mise_config_leaves_rust_to_rustup_$(basename "$cfg" .toml)"
    got="$(env -i HOME="$sandbox" PATH="$(dirname "$REAL_MISE"):/usr/bin:/bin" \
      MISE_DATA_DIR="$sandbox/d" MISE_CACHE_DIR="$sandbox/c" MISE_STATE_DIR="$sandbox/s" \
      MISE_CONFIG_DIR="$sandbox/cfg" MISE_OFFLINE=1 \
      mise config get -f "$cfg" tools.rust 2>/dev/null)" && rc=0 || rc=$?
    assert_equals "1:" "$rc:$got" "$(basename "$cfg") declares no rust for mise" || true
  done
  rm -rf "$sandbox"
else
  echo "  - skipped: mise not installed"
fi

for tool in node go bun starship wasmtime sops yazi zellij; do
  test_start "mise_lock_contains_${tool}"
  assert_file_contains "$lock" "[[tools.$tool]]" "lock contains $tool"
done

for platform in linux-arm64 linux-x64 macos-arm64 macos-x64 windows-x64; do
  test_start "mise_lock_contains_${platform}"
  assert_file_contains "$lock" "platforms.$platform" "lock contains $platform metadata"
done

test_start "mise_lock_has_sha256_metadata"
checksum_count="$(grep -Ec '^checksum = "sha256:[0-9a-f]{64}"$' "$lock" || true)"
if [[ "$checksum_count" -ge 50 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: insufficient checksum records"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
