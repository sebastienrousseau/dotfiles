#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Keep tests/quarantine.tsv honest.

A flaky test file listed in tests/quarantine.tsv still runs, but the test
runner does not let its failures fail the suite. That is only safe while
someone owns the fix, so every entry needs a test file that exists, an
owner, a reason, and an expiry date no more than 60 days away. An expired
entry fails CI here and stops protecting the file in the runner.

    tools/ci/check-quarantine.py            # check tests/quarantine.tsv
    tools/ci/check-quarantine.py --today D  # as of date D (tests)

Format, one entry per line, tab-separated; `#` starts a comment:

    test_file.sh<TAB>owner<TAB>YYYY-MM-DD<TAB>reason
"""

from __future__ import annotations

import argparse
import datetime as dt
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MAX_DAYS = 60


def entries(path: Path) -> list[list[str]]:
    """The non-comment, non-blank lines of the quarantine file, split on tabs."""
    lines = path.read_text(encoding="utf-8").splitlines()
    return [
        line.split("\t") for line in lines if line.strip() and not line.startswith("#")
    ]


def entry_problems(fields: list[str], known: set[str], today: dt.date) -> list[str]:
    """What is wrong with one entry, as messages naming its test file."""
    name = fields[0].strip()
    if len(fields) != 4 or not all(f.strip() for f in fields):
        return [f"{name}: needs a file, owner, expiry and reason"]
    problems = [] if name in known else [f"{name}: no such test file"]
    try:
        expires = dt.date.fromisoformat(fields[2].strip())
    except ValueError:
        return problems + [f"{name}: expiry {fields[2]!r} is not a YYYY-MM-DD date"]
    if expires < today:
        problems.append(
            f"{name}: expired on {expires}; fix the test or renew the entry"
        )
    elif (expires - today).days > MAX_DAYS:
        problems.append(f"{name}: expires {expires}, more than {MAX_DAYS} days out")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--file", type=Path, default=REPO_ROOT / "tests/quarantine.tsv")
    parser.add_argument("--tests-dir", type=Path, default=REPO_ROOT / "tests")
    parser.add_argument("--today", type=dt.date.fromisoformat, default=dt.date.today())
    args = parser.parse_args()

    known = {p.name for p in args.tests_dir.rglob("test_*.sh")}
    problems = [
        p for e in entries(args.file) for p in entry_problems(e, known, args.today)
    ]
    for problem in problems:
        print(f"::error file={args.file.name}::quarantine: {problem}")
    if not problems:
        print(f"{args.file.name}: every entry is owned, explained and current")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
