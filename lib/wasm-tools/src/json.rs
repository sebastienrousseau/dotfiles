// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! A small, allocation-light JSON reader used to inspect documents this
//! crate did not produce.
//!
//! [`Status`](crate::Status) has its own byte-exact grammar; this module is
//! the general half, and exists because the `dot attest` evidence record is
//! an arbitrary JSON document that has to be read *inside the sandbox*. A
//! verifier that asked its host to pre-extract fields with `jq` would move
//! the trust straight back out to the host, which is the thing being
//! avoided.
//!
//! The reader never builds a tree. [`validate`] walks a document once to
//! prove it is well-formed JSON; [`get`] walks it following a dotted path,
//! skipping every value it does not need. Nesting is handled with an
//! explicit stack rather than recursion and is capped at [`MAX_DEPTH`], so a
//! hostile document cannot exhaust the call stack.
//!
//! # Example
//!
//! ```
//! use dot_sys::json;
//!
//! let doc = r#"{"platform": {"host_os": "darwin", "cores": 12}, "ok": true}"#;
//! json::validate(doc)?;
//!
//! assert_eq!(json::get(doc, "platform.host_os")?.as_str()?, "darwin");
//! assert_eq!(json::get(doc, "platform.cores")?.as_u64()?, 12);
//! assert!(json::get(doc, "ok")?.as_bool()?);
//! # Ok::<(), dot_sys::Error>(())
//! ```

use crate::Error;

/// Deepest object/array nesting the reader accepts.
///
/// The evidence records this crate reads nest four levels; the cap is a
/// safety valve against hostile input, not a working limit.
pub const MAX_DEPTH: usize = 64;

/// The JSON type of a [`Value`].
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Kind {
    /// `null`.
    Null,
    /// `true` or `false`.
    Bool,
    /// Any JSON number.
    Number,
    /// A quoted string.
    String,
    /// A `[...]` array.
    Array,
    /// A `{...}` object.
    Object,
}

impl Kind {
    /// The name this kind is given in error messages.
    ///
    /// # Example
    ///
    /// ```
    /// use dot_sys::json::Kind;
    ///
    /// assert_eq!(Kind::Object.name(), "an object");
    /// ```
    #[must_use]
    pub const fn name(self) -> &'static str {
        match self {
            Self::Null => "null",
            Self::Bool => "a boolean",
            Self::Number => "a number",
            Self::String => "a string",
            Self::Array => "an array",
            Self::Object => "an object",
        }
    }
}

/// One JSON value, borrowed from the document it was read out of.
///
/// A `Value` is a validated span: the bytes from [`offset`](Value::offset)
/// to the end of [`text`](Value::text) are known to be one well-formed JSON
/// value of [`kind`](Value::kind). Decoding it into a Rust value is done on
/// demand by the `as_*` methods.
///
/// # Example
///
/// ```
/// use dot_sys::json::{self, Kind};
///
/// let v = json::get(r#"{"a": [1, 2]}"#, "a")?;
/// assert_eq!(v.kind(), Kind::Array);
/// assert_eq!(v.text(), "[1, 2]");
/// assert_eq!(v.offset(), 6);
/// # Ok::<(), dot_sys::Error>(())
/// ```
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Value<'a> {
    input: &'a str,
    start: usize,
    end: usize,
    kind: Kind,
}

impl<'a> Value<'a> {
    /// The JSON type of this value.
    #[must_use]
    pub const fn kind(self) -> Kind {
        self.kind
    }

    /// The byte offset of this value in the document it came from.
    #[must_use]
    pub const fn offset(self) -> usize {
        self.start
    }

