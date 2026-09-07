<!--
SPDX-License-Identifier: Apache-2.0 OR MIT
Copyright (c) 2015-2026 Sebastien Rousseau
-->

# dot-sys

The health-probe record emitted by the dotfiles framework's Rust helper.
The binary prints exactly one line:

```text
{"status": "ok", "timestamp": 1700000000, "engine": "wasm"}
```

The library behind it (`dot_sys`) models that record as a plain
[`Status`] struct with a byte-exact emitter (`to_json` / `Display`) and a
strict parser (`parse` / `FromStr`) that round-trips every value the
emitter can produce and reports the byte offset of anything it rejects.
The crate is `std`-only: three fixed fields do not justify a `serde`
dependency, and the hand-written code is fully unit-tested, fuzzed,
benchmarked and Miri-checked (see below).

[`Status`]: src/lib.rs

## Install

```bash
# From the repository checkout
cargo install --path lib/wasm-tools --locked

# Or build in place
cd lib/wasm-tools && cargo build --release
./target/release/dot-sys
```

Minimum supported Rust version: **1.86** (`rust-version` in
`Cargo.toml`, tested in CI with that exact toolchain).

## Usage

### Binary

```bash
$ dot-sys
{"status": "ok", "timestamp": 1700000000, "engine": "wasm"}
$ echo $?
0
```

Arguments and stdin are ignored. The only failure mode is a system clock
set before 1970, which prints `dot-sys: system clock is before the Unix
epoch` to stderr and exits `1`.

### Library

```rust
use dot_sys::{Error, Status};

fn main() -> Result<(), Error> {
    let probe = Status::now()?;
    println!("{probe}");

    let json = Status::at(1_700_000_000).to_json();
    assert_eq!(Status::parse(&json)?, Status::at(1_700_000_000));

    // Strict grammar: offsets point at the problem.
    let err = Status::parse(r#"{"status": "ok", "timestamp": 007, "engine": "wasm"}"#).unwrap_err();
    assert_eq!(err.to_string(), "expected no digit after a leading zero at byte 31");
    Ok(())
}
```

Three runnable examples live in `examples/`:

```bash
cargo run --example probe   # every constructor + to_json / Display
cargo run --example parse   # parse / FromStr and every error variant
cargo run --example cli     # cli::run with an injected clock and buffers
```

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
```

Coverage is measured with [`cargo-llvm-cov`] over the library, the
binary (`main.rs` is a one-expression wrapper over `cli::run`, so it is
covered by the `assert_cmd` integration tests) and the in-module tests.
The current figure is 100% lines / regions / functions; the gate is 98%.

[`cargo-llvm-cov`]: https://github.com/taiki-e/cargo-llvm-cov

### Fuzzing

Four `cargo-fuzz` targets ship under `fuzz/fuzz_targets/`. Between them
every public function that takes input is reached, and each target checks
an invariant rather than only surviving:

| Target           | Drives                                             | Checks                                                                 |
| :--------------- | :------------------------------------------------- | :--------------------------------------------------------------------- |
| `fuzz_parse`     | `Status::parse`, `FromStr`, `to_json`, `Display`, `Error::Display` | accepted input round-trips unchanged; every error offset is inside the input on a char boundary |
| `fuzz_roundtrip` | `Status::new`, `to_json`, `Display`, `parse`, `FromStr` (structure-aware via `Arbitrary`) | `parse(to_json(s)) == s` for any strings and any `u64`; output is one line with all control bytes escaped |
| `fuzz_at`        | `Status::at`, `Status::from_system_time`, `to_json`, `parse` | `at(n)` and `from_system_time(EPOCH + n)` agree and round-trip for every `u64` |
| `fuzz_cli`       | `cli::run` (and through it `from_system_time`, `Display`) | exit code, which stream got output, and that stdout parses back to `Status::at(secs)` |

Every push replays the seed corpus (`fuzz/corpus/<target>/`) plus the
minimised reproducers of previously-fixed findings
(`fuzz/regressions/<target>/`) with `-runs=0`, then fuzzes each target
for 60 seconds. A fixed crash therefore cannot silently return.

If `cargo-fuzz` came from a prebuilt release binary rather than
`cargo install` (for example via `taiki-e/install-action`), pass
`--target "$(rustc -vV | awk '/^host:/ { print $2 }')"` to every
invocation. It otherwise defaults to the triple it was itself built for,
which on Linux is a static musl build that AddressSanitizer cannot use.

```bash
cargo +nightly fuzz build
cargo +nightly fuzz run fuzz_parse     fuzz/corpus/fuzz_parse     fuzz/regressions/fuzz_parse
cargo +nightly fuzz run fuzz_roundtrip fuzz/corpus/fuzz_roundtrip fuzz/regressions/fuzz_roundtrip
cargo +nightly fuzz run fuzz_at        fuzz/corpus/fuzz_at        fuzz/regressions/fuzz_at
cargo +nightly fuzz run fuzz_cli       fuzz/corpus/fuzz_cli       fuzz/regressions/fuzz_cli

