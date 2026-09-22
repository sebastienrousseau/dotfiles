# ADR-018: Read-only MCP build and transport boundary

Status: Accepted target; isolated MCP service not implemented by hello.

## Decision

The eventual MCP executable may import only immutable snapshot DTOs and read-only
transport clients, never transaction, installer, effect or secret-broker packages.
Core will publish redacted snapshots on a distinct private socket/named pipe with
peer-identity checks, bounded messages and an optional stdio bridge. No mutating
methods are compiled into that listener. Slow tasks remain read-only diagnostics.

The existing MCP server remains a legacy compatibility surface. The prototype's
local `status` command is not the isolated MCP service: it opens the core lock and
therefore must not be exposed as the promised read-only socket implementation.
MCP revision support must be based on published specifications and conformance
fixtures; a future revision date in a roadmap is not proof of implementation.

## Acceptance

Before migration, a build dependency test must reject any mutation-package import,
including transitive imports; transport tests must reject unauthorized peers and
mutation-shaped requests. Record model/context/diagnostic metadata only, never
conversation text or credentials. ADR-012 remains unrelated to this trust boundary.
