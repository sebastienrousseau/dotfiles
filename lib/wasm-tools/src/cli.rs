// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! Command-line entry points, kept free of process-global state so they can
//! be driven from tests, benchmarks and fuzz targets with an injected
//! clock, an in-memory reader and in-memory writers.
//!
//! The same source builds two ways. As a host binary it is an ordinary CLI;
//! as `wasm32-wasip1` it is a module `wasmtime` runs, reading stdin and
//! writing stdout through WASI and nothing else. [`main`] is the shared
//! entry point, so there is no `cfg` fork between the two and no second
//! code path that only one of them exercises.
//!
//! # Example
//!
//! ```
//! use std::time::{Duration, UNIX_EPOCH};
//! use dot_sys::cli::{main, EXIT_SUCCESS};
//!
//! let evidence = br#"{"generated_at": "2026-09-09T12:00:00Z"}"#;
//! let (mut out, mut err) = (Vec::new(), Vec::new());
//! let code = main(
//!     &["verify".into(), "--json".into(), "--now".into(), "1788955200".into()],
//!     &mut &evidence[..],
//!     &mut out,
//!     &mut err,
//!     UNIX_EPOCH,
//! );
//!
//! // The record is well-formed but far from compliant, so the verdict is
//! // "failed" and the exit code is non-zero.
//! assert_ne!(code, EXIT_SUCCESS);
//! assert!(String::from_utf8(out).unwrap().contains(r#""status": "failed""#));
//! assert!(err.is_empty());
//! ```

use std::io::{Read, Write};
use std::time::SystemTime;

use crate::attest::{Report, MAX_AGE_DEFAULT};
use crate::{Status, ENGINE};

/// Process exit code when the record was written and every check passed.
pub const EXIT_SUCCESS: u8 = 0;

/// Process exit code when a check failed, the clock was unusable, or a
/// stream write failed.
pub const EXIT_FAILURE: u8 = 1;

/// Process exit code when the arguments or the input document were not
/// something the program could act on at all.
pub const EXIT_USAGE: u8 = 2;

/// The `--help` text, also printed on a usage error.
pub const USAGE: &str = "\
dot-sys — health probe and WebAssembly verifier for `dot attest` evidence

Usage:
  dot-sys                     print one health-probe record for now
  dot-sys verify [options]    verify an evidence record read from stdin
  dot-sys --help              print this text
  dot-sys --version           print the version and engine

Options for `verify`:
  --json            emit the machine-readable verdict instead of a table
  --max-age SECS    freshness window for `generated_at` (default 604800,
                    `any` to accept evidence of any age)
  --now SECS        verify as if the current Unix time were SECS, which
                    makes a verdict reproducible

Exit codes: 0 every check passed, 1 a check failed, 2 bad usage or input.
";

/// Runs the `dot-sys` command: writes one health-probe record for `clock`
/// to `out`, followed by a newline, and returns the process exit code.
///
/// On failure a one-line diagnostic prefixed with `dot-sys: ` is written to
/// `err` and [`EXIT_FAILURE`] is returned. A failure to write the
/// diagnostic itself is ignored — there is nowhere left to report it.
///
/// # Example
///
/// ```
/// use std::time::{Duration, UNIX_EPOCH};
/// use dot_sys::{cli, ENGINE};
///
/// let mut out = Vec::new();
/// let code = cli::run(&mut out, &mut std::io::sink(), UNIX_EPOCH + Duration::from_secs(1_700_000_000));
/// assert_eq!(code, cli::EXIT_SUCCESS);
/// assert_eq!(
///     String::from_utf8(out).unwrap(),
///     format!("{{\"status\": \"ok\", \"timestamp\": 1700000000, \"engine\": \"{ENGINE}\"}}\n"),
/// );
/// ```
#[must_use]
pub fn run(out: &mut dyn Write, err: &mut dyn Write, clock: SystemTime) -> u8 {
    let result = Status::from_system_time(clock)
        .map_err(|e| e.to_string())
        .and_then(|status| writeln!(out, "{status}").map_err(|e| e.to_string()));
    match result {
        Ok(()) => EXIT_SUCCESS,
        Err(message) => {
            // Best effort: if stderr is gone too, the exit code still says it.
            let _ = writeln!(err, "dot-sys: {message}");
            EXIT_FAILURE
        }
    }
}

