#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# `dot ai tools` probes each tool's --version. The npm crush shim unpacks
# its binary into the current directory (archive-XXXXXX) on first run and
# prints download progress before "crush version v0.94.2", so the probe
# littered ~/.dotfiles and showed the download line as the version.
# The probe lives in lib/dot/ai-probe.sh and runs through
# scripts/dot/commands/ai.sh. Pinned here with a stub that behaves like
# that shim:
#   - the cold-cache refresh leaves nothing in the caller's directory;
#   - the cached version is the real one, not the download noise;
#   - _ai_extract_version does the same;
#   - a one-line tool is unchanged, a later version line beats an earlier
#     banner, and output with no version token falls back to the first line.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

AI="$REPO_ROOT/scripts/dot/commands/ai.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ai-probe.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home" XDG_CACHE_HOME="$WORK/home/.cache" TMPDIR="$WORK/tmp"
export DOTFILES_SHOW_LOGO=0 DOTFILES_AI_PROBE_JOBS=2 NO_COLOR=1
mkdir -p "$HOME" "$TMPDIR" "$WORK/bin" "$WORK/cwd"

cat >"$WORK/bin/crush" <<'SHIM'
#!/usr/bin/env bash
mkdir -p archive-AbC123
echo "Downloading https://github.com/charmbracelet/crush/releases/download/v0.94.2/crush_0.94.2_Darwin_arm64.tar.gz to archive-AbC123/crush_0.94.2_Darwin_arm64.tar.gz..."
echo "Download complete: archive-AbC123/crush_0.94.2_Darwin_arm64.tar.gz"
echo "Installed @charmland/crush 0.94.2 to /opt/mise/installs/npm-charmland-crush/0.94.2/bin"
echo "crush version v0.94.2"
SHIM
printf '#!/bin/sh\necho "2.1.3 (Claude Code)"\n' >"$WORK/bin/claude"
printf '#!/bin/sh\necho "Shell-GPT build 42"\necho "sgpt 1.4.5"\n' >"$WORK/bin/sgpt"
printf '#!/bin/sh\necho "Kimi build 42"\n' >"$WORK/bin/kimi"
chmod +x "$WORK/bin/"*
export PATH="$WORK/bin:$PATH"

entries=("A|agent|Crush|crush|x" "A|agent|Claude|claude|x" "G|general|Shell-GPT|sgpt|x" "A|agent|Kimi|kimi|x")
cache="$(
  cd "$WORK/cwd" || exit 1
  set -- --help
  source "$AI" >/dev/null 2>&1
  _ai_refresh_status_cache "${entries[@]}" >/dev/null 2>&1
  cat "$AI_STATUS_CACHE_FILE"
)"

test_start "ai_probe_leaves_caller_directory_clean"
assert_equals "" "$(ls -A "$WORK/cwd")" "no archive-* is left where dot ai tools ran"

test_start "ai_probe_cache_records_real_crush_version"
assert_contains $'crush\t1\t0.94.2\n' "$cache"$'\n' "the crush row holds the version, not download progress"

test_start "ai_probe_cache_keeps_one_line_versions"
assert_contains $'claude\t1\t2.1.3 (Claude Code)' "$cache" "a single version line is unchanged"

test_start "ai_probe_cache_prefers_version_line_over_first"
assert_contains $'sgpt\t1\t1.4.5' "$cache" "the version line wins over an earlier non-version line"

test_start "ai_probe_cache_falls_back_to_first_line"
assert_contains $'kimi\t1\t42' "$cache" "with no version token the first line is used, as before"

test_start "ai_extract_version_uses_the_version_line"
out="$(
  cd "$WORK/cwd" || exit 1
  set -- --help
  source "$AI" >/dev/null 2>&1
  _ai_extract_version crush
)"
assert_equals "0.94.2" "$out" "_ai_extract_version skips the shim's noise"

test_start "ai_probe_scratch_dirs_are_removed"
assert_equals "" "$(ls -A "$TMPDIR" | grep dot-ai-probe || true)" "every probe scratch directory is removed"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
