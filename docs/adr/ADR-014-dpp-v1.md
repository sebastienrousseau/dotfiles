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
materialize, validate and shutdown. No post-commit hook is advertised by hello;
future hooks may return only core-authorized effect requests.

Proposal identity binds observed preconditions, ordered slots, nonce and executable
digest. Core seals the final plan only after verifying materialized bytes and
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
