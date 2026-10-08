---
render_with_liquid: false
---

# MCP Policy

MCP is treated as a controlled execution boundary.

## Default posture

The tracked default is `strict-local`.

Properties:

- local-first
- least privilege
- no broad filesystem roots
- no wildcard or unsafe flags
- no network-facing MCP servers enabled by default
- machine-readable validation output

## Policy artifact

The source of truth lives in [mcp-policy.json](https://github.com/sebastienrousseau/dotfiles/blob/main/defaults/dot_config/dotfiles/mcp-policy.json).
Approved package pins live in [mcp-lock.json](https://github.com/sebastienrousseau/dotfiles/blob/main/defaults/dot_config/dotfiles/mcp-lock.json).
Tracked server registry entries live in [mcp-registry.json](https://github.com/sebastienrousseau/dotfiles/blob/main/defaults/dot_config/dotfiles/mcp-registry.json).

Current defaults:

- Allowed launchers: `npx`, `node`, `uvx`; inline code (`node -e`, `sh -c`) is flagged
- Trusted transports: `stdio`, `http`, read from Claude's `type` key (or the older `transport`)
- Blocked filesystem roots: `/`, `/home`, `/Users`, checked on every server's
  arguments after normalising `..`, `//`, `~` and `${HOME}` (an error)
- Blocked argument patterns: `^--allow-.*`, `^--unsafe$`, `^\\*$`
- Network-facing servers disabled by default: `github`, `brave-search`, `fetch`, `puppeteer`, `filesystem`,
  matched by server key and by the package a server runs
- Approved packages must resolve through the tracked MCP lock manifest
- Every active server must match the tracked MCP registry
- `http`, `sse` and `streamable-http` transports must use `https://` (an error) and registry-declared OAuth2

Besides the managed `mcp_servers.json`, `dot mcp` checks the configs Claude Code
reads: `~/.claude.json` (user and project scopes), the `.mcp.json` of every
project listed there, and the working directory's `.mcp.json`.

## Validation

Run:

```bash
dot mcp --strict
dot mcp -s -j
dot mcp registry
```

The JSON form is the audit artifact for CI, release validation, and workstation attestation.

## Change control

Any change to MCP policy requires:

1. A signed commit
2. A matching test update
3. A release note if the effective trust boundary changes
4. A policy bundle review when enterprise defaults change

## Supply-chain controls

The default servers are installed at `chezmoi apply` time from committed,
hash-pinned manifests, and `mcp_servers.json` runs the installed binaries
under `~/.local/share/dot-mcp/`. Nothing is fetched by `npx -y` or `uvx` when
Claude starts a server.

| Server | Package | Manifest | Install |
|---|---|---|---|
| `git` | `mcp-server-git==2026.8.18` (PyPI) | `python/git/requirements.txt` | `uv pip install --require-hashes` into its own venv |
| `sqlite` | `mcp-server-sqlite==2025.4.25` (PyPI) | `python/sqlite/requirements.txt` | `uv pip install --require-hashes` into its own venv |
| `memory` | `@modelcontextprotocol/server-memory@2026.8.31` (npm) | `node/package-lock.json` | `npm ci --ignore-scripts` |

`uvx --with-requirements` does not enforce the hashes in a requirements file,
so the Python servers get a venv each instead. The npm names `mcp-server-git`
and `mcp-server-sqlite` are not the official servers (one is an npm security
placeholder, the other a third-party package); the official ones ship on PyPI.

`dot mcp --strict` and `dot mcp -s` now verify that:

- package refs are version-pinned
- the pinned refs match the tracked lock manifest
- each lock entry's integrity hash is the one its committed manifest pins
  for that exact package, and the server runs the approved binary
- non-approved package refs are rejected in strict mode
- active servers match the tracked registry entries
- remote HTTP transports are HTTPS and OAuth-backed

Policy bundle baselines live in [policy-bundles.json](https://github.com/sebastienrousseau/dotfiles/blob/main/defaults/dot_config/dotfiles/policy-bundles.json).
