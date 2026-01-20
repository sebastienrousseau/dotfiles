# shellcheck shell=bash
# Go Aliases

if command -v go &>/dev/null; then
  alias go='go'
  alias gor='go run'
  alias gob='go build'
  alias got='go test'
  alias gota='go test ./...'
  alias gocv='go coverage'
  alias gofmt='go fmt'
  alias govet='go vet'
  alias gomod='go mod'
  alias gomt='go mod tidy'
  alias gomv='go mod vendor'
  alias goget='go get'
  alias goinstall='go install'
fi
