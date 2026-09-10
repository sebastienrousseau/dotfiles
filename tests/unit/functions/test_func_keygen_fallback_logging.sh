#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The minimal logging shims at the top of the keygen function file.
#
# keygen sources ../utils/logging.sh when it is there and defines three
# one-line shims when it is not. In the checkout it is always there, so the
# shims had never been defined, let alone called. A fixture tree carrying
# keygen.sh but not its sibling makes that arm the one taken.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

KEYGEN_REL="defaults/.chezmoitemplates/functions/security/keygen.sh"

cov_setup_sandbox
trap cov_teardown_sandbox EXIT

# Not removed on exit: the aggregator resolves the symlink after the whole
# sweep has run, and a deleted fixture would resolve to nothing.
FX="${TMPDIR:-/tmp}"
FX="${FX%/}/dot-cov-fixtures/keygen-fallback"
rm -rf "$FX"
mkdir -p "$FX/$(dirname "$KEYGEN_REL")"
ln -s "$REPO_ROOT/$KEYGEN_REL" "$FX/$KEYGEN_REL"

test_start "keygen_defines_fallback_logging_without_its_sibling_library"
KG_OUT="$(
  cd "$FX" &&
    "${BASH:-bash}" -c '
      set -uo pipefail
      source '"$KEYGEN_REL"'
      log_info "info line"
      log_warning "warning line"
      log_error "error line"
    ' 2>&1 </dev/null
)"
assert_contains "[INFO] info line" "$KG_OUT" "the fallback log_info should be defined"
assert_contains "[WARNING] warning line" "$KG_OUT" \
  "the fallback log_warning should be defined"
assert_contains "[ERROR] error line" "$KG_OUT" \
  "the fallback log_error should be defined"

test_start "keygen_is_still_usable_with_the_fallback_logging"
KG_RC=0
KG_OUT="$(
  cd "$FX" &&
    "${BASH:-bash}" -c '
      set -uo pipefail
      source '"$KEYGEN_REL"'
      keygen --help
    ' 2>&1 </dev/null
)" || KG_RC=$?
assert_equals "0" "$KG_RC" "the function should still work with the shims in place"

print_summary
