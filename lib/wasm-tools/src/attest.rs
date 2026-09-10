// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//! The policy this module checks is the workstation evidence record that
//! `dot attest` emits, and checking it is why this crate compiles to
//! WebAssembly.
//!
//! `scripts/diagnostics/workstation-attestation.sh` writes a JSON record
//! describing a machine: its version, platform, git signing configuration,
//! agent profile and MCP posture. Until now nothing read it back. A
//! reviewer handed one of those records had to write their own checker, or
//! trust the `jq` incantation the machine under review handed them along
//! with the evidence.
//!
//! [`Report::verify`] is that checker, and it runs inside a WebAssembly
//! sandbox with no filesystem, no network and no environment: it reads the
//! document on stdin and writes a verdict on stdout. The reviewer needs
//! `wasmtime` — already pinned in `mise.toml` and checked by `dot doctor` —
//! and nothing else, on any platform, with the same bytes producing the
//! same verdict.
//!
//! # Example
//!
//! ```
//! use dot_sys::attest::Report;
//!
//! let evidence = r#"{
//!   "generated_at": "2026-09-09T12:00:00Z",
//!   "dotfiles_version": "0.2.519",
//!   "platform": {"runtime": "darwin-arm64", "host_os": "darwin", "hostname": "kestrel"},
//!   "git_signing": {
//!     "format": "ssh",
//!     "signing_key": "ssh-ed25519 AAAA",
//!     "allowed_signers_file": "/home/u/.config/git/allowed_signers",
//!     "merge_verify_signatures": true
//!   },
//!   "agent": {"current_profile": "ask"},
//!   "mcp": {"doctor": {"status": "healthy"}}
//! }"#;
//!
//! let report = Report::verify(evidence, 1_788_955_260, 3_600)?;
//! assert!(report.passed());
//! assert_eq!(report.summary().status, "ok");
//! # Ok::<(), dot_sys::Error>(())
//! ```

use std::fmt::{self, Write as _};

use crate::{json, time, write_json_string, Error, Status, ENGINE, STATUS_FAILED, STATUS_OK};

/// Default freshness window: evidence older than seven days is stale.
pub const MAX_AGE_DEFAULT: u64 = 7 * 24 * 60 * 60;

/// Pass this as `max_age` to accept evidence of any age.
///
/// The "not stamped in the future" half of the freshness check still
/// applies; only the upper bound is lifted.
pub const MAX_AGE_UNLIMITED: u64 = u64::MAX;

/// Members that must be present and hold a non-empty string.
pub const REQUIRED_STRINGS: &[&str] = &[
    "dotfiles_version",
    "platform.runtime",
    "platform.host_os",
    "platform.hostname",
    "git_signing.signing_key",
    "git_signing.allowed_signers_file",
];

/// Members that must be present and hold one of a fixed set of strings.
pub const REQUIRED_ENUMS: &[(&str, &[&str])] = &[
    ("git_signing.format", &["ssh", "openpgp", "x509"]),
    ("agent.current_profile", &["ask", "plan", "apply", "audit"]),
    // `scripts/diagnostics/mcp-doctor.sh` reports exactly one of
    // `healthy`, `warning` or `failed`; only the first is compliant.
    ("mcp.doctor.status", &["healthy"]),
];

/// Members that must be present and hold boolean `true`.
pub const REQUIRED_TRUE: &[&str] = &["git_signing.merge_verify_signatures"];

/// The member carrying the instant the evidence was produced.
pub const GENERATED_AT: &str = "generated_at";

/// Verdict of a single check.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Outcome {
    /// The member is present and satisfies the policy.
    Pass,
    /// The member is absent, ill-typed, or outside the policy.
    Fail,
}

impl Outcome {
    /// The lower-case word used for this outcome in both output formats.
    ///
    /// # Example
    ///
    /// ```
    /// use dot_sys::attest::Outcome;
    ///
    /// assert_eq!(Outcome::Pass.as_str(), "pass");
    /// assert_eq!(Outcome::Fail.as_str(), "fail");
    /// ```
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Pass => "pass",
            Self::Fail => "fail",
        }
    }
}