/// Verifies one evidence `document` against the attestation policy.
///
/// Writes the verdict to `out` — [`Report::to_json`] when `json` is set,
/// the aligned table otherwise — and returns the process exit code.
///
/// # Example
///
/// ```
/// use dot_sys::cli::{verify, EXIT_USAGE};
///
/// let (mut out, mut err) = (Vec::new(), Vec::new());
/// let code = verify("definitely not json", &mut out, &mut err, 0, 60, false);
/// assert_eq!(code, EXIT_USAGE);
/// assert!(out.is_empty());
/// assert_eq!(err, b"dot-sys: expected a JSON value at byte 0\n");
/// ```
#[must_use]
pub fn verify(
    document: &str,
    out: &mut dyn Write,
    err: &mut dyn Write,
    now: u64,
    max_age: u64,
    json: bool,
) -> u8 {
    let report = match Report::verify(document, now, max_age) {
        Ok(report) => report,
        Err(e) => {
            let _ = writeln!(err, "dot-sys: {e}");
            return EXIT_USAGE;
        }
    };
    // `Display` already ends its last line; the JSON form does not.
    let rendered = if json {
        format!("{}\n", report.to_json())
    } else {
        report.to_string()
    };
    finish(&report, out, err, rendered.as_bytes())
}

/// Writes `rendered` and turns the verdict into an exit code.
fn finish(report: &Report, out: &mut dyn Write, err: &mut dyn Write, rendered: &[u8]) -> u8 {
    if let Err(e) = out.write_all(rendered) {
        let _ = writeln!(err, "dot-sys: {e}");
        return EXIT_FAILURE;
    }
    if report.passed() {
        EXIT_SUCCESS
    } else {
        EXIT_FAILURE
    }
}

/// Dispatches `args` — the command line with the program name already
/// removed — to [`run`] or [`verify`].
///
/// `input` is only read by `verify`, and `clock` is only used when no
/// `--now` was given, so a caller that supplies both gets a completely
/// deterministic program.
///
/// # Example
///
/// ```
/// use std::time::{Duration, UNIX_EPOCH};
/// use dot_sys::cli::{main, EXIT_SUCCESS, EXIT_USAGE};
///
/// let (mut out, mut err) = (Vec::new(), Vec::new());
/// let code = main(&[], &mut &b""[..], &mut out, &mut err, UNIX_EPOCH + Duration::from_secs(7));
/// assert_eq!(code, EXIT_SUCCESS);
/// assert!(String::from_utf8(out).unwrap().contains(r#""timestamp": 7"#));
///
/// let (mut out, mut err) = (Vec::new(), Vec::new());
/// let code = main(&["woof".into()], &mut &b""[..], &mut out, &mut err, UNIX_EPOCH);
/// assert_eq!(code, EXIT_USAGE);
/// assert!(String::from_utf8(err).unwrap().starts_with("dot-sys: unknown argument \"woof\""));
/// ```
#[must_use]
pub fn main(
    args: &[String],
    input: &mut dyn Read,
    out: &mut dyn Write,
    err: &mut dyn Write,
    clock: SystemTime,
) -> u8 {
    match args.first().map(String::as_str) {
        None => run(out, err, clock),
        Some("--help" | "-h") => {
            let _ = out.write_all(USAGE.as_bytes());
            EXIT_SUCCESS
        }
        Some("--version" | "-V") => {
            let _ = writeln!(out, "dot-sys {} ({ENGINE})", env!("CARGO_PKG_VERSION"));
            EXIT_SUCCESS
        }
        Some("verify") => match Options::parse(&args[1..]) {
            Ok(options) => verify_stream(&options, input, out, err, clock),
            Err(message) => usage_error(err, &message),
        },
        Some(other) => usage_error(err, &format!("unknown argument {other:?}")),
    }
}

