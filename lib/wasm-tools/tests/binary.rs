// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! End-to-end tests that execute the built `dot-sys` binary.
//!
//! These spawn a process, which Miri cannot do, so they are skipped under
//! `cargo miri test`; the same logic is covered in-process by `cli::main`.
//! The WebAssembly build of the same binary is exercised by `wasm.rs`.

#![cfg(not(miri))]

use std::time::{SystemTime, UNIX_EPOCH};

use assert_cmd::Command;
use dot_sys::{cli, Status, ENGINE, ENGINE_NATIVE};

/// An evidence record that satisfies every check at [`STAMPED`].
const GOOD: &str = include_str!("data/compliant.json");

/// Unix time of the `generated_at` in `data/compliant.json`.
const STAMPED: &str = "1788955200";

fn dot_sys() -> Command {
    Command::cargo_bin("dot-sys").expect("binary built by cargo")
}

#[test]
fn the_host_binary_reports_the_native_engine() {
    // The `engine` field is a fact about where the code ran, so the host
    // build must not claim to be WebAssembly. `wasm.rs` asserts the other
    // half of the same contract.
    assert_eq!(ENGINE, ENGINE_NATIVE);
}

#[test]
fn prints_one_valid_record_and_exits_zero() {
    let before = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();
    let output = dot_sys()
        .assert()
        .success()
        .code(i32::from(cli::EXIT_SUCCESS))
        .get_output()
        .clone();
    let after = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();

    assert!(output.stderr.is_empty(), "stderr: {:?}", output.stderr);
    let stdout = String::from_utf8(output.stdout).expect("utf-8");
    let line = stdout.strip_suffix('\n').expect("single trailing newline");
    assert!(!line.contains('\n'), "exactly one line");

    let status = Status::parse(line).expect("stdout parses as a Status record");
    assert_eq!(status.status, "ok");
    assert_eq!(status.engine, ENGINE);
    assert!(
        (before..=after).contains(&status.timestamp),
        "{before} <= {} <= {after}",
        status.timestamp
    );
}

#[test]
fn output_is_byte_identical_to_historic_format() {
    // The pre-0.2 binary was literally
    //   println!(r#"{{"status": "ok", "timestamp": {}, "engine": "wasm"}}"#, now);
    // Assert the exact bytes around the timestamp, not just parseability.
    let output = dot_sys().assert().success().get_output().stdout.clone();
    let text = String::from_utf8(output).expect("utf-8");
    let prefix = r#"{"status": "ok", "timestamp": "#;
    let suffix = format!(", \"engine\": \"{ENGINE}\"}}\n");
    assert!(text.starts_with(prefix), "prefix mismatch: {text:?}");
    assert!(text.ends_with(&suffix), "suffix mismatch: {text:?}");
    let digits = &text[prefix.len()..text.len() - suffix.len()];
    assert!(
        !digits.is_empty() && digits.bytes().all(|b| b.is_ascii_digit()),
        "timestamp digits: {digits:?}"
    );
    assert_ne!(digits, "0");
    assert!(!digits.starts_with('0'));

    let expected = format!("{prefix}{digits}{suffix}");
    assert_eq!(text, expected);
    assert_eq!(
        text,
        format!("{}\n", Status::at(digits.parse().unwrap()).to_json())
    );
}

#[test]
fn help_and_version_are_available() {
    for flag in ["--help", "-h"] {
        let out = dot_sys().arg(flag).assert().success().get_output().clone();
        assert!(out.stderr.is_empty());
        assert_eq!(String::from_utf8(out.stdout).unwrap(), cli::USAGE);
    }
    let out = dot_sys()
        .arg("--version")
        .assert()
        .success()
        .get_output()
        .clone();
    let text = String::from_utf8(out.stdout).unwrap();
    assert!(text.starts_with("dot-sys "), "{text}");
    assert!(text.trim_end().ends_with(&format!("({ENGINE})")), "{text}");
}

#[test]
fn an_unknown_argument_is_a_usage_error() {
    let out = dot_sys()
        .args(["--anything", "goes"])
        .write_stdin("ignored")
        .assert()
        .code(i32::from(cli::EXIT_USAGE))
        .get_output()
        .clone();
    assert!(out.stdout.is_empty());
    let err = String::from_utf8(out.stderr).unwrap();
    assert!(
        err.starts_with("dot-sys: unknown argument \"--anything\""),
        "{err}"
    );
    assert!(err.ends_with(cli::USAGE), "{err}");
}

#[test]
fn verify_reads_stdin_and_passes_a_compliant_record() {
    let out = dot_sys()
        .args(["verify", "--now", STAMPED])
        .write_stdin(GOOD)
        .assert()
        .code(i32::from(cli::EXIT_SUCCESS))
        .get_output()
        .clone();
    assert!(out.stderr.is_empty());
    let text = String::from_utf8(out.stdout).unwrap();
    assert!(text.starts_with("pass  generated_at"), "{text}");
    assert!(
        text.ends_with(&format!("checks passed on {ENGINE}\n")),
        "{text}"
    );
}

#[test]
fn verify_json_round_trips_through_the_process_boundary() {
    let out = dot_sys()
        .args(["verify", "--json", "--now", STAMPED])
        .write_stdin(GOOD)
        .assert()
        .code(i32::from(cli::EXIT_SUCCESS))
        .get_output()
        .clone();
    let text = String::from_utf8(out.stdout).unwrap();
    let line = text.strip_suffix('\n').expect("one trailing newline");
    dot_sys::json::validate(line).expect("stdout is well-formed JSON");
    let summary = dot_sys::json::get(line, "summary").expect("summary present");
    assert_eq!(
        summary.text().parse::<Status>().expect("a Status record"),
        Status::new("ok", STAMPED.parse::<u64>().unwrap(), ENGINE)
    );
}

#[test]
fn verify_fails_loudly_on_a_non_compliant_record() {
    let broken = GOOD.replace(
        "\"merge_verify_signatures\": true",
        "\"merge_verify_signatures\": false",
    );
    let out = dot_sys()
        .args(["verify", "--now", STAMPED])
        .write_stdin(broken)
        .assert()
        .code(i32::from(cli::EXIT_FAILURE))
        .get_output()
        .clone();
    assert!(out.stderr.is_empty());
    let text = String::from_utf8(out.stdout).unwrap();
    assert!(
        text.contains("fail  git_signing.merge_verify_signatures"),
        "{text}"
    );
}

#[test]
fn verify_rejects_input_that_is_not_json() {
    let out = dot_sys()
        .arg("verify")
        .write_stdin("definitely not json")
        .assert()
        .code(i32::from(cli::EXIT_USAGE))
        .get_output()
        .clone();
    assert!(out.stdout.is_empty());
    assert_eq!(
        String::from_utf8(out.stderr).unwrap(),
        "dot-sys: expected a JSON value at byte 0\n"
    );
}
