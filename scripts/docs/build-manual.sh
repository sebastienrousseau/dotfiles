#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
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
#   bash scripts/docs/build-manual.sh           # full build
#   bash scripts/docs/build-manual.sh --fast    # skip PDF
#   bash scripts/docs/build-manual.sh --clean   # remove _build/manual first
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_DIR="$REPO_ROOT/docs/manual"
BUILD_DIR="$REPO_ROOT/_build/manual"
HTML_DIR="$BUILD_DIR/html"
VERSION="$(awk -F'"' '/^dotfiles_version/ {print $2; exit}' "$REPO_ROOT/.chezmoidata.toml")"
TITLE=".dotfiles Manual"
SUBTITLE="A Trusted Agent Workstation for macOS, Linux, and WSL"
REPO_URL="https://github.com/sebastienrousseau/dotfiles"
MANUAL_URL="https://sebastienrousseau.github.io/dotfiles/manual"
BUILD_DATE="$(date +%Y-%m-%d)"
BUILD_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

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
  cat >"$BUILD_DIR/style.css" <<'CSSEOF'
:root {
  --fg: #1c1c1e;
  --bg: #fff;
  --accent: #2d538e;
  --accent-text: #fff;
  --border: #e5e5ea;
  --code-bg: #f5f5f7;
  --muted: #6d6d72;
  --focus-ring: #0066cc;
}
@media (prefers-color-scheme: dark) {
  :root {
    --fg: #f2f2f7;
    --bg: #111;
    --accent: #64a0e4;
    --accent-text: #111;
    --border: #2c2c2e;
    --code-bg: #1c1c1e;
    --muted: #9b9ba0;
    --focus-ring: #5ac8fa;
  }
}

/* Skip link for keyboard users */
.skip-link {
  position: absolute;
  left: -9999px;
  top: 0;
  background: var(--accent);
  color: var(--accent-text);
  padding: 0.5rem 1rem;
  z-index: 1000;
  text-decoration: none;
}
.skip-link:focus { left: 0; }

*:focus-visible {
  outline: 2px solid var(--focus-ring);
  outline-offset: 2px;
  border-radius: 2px;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
  max-width: 820px;
  margin: 2rem auto;
  padding: 0 1rem;
  color: var(--fg);
  background: var(--bg);
  line-height: 1.6;
}

h1, h2, h3 { color: var(--accent); margin-top: 2rem; line-height: 1.3; }
h1 { border-bottom: 2px solid var(--accent); padding-bottom: 0.3rem; }
h2 { margin-top: 2.5rem; }

code {
  background: var(--code-bg);
  padding: 0.1rem 0.3rem;
  border-radius: 3px;
  font-family: "JetBrains Mono", "SF Mono", Menlo, monospace;
  font-size: 0.9em;
}
pre {
  background: var(--code-bg);
  padding: 1rem;
  border-radius: 6px;
  overflow-x: auto;
  border: 1px solid var(--border);
}
pre code { background: transparent; padding: 0; }

table { border-collapse: collapse; margin: 1rem 0; width: 100%; }
th, td { border: 1px solid var(--border); padding: 0.4rem 0.8rem; text-align: left; }
th { background: var(--code-bg); font-weight: 600; }

a { color: var(--accent); }
a:hover { text-decoration: underline; }

nav ol, nav ul { padding-left: 1.2rem; }
blockquote {
  border-left: 3px solid var(--accent);
  padding-left: 1rem;
  color: var(--muted);
  margin: 1rem 0;
}

/* Search box */
.search-widget {
  margin: 1rem 0 2rem;
  padding: 0.8rem 1rem;
  background: var(--code-bg);
  border: 1px solid var(--border);
  border-radius: 6px;
}
.search-widget input {
  width: 100%;
  padding: 0.5rem 0.8rem;
  font-size: 1rem;
  border: 1px solid var(--border);
  border-radius: 4px;
  background: var(--bg);
  color: var(--fg);
  font-family: inherit;
}
.search-results {
  margin-top: 0.8rem;
  max-height: 300px;
  overflow-y: auto;
}
.search-results li {
  list-style: none;
  padding: 0.4rem 0;
  border-bottom: 1px solid var(--border);
}
.search-results li:last-child { border-bottom: none; }
.search-results a { text-decoration: none; display: block; }
.search-results .hit-section { font-size: 0.85em; color: var(--muted); }

/* Page footer / edit link */
.page-footer {
  margin-top: 3rem;
  padding-top: 1rem;
  border-top: 1px solid var(--border);
  font-size: 0.9em;
  color: var(--muted);
}
.page-footer a { color: var(--muted); }

/* Formats list on landing */
.formats { margin: 2rem 0; }
.formats li { margin: 0.4rem 0; }
.size { color: var(--muted); font-size: 0.9em; }

