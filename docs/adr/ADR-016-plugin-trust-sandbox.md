# ADR-016: Explicit plugin trust and honest containment levels

Status: Accepted; audit-only development profile implemented.

## Decision

Never discover executable plugins through PATH. Production registry entries belong
in the platform's explicit `dot/plugins.d` directory and bind publisher identity,
signature, executable digest, protocol range, inputs and required containment.
Required containment must be enforced or invocation must fail closed.

The hello development registry lives inside its dedicated demo root. Core copies
an explicitly supplied executable, pins its SHA-256, and checks it before each
launch. This is local user-authorized trust, NOT a signed publisher registry.
Invocation requires `--allow-audit-plugin`. The reported level is `audit`:
environment filtering, deadlines and byte limits do not prevent filesystem or
network syscalls by a same-UID process. Run only the reviewed hello executable.

No ambient credentials, HOME, PATH or provider configuration are inherited. Shell
evaluation is absent. Stderr is bounded and discarded rather than persisted as
potentially sensitive text. Platform containment, memory/CPU/process/descriptor
limits and descendant containment are required before accepting untrusted plugins.

## Consequences and acceptance

Hash mismatch, symlink executable, invalid manifest, non-explicit registration and
missing audit consent must fail before spawning. Tests include stdout noise and
nonzero exits. Production trust-root rotation, signature verification, read-only
system registry precedence and OS-enforced profiles are separate follow-ups.
This reconciles ADR-003 without falsely promoting declarations to enforcement.
