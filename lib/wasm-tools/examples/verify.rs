// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! Verify a `dot attest` evidence record the way the WebAssembly module
//! does, in-process and against a fixed clock.
//!
//! ```sh
//! cargo run --example verify
//! ```
//!
//! To run the same policy over your own machine's evidence, build the
//! module and hand it the real thing:
//!
//! ```sh
//! cargo build --release --target wasm32-wasip1
//! dot attest --json | wasmtime run target/wasm32-wasip1/release/dot-sys.wasm verify
//! ```

use dot_sys::attest::{Outcome, Report, MAX_AGE_DEFAULT};
use dot_sys::{json, Error, ENGINE};

/// A record that satisfies every check, as `dot attest --json` would emit.
const COMPLIANT: &str = include_str!("../tests/data/compliant.json");

/// The same machine with signing switched off and MCP unhealthy.
const NON_COMPLIANT: &str = include_str!("../tests/data/non-compliant.json");

/// Unix time of the `generated_at` both records carry.
const STAMPED: u64 = 1_788_955_200;

fn main() -> Result<(), Error> {
    println!("engine: {ENGINE}\n");

    let good = Report::verify(COMPLIANT, STAMPED + 60, MAX_AGE_DEFAULT)?;
    println!("compliant evidence\n{good}");
    assert!(good.passed());

    let bad = Report::verify(NON_COMPLIANT, STAMPED + 60, MAX_AGE_DEFAULT)?;
    println!("non-compliant evidence\n{bad}");
    assert_eq!(bad.failures(), 6);

    // Stale evidence fails on freshness alone.
    let stale = Report::verify(COMPLIANT, STAMPED + MAX_AGE_DEFAULT + 1, MAX_AGE_DEFAULT)?;
    let freshness = &stale.checks[0];
    assert_eq!(freshness.outcome, Outcome::Fail);
    println!("stale evidence:   {}", freshness.detail);

    // The machine-readable form is what a fleet aggregator would store.
    let verdict = bad.to_json();
    json::validate(&verdict)?;
    println!(
        "verdict summary:  {}",
        json::get(&verdict, "summary")?.text()
    );

    // Input that is not JSON at all is an error, never a verdict.
    let err = Report::verify("definitely not json", 0, MAX_AGE_DEFAULT).unwrap_err();
    println!("bad input:        {err}");
    Ok(())
}
