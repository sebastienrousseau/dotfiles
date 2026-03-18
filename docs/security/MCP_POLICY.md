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

The source of truth lives in [mcp-policy.json](/home/seb/.dotfiles/dot_config/dotfiles/mcp-policy.json).
Approved package pins live in [mcp-lock.json](/home/seb/.dotfiles/dot_config/dotfiles/mcp-lock.json).

Current defaults:
- Allowed launchers: `npx`, `node`, `uvx`
- Blocked filesystem roots: `/`, `/home`, `/Users`
- Blocked argument patterns: `^--allow-.*`, `^--unsafe$`, `^\\*$`
- Network-facing servers disabled by default: `github`, `brave-search`, `fetch`, `puppeteer`, `filesystem`
- Approved packages must resolve through the tracked MCP lock manifest

## Validation

Run:

```bash
dot mcp --strict
dot mcp --strict --json
```

The JSON form is the audit artifact for CI, release validation, and workstation attestation.

## Change control

Any change to MCP policy requires:
1. A signed commit
2. A matching test update
3. A release note if the effective trust boundary changes

## Supply-chain controls

Phase 2 adds explicit package locking for default MCP servers.

Current approved refs:
- `mcp-server-git@2025.1.14`
- `@modelcontextprotocol/server-memory@2025.8.4`
- `mcp-server-sqlite@2025.1.14`

`dot mcp --strict` now verifies that:
- package refs are version-pinned
- the pinned refs match the tracked lock manifest
- non-approved package refs are rejected in strict mode
