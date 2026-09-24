#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# doc.dotfiles.io is built by tools/docs/build-site.sh with ssg and the
# vendored Lucid theme (the docs pages, the landing page and the manual under
# /manual/). With ssg installed this builds the site and checks what the
# published artefact actually contains:
#
#   * one page per docs/_toc.yml entry, plus the landing page and the manual;
#   * the landing page uses Lucid's index layout, doc pages its doc layout;
#   * every page loads Lucid's own stylesheets and nothing from MkDocs;
#   * no MkDocs-only markup survives into the HTML;
#   * ssg's injected highlight stylesheet (which follows the OS colour
#     scheme, not the theme toggle) is gone;
#   * each script's SRI hash matches the file it names;
#   * the custom-domain CNAME ships at the root.
#
# Without ssg the checks are skipped with a note.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/site-build.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
SITE="$WORK/site"

if ! command -v "${SSG:-ssg}" >/dev/null 2>&1; then
  test_start "site_build_needs_ssg"
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (skipped: ssg not installed)"
  echo ""
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 0
fi

rc=0
bash "$REPO_ROOT/tools/docs/build-site.sh" --out "$SITE" >"$WORK/build.log" 2>&1 || rc=$?

test_start "site_builds_and_every_link_resolves"
assert_equals "0" "$rc" "build-site.sh succeeds, including the whole-site link check ($(tail -1 "$WORK/build.log"))"

test_start "site_has_one_page_per_toc_entry"
toc_n="$(grep -cE '^      - ' "$REPO_ROOT/docs/_toc.yml")"
manual_n="$(find "$SITE/manual" -name index.html | wc -l | tr -d ' ')"
all_n="$(find "$SITE" -name index.html | wc -l | tr -d ' ')"
assert_equals "$((toc_n + 1 + manual_n))" "$all_n" "toc pages + landing + manual pages"

test_start "site_landing_uses_lucid_index_layout"
assert_file_contains "$SITE/index.html" 'class="hero"' "the landing page renders Lucid's hero"

test_start "site_doc_pages_use_lucid_doc_layout"
assert_file_contains "$SITE/guides/INSTALL/index.html" 'class="doc-side"' "a docs page has Lucid's side navigation"

test_start "site_doc_page_marks_itself_current"
assert_file_contains "$SITE/guides/INSTALL/index.html" 'aria-current="page">Install<' "the side nav marks the current page"

test_start "site_every_page_loads_lucid_styles"
missing="$(find "$SITE" -name index.html -exec grep -L 'href="[^"]*styles\.[0-9a-f]*\.css"' {} + | wc -l | tr -d ' ')"
assert_equals "0" "$missing" "every page links Lucid's fingerprinted stylesheet"

test_start "site_has_no_mkdocs_leftovers"
# Outside code blocks: an article that quotes MkDocs markup as an example
# is content, not a leftover.
leftovers="$(
  python3 - "$SITE" <<'PY'
import re, sys
from pathlib import Path
hits = []
for page in Path(sys.argv[1]).rglob("index.html"):
    text = re.sub(r"<pre.*?</pre>|<code.*?</code>", "", page.read_text(), flags=re.S)
    if re.search(r":material-[a-z-]+:|grid cards|md-typeset|assets/stylesheets/main\.", text):
        hits.append(page)
print(len(hits))
PY
)"
assert_equals "0" "$leftovers" "no MkDocs icons, card grids or Material stylesheets in the HTML"

test_start "site_drops_the_os_scheme_highlight_sheet"
hl="$( (
  grep -rl 'highlight\.css' "$SITE" --include=index.html
  find "$SITE" -name 'highlight*.css'
) | wc -l | tr -d ' ')"
assert_equals "0" "$hl" "no highlight stylesheet link or file"

test_start "site_sri_hashes_match_their_files"
sri="$(
  python3 - "$SITE" <<'PY'
import base64, hashlib, re, sys
from pathlib import Path
site = Path(sys.argv[1])
bad = set()
for page in site.rglob("index.html"):
    for src, algo, digest in re.findall(r'<script src="([^"]+)" integrity="(sha\d+)-([^"]+)"', page.read_text()):
        f = site / src.lstrip("/")
        want = base64.b64encode(hashlib.new(algo, f.read_bytes()).digest()).decode() if f.is_file() else None
        if want != digest:
            bad.add(src)
print(",".join(sorted(bad)) or "ok")
PY
)"
assert_equals "ok" "$sri" "every script's integrity attribute matches the file"

test_start "site_ships_the_cname"
assert_equals "doc.dotfiles.io" "$(tr -d '[:space:]' <"$SITE/CNAME" 2>/dev/null)" "custom domain at the root"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
