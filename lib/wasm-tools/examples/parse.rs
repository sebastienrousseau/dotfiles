// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! Parse records back with `Status::parse` / `FromStr` and show every error
//! the strict grammar can report, with its byte offset.
//!
//! ```sh
//! cargo run --example parse
//! ```

use dot_sys::{Error, Status};

fn main() -> Result<(), Error> {
    let json = r#"{"status": "ok", "timestamp": 1700000000, "engine": "wasm"}"#;
    let parsed = Status::parse(json)?;
    println!("parse:     {parsed:?}");

    let via_from_str: Status = json.parse()?;
    println!("FromStr:   {via_from_str:?}");
    assert_eq!(parsed, via_from_str);

    // Whitespace between tokens and JSON escapes are accepted...
    let fancy =
        " { \"status\" : \"o\\u006b\" , \"timestamp\" : 1 , \"engine\" : \"\\ud83e\\udd80\" } ";
    println!("escapes:   {}", Status::parse(fancy)?);

    // ...and everything the round trip cannot represent is rejected with a
    // byte offset pointing at the problem.
    let bad_inputs: [&str; 7] = [
        "",
        r#"["status"]"#,
        r#"{"status": "ok", "timestamp": 007, "engine": "wasm"}"#,
        r#"{"status": "ok", "timestamp": 99999999999999999999, "engine": "wasm"}"#,
        r#"{"status": "\q", "timestamp": 1, "engine": "wasm"}"#,
        r#"{"status": "\udc00", "timestamp": 1, "engine": "wasm"}"#,
        r#"{"status": "ok", "timestamp": 1, "engine": "wasm"} trailing"#,
    ];
    for input in bad_inputs {
        match Status::parse(input) {
            Ok(status) => println!("unexpectedly ok: {status}"),
            Err(err) => println!("rejected:  {input:<60} -> {err}"),
        }
    }
    Ok(())
}
