#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Lint GitHub workflows for script injection and leaked checkout tokens.

    tools/ci/check-workflow-hardening.py                     # CI: no regression
    tools/ci/check-workflow-hardening.py --no-baseline FILE  # strict, given files
    tools/ci/check-workflow-hardening.py --write-baseline    # ratchet down

Rule `injection` (CWE-78). GitHub expands `${{ ... }}` into the script text
before the shell sees it, so a release tag, a branch name, a dispatch input
or a step output carrying one becomes shell code. Flagged inside a `run:`
block (inline or block scalar):

    ${{ github.event.* }}      ${{ inputs.* }}      ${{ secrets.* }}
    ${{ github.ref_name }}     ${{ github.head_ref }}   ${{ github.token }}
    ${{ steps.<id>.outputs.<name> }}

The fix is always the same: hand the value to the step through `env:` and
quote "$VAR", where the shell treats it as data (and a secret stays out of
the script text and any URL built from it). Values that cannot carry shell
syntax are allowed explicitly: the numeric and SHA event fields in
SAFE_EVENT_FIELDS, and step outputs listed in
tools/ci/workflow-injection-allowlist.txt as `<file> <step>.<output>` with a
reason. That list is for outputs the step computes as a number; anything
derived from a tag, ref or input does not belong there.

Rule `checkout-credentials` (CWE-522). actions/checkout writes the job token
into the clone's git config unless told not to, where any later step (or a
compromised dependency) can read it. A job that never commits, pushes or
opens a PR must set `persist-credentials: false` on every checkout.

Workflows written before the injection rule carry findings, so it is a
ratchet like check-source-grep-tests.py: tools/ci/workflow-injection-baseline.txt
records `<file> <expression> <count>`. A pair above its count fails; fixing
a workflow and rewriting the baseline lowers the ceiling. The checkout rule
has no baseline.

Exit 0 when clean, 1 with `file:line: finding` per new finding.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from pathlib import Path

EXPR_RE = re.compile(r"\$\{\{(.*?)\}\}")
RISKY_RE = re.compile(
    r"(?<![\w.])(?:github\.event\.[\w.-]+|inputs\.[\w-]+|secrets\.[\w-]+"
    r"|github\.ref_name\b|github\.head_ref\b|github\.token\b"
    r"|steps\.[\w-]+\.outputs\.[\w-]+)"
)
STEP_OUTPUT_RE = re.compile(r"steps\.([\w-]+)\.outputs\.([\w-]+)")
# Numbers and commit SHAs GitHub itself assigns: no shell syntax possible.
SAFE_EVENT_FIELDS = {
    "github.event.after",
    "github.event.before",
    "github.event.pull_request.base.sha",
    "github.event.pull_request.head.sha",
    "github.event.number",
    "github.event.issue.number",
    "github.event.pull_request.number",
    "github.event.workflow_run.id",
    "github.event.workflow_run.run_number",
    "github.event.workflow_run.run_attempt",
}
RUN_RE = re.compile(r"^[ ]*(?:-[ ]+)?run:(?:[ ]+(.*))?$")
JOB_RE = re.compile(r"^  ([\w-]+):\s*(?:#.*)?$")
CHECKOUT_RE = re.compile(r"^([ ]*)(-[ ]+)?uses:[ ]*actions/checkout@")
# A job that writes back through the checkout's credentials.
WRITES_RE = re.compile(
    r"\bgit\s+(?:push|commit)\b|\bgh\s+pr\s+create\b|create-pull-request@"
    r"|git-auto-commit-action@"
)
PERSIST_OFF_RE = re.compile(r"^\s*persist-credentials:\s*false\b")

HERE = Path(__file__).resolve().parent
ALLOWLIST = HERE / "workflow-injection-allowlist.txt"
BASELINE = HERE / "workflow-injection-baseline.txt"


def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def read_rows(path: Path | None) -> list[list[str]]:
    if path is None or not path.is_file():
        return []
    rows = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        fields = raw.split("#", 1)[0].split()
        if fields:
            rows.append(fields)
    return rows


def load_allowlist(path: Path) -> set[tuple[str, str]]:
    return {(r[0], r[1]) for r in read_rows(path) if len(r) >= 2}


def load_baseline(path: Path | None) -> Counter:
    return Counter({(r[0], r[1]): int(r[2]) for r in read_rows(path) if len(r) == 3})


