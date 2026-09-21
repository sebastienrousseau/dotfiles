# ADR-015: Durable transactions and conservative recovery

Status: Accepted; restricted Unix hello transaction implemented.

## Decision

Core serializes operations with a kernel-held lock. It snapshots type, hash, mode,
owner and group; seals artifacts and backups in a private directory; flushes files
and directory entries before recording `PREPARED`. `COMMITTING` is append-and-fsync
before any replacement. Each replacement uses a same-directory exclusive temporary
file, file fsync, atomic rename and parent-directory fsync. Preconditions are checked
again immediately before replacement. `COMMITTED` is durable only after all writes.

Recovery does not execute plugins. An interrupted commit rolls back in reverse order
when each target matches either its before or sealed after state. A third state,
missing/corrupt backup or invalid seal blocks mutation with `DOT_E_RECOVERY_REQUIRED`.
Explicit rollback of a committed generation uses the same conflict protection.
Incomplete trailing journal records are discarded, never interpreted as committed.
Rollback interruption is resumable and repeated recovery is idempotent.

## Scope and limitations

Hello admits at most 16 private, regular, single-link files, 64 KiB each, and flat
ASCII names under a dedicated newly initialized root. Actual hello policy permits
two fixed filenames. Symlinks, hard links, special files and existing broad roots
are rejected. Rooted Go filesystem operations retain directory handles. Filesystems
must support reliable rename, flock and fsync; network filesystems are unsupported.
Independent writers with the same user authority cannot be fully excluded by flock;
the demo root is exclusive to this experiment. This is not a general atomic multi-file
filesystem or proof against malicious same-UID writers.

Windows mutation fails closed pending a handle-based replace/ACL implementation.
Process-crash tests are not hardware power-loss certification; macOS full hardware
flush guarantees require further work. Pre-PREPARED failures retain the incomplete
transaction as evidence and block reuse; automatic abandoned-stage cleanup is pending.
Transactions are retained, not silently pruned or reused for the next generation.

## Acceptance

Inject failures after prepare, commit intent, flush, rename, commit and rollback;
include a child process exiting without cleanup. Verify hashes/modes and absence
restoration, preservation of concurrent edits, seal tampering and lock exclusion.
