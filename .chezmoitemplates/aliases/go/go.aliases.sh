# shellcheck shell=bash
# Copyright (c) 2015-2026 . All rights reserved.
# Go Aliases

if command -v go &>/dev/null; then
  alias gor='go run'
  alias gob='go build'
  alias got='go test'
  alias gota='go test ./...'
  alias gocv='go coverage'
  alias gofmt='go fmt'
  alias govet='go vet'
  alias gom='go mod tidy'
  alias gomod='go mod'
  alias gomv='go mod vendor'
  alias goget='go get'
  alias goinstall='go install'
fi
