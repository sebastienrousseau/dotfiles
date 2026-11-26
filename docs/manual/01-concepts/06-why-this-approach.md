---
render_with_liquid: false
---

<!-- Moved from the README (wave 2, R2.3); the text is unchanged. -->

# Why this approach?

Most dotfiles repositories are personal collections. This one is
built as workstation infrastructure: chezmoi is the templating
engine ([ADR-005](../../../docs/adr/ADR-005-chezmoi-choice.md)), `dot` is the
lifecycle CLI on top ([ADR-004](../../../docs/adr/ADR-004-cli-architecture.md)),
and every claim on this page has a test, a workflow, or a document
behind it.

Three choices you will not find in `mathiasbynens/`, `holman/`, or
`paulirish/`:

1. **Wallpaper-driven terminal themes.** K-Means clustering in
   CIELAB extracts a palette from any wallpaper; the engine enforces
   WCAG AAA (7:1) contrast and writes `themes.toml` itself. 296
   generated themes ship today
   ([ADR-009](../../../docs/adr/ADR-009-wallpaper-driven-theming.md)).
2. **First-class agent governance.** Bounded profiles (`ask` /
   `plan` / `apply` / `audit`), MCP policy enforcement, A2A
   discovery, and signed attestation logs for every agent session
   ([`docs/security/MCP_POLICY.md`](../../../docs/security/MCP_POLICY.md),
   [`docs/interop/A2A.md`](../../../docs/interop/A2A.md)).
3. **Verified multi-shell parity.** One alias and function hub
   feeds zsh, bash, fish, nushell, and PowerShell; a parity contract
   runs the canonical command surface in every available shell on
   every PR ([ADR-007](../../../docs/adr/ADR-007-multi-shell-parity.md)).

Two architectural choices make the rest cheap:

- **Lazy hydration.** The prompt paints first from static escape
  codes; tool initialisations (`mise`, `atuin`, `zoxide`, `starship`)
  run through `_cached_eval`, which sources cached `init` output and
  invalidates on the binary's mtime and realpath. Heavy binaries
  resolve asynchronously after the first prompt
  ([ADR-002](../../../docs/adr/ADR-002-shell-performance.md)).
- **Idempotent, verifiable apply.** `dot sync` is chezmoi apply plus
  drift detection; `dot doctor fix` repairs tools, symlinks, and missing
  files; `dot doctor rollback` returns to a known-good state; a chaos
  test (`scripts/ops/chaos.sh`) breaks things on purpose to prove the
  loop closes.

The default install is signed (SSH ed25519 commits enforced on
`main`), attested (SLSA provenance and Cosign-signed SBOM per
release), multi-platform (macOS, Linux, WSL2, Apple Silicon CI
runners, Windows PowerShell), and schema-checked (`.chezmoidata.toml`
against [`config/chezmoidata.schema.json`](../../../config/chezmoidata.schema.json)
via taplo on every PR).
