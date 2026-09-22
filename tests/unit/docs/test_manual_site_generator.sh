#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Edge and failure paths of tools/docs/build-manual-site.py, on synthetic
# manual trees and synthetic built sites (no ssg needed):
#   prepare  — a _toc.yml entry with no file, a page with no title, duplicate
#              headings, a link that resolves outside the repository, and a
#              tree that is not a git checkout;
#   finalize — pages without a prose block, headings that slug to nothing,
#              and every class of broken link it must refuse;
#   main     — bad invocations.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

GEN="$REPO_ROOT/tools/docs/build-manual-site.py"
WORK="$(mktemp -d -t manual-gen.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# new_manual <name> — a minimal repo/docs/manual tree (not a git checkout).
new_manual() {
  local root="$WORK/$1/repo/docs/manual"
  mkdir -p "$root/01-concepts"
  printf '# Home\n\nThe landing page.\n' >"$root/index.md"
  printf 'sections:\n  - group: "Concepts"\n    prefix: "01-concepts"\n    files:\n      - 01-a.md\n' >"$root/_toc.yml"
  printf '%s\n' "$root"
}

gen() { python3 "$GEN" "$@" 2>&1; }

# ── prepare ──────────────────────────────────────────────────────────────
test_start "manual_gen_missing_toc_file_fails"
m="$(new_manual missing)"
out="$(gen prepare "$m" "$WORK/missing/out" /manual/)"
rc=$?
assert_equals "1" "$rc" "a _toc.yml entry without a file fails the build"
test_start "manual_gen_missing_toc_file_named"
assert_contains "names missing files: 01-concepts/01-a.md" "$out" "the missing file is named"

test_start "manual_gen_untitled_page_fails"
m="$(new_manual untitled)"
printf 'No heading here.\n' >"$m/01-concepts/01-a.md"
out="$(gen prepare "$m" "$WORK/untitled/out" /manual/)"
rc=$?
assert_equals "1" "$rc" "a page without a '# ' title fails the build"
test_start "manual_gen_untitled_page_named"
assert_contains "01-concepts/01-a.md has no '# ' title" "$out" "the untitled page is named"

m="$(new_manual ok)"
cat >"$m/01-concepts/01-a.md" <<'MD'
# Chapter A

## Usage

[outside](../../../../../../../../elsewhere.md) and [repo file](../../../README.md)

## Usage

## Usage
MD
: >"$WORK/ok/repo/README.md"
out="$(gen prepare "$m" "$WORK/ok/out" /manual/)"
rc=$?
page="$WORK/ok/out/01-concepts/01-a.md"
test_start "manual_gen_prepare_succeeds_outside_git"
assert_equals "0" "$rc" "prepare works in a tree that is not a git checkout"
test_start "manual_gen_duplicate_headings_get_unique_ids"
assert_file_contains "$page" '#usage-3' "a third duplicate heading gets -3"
test_start "manual_gen_outside_link_left_alone"
assert_file_contains "$page" '(../../../../../../../../elsewhere.md)' "a link outside the repo is not rewritten"
test_start "manual_gen_repo_link_points_at_github"
assert_file_contains "$page" '/blob/main/README.md' "a repo file outside the manual links to GitHub"
test_start "manual_gen_date_falls_back_outside_git"
assert_file_contains "$page" "date: \"$(date +%Y-%m-%d)\"" "no git history falls back to today"

# ── finalize ─────────────────────────────────────────────────────────────
site="$WORK/site"
mkdir -p "$site/a" "$site/b" "$site/c"
cat >"$site/a/index.html" <<'HTML'
<html><body><h1 id="a">A</h1><div class="prose"><h2>!!!</h2><h2>Good</h2><h3>Good</h3></div>
<nav class="pager"></nav><a href="https://example.com/x">ext</a><a href="#good">ok</a></body></html>
HTML
printf '<html><body><p>no prose block</p></body></html>\n' >"$site/b/index.html"
cat >"$site/c/index.html" <<'HTML'
<html><body><div class="prose"><h2>C</h2></div><nav class="pager"></nav>
<a href="#nowhere">x</a><a href="/manual/missing/">x</a><a href="/manual/a/#absent">x</a><a href="/manual/a/?q=1#good">x</a></body></html>
HTML
out="$(gen finalize "$site" /manual/)"
rc=$?
test_start "manual_gen_finalize_reports_problems"
assert_equals "1" "$rc" "broken links fail the build"
test_start "manual_gen_finalize_dangling_fragment"
assert_contains "c/index.html: dangling fragment #nowhere" "$out" "an in-page fragment with no target"
test_start "manual_gen_finalize_broken_link"
assert_contains "c/index.html: broken link /manual/missing/" "$out" "a link to a page that does not exist"
test_start "manual_gen_finalize_missing_remote_fragment"
assert_contains "c/index.html: /manual/a/#absent has no #absent" "$out" "a fragment missing on the target page"
test_start "manual_gen_finalize_query_link_resolves"
assert_output_not_contains "?q=1" printf '%s' "$out"
test_start "manual_gen_finalize_unsluggable_heading_kept"
assert_file_contains "$site/a/index.html" '<h2>!!!</h2>' "a heading with no slug is left without an id"
test_start "manual_gen_finalize_deeper_heading_deduplicated"
assert_file_contains "$site/a/index.html" '<h3 id="good-2">' "h3 ids avoid the h2 ids"
test_start "manual_gen_finalize_page_without_prose_untouched"
assert_equals "<html><body><p>no prose block</p></body></html>" "$(cat "$site/b/index.html")" "no prose block, no change"

# ── main ─────────────────────────────────────────────────────────────────
test_start "manual_gen_usage_error"
gen bogus >/dev/null
assert_equals "64" "$?" "an unknown mode is a usage error"
test_start "manual_gen_usage_wrong_arity"
gen prepare only-one-arg >/dev/null
assert_equals "64" "$?" "a wrong argument count is a usage error"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
