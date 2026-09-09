---
render_with_liquid: false
---

<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<!-- Copyright (c) 2015-2026 Sebastien Rousseau -->

# Ecosystem

**This is a single repository, deliberately.** The gold-standard
checklist asks multi-repo families for a CI-checked table of which
repo owns what, so the layout cannot silently drift. This page is that
table — and the argument for why the family currently has one member.

## What lives where

| Component | Where it lives | Why not a separate repo |
|---|---|---|
| `dot` CLI | `bin/dot` + `scripts/dot/commands/` + `lib/dot/` | It is the product. Splitting it from the configuration it manages would create a version-skew problem between the CLI and the config schema it reads (`defaults/.chezmoidata.toml`). |
| Configuration tree | `defaults/` (chezmoi source, rebased via `.chezmoiroot`) | Same reason, inverted: the config depends on the CLI's template data. |
| **MCP governance surface and server** | `scripts/dot/commands/meta.sh` → `dot mcp`, server in `defaults/dot_local/share/dot-mcp/` (Go), discovery card at `.well-known/mcp/server-card.json` | See below. |
| **A2A agent card** | `.well-known/agent-card.json`, validated by `dot agent a2a-card --validate`, conformance suite via `dot agent conformance` | A static discovery document plus a subcommand. Nothing to host separately. |
| AI fleet TUI | `defaults/dot_local/share/dot-ai-tui/` (Go) | Tested by `cockpit-test.yml`. Ships as part of the config tree; useless without it. |
| `dot-ui` widgets | `defaults/dot_local/share/dot-ui/` (Go) | Tested by `dot-ui-test.yml`. Same reasoning. |
| **WASM tooling** | `lib/wasm-tools/` (Rust, crate `dot-sys`) — *native binary despite the name* | See below. |
| Module registry | `docs/registry.json` + schema in `docs/schema/`, served over Pages, validated by `tools/ci/check-registry.sh` | A JSON document, not a service. |
| Packaging recipes | `pkg/` (brew, scoop, aur, nix, docker) | The *published* taps are separate repos and have to be — see the next table. |
| Documentation site | `docs/` → MkDocs → `doc.dotfiles.io` via `pages.yml` | Built from the same tree it documents; a docs repo would drift by construction. |

## Repositories that genuinely are separate

Three, and only because the tooling requires an external repository:

| Repo | Why it must be separate | Kept in sync by |
|---|---|---|
| `sebastienrousseau/homebrew-tap` | Homebrew requires a tap repository named `homebrew-*` | `release-distribute-homebrew.yml` opens a PR per release from `pkg/brew/dot.rb` |
| `sebastienrousseau/scoop-bucket` | Scoop requires a bucket repository | `release-distribute-scoop.yml`, from `pkg/scoop/dot.json` |
| `aur.archlinux.org/dot-cli-git` | AUR is its own git host | `release-distribute-aur.yml`, from `pkg/aur/PKGBUILD` |

None of these holds source. Each is a generated artefact of a release
and is never edited by hand.

## The three satellites the checklist asks about

### MCP — in-repo, and now a real server

`dot mcp` has two faces, both in-repo.

The **governance surface** is the older one: `dot mcp doctor` validates
MCP policy and audits the supply chain of the MCP servers *you* have
configured, and `dot mcp registry` prints the tracked registry.

The **protocol surface** is `dot mcp serve`: a stdio MCP server speaking
JSON-RPC 2.0 over newline-delimited frames on stdin/stdout. It
implements `initialize`, `notifications/initialized`, `ping`,
`tools/list`, `tools/call`, `resources/list`, `resources/read`,
`resources/templates/list` and `logging/setLevel`, and shuts down
cleanly on EOF. It is a third Go module,
[`defaults/dot_local/share/dot-mcp`](../defaults/dot_local/share/dot-mcp/README.md),
deployed to `~/.local/bin/dot-mcp` alongside `dot-ui` and `dot-ai-tui`.

Four tools are served, all read-only, each a fixed `dot` argument vector
run without a shell: `mcp-doctor`, `agent-mode`, `workstation-attestation`
and `fleet-status`. Mutating paths (`dot mode set`, `dot attest --write`)
are deliberately not exposed, so a client cannot change this workstation
through the server. Five resources expose the MCP policy, the MCP
registry, the agent profiles and both discovery cards.

`.well-known/mcp/server-card.json` now describes exactly that. It
previously advertised a transport of `dot mcp --strict --json` — a
one-shot audit report — together with `capabilities.tools`,
`capabilities.resources`, `capabilities.logging` and a four-entry
`tools[]` array, none of which existed. A client that followed the card
would have connected, sent `initialize`, and received a report it could
not parse. Rather than narrow the card, the protocol was implemented and
the card was corrected to match:

- `transport.stdio` is `dot mcp serve`, not `dot mcp --strict --json`
  — the flags kept their original meaning (strict audit, JSON output)
  instead of being overloaded into a mode switch;
- the four declared tools are the four served tools, and the check runs
  in both directions (`TestServerCardMatchesRegistry`);
- `capabilities.resources` and `capabilities.logging` stayed true
  because both are implemented; `prompts` stays false because no
  `prompts/*` handler exists, and a test fails if it is ever flipped
  without one.

