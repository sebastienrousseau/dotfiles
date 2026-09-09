<!--
SPDX-License-Identifier: Apache-2.0 OR MIT
Copyright (c) 2015-2026 Sebastien Rousseau
-->

# dot-sys

The WebAssembly verifier for `dot attest` evidence, and the health-probe
record it summarises its verdict as.

```bash
$ dot attest --verify
pass  generated_at                         2026-09-09T22:30:41Z (0s old)
pass  dotfiles_version                     0.2.519
...
pass  git_signing.merge_verify_signatures  true
all 11 checks passed on wasm
```

## Why this is WebAssembly and not a shell function

`scripts/diagnostics/workstation-attestation.sh` emits a JSON record
describing a machine: version, platform, git signing configuration, agent
profile and MCP posture. That record is produced **by the machine under
review**. A reviewer who checks it with a `jq` incantation running on that
same machine is trusting tools the machine controls.

The verifier is therefore a `wasm32-wasip1` module. It gets stdin, stdout
and a clock, and nothing else: no filesystem, no network, no environment,
no subprocesses. It parses the document itself — that is what
`src/json.rs` is for — so no host tool sits between the evidence and the
verdict. The same bytes produce the same verdict on Linux, macOS or
Windows, from any WebAssembly runtime.

`wasmtime` is already pinned in `mise.toml`, installed by `flake.nix` and
`Brewfile.cli`, and checked by `dot doctor`, so the runtime is not a new
dependency.

### Why `wasm32-wasip1` and not `wasm32-unknown-unknown`

The module needs three things from its host: the evidence on **stdin**,
the verdict on **stdout**, and a **wall clock** to judge how old the
evidence is.

- `wasm32-unknown-unknown` has no stdio at all and no clock —
  `SystemTime::now()` panics there. Using it would mean a JS or host-glue
  shim, `#[cfg]` forks through the crate, and a second code path only one
  build exercises.
