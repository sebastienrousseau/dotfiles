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

Required post-commit effects use a separate append-only `effects.wal`. Core fsyncs
an `ATTEMPTED` entry before the effect and a `FAILED` or `SUCCEEDED` entry after it.
The stable idempotency key is derived from the sealed plan ID, commit phase and
effect index. A committed plan with no effect record reports `POST_COMMIT_PENDING`;
an attempted or failed effect reports `POST_COMMIT_FAILED`. `recover` and the
explicit `retry-effects` command retry without starting a plugin. A durable success
is never re-executed, and archive refuses an incomplete required effect.

The guarantee is at-least-once when a process dies after the external action but
before recording success. Future effect drivers must use the supplied key for
deduplication; the prototype does not claim exactly-once external side effects.
The only implemented effect is a managed-root directory fsync, so explicit rollback
after it has run has no compensating external action to perform.

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
flush guarantees require further work. Pre-`PREPARED` failures report `ABANDONED`
and block reuse until an operator invokes `discard-abandoned`. That operation removes
only validated, private, bounded stage/transaction entries when no complete first
`PREPARED` journal record exists. It is deletion-boundary resumable and idempotent;
durable recovery, archive and unknown evidence fail closed and remain untouched.
Terminal transactions are retained until explicit `archive --plan-id`. Core checks
the exact sealed ID, terminal state, current target snapshots, backups, artifacts
and stage before archiving. A durable `.dot-archive` intent covers moving stage
into the transaction and moving the transaction to `.dot-history/<plan-id>`.
Both parent directories are synced before removing the intent. `recover` resumes
interrupted archives without invoking plugins; ambiguous or edited state blocks.
While archiving, status is `ARCHIVING`; after successful retirement it is `IDLE`.
The kernel lock remains held across all lifecycle operations.

History is limited to 32 generations; overflow fails without deleting evidence.
Explicit retirement permits another apply with a fresh nonce and preconditions.
Rollback remains limited to the active generation. There is no history pruning,
archived-generation rollback, or byte quota on arbitrary corrupted history entries.

## Acceptance

Inject failures before and after prepare, commit intent, flush, rename, commit and rollback;
include a child process exiting without cleanup. Inject effect failure, interruption
after execution, and interruption after a durable success record. Verify hashes/modes and absence
restoration, preservation of concurrent edits, seal tampering and lock exclusion.
Additionally exercise five archive fault boundaries across staged/unstaged and
committed/rolled-back transactions, repeat recovery, and exit a real child process
after the history rename. Test evidence retention, full history, mismatched IDs,
changed stages/targets, symlinks, and refusal to archive incomplete transactions.
For abandonment, cover every pre-prepare materialization boundary and every discard
boundary with both injected errors and real process exits, stage-only and truncated
journals, repeated discard, preservation of managed-file edits, and refusal of
complete unknown journals or unexpected entries.