The A2A card's `entrypoints.mcp` was updated from `dot mcp --strict
--json` to `dot mcp serve` for the same reason.

Even so, the *repository* conclusion is unchanged: this surface belongs
in-repo. It reads the workstation's own state, its declared transport is
the CLI binary this repo ships, and a satellite would need to depend on
this repo for every datum it serves.

**When that would change:** if it grew a real network transport, or
served data about a machine other than the one it runs on, it would
become a deployable artefact with its own lifecycle — and a satellite
would then be right.

### LSP — does not exist, and should not

There is no language server here, and none is planned.

The one file that might suggest otherwise is
`defaults/dot_config/nvim/.../lsp.lua`, and it is the opposite: that
configures Neovim as an LSP **client**, wiring up third-party servers
(`bash-language-server`, `taplo`, `marksman`) that this repo does not
author or ship. Consuming a protocol is not providing it.

An LSP satellite serves a language. This project's "language" surfaces
are shell scripts, Go templates and TOML, all three of which already
have mature servers. Writing another would mean competing with them
for the sake of completions this repo already generates natively from
the command registry via `dot completion` — a shell-completion
problem, not a language-server one.

**When that would change:** if `.chezmoidata.toml` grew a schema
complex enough that hover and go-to-definition over feature flags had
real value, an LSP over that schema would be defensible. Today the
schema is 40 lines and `docs/schema/chezmoidata.schema.json` plus
`taplo` covers it.

### WASM — in-repo, marginal, and **not actually WebAssembly**

`lib/wasm-tools/` is a Rust crate (`dot-sys`) with an 11-line
`main.rs` whose build output is gitignored. Three things about it are
worth stating plainly, because the directory name implies otherwise:

- `Cargo.toml` declares **no `wasm32` target and no `crate-type`**, so
  `cargo build` produces an ordinary native binary for the host.
- The program's entire behaviour is to print a timestamp — and a
  hardcoded `"engine": "wasm"` field, which is the only WebAssembly in
  it.
- `wasmtime` is pinned in `mise.toml` in anticipation of a runtime
  that nothing currently uses.

So it is an experiment with an aspirational name, not a shipped
surface. It is not a satellite because it is not yet a product;
promoting an experiment to its own repository is how you acquire a
repository nobody maintains.

**When that would change:** if it gained real functionality, an actual
`wasm32-*` target, and a consumer outside this repo, it would belong
on crates.io as its own crate — and a satellite repo would then be the
right home, because Rust crates version independently.

## The rule

A satellite repository is justified when a component has **an
independent release cadence and an independent consumer**. Both, not
either.

- `homebrew-tap` — both (Homebrew's cadence, Homebrew's users).
- `dot mcp` — neither: it releases with the CLI and its only consumer
  is an agent already on this machine.
- `lib/wasm-tools` — neither yet.

Splitting a component that fails this test moves complexity from a
directory boundary (free, enforced by review) to a repository boundary
(a release, a version constraint, a CI pipeline, and a place for
skew to hide).

## Corrections made while auditing this page

Two statements in the published discovery cards were factually wrong
and are fixed:

| File | Was | Now |
|---|---|---|
| `.well-known/agent-card.json` | `"url": "https://github.com/sebastienvermeille/dotfiles"` | `sebastienrousseau` — the card pointed at a different person's GitHub account |
| `.well-known/mcp/server-card.json` | `"policyRef": "dot_config/dotfiles/mcp-policy.json"` | `defaults/dot_config/...` — the path moved in the [`.chezmoiroot` reorg](operations/RFC_v0_2_503_reorganization.md) |

Both cards were also 18 releases stale at `0.2.501` while the project
shipped `0.2.519`. They are now checked by
`scripts/verify-release-versions` on every push and rewritten by
`scripts/version-sync.sh` at release time, so neither can drift again.

The larger discrepancy — the MCP card advertising a server that did
not exist — was resolved by implementing the protocol rather than
narrowing the card. `dot mcp serve` now serves every tool, resource and
capability the card declares, and the card and the registry are pinned
to each other by tests that fail in both directions.

## Keeping this page honest

The claims above are checkable rather than aspirational:

| Claim | Verify with |
|---|---|
| `dot mcp` exists and is routed | `dot mcp --help`; route table in `bin/dot` |
| `dot mcp serve` **is** an MCP server | `printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' \| dot mcp serve` returns an `initialize` result |
| The card and the server agree | `cd defaults/dot_local/share/dot-mcp && go test -run TestServerCard ./...` |
| The MCP card points at the server | `jq .transport .well-known/mcp/server-card.json` → `dot mcp serve` |
| `lib/wasm-tools` builds natively, not to wasm | `grep -c wasm32 lib/wasm-tools/Cargo.toml` → 0 |
| The A2A card is valid | `dot agent a2a-card --validate` |
| Card versions match the manifest | `bash scripts/verify-release-versions` (both cards are checked surfaces) |
| The three taps are generated, not authored | `pkg/README.md` and the `release-distribute-*.yml` workflows |
| The registry document is schema-valid | `bash tools/ci/check-registry.sh` |

If this page and the repository disagree, the repository wins and this
page is the bug.