- `wasm32-wasip1` gives all three through plain `std`: `fd_read`,
  `fd_write` and `clock_time_get`. The result is that `src/main.rs` is the
  *same source* for the host binary and the module, with no `cfg` fork, and
  it is a core module every runtime loads (`wasmtime`, `wasmer`, `wasm3`,
  Node's WASI) rather than a component.

So the clock is not papered over: under WASI it is a real
`clock_time_get`, and `tests/wasm.rs` proves it by checking that two host
timestamps taken around a module run bracket the one the module reported.
For reproducible verdicts the clock can also be supplied explicitly with
`--now`, which is what CI and the fixtures do.

### The `engine` field is evidence, not a label

`ENGINE` is `cfg`-selected: `"wasm"` on any `wasm32` target, `"native"`
otherwise. The historic record's `"engine": "wasm"` was a hardcoded string
in a host binary; it now states where the bytes were actually computed.
Run the module and the verdict says `wasm`; run the identical source as a
host binary and it says `native`. `tests/wasm.rs` asserts that the two
verdicts differ in exactly that one substring.

## The native binary

Still built, still useful, and no longer lying about what it is:

```bash
$ dot-sys                       # the health probe, engine "native"
{"status": "ok", "timestamp": 1788990045, "engine": "native"}
$ dot-sys verify < evidence.json
$ dot-sys --help
```

It is what `cargo test`, the benchmarks and the fuzz targets drive, and it
is the reference the WebAssembly build is compared against.

## Install

```bash
# The WebAssembly module (what `dot attest --verify` runs)
rustup target add wasm32-wasip1
cargo build --release --target wasm32-wasip1 --manifest-path lib/wasm-tools/Cargo.toml
wasmtime run lib/wasm-tools/target/wasm32-wasip1/release/dot-sys.wasm

# The host binary
cargo install --path lib/wasm-tools --locked
```

Minimum supported Rust version: **1.86** (`rust-version` in `Cargo.toml`,
tested in CI with that exact toolchain).

## Usage

### Verifying evidence

```bash
dot attest --verify                 # attest this machine, then verify it
dot attest --verify --json          # machine-readable verdict
dot attest --max-age 3600           # tighter freshness window
dot attest --json > evidence.json   # verify a record collected elsewhere
bash scripts/diagnostics/attest-verify.sh evidence.json
```

Exit codes: `0` every check passed, `1` at least one failed, `2` the
arguments or the document were unusable.

The policy lives in `src/attest.rs` as three tables plus a freshness rule,
so what is checked is readable in one screen:

| Check | Rule |
| :--- | :--- |
| `generated_at` | RFC 3339 UTC, not in the future, not older than `--max-age` (default 7 days) |
| `dotfiles_version`, `platform.runtime`, `platform.host_os`, `platform.hostname`, `git_signing.signing_key`, `git_signing.allowed_signers_file` | present, a string, non-empty |
| `git_signing.format` | one of `ssh`, `openpgp`, `x509` |
| `agent.current_profile` | one of `ask`, `plan`, `apply`, `audit` |
| `mcp.doctor.status` | `healthy` (the only compliant value `mcp-doctor.sh` emits) |
| `git_signing.merge_verify_signatures` | boolean `true` |

A missing, ill-typed or out-of-policy member is a **failed check** with a
byte offset, not an error. An error is reserved for input that is not
well-formed JSON, because then no check could be trusted.

### Library

```rust
use dot_sys::attest::{Report, MAX_AGE_DEFAULT};
use dot_sys::{json, Status, ENGINE};

fn main() -> Result<(), dot_sys::Error> {
    let evidence = std::fs::read_to_string("evidence.json").unwrap();
    let report = Report::verify(&evidence, 1_788_955_200, MAX_AGE_DEFAULT)?;
    println!("{report}");
    assert_eq!(report.summary().engine, ENGINE);

    // The general JSON reader is public; it never builds a tree.
    assert_eq!(json::get(&evidence, "git_signing.format")?.as_str()?, "ssh");

    // The probe record is unchanged, byte for byte.
    let probe = Status::at(1_700_000_000);
    assert_eq!(Status::parse(&probe.to_json())?, probe);
    Ok(())
}
```

Four runnable examples live in `examples/`:

```bash
cargo run --example verify  # the attestation policy over both fixtures
cargo run --example probe   # every constructor + to_json / Display
cargo run --example parse   # parse / FromStr and every error variant
cargo run --example cli     # cli::run with an injected clock and buffers
```

## Modules

| Module | Purpose |
| :--- | :--- |
| `dot_sys` (root) | `Status`, the three-field health record, with a byte-exact emitter and a strict parser |
| `dot_sys::json` | a general JSON reader: `validate` and a dotted-path `get`, no tree, no recursion, depth capped at 64 |
| `dot_sys::time` | `YYYY-MM-DDTHH:MM:SSZ` → Unix seconds, the one format `date -u` emits into the record |
| `dot_sys::attest` | the policy: `Report::verify` and the `Check`/`Outcome` it is made of |
| `dot_sys::cli` | argument dispatch and both output formats, with the clock and streams injected |

The crate has **no runtime dependencies**. A hand-written JSON reader for
one shape of document is smaller than `serde_json`, compiles faster, and
adds nothing to the supply chain of a binary whose entire job is to be
trusted by a third party.

## Development

All commands run from `lib/wasm-tools/`. Every one of them is a CI gate
(`.github/workflows/rust.yml`).

```bash
cargo fmt --all --check
cargo clippy --all-targets --all-features -- -D warnings -W clippy::pedantic
cargo test --locked                                   # unit + integration + doc
RUSTDOCFLAGS="-D warnings" cargo doc --no-deps        # rustdoc, missing_docs denied
cargo llvm-cov --all-features --locked \
  --fail-under-lines 98 --fail-under-regions 98 --fail-under-functions 98
cargo bench --no-run && cargo bench -- --quick        # criterion, every public fn
for e in examples/*.rs; do cargo run --example "$(basename "$e" .rs)"; done
cargo deny check                                      # licences, advisories, bans, sources
cargo audit
cargo +1.86.0 test --locked                           # MSRV

# WebAssembly
rustup target add wasm32-wasip1
cargo clippy --target wasm32-wasip1 --bins --lib -- -D warnings -W clippy::pedantic
cargo build --release --target wasm32-wasip1 --bin dot-sys
DOT_SYS_WASM=target/wasm32-wasip1/release/dot-sys.wasm \
  DOT_SYS_WASM_REQUIRED=1 cargo test --test wasm
```

Coverage is measured with [`cargo-llvm-cov`] over the library, the binary
(`main.rs` is a one-expression wrapper over `cli::main`, so it is covered
by the `assert_cmd` integration tests) and the in-module tests. The
current figure is 100% lines / regions / functions; the gate is 98%.

[`cargo-llvm-cov`]: https://github.com/taiki-e/cargo-llvm-cov

### Running as WebAssembly

`tests/wasm.rs` does not inspect the artefact — it executes it. Building a
`.wasm` nothing runs is the exact failure this crate spent a release
committing, so the tests spawn `wasmtime`, feed the module fixtures on
stdin, and assert on what comes back, including that the host binary and
the module produce verdicts identical apart from the engine name.

`DOT_SYS_WASM` points the tests at a module, `WASMTIME` at a runtime. With
neither available the tests print why and stop — unless
`DOT_SYS_WASM_REQUIRED=1`, which the `wasm` CI job sets, so a missing
module or runtime is a hard failure there and a developer without the
target installed is not blocked.

### Fuzzing

Six `cargo-fuzz` targets ship under `fuzz/fuzz_targets/`. Between them
every public function that takes input is reached, and each target checks
an invariant rather than only surviving:

| Target           | Drives                                             | Checks                                                                 |
| :--------------- | :------------------------------------------------- | :--------------------------------------------------------------------- |
| `fuzz_parse`     | `Status::parse`, `FromStr`, `to_json`, `Display`, `Error::Display` | accepted input round-trips unchanged; every error offset is inside the input on a char boundary |
| `fuzz_roundtrip` | `Status::new`, `to_json`, `Display`, `parse`, `FromStr` (structure-aware via `Arbitrary`) | `parse(to_json(s)) == s` for any strings and any `u64`; output is one line with all control bytes escaped |
| `fuzz_at`        | `Status::at`, `Status::from_system_time`, `to_json`, `parse` | `at(n)` and `from_system_time(EPOCH + n)` agree and round-trip for every `u64` |
| `fuzz_cli`       | `cli::run` (and through it `from_system_time`, `Display`) | exit code, which stream got output, and that stdout parses back to `Status::at(secs)` |
| `fuzz_json`      | `json::validate`, `json::get`, every `Value` accessor | a value `get` returns is valid JSON on its own and really is a slice of the input; every error offset is inside the input on a char boundary |
| `fuzz_verify`    | `attest::Report::verify`, `to_json`, `Display`, `summary` | a verdict is only refused for non-JSON input; the summary agrees with the checks; both renderings round-trip |

`fuzz_json` and `fuzz_verify` matter most: they cover the code that reads
documents the module did not produce, which is the crate's whole attack
surface once it is handed evidence from another machine. `fuzz_verify`
lays its input out by hand — eight little-endian bytes of `now`, eight of
`max_age`, then the document — so a seed is readable.

Every push replays the seed corpus (`fuzz/corpus/<target>/`) plus the
minimised reproducers of previously-fixed findings
(`fuzz/regressions/<target>/`) with `-runs=0`, then fuzzes each target for
60 seconds. A fixed crash therefore cannot silently return.

If `cargo-fuzz` came from a prebuilt release binary rather than
`cargo install` (for example via `taiki-e/install-action`), pass
`--target "$(rustc -vV | awk '/^host:/ { print $2 }')"` to every
invocation. It otherwise defaults to the triple it was itself built for,
which on Linux is a static musl build that AddressSanitizer cannot use.

```bash
cargo +nightly fuzz build
cargo +nightly fuzz run fuzz_json   fuzz/corpus/fuzz_json   fuzz/regressions/fuzz_json
cargo +nightly fuzz run fuzz_verify fuzz/corpus/fuzz_verify fuzz/regressions/fuzz_verify

# Replay only (what CI does first)
cargo +nightly fuzz run fuzz_parse fuzz/corpus/fuzz_parse fuzz/regressions/fuzz_parse -- -runs=0
```

See `fuzz/regressions/README.md` for how to file a new reproducer. The
directories start out holding only a `.gitkeep` (which libFuzzer skips, so
a replay of an empty regression set is a no-op).

### Miri (UB / aliasing / leak verification)

The crate is `#![forbid(unsafe_code)]`, so Miri does not police
`dot_sys`'s own code — every byte is checked at compile time. The Miri job
exists to verify the interaction with `std` (string building, the
`SystemTime` arithmetic, `Write` into buffers) is sound and to keep the
door shut should `unsafe` ever appear.

```bash
cargo +nightly miri test
```

`Status::now()` reads the wall clock, which Miri's default isolation
forbids; `.cargo/config.toml` sets `MIRIFLAGS=-Zmiri-disable-isolation` so
the plain command above passes from a clean checkout. Note that the
verifier itself never reads the clock: `Report::verify` takes `now` as an
argument, and only `cli::main` supplies it, so all the policy code is
deterministic and isolation-clean. The process-spawning tests in
`tests/binary.rs` and `tests/wasm.rs` are `#![cfg(not(miri))]`; the same
logic is exercised in-process through `cli::main`.

### CI

`.github/workflows/rust.yml` runs on every push and pull request that
touches `lib/wasm-tools/**` or the workflow itself. Every action is pinned
to a full commit SHA (`docs/security/CI_PINNING.md`).

| Job        | Toolchain(s)                    | Purpose                                                                 |
| :--------- | :------------------------------ | :---------------------------------------------------------------------- |
| `test`     | stable, 1.86.0, beta × ubuntu, macos | `cargo test --locked`, release build + output-format smoke, fixture verification |
| `wasm`     | stable + `wasm32-wasip1` + wasmtime 47.0.3 | clippy for the target, build the module, **execute it**, run `tests/wasm.rs` and the shell caller, upload the `.wasm` |
| `fmt`      | stable                          | `cargo fmt --check` on the crate and the fuzz crate                     |
| `clippy`   | stable                          | `-D warnings -W clippy::pedantic`, all targets                          |
| `doc`      | stable                          | `cargo doc --no-deps` with `RUSTDOCFLAGS=-D warnings`, doctests         |
| `coverage` | stable + llvm-tools             | `cargo llvm-cov`, fails under 98% lines / regions / functions           |
| `miri`     | nightly + miri                  | `cargo miri test`                                                       |
| `fuzz`     | nightly + cargo-fuzz (×6)       | corpus + regression replay (`-runs=0`), then 60s smoke per target       |
| `bench`    | stable                          | `cargo bench --no-run`, `cargo bench -- --quick`                        |
| `examples` | stable                          | runs every file in `examples/`                                          |
| `deny`     | —                               | `cargo deny check` (advisories, licences, bans, sources)                |
| `audit`    | stable + cargo-audit            | `cargo audit --deny warnings`                                           |

## Why the directory is still called `wasm-tools`

The crate is `dot-sys` in a directory called `wasm-tools`, which read as a
misnomer while the crate built nothing but a host binary. Now that it is
genuinely a WebAssembly module the directory name is accurate, and the
crate name says what the *record* is about — the system this machine
reports on. Renaming either would break `.gitignore`, `REUSE.toml`,
`config/lychee.toml`, `config/pre-commit-config.yaml`, the `rust.yml` path
filters and every doc cross-reference, for no gain now that the name is
true. If the verifier ever ships to crates.io it should be renamed there,
where the name is user-facing.

## License

Apache-2.0 OR MIT, like the rest of the repository.
