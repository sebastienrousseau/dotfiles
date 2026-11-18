#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Fail when a complexity baseline grew relative to a base revision.

Each baseline row is ``<measure>... <path>::<function>``: whitespace-
separated numeric ceilings, then the key. Against ``--base`` a baseline
may lose rows and lower ceilings; a new row or a raised ceiling fails,
so an offender cannot be waved through by editing the baseline. A
baseline that does not exist at the base revision is new and is not
checked.

Usage:
  tools/ci/check-baseline-shrink.py --base <rev> tools/ci/complexity-baseline*.txt
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def parse(text: str) -> dict[str, list[float]]:
    rows = {}
    for line in text.splitlines():
        if line.strip() and not line.startswith("#"):
            *values, key = line.split()
            rows[key] = [float(v) for v in values]
    return rows


def at_rev(rev: str, rel: str) -> str | None:
    res = subprocess.run(["git", "show", f"{rev}:{rel}"], cwd=ROOT, capture_output=True, text=True, check=False)
    return res.stdout if res.returncode == 0 else None


def compare(rel: str, old: dict, new: dict) -> list[str]:
    problems = [f"{rel}: new row {key}" for key in sorted(set(new) - set(old))]
    for key in sorted(set(new) & set(old)):
        raised = [f"column {i + 1} {a:g}->{b:g}" for i, (a, b) in enumerate(zip(old[key], new[key])) if b > a]
        if raised or len(old[key]) != len(new[key]):
            problems.append(f"{rel}: {key} raised ({', '.join(raised) or 'column count changed'})")
    return problems


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base", required=True, help="revision the baselines may only shrink from")
    ap.add_argument("files", nargs="+")
    args = ap.parse_args()
    problems = []
    for f in args.files:
        rel = str(Path(f).resolve().relative_to(ROOT))
        old = at_rev(args.base, rel)
        if old is None:
            print(f"{rel}: not in {args.base}; new baseline, not compared")
            continue
        problems += compare(rel, parse(old), parse((ROOT / rel).read_text()))
    for p in problems:
        print(f"  {p}")
    print(f"baseline shrink check: {len(args.files)} file(s), {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
