#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# build-manual.sh — Generate dotfiles documentation in 9 formats.
#
# Produces from docs/manual/ Markdown sources:
#   HTML (single page)
#   HTML (multi-page tree)
#   HTML gzipped (single)
#   HTML gzipped (tar.gz, multi-page)
#   EPUB
#   PDF (if xelatex available)
#   ASCII text
#   ASCII gzipped
#   Markdown source (tar.gz)
#   SHA256SUMS
#   Landing page (Stow-style format chooser)
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

log()  { printf '[manual] %s\n' "$*"; }
warn() { printf '[manual] WARN: %s\n' "$*" >&2; }
die()  { printf '[manual] ERROR: %s\n' "$*" >&2; exit 1; }

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
# Read TOC ordering from _toc.yml (simple grep-based — avoid YAML parser dep)
# -----------------------------------------------------------------------------

# Collect files in canonical order. We use the _toc.yml as a rough guide but
# fallback to find() if the YAML structure is unparseable.
collect_files() {
  # Order:
  #   00-introduction.md
  #   01-concepts/*.md (sorted)
  #   02-tutorials/*.md (sorted)
  #   03-reference/*.md (sorted)
  #   04-cookbook/*.md (sorted)
  #   05-appendices/*.md (sorted)
  #   concept-index.md (last)
  #   command-index.md (last)
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
# Assemble master Markdown (single concatenated file for single-page builds)
# -----------------------------------------------------------------------------

MASTER_MD="$BUILD_DIR/_master.md"
{
  echo "---"
  echo "title: $TITLE"
  echo "subtitle: $SUBTITLE"
  echo "version: $VERSION"
  echo "date: $(date +%Y-%m-%d)"
  echo "---"
  echo ""
  echo "$FILES_LIST" | while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    # Rewrite relative links to anchors for the single-page view
    # docs/manual/01-concepts/03-theme-engine.md#foo → #03-theme-engine-foo
    sed -E '
      s|\[([^]]+)\]\(\.\./?([0-9]+-[a-z]+/[0-9A-Z]+-[a-z-]+)\.md(#[a-z0-9-]+)?\)|[\1](\3)|g
      s|\[([^]]+)\]\(([0-9A-Z]+-[a-z-]+)\.md(#[a-z0-9-]+)?\)|[\1](\3)|g
    ' "$f"
    echo ""
    echo ""
  done
} > "$MASTER_MD"

MASTER_SIZE=$(wc -c < "$MASTER_MD")
log "master markdown: $(human_size "$MASTER_SIZE")"

# -----------------------------------------------------------------------------
# Build — Auto-generate concept and command indexes
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
  } > "$SOURCE_DIR/concept-index.md.gen"
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
  } > "$SOURCE_DIR/command-index.md.gen"
  mv "$SOURCE_DIR/command-index.md.gen" "$SOURCE_DIR/command-index.md"
}

build_indexes

# Regenerate master with updated indexes
{
  echo "---"
  echo "title: $TITLE"
  echo "subtitle: $SUBTITLE"
  echo "version: $VERSION"
  echo "date: $(date +%Y-%m-%d)"
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
} > "$MASTER_MD"

# -----------------------------------------------------------------------------
# HTML single page
# -----------------------------------------------------------------------------