impl fmt::Display for Outcome {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

/// One policy check applied to one member of the evidence record.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct Check {
    /// Dotted path of the member the check looked at.
    pub path: &'static str,
    /// Whether the member satisfied the policy.
    pub outcome: Outcome,
    /// The observed value on a pass, or what was wrong on a failure.
    pub detail: String,
}

impl Check {
    fn pass(path: &'static str, detail: impl Into<String>) -> Self {
        Self {
            path,
            outcome: Outcome::Pass,
            detail: detail.into(),
        }
    }

    fn fail(path: &'static str, detail: impl Into<String>) -> Self {
        Self {
            path,
            outcome: Outcome::Fail,
            detail: detail.into(),
        }
    }
}

/// The result of applying the whole policy to one evidence record.
///
/// # Example
///
/// ```
/// use dot_sys::attest::{Outcome, Report, MAX_AGE_UNLIMITED};
///
/// let report = Report::verify(r#"{"generated_at": 1}"#, 0, MAX_AGE_UNLIMITED)?;
/// assert!(!report.passed());
/// assert!(report.checks.iter().all(|c| c.outcome == Outcome::Fail));
/// # Ok::<(), dot_sys::Error>(())
/// ```
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct Report {
    /// Every check, in policy order, starting with freshness.
    pub checks: Vec<Check>,
    /// The Unix time the verification was performed at.
    pub verified_at: u64,
}

impl Report {
    /// Applies the whole policy to `document`.
    ///
    /// `now` is the verifier's idea of the current Unix time and `max_age`
    /// the freshness window in seconds ([`MAX_AGE_UNLIMITED`] to lift it).
    /// Passing the clock in rather than reading it keeps the function
    /// deterministic, which is what makes a verdict reproducible.
    ///
    /// A member that is missing, ill-typed or outside the policy is a
    /// failed [`Check`], not an error; an error means the input was not a
    /// well-formed JSON document at all, so no check could be trusted.
    ///
    /// # Errors
    ///
    /// Returns the [`Error`] from [`json::validate`] if `document` is not
    /// exactly one well-formed JSON value.
    ///
    /// # Example
    ///
    /// ```
    /// use dot_sys::{attest::Report, Error};
    ///
    /// assert_eq!(
    ///     Report::verify("{", 0, 60),
    ///     Err(Error::UnexpectedEnd),
    /// );
    /// ```
    pub fn verify(document: &str, now: u64, max_age: u64) -> Result<Self, Error> {
        json::validate(document)?;

        let mut checks = Vec::with_capacity(
            1 + REQUIRED_STRINGS.len() + REQUIRED_ENUMS.len() + REQUIRED_TRUE.len(),
        );
        checks.push(check_freshness(document, now, max_age));
        for &path in REQUIRED_STRINGS {
            checks.push(check_non_empty_string(document, path));
        }
        for &(path, allowed) in REQUIRED_ENUMS {
            checks.push(check_one_of(document, path, allowed));
        }
        for &path in REQUIRED_TRUE {
            checks.push(check_true(document, path));
        }

        Ok(Self {
            checks,
            verified_at: now,
        })
    }

    /// How many checks failed.
    ///
    /// # Example
    ///
    /// ```
    /// use dot_sys::attest::{Report, MAX_AGE_UNLIMITED};
    ///
    /// let report = Report::verify("{}", 0, MAX_AGE_UNLIMITED)?;
    /// assert_eq!(report.failures(), report.checks.len());
    /// # Ok::<(), dot_sys::Error>(())
    /// ```
    #[must_use]
    pub fn failures(&self) -> usize {
        self.checks
            .iter()
            .filter(|c| c.outcome == Outcome::Fail)
            .count()
    }

    /// Whether every check passed.
    ///
    /// # Example
    ///
    /// ```
    /// use dot_sys::attest::{Report, MAX_AGE_UNLIMITED};
    ///
    /// let report = Report::verify("{}", 0, MAX_AGE_UNLIMITED)?;
    /// assert!(!report.passed());
    /// assert_eq!(report.failures(), report.checks.len());
    /// # Ok::<(), dot_sys::Error>(())
    /// ```
    #[must_use]
    pub fn passed(&self) -> bool {
        self.failures() == 0
    }

