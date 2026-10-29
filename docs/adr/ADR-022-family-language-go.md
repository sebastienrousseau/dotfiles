# ADR-022: Go for the dot family's compiled code

Status: Accepted 2026-10-18.

Status note (0.2.539): the decision governs compiled code as it is written.
Today the host `bin/dot` is bash, and `dot top` (`plugins/top/dot-top`)
is bash too: it runs `lib/dot/bento.sh`. The Go code in the tree is
`core/` (`dot-core`, `dot-sandbox`, the transaction engine),
`dot-ai-tui`, `dot-mcp` and `dot-ui` (under
`defaults/dot_local/share/`), the fuzz harnesses in `fuzz/` and the
`templates/projects/go` template.

## Context

The family's compiled code is the `dot-cli` host, the `dot-top` monitor,
`dot-mcp` and `dot-ui` (see the status note for what is Go today). The question
came up whether `dot-top` should move to Rust or C++, since btop is C++.

Measured on the maintainer's Mac: a Go collector reading process data
through libproc used 0.45% CPU and 9.3 MiB, against btop's 2.05% and
11.3 MiB. The cost in today's Go TUI is frame composition in Lip Gloss
(1.8 to 2.6 ms and about 18k allocations per frame), which a renderer that
draws graphs and tables into a cell buffer fixes without a new language.

## Decision

- The host, `dot-top` (Bubble Tea v2 and Lip Gloss v2), `dot-mcp` and
  `dot-ui` are Go. Configuration stays shell and chezmoi templates.
- Rust is used only for `dot-attest`'s WebAssembly verifier. No C++.
- Builds use `CGO_ENABLED=0`; macOS frameworks are called through purego.
- `dot-top` must reach 1% CPU or less and 20 MiB or less on an end-to-end
  benchmark (600 processes, a 200×60 terminal, 1 s refresh). A miss is
  fixed in the Go renderer, not by changing language.

## Consequences

- One compiled language in the plugin template, the shared CI and the
  release workflow, besides the one Rust verifier.
- Static, cross-compiled binaries for every tier 1 and tier 2 platform
  without a C toolchain.

Related: [ADR-020](ADR-020-command-naming-system.md), [ADR-021](ADR-021-family-lockstep-version.md).
