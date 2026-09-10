// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! Build health-probe records every way the library allows and print them.
//!
//! ```sh
//! cargo run --example probe
//! ```

use std::time::{Duration, UNIX_EPOCH};

use dot_sys::{Error, Status, ENGINE, ENGINE_NATIVE, ENGINE_WASM, STATUS_OK};

fn main() -> Result<(), Error> {
    // The wall clock, exactly what the `dot-sys` binary prints.
    let live = Status::now()?;
    println!("now:              {live}");

    // A fixed instant, handy for reproducible fixtures.
    let fixed = Status::at(1_700_000_000);
    println!("at(1700000000):   {}", fixed.to_json());

    // Any `SystemTime`; sub-second precision is truncated.
    let from_time = Status::from_system_time(UNIX_EPOCH + Duration::from_millis(2_500))?;
    println!("from_system_time: {from_time}");
    assert_eq!(from_time, Status::at(2));

    // Fully custom values; strings are JSON-escaped on output.
    let custom = Status::new("degraded \"maybe\"", 3, "native\n");
    println!("new(..):          {custom}");

    // The constants the healthy record is built from. `ENGINE` is the one
    // records carry, and it states where this build is actually running.
    println!("constants:        status={STATUS_OK} engine={ENGINE}");
    println!("engine names:     wasm={ENGINE_WASM} native={ENGINE_NATIVE}");
    assert_eq!(fixed.engine, ENGINE);

    // Pre-epoch clocks are the one way construction can fail.
    let err = Status::from_system_time(UNIX_EPOCH - Duration::from_secs(1)).unwrap_err();
    println!("before epoch:     {err}");
    Ok(())
}
