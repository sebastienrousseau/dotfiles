#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# GTK3's CSS parser has no nesting (`&`) and no `transform` property. Each
# one logs a theme parsing error from every GTK3 app and the portal.
# shellcheck disable=SC1090,SC1091
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

GTK3_CSS="$REPO_ROOT/defaults/dot_config/gtk-3.0/gtk.css.tmpl"

test_start "gtk3_css_has_no_nested_selectors"
assert_equals "" "$(grep -n '&' "$GTK3_CSS")" "GTK3 CSS spells selectors out instead of nesting"

test_start "gtk3_css_has_no_transform"
assert_equals "" "$(grep -nE '^[[:space:]]*transform[[:space:]]*:' "$GTK3_CSS")" "GTK3 CSS has no transform property"

printf 'RESULTS:%s:%s:%s\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
