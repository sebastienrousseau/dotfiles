#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# `ai_core download` marks the downloaded llamafile executable, so it must
# only install bytes that match the pinned SHA-256.
#
# No case reaches the network: a curl stub serves the payload.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

AI_CORE="$REPO_ROOT/defaults/dot_local/bin/executable_ai_core"

WORK="$(mktemp -d -t ai-core.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/stubs"

cat >"$WORK/stubs/curl" <<STUB
#!/bin/sh
out=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) out="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
printf 'not the pinned model\n' >"\$out"
exit 0
STUB
chmod +x "$WORK/stubs/curl"

MODEL="$WORK/data/ai/models/llava-v1.5-7b-q4.llamafile"

test_start "ai_core_rejects_mismatched_model"
out="$(printf 'y' | XDG_DATA_HOME="$WORK/data" PATH="$WORK/stubs:/usr/bin:/bin" \
  bash "$AI_CORE" download 2>&1)"
rc=$?
assert_not_equals "0" "$rc" "a mismatched download should fail"

test_start "ai_core_mismatch_installs_nothing"
assert_file_not_exists "$MODEL" "the unverified model must not be installed"

test_start "ai_core_mismatch_leaves_no_partial"
assert_file_not_exists "$MODEL.partial" "the partial download is removed"

test_start "ai_core_mismatch_is_reported"
assert_contains "Checksum mismatch" "$out" "the failure names the checksum"

test_start "ai_core_pin_is_revision_and_hash"
url="$(sed -n 's/^LLAMAFILE_URL="\(.*\)"$/\1/p' "$AI_CORE")"
sha="$(sed -n 's/^LLAMAFILE_SHA256="\(.*\)"$/\1/p' "$AI_CORE")"
if [[ "$url" =~ ^https://huggingface\.co/.+/resolve/[0-9a-f]{40}/ && "$sha" =~ ^[0-9a-f]{64}$ ]]; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # URL must pin a commit and carry a SHA-256: $url $sha"
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
