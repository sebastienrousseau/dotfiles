# shellcheck shell=bash
# Go Aliases

if command -v go &>/dev/null; then
  alias g='go'
  alias gr='go run'
  alias gb='go build'
  alias gt='go test'
  alias gta='go test ./...'
  alias gcv='go coverage'
  alias gfmt='go fmt'
  alias gvet='go vet'
  alias gmod='go mod'
  alias gmt='go mod tidy'
  alias gmv='go mod vendor'
  alias gget='go get'
  alias ginstall='go install'
fi
