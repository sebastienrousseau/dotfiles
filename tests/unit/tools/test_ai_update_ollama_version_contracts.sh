#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Contracts of the Ollama version check in
# defaults/dot_local/bin/executable_ai-update (Linux branch). The mutation
# gate found both unprotected:
#
#   * the latest-release string must be a bare MAJOR.MINOR.PATCH: anything
#     with junk in front of the number is "could not determine", never a
#     version to download (the `^` anchor on the regex);
#   * an installed version equal to the latest is "already up to date";
#     one that differs goes to the verified download (the `==` verdict).
#
# The script runs for real against a stub-only PATH: `uname` says Linux,
# `sudo -v` is a no-op, `ollama --version` and the `curl -I` release
# probe are canned, and every other curl call fails so no download ever
# happens. HOME is a mktemp dir; nothing reaches the network.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

AI_UPDATE="$REPO_ROOT/defaults/dot_local/bin/executable_ai-update"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ai-update-ver.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

H="$WORK/home"
BASE="$WORK/base"
STUBS="$WORK/stubs"
CALLS="$WORK/curl.log"
mkdir -p "$H" "$BASE" "$STUBS"

# Only the ordinary tools the script needs; no mise/brew/pipx/claude/node
# can be found, so every other section is skipped.
ln -sf "${BASH:-$(command -v bash)}" "$BASE/bash"
for tool in sh sed grep head tail tr awk wc mktemp rm cat env printf; do
  resolved="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$resolved" ]] && ln -sf "$resolved" "$BASE/$tool"
done

cat >"$STUBS/chezmoi" <<STUB
#!/usr/bin/env bash
[[ "\${1:-}" == "source-path" ]] && echo "$REPO_ROOT/defaults"
exit 0
STUB
cat >"$STUBS/uname" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  -m) echo x86_64 ;;
  *) echo Linux ;;
esac
STUB
printf '#!/usr/bin/env bash\nexit 0\n' >"$STUBS/sudo"
cat >"$STUBS/ollama" <<'STUB'
#!/usr/bin/env bash
echo "ollama version is ${OLLAMA_STUB_CURRENT:?}"
STUB
# curl: the `-I` release probe answers with a canned Location header;
# every other request (a download) is logged and refused.
cat >"$STUBS/curl" <<STUB
#!/usr/bin/env bash
printf 'curl %s\n' "\$*" >>"$CALLS"
for a in "\$@"; do
  if [[ "\$a" == "-I" ]]; then
    printf 'location: https://github.com/ollama/ollama/releases/tag/v%s\r\n' "\${OLLAMA_STUB_LATEST:?}"
    exit 0
  fi
done
exit 22
STUB
chmod +x "$STUBS"/*

OUT=""
RC=0
# run_update <current> <latest> — run ai-update with the given installed
# and published Ollama versions; sets OUT / RC and clears the curl log.
run_update() {
  : >"$CALLS"
  RC=0
  OUT="$(HOME="$H" TMPDIR="$WORK" PATH="$STUBS:$BASE" \
    OLLAMA_STUB_CURRENT="$1" OLLAMA_STUB_LATEST="$2" \
    "${BASH:-bash}" "$AI_UPDATE" 2>&1 </dev/null)" || RC=$?
}

test_start "ai_update_ollama_rejects_junk_before_the_version"
run_update 0.1.0 "junk1.2.3"
assert_equals 0 "$RC" "the updater still completes"
assert_contains "could not determine the latest release" "$OUT" "junk-prefixed latest is not a version"
assert_false "grep -q 'releases/download/' '$CALLS'" "no download is attempted"

test_start "ai_update_ollama_up_to_date_skips"
run_update 0.2.0 0.2.0
assert_equals 0 "$RC" "the updater still completes"
assert_contains "already up to date" "$OUT" "equal versions skip"
assert_false "grep -q 'releases/download/' '$CALLS'" "no download is attempted"

test_start "ai_update_ollama_outdated_downloads_the_release"
run_update 0.1.0 0.2.0
assert_equals 0 "$RC" "the updater still completes"
assert_false "[[ \"\$OUT\" == *'already up to date'* ]]" "a different version is not reported as current"
assert_file_contains "$CALLS" "releases/download/v0.2.0/sha256sum.txt" "the pinned release manifest is requested"
assert_contains "Integrity check failed" "$OUT" "the refused download is reported"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
