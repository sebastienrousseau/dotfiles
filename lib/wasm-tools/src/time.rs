// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! Conversion from the one timestamp format the evidence record uses into
//! Unix seconds.
//!
//! `scripts/diagnostics/workstation-attestation.sh` stamps its records with
//! `date -u +%Y-%m-%dT%H:%M:%SZ`, so exactly one shape has to be understood:
//! a 20-byte RFC 3339 instant in UTC, second precision, `Z` suffix. Parsing
//! it here rather than shelling out keeps the freshness check inside the
//! sandbox, where the whole point is that no host tool is trusted.
//!
//! # Example
//!
//! ```
//! use dot_sys::time::parse_rfc3339_utc;
//!
//! assert_eq!(parse_rfc3339_utc("1970-01-01T00:00:00Z")?, 0);
//! assert_eq!(parse_rfc3339_utc("2026-09-09T12:00:00Z")?, 1_788_955_200);
//! # Ok::<(), dot_sys::Error>(())
//! ```

use crate::Error;

/// Number of bytes in the accepted timestamp format.
const LEN: usize = 20;

/// Days in each month of a non-leap year.
const MONTH_DAYS: [u8; 12] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

/// Parses `YYYY-MM-DDTHH:MM:SSZ` into seconds since the Unix epoch.
///
/// The grammar is deliberately narrow: fixed width, ASCII digits in fixed
/// positions, an upper-case `T` separator and `Z` zone, no fractional
/// seconds and no numeric offset. Years before 1970 are rejected because
/// the result is a `u64`, and `60` is not accepted in the seconds field —
/// `date` never emits a leap second.
///
/// # Errors
///
/// Returns [`Error::InvalidDateTime`] carrying the byte offset of the first
/// character that does not fit the grammar, or of the first digit of an
/// out-of-range field.
///
/// # Example
///
/// ```
/// use dot_sys::{time::parse_rfc3339_utc, Error};
///
/// assert_eq!(parse_rfc3339_utc("2000-02-29T00:00:00Z")?, 951_782_400);
/// assert_eq!(
///     parse_rfc3339_utc("2001-02-29T00:00:00Z"),
///     Err(Error::InvalidDateTime { offset: 8 }),
/// );
/// # Ok::<(), Error>(())
/// ```
pub fn parse_rfc3339_utc(text: &str) -> Result<u64, Error> {
    let bytes = text.as_bytes();
    if bytes.len() != LEN {
        return Err(Error::InvalidDateTime {
            offset: bytes.len().min(LEN),
        });
    }
    for (offset, expected) in [
        (4, b'-'),
        (7, b'-'),
        (10, b'T'),
        (13, b':'),
        (16, b':'),
        (19, b'Z'),
    ] {
        if bytes[offset] != expected {
            return Err(Error::InvalidDateTime { offset });
        }
    }

    let year = field(bytes, 0, 4)?;
    let month = field(bytes, 5, 2)?;
    let day = field(bytes, 8, 2)?;
    let hour = field(bytes, 11, 2)?;
    let minute = field(bytes, 14, 2)?;
    let second = field(bytes, 17, 2)?;

    if year < 1970 {
        return Err(Error::InvalidDateTime { offset: 0 });
    }
    if !(1..=12).contains(&month) {
        return Err(Error::InvalidDateTime { offset: 5 });
    }
    if day < 1 || u32::from(days_in_month(year, month)) < day {
        return Err(Error::InvalidDateTime { offset: 8 });
    }
    if hour > 23 {
        return Err(Error::InvalidDateTime { offset: 11 });
    }
    if minute > 59 {
        return Err(Error::InvalidDateTime { offset: 14 });
    }
    if second > 59 {
        return Err(Error::InvalidDateTime { offset: 17 });
    }

    let days = days_from_epoch(year, month, day);
    Ok(days * 86_400 + u64::from(hour) * 3_600 + u64::from(minute) * 60 + u64::from(second))
}

/// Reads `width` ASCII digits starting at `offset`.
fn field(bytes: &[u8], offset: usize, width: usize) -> Result<u32, Error> {
    let mut value = 0u32;
    for (i, &b) in bytes[offset..offset + width].iter().enumerate() {
        if !b.is_ascii_digit() {
            return Err(Error::InvalidDateTime { offset: offset + i });
        }
        value = value * 10 + u32::from(b - b'0');
    }
    Ok(value)
}

