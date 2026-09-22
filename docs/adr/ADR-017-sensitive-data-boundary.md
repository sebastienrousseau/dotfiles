# ADR-017: Secret references, not secret payloads

Status: Accepted; no secret capability in the hello profile.

## Decision

Plans, WAL records, cache keys, diagnostic events and generic DPP messages must not
contain plaintext credentials or secret-derived fingerprints. The core-owned broker
will decrypt SOPS/age data in memory and issue short-lived audience-scoped handles.
Plugins request references, not values. Telemetry uses an allowlist of event fields;
`sensitivity: secret` is defense in depth, not permission to serialize a secret.

The hello profile has no broker or secret materialization capability and must never
be pointed at existing user configuration. Its backups are private files containing
the two non-secret demonstration outputs only. Provider token injection is not
implemented by this milestone. Unknown fields such as `value`, `token` and `prompt`
are rejected by the secret-reference/event schemas.

## Acceptance

Schema fixtures include secret canaries and reject unknown event/secret fields.
Plugins receive a minimal explicit environment. Future broker work must test audience
and lifetime checks, redaction before event construction, cancellation, pipe/handle
closure and prevention of secrets entering rollback journals or support bundles.
