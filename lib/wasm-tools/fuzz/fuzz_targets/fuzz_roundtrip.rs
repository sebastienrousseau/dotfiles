// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! Structure-aware target: builds a `Status` from `Arbitrary` field values
//! (any strings, any `u64`) and proves `parse(to_json(s)) == s`, that
//! `Display` and `FromStr` agree with the inherent methods, and that the
//! emitted JSON is a single line with every control character escaped.

#![no_main]

use arbitrary::Arbitrary;
use dot_sys::Status;
use libfuzzer_sys::fuzz_target;

#[derive(Arbitrary, Debug)]
struct Input {
    status: String,
    timestamp: u64,
    engine: String,
}

fuzz_target!(|input: Input| {
    let status = Status::new(input.status, input.timestamp, input.engine);
    let json = status.to_json();
    assert_eq!(status.to_string(), json);
    assert!(
        json.bytes().all(|b| b >= 0x20),
        "raw control byte in {json:?}"
    );
    assert_eq!(Status::parse(&json).as_ref(), Ok(&status));
    assert_eq!(json.parse::<Status>(), Ok(status));
});
