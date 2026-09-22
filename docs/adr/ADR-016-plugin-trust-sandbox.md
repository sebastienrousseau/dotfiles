# ADR-016: Explicit plugin trust and honest containment levels

Status: Accepted; audit and experimental Linux process profiles implemented.

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

Linux can instead register assurance `process` and invoke with
`--require-process-sandbox`. Core resolves a fixed sibling `dot-sandbox` runner,
which requires Landlock ABI 3, `no_new_privs`, a seccomp architecture check and
deny policy, a parent-death signal, and hard address-space, CPU, output-file and
descriptor limits. Landlock permits the plugin to read and execute only its exact
binary and to operate only inside its private stage; execute permission is absent
from the stage. The runner therefore requires a statically linked ELF executable
and rejects interpreter-backed or malformed binaries before installing Landlock;
this keeps dynamic loaders and shared libraries outside the granted boundary.
Seccomp denies network creation and I/O, namespace and process-group
escape, new processes, tracing, external signalling, mount and selected kernel
attack surfaces while preserving Go runtime threads. It also denies external
metadata mutation, anonymous executable creation and changing the parent-death
contract. Unsupported kernels,
architectures, macOS and Windows fail closed rather than reporting process assurance.

No ambient credentials, HOME, PATH or provider configuration are inherited. Shell
evaluation is absent. Stderr is bounded and discarded rather than persisted as
potentially sensitive text. The audit profile still lacks platform containment,
resource limits and descendant containment and cannot accept untrusted plugins.

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
missing exact assurance consent must fail before spawning. Tests include stdout
noise, nonzero exits and Linux probes for denied filesystem, network, namespace,
process-group and executable access. The process profile remains an experimental
hello proof, not permission to run arbitrary untrusted code: the seccomp policy is
deny-targeted rather than a syscall allowlist; Landlock has documented mediation
limits; same-UID replacement races and tamper-resistant runner installation remain;
and macOS/Windows need their native implementations. Production trust-root
rotation, signature verification and read-only system registry precedence are
separate follow-ups.
This reconciles ADR-003 without falsely promoting declarations to enforcement.
