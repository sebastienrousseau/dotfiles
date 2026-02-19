#!/usr/bin/env bash
# Install a pinned Chezmoi release with checksum verification.
set -euo pipefail

VERSION="${1:-}"
BIN_DIR="${2:-$HOME/.local/bin}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <chezmoi-version> [bin-dir]" >&2
  exit 1
fi

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$OS" in
  linux|darwin) ;;
  *)
    echo "Unsupported OS: $OS" >&2
    exit 1
    ;;
esac

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *)
    echo "Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

ASSET="chezmoi_${VERSION}_${OS}_${ARCH}.tar.gz"
CHECKSUMS_ASSET="chezmoi_${VERSION}_checksums.txt"
BASE_URL="https://github.com/twpayne/chezmoi/releases/download/v${VERSION}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Support both old and new checksum filenames.
if ! curl -fsSL -o "$TMP_DIR/checksums.txt" "$BASE_URL/$CHECKSUMS_ASSET"; then
  curl -fsSL -o "$TMP_DIR/checksums.txt" "$BASE_URL/checksums.txt"
fi
curl -fsSL -o "$TMP_DIR/$ASSET" "$BASE_URL/$ASSET"

CHECKSUM_LINE="$(grep -E "[[:space:]]${ASSET}$" "$TMP_DIR/checksums.txt" | head -n1 || true)"
if [[ -z "$CHECKSUM_LINE" ]]; then
  echo "Checksum entry not found for $ASSET" >&2
  exit 1
fi

(
  cd "$TMP_DIR"
  if command -v sha256sum >/dev/null 2>&1; then
    echo "$CHECKSUM_LINE" | sha256sum -c -
  else
    echo "$CHECKSUM_LINE" | shasum -a 256 -c -
  fi
)

tar -xzf "$TMP_DIR/$ASSET" -C "$TMP_DIR" chezmoi
mkdir -p "$BIN_DIR"
install -m 755 "$TMP_DIR/chezmoi" "$BIN_DIR/chezmoi"
