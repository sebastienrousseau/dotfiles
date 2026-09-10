// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! Drives the general JSON reader with arbitrary text and checks its two
//! invariants: a document it accepts can be read back, and every error it
//! reports points inside the input at a character boundary.
//!
//! This is the target that matters most for the WebAssembly build: the
//! module reads evidence it did not produce, so `json` is the only code in
//! the crate exposed to input an attacker chooses.

#![no_main]

use dot_sys::{json, Error};
use libfuzzer_sys::fuzz_target;

/// Paths the verifier actually looks up, plus shapes meant to trip it.
const PATHS: [&str; 6] = [
    "",
    "generated_at",
    "git_signing.merge_verify_signatures",
    "mcp.doctor.status",
    "a.b.c.d.e.f.g",
    "platform.hostname",
];

fn offset_of(error: Error) -> Option<usize> {
    match error {
        Error::Unexpected { offset, .. }
        | Error::NumberOverflow { offset }
        | Error::InvalidEscape { offset }
        | Error::InvalidUnicodeEscape { offset }
        | Error::TrailingInput { offset }
        | Error::TooDeep { offset } => Some(offset),
        _ => None,
    }
}

fuzz_target!(|input: &str| {
    let valid = json::validate(input);
    if let Err(e) = valid {
        if let Some(offset) = offset_of(e) {
            assert!(offset <= input.len(), "offset {offset} past the end");
            assert!(
                input.is_char_boundary(offset),
                "offset {offset} splits a character"
            );
        }
    }

    for path in PATHS {
        match json::get(input, path) {
            Ok(value) => {
                // Whatever `get` hands back is a value the reader accepts
                // on its own, and its span really is inside the input.
                let text = value.text();
                assert!(value.offset() + text.len() <= input.len());
                assert_eq!(&input[value.offset()..value.offset() + text.len()], text);
                json::validate(text).expect("a returned value is valid on its own");
                assert_eq!(value.kind(), json::get(text, "").unwrap().kind());

                // The typed readers never panic, whatever the kind.
                let _ = value.as_str();
                let _ = value.as_u64();
                let _ = value.as_bool();
                let _ = value.is_null();
            }
            Err(e) => {
                if let Some(offset) = offset_of(e) {
                    assert!(offset <= input.len());
                    assert!(input.is_char_boundary(offset));
                }
            }
        }
    }

    // A whole valid document is reachable through the empty path.
    if valid.is_ok() {
        let root = json::get(input, "").expect("a valid document has a root");
        assert_eq!(root.text().trim(), input.trim());
    }
});
