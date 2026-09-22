# Experimental DOT core / hello vertical slice

This is an **audit-only demonstration**, not a replacement for `dot`, a sandbox,
or a production migration. macOS/Linux file mutations are supported on local
filesystems; other platforms fail closed. Only use the reviewed hello binary.
See [ADRs 013–018](../docs/adr/README.md) for the boundaries and unfinished work.

```sh
cd core
go test -race ./...
demo_parent=$(mktemp -d)
go build -o "$demo_parent/dot-core" ./cmd/dot-core
go build -o "$demo_parent/dot-hello" ./cmd/dot-hello
"$demo_parent/dot-core" init --root "$demo_parent/managed"
"$demo_parent/dot-core" register --root "$demo_parent/managed" --plugin "$demo_parent/dot-hello"
"$demo_parent/dot-core" apply --root "$demo_parent/managed" --allow-audit-plugin
"$demo_parent/dot-core" status --root "$demo_parent/managed"  # COMMITTED
"$demo_parent/dot-core" rollback --root "$demo_parent/managed"
"$demo_parent/dot-core" status --root "$demo_parent/managed"  # ROLLED_BACK
demo_plan=$("$demo_parent/dot-core" plan-id --root "$demo_parent/managed")
"$demo_parent/dot-core" archive --root "$demo_parent/managed" --plan-id "$demo_plan"
"$demo_parent/dot-core" status --root "$demo_parent/managed"  # IDLE
"$demo_parent/dot-core" apply --root "$demo_parent/managed" --allow-audit-plugin
```

Keep the demonstration directory to inspect `.dot-txn/plan.json`, its WAL and
backups. Do not point this tool at HOME, a repository, or an existing config tree.
`init` refuses existing directories. Only core writes targets; the plugin writes
two files in `.dot-stage`, returns hashes and exits before commit. Recovery needs
no plugin and refuses to overwrite independently changed targets.

Only an explicit `archive --plan-id` retires a terminal transaction. Its plan,
WAL, artifacts, backups and stage are retained in `.dot-history/<plan-id>`;
target contents are not changed. A durable `.dot-archive` intent makes both
directory renames recoverable with `recover`. Interrupted archives report
`ARCHIVING` and block apply/rollback until recovery finishes. Before archiving,
core verifies terminal state, target preconditions and retained evidence. A
changed target blocks recovery rather than overwriting the user's edit.

History is capped at 32 generations (not a whole-directory byte quota); reaching
the cap fails without deleting evidence. There is no automatic pruning, archived
generation rollback, or pre-PREPARED abandoned-stage cleanup. Rollback applies
only to the active generation; archive it only when this is the intended choice.

Unix plugins run in a separate process group; core kills remaining same-group
children before committing, on protocol failure and on timeout. A child can
deliberately escape that group. This is process cleanup, **not OS containment**.
The Darwin kernel inspection dependency is pinned in `go.mod`/`go.sum`.

Flags are command-specific: only `register` accepts `--plugin`, only `apply`
accepts `--allow-audit-plugin`, and only `archive` accepts `--plan-id`. Unknown
commands, irrelevant flags, missing registration/archive arguments and absent
audit consent are rejected before opening the root. Direct CLI tests cover these
negative paths and two complete apply/archive generations.

Registration and initialization also bind the exact restricted profile, audit
assurance and capability set. A plugin cannot silently downgrade containment or
drop/reorder capabilities after the user grants audit consent. This negotiation
does not upgrade the audit-only process boundary into a sandbox.

Garbage collection, production registry signatures, OS containment, full JCS,
effect drivers, Windows ACL/replace semantics, secret brokering and read-only MCP
isolation remain separate gates. The tests simulate process crashes and I/O errors;
they do not certify physical power-loss durability or resistance to a malicious
same-UID plugin. No release version is bumped by this experimental module.
