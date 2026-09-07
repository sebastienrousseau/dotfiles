// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! Drives `cli::run` with an arbitrary clock (either side of the epoch, with
//! sub-second noise) and checks the exit code, the stream that received
//! output, and that a successful record parses back to `Status::at(secs)`.

#![no_main]

use std::time::{Duration, UNIX_EPOCH};

use arbitrary::Arbitrary;
use dot_sys::cli::{run, EXIT_FAILURE, EXIT_SUCCESS};
use dot_sys::Status;
use libfuzzer_sys::fuzz_target;

#[derive(Arbitrary, Debug)]
struct Input {
    secs: u64,
    nanos: u32,
    before_epoch: bool,
}

fuzz_target!(|input: Input| {
    let delta = Duration::new(input.secs, input.nanos % 1_000_000_000);
    let clock = if input.before_epoch {
        UNIX_EPOCH.checked_sub(delta)
    } else {
        UNIX_EPOCH.checked_add(delta)
    };
    let Some(clock) = clock else {
        return;
    };

    let (mut out, mut err) = (Vec::new(), Vec::new());
    let code = run(&mut out, &mut err, clock);

    if input.before_epoch && delta > Duration::ZERO {
        assert_eq!(code, EXIT_FAILURE);
        assert!(out.is_empty());
        assert_eq!(err, b"dot-sys: system clock is before the Unix epoch\n");
    } else {
        assert_eq!(code, EXIT_SUCCESS);
        assert!(err.is_empty());
        let text = String::from_utf8(out).expect("utf-8");
        let line = text.strip_suffix('\n').expect("one trailing newline");
        assert_eq!(Status::parse(line), Ok(Status::at(input.secs)));
    }
});