build_html_single() {
  local out="$BUILD_DIR/dotfiles.html"
  log "building HTML single page"
  pandoc "$MASTER_MD" \
    -f markdown \
    -t html5 \
    --standalone \
    --toc \
    --toc-depth=3 \
    --section-divs \
    --metadata title="$TITLE" \
    --metadata subtitle="$SUBTITLE — v$VERSION" \
    --css=style.css \
    -o "$out"

  cat > "$BUILD_DIR/style.css" <<'CSSEOF'
:root { --fg: #1c1c1e; --bg: #fff; --accent: #2d538e; --border: #e5e5ea; --code-bg: #f5f5f7; }
@media (prefers-color-scheme: dark) {
  :root { --fg: #f2f2f7; --bg: #111; --accent: #64a0e4; --border: #2c2c2e; --code-bg: #1c1c1e; }
}
body { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; max-width: 820px; margin: 2rem auto; padding: 0 1rem; color: var(--fg); background: var(--bg); line-height: 1.6; }
h1, h2, h3 { color: var(--accent); margin-top: 2rem; }
h1 { border-bottom: 2px solid var(--accent); padding-bottom: 0.3rem; }
code { background: var(--code-bg); padding: 0.1rem 0.3rem; border-radius: 3px; font-family: "JetBrains Mono", Menlo, monospace; font-size: 0.9em; }
pre { background: var(--code-bg); padding: 1rem; border-radius: 6px; overflow-x: auto; border: 1px solid var(--border); }
pre code { background: transparent; padding: 0; }
table { border-collapse: collapse; margin: 1rem 0; }
th, td { border: 1px solid var(--border); padding: 0.4rem 0.8rem; }
th { background: var(--code-bg); }
a { color: var(--accent); }
nav ol, nav ul { padding-left: 1.2rem; }
blockquote { border-left: 3px solid var(--accent); padding-left: 1rem; color: #6d6d72; }
CSSEOF
  local sz; sz=$(file_size "$out")
  log "  → dotfiles.html ($(human_size "$sz"))"
}

# -----------------------------------------------------------------------------
# HTML multi-page (one HTML per source file)
# -----------------------------------------------------------------------------

build_html_multi() {
  log "building HTML multi-page"
  local nav_html="<nav class='sidebar'><h3>Manual</h3><ul>"
  echo "$FILES_LIST" | while IFS= read -r f; do
    local rel_src="${f#$SOURCE_DIR/}"
    local basename
    basename="$(basename "$f" .md)"
    local outpath="$HTML_DIR/${rel_src%.md}.html"
    mkdir -p "$(dirname "$outpath")"
    pandoc "$f" \
      -f markdown \
      -t html5 \
      --standalone \
      --toc \
      --toc-depth=3 \
      --metadata title="$basename" \
      --css=../style.css \
      -o "$outpath"
  done
  cp "$BUILD_DIR/style.css" "$HTML_DIR/style.css"

  # Index page
  {
    echo '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">'
    echo "<title>$TITLE — v$VERSION</title>"
    echo '<link rel="stylesheet" href="style.css">'
    echo '</head><body>'
    echo "<h1>$TITLE</h1>"
    echo "<p><em>$SUBTITLE</em> — v$VERSION</p>"
    echo '<nav><ul>'
    echo "$FILES_LIST" | while IFS= read -r f; do
      local rel_src="${f#$SOURCE_DIR/}"
      local html_link="${rel_src%.md}.html"
      local basename
      basename="$(basename "$f" .md)"
      local title
      title="$(head -1 "$f" | sed 's/^#\+ *//')"
      printf '  <li><a href="%s">%s</a></li>\n' "$html_link" "${title:-$basename}"
    done
    echo '</ul></nav></body></html>'
  } > "$HTML_DIR/index.html"

  local count; count=$(find "$HTML_DIR" -name '*.html' | wc -l | tr -d ' ')
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
    --metadata date="$(date +%Y-%m-%d)" \
    --metadata publisher="EUXIS" \
    --metadata rights="MIT License" \
    --toc \
    --toc-depth=3 \
    -o "$out"
  local sz; sz=$(file_size "$out")
  log "  → dotfiles.epub ($(human_size "$sz"))"
}

# -----------------------------------------------------------------------------
# PDF
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
  log "building PDF"
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
    --metadata title="$TITLE" \
    --metadata author="Sebastien Rousseau" \
    --metadata date="$(date +%Y-%m-%d)" \
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
  local sz; sz=$(file_size "$out")
  log "  → dotfiles.txt ($(human_size "$sz"))"
}

# -----------------------------------------------------------------------------
# Compressed archives
# -----------------------------------------------------------------------------

build_archives() {
  log "compressing archives"

  # HTML single gzipped
  if [[ -f "$BUILD_DIR/dotfiles.html" ]]; then
    gzip -c "$BUILD_DIR/dotfiles.html" > "$BUILD_DIR/dotfiles.html.gz"
    log "  → dotfiles.html.gz ($(human_size "$(file_size "$BUILD_DIR/dotfiles.html.gz")"))"
  fi

  # HTML multi tar.gz
  if [[ -d "$HTML_DIR" ]]; then
    tar -czf "$BUILD_DIR/html.tar.gz" -C "$BUILD_DIR" html
    log "  → html.tar.gz ($(human_size "$(file_size "$BUILD_DIR/html.tar.gz")"))"
  fi

  # Text gzipped
  if [[ -f "$BUILD_DIR/dotfiles.txt" ]]; then
    gzip -c "$BUILD_DIR/dotfiles.txt" > "$BUILD_DIR/dotfiles.txt.gz"
    log "  → dotfiles.txt.gz ($(human_size "$(file_size "$BUILD_DIR/dotfiles.txt.gz")"))"
  fi

  # Markdown source tar.gz
  tar -czf "$BUILD_DIR/dotfiles-md.tar.gz" -C "$REPO_ROOT/docs" manual
  log "  → dotfiles-md.tar.gz ($(human_size "$(file_size "$BUILD_DIR/dotfiles-md.tar.gz")"))"
}

# -----------------------------------------------------------------------------
# SHA256SUMS
# -----------------------------------------------------------------------------

build_checksums() {
  log "computing SHA256SUMS"
  ( cd "$BUILD_DIR" && sha256sum dotfiles.* html.tar.gz 2>/dev/null > SHA256SUMS || \
    shasum -a 256 dotfiles.* html.tar.gz 2>/dev/null > SHA256SUMS )
  log "  → SHA256SUMS"
}

# -----------------------------------------------------------------------------
# Landing page (Stow-style format chooser)
# -----------------------------------------------------------------------------

build_landing() {
  log "building landing page"
  local out="$BUILD_DIR/index.html"

  # Collect format info
  local html_size=""; html_gz_size=""; html_tar_size=""
  local epub_size=""; pdf_size=""; txt_size=""; txt_gz_size=""; md_size=""

  [[ -f "$BUILD_DIR/dotfiles.html" ]]      && html_size="$(human_size "$(file_size "$BUILD_DIR/dotfiles.html")")"
  [[ -f "$BUILD_DIR/dotfiles.html.gz" ]]   && html_gz_size="$(human_size "$(file_size "$BUILD_DIR/dotfiles.html.gz")")"
  [[ -f "$BUILD_DIR/html.tar.gz" ]]        && html_tar_size="$(human_size "$(file_size "$BUILD_DIR/html.tar.gz")")"
  [[ -f "$BUILD_DIR/dotfiles.epub" ]]      && epub_size="$(human_size "$(file_size "$BUILD_DIR/dotfiles.epub")")"
  [[ -f "$BUILD_DIR/dotfiles.pdf" ]]       && pdf_size="$(human_size "$(file_size "$BUILD_DIR/dotfiles.pdf")")"
  [[ -f "$BUILD_DIR/dotfiles.txt" ]]       && txt_size="$(human_size "$(file_size "$BUILD_DIR/dotfiles.txt")")"
  [[ -f "$BUILD_DIR/dotfiles.txt.gz" ]]    && txt_gz_size="$(human_size "$(file_size "$BUILD_DIR/dotfiles.txt.gz")")"
  [[ -f "$BUILD_DIR/dotfiles-md.tar.gz" ]] && md_size="$(human_size "$(file_size "$BUILD_DIR/dotfiles-md.tar.gz")")"

  cat > "$out" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>The .dotfiles Manual — v$VERSION</title>
  <link rel="stylesheet" href="style.css">
  <style>
    .formats { margin: 2rem 0; }
    .formats li { margin: 0.4rem 0; }
    .size { color: #6d6d72; font-size: 0.9em; }
    .footer { margin-top: 3rem; padding-top: 1rem; border-top: 1px solid var(--border); font-size: 0.9em; color: #6d6d72; }
  </style>
</head>
<body>
  <h1>The .dotfiles Manual — v$VERSION</h1>
  <p><em>A Trusted Agent Workstation for macOS, Linux, and WSL</em></p>

  <p>This manual is available in the following formats:</p>

  <ul class="formats">
    <li><a href="html/index.html">HTML — with one web page per node</a></li>
    <li><a href="dotfiles.html">HTML ($html_size) — entirely on one web page</a></li>
    <li><a href="html.tar.gz">HTML compressed ($html_tar_size gzipped tar) — multi-page</a></li>
    <li><a href="dotfiles.html.gz">HTML compressed ($html_gz_size gzipped) — single page</a></li>
    <li><a href="dotfiles.epub">EPUB ($epub_size)</a></li>
HTML

  if [[ -n "$pdf_size" ]]; then
    echo "    <li><a href=\"dotfiles.pdf\">PDF ($pdf_size)</a></li>" >> "$out"
  fi

  cat >> "$out" <<HTML
    <li><a href="dotfiles.txt">ASCII text ($txt_size)</a></li>
    <li><a href="dotfiles.txt.gz">ASCII text compressed ($txt_gz_size gzipped)</a></li>
    <li><a href="dotfiles-md.tar.gz">Markdown source ($md_size gzipped tar)</a></li>
  </ul>

  <p>Checksums: <a href="SHA256SUMS">SHA256SUMS</a></p>

  <p>You can also browse the manual online directly at <a href="html/index.html">html/index.html</a>.</p>

  <h2>What this is</h2>
  <p><code>.dotfiles</code> is workstation infrastructure: signed, attested, multi-platform, AI-aware, and self-healing.
  Install with one command; get terminal themes generated from your wallpapers, encrypted secrets, agent policy enforcement,
  and cross-host attestation.</p>

  <h2>Getting started</h2>
  <pre><code>bash -c "\$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/install.sh)"
dot doctor
dot learn</code></pre>

  <h2>Source code</h2>
  <p>Repository: <a href="https://github.com/sebastienrousseau/dotfiles">sebastienrousseau/dotfiles</a></p>
  <p>License: <a href="https://github.com/sebastienrousseau/dotfiles/blob/master/LICENSE">MIT</a></p>

  <div class="footer">
    <p>Generated $(date +%Y-%m-%d) from <a href="dotfiles-md.tar.gz">docs/manual/</a> via <code>scripts/docs/build-manual.sh</code>.</p>
    <p>Questions? <a href="https://github.com/sebastienrousseau/dotfiles/issues">Open an issue</a>.</p>
  </div>
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

  build_html_single
  build_html_multi
  build_epub
  build_pdf
  build_text
  build_archives
  build_checksums
  build_landing

  # Cleanup master
  rm -f "$MASTER_MD"

  log ""
  log "build complete"
  log "  landing:  $BUILD_DIR/index.html"
  log "  formats:  $(ls "$BUILD_DIR" | wc -l | tr -d ' ') files"
  log ""
  log "open locally: open $BUILD_DIR/index.html"
}

main
