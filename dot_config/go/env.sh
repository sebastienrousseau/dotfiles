#!/usr/bin/env bash
# Go environment configuration
# Source this file in your shell rc

# GOPATH and GOBIN
export GOPATH="${GOPATH:-$HOME/go}"
export GOBIN="${GOBIN:-$GOPATH/bin}"

# Add Go bin to PATH
[[ ":$PATH:" != *":$GOBIN:"* ]] && export PATH="$GOBIN:$PATH"

# Go environment variables
export GOPROXY="https://proxy.golang.org,direct"
export GOPRIVATE=""
export GOFLAGS="-trimpath"

# Default build tags (can be overridden per project)
export GOFLAGS="${GOFLAGS} -tags="

# Enable Go modules
export GO111MODULE="on"

# CGO settings
export CGO_ENABLED="${CGO_ENABLED:-1}"
