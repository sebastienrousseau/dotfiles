// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! Criterion benchmarks for the JSON reader, the timestamp parser and the
//! attestation policy — the code the WebAssembly module spends its time in.
//!
//! One benchmark per public entry point, so a regression in any of them
//! shows up in `cargo bench` output. `cargo bench -- --quick` is the CI
//! smoke run.

use std::hint::black_box;
use std::io;

use criterion::{criterion_group, criterion_main, Criterion};

use dot_sys::attest::{Report, MAX_AGE_DEFAULT};
use dot_sys::time::parse_rfc3339_utc;
use dot_sys::{cli, json};

/// A realistic evidence record, the same fixture the tests use.
const EVIDENCE: &str = include_str!("../tests/data/compliant.json");

/// The same machine failing six of the eleven checks.
const NON_COMPLIANT: &str = include_str!("../tests/data/non-compliant.json");

/// Unix time of the `generated_at` both fixtures carry.
const STAMPED: u64 = 1_788_955_200;

fn json_reader(c: &mut Criterion) {
    let mut g = c.benchmark_group("json");
    g.bench_function("validate/evidence", |b| {
        b.iter(|| json::validate(black_box(EVIDENCE)).expect("valid"));
    });
    g.bench_function("validate/error", |b| {
        b.iter(|| json::validate(black_box("{\"a\": 1 \"b\": 2}")).expect_err("invalid"));
    });
    g.bench_function("get/first-member", |b| {
        b.iter(|| json::get(black_box(EVIDENCE), "generated_at").expect("present"));
    });
    g.bench_function("get/deep-member", |b| {
        b.iter(|| json::get(black_box(EVIDENCE), "mcp.doctor.status").expect("present"));
    });
    g.bench_function("get/missing", |b| {
        b.iter(|| json::get(black_box(EVIDENCE), "nope").expect_err("absent"));
    });

    let string = json::get(EVIDENCE, "git_signing.signing_key").expect("present");
    let number = json::get(EVIDENCE, "mcp.doctor.warnings").expect("present");
    let boolean = json::get(EVIDENCE, "git_signing.merge_verify_signatures").expect("present");
    g.bench_function("Value::as_str", |b| {
        b.iter(|| black_box(string).as_str().expect("a string"));
    });
    g.bench_function("Value::as_u64", |b| {
        b.iter(|| black_box(number).as_u64().expect("a number"));
    });
    g.bench_function("Value::as_bool", |b| {
        b.iter(|| black_box(boolean).as_bool().expect("a boolean"));
    });
    g.bench_function("Value::text", |b| b.iter(|| black_box(string).text()));
    g.bench_function("Value::is_null", |b| b.iter(|| black_box(string).is_null()));
    g.bench_function("Value::kind", |b| b.iter(|| black_box(string).kind()));
    g.bench_function("Value::offset", |b| b.iter(|| black_box(string).offset()));
    g.bench_function("Kind::name", |b| b.iter(|| black_box(string).kind().name()));
    g.finish();
}

fn timestamps(c: &mut Criterion) {
    let mut g = c.benchmark_group("time");
    g.bench_function("parse_rfc3339_utc/ok", |b| {
        b.iter(|| parse_rfc3339_utc(black_box("2026-09-09T12:00:00Z")).expect("valid"));
    });
    g.bench_function("parse_rfc3339_utc/error", |b| {
        b.iter(|| parse_rfc3339_utc(black_box("2026-13-09T12:00:00Z")).expect_err("invalid"));
    });
    g.finish();
}

fn policy(c: &mut Criterion) {
    let mut g = c.benchmark_group("attest");
    g.bench_function("Report::verify/pass", |b| {
        b.iter(|| Report::verify(black_box(EVIDENCE), STAMPED, MAX_AGE_DEFAULT).expect("valid"));
    });
    g.bench_function("Report::verify/fail", |b| {
        b.iter(|| {
            Report::verify(black_box(NON_COMPLIANT), STAMPED, MAX_AGE_DEFAULT).expect("valid")
        });
    });
    g.bench_function("Report::verify/not-json", |b| {
        b.iter(|| Report::verify(black_box("definitely not json"), 0, 0).expect_err("invalid"));
    });

    let report = Report::verify(EVIDENCE, STAMPED, MAX_AGE_DEFAULT).expect("valid");
    g.bench_function("Report::to_json", |b| {
        b.iter(|| black_box(&report).to_json());
    });
    g.bench_function("Report::Display", |b| {
        b.iter(|| black_box(&report).to_string());
    });
    g.bench_function("Report::summary", |b| {
        b.iter(|| black_box(&report).summary());
    });
    g.bench_function("Report::passed", |b| {
        b.iter(|| black_box(&report).passed());
    });
    g.bench_function("Report::failures", |b| {
        b.iter(|| black_box(&report).failures());
    });
    g.bench_function("Outcome::as_str", |b| {
        b.iter(|| black_box(report.checks[0].outcome).as_str());
    });
    g.finish();
}

fn cli_verify(c: &mut Criterion) {
    let mut g = c.benchmark_group("cli-verify");
    for (name, json) in [("table", false), ("json", true)] {
        g.bench_function(format!("cli::verify/{name}"), |b| {
            b.iter(|| {
                cli::verify(
                    black_box(EVIDENCE),
                    &mut io::sink(),
                    &mut io::sink(),
                    STAMPED,
                    MAX_AGE_DEFAULT,
                    json,
                )
            });
        });
    }
    g.bench_function("cli::main/verify", |b| {
        b.iter(|| {
            cli::main(
                &[
                    "verify".to_string(),
                    "--now".to_string(),
                    STAMPED.to_string(),
                ],
                &mut EVIDENCE.as_bytes(),
                &mut io::sink(),
                &mut io::sink(),
                std::time::UNIX_EPOCH,
            )
        });
    });
    g.finish();
}

criterion_group!(benches, json_reader, timestamps, policy, cli_verify);
criterion_main!(benches);
