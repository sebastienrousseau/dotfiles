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

On Unix, the hello host creates a dedicated process group and terminates remaining
same-group descendants before commit, on protocol failure and on timeout. The
leader is not reaped until the final group signal, avoiding group-ID reuse. Darwin
may return `EPERM` for a zombie-only group: a kernel query confined to that group
must confirm no live members before that case is accepted; query failures and live
members fail closed. Since EOF may precede the final kernel exit-state transition,
core signals and samples at most 50 times, separated by 2 ms, until every observed
member is a zombie or the group is absent; a timeout is never interpreted as
success. For Darwin's zombie-filter `EPERM` race, core stops signalling and permits
up to two seconds for the unreaped leader to become observably terminal; persistent
live state returns the original permission error. Deterministic tests cover
transitional, live, unknown, permission-race and failed-query states;
CI repeats 30 delayed descendants and 1,000 short-lived exits per Unix host. The
descendant fixture is released only after `Apply` returns, so slow test execution
cannot be mistaken for a surviving process. This uses pinned
`golang.org/x/sys` rather than parsing `ps`.
Tests spawn background children that outlive protocol descriptors and verify they
cannot write a delayed marker after success, malformed output or timeout. Children
can deliberately create another session/group; these tests do NOT establish an
OS-enforced process tree, filesystem or network boundary.

## Consequences and acceptance

Hash mismatch, symlink executable, invalid manifest, non-explicit registration and
missing audit consent must fail before spawning. Tests include stdout noise and
nonzero exits. Production trust-root rotation, signature verification, read-only
system registry precedence and OS-enforced profiles are separate follow-ups.
This reconciles ADR-003 without falsely promoting declarations to enforcement.
