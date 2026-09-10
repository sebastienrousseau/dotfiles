// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! Executes the `wasm32-wasip1` build of `dot-sys` in a real WebAssembly
//! runtime and asserts on what comes back.
//!
//! Building a `.wasm` nothing runs is the failure this crate exists to
//! stop repeating, so these tests do not inspect the artefact — they run
//! it. The engine field is the proof: the module is the same source as the
//! host binary, and it can only print `"engine": "wasm"` if the bytes were
//! executed by a WebAssembly runtime rather than by the host.
//!
//! Two things must be in place, and CI's `wasm` job guarantees both:
//!
//! ```sh
//! rustup target add wasm32-wasip1
//! cargo build --release --target wasm32-wasip1 --bin dot-sys
//! cargo test --test wasm
//! ```
//!
//! `DOT_SYS_WASM` overrides where the module is looked for and `WASMTIME`
//! overrides the runtime. When either is missing the tests report why and
//! stop — unless `DOT_SYS_WASM_REQUIRED=1` is set, which CI does, and then
//! a missing module or runtime is a failure. Process spawning is invisible
//! to Miri, so the file is skipped there like `binary.rs`.

#![cfg(not(miri))]

use std::path::PathBuf;
use std::process::{Command, Stdio};

use dot_sys::{Status, ENGINE_WASM};

/// An evidence record that satisfies every check at [`STAMPED`].
const GOOD: &str = include_str!("data/compliant.json");

/// The same machine failing six checks.
const BAD: &str = include_str!("data/non-compliant.json");

/// Unix time of the `generated_at` both fixtures carry.
const STAMPED: &str = "1788955200";

/// Where `cargo build --target wasm32-wasip1 --release` puts the module.
const DEFAULT_MODULE: &str = "target/wasm32-wasip1/release/dot-sys.wasm";

/// Everything needed to run the module, or the reason there is nothing to
/// run.
enum Runtime {
    Ready { wasmtime: String, module: PathBuf },
    Missing(String),
}

impl Runtime {
    fn find() -> Self {
        let module = std::env::var("DOT_SYS_WASM")
            .map_or_else(|_| PathBuf::from(DEFAULT_MODULE), PathBuf::from);
        if !module.is_file() {
            return Self::Missing(format!(
                "no WebAssembly module at {}; run `cargo build --release \
                 --target wasm32-wasip1 --bin dot-sys` first",
                module.display()
            ));
        }
        let wasmtime = std::env::var("WASMTIME").unwrap_or_else(|_| "wasmtime".to_string());
        match Command::new(&wasmtime).arg("--version").output() {
            Ok(out) if out.status.success() => Self::Ready { wasmtime, module },
            _ => Self::Missing(format!("no usable WebAssembly runtime at {wasmtime:?}")),
        }
    }
}

/// Result of one module run.
struct Run {
    code: i32,
    stdout: String,
    stderr: String,
}

/// Runs the module with `args` and `stdin`, or `None` when the toolchain is
/// absent and the environment has not demanded it be present.
fn run(args: &[&str], stdin: &str) -> Option<Run> {
    let (wasmtime, module) = match Runtime::find() {
        Runtime::Ready { wasmtime, module } => (wasmtime, module),
        Runtime::Missing(why) => {
            assert!(
                std::env::var("DOT_SYS_WASM_REQUIRED").is_err(),
                "DOT_SYS_WASM_REQUIRED is set but {why}"
            );
            eprintln!("skipping: {why}");
            return None;
        }
    };

    let mut command = Command::new(wasmtime);
    command.arg("run").arg(&module);
    for arg in args {
        command.arg(arg);
    }
    let mut child = command
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("wasmtime starts");
    {
        use std::io::Write as _;
        child
            .stdin
            .as_mut()
            .expect("piped stdin")
            .write_all(stdin.as_bytes())
            .expect("the module reads its input");
    }
    let out = child.wait_with_output().expect("wasmtime finishes");
    Some(Run {
        code: out.status.code().expect("an exit code, not a signal"),
        stdout: String::from_utf8(out.stdout).expect("utf-8 on stdout"),
        stderr: String::from_utf8(out.stderr).expect("utf-8 on stderr"),
    })
}

