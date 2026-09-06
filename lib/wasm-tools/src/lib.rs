// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! `dot-sys` — the health-probe record emitted by the dotfiles framework's
//! Rust helper.
//!
//! The crate models exactly one JSON record:
//!
//! ```text
//! {"status": "ok", "timestamp": 1700000000, "engine": "wasm"}
//! ```
//!
//! [`Status`] holds the three fields, [`Status::to_json`] emits the record
//! byte-for-byte in the format the `dot-sys` binary has always printed, and
//! [`Status::parse`] is the strict inverse: it accepts only well-formed
//! records with the keys in that order, rejects everything else with a
//! byte-offset [`Error`], and round-trips every value `to_json` can produce.
//!
//! The binary itself is a thin wrapper over [`cli::run`] with the real
//! clock and standard streams plugged in.
//!
//! # Example
//!
//! ```
//! use dot_sys::Status;
//!
//! let probe = Status::at(1_700_000_000);
//! let json = probe.to_json();
//! assert_eq!(json, r#"{"status": "ok", "timestamp": 1700000000, "engine": "wasm"}"#);
//!
//! let parsed = Status::parse(&json)?;
//! assert_eq!(parsed, probe);
//! # Ok::<(), dot_sys::Error>(())
//! ```
//!
//! # Dependencies
//!
//! The crate is `std`-only. The record has three fixed fields, so a
//! hand-written emitter and a strict recursive-descent parser are smaller,
//! compile faster, and carry no supply chain compared with `serde` +
//! `serde_json`. Both halves are exhaustively unit-tested, fuzzed for
//! round-trip equality, and checked under Miri.

use std::fmt::{self, Write as _};
use std::str::FromStr;
use std::time::{SystemTime, UNIX_EPOCH};

pub mod cli;

/// The `status` value reported by a healthy probe.
pub const STATUS_OK: &str = "ok";

/// The `engine` value reported by this helper.
pub const ENGINE_WASM: &str = "wasm";

/// One health-probe record.
///
/// Fields are public because the type is plain data: there are no
/// invariants beyond "any string, any `u64`". Every value representable here
/// survives a [`to_json`](Status::to_json) → [`parse`](Status::parse)
/// round-trip, including control characters, quotes, backslashes and
/// astral-plane code points in the string fields.
///
/// # Example
///
/// ```
/// use dot_sys::{Status, ENGINE_WASM, STATUS_OK};
///
/// let s = Status::at(42);
/// assert_eq!(s.status, STATUS_OK);
/// assert_eq!(s.timestamp, 42);
/// assert_eq!(s.engine, ENGINE_WASM);
/// ```
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct Status {
    /// Health verdict; [`STATUS_OK`] for a healthy probe.
    pub status: String,
    /// Seconds since the Unix epoch at which the probe was taken.
    pub timestamp: u64,
    /// Execution engine that produced the record; [`ENGINE_WASM`] here.
    pub engine: String,
}

impl Status {
    /// Builds a record from explicit field values.
    ///
    /// # Example
    ///
    /// ```
    /// use dot_sys::Status;
    ///
    /// let s = Status::new("degraded", 7, "native");
    /// assert_eq!(s.to_json(), r#"{"status": "degraded", "timestamp": 7, "engine": "native"}"#);
    /// ```
    #[must_use]
    pub fn new(status: impl Into<String>, timestamp: u64, engine: impl Into<String>) -> Self {
        Self {
            status: status.into(),
            timestamp,
            engine: engine.into(),
        }
    }

    /// Builds a healthy (`"ok"` / `"wasm"`) record for the given Unix time.
    ///
    /// # Example
    ///
    /// ```
    /// use dot_sys::Status;
    ///
    /// assert_eq!(Status::at(0).to_json(), r#"{"status": "ok", "timestamp": 0, "engine": "wasm"}"#);
    /// ```
    #[must_use]
    pub fn at(timestamp: u64) -> Self {
        Self::new(STATUS_OK, timestamp, ENGINE_WASM)
    }