    /// The one-line health record this verdict reduces to.
    ///
    /// The `engine` field is [`ENGINE`], so the record states where the
    /// verdict was actually computed: `wasm` when the module ran in a
    /// WebAssembly runtime, `native` when the same code ran as a host
    /// binary.
    ///
    /// # Example
    ///
    /// ```
    /// use dot_sys::attest::{Report, MAX_AGE_UNLIMITED};
    ///
    /// let summary = Report::verify("{}", 42, MAX_AGE_UNLIMITED)?.summary();
    /// assert_eq!(summary.status, "failed");
    /// assert_eq!(summary.timestamp, 42);
    /// assert_eq!(summary.engine, dot_sys::ENGINE);
    /// # Ok::<(), dot_sys::Error>(())
    /// ```
    #[must_use]
    pub fn summary(&self) -> Status {
        let status = if self.passed() {
            STATUS_OK
        } else {
            STATUS_FAILED
        };
        Status::new(status, self.verified_at, ENGINE)
    }

    /// Serialises the whole verdict, summary record included.
    ///
    /// # Example
    ///
    /// ```
    /// use dot_sys::attest::{Report, MAX_AGE_UNLIMITED};
    ///
    /// let json = Report::verify("{}", 0, MAX_AGE_UNLIMITED)?.to_json();
    /// assert!(json.starts_with(r#"{"summary": {"status": "failed", "timestamp": 0,"#));
    /// assert!(json.contains(r#"{"path": "generated_at", "outcome": "fail","#));
    /// # Ok::<(), dot_sys::Error>(())
    /// ```
    #[must_use]
    pub fn to_json(&self) -> String {
        let mut out = String::with_capacity(128 + self.checks.len() * 96);
        out.push_str(r#"{"summary": "#);
        out.push_str(&self.summary().to_json());
        out.push_str(r#", "checks": ["#);
        for (i, check) in self.checks.iter().enumerate() {
            if i > 0 {
                out.push_str(", ");
            }
            out.push_str(r#"{"path": "#);
            write_json_string(&mut out, check.path);
            out.push_str(r#", "outcome": "#);
            write_json_string(&mut out, check.outcome.as_str());
            out.push_str(r#", "detail": "#);
            write_json_string(&mut out, &check.detail);
            out.push('}');
        }
        out.push_str("]}");
        out
    }
}

/// Renders the verdict as one aligned line per check plus a summary line.
///
/// # Example
///
/// ```
/// use dot_sys::attest::{Report, MAX_AGE_UNLIMITED};
///
/// let report = Report::verify("{}", 0, MAX_AGE_UNLIMITED)?;
/// let text = report.to_string();
/// assert!(text.lines().next().unwrap().starts_with("fail  generated_at"));
/// let n = report.checks.len();
/// assert!(text.ends_with(&format!("{n} of {n} checks failed\n")));
/// # Ok::<(), dot_sys::Error>(())
/// ```
impl fmt::Display for Report {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let width = self
            .checks
            .iter()
            .map(|c| c.path.len())
            .max()
            .unwrap_or_default();
        for check in &self.checks {
            writeln!(
                f,
                "{}  {:width$}  {}",
                check.outcome.as_str(),
                check.path,
                flatten(&check.detail)
            )?;
        }
        let failures = self.failures();
        if failures == 0 {
            writeln!(f, "all {} checks passed on {ENGINE}", self.checks.len())
        } else {
            writeln!(f, "{failures} of {} checks failed", self.checks.len())
        }
    }
}

/// Renders one detail as a single line carrying nothing a terminal acts on.
///
/// A detail quotes a value taken straight from the document under review,
/// and that document is chosen by the machine being attested. Two things
/// follow, and both are the verifier's problem rather than the reader's:
///
/// - a newline would split one check across two lines, breaking the "one
///   line per check" shape the report promises (found by `fuzz_verify`;
///   the reproducer is in `fuzz/regressions/fuzz_verify/`);
/// - a carriage return, backspace or `ESC` would let the attested machine
///   repaint the reviewer's screen — and for a tool whose entire product
///   is a verdict someone reads, forging that verdict is the whole attack.
///
/// So every [`char::is_control`] character is escaped, not just the ones
/// that break the line count. Doing it at the single render site rather
/// than at each call site means a check added later cannot reintroduce
/// either problem by forgetting to.
///
/// [`Report::to_json`] deliberately does not do this: it writes `detail`
/// through the crate's JSON string writer, so the machine-readable verdict
/// keeps the value byte-for-byte as the document had it. The two
/// renderings differ because a parser and a terminal are not at risk from
/// the same bytes.
fn flatten(detail: &str) -> String {
    let mut out = String::with_capacity(detail.len());
    for c in detail.chars() {
        match c {
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            // Writing into a String cannot fail.
            c if c.is_control() => {
                let _ = write!(out, "\\u{:04x}", u32::from(c));
            }
            c => out.push(c),
        }
    }
    out
}

/// Checks that `generated_at` is a UTC instant that is neither in the
/// future nor older than `max_age` seconds.
fn check_freshness(document: &str, now: u64, max_age: u64) -> Check {
    let text = match string_at(document, GENERATED_AT) {
        Ok(text) => text,
        Err(detail) => return Check::fail(GENERATED_AT, detail),
    };
    let stamped = match time::parse_rfc3339_utc(&text) {
        Ok(stamped) => stamped,
        Err(e) => return Check::fail(GENERATED_AT, format!("{text:?}: {e}")),
    };
    if stamped > now {
        let ahead = stamped - now;
        return Check::fail(GENERATED_AT, format!("{text} is {ahead}s in the future"));
    }
    let age = now - stamped;
    if age > max_age {
        Check::fail(
            GENERATED_AT,
            format!("{text} is {age}s old, past the {max_age}s limit"),
        )
    } else {
        Check::pass(GENERATED_AT, format!("{text} ({age}s old)"))
    }
}

/// Checks that `path` holds a string with at least one character.
fn check_non_empty_string(document: &str, path: &'static str) -> Check {
    match string_at(document, path) {
        Err(detail) => Check::fail(path, detail),
        Ok(value) if value.is_empty() => Check::fail(path, "present but empty"),
        Ok(value) => Check::pass(path, value),
    }
}

/// Checks that `path` holds one of `allowed`.
fn check_one_of(document: &str, path: &'static str, allowed: &[&str]) -> Check {
    match string_at(document, path) {
        Err(detail) => Check::fail(path, detail),
        Ok(value) if allowed.contains(&value.as_str()) => Check::pass(path, value),
        Ok(value) => Check::fail(
            path,
            format!("{value:?} is not one of {}", allowed.join(", ")),
        ),
    }
}

/// Checks that `path` holds boolean `true`.
fn check_true(document: &str, path: &'static str) -> Check {
    match json::get(document, path).and_then(json::Value::as_bool) {
        Err(e) => Check::fail(path, e.to_string()),
        Ok(false) => Check::fail(path, "expected true, found false"),
        Ok(true) => Check::pass(path, "true"),
    }
}

/// Reads `path` as a string, rendering any lookup failure as a detail line.
fn string_at(document: &str, path: &'static str) -> Result<String, String> {
    json::get(document, path)
        .and_then(json::Value::as_str)
        .map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;

    /// An evidence record that satisfies every check, stamped at
    /// 2026-09-09T12:00:00Z (Unix 1 788 955 200).
    const GOOD: &str = r#"{
      "generated_at": "2026-09-09T12:00:00Z",
      "dotfiles_version": "0.2.519",
      "platform": {
        "runtime": "darwin-arm64",
        "host_os": "darwin",
        "architecture": "arm64",
        "hostname": "kestrel"
      },
      "git_signing": {
        "format": "ssh",
        "signing_key": "ssh-ed25519 AAAAC3Nz",
        "allowed_signers_file": "/home/u/.config/git/allowed_signers",
        "merge_verify_signatures": true
      },
      "agent": {"current_profile": "ask", "profiles": {"defaultProfile": "ask"}},
      "governance": {"policy_bundles": [], "model_registry": null},
      "mcp": {"doctor": {"status": "healthy", "servers": []}, "policy": {}}
    }"#;

    /// Unix time of `GOOD`'s `generated_at`.
    const STAMPED: u64 = 1_788_955_200;

    /// Number of checks the policy is made of.
    const TOTAL: usize = 11;

    fn verify(document: &str) -> Report {
        Report::verify(document, STAMPED, MAX_AGE_DEFAULT).expect("well-formed JSON")
    }

    fn detail_of(report: &Report, path: &str) -> String {
        named(report, path).detail.clone()
    }

    fn named<'a>(report: &'a Report, path: &str) -> &'a Check {
        report
            .checks
            .iter()
            .find(|c| c.path == path)
            .expect("the policy carries a check for this path")
    }

    /// The string `document` gives to the member spelled `leaf`.
    fn value_of(document: &str, leaf: &str) -> String {
        let needle = format!("\"{leaf}\": \"");
        let start = document.find(&needle).expect("member present") + needle.len();
        let rest = &document[start..];
        rest[..rest.find('"').expect("closing quote")].to_string()
    }

    /// `document` with the string member `leaf` given a new `value`.
    fn with(document: &str, leaf: &str, value: &str) -> String {
        let old = format!("\"{leaf}\": \"{}\"", value_of(document, leaf));
        let new = format!("\"{leaf}\": \"{value}\"");
        assert_eq!(document.matches(&old).count(), 1, "{old} is not unique");
        document.replace(&old, &new)
    }

    #[test]
    fn a_compliant_record_passes_every_check() {
        let report = verify(GOOD);
        assert!(report.passed(), "{report}");
        assert_eq!(report.failures(), 0);
        assert_eq!(report.checks.len(), TOTAL);
        assert_eq!(
            TOTAL,
            1 + REQUIRED_STRINGS.len() + REQUIRED_ENUMS.len() + REQUIRED_TRUE.len()
        );
        assert_eq!(report.checks[0].path, GENERATED_AT);
        assert_eq!(detail_of(&report, "dotfiles_version"), "0.2.519");
        assert_eq!(detail_of(&report, "platform.hostname"), "kestrel");
        assert_eq!(
            detail_of(&report, GENERATED_AT),
            "2026-09-09T12:00:00Z (0s old)"
        );
        assert_eq!(report.summary(), Status::new(STATUS_OK, STAMPED, ENGINE));
    }

    #[test]
    fn malformed_json_is_an_error_not_a_verdict() {
        assert_eq!(Report::verify("{", 0, 60), Err(Error::UnexpectedEnd));
        assert_eq!(Report::verify("", 0, 60), Err(Error::UnexpectedEnd));
        assert_eq!(
            Report::verify("{} trailing", 0, 60),
            Err(Error::TrailingInput { offset: 3 })
        );
    }

    #[test]
    fn an_empty_object_fails_every_check() {
        let report = Report::verify("{}", STAMPED, MAX_AGE_DEFAULT).expect("valid JSON");
        assert!(!report.passed());
        assert_eq!(report.failures(), TOTAL);
        for check in &report.checks {
            assert_eq!(check.outcome, Outcome::Fail);
            assert!(
                check.detail.starts_with("no member"),
                "{}: {}",
                check.path,
                check.detail
            );
        }
        assert_eq!(
            report.summary(),
            Status::new(STATUS_FAILED, STAMPED, ENGINE)
        );
    }

    #[test]
    fn freshness_rejects_stale_and_future_stamps() {
        let stale = Report::verify(GOOD, STAMPED + MAX_AGE_DEFAULT + 1, MAX_AGE_DEFAULT)
            .expect("valid JSON");
        assert_eq!(named(&stale, GENERATED_AT).outcome, Outcome::Fail);
        assert_eq!(
            detail_of(&stale, GENERATED_AT),
            format!(
                "2026-09-09T12:00:00Z is {}s old, past the {MAX_AGE_DEFAULT}s limit",
                MAX_AGE_DEFAULT + 1
            )
        );

        let future = Report::verify(GOOD, STAMPED - 5, MAX_AGE_DEFAULT).expect("valid JSON");
        assert_eq!(named(&future, GENERATED_AT).outcome, Outcome::Fail);
        assert_eq!(
            detail_of(&future, GENERATED_AT),
            "2026-09-09T12:00:00Z is 5s in the future"
        );

        // Exactly at the limit is still fresh.
        let edge =
            Report::verify(GOOD, STAMPED + MAX_AGE_DEFAULT, MAX_AGE_DEFAULT).expect("valid JSON");
        assert_eq!(named(&edge, GENERATED_AT).outcome, Outcome::Pass);

        // The unlimited window accepts arbitrarily old evidence.
        let ancient = Report::verify(GOOD, u64::MAX, MAX_AGE_UNLIMITED).expect("valid JSON");
        assert_eq!(named(&ancient, GENERATED_AT).outcome, Outcome::Pass);
    }

    #[test]
    fn freshness_rejects_unparsable_and_ill_typed_stamps() {
        let bad = with(GOOD, GENERATED_AT, "yesterday");
        assert_eq!(
            detail_of(&verify(&bad), GENERATED_AT),
            "\"yesterday\": invalid RFC 3339 UTC timestamp at byte 9"
        );

        let numeric = GOOD.replace(r#""2026-09-09T12:00:00Z""#, "1788955200");
        let detail = detail_of(&verify(&numeric), GENERATED_AT);
        assert!(detail.starts_with("expected a string at byte"), "{detail}");
    }

    #[test]
    fn required_strings_must_be_present_and_non_empty() {
        for &path in REQUIRED_STRINGS {
            let leaf = path.rsplit('.').next().expect("non-empty path");
            let emptied = with(GOOD, leaf, "");
            let report = verify(&emptied);
            assert_eq!(named(&report, path).outcome, Outcome::Fail, "{path}");
            assert_eq!(detail_of(&report, path), "present but empty", "{path}");
            // Emptying one member does not disturb the others.
            assert_eq!(report.failures(), 1, "{path}: {report}");
        }
    }

    #[test]
    fn required_strings_must_be_strings() {
        let retyped = GOOD.replace(
            r#""dotfiles_version": "0.2.519""#,
            r#""dotfiles_version": []"#,
        );
        let detail = detail_of(&verify(&retyped), "dotfiles_version");
        assert!(detail.starts_with("expected a string at byte"), "{detail}");
    }

    #[test]
    fn enum_members_must_be_inside_their_set() {
        let cases: [(&str, &str, &str); 3] = [
            ("format", "none", "git_signing.format"),
            ("current_profile", "yolo", "agent.current_profile"),
            ("status", "degraded", "mcp.doctor.status"),
        ];
        let wanted = ["ssh, openpgp, x509", "ask, plan, apply, audit", "healthy"];
        for ((leaf, value, path), allowed) in cases.into_iter().zip(wanted) {
            let report = verify(&with(GOOD, leaf, value));
            assert_eq!(named(&report, path).outcome, Outcome::Fail, "{path}");
            assert_eq!(
                detail_of(&report, path),
                format!("{value:?} is not one of {allowed}")
            );
        }

        // Every allowed value is accepted.
        for &(path, allowed) in REQUIRED_ENUMS {
            let leaf = path.rsplit('.').next().expect("non-empty path");
            for &value in allowed {
                let report = verify(&with(GOOD, leaf, value));
                assert_eq!(
                    named(&report, path).outcome,
                    Outcome::Pass,
                    "{path}={value}"
                );
            }
        }
    }

    #[test]
    fn boolean_members_must_be_true() {
        let path = "git_signing.merge_verify_signatures";
        let wrong = GOOD.replace(
            r#""merge_verify_signatures": true"#,
            r#""merge_verify_signatures": false"#,
        );
        assert_eq!(
            detail_of(&verify(&wrong), path),
            "expected true, found false"
        );

        let wrong = GOOD.replace(
            r#""merge_verify_signatures": true"#,
            r#""merge_verify_signatures": "true""#,
        );
        let detail = detail_of(&verify(&wrong), path);
        assert!(detail.starts_with("expected a boolean at byte"), "{detail}");
    }

    #[test]
    fn a_member_of_a_non_object_is_reported_not_ignored() {
        let flattened = GOOD.replace(
            r#""mcp": {"doctor": {"status": "healthy", "servers": []}, "policy": {}}"#,
            r#""mcp": "absent""#,
        );
        let detail = detail_of(&verify(&flattened), "mcp.doctor.status");
        assert!(detail.starts_with("expected an object at byte"), "{detail}");
    }

    #[test]
    fn json_output_is_parseable_and_carries_the_summary() {
        let json = verify(GOOD).to_json();
        json::validate(&json).expect("emitted JSON is well-formed");
        assert_eq!(
            json::get(&json, "summary.status")
                .unwrap()
                .as_str()
                .unwrap(),
            STATUS_OK
        );
        assert_eq!(
            json::get(&json, "summary.engine")
                .unwrap()
                .as_str()
                .unwrap(),
            ENGINE
        );
        assert_eq!(
            json::get(&json, "summary.timestamp")
                .unwrap()
                .as_u64()
                .unwrap(),
            STAMPED
        );
        assert_eq!(
            json::get(&json, "checks").unwrap().kind(),
            json::Kind::Array
        );

        let json = Report::verify("{}", 7, MAX_AGE_DEFAULT)
            .expect("valid JSON")
            .to_json();
        json::validate(&json).expect("emitted JSON is well-formed");
        assert_eq!(
            json::get(&json, "summary.status")
                .unwrap()
                .as_str()
                .unwrap(),
            STATUS_FAILED
        );
        assert!(json.contains(r#"{"path": "generated_at", "outcome": "fail", "detail": "#));
    }

    #[test]
    fn json_output_escapes_details() {
        let json = verify(&with(GOOD, "hostname", "a\\\"b")).to_json();
        json::validate(&json).expect("emitted JSON is well-formed");
        assert!(json.contains(r#""detail": "a\"b""#), "{json}");
    }

    #[test]
    fn display_aligns_and_summarises() {
        let report = verify(GOOD);
        let text = report.to_string();
        assert!(text.starts_with("pass  generated_at"), "{text}");
        assert_eq!(text.lines().count(), TOTAL + 1);
        assert!(text.ends_with(&format!("all {TOTAL} checks passed on {ENGINE}\n")));

        let text = Report::verify("{}", 0, MAX_AGE_DEFAULT)
            .expect("valid JSON")
            .to_string();
        assert!(text.ends_with(&format!("{TOTAL} of {TOTAL} checks failed\n")));

        // The path column is as wide as the longest path.
        let width = REQUIRED_TRUE[0].len();
        assert!(
            text.contains(&format!("fail  {GENERATED_AT:width$}  ")),
            "{text}"
        );
    }

    #[test]
    fn a_detail_never_breaks_the_one_line_per_check_shape() {
        // Found by `fuzz_verify` in CI: `platform.runtime` held the JSON
        // escape `\n`, which the reader decodes into a real newline, which
        // then split one check across two lines. The minimised reproducer
        // is `fuzz/regressions/fuzz_verify/newline-in-a-detail`.
        let split = GOOD.replace(r#""runtime": "darwin-arm64""#, r#""runtime": "li\nux-x64""#);
        let report = verify(&split);
        assert_eq!(
            named(&report, "platform.runtime").detail,
            "li\nux-x64",
            "the detail keeps the value the document gave it"
        );
        assert_eq!(report.failures(), 0, "a newline is not a policy failure");

        let text = report.to_string();
        assert_eq!(text.lines().count(), TOTAL + 1, "{text}");
        assert!(text.contains("pass  platform.runtime                     li\\nux-x64\n"));
    }

    #[test]
    fn no_control_character_from_the_document_reaches_the_terminal() {
        // A carriage return or an ESC would let the attested machine
        // repaint the reviewer's screen and forge the verdict it is
        // reading, so the whole Cc category is escaped, not just the
        // characters that break the line count.
        let hostile = with(GOOD, "hostname", r"ok\u001b[2K\u001b[Aall 11 checks passed");
        let report = verify(&hostile);
        let text = report.to_string();
        assert_eq!(text.lines().count(), TOTAL + 1, "{text}");
        for line in text.lines() {
            assert!(
                !line.chars().any(char::is_control),
                "control character in rendered line {line:?}"
            );
        }
        assert!(
            text.contains("ok\\u001b[2K\\u001b[Aall 11 checks passed"),
            "{text}"
        );
    }

    #[test]
    fn flatten_escapes_every_control_and_passes_everything_else_through() {
        assert_eq!(flatten("plain"), "plain");
        assert_eq!(flatten("a\nb"), "a\\nb");
        assert_eq!(flatten("a\rb"), "a\\rb");
        assert_eq!(flatten("a\tb"), "a\\tb");
        assert_eq!(flatten("a\u{08}b"), "a\\u0008b");
        assert_eq!(flatten("a\u{0c}b"), "a\\u000cb");
        assert_eq!(flatten("a\u{1b}b"), "a\\u001bb");
        assert_eq!(flatten("a\u{00}b"), "a\\u0000b");
        assert_eq!(flatten("a\u{7f}b"), "a\\u007fb");
        // C1 controls are `Cc` too, and some terminals act on them.
        assert_eq!(flatten("a\u{85}b"), "a\\u0085b");
        // Quotes, backslashes and non-ASCII text are left alone: they are
        // safe on a line, and the JSON form is where exactness matters.
        assert_eq!(flatten(r#"C:\Users "x" é🦀"#), r#"C:\Users "x" é🦀"#);
        assert_eq!(flatten(""), "");
    }

    #[test]
    fn the_json_verdict_keeps_the_value_the_table_escapes() {
        // The two renderings differ on purpose: a parser and a terminal are
        // not at risk from the same bytes, so the machine-readable verdict
        // stays byte-true to the document.
        let split = GOOD.replace(r#""runtime": "darwin-arm64""#, r#""runtime": "li\nux-x64""#);
        let json = verify(&split).to_json();
        json::validate(&json).expect("emitted JSON is well-formed");
        let checks = json::get(&json, "checks").expect("checks present").text();
        assert!(checks.contains(r#""detail": "li\nux-x64""#), "{checks}");
    }

    #[test]
    fn display_of_an_empty_report_does_not_panic() {
        let report = Report {
            checks: Vec::new(),
            verified_at: 3,
        };
        assert_eq!(
            report.to_string(),
            format!("all 0 checks passed on {ENGINE}\n")
        );
        assert!(report.passed());
        assert_eq!(report.summary(), Status::new(STATUS_OK, 3, ENGINE));
        assert_eq!(
            report.to_json(),
            format!(
                r#"{{"summary": {}, "checks": []}}"#,
                report.summary().to_json()
            )
        );
    }

    /// A formatter sink whose every write fails.
    struct Failing;

    impl fmt::Write for Failing {
        fn write_str(&mut self, _: &str) -> fmt::Result {
            Err(fmt::Error)
        }
    }

    #[test]
    fn display_propagates_a_failing_formatter() {
        use fmt::Write as _;

        // A check line fails first...
        assert!(write!(Failing, "{}", verify(GOOD)).is_err());
        // ...and with no checks at all, the summary line fails instead.
        let empty = Report {
            checks: Vec::new(),
            verified_at: 0,
        };
        assert!(write!(Failing, "{empty}").is_err());
    }

    #[test]
    fn outcome_renders_both_ways() {
        assert_eq!(Outcome::Pass.to_string(), "pass");
        assert_eq!(Outcome::Fail.to_string(), "fail");
        assert_eq!(Outcome::Pass.as_str(), "pass");
        assert_eq!(Outcome::Fail.as_str(), "fail");
    }

    #[test]
    fn derived_traits_behave() {
        let a = verify(GOOD);
        let b = a.clone();
        assert_eq!(a, b);
        assert_ne!(a, Report::verify("{}", STAMPED, MAX_AGE_DEFAULT).unwrap());
        assert!(format!("{a:?}").contains("verified_at"));

        let check = a.checks[0].clone();
        assert_eq!(check, a.checks[0]);
        assert_ne!(check, a.checks[1]);
        assert!(format!("{check:?}").contains("Pass"));

        let mut reports: HashSet<Report> = HashSet::new();
        assert!(reports.insert(a.clone()));
        assert!(!reports.insert(a));

        let mut outcomes: HashSet<Outcome> = HashSet::new();
        assert!(outcomes.insert(Outcome::Pass));
        assert!(!outcomes.insert(Outcome::Pass));
        assert!(outcomes.insert(Outcome::Fail));
        assert!(format!("{:?}", Outcome::Fail).contains("Fail"));
    }
}