/// Reads the whole document from `input` and hands it to [`verify`].
fn verify_stream(
    options: &Options,
    input: &mut dyn Read,
    out: &mut dyn Write,
    err: &mut dyn Write,
    clock: SystemTime,
) -> u8 {
    let mut document = String::new();
    if let Err(e) = input.read_to_string(&mut document) {
        let _ = writeln!(err, "dot-sys: {e}");
        return EXIT_USAGE;
    }
    let now = match options.now {
        Some(now) => now,
        None => match Status::from_system_time(clock) {
            Ok(status) => status.timestamp,
            Err(e) => {
                let _ = writeln!(err, "dot-sys: {e}");
                return EXIT_FAILURE;
            }
        },
    };
    verify(&document, out, err, now, options.max_age, options.json)
}

/// Reports a bad command line and returns [`EXIT_USAGE`].
fn usage_error(err: &mut dyn Write, message: &str) -> u8 {
    let _ = writeln!(err, "dot-sys: {message}");
    let _ = err.write_all(USAGE.as_bytes());
    EXIT_USAGE
}

/// Everything `verify` can be told from the command line.
#[derive(Debug, PartialEq, Eq)]
struct Options {
    json: bool,
    max_age: u64,
    now: Option<u64>,
}

impl Options {
    /// Parses the arguments that follow `verify`.
    fn parse(args: &[String]) -> Result<Self, String> {
        let mut options = Self {
            json: false,
            max_age: MAX_AGE_DEFAULT,
            now: None,
        };
        let mut rest = args.iter();
        while let Some(arg) = rest.next() {
            match arg.as_str() {
                "--json" | "-j" => options.json = true,
                "--max-age" => options.max_age = parse_max_age(next(&mut rest, arg)?)?,
                "--now" => options.now = Some(parse_u64(next(&mut rest, arg)?, "--now")?),
                other => return Err(format!("unknown argument {other:?}")),
            }
        }
        Ok(options)
    }
}

/// Takes the value that must follow `flag`.
fn next<'a>(rest: &mut std::slice::Iter<'a, String>, flag: &str) -> Result<&'a str, String> {
    rest.next()
        .map(String::as_str)
        .ok_or_else(|| format!("{flag} needs a value"))
}

/// Parses a `--max-age` value, where `any` lifts the limit.
fn parse_max_age(text: &str) -> Result<u64, String> {
    if text == "any" {
        return Ok(crate::attest::MAX_AGE_UNLIMITED);
    }
    parse_u64(text, "--max-age")
}

