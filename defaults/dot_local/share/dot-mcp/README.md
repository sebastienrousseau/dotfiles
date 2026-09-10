# dot-mcp

The Model Context Protocol server behind `dot mcp serve`. It speaks
JSON-RPC 2.0 over newline-delimited frames on stdin/stdout — exactly the
transport `.well-known/mcp/server-card.json` advertises — and exposes the
`dot` CLI's read-only governance surface to an MCP client. Deployed to
`~/.local/bin/dot-mcp`.

stdout carries protocol frames and nothing else. Every diagnostic goes to
stderr, because one stray byte on stdout desynchronises the client's
frame reader for the rest of the session.

## Wiring it into a client

```json
{
  "mcpServers": {
    "dotfiles": { "command": "dot", "args": ["mcp", "serve"] }
  }
}
```

`dot mcp serve` resolves the dotfiles checkout and the `dot` binary and
execs this server with both exported (`DOT_MCP_REPO_ROOT`,
`DOT_MCP_DOT_BIN`). Running `dot-mcp serve` directly works too: it walks
up from the working directory to find the checkout and takes `dot` from
`PATH`.

## What it serves

| Method | Behaviour |
| :--- | :--- |
| `initialize` | Negotiates `2025-06-18`, `2025-03-26` or `2024-11-05`; declares tools, resources and logging |
| `notifications/initialized` | Completes the handshake; unknown notifications are ignored |
| `ping` | Answers before initialization too, so a client can probe liveness |
| `tools/list`, `tools/call` | The four tools below |
| `resources/list`, `resources/read`, `resources/templates/list` | The five documents below (no templates) |
| `logging/setLevel` | Sets the minimum severity of `notifications/message` |

Every tool is read-only, runs a fixed argument vector through `dot`
without a shell, and is annotated `readOnlyHint: true`. Mutating paths
(`dot mode set`, `dot attest --write`, anything under `dot apply`) are
deliberately not exposed — an MCP client cannot change this workstation
through this server. The one write any tool causes is the audit-log line
`dot mode` appends for every invocation, human or otherwise.

| Tool | Runs | Arguments |
| :--- | :--- | :--- |
| `mcp-doctor` | `dot mcp doctor --json [--strict]` | `strict` (boolean) |
| `agent-mode` | `dot mode current\|list\|show <profile>` | `action` (enum), `profile` (pattern-checked, required for `show`) |
| `workstation-attestation` | `dot attest --json` | none |
| `fleet-status` | `dot fleet status --json` | none |

A tool whose command prints a JSON object returns it as
`structuredContent` with the exit code attached. A non-zero exit is not
automatically a failure: `dot mcp doctor` exits 1 when it finds policy
problems and still returns the report that was asked for. `isError` is
set only when the command produced no usable report.

| Resource | Document |
| :--- | :--- |
| `dotfiles://mcp/policy` | `dot_config/dotfiles/mcp-policy.json` |
| `dotfiles://mcp/registry` | `dot_config/dotfiles/mcp-registry.json` |
| `dotfiles://mcp/server-card` | `.well-known/mcp/server-card.json` |
| `dotfiles://agent/profiles` | `dot_config/dotfiles/agent-profiles.json` |
| `dotfiles://agent/card` | `.well-known/agent-card.json` |

The URI table is closed: a client names a URI, never a path, so there is
no traversal surface. `MCP_POLICY_CONFIG`, `MCP_REGISTRY_CONFIG` and
`AGENT_PROFILE_CONFIG` are honoured, as they are by the bash commands.

`dot-mcp tools` prints the tool and resource manifest as JSON without
speaking the protocol, for inspecting or diffing what is served.
`TestServerCardMatchesRegistry` asserts the same registry against the
published card, in both directions.

See [FEATURES.md](FEATURES.md) for the full feature → test matrix.

## Development

Go MSRV: **1.26** (`go.mod`), standard library only. Everything below
runs from this directory.

```bash
go build -o ~/.local/bin/dot-mcp .    # build the binary chezmoi deploys
go test ./...                         # unit, e2e, example + fuzz-corpus replay
go test -race -count=3 ./...
go test -coverprofile=cov.out ./... && go tool cover -func=cov.out | tail -1   # gate: >= 98%
go test -bench . -benchtime=1x -run '^$' ./...   # every benchmark once (CI smoke)
go test -fuzz FuzzServeSession -fuzztime=60s ./...
go vet ./... && staticcheck ./... && golangci-lint run ./...
```

Drive it by hand:

```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | dot mcp serve | jq .
```

`TestEndToEndProtocolExchange` does the same thing against the compiled
binary over real pipes; unit tests prove the handlers behave, only that
one proves the process speaks the protocol.