    /// Builds a healthy record for an arbitrary [`SystemTime`].
    ///
    /// Sub-second precision is truncated. Times before the Unix epoch are
    /// not representable and yield [`Error::ClockBeforeEpoch`].
    ///
    /// # Errors
    ///
    /// Returns [`Error::ClockBeforeEpoch`] if `time` precedes
    /// [`UNIX_EPOCH`].
    ///
    /// # Example
    ///
    /// ```
    /// use std::time::{Duration, UNIX_EPOCH};
    /// use dot_sys::{Error, Status};
    ///
    /// let t = UNIX_EPOCH + Duration::from_millis(1_500);
    /// assert_eq!(Status::from_system_time(t)?, Status::at(1));
    ///
    /// let before = UNIX_EPOCH - Duration::from_secs(1);
    /// assert_eq!(Status::from_system_time(before), Err(Error::ClockBeforeEpoch));
    /// # Ok::<(), Error>(())
    /// ```
    pub fn from_system_time(time: SystemTime) -> Result<Self, Error> {
        time.duration_since(UNIX_EPOCH)
            .map(|d| Self::at(d.as_secs()))
            .map_err(|_| Error::ClockBeforeEpoch)
    }

    /// Builds a healthy record for the current wall-clock time.
    ///
    /// # Errors
    ///
    /// Returns [`Error::ClockBeforeEpoch`] if the system clock is set before
    /// 1970-01-01T00:00:00Z.
    ///
    /// # Example
    ///
    /// ```
    /// use dot_sys::Status;
    ///
    /// let s = Status::now()?;
    /// assert_eq!(s.status, "ok");
    /// assert!(s.timestamp > 1_600_000_000);
    /// # Ok::<(), dot_sys::Error>(())
    /// ```
    pub fn now() -> Result<Self, Error> {
        Self::from_system_time(SystemTime::now())
    }

    /// Serialises the record in the exact format the `dot-sys` binary prints.
    ///
    /// The layout is fixed — one space after every `:` and `,`, keys in the
    /// order `status`, `timestamp`, `engine`, no trailing newline. String
    /// fields are JSON-escaped: `"`, `\`, and the C0 control characters are
    /// escaped (`\n`, `\t`, `\r`, `\b`, `\f`, or `\u00XX`); everything else
    /// is emitted as raw UTF-8.
    ///
    /// # Example
    ///
    /// ```
    /// use dot_sys::Status;
    ///
    /// let s = Status::new("o\"k", 1, "tab\there");
    /// assert_eq!(s.to_json(), r#"{"status": "o\"k", "timestamp": 1, "engine": "tab\there"}"#);
    /// ```
    #[must_use]
    pub fn to_json(&self) -> String {
        let mut out = String::with_capacity(64 + self.status.len() + self.engine.len());
        out.push_str(r#"{"status": "#);
        write_json_string(&mut out, &self.status);
        out.push_str(r#", "timestamp": "#);
        // Writing a u64 into a String cannot fail.
        let _ = write!(out, "{}", self.timestamp);
        out.push_str(r#", "engine": "#);
        write_json_string(&mut out, &self.engine);
        out.push('}');
        out
    }

    /// Parses a record produced by [`to_json`](Status::to_json).
    ///
    /// The grammar is deliberately strict:
    ///
    /// - exactly the three keys `status`, `timestamp`, `engine`, in that
    ///   order, each spelled literally (no escapes inside key names);
    /// - `timestamp` is a non-negative JSON integer with no sign, exponent,
    ///   fraction or leading zero, and must fit in a `u64`;
    /// - string values accept the full JSON escape set, including `\uXXXX`
    ///   surrogate pairs; raw control characters are rejected;
    /// - JSON whitespace (space, tab, CR, LF) is allowed between tokens, and
    ///   nothing but whitespace may follow the closing brace.
    ///
    /// Every error carries the byte offset into `input` where parsing
    /// stopped.
    ///
    /// # Errors
    ///
    /// Returns an [`Error`] describing the first violation of the grammar.
    ///
    /// # Example
    ///
    /// ```
    /// use dot_sys::{Error, Status};
    ///
    /// let s = Status::parse(" { \"status\": \"ok\", \"timestamp\": 5, \"engine\": \"wasm\" } ")?;
    /// assert_eq!(s, Status::at(5));
    ///
    /// assert_eq!(
    ///     Status::parse(r#"{"status": "ok", "timestamp": 05, "engine": "wasm"}"#),
    ///     Err(Error::Unexpected { offset: 31, expected: "no digit after a leading zero" }),
    /// );
    /// # Ok::<(), Error>(())
    /// ```
    pub fn parse(input: &str) -> Result<Self, Error> {
        let mut p = Parser { input, pos: 0 };
        p.skip_ws();
        p.expect(b'{', "'{'")?;
        p.skip_ws();
        p.expect_literal("\"status\"")?;
        p.skip_ws();
        p.expect(b':', "':'")?;
        p.skip_ws();
        let status = p.parse_string()?;
        p.skip_ws();
        p.expect(b',', "','")?;
        p.skip_ws();
        p.expect_literal("\"timestamp\"")?;
        p.skip_ws();
        p.expect(b':', "':'")?;
        p.skip_ws();
        let timestamp = p.parse_u64()?;
        p.skip_ws();
        p.expect(b',', "','")?;
        p.skip_ws();
        p.expect_literal("\"engine\"")?;
        p.skip_ws();
        p.expect(b':', "':'")?;
        p.skip_ws();
        let engine = p.parse_string()?;
        p.skip_ws();
        p.expect(b'}', "'}'")?;
        p.skip_ws();
        if p.pos < input.len() {
            return Err(Error::TrailingInput { offset: p.pos });
        }
        Ok(Self {
            status,
            timestamp,
            engine,
        })
    }
}

/// Formats the record exactly as [`Status::to_json`] does.
///
/// # Example
///
/// ```
/// use dot_sys::Status;
///
/// let s = Status::at(3);
/// assert_eq!(s.to_string(), s.to_json());
/// ```
impl fmt::Display for Status {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.to_json())
    }
}

/// Parses with [`Status::parse`], so `"...".parse::<Status>()` works.
///
/// # Example
///
/// ```
/// use dot_sys::Status;
///
/// let s: Status = r#"{"status": "ok", "timestamp": 9, "engine": "wasm"}"#.parse()?;
/// assert_eq!(s, Status::at(9));
/// # Ok::<(), dot_sys::Error>(())
/// ```
impl FromStr for Status {
    type Err = Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Self::parse(s)
    }
}

