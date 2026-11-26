#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# test-kind: structural
# shellcheck disable=SC1091
# `.chezmoi.sourceDir` is defaults/ here (.chezmoiroot), so a template that
# reaches the repository's install/, lib/, bin/ or tools/ through it points
# at a path that does not exist. Two did: the Linux package provisioner
# failed on its first line on every machine (`defaults/install/lib/
# logging.sh: No such file`, drill A1), and the deployed dot.ps1 wrapper ran
# defaults/bin/dot.ps1. The repository root is `.chezmoi.workingTree`.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

test_start "templates_reach_the_repo_root_through_workingTree"
found="$(cd "$REPO_ROOT" && git grep -n -E '\.chezmoi\.sourceDir *\}\}/(install|lib|bin|tools|scripts|plugins)/' -- install defaults || true)"
if [[ -z "$found" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: .chezmoi.sourceDir is defaults/, not the repository root:"
  printf '      %s\n' "$found"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
