#!/usr/bin/env bash
# Legal & Licensing Aliases
# Tools for license compliance, headers, and attribution.

# -----------------------------------------------------------------------------
# FOSSology & License Scanning
# -----------------------------------------------------------------------------

# Start a local FOSSology instance for deep scan
if command -v docker &>/dev/null; then
  alias fossology-start='docker run -d -p 8081:80 --name fossology fossology/fossology && echo "FOSSology started at http://localhost:8081"'
  alias fossology-stop='docker stop fossology && docker rm fossology'
fi

# Lightweight license check (using trivy as a modern proxy for compliance scanning)
if command -v trivy &>/dev/null; then
  alias scan-licenses='trivy fs . --scanners license'
else
  if [ "$(uname -s)" = "Darwin" ] && command -v brew >/dev/null; then
    alias scan-licenses='echo "trivy not found. Installing via homebrew..." && brew install trivy && trivy fs . --scanners license'
  else
    alias scan-licenses='echo "trivy not found. Install trivy to use scan-licenses."'
  fi
fi

# -----------------------------------------------------------------------------
# Copyright Headers (add-headers)
# -----------------------------------------------------------------------------

# Using google/addlicense (Go) via Docker to avoid local deps
# Usage: add-headers
add_headers_fn() {
  local holder="${GIT_AUTHOR_NAME:-Sebastien Rousseau}"
  echo "Adding MIT license headers for: $holder"
  docker run --rm -v "$(pwd):/src" -w /src ghcr.io/google/addlicense \
    -c "$holder" \
    -l mit \
    -v \
    .
}
alias add-headers=add_headers_fn

# -----------------------------------------------------------------------------
# NOTICE generation (`gen-notice`)
# -----------------------------------------------------------------------------

# Generate attribution report for Go projects (expandable to others)
gen_notice_fn() {
    echo "Generating NOTICE file for dependencies..."
    if [ -f "go.mod" ]; then
        docker run --rm -v "$(pwd):/src" -w /src golang:latest \
            sh -c "go install github.com/google/go-licenses@latest && go-licenses report . --template /src/NOTICE.tpl > NOTICE"
    else
        echo "️  No supported package manager found for automatic NOTICE generation."
    fi
}
alias gen-notice=gen_notice_fn

# -----------------------------------------------------------------------------
# CLA Checking
# -----------------------------------------------------------------------------

# Check CLA status for the current branch's PR
check_cla_fn() {
  if command -v gh &>/dev/null; then
    echo "Checking PR checks for CLA status..."
    gh pr checks --watch
  else
    echo " GitHub CLI (gh) not found."
  fi
}
alias check-cla=check_cla_fn
