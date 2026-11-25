#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Find flaky test files across repeated runs of the test runner.

Given the logs of N runs of tests/framework/test_runner.sh on the same
commit, a file that failed in some runs and passed in others is flaky; a
file that failed in every run is broken. Either fails the job, unless a
flaky file is listed in tests/quarantine.tsv, where it is still reported.

    tools/ci/flake-report.py run1.log run2.log ...
    tools/ci/flake-report.py --summary "$GITHUB_STEP_SUMMARY" run*.log
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ANSI = re.compile(r"\x1b\[[0-9;]*m")
SECTION = re.compile(r"^(Failed|Quarantined) test files \(\d+\):$")
ITEM = re.compile(r"^  - (\S+)")


def failed_files(log: str) -> set[str]:
    """Test files a runner log lists as failed or quarantined."""
    names: set[str] = set()
    in_list = False
    for raw in log.splitlines():
        line = ANSI.sub("", raw)
        if SECTION.match(line):
            in_list = True
        elif in_list and (item := ITEM.match(line)):
            names.add(item.group(1))
        else:
            in_list = False
    return names


def quarantined(path: Path) -> set[str]:
    """Test files tests/quarantine.tsv lists (validity is check-quarantine.py's job)."""
    if not path.is_file():
        return set()
    lines = path.read_text(encoding="utf-8").splitlines()
    return {
        line.split("\t")[0]
        for line in lines
        if line.strip() and not line.startswith("#")
    }


def classify(
    counts: Counter[str], runs: int, known: set[str]
) -> tuple[list[str], bool]:
    """Report lines, and whether any of them should fail the job."""
    lines, fatal = [], False
    for name, failures in sorted(counts.items()):
        if failures == runs:
            kind, bad = "broken", True
        elif name in known:
            kind, bad = "quarantined", False
        else:
            kind, bad = "flaky", True
        lines.append(f"{kind}: {name} failed {failures} of {runs} runs")
        fatal = fatal or bad
    return lines, fatal


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("logs", nargs="+", type=Path)
    parser.add_argument(
        "--quarantine", type=Path, default=REPO_ROOT / "tests/quarantine.tsv"
    )
    parser.add_argument("--summary", type=Path, help="append a Markdown report here")
    args = parser.parse_args()

    counts: Counter[str] = Counter()
    for log in args.logs:
        counts.update(failed_files(log.read_text(encoding="utf-8", errors="replace")))
    lines, fatal = classify(counts, len(args.logs), quarantined(args.quarantine))
    report = lines or [f"no test file failed in any of {len(args.logs)} runs"]
    print("\n".join(report))
    if args.summary:
        with args.summary.open("a", encoding="utf-8") as fh:
            fh.write("## Flake report\n\n" + "".join(f"- {line}\n" for line in report))
    return 1 if fatal else 0


if __name__ == "__main__":
    sys.exit(main())