# Replay only (what CI does first)
cargo +nightly fuzz run fuzz_parse fuzz/corpus/fuzz_parse fuzz/regressions/fuzz_parse -- -runs=0
```

See `fuzz/regressions/README.md` for how to file a new reproducer. The
directories start out holding only a `.gitkeep` (which libFuzzer skips, so
a replay of an empty regression set is a no-op).

### Miri (UB / aliasing / leak verification)

The crate is `#![forbid(unsafe_code)]`, so Miri does not police
`dot_sys`'s own code — every byte is checked at compile time. The Miri
job exists to verify the interaction with `std` (string building, the
`SystemTime` arithmetic, `Write` into buffers) is sound and to keep the
door shut should `unsafe` ever appear.

```bash
cargo +nightly miri test
```

`Status::now()` reads the wall clock, which Miri's default isolation
forbids; `.cargo/config.toml` sets `MIRIFLAGS=-Zmiri-disable-isolation`
so the plain command above passes from a clean checkout. The
process-spawning integration tests in `tests/binary.rs` are
`#![cfg(not(miri))]`; the same logic is exercised in-process through
`cli::run`.

### CI

`.github/workflows/rust.yml` runs on every push and pull request that
touches `lib/wasm-tools/**` or the workflow itself. Every action is
pinned to a full commit SHA (`docs/security/CI_PINNING.md`).

| Job        | Toolchain(s)                    | Purpose                                                                 |
| :--------- | :------------------------------ | :---------------------------------------------------------------------- |
| `test`     | stable, 1.86.0, beta × ubuntu, macos | `cargo test --locked`, release build + output-format smoke          |
| `fmt`      | stable                          | `cargo fmt --check` on the crate and the fuzz crate                     |
| `clippy`   | stable                          | `-D warnings -W clippy::pedantic`, all targets                          |
| `doc`      | stable                          | `cargo doc --no-deps` with `RUSTDOCFLAGS=-D warnings`, doctests         |
| `coverage` | stable + llvm-tools             | `cargo llvm-cov`, fails under 98% lines / regions / functions           |
| `miri`     | nightly + miri                  | `cargo miri test`                                                       |
| `fuzz`     | nightly + cargo-fuzz (×4)       | corpus + regression replay (`-runs=0`), then 60s smoke per target       |
| `bench`    | stable                          | `cargo bench --no-run`, `cargo bench -- --quick`                        |
| `examples` | stable                          | runs every file in `examples/`                                          |
| `deny`     | —                               | `cargo deny check` (advisories, licences, bans, sources)                |
| `audit`    | stable + cargo-audit            | `cargo audit --deny warnings`                                           |

## License

Apache-2.0 OR MIT, like the rest of the repository.
