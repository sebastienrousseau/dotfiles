#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

CHEATSHEET_SCRIPT="$REPO_ROOT/scripts/diagnostics/aliases-cheatsheet.sh"

test_start "aliases_cheatsheet_script_exists"
assert_file_exists "$CHEATSHEET_SCRIPT" "aliases-cheatsheet script should exist"

test_start "aliases_cheatsheet_generates_output"
tmp_src="$(mktemp -d)"
mkdir -p "$tmp_src/scripts/diagnostics"
cat >"$tmp_src/scripts/diagnostics/aliases-manifest.sh" <<'EOF'
#!/usr/bin/env bash
cat <<'OUT'
c	clear_screen	/.*
a	ai_core query	/ai/
d	dot	/system/
OUT
EOF
chmod +x "$tmp_src/scripts/diagnostics/aliases-manifest.sh"

output="$(CHEZMOI_SOURCE_DIR="$tmp_src" bash "$CHEATSHEET_SCRIPT" 2>&1 || true)"
if [[ "$output" == *"# Alias Cheatsheet"* ]] && [[ "$output" == *"- \`c\`"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: emits markdown cheatsheet"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected markdown output"
  echo "$output"
fi
rm -rf "$tmp_src"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
