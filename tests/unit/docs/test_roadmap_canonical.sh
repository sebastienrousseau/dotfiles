#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CANONICAL="$REPO_ROOT/ROADMAP.md"
STUBS=(
  "docs/operations/ROADMAP.md"
  "docs/operations/ROADMAP_2026.md"
  "docs/operations/ARCHITECTURE_ROADMAP.md"
  "docs/operations/ROADMAP_V0_2_503.md"
  "docs/archive/LEGACY_ROADMAP.md"
)

test_start "roadmap_root_is_canonical"
assert_file_contains "$CANONICAL" "This is the canonical roadmap" \
  "root ROADMAP.md declares canonical status"

test_start "roadmap_stubs_redirect_to_canonical"
for rel in "${STUBS[@]}"; do
  assert_file_contains "$REPO_ROOT/$rel" "../../ROADMAP.md" "$rel links to canonical roadmap"
done

test_start "roadmap_stubs_do_not_carry_active_plans"
for rel in "${STUBS[@]}"; do
  line_count="$(wc -l <"$REPO_ROOT/$rel" | tr -d ' ')"
  if [[ "$line_count" -le 12 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $rel is a short compatibility stub"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $rel has $line_count lines; keep active roadmap content in ROADMAP.md"
  fi
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
