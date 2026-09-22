# ADR-014: DPP framing, profiles and sealing

Status: Accepted; hello profile implemented, full DPP conformance remains gated.

## Decision

Use [JSON-RPC 2.0](https://www.jsonrpc.org/specification) over stdio with exactly
`Content-Length: N\r\n\r\n` followed by N UTF-8 bytes. Stdout is protocol-only.
The hello profile caps frames at 64 KiB, nesting at 16, total stdout at 512 KiB,
stderr at 8 KiB and an invocation at five seconds. It uses positive sequential
integer request IDs, one outstanding request, and no notifications or batching.
Duplicate keys, unknown fields, extra headers, mismatched IDs and trailing output
are rejected. Unsupported profiles are not silently treated as compatible.

Initialize binds version, plugin identity and a random 256-bit nonce. Plan precedes
materialize, validate and shutdown. The hello profile advertises the ordered
`post-commit-effects` capability and returns a bounded typed effect list in its
plan response. Core accepts only its exact allowlisted root-sync request; there is
no generic hook invocation or user-controlled executable.
The persisted plan schema keeps `effects` optional solely so core can inspect and
recover pre-capability hello transactions; a newly negotiated hello proposal must
contain the exact required effect.

The restricted profile negotiates all security-relevant dimensions explicitly:
profile `org.dot.hello/v1`, assurance `audit`, and the exact ordered capability set
`materialize`, `plan`, `post-commit-effects`, `validate`. The manifest binds profile
and assurance before launch. Core sends its required values and nonce in `dot.initialize`; the plugin
must echo an exact identity, profile, assurance, capability set, protocol and nonce.
Missing, reordered, added or downgraded values fail before planning. Audit consent
does not satisfy or impersonate a future OS-enforced assurance level.

Proposal identity binds observed preconditions, ordered slots, typed effects, nonce
and executable digest. Core seals the final plan only after verifying materialized bytes and
terminating the plugin. SHA-256 hashes canonical bytes, excluding `plan_id` itself.
The [JCS](https://www.rfc-editor.org/rfc/rfc8785) hello subset accepts printable
ASCII strings and nonnegative safe integers only; keys sort lexically. Unicode,
fractions and larger integers fail rather than receiving a misleading JCS hash.
General DPP requires a full JCS implementation and official cross-language vectors.

## Consequences and acceptance

Version 1 is negotiated with a named restricted profile, not a claim that every
future plugin capability exists. Tests cover framing, correlation, bounds and
canonical order. Fuzzing runs independently. A general RPC server must add standard
JSON-RPC error responses and negotiated `dot.log` notifications before advertising
general DPP compatibility. The restricted executable currently terminates on errors.
