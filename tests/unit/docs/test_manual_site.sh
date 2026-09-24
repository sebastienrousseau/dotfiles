#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The web manual (doc.dotfiles.io/manual/) is built by ssg with the vendored
# Lucid theme. Checks, from cheapest to most expensive:
#   1. the .dotfiles palette in the theme clears WCAG AAA for every token
#      pair Lucid renders (7:1 text, 4.5:1 non-text), in both schemes;
#   2. the generator turns every chapter in _toc.yml into a page with no
#      chapter link left pointing at a .md source;
#   3. with ssg installed, the full build succeeds, every internal link and
#      fragment resolves, and ssg's own quality gate passes.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

STYLES="$REPO_ROOT/docs/manual-site/themes/lucid/_layouts/styles.css"
GEN="$REPO_ROOT/tools/docs/build-manual-site.py"

WORK="$(mktemp -d -t manual-site.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# ── 1. contrast ──────────────────────────────────────────────────────────
test_start "manual_site_palette_is_aaa"
contrast="$(
  python3 - "$STYLES" <<'PY'
import re, sys
css = open(sys.argv[1]).read()
def block(selector):
    m = re.search(re.escape(selector) + r"\s*\{(.*?)\}", css, re.S)
    return dict(re.findall(r"--([a-z-]+):\s*(#[0-9a-fA-F]{6})", m.group(1)))
light = block(':root[data-theme="light"]')
dark = block(':root[data-theme="dark"]')
def lin(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def lum(h):
    r, g, b = (int(h[i:i + 2], 16) for i in (1, 3, 5))
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
def ratio(a, b):
    x, y = sorted((lum(a), lum(b)), reverse=True)
    return (x + 0.05) / (y + 0.05)
TEXT, UI = 7.0, 4.5
pairs = [
    ("ink", "bg", TEXT), ("ink", "surface", TEXT), ("ink-soft", "bg", TEXT),
    ("ink-soft", "surface", TEXT), ("ink-muted", "bg", TEXT),
    ("ink-muted", "surface", TEXT), ("ink-muted", "surface-soft", TEXT),
    ("accent", "bg", TEXT), ("accent", "surface", TEXT),
    ("accent", "surface-soft", TEXT), ("accent-ink", "accent", TEXT),
    ("accent-hover", "surface", TEXT), ("on-accent-soft", "accent-soft", TEXT),
    ("focus", "bg", UI), ("focus", "surface", UI), ("line", "surface", UI),
    ("line", "bg", UI),
]
bad = [f"{name} --{f} on --{b}: {ratio(t[f], t[b]):.2f} < {need}"
       for name, t in (("light", light), ("dark", dark))
       for f, b, need in pairs if ratio(t[f], t[b]) < need]
print("\n".join(bad) if bad else "ok")
PY
)"
assert_equals "ok" "$contrast" "every Lucid token pair clears AAA in both schemes"

test_start "manual_site_dark_scheme_matches_media_query"
dark_attr="$(sed -n '/^:root\[data-theme="dark"\] {/,/^}/p' "$STYLES" | grep -- '--' | tr -d ' ')"
dark_media="$(sed -n '/^  :root:not(\[data-theme="light"\]) {/,/^  }/p' "$STYLES" | grep -- '--' | tr -d ' ')"
assert_equals "$dark_attr" "$dark_media" "explicit dark and system dark use the same tokens"

# ── 2. generator ─────────────────────────────────────────────────────────
python3 "$GEN" prepare "$REPO_ROOT/docs/manual" "$WORK/content" /manual/ >/dev/null
toc_files="$(grep -cE '^\s+- [0-9A-Z].*\.md$|^\s+- file:' "$REPO_ROOT/docs/manual/_toc.yml")"

test_start "manual_site_one_page_per_chapter"
generated="$(find "$WORK/content" -name '*.md' | wc -l | tr -d ' ')"
assert_equals "$((toc_files + 1))" "$generated" "every _toc.yml entry plus the landing page"

test_start "manual_site_no_md_chapter_links"
leftover="$(grep -rhoE '\]\([^)#:]*\.md(#[^)]*)?\)' "$WORK/content" | head -5)"
assert_equals "" "$leftover" "chapter links point at published URLs"

test_start "manual_site_pages_use_doc_layout"
without="$(find "$WORK/content" -name '*.md' -exec grep -L '^layout: "doc"$' {} +)"
assert_equals "" "$without" "every page renders with the Lucid doc layout"

# ── 3. full build ────────────────────────────────────────────────────────
if ! command -v "${SSG:-ssg}" >/dev/null 2>&1; then
  echo "  (ssg not installed: skipping the full build)"
else
  test_start "manual_site_builds"
  out="$(bash "$REPO_ROOT/tools/docs/build-manual-site.sh" --out "$WORK/site/manual" 2>&1)"
  rc=$?
  assert_equals "0" "$rc" "ssg build, anchoring and link check succeed"

  test_start "manual_site_links_resolve"
  assert_contains "all internal links resolve" "$out" "no broken internal link or fragment"

  test_start "manual_site_quality_gate"
  gate="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["passed_pillars"], d["total_pillars"])' \
    "$WORK/site/manual/quality-gate-report.json" 2>/dev/null)"
  assert_equals "10 10" "$gate" "ssg quality gate passes every pillar"

  test_start "manual_site_terminal_logo_and_palette"
  page="$WORK/site/manual/03-reference/01-dot-cli/index.html"
  assert_file_contains "$page" 'M20,19V7H4V19H20' "the terminal logo is in the masthead"
  test_start "manual_site_headings_anchored"
  assert_file_contains "$page" '<h2 id="global-flags">' "rendered headings carry ids"
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
