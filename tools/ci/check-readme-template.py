#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Check README.md against the workspace README template.

REPO-STANDARD fixes one README shape for every repository: the level-2
headings of ~/Code/README-TEMPLATE.md, in its order. standards-sync
keeps a copy at defaults/Code/README-TEMPLATE.md, which this check
reads, so the expected order never drifts from the standard. It also
reports a `{{TOKEN}}` left unresolved outside code, and a Quick Start
more than 90 lines down (REPO-STANDARD: "within one screen of the top").

    tools/ci/check-readme-template.py            # report: annotate, exit 0
    tools/ci/check-readme-template.py --enforce  # exit 1 on any finding

Report mode lets CI show the gap while the README is restructured; the
job switches to --enforce once it is clean.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
H1 = re.compile(r'<h1 align="center">([^<]+)</h1>')
H2 = re.compile(r"(?m)^## (.+?)\s*$")
TOKEN = re.compile(r"\{\{[A-Z][A-Z0-9_]*\}\}")
FENCE = re.compile(r"(?ms)^```.*?^```[^\n]*$|`[^`\n]*`")
QUICK_START_MAX_LINE = 90


def template_headings(template: str, project: str) -> list[str]:
    """The template's level-2 headings, with the project name filled in."""
    return [h.replace("{{PROJECT_NAME}}", project) for h in H2.findall(template)]


def heading_findings(readme: str, required: list[str]) -> list[str]:
    """Missing, unexpected or reordered level-2 headings."""
    actual = H2.findall(readme)
    if actual == required:
        return []
    findings = [f"missing heading: {h}" for h in required if h not in actual]
    findings += [f"unexpected heading: {h}" for h in actual if h not in required]
    return findings or ["required headings are out of order"]


def token_findings(readme: str) -> list[str]:
    """Template variables left in prose (code spans and blocks are skipped)."""
    prose = FENCE.sub("", readme)
    return [
        f"unresolved template variable: {t}" for t in sorted(set(TOKEN.findall(prose)))
    ]


def quick_start_findings(readme: str) -> list[str]:
    """A Quick Start heading further down than one screen."""
    for number, line in enumerate(readme.splitlines(), start=1):
        if line.strip() == "## Quick Start":
            if number > QUICK_START_MAX_LINE:
                return [
                    f"Quick Start is at line {number}; it must be at line {QUICK_START_MAX_LINE} or above"
                ]
            return []
    return []


def findings_for(readme: str, template: str) -> list[str]:
    """Every finding for one README, or a single blocking one."""
    match = H1.search(readme)
    if not match:
        return ['centred project <h1 align="center"> missing']
    required = template_headings(template, match.group(1).strip())
    return (
        heading_findings(readme, required)
        + token_findings(readme)
        + quick_start_findings(readme)
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--readme", type=Path, default=REPO_ROOT / "README.md")
    parser.add_argument(
        "--template", type=Path, default=REPO_ROOT / "defaults/Code/README-TEMPLATE.md"
    )
    parser.add_argument(
        "--enforce", action="store_true", help="exit 1 when anything is found"
    )
    args = parser.parse_args()

    findings = findings_for(
        args.readme.read_text(encoding="utf-8"),
        args.template.read_text(encoding="utf-8"),
    )
    level = "error" if args.enforce else "warning"
    for finding in findings:
        print(f"::{level} file={args.readme.name}::README template: {finding}")
    if not findings:
        print(f"{args.readme.name} matches the README template")
    return 1 if findings and args.enforce else 0


if __name__ == "__main__":
    sys.exit(main())