    /// The raw JSON text of this value, escapes and all.
    #[must_use]
    pub fn text(self) -> &'a str {
        &self.input[self.start..self.end]
    }

    /// Whether this value is JSON `null`.
    #[must_use]
    pub fn is_null(self) -> bool {
        self.kind == Kind::Null
    }

    /// Decodes a string value, resolving every escape.
    ///
    /// # Errors
    ///
    /// Returns [`Error::Unexpected`] if the value is not a string.
    ///
    /// # Example
    ///
    /// ```
    /// use dot_sys::json;
    ///
    /// assert_eq!(json::get(r#"{"k": "a\nb"}"#, "k")?.as_str()?, "a\nb");
    /// # Ok::<(), dot_sys::Error>(())
    /// ```
    pub fn as_str(self) -> Result<String, Error> {
        self.expect_kind(Kind::String)?;
        Scanner::at(self.input, self.start).parse_string()
    }

    /// Reads a number value as a `u64`.
    ///
    /// The number must be a non-negative integer with no sign, fraction or
    /// exponent — the same grammar
    /// [`Status::parse`](crate::Status::parse) accepts for `timestamp`.
    ///
    /// # Errors
    ///
    /// Returns [`Error::Unexpected`] if the value is not a number or not a
    /// plain non-negative integer, and [`Error::NumberOverflow`] if it does
    /// not fit in a `u64`.
    ///
    /// # Example
    ///
    /// ```
    /// use dot_sys::json;
    ///
    /// assert_eq!(json::get(r#"{"k": 7}"#, "k")?.as_u64()?, 7);
    /// assert!(json::get(r#"{"k": 7.5}"#, "k")?.as_u64().is_err());
    /// # Ok::<(), dot_sys::Error>(())
    /// ```
    pub fn as_u64(self) -> Result<u64, Error> {
        self.expect_kind(Kind::Number)?;
        let mut s = Scanner::at(self.input, self.start);
        let value = s.parse_u64()?;
        if s.pos == self.end {
            Ok(value)
        } else {
            Err(Error::Unexpected {
                offset: s.pos,
                expected: "a plain non-negative integer",
            })
        }
    }

    /// Reads a boolean value.
    ///
    /// # Errors
    ///
    /// Returns [`Error::Unexpected`] if the value is not `true` or `false`.
    ///
    /// # Example
    ///
    /// ```
    /// use dot_sys::json;
    ///
    /// assert!(!json::get(r#"{"k": false}"#, "k")?.as_bool()?);
    /// # Ok::<(), dot_sys::Error>(())
    /// ```
    pub fn as_bool(self) -> Result<bool, Error> {
        self.expect_kind(Kind::Bool)?;
        Ok(self.text() == "true")
    }

    fn expect_kind(self, kind: Kind) -> Result<(), Error> {
        if self.kind == kind {
            Ok(())
        } else {
            Err(Error::Unexpected {
                offset: self.start,
                expected: kind.name(),
            })
        }
    }
}

/// Checks that `input` is exactly one well-formed JSON value.
///
/// Leading and trailing JSON whitespace is allowed; anything else after the
/// value is rejected.
///
/// # Errors
///
/// Returns the first [`Error`] in the document, carrying the byte offset at
/// which scanning stopped.
///
/// # Example
///
/// ```
/// use dot_sys::{json, Error};
///
/// json::validate(r#"  {"a": [1, null, true]}  "#)?;
/// assert_eq!(json::validate("{} {}"), Err(Error::TrailingInput { offset: 3 }));
/// # Ok::<(), Error>(())
/// ```
pub fn validate(input: &str) -> Result<(), Error> {
    let mut s = Scanner::at(input, 0);
    s.scan_value()?;
    s.skip_ws();
    if s.pos < input.len() {
        return Err(Error::TrailingInput { offset: s.pos });
    }
    Ok(())
}

/// Reads the value at a dotted `path` out of `input`.
///
/// An empty path selects the document root. Any other path is a sequence of
/// object member names separated by `.`; a member whose name contains a
/// literal dot is not addressable, which the records this crate reads never
/// need.
///
/// `get` stops as soon as it has the value it was asked for, so it only
/// proves that the *path* is well-formed — call [`validate`] first if the
/// whole document has to be sound, which is what
/// [`attest::Report::verify`](crate::attest::Report::verify) does.
///
/// # Errors
///
/// Returns [`Error::MissingMember`] if a segment is absent,
/// [`Error::Unexpected`] if a segment names a member of something that is
/// not an object, and any other [`Error`] variant if the document is
/// malformed along the way.
///
/// # Example
///
/// ```
/// use dot_sys::{json, Error};
///
/// let doc = r#"{"git_signing": {"format": "ssh"}}"#;
/// assert_eq!(json::get(doc, "git_signing.format")?.as_str()?, "ssh");
/// assert_eq!(json::get(doc, "")?.kind(), json::Kind::Object);
/// assert_eq!(
///     json::get(doc, "git_signing.key"),
///     Err(Error::MissingMember { path: "git_signing.key" }),
/// );
/// # Ok::<(), Error>(())
/// ```
pub fn get<'a>(input: &'a str, path: &'static str) -> Result<Value<'a>, Error> {
    let mut s = Scanner::at(input, 0);
    for segment in path.split('.').filter(|s| !s.is_empty()) {
        if !s.seek_member(segment)? {
            return Err(Error::MissingMember { path });
        }
    }
    s.scan_value()
}