/// Parses a plain decimal `u64`, naming `flag` if it will not.
fn parse_u64(text: &str, flag: &str) -> Result<u64, String> {
    text.parse()
        .map_err(|_| format!("{flag} needs a non-negative whole number, not {text:?}"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io;
    use std::time::{Duration, UNIX_EPOCH};

    use crate::attest::MAX_AGE_UNLIMITED;

    /// An evidence record that satisfies every check at [`STAMPED`].
    const GOOD: &str = r#"{
      "generated_at": "2026-09-09T12:00:00Z",
      "dotfiles_version": "0.2.519",
      "platform": {"runtime": "linux-x64", "host_os": "linux", "hostname": "kestrel"},
      "git_signing": {
        "format": "ssh",
        "signing_key": "ssh-ed25519 AAAAC3Nz",
        "allowed_signers_file": "/home/u/.config/git/allowed_signers",
        "merge_verify_signatures": true
      },
      "agent": {"current_profile": "ask"},
      "mcp": {"doctor": {"status": "healthy"}}
    }"#;

    const STAMPED: u64 = 1_788_955_200;

    /// A writer whose every write fails.
    struct Broken;

    impl Write for Broken {
        fn write(&mut self, _: &[u8]) -> io::Result<usize> {
            Err(io::Error::new(io::ErrorKind::BrokenPipe, "pipe closed"))
        }

        fn flush(&mut self) -> io::Result<()> {
            Ok(())
        }
    }

    /// A reader whose every read fails.
    struct Unreadable;

    impl Read for Unreadable {
        fn read(&mut self, _: &mut [u8]) -> io::Result<usize> {
            Err(io::Error::new(io::ErrorKind::ConnectionAborted, "no stdin"))
        }
    }

    fn args(words: &[&str]) -> Vec<String> {
        words.iter().map(|w| (*w).to_string()).collect()
    }

    /// Runs `main` and returns `(code, stdout, stderr)`.
    fn cli(words: &[&str], input: &str, clock: SystemTime) -> (u8, String, String) {
        let (mut out, mut err) = (Vec::new(), Vec::new());
        let code = main(
            &args(words),
            &mut input.as_bytes(),
            &mut out,
            &mut err,
            clock,
        );
        (
            code,
            String::from_utf8(out).expect("utf-8"),
            String::from_utf8(err).expect("utf-8"),
        )
    }

    #[test]
    fn success_writes_record_and_newline() {
        let (mut out, mut err) = (Vec::new(), Vec::new());
        let code = run(
            &mut out,
            &mut err,
            UNIX_EPOCH + Duration::from_secs(1_700_000_000),
        );
        assert_eq!(code, EXIT_SUCCESS);
        assert_eq!(
            String::from_utf8(out).expect("utf-8"),
            format!(
                "{{\"status\": \"ok\", \"timestamp\": 1700000000, \"engine\": \"{ENGINE}\"}}\n"
            )
        );
        assert!(err.is_empty());
    }

    #[test]
    fn clock_before_epoch_reports_and_fails() {
        let (mut out, mut err) = (Vec::new(), Vec::new());
        let code = run(&mut out, &mut err, UNIX_EPOCH - Duration::from_secs(1));
        assert_eq!(code, EXIT_FAILURE);
        assert!(out.is_empty());
        assert_eq!(err, b"dot-sys: system clock is before the Unix epoch\n");
    }

    #[test]
    fn broken_stdout_reports_and_fails() {
        let mut err = Vec::new();
        let code = run(&mut Broken, &mut err, UNIX_EPOCH);
        assert_eq!(code, EXIT_FAILURE);
        assert_eq!(err, b"dot-sys: pipe closed\n");
    }

    #[test]
    fn broken_stderr_still_fails_cleanly() {
        let code = run(&mut Broken, &mut Broken, UNIX_EPOCH);
        assert_eq!(code, EXIT_FAILURE);
        // The helper's flush is a no-op by contract; pin that.
        assert!(Broken.flush().is_ok());
    }

    #[test]
    fn real_streams_accept_the_writers() {
        // Exercises the `dyn Write` coercion the binary relies on.
        let code = run(&mut io::sink(), &mut io::sink(), UNIX_EPOCH);
        assert_eq!(code, EXIT_SUCCESS);
    }

    #[test]
    fn no_arguments_prints_the_probe() {
        let (code, out, err) = cli(&[], "", UNIX_EPOCH + Duration::from_secs(9));
        assert_eq!(code, EXIT_SUCCESS);
        assert_eq!(
            out,
            format!("{{\"status\": \"ok\", \"timestamp\": 9, \"engine\": \"{ENGINE}\"}}\n")
        );
        assert!(err.is_empty());
    }

    #[test]
    fn help_and_version_go_to_stdout() {
        for flag in ["--help", "-h"] {
            let (code, out, err) = cli(&[flag], "", UNIX_EPOCH);
            assert_eq!(code, EXIT_SUCCESS);
            assert_eq!(out, USAGE);
            assert!(err.is_empty());
        }
        for flag in ["--version", "-V"] {
            let (code, out, err) = cli(&[flag], "", UNIX_EPOCH);
            assert_eq!(code, EXIT_SUCCESS);
            assert_eq!(
                out,
                format!("dot-sys {} ({ENGINE})\n", env!("CARGO_PKG_VERSION"))
            );
            assert!(err.is_empty());
        }
    }

    #[test]
    fn unknown_arguments_are_a_usage_error() {
        let (code, out, err) = cli(&["woof"], "", UNIX_EPOCH);
        assert_eq!(code, EXIT_USAGE);
        assert!(out.is_empty());
        assert!(err.starts_with("dot-sys: unknown argument \"woof\"\n"));
        assert!(err.ends_with(USAGE));

        let (code, _, err) = cli(&["verify", "--woof"], "{}", UNIX_EPOCH);
        assert_eq!(code, EXIT_USAGE);
        assert!(err.starts_with("dot-sys: unknown argument \"--woof\"\n"));
    }

    #[test]
    fn flags_that_need_values_say_so() {
        for flag in ["--max-age", "--now"] {
            let (code, _, err) = cli(&["verify", flag], "{}", UNIX_EPOCH);
            assert_eq!(code, EXIT_USAGE);
            assert!(
                err.starts_with(&format!("dot-sys: {flag} needs a value\n")),
                "{err}"
            );
        }
        let (code, _, err) = cli(&["verify", "--now", "soon"], "{}", UNIX_EPOCH);
        assert_eq!(code, EXIT_USAGE);
        assert!(
            err.starts_with("dot-sys: --now needs a non-negative whole number, not \"soon\"\n"),
            "{err}"
        );
        let (code, _, err) = cli(&["verify", "--max-age", "-1"], "{}", UNIX_EPOCH);
        assert_eq!(code, EXIT_USAGE);
        assert!(
            err.starts_with("dot-sys: --max-age needs a non-negative whole number, not \"-1\"\n"),
            "{err}"
        );
    }

    #[test]
    fn verify_passes_a_compliant_record() {
        let (code, out, err) = cli(&["verify", "--now", "1788955200"], GOOD, UNIX_EPOCH);
        assert_eq!(code, EXIT_SUCCESS);
        assert!(out.starts_with("pass  generated_at"), "{out}");
        assert!(
            out.ends_with(&format!("checks passed on {ENGINE}\n")),
            "{out}"
        );
        assert!(err.is_empty());
    }

    #[test]
    fn verify_json_emits_one_line_and_the_summary() {
        let (code, out, err) = cli(
            &["verify", "--json", "--now", "1788955200"],
            GOOD,
            UNIX_EPOCH,
        );
        assert_eq!(code, EXIT_SUCCESS);
        assert!(err.is_empty());
        let line = out.strip_suffix('\n').expect("one trailing newline");
        assert!(!line.contains('\n'), "one line: {line:?}");
        crate::json::validate(line).expect("well-formed JSON");
        assert!(line.starts_with(&format!(
            "{{\"summary\": {{\"status\": \"ok\", \"timestamp\": 1788955200, \"engine\": \"{ENGINE}\"}}"
        )));
        let summary = crate::json::get(line, "summary").expect("summary present");
        assert_eq!(
            summary
                .text()
                .parse::<Status>()
                .expect("summary is a record"),
            Status::new(crate::STATUS_OK, STAMPED, ENGINE)
        );
    }

    #[test]
    fn verify_fails_a_non_compliant_record() {
        let broken = GOOD.replace(
            "\"merge_verify_signatures\": true",
            "\"merge_verify_signatures\": false",
        );
        let (code, out, err) = cli(&["verify", "--now", "1788955200"], &broken, UNIX_EPOCH);
        assert_eq!(code, EXIT_FAILURE);
        assert!(
            out.contains("fail  git_signing.merge_verify_signatures"),
            "{out}"
        );
        assert!(out.ends_with("1 of 11 checks failed\n"), "{out}");
        assert!(err.is_empty());
    }

    #[test]
    fn verify_rejects_input_that_is_not_json() {
        let (code, out, err) = cli(&["verify"], "definitely not json", UNIX_EPOCH);
        assert_eq!(code, EXIT_USAGE);
        assert!(out.is_empty());
        assert_eq!(err, "dot-sys: expected a JSON value at byte 0\n");
    }

    #[test]
    fn verify_honours_max_age_and_any() {
        let stale = STAMPED + MAX_AGE_DEFAULT + 1;
        let (code, out, _) = cli(&["verify", "--now", &stale.to_string()], GOOD, UNIX_EPOCH);
        assert_eq!(code, EXIT_FAILURE);
        assert!(out.contains("past the"), "{out}");

        let (code, _, _) = cli(
            &["verify", "--now", &stale.to_string(), "--max-age", "any"],
            GOOD,
            UNIX_EPOCH,
        );
        assert_eq!(code, EXIT_SUCCESS);

        let (code, out, _) = cli(
            &[
                "verify",
                "--now",
                &(STAMPED + 10).to_string(),
                "--max-age",
                "5",
            ],
            GOOD,
            UNIX_EPOCH,
        );
        assert_eq!(code, EXIT_FAILURE);
        assert!(out.contains("10s old, past the 5s limit"), "{out}");
    }

    #[test]
    fn verify_falls_back_to_the_injected_clock() {
        let clock = UNIX_EPOCH + Duration::from_secs(STAMPED + 30);
        let (code, out, _) = cli(&["verify"], GOOD, clock);
        assert_eq!(code, EXIT_SUCCESS);
        assert!(out.contains("(30s old)"), "{out}");

        // A clock before the epoch is a runtime failure, not a verdict.
        let (mut out, mut err) = (Vec::new(), Vec::new());
        let code = main(
            &args(&["verify"]),
            &mut GOOD.as_bytes(),
            &mut out,
            &mut err,
            UNIX_EPOCH - Duration::from_secs(1),
        );
        assert_eq!(code, EXIT_FAILURE);
        assert!(out.is_empty());
        assert_eq!(err, b"dot-sys: system clock is before the Unix epoch\n");
    }

    #[test]
    fn unreadable_stdin_is_a_usage_error() {
        let (mut out, mut err) = (Vec::new(), Vec::new());
        let code = main(
            &args(&["verify"]),
            &mut Unreadable,
            &mut out,
            &mut err,
            UNIX_EPOCH,
        );
        assert_eq!(code, EXIT_USAGE);
        assert!(out.is_empty());
        assert_eq!(err, b"dot-sys: no stdin\n");
    }

    #[test]
    fn a_broken_stdout_beats_the_verdict() {
        for json in [false, true] {
            let mut err = Vec::new();
            let code = verify(
                GOOD,
                &mut Broken,
                &mut err,
                STAMPED,
                MAX_AGE_UNLIMITED,
                json,
            );
            assert_eq!(code, EXIT_FAILURE);
            assert_eq!(err, b"dot-sys: pipe closed\n");
        }
    }

    #[test]
    fn options_defaults_and_derives() {
        let parsed = Options::parse(&[]).expect("no arguments is valid");
        assert_eq!(
            parsed,
            Options {
                json: false,
                max_age: MAX_AGE_DEFAULT,
                now: None,
            }
        );
        assert_eq!(parsed, parsed);
        assert_ne!(parsed, Options::parse(&args(&["-j"])).expect("valid"));
        assert!(format!("{parsed:?}").contains("max_age"));
        assert_eq!(
            Options::parse(&args(&["--json", "--max-age", "any", "--now", "5"])),
            Ok(Options {
                json: true,
                max_age: MAX_AGE_UNLIMITED,
                now: Some(5),
            })
        );
    }
}
