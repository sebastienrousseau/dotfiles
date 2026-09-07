// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! End-to-end tests that execute the built `dot-sys` binary.
//!
//! These spawn a process, which Miri cannot do, so they are skipped under
//! `cargo miri test`; the same logic is covered in-process by `cli::run`.

#![cfg(not(miri))]

use std::time::{SystemTime, UNIX_EPOCH};

use assert_cmd::Command;
use dot_sys::{cli, Status};

fn dot_sys() -> Command {
    Command::cargo_bin("dot-sys").expect("binary built by cargo")
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
    assert_eq!(status.engine, "wasm");
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
    let suffix = ", \"engine\": \"wasm\"}\n";
    assert!(text.starts_with(prefix), "prefix mismatch: {text:?}");
    assert!(text.ends_with(suffix), "suffix mismatch: {text:?}");
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
fn ignores_arguments_and_stdin() {
    let output = dot_sys()
        .args(["--anything", "goes"])
        .write_stdin("ignored")
        .assert()
        .success()
        .stderr("")
        .get_output()
        .stdout
        .clone();
    assert!(
        output.starts_with(br#"{"status": "ok", "timestamp": "#),
        "{output:?}"
    );
}
