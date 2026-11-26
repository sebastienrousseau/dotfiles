#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Render the CI-gate table in DEVELOPMENT.md: one row per workflow job.

Each row gives the job (its name, or its id), the command that reproduces
it from docs/ci-gates.toml (the job's own, else its workflow's), its egress
policy (Harden Runner: blocked, allow-listed or unrestricted; reusable for
a job that calls another workflow) and the secrets it reads. Fails when a
workflow has no entry, or a command names a make target or a script that
does not exist.

    tools/docs/gen_ci_gates.py           # rewrite the table
    tools/docs/gen_ci_gates.py --check   # exit 1 when stale or invalid

Workflows are read as text (the standard library has no YAML, and the
Doc Drift jobs run with egress blocked): job ids at two spaces under
`jobs:`, and each job's block below its id.
"""

from __future__ import annotations

import argparse
import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path("docs/ci-gates.toml")
TARGET = Path("DEVELOPMENT.md")
WORKFLOWS = Path(".github/workflows")
BEGIN = "<!-- BEGIN GENERATED: docs/ci-gates.toml -->"
END = "<!-- END GENERATED -->"
JOB_ID = re.compile(r"^  ([A-Za-z0-9_-]+):\s*$")
SECRET = re.compile(r"secrets\.([A-Z0-9_]+)")
MAKE = re.compile(r"\bmake ([a-z][a-z0-9_-]*)")
SCRIPT = re.compile(r"(?:bash|python3|pwsh) ((?:\./)?[\w./-]+\.(?:sh|py|ps1))")


def jobs(text: str) -> list[tuple[str, str]]:
    """[(job id, job block)] in file order."""
    lines = text.splitlines()
    try:
        start = lines.index("jobs:") + 1
    except ValueError:
        return []
    found, current, block = [], None, []
    for line in lines[start:]:
        if line and not line.startswith(" "):
            break
        m = JOB_ID.match(line)
        if m:
            if current:
                found.append((current, "\n".join(block)))
            current, block = m.group(1), []
        elif current:
            block.append(line)
    if current:
        found.append((current, "\n".join(block)))
    return found


def job_name(job_id: str, block: str) -> str:
    m = re.search(r"(?m)^    name:\s*(.+?)\s*$", block)
    return m.group(1).strip("'\"") if m else job_id


def egress(block: str) -> str:
    if re.search(r"(?m)^    uses:\s", block):
        return "reusable"
    m = re.search(r"egress-policy:\s*(\w+)", block)
    if not m or m.group(1) != "block":
        return "unrestricted"
    return "allow-listed" if "allowed-endpoints:" in block else "blocked"


def secrets(block: str) -> str:
    names = sorted(set(SECRET.findall(block)) - {"GITHUB_TOKEN"})
    return ", ".join(f"`{n}`" for n in names) or "—"


def cell(command: str) -> str:
    """The command as code; a trailing "(note)" stays prose. A `|` would
    end the table cell even inside backticks, so it is escaped."""
    if command.startswith("none:"):
        return command.replace("|", "\\|")
    code, sep, note = command.partition(" (")
    return (f"`{code}`" + (f" ({note}" if sep else "")).replace("|", "\\|")


def command_problems(
    root: Path, where: str, command: str, targets: set[str]
) -> list[str]:
    if command.startswith("none:"):
        return []
    problems = [
        f"{where}: make {t} is not a Makefile target"
        for t in MAKE.findall(command)
        if t not in targets
    ]
    problems += [
        f"{where}: {p} does not exist"
        for p in SCRIPT.findall(command)
        if not (root / p).exists()
    ]
    return problems


def build(root: Path) -> tuple[list[str], list[str]]:
    """(table rows, problems)."""
    data = tomllib.loads((root / SOURCE).read_text())["workflows"]
    targets = set(
        re.findall(r"(?m)^([A-Za-z0-9_.-]+):", (root / "Makefile").read_text())
    )
    rows, problems = [], []
    for path in sorted((root / WORKFLOWS).glob("*.yml")):
        entry = data.get(path.name)
        if entry is None:
            problems.append(f"{SOURCE}: no entry for {path.name}")
            continue
        for job_id, block in jobs(path.read_text()):
            command = entry.get("jobs", {}).get(job_id, entry["local"])
            problems += command_problems(
                root, f"{path.name}:{job_id}", command, targets
            )
            rows.append(
                f"| `{path.name}` | {job_name(job_id, block)} | {cell(command)}"
                f" | {egress(block)} | {secrets(block)} |"
            )
    return rows, problems


def table(rows: list[str]) -> str:
    return "\n".join(
        [
            BEGIN,
            "<!-- Do not edit: run `make generate` after changing docs/ci-gates.toml or a workflow. -->",
            "",
            "| Workflow | Job | Locally | Egress | Secrets |",
            "|---|---|---|---|---|",
            *rows,
            "",
            END,
        ]
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="exit 1 when stale")
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    rows, problems = build(args.root)
    doc = (args.root / TARGET).read_text()
    pattern = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.DOTALL)
    if not pattern.search(doc):
        problems.append(f"{TARGET} has no {BEGIN} ... {END} block")
    for problem in problems:
        print(f"gen_ci_gates: {problem}", file=sys.stderr)
    if problems:
        return 1
    fresh = pattern.sub(lambda _: table(rows), doc, count=1)
    if args.check:
        if fresh != doc:
            print(
                f"gen_ci_gates: {TARGET} is stale; run `make generate`", file=sys.stderr
            )
            return 1
        return 0
    (args.root / TARGET).write_text(fresh)
    return 0


if __name__ == "__main__":
    sys.exit(main())
