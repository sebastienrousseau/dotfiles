# Experimental DOT core / hello vertical slice

This is a **restricted development demonstration**, not a replacement for `dot`
or a production migration. Audit assurance works on macOS and Linux; experimental
process assurance is Linux-only and fails closed elsewhere. Only use the reviewed
hello binary.
See [ADRs 013–018](../docs/adr/README.md) for the boundaries and unfinished work.

```sh
cd core
go test -race ./...
demo_parent=$(mktemp -d)
go build -o "$demo_parent/dot-core" ./cmd/dot-core
go build -o "$demo_parent/dot-hello" ./cmd/dot-hello
go build -o "$demo_parent/dot-sandbox" ./cmd/dot-sandbox
"$demo_parent/dot-core" init --root "$demo_parent/managed"
"$demo_parent/dot-core" register --root "$demo_parent/managed" --plugin "$demo_parent/dot-hello"
"$demo_parent/dot-core" apply --root "$demo_parent/managed" --allow-audit-plugin
"$demo_parent/dot-core" status --root "$demo_parent/managed"  # COMMITTED
"$demo_parent/dot-core" retry-effects --root "$demo_parent/managed" # idempotent
"$demo_parent/dot-core" rollback --root "$demo_parent/managed"
"$demo_parent/dot-core" status --root "$demo_parent/managed"  # ROLLED_BACK
demo_plan=$("$demo_parent/dot-core" plan-id --root "$demo_parent/managed")
"$demo_parent/dot-core" archive --root "$demo_parent/managed" --plan-id "$demo_plan"
"$demo_parent/dot-core" status --root "$demo_parent/managed"  # IDLE
"$demo_parent/dot-core" apply --root "$demo_parent/managed" --allow-audit-plugin
```

On Linux kernels with Landlock ABI 3 or newer, the same hello lifecycle can require
the experimental process boundary. Process-assured plugins must be statically
linked ELF executables so their loader and shared libraries cannot expand the
Landlock read/execute boundary:

```sh
CGO_ENABLED=0 go build -o "$demo_parent/dot-hello" ./cmd/dot-hello
"$demo_parent/dot-core" init --root "$demo_parent/contained"
"$demo_parent/dot-core" register --root "$demo_parent/contained" \
  --plugin "$demo_parent/dot-hello" --assurance process
"$demo_parent/dot-core" apply --root "$demo_parent/contained" \
  --require-process-sandbox
```

`dot-sandbox` must be installed beside `dot-core`. It restricts the plugin to its
exact executable and private staging directory with Landlock, applies
`no_new_privs`, bounded address-space/CPU/file-size/descriptor limits and a
seccomp deny policy for network, namespace, process escape, mount, tracing and
other high-risk syscalls. It also denies external metadata mutation, anonymous
executable creation and changing the parent-death contract. Unsupported kernels
and architectures fail closed.

Keep the demonstration directory to inspect `.dot-txn/plan.json`, its WAL and
backups. Do not point this tool at HOME, a repository, or an existing config tree.
`init` refuses existing directories. Only core writes targets; the plugin writes
two files in `.dot-stage`, returns hashes and exits before commit. Recovery needs
no plugin and refuses to overwrite independently changed targets.

The sealed hello plan also contains one required, typed `sync:managed-root`
post-commit effect. Core records an attempt before executing it and records its
result afterward in `effects.wal`; both records are fsynced. A failed or interrupted
effect reports `POST_COMMIT_FAILED`, keeps the committed files and evidence, and can
be retried with `retry-effects` or `recover`. Every retry reuses the same SHA-256
idempotency key. Archiving is blocked until required effects have succeeded.

This is deliberately a mechanical proof, not a general reload framework. The only
driver fsyncs the managed demo root. Core rejects commands, paths, PIDs, plugin
callbacks, optional failure policies and any unknown effect. An interruption after
the external action but before its success record is at-least-once delivery; future
externally visible drivers must deduplicate the stable key.

Only an explicit `archive --plan-id` retires a terminal transaction. Its plan,
WAL, artifacts, backups and stage are retained in `.dot-history/<plan-id>`;
target contents are not changed. A durable `.dot-archive` intent makes both
directory renames recoverable with `recover`. Interrupted archives report
`ARCHIVING` and block apply/rollback until recovery finishes. Before archiving,
core verifies terminal state, target preconditions and retained evidence. A
changed target blocks recovery rather than overwriting the user's edit.

History is capped at 32 generations (not a whole-directory byte quota); reaching
the cap fails without deleting evidence. There is no automatic pruning or archived
generation rollback. Rollback applies only to the active generation; archive it
only when this is the intended choice.

Plugin or host failure before the transaction journal reaches a complete,
newline-terminated, fsynced `PREPARED` record can leave bounded `.dot-stage` or
`.dot-txn` artifacts. `status` reports `ABANDONED` for this state. An operator may
run `discard-abandoned`. The command validates private directory ownership, a
closed entry allowlist, file identity and journal state before deleting anything.
It is idempotent and resumable at each deletion boundary, never changes managed
targets, and refuses durable `PREPARED`, archive or unknown evidence; those states
require recovery or investigation.

Audit-mode Unix plugins run in a separate process group; core kills remaining same-group
children before committing, on protocol failure and on timeout. A child can
deliberately escape that group. This is process cleanup, **not OS containment**.
The Darwin kernel inspection dependency is pinned in `go.mod`/`go.sum`.

Flags are command-specific: only `register` accepts `--plugin` and `--assurance`,
only `apply` accepts exactly one of `--allow-audit-plugin` or
`--require-process-sandbox`, and only `archive` accepts `--plan-id`.
`discard-abandoned` accepts no destructive scope beyond the explicit demo root. Unknown
commands, irrelevant flags, missing registration/archive arguments and absent
assurance consent are rejected before opening the root. Direct CLI tests cover these
negative paths and two complete apply/archive generations.

Registration and initialization also bind the exact restricted profile, requested
`audit` or `process` assurance and capability set. A plugin cannot silently
downgrade containment or drop/reorder capabilities after the user grants consent.
Protocol negotiation alone does not create a sandbox; core selects and enforces
the platform runner before accepting the claimed process assurance.

Garbage collection, production registry signatures, macOS/Windows process
containment, a default-deny syscall allowlist, full JCS, production effect drivers,
Windows ACL/replace semantics, secret brokering and read-only MCP isolation remain
separate gates. The Linux runner is an experimental hello-profile proof: Landlock
has documented mediation limits and signed, tamper-resistant publisher installation
is still absent. On Linux, core now opens and validates the plugin and fixed sibling
runner once, then executes those exact inodes through inherited `/proc/self/fd`
descriptors. Replacing either pathname after validation cannot select different
bytes. macOS audit mode retains the documented pathname race; process assurance
continues to fail closed there and on Windows.
The tests simulate process crashes and I/O errors; they do not certify physical
power-loss durability or resistance to a malicious same-UID plugin. No release
version is bumped by this experimental module.