def run_blocks(lines: list[str]):
    """Yield (line number, text) for every line that belongs to a run: value."""
    i = 0
    while i < len(lines):
        m = RUN_RE.match(lines[i])
        i += 1
        if not m:
            continue
        key_col = lines[i - 1].index("run:")
        head = (m.group(1) or "").strip()
        if head and not head.startswith(("|", ">")):
            yield i, head
        while i < len(lines):
            body = lines[i]
            if body.strip() and indent_of(body) <= key_col:
                break
            yield i + 1, body
            i += 1


def allowed(expr: str, name: str, allow: set[tuple[str, str]]) -> bool:
    if expr in SAFE_EVENT_FIELDS:
        return True
    m = STEP_OUTPUT_RE.fullmatch(expr)
    return bool(m) and (name, f"{m.group(1)}.{m.group(2)}") in allow


def scan_injection(path: Path, lines: list[str], allow) -> list[tuple[str, int, str]]:
    findings = []
    for lineno, text in run_blocks(lines):
        for expr in EXPR_RE.findall(text):
            for hit in RISKY_RE.findall(expr):
                if not allowed(hit, str(path), allow):
                    findings.append((str(path), lineno, hit))
    return findings


def jobs(lines: list[str]):
    """Yield (start, end) line ranges of each job under the top-level jobs:."""
    try:
        top = lines.index("jobs:")
    except ValueError:
        return
    starts = []
    for i in range(top + 1, len(lines)):
        if lines[i][:1] not in ("", " ", "#"):
            break
        if JOB_RE.match(lines[i]):
            starts.append(i)
    else:
        i = len(lines)
    bounds = starts + [i]
    for a, b in zip(bounds, bounds[1:]):
        yield a, b


def step_span(lines: list[str], at: int, end: int) -> tuple[int, int]:
    """Return the line range of the step whose `uses:` sits on line `at`."""
    m = CHECKOUT_RE.match(lines[at])
    start = at
    if not m.group(2):
        while start > 0 and not lines[start].lstrip().startswith("- "):
            start -= 1
    dash_col = indent_of(lines[start])
    stop = start + 1
    while stop < end and not (
        lines[stop].strip() and indent_of(lines[stop]) <= dash_col
    ):
        stop += 1
    return start, stop


def scan_checkout(path: Path, lines: list[str]) -> list[tuple[str, int, str]]:
    findings = []
    for a, b in jobs(lines):
        if any(WRITES_RE.search(ln) for ln in lines[a:b]):
            continue
        for i in range(a, b):
            if not CHECKOUT_RE.match(lines[i]):
                continue
            s, e = step_span(lines, i, b)
            if not any(PERSIST_OFF_RE.match(ln) for ln in lines[s:e]):
                findings.append((str(path), i + 1, "checkout without persist-credentials: false"))
    return findings


def targets(args: list[str]) -> list[Path]:
    if args:
        return [Path(a) for a in args]
    return sorted(
        p
        for p in Path(".github").rglob("*")
        if p.suffix in (".yml", ".yaml") and p.is_file()
    )


def over_baseline(findings, baseline: Counter) -> list[tuple[str, int, str]]:
    budget = Counter(baseline)
    new = []
    for path, lineno, hit in findings:
        if budget[(path, hit)] > 0:
            budget[(path, hit)] -= 1
        else:
            new.append((path, lineno, hit))
    return new


def write_baseline(path: Path, findings) -> None:
    counts = Counter((p, h) for p, _, h in findings)
    body = "".join(f"{p} {h} {n}\n" for (p, h), n in sorted(counts.items()))
    header = "# <file> <expression> <count>: tools/ci/check-workflow-hardening.py\n"
    path.write_text(header + body, encoding="utf-8")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("files", nargs="*")
    ap.add_argument("--allowlist", type=Path, default=ALLOWLIST)
    ap.add_argument("--baseline", type=Path, default=BASELINE)
    ap.add_argument("--no-baseline", action="store_true")
    ap.add_argument("--write-baseline", action="store_true")
    args = ap.parse_args(argv)
    allow = load_allowlist(args.allowlist)
    injection, checkout = [], []
    for p in targets(args.files):
        lines = p.read_text(encoding="utf-8").splitlines()
        injection += scan_injection(p, lines, allow)
        checkout += scan_checkout(p, lines)
    if args.write_baseline:
        write_baseline(args.baseline, injection)
        return 0
    baseline = Counter() if args.no_baseline else load_baseline(args.baseline)
    new = over_baseline(injection, baseline) + checkout
    for path, lineno, hit in new:
        print(f"{path}:{lineno}: {hit}")
    if new:
        print(
            f"{len(new)} finding(s): pass expressions through env: and quote "
            '"$VAR"; set persist-credentials: false on read-only checkouts.',
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