/// Which kind of container the scanner is currently inside.
#[derive(Clone, Copy, PartialEq, Eq)]
enum Frame {
    Object,
    Array,
}

/// Minimal cursor over the input bytes, shared by the fixed record grammar
/// in [`crate`] and the general reader in this module.
pub(crate) struct Scanner<'a> {
    input: &'a str,
    pub(crate) pos: usize,
}

impl<'a> Scanner<'a> {
    /// A scanner positioned at byte `pos` of `input`.
    pub(crate) const fn at(input: &'a str, pos: usize) -> Self {
        Self { input, pos }
    }

    fn peek(&self) -> Option<u8> {
        self.input.as_bytes().get(self.pos).copied()
    }

    pub(crate) fn skip_ws(&mut self) {
        while matches!(self.peek(), Some(b' ' | b'\t' | b'\n' | b'\r')) {
            self.pos += 1;
        }
    }

    /// Consumes exactly `byte`, or fails describing `expected`.
    pub(crate) fn expect(&mut self, byte: u8, expected: &'static str) -> Result<(), Error> {
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
    pub(crate) fn expect_literal(&mut self, literal: &'static str) -> Result<(), Error> {
        for &b in literal.as_bytes() {
            self.expect(b, literal)?;
        }
        Ok(())
    }

    /// Parses a strict JSON non-negative integer into a `u64`.
    pub(crate) fn parse_u64(&mut self) -> Result<u64, Error> {
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
    pub(crate) fn parse_string(&mut self) -> Result<String, Error> {
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

    /// Consumes one JSON number, checking the full grammar.
    fn scan_number(&mut self) -> Result<(), Error> {
        if self.peek() == Some(b'-') {
            self.pos += 1;
        }
        match self.peek() {
            None => return Err(Error::UnexpectedEnd),
            Some(b'0') => self.pos += 1,
            Some(b'1'..=b'9') => {
                while matches!(self.peek(), Some(b'0'..=b'9')) {
                    self.pos += 1;
                }
            }
            Some(_) => {
                return Err(Error::Unexpected {
                    offset: self.pos,
                    expected: "a digit",
                })
            }
        }
        if self.peek() == Some(b'.') {
            self.pos += 1;
            self.scan_digits()?;
        }
        if matches!(self.peek(), Some(b'e' | b'E')) {
            self.pos += 1;
            if matches!(self.peek(), Some(b'+' | b'-')) {
                self.pos += 1;
            }
            self.scan_digits()?;
        }
        Ok(())
    }

    /// Consumes one or more decimal digits.
    fn scan_digits(&mut self) -> Result<(), Error> {
        match self.peek() {
            None => Err(Error::UnexpectedEnd),
            Some(b'0'..=b'9') => {
                while matches!(self.peek(), Some(b'0'..=b'9')) {
                    self.pos += 1;
                }
                Ok(())
            }
            Some(_) => Err(Error::Unexpected {
                offset: self.pos,
                expected: "a digit",
            }),
        }
    }

    /// Positions the scanner on the value of the member called `name`.
    ///
    /// Returns `false` — with the scanner left somewhere inside the object
    /// — when there is no such member. Values of other members are scanned
    /// and discarded on the way past, so a malformed sibling before the
    /// wanted key is still reported.
    fn seek_member(&mut self, name: &str) -> Result<bool, Error> {
        self.skip_ws();
        match self.peek() {
            None => return Err(Error::UnexpectedEnd),
            Some(b'{') => self.pos += 1,
            Some(_) => {
                return Err(Error::Unexpected {
                    offset: self.pos,
                    expected: Kind::Object.name(),
                })
            }
        }
        loop {
            self.skip_ws();
            if self.peek() == Some(b'}') {
                return Ok(false);
            }
            let key = self.parse_string()?;
            self.skip_ws();
            self.expect(b':', "':'")?;
            if key == name {
                return Ok(true);
            }
            self.scan_value()?;
            self.skip_ws();
            match self.peek() {
                Some(b',') => self.pos += 1,
                Some(b'}') => return Ok(false),
                None => return Err(Error::UnexpectedEnd),
                Some(_) => {
                    return Err(Error::Unexpected {
                        offset: self.pos,
                        expected: "',' or '}'",
                    })
                }
            }
        }
    }

    /// Consumes one complete JSON value and returns its span.
    ///
    /// Containers are walked with an explicit stack rather than recursion,
    /// so depth costs heap instead of call frames and is capped at
    /// [`MAX_DEPTH`].
    pub(crate) fn scan_value(&mut self) -> Result<Value<'a>, Error> {
        self.skip_ws();
        let start = self.pos;
        let kind = match self.peek() {
            None => return Err(Error::UnexpectedEnd),
            Some(b'{') => Kind::Object,
            Some(b'[') => Kind::Array,
            Some(b'"') => Kind::String,
            Some(b't' | b'f') => Kind::Bool,
            Some(b'n') => Kind::Null,
            Some(b'-' | b'0'..=b'9') => Kind::Number,
            Some(_) => {
                return Err(Error::Unexpected {
                    offset: start,
                    expected: "a JSON value",
                })
            }
        };

        let mut stack: Vec<Frame> = Vec::new();
        loop {
            // `scan_head` opening a container means another value follows;
            // otherwise a whole value is done and every container that ends
            // here closes, until a comma asks for one more.
            if self.scan_head(&mut stack)? {
                continue;
            }
            if !self.close_frames(&mut stack)? {
                break;
            }
        }

        Ok(Value {
            input: self.input,
            start,
            end: self.pos,
            kind,
        })
    }

    /// Consumes the start of one value: a whole scalar, or the opening
    /// bracket of a container.
    ///
    /// Returns `true` when a container was opened and is not empty, so the
    /// caller must read the value that follows.
    fn scan_head(&mut self, stack: &mut Vec<Frame>) -> Result<bool, Error> {
        self.skip_ws();
        match self.peek() {
            None => Err(Error::UnexpectedEnd),
            Some(b'{') => {
                self.enter(stack, Frame::Object)?;
                self.skip_ws();
                if self.peek() == Some(b'}') {
                    self.pos += 1;
                    stack.pop();
                    return Ok(false);
                }
                self.scan_key()?;
                Ok(true)
            }
            Some(b'[') => {
                self.enter(stack, Frame::Array)?;
                self.skip_ws();
                if self.peek() == Some(b']') {
                    self.pos += 1;
                    stack.pop();
                    return Ok(false);
                }
                Ok(true)
            }
            Some(b'"') => {
                self.parse_string()?;
                Ok(false)
            }
            Some(b't') => self.expect_literal("true").map(|()| false),
            Some(b'f') => self.expect_literal("false").map(|()| false),
            Some(b'n') => self.expect_literal("null").map(|()| false),
            Some(b'-' | b'0'..=b'9') => self.scan_number().map(|()| false),
            Some(_) => Err(Error::Unexpected {
                offset: self.pos,
                expected: "a JSON value",
            }),
        }
    }

    /// Consumes a member name and the `:` after it.
    fn scan_key(&mut self) -> Result<(), Error> {
        self.skip_ws();
        self.parse_string()?;
        self.skip_ws();
        self.expect(b':', "':'")
    }

    /// Closes every container that ends at the cursor.
    ///
    /// Returns `true` when a comma asked for one more element instead, so
    /// the caller must read another value.
    fn close_frames(&mut self, stack: &mut Vec<Frame>) -> Result<bool, Error> {
        while let Some(&frame) = stack.last() {
            self.skip_ws();
            match (self.peek(), frame) {
                (Some(b','), Frame::Object) => {
                    self.pos += 1;
                    self.scan_key()?;
                    return Ok(true);
                }
                (Some(b','), Frame::Array) => {
                    self.pos += 1;
                    return Ok(true);
                }
                (Some(b'}'), Frame::Object) | (Some(b']'), Frame::Array) => {
                    self.pos += 1;
                    stack.pop();
                }
                (None, _) => return Err(Error::UnexpectedEnd),
                (Some(_), Frame::Object) => {
                    return Err(Error::Unexpected {
                        offset: self.pos,
                        expected: "',' or '}'",
                    })
                }
                (Some(_), Frame::Array) => {
                    return Err(Error::Unexpected {
                        offset: self.pos,
                        expected: "',' or ']'",
                    })
                }
            }
        }
        Ok(false)
    }

    /// Consumes an opening bracket and pushes its frame, refusing to nest
    /// deeper than [`MAX_DEPTH`].
    fn enter(&mut self, stack: &mut Vec<Frame>, frame: Frame) -> Result<(), Error> {
        if stack.len() == MAX_DEPTH {
            return Err(Error::TooDeep { offset: self.pos });
        }
        self.pos += 1;
        stack.push(frame);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;

    const DOC: &str = r#"{
      "generated_at": "2026-09-09T12:00:00Z",
      "dotfiles_version": "0.2.519",
      "empty_object": {},
      "empty_array": [],
      "numbers": [0, -1, 1.5, 2e3, 2E+3, 12e-3, -0.0],
      "literals": [true, false, null],
      "nested": {"a": {"b": {"c": "deep"}}, "list": [{"k": 1}, {"k": 2}]},
      "escaped": "a\"b\\cA"
    }"#;

    #[test]
    fn validate_accepts_a_realistic_document() {
        validate(DOC).expect("well-formed");
    }

    #[test]
    fn validate_accepts_every_scalar_at_the_root() {
        for input in [
            "null",
            "true",
            "false",
            "0",
            "-0",
            "12",
            "1.5",
            "2e3",
            "2E+3",
            "1e-3",
            "-0.0",
            "\"\"",
            "\"a\"",
            "{}",
            "[]",
            " \t\r\n{}\n",
        ] {
            assert!(validate(input).is_ok(), "{input:?} should be valid");
        }
    }

    #[test]
    fn validate_rejects_trailing_and_empty_input() {
        assert_eq!(validate("{} {}"), Err(Error::TrailingInput { offset: 3 }));
        assert_eq!(validate(""), Err(Error::UnexpectedEnd));
        assert_eq!(validate("   "), Err(Error::UnexpectedEnd));
    }

    #[test]
    fn validate_rejects_malformed_containers() {
        let cases: [(&str, Error); 16] = [
            ("{", Error::UnexpectedEnd),
            ("[", Error::UnexpectedEnd),
            ("[1", Error::UnexpectedEnd),
            ("{\"a\": 1", Error::UnexpectedEnd),
            (
                "[1}",
                Error::Unexpected {
                    offset: 2,
                    expected: "',' or ']'",
                },
            ),
            (
                "{\"a\": 1]",
                Error::Unexpected {
                    offset: 7,
                    expected: "',' or '}'",
                },
            ),
            (
                "{a: 1}",
                Error::Unexpected {
                    offset: 1,
                    expected: "'\"'",
                },
            ),
            (
                "{\"a\" 1}",
                Error::Unexpected {
                    offset: 5,
                    expected: "':'",
                },
            ),
            (
                "{\"a\": 1, b: 2}",
                Error::Unexpected {
                    offset: 9,
                    expected: "'\"'",
                },
            ),
            (
                "{\"a\": 1, \"b\" 2}",
                Error::Unexpected {
                    offset: 13,
                    expected: "':'",
                },
            ),
            (
                "@",
                Error::Unexpected {
                    offset: 0,
                    expected: "a JSON value",
                },
            ),
            (
                "[1, @]",
                Error::Unexpected {
                    offset: 4,
                    expected: "a JSON value",
                },
            ),
            (
                "[{\"a\": @}]",
                Error::Unexpected {
                    offset: 7,
                    expected: "a JSON value",
                },
            ),
            // A string value, rather than a member name, that never ends.
            ("\"unterminated", Error::UnexpectedEnd),
            ("[\"a", Error::UnexpectedEnd),
            ("[\"a\\z\"]", Error::InvalidEscape { offset: 3 }),
        ];
        for (input, want) in cases {
            assert_eq!(validate(input), Err(want), "input: {input:?}");
        }
    }

    #[test]
    fn validate_rejects_malformed_numbers_and_literals() {
        let cases: [(&str, Error); 13] = [
            ("-", Error::UnexpectedEnd),
            (
                "-x",
                Error::Unexpected {
                    offset: 1,
                    expected: "a digit",
                },
            ),
            ("1.", Error::UnexpectedEnd),
            (
                "1.x",
                Error::Unexpected {
                    offset: 2,
                    expected: "a digit",
                },
            ),
            ("1e", Error::UnexpectedEnd),
            ("1e+", Error::UnexpectedEnd),
            (
                "1e+x",
                Error::Unexpected {
                    offset: 3,
                    expected: "a digit",
                },
            ),
            ("tru", Error::UnexpectedEnd),
            ("fals", Error::UnexpectedEnd),
            ("nul", Error::UnexpectedEnd),
            (
                "trux",
                Error::Unexpected {
                    offset: 3,
                    expected: "true",
                },
            ),
            (
                "falsy",
                Error::Unexpected {
                    offset: 4,
                    expected: "false",
                },
            ),
            ("nulls", Error::TrailingInput { offset: 4 }),
        ];
        for (input, want) in cases {
            assert_eq!(validate(input), Err(want), "input: {input:?}");
        }
        // A leading zero terminates the integer part, so `01` scans as `0`
        // followed by trailing input rather than as a malformed number.
        assert_eq!(validate("01"), Err(Error::TrailingInput { offset: 1 }));
    }

    #[test]
    fn depth_is_capped_in_both_container_kinds() {
        let deep_ok = format!("{}{}", "[".repeat(MAX_DEPTH), "]".repeat(MAX_DEPTH));
        validate(&deep_ok).expect("exactly at the cap");

        let too_deep = format!("{}{}", "[".repeat(MAX_DEPTH + 1), "]".repeat(MAX_DEPTH + 1));
        assert_eq!(
            validate(&too_deep),
            Err(Error::TooDeep { offset: MAX_DEPTH })
        );

        let objects = "{\"a\": ".repeat(MAX_DEPTH + 1);
        assert_eq!(
            validate(&format!("{objects}1{}", "}".repeat(MAX_DEPTH + 1))),
            Err(Error::TooDeep {
                offset: MAX_DEPTH * 6
            })
        );
    }

    #[test]
    fn get_reads_scalars_along_a_path() {
        assert_eq!(
            get(DOC, "dotfiles_version").unwrap().as_str().unwrap(),
            "0.2.519"
        );
        assert_eq!(get(DOC, "nested.a.b.c").unwrap().as_str().unwrap(), "deep");
        assert_eq!(get(DOC, "escaped").unwrap().as_str().unwrap(), "a\"b\\cA");
        assert_eq!(get(DOC, "literals").unwrap().kind(), Kind::Array);
        assert_eq!(get(DOC, "empty_object").unwrap().text(), "{}");
        assert_eq!(get(DOC, "empty_array").unwrap().text(), "[]");
        assert_eq!(get(DOC, "numbers").unwrap().kind(), Kind::Array);
    }

    #[test]
    fn get_with_an_empty_path_returns_the_root() {
        let root = get(DOC, "").unwrap();
        assert_eq!(root.kind(), Kind::Object);
        assert_eq!(root.offset(), 0);
        assert_eq!(root.text(), DOC);
    }

    #[test]
    fn get_reports_missing_members_and_non_objects() {
        assert_eq!(get(DOC, "nope"), Err(Error::MissingMember { path: "nope" }));
        assert_eq!(
            get(DOC, "nested.a.zzz"),
            Err(Error::MissingMember {
                path: "nested.a.zzz"
            })
        );
        assert_eq!(
            get(DOC, "empty_object.k"),
            Err(Error::MissingMember {
                path: "empty_object.k"
            })
        );
        let err = get(DOC, "dotfiles_version.inner").unwrap_err();
        assert!(
            matches!(
                err,
                Error::Unexpected {
                    expected: "an object",
                    ..
                }
            ),
            "{err:?}"
        );
        assert_eq!(get("", "a"), Err(Error::UnexpectedEnd));
    }

    #[test]
    fn get_propagates_malformed_input() {
        assert_eq!(get("{", "a"), Err(Error::UnexpectedEnd));
        assert_eq!(
            get("{\"a\": 1 \"b\": 2}", "b"),
            Err(Error::Unexpected {
                offset: 8,
                expected: "',' or '}'"
            })
        );
        assert_eq!(get("{\"a\": 1,", "b"), Err(Error::UnexpectedEnd));
        // The document ends right after a member the path did not want.
        assert_eq!(get("{\"a\": 1", "b"), Err(Error::UnexpectedEnd));
        assert_eq!(
            get("{\"a\": 1, @}", "b"),
            Err(Error::Unexpected {
                offset: 9,
                expected: "'\"'"
            })
        );
        assert_eq!(
            get("{\"a\" 1}", "b"),
            Err(Error::Unexpected {
                offset: 5,
                expected: "':'"
            })
        );
        assert_eq!(get("{\"a\": ", "b"), Err(Error::UnexpectedEnd));
        // A malformed sibling before the wanted key is still reported.
        assert_eq!(
            get("{\"a\": @, \"b\": 1}", "b"),
            Err(Error::Unexpected {
                offset: 6,
                expected: "a JSON value"
            })
        );
    }

    #[test]
    fn as_str_rejects_other_kinds() {
        let v = get(DOC, "empty_array").unwrap();
        assert_eq!(
            v.as_str(),
            Err(Error::Unexpected {
                offset: v.offset(),
                expected: "a string"
            })
        );
    }

    #[test]
    fn as_u64_accepts_integers_and_rejects_the_rest() {
        assert_eq!(get("{\"n\": 0}", "n").unwrap().as_u64(), Ok(0));
        assert_eq!(
            get("{\"n\": 18446744073709551615}", "n").unwrap().as_u64(),
            Ok(u64::MAX)
        );
        assert_eq!(
            get("{\"n\": 18446744073709551616}", "n").unwrap().as_u64(),
            Err(Error::NumberOverflow { offset: 6 })
        );
        assert_eq!(
            get("{\"n\": 1.5}", "n").unwrap().as_u64(),
            Err(Error::Unexpected {
                offset: 7,
                expected: "a plain non-negative integer"
            })
        );
        assert_eq!(
            get("{\"n\": -1}", "n").unwrap().as_u64(),
            Err(Error::Unexpected {
                offset: 6,
                expected: "a digit"
            })
        );
        assert_eq!(
            get("{\"n\": \"1\"}", "n").unwrap().as_u64(),
            Err(Error::Unexpected {
                offset: 6,
                expected: "a number"
            })
        );
    }

    #[test]
    fn as_bool_and_is_null() {
        assert_eq!(get("{\"b\": true}", "b").unwrap().as_bool(), Ok(true));
        assert_eq!(get("{\"b\": false}", "b").unwrap().as_bool(), Ok(false));
        assert!(get("{\"b\": null}", "b").unwrap().is_null());
        assert!(!get("{\"b\": true}", "b").unwrap().is_null());
        assert_eq!(
            get("{\"b\": 1}", "b").unwrap().as_bool(),
            Err(Error::Unexpected {
                offset: 6,
                expected: "a boolean"
            })
        );
    }

    #[test]
    fn kind_names_are_stable() {
        assert_eq!(Kind::Null.name(), "null");
        assert_eq!(Kind::Bool.name(), "a boolean");
        assert_eq!(Kind::Number.name(), "a number");
        assert_eq!(Kind::String.name(), "a string");
        assert_eq!(Kind::Array.name(), "an array");
        assert_eq!(Kind::Object.name(), "an object");
    }

    #[test]
    fn derived_traits_behave() {
        let a = get(DOC, "dotfiles_version").unwrap();
        let b = a;
        assert_eq!(a, b);
        assert_ne!(a, get(DOC, "generated_at").unwrap());
        assert!(format!("{a:?}").contains("String"));
        let mut kinds: HashSet<Kind> = HashSet::new();
        assert!(kinds.insert(Kind::Bool));
        assert!(!kinds.insert(Kind::Bool));
        assert_eq!(Kind::Bool, Kind::Bool);
        assert_ne!(Kind::Bool, Kind::Null);
        assert!(format!("{:?}", Kind::Array).contains("Array"));
    }
}
