// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! `dot-sys` executable: a health probe, and the verifier for the evidence
//! `dot attest` produces.
//!
//! The same file is the host binary and the `wasm32-wasip1` module. All
//! logic lives in [`dot_sys::cli::main`] so it can be unit tested with an
//! injected clock, reader and writers; this file only wires the real ones
//! in, which under WASI means the runtime's stdin, stdout and
//! `clock_time_get`.

use std::io;
use std::process::ExitCode;
use std::time::SystemTime;

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    ExitCode::from(dot_sys::cli::main(
        &args,
        &mut io::stdin().lock(),
        &mut io::stdout().lock(),
        &mut io::stderr().lock(),
        SystemTime::now(),
    ))
}
