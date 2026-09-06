// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! Drives `Status::at` and `Status::from_system_time` with every `u64`
//! timestamp and checks they agree with each other and with the JSON round
//! trip.

#![no_main]

use std::time::{Duration, UNIX_EPOCH};

use dot_sys::{Status, ENGINE_WASM, STATUS_OK};
use libfuzzer_sys::fuzz_target;

fuzz_target!(|secs: u64| {
    let status = Status::at(secs);
    assert_eq!(status.status, STATUS_OK);
    assert_eq!(status.engine, ENGINE_WASM);
    assert_eq!(status.timestamp, secs);

    let json = status.to_json();
    assert_eq!(Status::parse(&json).as_ref(), Ok(&status));

    // Platforms cap how far `SystemTime` can reach; only compare when the
    // instant is representable.
    if let Some(time) = UNIX_EPOCH.checked_add(Duration::from_secs(secs)) {
        assert_eq!(Status::from_system_time(time), Ok(status));
    }
});
