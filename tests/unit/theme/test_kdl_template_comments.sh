#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# KDL templates: a `//` comment line followed by a `{{- ... -}}` action
# loses its newline, so the next rendered node lands inside the comment.
# niri then rejects the whole file and falls back to its defaults.
# shellcheck disable=SC1090,SC1091
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

# _glued_comments <file>: print file:line for each comment the next action
# would swallow the newline of.
_glued_comments() {
  awk -v f="$1" '
    prev ~ /^[[:space:]]*\/\// && $0 ~ /^[[:space:]]*\{\{-.*-\}\}[[:space:]]*$/ {
      print f ":" NR
    }
    { prev = $0 }
  ' "$1"
}

test_start "kdl_glued_comment_detector_catches_the_pattern"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/kdl-comments.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
printf '// header\n{{- /* set */ -}}\nnode {\n}\n' >"$WORK/bad.kdl.tmpl"
printf '// header\n{{ /* set */ -}}\nnode {\n}\n' >"$WORK/good.kdl.tmpl"
printf '// header\n{{- if .x }}\nnode {\n}\n{{- end }}\n' >"$WORK/keeps.kdl.tmpl"
assert_equals "$WORK/bad.kdl.tmpl:2" "$(_glued_comments "$WORK/bad.kdl.tmpl")" "both-side trim after a comment is caught"
assert_equals "" "$(_glued_comments "$WORK/good.kdl.tmpl")" "right-only trim keeps the newline"
assert_equals "" "$(_glued_comments "$WORK/keeps.kdl.tmpl")" "left-only trim keeps the action's newline"

test_start "kdl_templates_keep_comment_newlines"
found=""
while IFS= read -r -d '' tmpl; do
  found+="$(_glued_comments "$tmpl")"
done < <(find "$REPO_ROOT/defaults" -name '*.kdl.tmpl' -type f -print0)
assert_equals "" "$found" "no KDL template glues a node onto a comment"

printf 'RESULTS:%s:%s:%s\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
