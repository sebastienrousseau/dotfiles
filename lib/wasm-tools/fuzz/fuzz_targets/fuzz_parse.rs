// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! Feeds arbitrary bytes to `Status::parse` and checks the two invariants
//! the strict grammar promises: anything accepted round-trips through
//! `to_json` / `Display` / `FromStr` unchanged, and every rejection carries a
//! byte offset that lies inside the input on a character boundary.

#![no_main]

use dot_sys::{Error, Status};
use libfuzzer_sys::fuzz_target;

fn offset_of(err: Error) -> Option<usize> {
    match err {
        Error::Unexpected { offset, .. }
        | Error::NumberOverflow { offset }
        | Error::InvalidEscape { offset }
        | Error::InvalidUnicodeEscape { offset }
        | Error::TrailingInput { offset } => Some(offset),
        _ => None,
    }
}

fuzz_target!(|data: &[u8]| {
    let Ok(input) = std::str::from_utf8(data) else {
        return;
    };
    match Status::parse(input) {
        Ok(status) => {
            let json = status.to_json();
            assert_eq!(status.to_string(), json);
            assert_eq!(Status::parse(&json).as_ref(), Ok(&status));
            assert_eq!(json.parse::<Status>().as_ref(), Ok(&status));
            assert_eq!(input.parse::<Status>().as_ref(), Ok(&status));
        }
        Err(err) => {
            assert!(!err.to_string().is_empty());
            assert_eq!(input.parse::<Status>(), Err(err));
            if let Some(offset) = offset_of(err) {
                assert!(offset < input.len(), "{err:?} beyond {input:?}");
                assert!(
                    input.is_char_boundary(offset),
                    "{err:?} mid-char in {input:?}"
                );
            }
        }
    }
});
