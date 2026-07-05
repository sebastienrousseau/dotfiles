#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# build-manual.sh — Generate dotfiles documentation in 9 formats.
#
# Produces from docs/manual/ Markdown sources:
#   HTML (single page)              with search, skip-links, ARIA
#   HTML (multi-page tree)          with edit-this-page + last-modified
#   HTML gzipped (single)
#   HTML gzipped (tar.gz, multi-page)
#   EPUB 3
#   PDF (if xelatex available)      with cover page and metadata
#   ASCII text
#   ASCII gzipped
#   Markdown source (tar.gz)
#   SHA256SUMS
#   Landing page                    with FAQ JSON-LD, Open Graph, search
#   search-index.json               client-side search index
#
# Usage:
#   bash tools/docs/build-manual.sh           # full build
#   bash tools/docs/build-manual.sh --fast    # skip PDF
#   bash tools/docs/build-manual.sh --clean   # remove _build/manual first
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_DIR="$REPO_ROOT/docs/manual"
BUILD_DIR="$REPO_ROOT/_build/manual"
HTML_DIR="$BUILD_DIR/html"
VERSION="$(awk -F'"' '/^dotfiles_version/ {print $2; exit}' "$REPO_ROOT/defaults/.chezmoidata.toml")"
TITLE=".dotfiles Manual"
SUBTITLE="A Trusted Agent Workstation for macOS, Linux, and WSL"
REPO_URL="https://github.com/sebastienrousseau/dotfiles"
MANUAL_URL="https://sebastienrousseau.github.io/dotfiles/manual"
BUILD_DATE="$(date +%Y-%m-%d)"

FAST=false
CLEAN=false
for arg in "$@"; do
  case "$arg" in
    --fast) FAST=true ;;
    --clean) CLEAN=true ;;
    --help | -h)
      grep '^#' "$0" | sed 's/^# //; s/^#//'
      exit 0
      ;;
  esac
done

# -----------------------------------------------------------------------------
# Utilities
# -----------------------------------------------------------------------------

log() { printf '[manual] %s\n' "$*"; }
warn() { printf '[manual] WARN: %s\n' "$*" >&2; }
die() {
  printf '[manual] ERROR: %s\n' "$*" >&2
  exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }

human_size() {
  local bytes="$1"
  if [[ $bytes -lt 1024 ]]; then
    echo "${bytes}B"
  elif [[ $bytes -lt 1048576 ]]; then
    echo "$((bytes / 1024))K"
  else
    echo "$((bytes / 1048576))M"
  fi
}

