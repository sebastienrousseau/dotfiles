# Go Aliases

Manage Go language aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `go.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. Every definition below exists only when `go` is on PATH.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `gor` | `go run` |  |
| `gob` | `go build` |  |
| `got` | `go test` |  |
| `gota` | `go test ./...` |  |
| `gocv` | `go coverage` | `go coverage` is not a Go subcommand. |
| `gofmt` | `go fmt` | This shadows the standalone `gofmt` binary. |
| `govet` | `go vet` |  |
| `gom` | `go mod tidy` |  |
| `gomod` | `go mod` |  |
| `gomv` | `go mod vendor` |  |
| `goget` | `go get` |  |
| `goinstall` | `go install` |  |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
