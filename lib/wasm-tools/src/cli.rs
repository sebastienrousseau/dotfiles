// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! Command-line entry point, kept free of process-global state so it can be
//! driven from tests, benchmarks and fuzz targets with an injected clock and
//! in-memory writers.
//!
//! # Example
//!
//! ```
//! use std::time::{Duration, UNIX_EPOCH};
//! use dot_sys::cli::{run, EXIT_FAILURE, EXIT_SUCCESS};
//!
//! let (mut out, mut err) = (Vec::new(), Vec::new());
//! let code = run(&mut out, &mut err, UNIX_EPOCH + Duration::from_secs(5));
//! assert_eq!(code, EXIT_SUCCESS);
//! assert_eq!(out, b"{\"status\": \"ok\", \"timestamp\": 5, \"engine\": \"wasm\"}\n");
//! assert!(err.is_empty());
//!
//! let code = run(&mut out, &mut err, UNIX_EPOCH - Duration::from_secs(1));
//! assert_eq!(code, EXIT_FAILURE);
//! assert_eq!(err, b"dot-sys: system clock is before the Unix epoch\n");
//! ```

use std::io::Write;
use std::time::SystemTime;

use crate::Status;

/// Process exit code when the record was written.
pub const EXIT_SUCCESS: u8 = 0;

/// Process exit code when the clock was unusable or a stream write failed.
pub const EXIT_FAILURE: u8 = 1;

/// Runs the `dot-sys` command: writes one health-probe record for `clock`
/// to `out`, followed by a newline, and returns the process exit code.
///
/// On failure a one-line diagnostic prefixed with `dot-sys: ` is written to
/// `err` and [`EXIT_FAILURE`] is returned. A failure to write the diagnostic
/// itself is ignored — there is nowhere left to report it.
///
/// The `main` binary calls this with `stdout`, `stderr` and
/// [`SystemTime::now`]; its output is byte-for-byte identical to the
/// historic `println!` implementation.
///
/// # Example
///
/// ```
/// use std::time::{Duration, UNIX_EPOCH};
/// use dot_sys::cli;
///
/// let mut out = Vec::new();
/// let code = cli::run(&mut out, &mut std::io::sink(), UNIX_EPOCH + Duration::from_secs(1_700_000_000));
/// assert_eq!(code, cli::EXIT_SUCCESS);
/// assert_eq!(
///     String::from_utf8(out).unwrap(),
///     "{\"status\": \"ok\", \"timestamp\": 1700000000, \"engine\": \"wasm\"}\n"
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::io;
    use std::time::{Duration, UNIX_EPOCH};

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
            out,
            b"{\"status\": \"ok\", \"timestamp\": 1700000000, \"engine\": \"wasm\"}\n"
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
}
