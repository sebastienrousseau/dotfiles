#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Render docs/ecosystem.toml into the generated table of docs/ECOSYSTEM.md.

The table sits between the `BEGIN GENERATED: docs/ecosystem.toml` and
`END GENERATED` comments; the prose around it is written by hand and left
alone. Every home path must exist, so the map cannot point at code that
moved.

    tools/docs/gen_ecosystem.py           # rewrite the table
    tools/docs/gen_ecosystem.py --check   # exit 1 when it is stale
"""

from __future__ import annotations

import argparse
import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path("docs/ecosystem.toml")
TARGET = Path("docs/ECOSYSTEM.md")
BEGIN = "<!-- BEGIN GENERATED: docs/ecosystem.toml -->"
END = "<!-- END GENERATED -->"
WAVES = {1: "1", 2: "2", 3: "3", 4: "final split"}


def row(c: dict) -> str:
    home = ", ".join(f"`{h}`" for h in c["home"])
    release = c["latest_release"] or "ships inside .dotfiles"
    return (
        f"| `{c['repo']}` | `{c['command']}` | {c['kind']} | {home}"
        f" | {WAVES[c['wave']]} | {release} |"
    )


def table(components: list[dict]) -> str:
    lines = [
        BEGIN,
        "<!-- Do not edit: run `make generate` after changing docs/ecosystem.toml. -->",
        "",
        "| Repository | Command | Kind | Lives today in | Extraction wave | Latest release |",
        "|---|---|---|---|---|---|",
        *(row(c) for c in components),
        "",
        END,
    ]
    return "\n".join(lines)


def missing_homes(root: Path, components: list[dict]) -> list[str]:
    return [h for c in components for h in c["home"] if not (root / h).exists()]


def render(root: Path) -> tuple[str, str, list[str]]:
    """(current document, document with a fresh table, problems)."""
    components = tomllib.loads((root / SOURCE).read_text())["component"]
    doc = (root / TARGET).read_text()
    pattern = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.DOTALL)
    if not pattern.search(doc):
        return doc, doc, [f"{TARGET} has no {BEGIN} ... {END} block"]
    fresh = pattern.sub(lambda _: table(components), doc, count=1)
    problems = [
        f"{SOURCE}: home {h} does not exist" for h in missing_homes(root, components)
    ]
    return doc, fresh, problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="exit 1 when stale")
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    doc, fresh, problems = render(args.root)
    for problem in problems:
        print(f"gen_ecosystem: {problem}", file=sys.stderr)
    if problems:
        return 1
    if args.check:
        if doc != fresh:
            print(
                f"gen_ecosystem: {TARGET} is stale; run `make generate`",
                file=sys.stderr,
            )
            return 1
        return 0
    (args.root / TARGET).write_text(fresh)
    return 0


if __name__ == "__main__":
    sys.exit(main())