file_size() {
  [[ -f "$1" ]] || return 1
  stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Prerequisites
# -----------------------------------------------------------------------------

have pandoc || die "pandoc is required. Install via: brew install pandoc (or apt/dnf)"
have gzip || die "gzip is required"
have tar || die "tar is required"

PDF_SUPPORT=false
if have xelatex || have tectonic; then
  PDF_SUPPORT=true
fi

# -----------------------------------------------------------------------------
# Clean
# -----------------------------------------------------------------------------

if $CLEAN; then
  log "cleaning $BUILD_DIR"
  rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR" "$HTML_DIR"

# -----------------------------------------------------------------------------
# File discovery
# -----------------------------------------------------------------------------

collect_files() {
  local files=()
  [[ -f "$SOURCE_DIR/00-introduction.md" ]] && files+=("$SOURCE_DIR/00-introduction.md")
  for dir in 01-concepts 02-tutorials 03-reference 04-cookbook 05-appendices; do
    if [[ -d "$SOURCE_DIR/$dir" ]]; then
      while IFS= read -r f; do files+=("$f"); done < <(find "$SOURCE_DIR/$dir" -maxdepth 1 -name '*.md' -type f | sort)
    fi
  done
  [[ -f "$SOURCE_DIR/concept-index.md" ]] && files+=("$SOURCE_DIR/concept-index.md")
  [[ -f "$SOURCE_DIR/command-index.md" ]] && files+=("$SOURCE_DIR/command-index.md")
  printf '%s\n' "${files[@]}"
}

FILES_LIST="$(collect_files)"
TOTAL_FILES=$(echo "$FILES_LIST" | wc -l | tr -d ' ')
log "found $TOTAL_FILES manual files"

# -----------------------------------------------------------------------------
# Auto-generate concept + command indexes
# -----------------------------------------------------------------------------

build_indexes() {
  log "generating concept-index"
  {
    echo "# Concept Index"
    echo ""
    echo "Alphabetical list of concepts covered in the manual."
    echo ""
    grep -rhE '^## [A-Z]' "$SOURCE_DIR"/{01-concepts,02-tutorials,03-reference,04-cookbook,05-appendices}/*.md 2>/dev/null |
      sed 's/^## //' |
      sort -u |
      awk '{ print "- " $0 }'
  } >"$SOURCE_DIR/concept-index.md.gen"
  mv "$SOURCE_DIR/concept-index.md.gen" "$SOURCE_DIR/concept-index.md"

  log "generating command-index"
  {
    echo "# Command Index"
    echo ""
    echo "Alphabetical list of \`dot\` subcommands referenced in the manual."
    echo ""
    # shellcheck disable=SC2016 # literal grep pattern; single quotes intentional
    grep -rhoE '`dot [a-z][a-z-]+( [a-z-]+)?`' "$SOURCE_DIR"/*.md "$SOURCE_DIR"/*/*.md 2>/dev/null |
      sort -u |
      awk '{ print "- " $0 }'
  } >"$SOURCE_DIR/command-index.md.gen"
  mv "$SOURCE_DIR/command-index.md.gen" "$SOURCE_DIR/command-index.md"
}

build_indexes

# -----------------------------------------------------------------------------
# Assemble master Markdown
# -----------------------------------------------------------------------------

MASTER_MD="$BUILD_DIR/_master.md"
{
  echo "---"
  echo "title: $TITLE"
  echo "subtitle: $SUBTITLE"
  echo "version: $VERSION"
  echo "date: $BUILD_DATE"
  echo "lang: en"
  echo "author: Sebastien Rousseau"
  echo "publisher: EUXIS"
  echo "rights: MIT License"
  echo "---"
  echo ""
  echo "$FILES_LIST" | while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    sed -E '
      s|\[([^]]+)\]\(\.\./?([0-9]+-[a-z]+/[0-9A-Z]+-[a-z-]+)\.md(#[a-z0-9-]+)?\)|[\1](\3)|g
      s|\[([^]]+)\]\(([0-9A-Z]+-[a-z-]+)\.md(#[a-z0-9-]+)?\)|[\1](\3)|g
    ' "$f"
    echo ""
    echo ""
  done
} >"$MASTER_MD"

MASTER_SIZE=$(wc -c <"$MASTER_MD")
log "master markdown: $(human_size "$MASTER_SIZE")"

# -----------------------------------------------------------------------------
# Enhanced CSS with accessibility + search
# -----------------------------------------------------------------------------

write_css() {
  # Apple-inspired design system, mirroring dotfiles.io
  # (VitePress + custom Apple-style theme). Token names align with
  # the public site so an upstream redesign here travels there too.
  cat >"$BUILD_DIR/style.css" <<'CSSEOF'
:root {
  /* Surfaces */
  --bg: #ffffff;
  --bg-secondary: #f5f5f7;
  --bg-elevated: #ffffff;
  --bg-nav: rgba(255, 255, 255, 0.72);
  --bg-footer: #f5f5f7;

  /* Text */
  --text-primary: #1d1d1f;
  --text-secondary: #494950;
  --text-muted: #6e6e73;
  --footer-title: #1d1d1f;
  --footer-text: #494950;
  --footer-link: #3b3b40;

  /* Borders & dividers */
  --border: #d2d2d7;
  --divider: #e5e5ea;

  /* Links & focus */
  --link: #004fa3;
  --link-hover: #003d80;
  --focus-ring: #0058b0;

  /* Brand / accent */
  --brand: #0071e3;
  --brand-hover: #005bb5;
  --brand-text: #ffffff;

  /* Code */
  --code-bg: #f5f5f7;
  --code-border: #e5e5ea;
  --code-text: #1d1d1f;
  --code-keyword: #aa0d91;
  --code-string: #c41a16;
  --code-comment: #6e6e73;

  /* Effects */
  --shadow-card: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04);
  --shadow-card-hover: 0 4px 12px rgba(0,0,0,0.08);
  --radius: 12px;
  --radius-sm: 8px;
  --radius-pill: 980px;

  /* Type */
  --font-sans: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", "Inter", Roboto, "Helvetica Neue", Helvetica, Arial, sans-serif;
  --font-mono: "SF Mono", SFMono-Regular, ui-monospace, "JetBrains Mono", Menlo, Consolas, monospace;
  --font-display: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Inter", system-ui, sans-serif;

  /* Layout */
  --content-max: 980px;
  --nav-height: 56px;
}

@media (prefers-color-scheme: dark) {
  :root {
    --bg: #000000;
    --bg-secondary: #1d1d1f;
    --bg-elevated: #1d1d1f;
    --bg-nav: rgba(0, 0, 0, 0.72);
    --bg-footer: #1d1d1f;

    --text-primary: #f5f5f7;
    --text-secondary: #acacb0;
    --text-muted: #86868b;
    --footer-title: #f5f5f7;
    --footer-text: #c0c0c5;
    --footer-link: #d0d0d5;

    --border: #424245;
    --divider: #2c2c2e;

    --link: #4dadff;
    --link-hover: #6fc0ff;
    --focus-ring: #4dadff;

    --brand: #2997ff;
    --brand-hover: #0a84ff;

    --code-bg: #1d1d1f;
    --code-border: #2c2c2e;
    --code-text: #f5f5f7;
    --code-keyword: #ff7ab2;
    --code-string: #fc6a5d;
    --code-comment: #86868b;

    --shadow-card: 0 1px 3px rgba(0,0,0,0.5), 0 1px 2px rgba(0,0,0,0.4);
    --shadow-card-hover: 0 4px 12px rgba(0,0,0,0.6);
  }
}

/* ── Reset / base ─────────────────────────────────────────────────────── */

*, *::before, *::after { box-sizing: border-box; }

html { scroll-behavior: smooth; -webkit-text-size-adjust: 100%; }

body {
  margin: 0;
  font-family: var(--font-sans);
  font-size: 17px;
  font-weight: 400;
  line-height: 1.6;
  color: var(--text-primary);
  background: var(--bg);
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

/* ── Accessibility ──────────────────────────────────────────────────────── */

.skip-link {
  position: absolute;
  left: -9999px;
  top: 0;
  background: var(--brand);
  color: var(--brand-text);
  padding: 0.6rem 1rem;
  z-index: 1000;
  text-decoration: none;
  font-weight: 500;
  border-radius: 0 0 var(--radius-sm) 0;
}
.skip-link:focus { left: 0; }

*:focus-visible {
  outline: 2px solid var(--focus-ring);
  outline-offset: 2px;
  border-radius: 4px;
}

/* ── Top navigation bar (Apple-style) ───────────────────────────────────── */

.site-nav {
  position: sticky;
  top: 0;
  height: var(--nav-height);
  background: var(--bg-nav);
  backdrop-filter: saturate(180%) blur(20px);
  -webkit-backdrop-filter: saturate(180%) blur(20px);
  border-bottom: 1px solid var(--divider);
  z-index: 100;
}
.site-nav-inner {
  max-width: var(--content-max);
  margin: 0 auto;
  padding: 0 1.25rem;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1.5rem;
  font-size: 0.875rem;
}
.site-nav .brand-link {
  font-weight: 600;
  color: var(--text-primary);
  text-decoration: none;
  letter-spacing: -0.01em;
}
.site-nav .brand-link::before {
  content: "◈";
  display: inline-block;
  margin-right: 0.5rem;
  color: var(--brand);
}
.site-nav-links {
  display: flex;
  gap: 1.5rem;
  align-items: center;
  list-style: none;
  margin: 0;
  padding: 0;
}
.site-nav-links a {
  color: var(--text-secondary);
  text-decoration: none;
  font-weight: 400;
  transition: color 0.15s ease;
}
.site-nav-links a:hover { color: var(--text-primary); }

/* ── Layout ─────────────────────────────────────────────────────────────── */

body > main, .content, article {
  max-width: var(--content-max);
  margin: 0 auto;
  padding: 2.5rem 1.5rem 4rem;
}

/* ── Typography ─────────────────────────────────────────────────────────── */

h1, h2, h3, h4, h5, h6 {
  color: var(--text-primary);
  font-family: var(--font-display);
  font-weight: 600;
  line-height: 1.15;
  letter-spacing: -0.02em;
  margin: 2.5rem 0 1rem;
}
h1 {
  font-size: clamp(2rem, 4vw, 2.75rem);
  font-weight: 700;
  letter-spacing: -0.025em;
  margin-top: 1rem;
}
h2 {
  font-size: clamp(1.5rem, 2.6vw, 1.875rem);
  margin-top: 3rem;
  padding-top: 1rem;
  border-top: 1px solid var(--divider);
}
h3 { font-size: 1.25rem; margin-top: 2rem; }
h4 { font-size: 1.0625rem; color: var(--text-secondary); }

p { margin: 0 0 1rem; }

a { color: var(--link); text-decoration: none; transition: color 0.15s ease; }
a:hover { color: var(--link-hover); text-decoration: underline; text-underline-offset: 3px; }

ul, ol { padding-left: 1.5rem; margin: 0 0 1rem; }
li { margin: 0.25rem 0; }

blockquote {
  border-left: 3px solid var(--brand);
  padding: 0.5rem 1.25rem;
  margin: 1.5rem 0;
  background: var(--bg-secondary);
  border-radius: 0 var(--radius-sm) var(--radius-sm) 0;
  color: var(--text-secondary);
}

hr {
  border: 0;
  border-top: 1px solid var(--divider);
  margin: 2.5rem 0;
}

/* ── Code ───────────────────────────────────────────────────────────────── */

code {
  background: var(--code-bg);
  color: var(--code-text);
  padding: 0.125rem 0.375rem;
  border-radius: 4px;
  font-family: var(--font-mono);
  font-size: 0.875em;
  border: 1px solid var(--code-border);
}
pre {
  background: var(--code-bg);
  color: var(--code-text);
  padding: 1.125rem 1.25rem;
  border-radius: var(--radius-sm);
  overflow-x: auto;
  border: 1px solid var(--code-border);
  font-size: 0.875rem;
  line-height: 1.5;
  margin: 1.25rem 0;
}
pre code { background: transparent; padding: 0; border: 0; font-size: inherit; }

/* ── Tables ─────────────────────────────────────────────────────────────── */

table {
  border-collapse: collapse;
  margin: 1.5rem 0;
  width: 100%;
  font-size: 0.9375rem;
}
th, td {
  border-bottom: 1px solid var(--divider);
  padding: 0.625rem 1rem;
  text-align: left;
  vertical-align: top;
}
thead th {
  background: var(--bg-secondary);
  font-weight: 600;
  border-bottom: 1px solid var(--border);
  font-size: 0.875rem;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--text-secondary);
}
tbody tr:hover { background: var(--bg-secondary); }

/* ── Buttons ────────────────────────────────────────────────────────────── */

.btn, button.btn, a.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.625rem 1.5rem;
  background: var(--brand);
  color: var(--brand-text);
  border: 0;
  border-radius: var(--radius-pill);
  font-family: inherit;
  font-size: 0.9375rem;
  font-weight: 500;
  text-decoration: none;
  cursor: pointer;
  transition: background-color 0.15s ease, transform 0.05s ease;
  line-height: 1.2;
}
.btn:hover { background: var(--brand-hover); color: var(--brand-text); text-decoration: none; }
.btn:active { transform: scale(0.98); }
.btn-secondary {
  background: var(--bg-secondary);
  color: var(--text-primary);
  border: 1px solid var(--border);
}
.btn-secondary:hover { background: var(--bg-elevated); color: var(--text-primary); }

/* ── Search widget ──────────────────────────────────────────────────────── */

.search-widget {
  margin: 1.5rem 0 2.5rem;
  padding: 1rem 1.25rem;
  background: var(--bg-secondary);
  border: 1px solid var(--divider);
  border-radius: var(--radius);
}
.search-widget label {
  display: block;
  font-size: 0.8125rem;
  font-weight: 500;
  color: var(--text-secondary);
  margin-bottom: 0.5rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
.search-widget input {
  width: 100%;
  padding: 0.625rem 0.875rem;
  font-size: 0.9375rem;
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  background: var(--bg);
  color: var(--text-primary);
  font-family: inherit;
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}
.search-widget input:focus {
  outline: 0;
  border-color: var(--focus-ring);
  box-shadow: 0 0 0 3px rgba(0, 113, 227, 0.18);
}
.search-results {
  margin-top: 0.875rem;
  max-height: 320px;
  overflow-y: auto;
  list-style: none;
  padding: 0;
}
.search-results li {
  padding: 0.625rem 0;
  border-bottom: 1px solid var(--divider);
}
.search-results li:last-child { border-bottom: none; }
.search-results a { text-decoration: none; display: block; color: var(--text-primary); }
.search-results a:hover { color: var(--link); }
.search-results .hit-section { font-size: 0.8125rem; color: var(--text-muted); margin-top: 0.125rem; }

/* ── Page footer / edit link ────────────────────────────────────────────── */

.page-footer {
  margin-top: 4rem;
  padding-top: 1.5rem;
  border-top: 1px solid var(--divider);
  font-size: 0.875rem;
  color: var(--text-muted);
}
.page-footer a { color: var(--text-secondary); }

/* ── Landing: hero, features, formats ───────────────────────────────────── */

.hero {
  text-align: center;
  padding: 4rem 1rem 3rem;
  border-bottom: 1px solid var(--divider);
  margin-bottom: 3rem;
}
.hero h1 {
  font-size: clamp(2.25rem, 5vw, 3.5rem);
  font-weight: 700;
  letter-spacing: -0.03em;
  margin: 0 0 1rem;
}
.hero .tagline {
  font-size: clamp(1.0625rem, 1.6vw, 1.25rem);
  color: var(--text-secondary);
  max-width: 640px;
  margin: 0 auto 2rem;
  font-weight: 400;
}
.hero-actions {
  display: flex;
  gap: 0.75rem;
  justify-content: center;
  flex-wrap: wrap;
  margin-top: 1.5rem;
}

.version-badge {
  display: inline-block;
  background: var(--bg-secondary);
  color: var(--text-secondary);
  padding: 0.25rem 0.75rem;
  border-radius: var(--radius-pill);
  font-size: 0.75rem;
  font-weight: 500;
  letter-spacing: 0.02em;
  margin-left: 0.5rem;
  border: 1px solid var(--divider);
}

.features {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 1rem;
  margin: 2.5rem 0;
}
.feature-card {
  background: var(--bg-secondary);
  border: 1px solid var(--divider);
  padding: 1.5rem;
  border-radius: var(--radius);
  transition: box-shadow 0.2s ease, transform 0.2s ease;
}
.feature-card:hover {
  box-shadow: var(--shadow-card-hover);
  transform: translateY(-1px);
}
.feature-card h3 {
  margin: 0 0 0.5rem;
  font-size: 1.0625rem;
  letter-spacing: -0.01em;
}
.feature-card p {
  margin: 0;
  font-size: 0.9375rem;
  color: var(--text-secondary);
  line-height: 1.5;
}

.formats { margin: 2.5rem 0; list-style: none; padding: 0; }
.formats li {
  display: flex;
  align-items: baseline;
  gap: 0.75rem;
  margin: 0.625rem 0;
  padding: 0.5rem 0.75rem;
  border-radius: var(--radius-sm);
  transition: background-color 0.15s ease;
}
.formats li:hover { background: var(--bg-secondary); }
.formats a { font-weight: 500; }
.size { color: var(--text-muted); font-size: 0.8125rem; margin-left: auto; font-variant-numeric: tabular-nums; }

/* ── Footer (page-bottom site footer for the landing) ─────────────────── */

.site-footer {
  background: var(--bg-footer);
  border-top: 1px solid var(--divider);
  margin-top: 4rem;
  padding: 2.5rem 1.5rem;
  font-size: 0.8125rem;
  color: var(--footer-text);
}
.site-footer .footer-inner {
  max-width: var(--content-max);
  margin: 0 auto;
}
.site-footer a { color: var(--footer-link); }
.site-footer a:hover { color: var(--text-primary); }

/* ── Responsive tweaks ──────────────────────────────────────────────────── */

@media (max-width: 640px) {
  .site-nav-links { gap: 0.875rem; font-size: 0.8125rem; }
  body { font-size: 16px; }
  .hero { padding: 2.5rem 1rem 2rem; }
}

/* ── Print ──────────────────────────────────────────────────────────────── */

@media print {
  .site-nav, .search-widget, .skip-link, .hero-actions { display: none; }
  body { font-size: 11pt; color: #000; background: #fff; }
  a { color: inherit; text-decoration: underline; }
  pre, code { background: #f5f5f7; border-color: #d2d2d7; }
}
CSSEOF
}

# -----------------------------------------------------------------------------
# Client-side search index + script
# -----------------------------------------------------------------------------

build_search_index() {
  log "building search index"
  local idx="$BUILD_DIR/search-index.json"

  # Extract headings + surrounding text from each manual file
  python3 - <<PYEOF >"$idx"
import json, os, re
SOURCE_DIR = "$SOURCE_DIR"
REPO_ROOT = "$REPO_ROOT"
entries = []
files = []
for dirpath, _, filenames in os.walk(SOURCE_DIR):
    for f in filenames:
        if f.endswith('.md'):
            files.append(os.path.join(dirpath, f))
files.sort()

for path in files:
    rel = os.path.relpath(path, SOURCE_DIR)
    html_path = rel.replace('.md', '.html')
    with open(path) as fh:
        lines = fh.readlines()
    title = ''
    for line in lines:
        if line.startswith('# '):
            title = line[2:].strip()
            break
    current_section = title
    buf = []
    for line in lines:
        if line.startswith('## '):
            if buf:
                entries.append({
                    'file': html_path,
                    'title': title,
                    'section': current_section,
                    'text': ' '.join(buf)[:500],
                })
            current_section = line[3:].strip()
            buf = []
        elif line.startswith('### '):
            if buf:
                entries.append({
                    'file': html_path,
                    'title': title,
                    'section': current_section,
                    'text': ' '.join(buf)[:500],
                })
            current_section = line[4:].strip()
            buf = []
        elif line.strip() and not line.startswith('#'):
            buf.append(line.strip())
    if buf:
        entries.append({
            'file': html_path,
            'title': title,
            'section': current_section,
            'text': ' '.join(buf)[:500],
        })

print(json.dumps(entries))
PYEOF

  local sz
  sz=$(file_size "$idx")
  log "  → search-index.json ($(human_size "$sz"), $(python3 -c "import json; print(len(json.load(open('$idx'))))") entries)"

  # Search widget JS
  cat >"$BUILD_DIR/search.js" <<'JSEOF'
(function() {
  const input = document.getElementById('manual-search');
  const results = document.getElementById('manual-search-results');
  if (!input || !results) return;

  let index = [];
  fetch('search-index.json').then(r => r.json()).then(data => { index = data; });

  let debounce;
  input.addEventListener('input', () => {
    clearTimeout(debounce);
    debounce = setTimeout(() => {
      const q = input.value.trim().toLowerCase();
      if (q.length < 2) { results.innerHTML = ''; return; }
      const terms = q.split(/\s+/);
      const hits = index.filter(e => {
        const haystack = (e.title + ' ' + e.section + ' ' + e.text).toLowerCase();
        return terms.every(t => haystack.includes(t));
      }).slice(0, 10);
      results.innerHTML = hits.length
        ? '<ul class="search-results">' + hits.map(h =>
            `<li><a href="${h.file}"><strong>${h.title}</strong> <span class="hit-section">— ${h.section}</span></a></li>`
          ).join('') + '</ul>'
        : '<p class="search-results">No results.</p>';
    }, 150);
  });
})();
JSEOF
  log "  → search.js"
}

# -----------------------------------------------------------------------------
# HTML single page
# -----------------------------------------------------------------------------

build_html_single() {
  local out="$BUILD_DIR/dotfiles.html"
  log "building HTML single page"
  write_css
  pandoc "$MASTER_MD" \
    -f markdown \
    -t html5 \
    --standalone \
    --toc \
    --toc-depth=3 \
    --section-divs \
    --metadata lang=en \
    --metadata title="$TITLE" \
    --metadata subtitle="$SUBTITLE — v$VERSION" \
    --css=style.css \
    -o "$out"

  # Inject skip link + top-nav + ARIA landmarks (matches dotfiles.io UX)
  local nav_html
  nav_html="<nav class=\"site-nav\" aria-label=\"Site\"><div class=\"site-nav-inner\"><a href=\"./index.html\" class=\"brand-link\">dotfiles<span class=\"version-badge\">v$VERSION</span></a><ul class=\"site-nav-links\"><li><a href=\"./index.html\">Home</a></li><li><a href=\"$REPO_URL\">GitHub</a></li></ul></div></nav>"
  sed -i.bak "
    s|<body>|<body>\\
<a href=\"#main\" class=\"skip-link\">Skip to main content</a>\\
$nav_html\\
<main id=\"main\" role=\"main\">|
    s|</body>|</main>\\
</body>|
  " "$out" && rm -f "$out.bak"

  local sz
  sz=$(file_size "$out")
  log "  → dotfiles.html ($(human_size "$sz"))"
}

# -----------------------------------------------------------------------------
# HTML multi-page (one HTML per source file) with edit links + last-modified
# -----------------------------------------------------------------------------

build_html_multi() {
  log "building HTML multi-page"
  write_css
  echo "$FILES_LIST" | while IFS= read -r f; do
    local rel_src="${f#$SOURCE_DIR/}"
    local basename
    basename="$(basename "$f" .md)"
    local outpath="$HTML_DIR/${rel_src%.md}.html"
    mkdir -p "$(dirname "$outpath")"

    # Compute edit URL + last-modified date
    local edit_url="$REPO_URL/edit/main/docs/manual/$rel_src"
    local last_modified
    last_modified="$(cd "$REPO_ROOT" && git log -1 --format='%ai' -- "docs/manual/$rel_src" 2>/dev/null | cut -d' ' -f1)"
    [[ -z "$last_modified" ]] && last_modified="$BUILD_DATE"

    # Footer with edit link + last-modified
    local footer
    footer=$(
      cat <<FOOT
<div class="page-footer">
  <p>Last updated: $last_modified · <a href="$edit_url">Edit this page on GitHub</a></p>
  <p><a href="../index.html">← Manual home</a></p>
</div>
FOOT
    )

    pandoc "$f" \
      -f markdown \
      -t html5 \
      --standalone \
      --toc \
      --toc-depth=3 \
      --metadata lang=en \
      --metadata title="$basename" \
      --css=../style.css \
      --include-after-body=<(echo "$footer") \
      -o "$outpath"

    # Inject skip link + top-nav + ARIA.
    # `up` = path back to BUILD_DIR (landing root). For html/foo.html,
    # that's `../`. For html/a/b.html it's `../../` (one ../ per
    # slash in rel_src). `manual_up` = path back to html/ (drops one
    # leading ../ from `up`).
    local sub_depth="${rel_src//[^\/]/}"
    local up="../"
    [[ -n "$sub_depth" ]] && for _ in $(seq ${#sub_depth}); do up="../$up"; done
    local manual_up="${up#../}"
    local sub_nav
    sub_nav="<nav class=\"site-nav\" aria-label=\"Site\"><div class=\"site-nav-inner\"><a href=\"${up}index.html\" class=\"brand-link\">dotfiles<span class=\"version-badge\">v$VERSION</span></a><ul class=\"site-nav-links\"><li><a href=\"${manual_up}index.html\">Manual</a></li><li><a href=\"${up}dotfiles.html\">Single page</a></li><li><a href=\"$REPO_URL\">GitHub</a></li></ul></div></nav>"
    sed -i.bak "
      s|<body>|<body>\\
<a href=\"#main\" class=\"skip-link\">Skip to main content</a>\\
$sub_nav\\
<main id=\"main\" role=\"main\">|
      s|</body>|</main>\\
</body>|
    " "$outpath" && rm -f "$outpath.bak"
  done

  cp "$BUILD_DIR/style.css" "$HTML_DIR/style.css"

  # Multi-page index with search + Apple-style nav
  {
    echo '<!DOCTYPE html>'
    echo '<html lang="en">'
    echo '<head><meta charset="UTF-8">'
    echo '<meta name="viewport" content="width=device-width, initial-scale=1">'
    echo "<title>$TITLE — v$VERSION</title>"
    echo '<link rel="stylesheet" href="style.css">'
    echo '</head>'
    echo '<body>'
    echo '<a href="#main" class="skip-link">Skip to main content</a>'
    echo '<nav class="site-nav" aria-label="Site"><div class="site-nav-inner">'
    echo "<a href=\"../index.html\" class=\"brand-link\">dotfiles<span class=\"version-badge\">v$VERSION</span></a>"
    echo '<ul class="site-nav-links">'
    echo '<li><a href="./index.html">Manual</a></li>'
    echo '<li><a href="../dotfiles.html">Single page</a></li>'
    echo "<li><a href=\"$REPO_URL\">GitHub</a></li>"
    echo '</ul></div></nav>'
    echo '<main id="main" role="main">'
    echo '<section class="hero" style="padding:3rem 1rem 2rem;border-bottom:0;margin-bottom:1rem;">'
    echo "<h1>$TITLE</h1>"
    echo "<p class=\"tagline\">$SUBTITLE</p>"
    echo '</section>'
    echo '<div class="search-widget" role="search">'
    echo '  <label for="manual-search">Search the manual</label>'
    echo '  <input type="search" id="manual-search" placeholder="Type at least 2 characters..." aria-label="Search the manual" autocomplete="off">'
    echo '  <div id="manual-search-results" aria-live="polite"></div>'
    echo '</div>'
    echo '<h2>Table of contents</h2>'
    echo '<nav aria-label="Manual table of contents"><ul>'
    echo "$FILES_LIST" | while IFS= read -r f; do
      local rel_src="${f#$SOURCE_DIR/}"
      local html_link="${rel_src%.md}.html"
      local basename
      basename="$(basename "$f" .md)"
      local title
      title="$(head -1 "$f" | sed 's/^#\+ *//')"
      printf '  <li><a href="%s">%s</a></li>\n' "$html_link" "${title:-$basename}"
    done
    echo '</ul></nav>'
    echo '</main>'
    echo '<footer class="site-footer"><div class="footer-inner">'
    echo "<p>Generated $BUILD_DATE · <a href=\"$REPO_URL\">sebastienrousseau/dotfiles</a> · <a href=\"$REPO_URL/blob/main/LICENSE\">MIT License</a></p>"
    echo '</div></footer>'
    echo '<script src="../search.js" defer></script>'
    echo '</body></html>'
  } >"$HTML_DIR/index.html"

  local count
  count=$(find "$HTML_DIR" -name '*.html' | wc -l | tr -d ' ')
  log "  → html/index.html + $count pages"
}

# -----------------------------------------------------------------------------
# EPUB
# -----------------------------------------------------------------------------

build_epub() {
  local out="$BUILD_DIR/dotfiles.epub"
  log "building EPUB"
  pandoc "$MASTER_MD" \
    -f markdown \
    -t epub3 \
    --metadata title="$TITLE" \
    --metadata author="Sebastien Rousseau" \
    --metadata date="$BUILD_DATE" \
    --metadata publisher="EUXIS" \
    --metadata rights="MIT License" \
    --metadata lang="en" \
    --toc \
    --toc-depth=3 \
    -o "$out"
  local sz
  sz=$(file_size "$out")
  log "  → dotfiles.epub ($(human_size "$sz"))"
}

# -----------------------------------------------------------------------------
# PDF with cover page
# -----------------------------------------------------------------------------

build_pdf() {
  if ! $PDF_SUPPORT; then
    warn "skipping PDF (xelatex/tectonic not available)"
    return
  fi
  if $FAST; then
    warn "skipping PDF (--fast mode)"
    return
  fi
  local out="$BUILD_DIR/dotfiles.pdf"
  log "building PDF with cover"
  local engine="xelatex"
  have tectonic && engine="tectonic"

  pandoc "$MASTER_MD" \
    -f markdown \
    -t pdf \
    --pdf-engine="$engine" \
    --toc \
    --toc-depth=3 \
    --variable geometry:margin=1in \
    --variable fontsize=10pt \
    --variable colorlinks=true \
    --variable linkcolor=blue \
    --variable documentclass=report \
    --variable title-meta="$TITLE" \
    --variable author-meta="Sebastien Rousseau" \
    --variable subject-meta="$SUBTITLE" \
    --variable keywords="dotfiles,chezmoi,macOS,Linux,WSL,AI,MCP" \
    --metadata title="$TITLE" \
    --metadata subtitle="$SUBTITLE" \
    --metadata author="Sebastien Rousseau" \
    --metadata date="$BUILD_DATE — v$VERSION" \
    --metadata lang="en" \
    -o "$out" 2>/dev/null || warn "PDF build failed — continuing"
  [[ -f "$out" ]] && log "  → dotfiles.pdf ($(human_size "$(file_size "$out")"))"
}

# -----------------------------------------------------------------------------
# ASCII text
# -----------------------------------------------------------------------------

build_text() {
  local out="$BUILD_DIR/dotfiles.txt"
  log "building ASCII text"
  pandoc "$MASTER_MD" \
    -f markdown \
    -t plain \
    --toc \
    --toc-depth=3 \
    -o "$out"
  local sz
  sz=$(file_size "$out")
  log "  → dotfiles.txt ($(human_size "$sz"))"
}

# -----------------------------------------------------------------------------
# Compressed archives
# -----------------------------------------------------------------------------

build_archives() {
  log "compressing archives"

  if [[ -f "$BUILD_DIR/dotfiles.html" ]]; then
    gzip -c "$BUILD_DIR/dotfiles.html" >"$BUILD_DIR/dotfiles.html.gz"
    log "  → dotfiles.html.gz ($(human_size "$(file_size "$BUILD_DIR/dotfiles.html.gz")"))"
  fi

  if [[ -d "$HTML_DIR" ]]; then
    tar -czf "$BUILD_DIR/html.tar.gz" -C "$BUILD_DIR" html
    log "  → html.tar.gz ($(human_size "$(file_size "$BUILD_DIR/html.tar.gz")"))"
  fi

  if [[ -f "$BUILD_DIR/dotfiles.txt" ]]; then
    gzip -c "$BUILD_DIR/dotfiles.txt" >"$BUILD_DIR/dotfiles.txt.gz"
    log "  → dotfiles.txt.gz ($(human_size "$(file_size "$BUILD_DIR/dotfiles.txt.gz")"))"
  fi

  tar -czf "$BUILD_DIR/dotfiles-md.tar.gz" -C "$REPO_ROOT/docs" manual
  log "  → dotfiles-md.tar.gz ($(human_size "$(file_size "$BUILD_DIR/dotfiles-md.tar.gz")"))"
}

# -----------------------------------------------------------------------------
# SHA256SUMS
# -----------------------------------------------------------------------------

build_checksums() {
  log "computing SHA256SUMS"
  (cd "$BUILD_DIR" && (sha256sum dotfiles.* html.tar.gz search-index.json 2>/dev/null ||
    shasum -a 256 dotfiles.* html.tar.gz search-index.json 2>/dev/null) >SHA256SUMS)
  log "  → SHA256SUMS"
}

# -----------------------------------------------------------------------------
# Landing page — Stow-style with FAQ JSON-LD + Open Graph + search
# -----------------------------------------------------------------------------

build_landing() {
  log "building landing page"
  local out="$BUILD_DIR/index.html"

  local html_size="" html_gz_size="" html_tar_size=""
  local epub_size="" pdf_size="" txt_size="" txt_gz_size="" md_size=""

  [[ -f "$BUILD_DIR/dotfiles.html" ]] && html_size="$(human_size "$(file_size "$BUILD_DIR/dotfiles.html")")"
  [[ -f "$BUILD_DIR/dotfiles.html.gz" ]] && html_gz_size="$(human_size "$(file_size "$BUILD_DIR/dotfiles.html.gz")")"
  [[ -f "$BUILD_DIR/html.tar.gz" ]] && html_tar_size="$(human_size "$(file_size "$BUILD_DIR/html.tar.gz")")"
  [[ -f "$BUILD_DIR/dotfiles.epub" ]] && epub_size="$(human_size "$(file_size "$BUILD_DIR/dotfiles.epub")")"
  [[ -f "$BUILD_DIR/dotfiles.pdf" ]] && pdf_size="$(human_size "$(file_size "$BUILD_DIR/dotfiles.pdf")")"
  [[ -f "$BUILD_DIR/dotfiles.txt" ]] && txt_size="$(human_size "$(file_size "$BUILD_DIR/dotfiles.txt")")"
  [[ -f "$BUILD_DIR/dotfiles.txt.gz" ]] && txt_gz_size="$(human_size "$(file_size "$BUILD_DIR/dotfiles.txt.gz")")"
  [[ -f "$BUILD_DIR/dotfiles-md.tar.gz" ]] && md_size="$(human_size "$(file_size "$BUILD_DIR/dotfiles-md.tar.gz")")"

  cat >"$out" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>The .dotfiles Manual — v$VERSION</title>
  <meta name="description" content="Declarative dotfiles for macOS, Linux, and WSL. Multi-shell by default, with sub-second startup, wallpaper-driven themes, and signed releases.">
  <meta name="author" content="Sebastien Rousseau">
  <meta name="keywords" content="dotfiles, chezmoi, workstation, multi-shell, fish, zsh, nushell, macOS, Linux, WSL, themes, secrets, attestation">

  <!-- Open Graph -->
  <meta property="og:type" content="website">
  <meta property="og:title" content="The .dotfiles Manual — v$VERSION">
  <meta property="og:description" content="Declarative dotfiles for macOS, Linux, and WSL. Multi-shell by default, with sub-second startup, wallpaper-driven themes, and signed releases.">
  <meta property="og:url" content="$MANUAL_URL/">
  <meta property="og:site_name" content=".dotfiles">
  <meta property="og:locale" content="en_US">

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="The .dotfiles Manual — v$VERSION">
  <meta name="twitter:description" content="Declarative dotfiles for macOS, Linux, and WSL. Multi-shell by default, with sub-second startup, wallpaper-driven themes, and signed releases.">

  <link rel="canonical" href="$MANUAL_URL/">
  <link rel="stylesheet" href="style.css">

  <!-- FAQ JSON-LD for SGE / Perplexity / Gemini capture -->
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "TechArticle",
    "headline": "The .dotfiles Manual",
    "description": "Declarative dotfiles for macOS, Linux, and WSL — multi-shell, fast-startup, signed",
    "author": {"@type": "Person", "name": "Sebastien Rousseau", "url": "https://sebastienrousseau.com"},
    "datePublished": "$BUILD_DATE",
    "dateModified": "$BUILD_DATE",
    "version": "$VERSION",
    "license": "https://opensource.org/licenses/MIT",
    "codeRepository": "$REPO_URL",
    "programmingLanguage": "Shell"
  }
  </script>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    "mainEntity": [
      {
        "@type": "Question",
        "name": "What is .dotfiles?",
        "acceptedAnswer": {"@type": "Answer", "text": "Declarative, chezmoi-managed dotfiles for macOS, Linux, and WSL. Multi-shell by default (fish, zsh, nushell, PowerShell), with sub-second startup, wallpaper-driven themes, encrypted secrets, and signed releases."}
      },
      {
        "@type": "Question",
        "name": "How do I install .dotfiles?",
        "acceptedAnswer": {"@type": "Answer", "text": "Run: bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh)\" — then verify with 'dot doctor'."}
      },
      {
        "@type": "Question",
        "name": "What platforms are supported?",
        "acceptedAnswer": {"@type": "Answer", "text": "macOS 14+, Ubuntu/Debian, Arch/CachyOS, Fedora, openSUSE, WSL2. PowerShell 7.5+ for baseline parity on Windows."}
      },
      {
        "@type": "Question",
        "name": "How are terminal themes generated?",
        "acceptedAnswer": {"@type": "Answer", "text": "K-Means clustering in CIELAB color space extracts dominant colors from wallpaper images and generates WCAG AAA-compliant palettes — no hand-crafted themes."}
      },
      {
        "@type": "Question",
        "name": "How do I switch themes?",
        "acceptedAnswer": {"@type": "Answer", "text": "Run 'dot theme' for an interactive picker, 'dot theme <name>' to switch directly, or 'dot theme toggle' to swap dark/light."}
      },
      {
        "@type": "Question",
        "name": "How are secrets managed?",
        "acceptedAnswer": {"@type": "Answer", "text": "Age encryption for individual files and SOPS for YAML/JSON. Encrypted at rest in the repository, decrypted on 'dot apply' using the local private key."}
      }
    ]
  }
  </script>
</head>
<body>
  <a href="#main" class="skip-link">Skip to main content</a>

  <nav class="site-nav" aria-label="Site">
    <div class="site-nav-inner">
      <a href="./" class="brand-link">dotfiles<span class="version-badge">v$VERSION</span></a>
      <ul class="site-nav-links">
        <li><a href="html/index.html">Manual</a></li>
        <li><a href="dotfiles.html">Single page</a></li>
        <li><a href="$REPO_URL">GitHub</a></li>
      </ul>
    </div>
  </nav>

  <main id="main" role="main">
    <section class="hero">
      <h1>Your Shell, Everywhere.</h1>
      <p class="tagline">$SUBTITLE — multi-shell by default, sub-second startup, wallpaper-driven themes, encrypted secrets, and signed releases.</p>
      <div class="hero-actions">
        <a class="btn" href="html/index.html">Read the Manual</a>
        <a class="btn btn-secondary" href="$REPO_URL">View on GitHub</a>
      </div>
    </section>

    <section class="features" aria-label="Key features">
      <div class="feature-card">
        <h3>Modern Core</h3>
        <p>Chezmoi-managed templates, mise-pinned toolchains, and a single <code>dot</code> CLI surface across fish, zsh, nushell, bash, and PowerShell.</p>
      </div>
      <div class="feature-card">
        <h3>Hardened Security</h3>
        <p>SLSA L3 provenance, signed releases, in-toto attestations, age + SOPS-encrypted secrets, and an OpenSSF Scorecard 10/10 baseline.</p>
      </div>
      <div class="feature-card">
        <h3>Infrastructure Approach</h3>
        <p>Self-healing apply, fleet-aware namespacing, drift detection, and reproducible environment manifests for every workstation.</p>
      </div>
      <div class="feature-card">
        <h3>Cross-Platform</h3>
        <p>First-class macOS, Ubuntu, Arch, Fedora, openSUSE, WSL2, and PowerShell 7.5+ support — the same UX everywhere.</p>
      </div>
    </section>

    <div class="search-widget" role="search">
      <label for="manual-search">Search the manual</label>
      <input type="search" id="manual-search" placeholder="Type at least 2 characters..." aria-label="Search the manual" autocomplete="off">
      <div id="manual-search-results" aria-live="polite"></div>
    </div>

    <h2>Available formats</h2>
    <p>This manual is published from a single Markdown source in the following formats:</p>
    <ul class="formats">
      <li><a href="html/index.html">HTML</a> — one page per chapter, with search</li>
      <li><a href="dotfiles.html">HTML single page</a> <span class="size">$html_size</span></li>
      <li><a href="html.tar.gz">HTML compressed (multi-page)</a> <span class="size">$html_tar_size</span></li>
      <li><a href="dotfiles.html.gz">HTML compressed (single page)</a> <span class="size">$html_gz_size</span></li>
      <li><a href="dotfiles.epub">EPUB</a> <span class="size">$epub_size</span></li>
HTML

  if [[ -n "$pdf_size" ]]; then
    echo "      <li><a href=\"dotfiles.pdf\">PDF</a> <span class=\"size\">$pdf_size</span></li>" >>"$out"
  fi

  cat >>"$out" <<HTML
      <li><a href="dotfiles.txt">ASCII text</a> <span class="size">$txt_size</span></li>
      <li><a href="dotfiles.txt.gz">ASCII text compressed</a> <span class="size">$txt_gz_size</span></li>
      <li><a href="dotfiles-md.tar.gz">Markdown source</a> <span class="size">$md_size</span></li>
    </ul>

    <p>Integrity: <a href="SHA256SUMS">SHA256SUMS</a> · Version history: <a href="$REPO_URL/releases">GitHub Releases</a></p>

    <h2>Quick start</h2>
    <pre><code>bash -c "\$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh)"
dot doctor
dot learn</code></pre>

    <h2>Source</h2>
    <p>Repository: <a href="$REPO_URL">sebastienrousseau/dotfiles</a> · License: <a href="$REPO_URL/blob/main/LICENSE">MIT</a></p>
  </main>

  <footer class="site-footer">
    <div class="footer-inner">
      <p>Generated $BUILD_DATE from <a href="dotfiles-md.tar.gz">docs/manual/</a> via <code>tools/docs/build-manual.sh</code>.
      Questions? <a href="$REPO_URL/issues">Open an issue</a> or <a href="$REPO_URL/discussions">start a discussion</a>.</p>
      <p>&copy; 2015–$(date +%Y) Sebastien Rousseau · <a href="$REPO_URL/blob/main/LICENSE">MIT License</a></p>
    </div>
  </footer>

  <script src="search.js" defer></script>
</body>
</html>
HTML

  log "  → index.html"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  log "building .dotfiles manual v$VERSION"
  log "source: $SOURCE_DIR"
  log "output: $BUILD_DIR"

  build_search_index
  build_html_single
  build_html_multi
  build_epub
  build_pdf
  build_text
  build_archives
  build_checksums
  build_landing

  rm -f "$MASTER_MD"

  log ""
  log "build complete"
  log "  landing:  $BUILD_DIR/index.html"
  log "  formats:  $(ls "$BUILD_DIR" | wc -l | tr -d ' ') files"
  log ""
  log "open locally: /usr/bin/open $BUILD_DIR/index.html"
}

main
