#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Check the README's toolchain versions against where they are decided.

docs/MINIMUM-TOOLCHAIN.md sets each floor and CI pins chezmoi
(CHEZMOI_VERSION in ci.yml). The README repeats them in the toolchain badge
and the Requirements table; this fails when the two disagree, so a floor or
pin cannot move without the README. It also fails when the chezmoi floor
is not the pinned version, and when the README names a platform floor the
toolchain table does not list.

    tools/ci/check-readme-toolchain.py   # exit 1 on any mismatch
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

# Floor rows of the toolchain table: README name -> row label pattern.
FLOOR_ROWS = {
    "bash": r"\*\*bash\*\* \(as an \*interactive\*",
    "zsh": r"\*\*zsh\*\*",
    "PowerShell": r"\*\*PowerShell\*\*",
    "git": r"\*\*git\*\*",
    "chezmoi": r"\*\*chezmoi\*\*",
}
# Where the README states each floor: pattern with one group, the version.
README_FLOORS = {
    "bash": [
        r"\bbash (\d[\d.]*)\+",
        r"toolchain-bash%20(\d[\d.]*)%20",
        r"Minimum toolchain: bash (\d[\d.]*),",
    ],
    "zsh": [r"\bzsh (\d[\d.]*)\+"],
    "PowerShell": [r"PowerShell (\d[\d.]*)\+"],
    "git": [r"^\| git \| (\d[\d.]*)\+"],
    "chezmoi": [
        r"^\| chezmoi \| (\d[\d.]*)\+",
        r"chezmoi%20(\d[\d.]*)-",
        r"chezmoi (\d[\d.]*)\" /",
    ],
}
PLATFORM = re.compile(
    r"(macOS|Ubuntu|Debian|NixOS|Fedora|RHEL|Rocky|Alma) (\d[\d.]*)\+"
)


def table_floors(toolchain: str) -> dict[str, str]:
    """{tool: floor} from the toolchain table's bold floor column."""
    floors = {}
    for tool, label in FLOOR_ROWS.items():
        m = re.search(rf"(?m)^\| {label}[^|]*\| \*\*([\d.]+)\*\* \|", toolchain)
        if m:
            floors[tool] = m.group(1)
    return floors


def floor_findings(readme: str, floors: dict[str, str]) -> list[str]:
    findings = []
    for tool, patterns in README_FLOORS.items():
        want = floors.get(tool)
        if want is None:
            findings.append(f"docs/MINIMUM-TOOLCHAIN.md has no {tool} floor")
            continue
        for pattern in patterns:
            found = re.findall(pattern, readme, flags=re.MULTILINE)
            if not found:
                findings.append(
                    f"README states no {tool} floor where /{pattern}/ expects one"
                )
            findings += [
                f"README says {tool} {v}; docs/MINIMUM-TOOLCHAIN.md says {want}"
                for v in sorted(set(found))
                if v != want
            ]
    return findings


def pin_findings(ci: str, floors: dict[str, str]) -> list[str]:
    m = re.search(r'CHEZMOI_VERSION:\s*"([^"]+)"', ci)
    if not m:
        return ["ci.yml pins no CHEZMOI_VERSION"]
    if m.group(1) != floors.get("chezmoi"):
        floor = floors.get("chezmoi")
        msg = f"CHEZMOI_VERSION is {m.group(1)} in ci.yml; the chezmoi floor is {floor}"
        return [msg]
    return []


def platform_findings(readme: str, toolchain: str) -> list[str]:
    row = re.search(r"(?m)^\| Platforms \| (.+) \|$", readme)
    if not row:
        return ["README Requirements has no Platforms row"]
    listed = {
        f"{name} {ver}"
        for name, ver in re.findall(r"(?m)^\| (\w+) (\d[\d.]*)", toolchain)
    }
    return [
        f"README names {name} {ver}+, which docs/MINIMUM-TOOLCHAIN.md does not list"
        for name, ver in PLATFORM.findall(row.group(1))
        if f"{name} {ver}" not in listed
    ]


def findings_for(readme: str, toolchain: str, ci: str) -> list[str]:
    floors = table_floors(toolchain)
    return (
        floor_findings(readme, floors)
        + pin_findings(ci, floors)
        + platform_findings(readme, toolchain)
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--readme", type=Path, default=REPO_ROOT / "README.md")
    parser.add_argument(
        "--toolchain", type=Path, default=REPO_ROOT / "docs/MINIMUM-TOOLCHAIN.md"
    )
    parser.add_argument(
        "--ci", type=Path, default=REPO_ROOT / ".github/workflows/ci.yml"
    )
    args = parser.parse_args()
    findings = findings_for(
        args.readme.read_text(encoding="utf-8"),
        args.toolchain.read_text(encoding="utf-8"),
        args.ci.read_text(encoding="utf-8"),
    )
    for finding in findings:
        print(f"::error file={args.readme.name}::README toolchain: {finding}")
    if not findings:
        print("README toolchain versions match docs/MINIMUM-TOOLCHAIN.md and CI")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