/// Everything that can go wrong in this crate.
///
/// All parse variants carry a byte `offset` into the input at which the
/// problem was detected, so callers can point at it.
///
/// # Example
///
/// ```
/// use dot_sys::{Error, Status};
///
/// let err = Status::parse("{").unwrap_err();
/// assert_eq!(err, Error::UnexpectedEnd);
/// assert_eq!(err.to_string(), "unexpected end of input");
/// ```
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum Error {
    /// The clock reported a time before the Unix epoch.
    ClockBeforeEpoch,
    /// The input ended before the record was complete.
    UnexpectedEnd,
    /// A token other than `expected` was found at `offset`.
    Unexpected {
        /// Byte offset of the offending character.
        offset: usize,
        /// Human-readable description of what the grammar wanted.
        expected: &'static str,
    },
    /// The `timestamp` integer starting at `offset` does not fit in a `u64`.
    NumberOverflow {
        /// Byte offset of the first digit.
        offset: usize,
    },
    /// The backslash at `offset` starts an escape the grammar does not know.
    InvalidEscape {
        /// Byte offset of the backslash.
        offset: usize,
    },
    /// The `\u` escape at `offset` is malformed or encodes an invalid
    /// surrogate sequence.
    InvalidUnicodeEscape {
        /// Byte offset of the backslash.
        offset: usize,
    },
    /// Non-whitespace input follows the closing brace, starting at `offset`.
    TrailingInput {
        /// Byte offset of the first trailing character.
        offset: usize,
    },
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::ClockBeforeEpoch => f.write_str("system clock is before the Unix epoch"),
            Self::UnexpectedEnd => f.write_str("unexpected end of input"),
            Self::Unexpected { offset, expected } => {
                write!(f, "expected {expected} at byte {offset}")
            }
            Self::NumberOverflow { offset } => {
                write!(f, "timestamp at byte {offset} does not fit in a u64")
            }
            Self::InvalidEscape { offset } => write!(f, "invalid escape sequence at byte {offset}"),
            Self::InvalidUnicodeEscape { offset } => {
                write!(f, "invalid \\u escape at byte {offset}")
            }
            Self::TrailingInput { offset } => {
                write!(f, "unexpected trailing input at byte {offset}")
            }
        }
    }
}

