# Experimental DOT core / hello vertical slice

This is an **audit-only demonstration**, not a replacement for `dot`, a sandbox,
or a production migration. macOS/Linux file mutations are supported on local
filesystems; other platforms fail closed. Only use the reviewed hello binary.
See [ADRs 013–018](../docs/adr/README.md) for the boundaries and unfinished work.

```sh
cd core
go test -race ./...
go build -o /tmp/dot-core ./cmd/dot-core
go build -o /tmp/dot-hello ./cmd/dot-hello
demo_parent=$(mktemp -d)
/tmp/dot-core init --root "$demo_parent/managed"
/tmp/dot-core register --root "$demo_parent/managed" --plugin /tmp/dot-hello
/tmp/dot-core apply --root "$demo_parent/managed" --allow-audit-plugin
/tmp/dot-core status --root "$demo_parent/managed"  # COMMITTED
/tmp/dot-core rollback --root "$demo_parent/managed"
/tmp/dot-core status --root "$demo_parent/managed"  # ROLLED_BACK
```

Keep the demonstration directory to inspect `.dot-txn/plan.json`, its WAL and
backups. Do not point this tool at HOME, a repository, or an existing config tree.
`init` refuses existing directories. Only core writes targets; the plugin writes
two files in `.dot-stage`, returns hashes and exits before commit. Recovery needs
no plugin and refuses to overwrite independently changed targets.

The retained transaction deliberately prevents a second apply. Generations,
garbage collection, production registry signatures, OS containment, full JCS,
effect drivers, Windows ACL/replace semantics, secret brokering and read-only MCP
isolation remain separate gates. The tests simulate process crashes and I/O errors;
they do not certify physical power-loss durability or resistance to a malicious
same-UID plugin. No release version is bumped by this experimental module.