/* Version badge */
.version-badge {
  display: inline-block;
  background: var(--accent);
  color: var(--accent-text);
  padding: 0.15rem 0.6rem;
  border-radius: 12px;
  font-size: 0.8em;
  font-weight: 600;
  margin-left: 0.5rem;
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

  # Inject skip link + ARIA landmarks
  sed -i.bak '
    s|<body>|<body>\n<a href="#main" class="skip-link">Skip to main content</a>\n<main id="main" role="main">|
    s|</body>|</main>\n</body>|
  ' "$out" && rm -f "$out.bak"

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
    local edit_url="$REPO_URL/edit/master/docs/manual/$rel_src"
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

    # Inject skip link + ARIA
    sed -i.bak '
      s|<body>|<body>\n<a href="#main" class="skip-link">Skip to main content</a>\n<main id="main" role="main">|
      s|</body>|</main>\n</body>|
    ' "$outpath" && rm -f "$outpath.bak"
  done

  cp "$BUILD_DIR/style.css" "$HTML_DIR/style.css"

  # Multi-page index with search
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
    echo '<main id="main" role="main">'
    echo "<h1>$TITLE <span class=\"version-badge\">v$VERSION</span></h1>"
    echo "<p><em>$SUBTITLE</em></p>"
    echo '<div class="search-widget" role="search">'
    echo '  <label for="manual-search" style="font-weight: 600;">Search the manual</label>'
    echo '  <input type="search" id="manual-search" placeholder="Type at least 2 characters..." aria-label="Search the manual" autocomplete="off">'
    echo '  <div id="manual-search-results" aria-live="polite"></div>'
    echo '</div>'
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
  <meta name="description" content="The Trusted agent workstation. Wallpaper-driven themes. Cryptographic attestation. MCP-native. One CLI for macOS, Linux, and WSL.">
  <meta name="author" content="Sebastien Rousseau">
  <meta name="keywords" content="dotfiles, chezmoi, workstation, trusted agent, MCP, AI, macOS, Linux, WSL, themes, secrets, attestation">

  <!-- Open Graph -->
  <meta property="og:type" content="website">
  <meta property="og:title" content="The .dotfiles Manual — v$VERSION">
  <meta property="og:description" content="The Trusted agent workstation. Wallpaper-driven themes. Cryptographic attestation. MCP-native.">
  <meta property="og:url" content="$MANUAL_URL/">
  <meta property="og:site_name" content=".dotfiles">
  <meta property="og:locale" content="en_US">

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="The .dotfiles Manual — v$VERSION">
  <meta name="twitter:description" content="The Trusted agent workstation. Wallpaper-driven themes. Cryptographic attestation. MCP-native.">

  <link rel="canonical" href="$MANUAL_URL/">
  <link rel="stylesheet" href="style.css">

  <!-- FAQ JSON-LD for SGE / Perplexity / Gemini capture -->
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "TechArticle",
    "headline": "The .dotfiles Manual",
    "description": "A Trusted Agent Workstation for macOS, Linux, and WSL",
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
        "acceptedAnswer": {"@type": "Answer", "text": "A signed, local-first Trusted agent workstation baseline for macOS, Linux, and WSL with wallpaper-driven themes, MCP policy enforcement, cryptographic attestation, and self-healing."}
      },
      {
        "@type": "Question",
        "name": "How do I install .dotfiles?",
        "acceptedAnswer": {"@type": "Answer", "text": "Run: bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/install.sh)\" — then verify with 'dot doctor'."}
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
  <main id="main" role="main">
  <header>
    <h1>The .dotfiles Manual <span class="version-badge">v$VERSION</span></h1>
    <p><em>$SUBTITLE</em></p>
  </header>

  <div class="search-widget" role="search">
    <label for="manual-search" style="font-weight: 600;">Search the manual</label>
    <input type="search" id="manual-search" placeholder="Type at least 2 characters..." aria-label="Search the manual" autocomplete="off">
    <div id="manual-search-results" aria-live="polite"></div>
  </div>

  <h2>Available formats</h2>
  <p>This manual is published from a single Markdown source in the following formats:</p>
  <ul class="formats">
    <li><a href="html/index.html">HTML</a> — one page per chapter, with search</li>
    <li><a href="dotfiles.html">HTML single page</a> <span class="size">($html_size)</span></li>
    <li><a href="html.tar.gz">HTML compressed</a> <span class="size">($html_tar_size gzipped tar, multi-page)</span></li>
    <li><a href="dotfiles.html.gz">HTML compressed</a> <span class="size">($html_gz_size gzipped, single page)</span></li>
    <li><a href="dotfiles.epub">EPUB</a> <span class="size">($epub_size)</span></li>
HTML

  if [[ -n "$pdf_size" ]]; then
    echo "    <li><a href=\"dotfiles.pdf\">PDF</a> <span class=\"size\">($pdf_size, with cover page)</span></li>" >>"$out"
  fi

  cat >>"$out" <<HTML
    <li><a href="dotfiles.txt">ASCII text</a> <span class="size">($txt_size)</span></li>
    <li><a href="dotfiles.txt.gz">ASCII text compressed</a> <span class="size">($txt_gz_size gzipped)</span></li>
    <li><a href="dotfiles-md.tar.gz">Markdown source</a> <span class="size">($md_size gzipped tar)</span></li>
  </ul>

  <p>Integrity: <a href="SHA256SUMS">SHA256SUMS</a> · Version history: <a href="$REPO_URL/releases">GitHub Releases</a></p>

  <h2>About this manual</h2>
  <p><code>.dotfiles</code> is workstation infrastructure: signed, attested, multi-platform, AI-aware, and self-healing.
  Install with one command; get terminal themes generated from wallpapers, encrypted secrets, agent policy enforcement,
  and cross-host attestation.</p>

  <h2>Quick start</h2>
  <pre><code>bash -c "\$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/install.sh)"
dot doctor
dot learn</code></pre>

  <h2>Source code</h2>
  <p>Repository: <a href="$REPO_URL">sebastienrousseau/dotfiles</a> · License: <a href="$REPO_URL/blob/master/LICENSE">MIT</a></p>

  <div class="page-footer">
    <p>Generated $BUILD_DATE from <a href="dotfiles-md.tar.gz">docs/manual/</a> via <code>scripts/docs/build-manual.sh</code>.</p>
    <p>Questions? <a href="$REPO_URL/issues">Open an issue</a> or <a href="$REPO_URL/discussions">start a discussion</a>.</p>
  </div>
  </main>
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