impl std::error::Error for Error {}

/// Appends `s` to `out` as a JSON string literal, quotes included.
fn write_json_string(out: &mut String, s: &str) {
    out.push('"');
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            '\u{08}' => out.push_str("\\b"),
            '\u{0C}' => out.push_str("\\f"),
            c if c < ' ' => {
                // Writing into a String cannot fail.
                let _ = write!(out, "\\u{:04x}", u32::from(c));
            }
            c => out.push(c),
        }
    }
    out.push('"');
}

/// Minimal recursive-descent cursor over the input bytes.
struct Parser<'a> {
    input: &'a str,
    pos: usize,
}

impl Parser<'_> {
    fn peek(&self) -> Option<u8> {
        self.input.as_bytes().get(self.pos).copied()
    }

    fn skip_ws(&mut self) {
        while matches!(self.peek(), Some(b' ' | b'\t' | b'\n' | b'\r')) {
            self.pos += 1;
        }
    }

    /// Consumes exactly `byte`, or fails describing `expected`.
    fn expect(&mut self, byte: u8, expected: &'static str) -> Result<(), Error> {
        match self.peek() {
            None => Err(Error::UnexpectedEnd),
            Some(b) if b == byte => {
                self.pos += 1;
                Ok(())
            }
            Some(_) => Err(Error::Unexpected {
                offset: self.pos,
                expected,
            }),
        }
    }

    /// Consumes `literal` byte for byte; the error points at the first
    /// mismatching byte and names the whole literal.
    fn expect_literal(&mut self, literal: &'static str) -> Result<(), Error> {
        for &b in literal.as_bytes() {
            self.expect(b, literal)?;
        }
        Ok(())
    }

    /// Parses a strict JSON non-negative integer into a `u64`.
    fn parse_u64(&mut self) -> Result<u64, Error> {
        let start = self.pos;
        let first = match self.peek() {
            None => return Err(Error::UnexpectedEnd),
            Some(b @ b'0'..=b'9') => b,
            Some(_) => {
                return Err(Error::Unexpected {
                    offset: start,
                    expected: "a digit",
                })
            }
        };
        self.pos += 1;
        if first == b'0' {
            return match self.peek() {
                Some(b'0'..=b'9') => Err(Error::Unexpected {
                    offset: self.pos,
                    expected: "no digit after a leading zero",
                }),
                _ => Ok(0),
            };
        }
        let mut value = u64::from(first - b'0');
        while let Some(b @ b'0'..=b'9') = self.peek() {
            value = value
                .checked_mul(10)
                .and_then(|v| v.checked_add(u64::from(b - b'0')))
                .ok_or(Error::NumberOverflow { offset: start })?;
            self.pos += 1;
        }
        Ok(value)
    }

    /// Parses a JSON string literal, decoding escapes.
    fn parse_string(&mut self) -> Result<String, Error> {
        self.expect(b'"', "'\"'")?;
        let mut out = String::new();
        loop {
            let Some(c) = self.input[self.pos..].chars().next() else {
                return Err(Error::UnexpectedEnd);
            };
            match c {
                '"' => {
                    self.pos += 1;
                    return Ok(out);
                }
                '\\' => {
                    let decoded = self.parse_escape()?;
                    out.push(decoded);
                }
                c if c < ' ' => {
                    return Err(Error::Unexpected {
                        offset: self.pos,
                        expected: "an escaped control character",
                    })
                }
                c => {
                    self.pos += c.len_utf8();
                    out.push(c);
                }
            }
        }
    }

    /// Parses one escape sequence; `self.pos` is on the backslash.
    fn parse_escape(&mut self) -> Result<char, Error> {
        let start = self.pos;
        self.pos += 1;
        let Some(tag) = self.peek() else {
            return Err(Error::UnexpectedEnd);
        };
        self.pos += 1;
        let decoded = match tag {
            b'"' => '"',
            b'\\' => '\\',
            b'/' => '/',
            b'b' => '\u{08}',
            b'f' => '\u{0C}',
            b'n' => '\n',
            b'r' => '\r',
            b't' => '\t',
            b'u' => return self.parse_unicode_escape(start),
            _ => return Err(Error::InvalidEscape { offset: start }),
        };
        Ok(decoded)
    }

    /// Parses the `XXXX` (and, for a high surrogate, the following
    /// `\uYYYY`) of a `\u` escape; `self.pos` is just past the `u`.
    fn parse_unicode_escape(&mut self, start: usize) -> Result<char, Error> {
        let mut units = [self.parse_hex4()?, 0];
        let mut len = 1;
        if (0xD800..=0xDBFF).contains(&units[0]) {
            // A high surrogate is only meaningful as the first half of a
            // `\uXXXX\uYYYY` pair, so the next two bytes must be `\u`.
            let Some(next) = self.input.as_bytes().get(self.pos..self.pos + 2) else {
                return Err(Error::UnexpectedEnd);
            };
            if next != b"\\u" {
                return Err(Error::InvalidUnicodeEscape { offset: start });
            }
            self.pos += 2;
            units[1] = self.parse_hex4()?;
            len = 2;
        }
        // `decode_utf16` rejects lone or mismatched surrogates for us.
        char::decode_utf16(units[..len].iter().copied())
            .next()
            .and_then(Result::ok)
            .ok_or(Error::InvalidUnicodeEscape { offset: start })
    }

    /// Reads exactly four hex digits at `self.pos`; the error offset points
    /// at the first byte that is not a hex digit.
    fn parse_hex4(&mut self) -> Result<u16, Error> {
        let Some(digits) = self.input.as_bytes().get(self.pos..self.pos + 4) else {
            return Err(Error::UnexpectedEnd);
        };
        let mut value = 0u16;
        for (i, &d) in digits.iter().enumerate() {
            let nibble = match d {
                b'0'..=b'9' => d - b'0',
                b'a'..=b'f' => d - b'a' + 10,
                b'A'..=b'F' => d - b'A' + 10,
                _ => {
                    return Err(Error::InvalidUnicodeEscape {
                        offset: self.pos + i,
                    })
                }
            };
            value = (value << 4) | u16::from(nibble);
        }
        self.pos += 4;
        Ok(value)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;
    use std::time::Duration;

    const CANONICAL: &str = r#"{"status": "ok", "timestamp": 1700000000, "engine": "wasm"}"#;

    #[test]
    fn at_uses_constants() {
        let s = Status::at(1_700_000_000);
        assert_eq!(s.status, STATUS_OK);
        assert_eq!(s.engine, ENGINE_WASM);
        assert_eq!(s.timestamp, 1_700_000_000);
    }

    #[test]
    fn new_accepts_string_and_str() {
        let a = Status::new("a", 1, String::from("b"));
        let b = Status::new(String::from("a"), 1, "b");
        assert_eq!(a, b);
    }

    #[test]
    fn to_json_matches_historic_binary_format() {
        assert_eq!(Status::at(1_700_000_000).to_json(), CANONICAL);
        assert_eq!(
            Status::at(0).to_json(),
            r#"{"status": "ok", "timestamp": 0, "engine": "wasm"}"#
        );
        assert_eq!(
            Status::at(u64::MAX).to_json(),
            r#"{"status": "ok", "timestamp": 18446744073709551615, "engine": "wasm"}"#
        );
    }

    #[test]
    fn display_equals_to_json() {
        let s = Status::new("x\"y", 5, "\u{1F980}");
        assert_eq!(s.to_string(), s.to_json());
        assert_eq!(format!("{s}"), s.to_json());
    }

    #[test]
    fn to_json_escapes_every_special_character() {
        let s = Status::new("\"\\\n\r\t\u{08}\u{0C}\u{01}\u{1F}/", 0, "é\u{1F980}");
        assert_eq!(
            s.to_json(),
            "{\"status\": \"\\\"\\\\\\n\\r\\t\\b\\f\\u0001\\u001f/\", \"timestamp\": 0, \"engine\": \"é\u{1F980}\"}"
        );
    }

    #[test]
    fn from_system_time_truncates_and_rejects_pre_epoch() {
        assert_eq!(Status::from_system_time(UNIX_EPOCH), Ok(Status::at(0)));
        assert_eq!(
            Status::from_system_time(UNIX_EPOCH + Duration::from_millis(2_999)),
            Ok(Status::at(2))
        );
        assert_eq!(
            Status::from_system_time(UNIX_EPOCH - Duration::from_nanos(1)),
            Err(Error::ClockBeforeEpoch)
        );
    }

    #[test]
    fn now_is_after_2020() {
        let s = Status::now().expect("clock after epoch");
        assert!(s.timestamp > 1_577_836_800);
        assert_eq!(s.status, STATUS_OK);
    }

    #[test]
    fn parse_canonical() {
        assert_eq!(Status::parse(CANONICAL), Ok(Status::at(1_700_000_000)));
    }

    #[test]
    fn parse_via_from_str() {
        let s: Status = CANONICAL.parse().expect("valid");
        assert_eq!(s, Status::at(1_700_000_000));
        assert_eq!("".parse::<Status>(), Err(Error::UnexpectedEnd));
    }

    #[test]
    fn parse_tolerates_json_whitespace() {
        let spaced =
            " \t\r\n{ \"status\"\t:\n\"ok\" , \"timestamp\" : 7 , \"engine\" : \"wasm\" }\n";
        assert_eq!(Status::parse(spaced), Ok(Status::at(7)));
        let tight = r#"{"status":"ok","timestamp":7,"engine":"wasm"}"#;
        assert_eq!(Status::parse(tight), Ok(Status::at(7)));
    }

    #[test]
    fn parse_zero_and_max() {
        assert_eq!(
            Status::parse(r#"{"status": "ok", "timestamp": 0, "engine": "wasm"}"#),
            Ok(Status::at(0))
        );
        assert_eq!(
            Status::parse(
                r#"{"status": "ok", "timestamp": 18446744073709551615, "engine": "wasm"}"#
            ),
            Ok(Status::at(u64::MAX))
        );
    }

    #[test]
    fn parse_number_errors() {
        let overflow = r#"{"status": "ok", "timestamp": 18446744073709551616, "engine": "wasm"}"#;
        assert_eq!(
            Status::parse(overflow),
            Err(Error::NumberOverflow { offset: 30 })
        );
        let leading_zero = r#"{"status": "ok", "timestamp": 01, "engine": "wasm"}"#;
        assert_eq!(
            Status::parse(leading_zero),
            Err(Error::Unexpected {
                offset: 31,
                expected: "no digit after a leading zero"
            })
        );
        let negative = r#"{"status": "ok", "timestamp": -1, "engine": "wasm"}"#;
        assert_eq!(
            Status::parse(negative),
            Err(Error::Unexpected {
                offset: 30,
                expected: "a digit"
            })
        );
        let float = r#"{"status": "ok", "timestamp": 1.5, "engine": "wasm"}"#;
        assert_eq!(
            Status::parse(float),
            Err(Error::Unexpected {
                offset: 31,
                expected: "','"
            })
        );
        assert_eq!(
            Status::parse(r#"{"status": "ok", "timestamp": "#),
            Err(Error::UnexpectedEnd)
        );
    }

    #[test]
    fn parse_structural_errors() {
        assert_eq!(Status::parse(""), Err(Error::UnexpectedEnd));
        assert_eq!(Status::parse("   "), Err(Error::UnexpectedEnd));
        assert_eq!(
            Status::parse("["),
            Err(Error::Unexpected {
                offset: 0,
                expected: "'{'"
            })
        );
        assert_eq!(
            Status::parse(r#"{"state": "ok"}"#),
            Err(Error::Unexpected {
                offset: 6,
                expected: "\"status\""
            })
        );
        assert_eq!(Status::parse(r#"{"stat"#), Err(Error::UnexpectedEnd));
        assert_eq!(
            Status::parse(r#"{"status" "ok"}"#),
            Err(Error::Unexpected {
                offset: 10,
                expected: "':'"
            })
        );
        assert_eq!(
            Status::parse(r#"{"status": "ok"; "timestamp": 1, "engine": "wasm"}"#),
            Err(Error::Unexpected {
                offset: 15,
                expected: "','"
            })
        );
        assert_eq!(
            Status::parse(r#"{"status": "ok", "engine": "wasm", "timestamp": 1}"#),
            Err(Error::Unexpected {
                offset: 18,
                expected: "\"timestamp\""
            })
        );
        assert_eq!(
            Status::parse(r#"{"status": "ok", "timestamp": 1, "engine": "wasm", "extra": 1}"#),
            Err(Error::Unexpected {
                offset: 49,
                expected: "'}'"
            })
        );
        assert_eq!(
            Status::parse(r#"{"status": "ok", "timestamp": 1, "engine": "wasm"} x"#),
            Err(Error::TrailingInput { offset: 51 })
        );
        assert_eq!(
            Status::parse(r#"{"status": ok, "timestamp": 1, "engine": "wasm"}"#),
            Err(Error::Unexpected {
                offset: 11,
                expected: "'\"'"
            })
        );
    }

    #[test]
    fn parse_errors_after_each_key() {
        // Every `?` in `parse` has its own failure case so no error arm is
        // dead: this covers the separators around `timestamp` and `engine`.
        let expected = |offset, expected| Err(Error::Unexpected { offset, expected });
        assert_eq!(
            Status::parse(r#"{"status": "ok", "timestamp" 1}"#),
            expected(29, "':'")
        );
        assert_eq!(
            Status::parse(r#"{"status": "ok", "timestamp": 1, "motor": "x"}"#),
            expected(34, "\"engine\"")
        );
        assert_eq!(
            Status::parse(r#"{"status": "ok", "timestamp": 1, "engine" "x"}"#),
            expected(42, "':'")
        );
        assert_eq!(
            Status::parse(r#"{"status": "ok", "timestamp": 1, "engine": wasm}"#),
            expected(43, "'\"'")
        );
        assert_eq!(
            Status::parse(r#"{"status": "ok", "timestamp": 1, "engine": "\z"}"#),
            Err(Error::InvalidEscape { offset: 44 })
        );
        assert_eq!(
            Status::parse(r#"{"status": "ok", "timestamp": 1, "engine": "#),
            Err(Error::UnexpectedEnd)
        );
    }

    #[test]
    fn parse_string_escapes() {
        let input = r#"{"status": "\"\\\/\b\f\n\r\t\u0041\u00e9\ud83e\udd80", "timestamp": 1, "engine": "\u001F"}"#;
        assert_eq!(
            Status::parse(input),
            Ok(Status::new(
                "\"\\/\u{08}\u{0C}\n\r\tAé\u{1F980}",
                1,
                "\u{1F}"
            ))
        );
        let raw_unicode = r#"{"status": "héllo 🦀", "timestamp": 1, "engine": "wasm"}"#;
        assert_eq!(
            Status::parse(raw_unicode),
            Ok(Status::new("héllo 🦀", 1, "wasm"))
        );
    }

    #[test]
    fn parse_string_errors() {
        assert_eq!(
            Status::parse(r#"{"status": "unterminated"#),
            Err(Error::UnexpectedEnd)
        );
        assert_eq!(
            Status::parse("{\"status\": \"\\"),
            Err(Error::UnexpectedEnd)
        );
        assert_eq!(
            Status::parse(r#"{"status": "\x""#),
            Err(Error::InvalidEscape { offset: 12 })
        );
        assert_eq!(
            Status::parse("{\"status\": \"a\nb\""),
            Err(Error::Unexpected {
                offset: 13,
                expected: "an escaped control character"
            })
        );
    }

    #[test]
    fn parse_unicode_escape_errors() {
        // Too short.
        assert_eq!(
            Status::parse(r#"{"status": "\u12"#),
            Err(Error::UnexpectedEnd)
        );
        // Bad hex digit (first, second and fourth positions).
        assert_eq!(
            Status::parse(r#"{"status": "\uZ000""#),
            Err(Error::InvalidUnicodeEscape { offset: 14 })
        );
        assert_eq!(
            Status::parse(r#"{"status": "\u0G00""#),
            Err(Error::InvalidUnicodeEscape { offset: 15 })
        );
        assert_eq!(
            Status::parse(r#"{"status": "\u000g""#),
            Err(Error::InvalidUnicodeEscape { offset: 17 })
        );
        // Lone low surrogate.
        assert_eq!(
            Status::parse(r#"{"status": "\udc00""#),
            Err(Error::InvalidUnicodeEscape { offset: 12 })
        );
        // High surrogate at end of input / not followed by an escape / followed
        // by a non-surrogate / followed by a truncated escape.
        assert_eq!(
            Status::parse(r#"{"status": "\ud83e"#),
            Err(Error::UnexpectedEnd)
        );
        assert_eq!(
            Status::parse(r#"{"status": "\ud83e""#),
            Err(Error::UnexpectedEnd)
        );
        assert_eq!(
            Status::parse(r#"{"status": "\ud83eab""#),
            Err(Error::InvalidUnicodeEscape { offset: 12 })
        );
        assert_eq!(
            Status::parse(r#"{"status": "\ud83e\n""#),
            Err(Error::InvalidUnicodeEscape { offset: 12 })
        );
        assert_eq!(
            Status::parse(r#"{"status": "\ud83e\u0041""#),
            Err(Error::InvalidUnicodeEscape { offset: 12 })
        );
        assert_eq!(
            Status::parse(r#"{"status": "\ud83e\u00"#),
            Err(Error::UnexpectedEnd)
        );
        assert_eq!(
            Status::parse(r#"{"status": "\ud83e\uXXXX""#),
            Err(Error::InvalidUnicodeEscape { offset: 20 })
        );
    }

    #[test]
    fn round_trip_preserves_every_field() {
        let cases = [
            Status::at(0),
            Status::at(u64::MAX),
            Status::new("", 1, ""),
            Status::new(
                "\"\\/\u{08}\u{0C}\n\r\t\u{00}\u{1F}",
                2,
                "é\u{1F980}\u{FFFF}\u{10FFFF}",
            ),
            Status::new("plain ascii", 3, "with spaces  and\ttabs"),
        ];
        for case in cases {
            let json = case.to_json();
            assert_eq!(Status::parse(&json), Ok(case.clone()), "json: {json}");
            assert_eq!(json.parse::<Status>(), Ok(case));
        }
    }

    #[test]
    fn error_display_messages() {
        let cases: [(Error, &str); 7] = [
            (
                Error::ClockBeforeEpoch,
                "system clock is before the Unix epoch",
            ),
            (Error::UnexpectedEnd, "unexpected end of input"),
            (
                Error::Unexpected {
                    offset: 3,
                    expected: "'{'",
                },
                "expected '{' at byte 3",
            ),
            (
                Error::NumberOverflow { offset: 4 },
                "timestamp at byte 4 does not fit in a u64",
            ),
            (
                Error::InvalidEscape { offset: 5 },
                "invalid escape sequence at byte 5",
            ),
            (
                Error::InvalidUnicodeEscape { offset: 6 },
                "invalid \\u escape at byte 6",
            ),
            (
                Error::TrailingInput { offset: 7 },
                "unexpected trailing input at byte 7",
            ),
        ];
        for (err, msg) in cases {
            assert_eq!(err.to_string(), msg);
            let boxed: Box<dyn std::error::Error> = Box::new(err);
            assert_eq!(boxed.to_string(), msg);
        }
    }

    #[test]
    fn derived_traits_behave() {
        let a = Status::at(1);
        let b = a.clone();
        assert_eq!(a, b);
        assert_ne!(a, Status::at(2));
        let set: HashSet<Status> = [a.clone(), b, Status::at(2)].into_iter().collect();
        assert_eq!(set.len(), 2);
        assert!(format!("{a:?}").contains("timestamp: 1"));

        let e = Error::TrailingInput { offset: 1 };
        let errs: HashSet<Error> = [e, e, Error::UnexpectedEnd].into_iter().collect();
        assert_eq!(errs.len(), 2);
        assert!(format!("{e:?}").contains("TrailingInput"));
    }
}
