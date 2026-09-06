// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! Criterion benchmarks covering every public function of `dot_sys`.
//!
//! One benchmark per entry point, so a regression in any of them shows up
//! in `cargo bench` output. `cargo bench -- --quick` is the CI smoke run.

use std::io;
use std::time::{Duration, UNIX_EPOCH};

use criterion::{criterion_group, criterion_main, Criterion};
use std::hint::black_box;

use dot_sys::{cli, Error, Status};

const CANONICAL: &str = r#"{"status": "ok", "timestamp": 1700000000, "engine": "wasm"}"#;
const ESCAPED: &str =
    r#"{"status": "\"\\\/\b\f\n\r\t\u0041\u00e9\ud83e\udd80", "timestamp": 1, "engine": "\u001F"}"#;
const PADDED: &str =
    " \t\r\n{ \"status\"\t:\n\"ok\" , \"timestamp\" : 7 , \"engine\" : \"wasm\" }\n";

fn constructors(c: &mut Criterion) {
    let mut g = c.benchmark_group("constructors");
    g.bench_function("Status::new", |b| {
        b.iter(|| Status::new(black_box("ok"), black_box(1_700_000_000), black_box("wasm")));
    });
    g.bench_function("Status::at", |b| {
        b.iter(|| Status::at(black_box(1_700_000_000)));
    });
    g.bench_function("Status::now", |b| {
        b.iter(|| Status::now().expect("clock after epoch"));
    });
    let t = UNIX_EPOCH + Duration::from_secs(1_700_000_000);
    g.bench_function("Status::from_system_time", |b| {
        b.iter(|| Status::from_system_time(black_box(t)).expect("after epoch"));
    });
    let before = UNIX_EPOCH - Duration::from_secs(1);
    g.bench_function("Status::from_system_time/err", |b| {
        b.iter(|| Status::from_system_time(black_box(before)).expect_err("before epoch"));
    });
    g.finish();
}

fn serialise(c: &mut Criterion) {
    let mut g = c.benchmark_group("serialise");
    let plain = Status::at(1_700_000_000);
    let escaped = Status::new("\"\\\n\r\t\u{08}\u{0C}\u{01}", 1, "é\u{1F980}");
    g.bench_function("Status::to_json/plain", |b| {
        b.iter(|| black_box(&plain).to_json());
    });
    g.bench_function("Status::to_json/escaped", |b| {
        b.iter(|| black_box(&escaped).to_json());
    });
    g.bench_function("Display::fmt", |b| b.iter(|| black_box(&plain).to_string()));
    g.finish();
}

fn parse(c: &mut Criterion) {
    let mut g = c.benchmark_group("parse");
    g.bench_function("Status::parse/canonical", |b| {
        b.iter(|| Status::parse(black_box(CANONICAL)).expect("valid"));
    });
    g.bench_function("Status::parse/escaped", |b| {
        b.iter(|| Status::parse(black_box(ESCAPED)).expect("valid"));
    });
    g.bench_function("Status::parse/padded", |b| {
        b.iter(|| Status::parse(black_box(PADDED)).expect("valid"));
    });
    g.bench_function("Status::parse/error", |b| {
        b.iter(|| {
            Status::parse(black_box(r#"{"status": "ok", "timestamp": 1.5}"#)).expect_err("invalid")
        });
    });
    g.bench_function("FromStr::from_str", |b| {
        b.iter(|| black_box(CANONICAL).parse::<Status>().expect("valid"));
    });
    g.finish();
}

fn errors(c: &mut Criterion) {
    let mut g = c.benchmark_group("errors");
    let err = Error::Unexpected {
        offset: 30,
        expected: "a digit",
    };
    g.bench_function("Error::Display", |b| b.iter(|| black_box(err).to_string()));
    g.finish();
}

fn cli_run(c: &mut Criterion) {
    let mut g = c.benchmark_group("cli");
    let t = UNIX_EPOCH + Duration::from_secs(1_700_000_000);
    let before = UNIX_EPOCH - Duration::from_secs(1);
    g.bench_function("cli::run/success", |b| {
        b.iter(|| cli::run(&mut io::sink(), &mut io::sink(), black_box(t)));
    });
    g.bench_function("cli::run/failure", |b| {
        b.iter(|| cli::run(&mut io::sink(), &mut io::sink(), black_box(before)));
    });
    g.finish();
}

criterion_group!(benches, constructors, serialise, parse, errors, cli_run);
criterion_main!(benches);