#[test]
fn the_module_reports_the_wasm_engine() {
    let Some(run) = run(&[], "") else { return };
    assert_eq!(run.code, 0, "stderr: {}", run.stderr);

    let line = run.stdout.strip_suffix('\n').expect("one trailing newline");
    let status = Status::parse(line).expect("stdout parses as a Status record");

    // This is the whole point: the same source that prints "native" when
    // built for the host prints "wasm" when a runtime executes it.
    assert_eq!(status.engine, ENGINE_WASM);
    assert_eq!(status.status, "ok");
    assert!(status.timestamp > 1_700_000_000, "{status}");
}

#[test]
fn the_module_reads_the_wasi_clock() {
    // `SystemTime::now()` is `clock_time_get` under WASI. Two runs a moment
    // apart must both land in the window the host measured around them,
    // which no constant could satisfy.
    let before = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .expect("host clock after the epoch")
        .as_secs();
    let Some(run) = run(&[], "") else { return };
    let after = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .expect("host clock after the epoch")
        .as_secs();

    let status = Status::parse(run.stdout.trim_end()).expect("a record");
    assert!(
        (before..=after).contains(&status.timestamp),
        "{before} <= {} <= {after}",
        status.timestamp
    );
}

#[test]
fn the_module_verifies_compliant_evidence_from_stdin() {
    let Some(run) = run(&["verify", "--now", STAMPED], GOOD) else {
        return;
    };
    assert_eq!(run.code, 0, "stderr: {}", run.stderr);
    assert!(run.stderr.is_empty(), "{}", run.stderr);
    assert!(
        run.stdout.starts_with("pass  generated_at"),
        "{}",
        run.stdout
    );
    assert!(
        run.stdout.ends_with("all 11 checks passed on wasm\n"),
        "{}",
        run.stdout
    );
}

#[test]
fn the_module_fails_non_compliant_evidence_with_a_verdict() {
    let Some(run) = run(&["verify", "--json", "--now", STAMPED], BAD) else {
        return;
    };
    assert_eq!(run.code, 1, "stderr: {}", run.stderr);
    assert!(run.stderr.is_empty(), "{}", run.stderr);

    let line = run.stdout.strip_suffix('\n').expect("one trailing newline");
    dot_sys::json::validate(line).expect("the module emits well-formed JSON");
    let summary = dot_sys::json::get(line, "summary").expect("summary present");
    assert_eq!(
        summary.text().parse::<Status>().expect("a Status record"),
        Status::new("failed", STAMPED.parse::<u64>().unwrap(), ENGINE_WASM)
    );

    // The verdict names every check that failed, computed inside the sandbox.
    for path in [
        "platform.hostname",
        "git_signing.signing_key",
        "git_signing.format",
        "agent.current_profile",
        "mcp.doctor.status",
        "git_signing.merge_verify_signatures",
    ] {
        assert!(
            line.contains(&format!(r#"{{"path": "{path}", "outcome": "fail""#)),
            "{path} missing from {line}"
        );
    }
}

#[test]
fn the_module_rejects_input_that_is_not_json() {
    let Some(run) = run(&["verify"], "definitely not json") else {
        return;
    };
    assert_eq!(run.code, 2);
    assert!(run.stdout.is_empty());
    assert_eq!(run.stderr, "dot-sys: expected a JSON value at byte 0\n");
}

#[test]
fn the_module_and_the_host_binary_agree_on_the_verdict() {
    let Some(wasm) = run(&["verify", "--json", "--now", STAMPED], BAD) else {
        return;
    };
    let native = assert_cmd::Command::cargo_bin("dot-sys")
        .expect("host binary")
        .args(["verify", "--json", "--now", STAMPED])
        .write_stdin(BAD)
        .assert()
        .code(1)
        .get_output()
        .stdout
        .clone();
    let native = String::from_utf8(native).expect("utf-8");

    // The verdicts differ in exactly one byte range — the engine name —
    // which is what makes the engine field evidence rather than decoration.
    assert_ne!(wasm.stdout, native);
    assert_eq!(
        wasm.stdout
            .replace("\"engine\": \"wasm\"", "\"engine\": \"native\""),
        native
    );
}
