#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Clipboard-dispatch coverage for the genpass function.
#
# genpass ends in a five-way `elif` chain over clipboard tools (cb, pbcopy,
# xclip, wl-copy, clip.exe) with a warning fallback. Only the first arm that
# matches is ever evaluated, so the existing behavioural suite — which mocks
# every tool at once — can only ever reach `cb`. Each case here runs genpass
# with a PATH that contains exactly one clipboard tool (or none), which is the
# only way the later arms can be reached at all.
#
# The PATH is rebuilt from scratch per case rather than prepended to, because
# on macOS pbcopy is in /usr/bin and could not otherwise be hidden.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

FUNC_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/security/genpass.sh"

WORK="$(mktemp -d -t genpass-clip.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$WORK"; cov_teardown_sandbox' EXIT

source "$FUNC_FILE"

# The minimal set of external binaries genpass itself needs. Anything not
# listed here is invisible to the function under test.
GP_BASE="$WORK/base"
mkdir -p "$GP_BASE"
for tool in openssl tr head cat; do
  resolved="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$resolved" ]] && ln -sf "$resolved" "$GP_BASE/$tool"
done

if [[ ! -x "$GP_BASE/openssl" ]]; then
  echo "SKIP: openssl not available"
  echo "RESULTS:0:0:0"
  exit 0
fi

# gp_with <tool|none> — run genpass with exactly one clipboard tool visible.
# The tool records what it was handed so the test can prove the password
# really was piped into it, not merely that the arm was taken.
GP_OUT=""
GP_SINK=""
gp_with() {
  local tool="$1"
  shift
  local dir="$WORK/case_${tool}"
  rm -rf "$dir"
  mkdir -p "$dir"
  GP_SINK="$dir/captured"
  if [[ "$tool" != "none" ]]; then
    # `#!/bin/sh` rather than `#!/usr/bin/env bash`: the case PATH is
    # deliberately tiny and does not carry env or bash.
    printf '#!/bin/sh\ncat >"%s"\n' "$GP_SINK" >"$dir/$tool"
    chmod +x "$dir/$tool"
  fi
  GP_OUT="$(PATH="$dir:$GP_BASE" genpass "$@" 2>&1)"
}

# ── 1. Each clipboard arm in turn ──────────────────────────────────────────
test_start "genpass_uses_cb_when_available"
gp_with cb 1 "|"
assert_contains "copied to clipboard" "$GP_OUT" "cb should be reported as used"
assert_equals "12" "$(wc -c <"$GP_SINK" | tr -d ' ')" \
  "the generated password should be piped into cb"

test_start "genpass_uses_pbcopy_when_cb_is_absent"
gp_with pbcopy 1 "|"
assert_contains "(macOS)" "$GP_OUT" "pbcopy should be reported as the macOS path"
assert_equals "12" "$(wc -c <"$GP_SINK" | tr -d ' ')" \
  "the generated password should be piped into pbcopy"

test_start "genpass_uses_xclip_when_earlier_tools_are_absent"
gp_with xclip 1 "|"
assert_contains "(Linux)" "$GP_OUT" "xclip should be reported as the Linux path"

test_start "genpass_uses_wl_copy_on_wayland"
gp_with wl-copy 1 "|"
assert_contains "Wayland" "$GP_OUT" "wl-copy should be reported as the Wayland path"

test_start "genpass_uses_clip_exe_on_windows"
gp_with clip.exe 1 "|"
assert_contains "(Windows)" "$GP_OUT" "clip.exe should be reported as the Windows path"

test_start "genpass_warns_when_no_clipboard_tool_exists"
gp_with none 1 "|"
assert_contains "Clipboard tool not found" "$GP_OUT" \
  "the fallback should warn rather than fail"
assert_contains "Generated password:" "$GP_OUT" \
  "the password is still printed when it cannot be copied"

# ── 2. openssl is a hard requirement ───────────────────────────────────────
test_start "genpass_requires_openssl"
GP_EMPTY="$WORK/empty"
mkdir -p "$GP_EMPTY"
rc=0
out="$(PATH="$GP_EMPTY" genpass 2>&1)" || rc=$?
assert_equals "1" "$rc" "genpass should fail when openssl is missing"
assert_contains "'openssl' is required" "$out" "the failure should name openssl"

print_summary
