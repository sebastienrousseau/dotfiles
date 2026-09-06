// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! Drive the command-line entry point in-process with an injected clock and
//! in-memory streams — the same call the `dot-sys` binary makes with the
//! real ones.
//!
//! ```sh
//! cargo run --example cli
//! ```

use std::io;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use dot_sys::cli::{run, EXIT_FAILURE, EXIT_SUCCESS};

fn main() {
    // Exactly what the binary does, but into a buffer we can inspect.
    let mut out = Vec::new();
    let code = run(
        &mut out,
        &mut io::sink(),
        UNIX_EPOCH + Duration::from_secs(1_700_000_000),
    );
    assert_eq!(code, EXIT_SUCCESS);
    print!(
        "buffered stdout: {}",
        String::from_utf8(out).expect("utf-8")
    );

    // A clock before 1970 is the failure path: diagnostic on stderr, exit 1.
    let mut err = Vec::new();
    let code = run(
        &mut io::sink(),
        &mut err,
        UNIX_EPOCH - Duration::from_secs(1),
    );
    assert_eq!(code, EXIT_FAILURE);
    print!(
        "buffered stderr: {}",
        String::from_utf8(err).expect("utf-8")
    );

    // And the real thing, straight to this process's stdout.
    let code = run(
        &mut io::stdout().lock(),
        &mut io::stderr().lock(),
        SystemTime::now(),
    );
    println!("exit code: {code}");
}