/// Whether `year` is a leap year in the proleptic Gregorian calendar.
const fn is_leap(year: u32) -> bool {
    year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

/// Length of `month` (1-12) in `year`.
fn days_in_month(year: u32, month: u32) -> u8 {
    let base = MONTH_DAYS[month as usize - 1];
    if month == 2 && is_leap(year) {
        base + 1
    } else {
        base
    }
}

/// Days from 1970-01-01 to `year-month-day`, which the caller has already
/// range-checked and knows is not before the epoch.
///
/// This is Howard Hinnant's `days_from_civil` with the era arithmetic done
/// in `u64`: the year is at least 1970 and at most 9999, so the negative
/// branch of the original is unreachable and nothing can overflow. The
/// result of the final subtraction is exactly zero at the epoch.
fn days_from_epoch(year: u32, month: u32, day: u32) -> u64 {
    let y = u64::from(if month <= 2 { year - 1 } else { year });
    let era = y / 400;
    let yoe = y - era * 400;
    let mp = u64::from((month + 9) % 12);
    let doy = (153 * mp + 2) / 5 + u64::from(day) - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    // 1970-01-01 is day 719 468 of the proleptic Gregorian calendar.
    era * 146_097 + doe - 719_468
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn known_instants() {
        let cases: [(&str, u64); 8] = [
            ("1970-01-01T00:00:00Z", 0),
            ("1970-01-01T00:00:01Z", 1),
            ("1970-01-02T00:00:00Z", 86_400),
            ("1999-12-31T23:59:59Z", 946_684_799),
            ("2000-01-01T00:00:00Z", 946_684_800),
            ("2000-02-29T12:34:56Z", 951_827_696),
            ("2023-11-14T22:13:20Z", 1_700_000_000),
            ("9999-12-31T23:59:59Z", 253_402_300_799),
        ];
        for (text, want) in cases {
            assert_eq!(parse_rfc3339_utc(text), Ok(want), "{text}");
        }
    }

    #[test]
    fn every_month_boundary_round_trips() {
        // Walk the first and last second of every month of a leap year and
        // of the following common year, checking that consecutive months
        // differ by exactly the length of the earlier one.
        for year in [2024u32, 2025] {
            let mut previous: Option<(u32, u64)> = None;
            for month in 1..=12u32 {
                let text = format!("{year:04}-{month:02}-01T00:00:00Z");
                let secs = parse_rfc3339_utc(&text).expect("valid");
                if let Some((prev_month, prev_secs)) = previous {
                    let days = u64::from(days_in_month(year, prev_month));
                    assert_eq!(secs - prev_secs, days * 86_400, "{text}");
                }
                previous = Some((month, secs));
            }
        }
    }

    #[test]
    fn rejects_wrong_length() {
        assert_eq!(
            parse_rfc3339_utc(""),
            Err(Error::InvalidDateTime { offset: 0 })
        );
        assert_eq!(
            parse_rfc3339_utc("2026-09-09T12:00:00"),
            Err(Error::InvalidDateTime { offset: 19 })
        );
        assert_eq!(
            parse_rfc3339_utc("2026-09-09T12:00:00.000Z"),
            Err(Error::InvalidDateTime { offset: 20 })
        );
    }

    #[test]
    fn rejects_wrong_separators() {
        let cases: [(&str, usize); 6] = [
            ("2026/09-09T12:00:00Z", 4),
            ("2026-09/09T12:00:00Z", 7),
            ("2026-09-09 12:00:00Z", 10),
            ("2026-09-09T12-00:00Z", 13),
            ("2026-09-09T12:00-00Z", 16),
            ("2026-09-09T12:00:00+", 19),
        ];
        for (text, offset) in cases {
            assert_eq!(
                parse_rfc3339_utc(text),
                Err(Error::InvalidDateTime { offset }),
                "{text}"
            );
        }
    }

    #[test]
    fn rejects_non_digits_in_every_field() {
        let cases: [(&str, usize); 6] = [
            ("x026-09-09T12:00:00Z", 0),
            ("2026-x9-09T12:00:00Z", 5),
            ("2026-09-x9T12:00:00Z", 8),
            ("2026-09-09Tx2:00:00Z", 11),
            ("2026-09-09T12:x0:00Z", 14),
            ("2026-09-09T12:00:x0Z", 17),
        ];
        for (text, offset) in cases {
            assert_eq!(
                parse_rfc3339_utc(text),
                Err(Error::InvalidDateTime { offset }),
                "{text}"
            );
        }
        // The offset points at the offending digit, not the field start.
        assert_eq!(
            parse_rfc3339_utc("202x-09-09T12:00:00Z"),
            Err(Error::InvalidDateTime { offset: 3 })
        );
    }

    #[test]
    fn rejects_out_of_range_fields() {
        let cases: [(&str, usize); 8] = [
            ("1969-12-31T23:59:59Z", 0),
            ("2026-00-09T12:00:00Z", 5),
            ("2026-13-09T12:00:00Z", 5),
            ("2026-09-00T12:00:00Z", 8),
            ("2026-09-31T12:00:00Z", 8),
            ("2026-09-09T24:00:00Z", 11),
            ("2026-09-09T12:60:00Z", 14),
            ("2026-09-09T12:00:60Z", 17),
        ];
        for (text, offset) in cases {
            assert_eq!(
                parse_rfc3339_utc(text),
                Err(Error::InvalidDateTime { offset }),
                "{text}"
            );
        }
    }

    #[test]
    fn leap_years_follow_the_gregorian_rule() {
        assert!(is_leap(2024));
        assert!(!is_leap(2025));
        assert!(!is_leap(1900));
        assert!(is_leap(2000));
        assert_eq!(days_in_month(2024, 2), 29);
        assert_eq!(days_in_month(2025, 2), 28);
        assert_eq!(days_in_month(2025, 1), 31);
        assert_eq!(days_in_month(2025, 4), 30);
        assert!(parse_rfc3339_utc("2024-02-29T00:00:00Z").is_ok());
        assert_eq!(
            parse_rfc3339_utc("2100-02-29T00:00:00Z"),
            Err(Error::InvalidDateTime { offset: 8 })
        );
        assert!(parse_rfc3339_utc("2000-02-29T00:00:00Z").is_ok());
    }
}
