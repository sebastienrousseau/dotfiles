// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! Drives the attestation policy with arbitrary documents, clocks and
//! freshness windows, and checks that a verdict is always self-consistent
//! and always serialises to something the crate can read back.
//!
//! The input is laid out by hand rather than through `Arbitrary` so that a
//! corpus seed is readable: eight little-endian bytes of `now`, eight of
//! `max_age`, then the evidence document as UTF-8.

#![no_main]

use dot_sys::attest::{Outcome, Report};
use dot_sys::{json, Status, ENGINE, STATUS_FAILED, STATUS_OK};
use libfuzzer_sys::fuzz_target;

/// Bytes of clock header before the document starts.
const HEADER: usize = 16;

fuzz_target!(|data: &[u8]| {
    if data.len() < HEADER {
        return;
    }
    let now = u64::from_le_bytes(data[..8].try_into().expect("eight bytes"));
    let max_age = u64::from_le_bytes(data[8..HEADER].try_into().expect("eight bytes"));
    let Ok(document) = std::str::from_utf8(&data[HEADER..]) else {
        return;
    };

    let Ok(report) = Report::verify(document, now, max_age) else {
        // Refusing a document is only allowed when it is not valid JSON.
        assert!(json::validate(document).is_err());
        return;
    };
    assert!(json::validate(document).is_ok());

    // The verdict agrees with the checks it is made of.
    let failures = report
        .checks
        .iter()
        .filter(|c| c.outcome == Outcome::Fail)
        .count();
    assert_eq!(failures, report.failures());
    assert_eq!(report.passed(), failures == 0);

    // The summary states the outcome, the clock it was given, and where it
    // ran — never anything else.
    let summary = report.summary();
    assert_eq!(summary.timestamp, now);
    assert_eq!(summary.engine, ENGINE);
    assert_eq!(
        summary.status,
        if report.passed() {
            STATUS_OK
        } else {
            STATUS_FAILED
        }
    );

    // Both renderings survive a round trip.
    let verdict = report.to_json();
    json::validate(&verdict).expect("the verdict is well-formed JSON");
    let read_back = json::get(&verdict, "summary").expect("summary present");
    assert_eq!(read_back.text().parse::<Status>(), Ok(summary));

    let text = report.to_string();
    assert!(text.ends_with('\n'));

    // One line per check plus the summary. A detail quotes a value the
    // document chose, so a newline in it would split a row in two; a
    // carriage return or an ESC would let the attested machine repaint the
    // reviewer's screen. Neither may survive rendering.
    assert_eq!(
        text.lines().count(),
        report.checks.len() + 1,
        "a check rendered across more than one line: {text:?}"
    );
    for line in text.lines() {
        assert!(
            !line.chars().any(char::is_control),
            "control character reached the rendered line {line:?}"
        );
    }
});
