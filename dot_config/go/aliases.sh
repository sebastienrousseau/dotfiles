#!/usr/bin/env bash
# Go aliases and functions

# Aliases for common Go commands
alias got='go test ./...'
alias gotr='go test -race ./...'
alias gotv='go test -v ./...'
alias gotc='go test -cover ./...'
alias gom='go mod tidy'
alias gomu='go mod tidy && go mod verify'
alias gob='go build ./...'
alias gor='go run .'
alias gog='go generate ./...'
alias gov='go vet ./...'
alias gof='gofumpt -w .'
alias gol='golangci-lint run'
alias golf='golangci-lint run --fix'

# Go doc server
alias godocs='godoc -http=:6060'

# Update all Go tools
go-update-tools() {
  echo "Updating Go tools..."
  local tools=(
    "golang.org/x/tools/gopls@latest"
    "github.com/go-delve/delve/cmd/dlv@latest"
    "mvdan.cc/gofumpt@latest"
    "github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
  )
  for tool in "${tools[@]}"; do
    echo "Installing $tool..."
    go install "$tool"
  done
  echo "Done!"
}

# Create new Go module
go-new() {
  local name="${1:?Usage: go-new <module-name>}"
  mkdir -p "$name" && cd "$name" || return
  go mod init "$name"
  cat > main.go << 'EOF'
package main

import "fmt"

func main() {
	fmt.Println("Hello, World!")
}
EOF
  echo "Created new Go module: $name"
}

# Run tests with coverage and open in browser
go-cover() {
  local profile="${1:-coverage.out}"
  go test -coverprofile="$profile" ./...
  go tool cover -html="$profile"
  rm -f "$profile"
}
