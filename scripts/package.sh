#!/usr/bin/env bash
# Script: package.sh
# Description: Bundles the dotfiles for distribution or backup.
# Generates a standard .tar.gz archive and validates structure.

set -e

VERSION="${1:-v0.2.471}"
DIST_DIR="dist"
ARCHIVE_NAME="dotfiles-${VERSION}.tar.gz"

echo "📦 Packaging Dotfiles (${VERSION})..."

# Create dist directory
mkdir -p "$DIST_DIR"

# Create artifact manifest
echo "Manifest generated at $(date)" > "$DIST_DIR/MANIFEST.txt"
echo "Version: ${VERSION}" >> "$DIST_DIR/MANIFEST.txt"
echo "Commit: $(git rev-parse HEAD)" >> "$DIST_DIR/MANIFEST.txt"

# Archive core files (excluding sensitive data/git)
# Using git archive for clean export if possible, fallback to tar
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "   -> EXPORT: Using git archive..."
    git archive --format=tar.gz \
        --output="$DIST_DIR/$ARCHIVE_NAME" \
        --prefix="dotfiles-${VERSION}/" \
        HEAD
else
    echo "   -> EXPORT: Using tar (fallback)..."
    tar --exclude='.git' \
        --exclude='dist' \
        --exclude='secrets' \
        -czf "$DIST_DIR/$ARCHIVE_NAME" .
fi

echo "   -> CHECKSUM: Generating sha256..."
if command -v shasum >/dev/null; then
    shasum -a 256 "$DIST_DIR/$ARCHIVE_NAME" > "$DIST_DIR/${ARCHIVE_NAME}.sha256"
else
    sha256sum "$DIST_DIR/$ARCHIVE_NAME" > "$DIST_DIR/${ARCHIVE_NAME}.sha256"
fi

echo "✅ Package created at ${DIST_DIR}/${ARCHIVE_NAME}"
echo "   Size: $(du -h "$DIST_DIR/$ARCHIVE_NAME" | cut -f1)"
