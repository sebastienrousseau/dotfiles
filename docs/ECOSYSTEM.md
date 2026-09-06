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
| **MCP server** | `scripts/dot/commands/meta.sh` → `dot mcp`, discovery card at `.well-known/mcp/server-card.json` | See below. |
| **A2A agent card** | `.well-known/agent-card.json`, validated by `dot agent a2a-card --validate`, conformance suite via `dot agent conformance` | A static discovery document plus a subcommand. Nothing to host separately. |
| AI fleet TUI | `defaults/dot_local/share/dot-ai-tui/` (Go) | Tested by `cockpit-test.yml`. Ships as part of the config tree; useless without it. |
| `dot-ui` widgets | `defaults/dot_local/share/dot-ui/` (Go) | Tested by `dot-ui-test.yml`. Same reasoning. |
| **WASM tooling** | `lib/wasm-tools/` (Rust, crate `dot-sys`) | See below. |
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

### MCP — in-repo, and it should stay there

`dot mcp` exists today (`dot mcp doctor`, `dot mcp registry`), with a
discovery manifest at `.well-known/mcp/server-card.json` declaring a
stdio transport of `dot mcp --strict --json`.

It is a **governance surface, not a server**: it validates MCP policy,
audits the supply chain of configured MCP servers, and reports the
registry. It exposes the workstation's own state to an agent that
already has shell access to that workstation. There is no network
listener, no daemon, and no deployment target.

A separate `dotfiles-mcp` repository would therefore need to depend on
this one for every piece of data it serves, and would add a release
axis and a version-skew surface to buy nothing. The evidence that
in-repo is the right call: the manifest's transport is literally the
CLI binary this repo ships.

**When that would change:** if the MCP surface grew a network
transport, or needed to serve data about a machine other than the one
it runs on, it would become a deployable artefact with its own
lifecycle, and a satellite would then be right.

### LSP — does not exist, and should not

There is no language server, and none is planned.

An LSP satellite serves a language. This project's "language" surfaces
are shell scripts, Go templates, and TOML, each of which already has a
mature language server (`bash-language-server`, `taplo`, `marksman`)
that the Neovim configuration in `defaults/dot_config/nvim/` wires up.
Writing another would mean competing with those, for the sake of
completions this repo already generates natively from the command
registry via `dot completion` — a shell-completion problem, not a
language-server one.

**When that would change:** if `.chezmoidata.toml` grew a schema
complex enough that hover and go-to-definition over feature flags had
real value, an LSP over that schema would be defensible. Today the
schema is 40 lines and `docs/schema/chezmoidata.schema.json` plus
`taplo` covers it.

### WASM — in-repo, and marginal

`lib/wasm-tools/` is a Rust crate (`dot-sys`) whose build output is
gitignored, an experiment rather than a shipped surface: 11 lines of
`main.rs`. `wasmtime` is pinned in `mise.toml` for it.

It is not a satellite because it is not yet a product. Promoting an
experiment to its own repository is how you acquire a repository
nobody maintains.

**When that would change:** if the WASM tooling gained real
functionality and a consumer outside this repo, it would belong on
crates.io as its own crate — at which point a satellite repo is the
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

## Keeping this page honest

The claims above are checkable rather than aspirational:

| Claim | Verify with |
|---|---|
| `dot mcp` exists and is routed | `dot mcp --help`; route table in `bin/dot` |
| The MCP card points at the CLI | `jq .transport .well-known/mcp/server-card.json` |
| The A2A card is valid | `dot agent a2a-card --validate` |
| Card versions match the manifest | `bash scripts/verify-release-versions` (both cards are checked surfaces) |
| The three taps are generated, not authored | `pkg/README.md` and the `release-distribute-*.yml` workflows |
| The registry document is schema-valid | `bash tools/ci/check-registry.sh` |

If this page and the repository disagree, the repository wins and this
page is the bug.
