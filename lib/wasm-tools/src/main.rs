// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! `dot-sys` binary: prints one health-probe record to stdout.
//!
//! All logic lives in [`dot_sys::cli::run`] so it can be unit tested with
//! an injected clock and writers; this file only wires the real ones in.

use std::io;
use std::process::ExitCode;
use std::time::SystemTime;

fn main() -> ExitCode {
    ExitCode::from(dot_sys::cli::run(
        &mut io::stdout().lock(),
        &mut io::stderr().lock(),
        SystemTime::now(),
    ))
}
