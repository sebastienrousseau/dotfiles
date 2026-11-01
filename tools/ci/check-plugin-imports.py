#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""The plugin import gate (P2.2): a bundled plugin reaches the host only
through the SDK.

A plugin under plugins/<domain>/ may source:

  * an SDK file through $DOT_SDK, written "${DOT_SDK:-<fallback>}/<file>"
    (the fallback is for a plugin run outside bin/dot, as in tests), where
    <file> is one of SDK_FILES (lib/dot/sdk.sh lists what they hold);
  * its own files: a path from its own directory that does not climb out
    of plugins/<domain>/.

Anything else is a coupling edge. Those left from before the SDK are
recorded in tools/ci/plugin-imports-baseline.txt, one "<file> <target>"
per line; a new one fails, and moving a library into the plugin that owns
it (then rewriting the baseline) shrinks the list. It never grows.

    tools/ci/check-plugin-imports.py                   # CI: no new edges
    tools/ci/check-plugin-imports.py --write-baseline  # ratchet down
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASELINE = pathlib.Path("tools/ci/plugin-imports-baseline.txt")
SDK_FILES = {
    "sdk.sh",
    "ui.sh",
    "log.sh",
    "platform.sh",
    "preflight.sh",
    "probe.sh",
    "verified-download.sh",
    "ai-roster.sh",
    "lock.sh",
}
SOURCE = re.compile(r'^\s*(?:source|\.)\s+"([^"]+)"')
SDK_FORM = re.compile(
    r"^\$\{DOT_SDK:-[^}]*\}/([A-Za-z0-9_.-]+)$|^\$DOT_SDK/([A-Za-z0-9_.-]+)$"
)
LOCAL_FORM = re.compile(r"^\$\{?[A-Za-z_][A-Za-z0-9_]*\}?/(?!\.\./)[^$]*$")


def shell_files(root: pathlib.Path) -> list[pathlib.Path]:
    """Every shell file under plugins/: the entries and libexec scripts."""
    out = []
    for path in sorted((root / "plugins").rglob("*")):
        if not path.is_file():
            continue
        if path.suffix == ".sh" or path.name.startswith("dot-"):
            out.append(path)
    return out


def target_of(raw: str) -> str:
    """A source path, reduced to what it names in the repository."""
    tail = raw.split("/../")[-1].lstrip("./")
    return tail.replace("$_HOOK_LIB", "lib/dot")


def edges(root: pathlib.Path) -> list[str]:
    """`<file> <target>` for each import that is neither SDK nor local."""
    found = []
    for path in shell_files(root):
        rel = path.relative_to(root).as_posix()
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except UnicodeDecodeError:
            continue
        for line in lines:
            match = SOURCE.match(line)
            if not match:
                continue
            raw = match.group(1)
            sdk = SDK_FORM.match(raw)
            if sdk:
                name = sdk.group(1) or sdk.group(2)
                if name in SDK_FILES:
                    continue
                found.append(f"{rel} sdk:{name}")
                continue
            if LOCAL_FORM.match(raw) and "/lib/dot/" not in raw and "_LIB" not in raw:
                continue
            found.append(f"{rel} {target_of(raw)}")
    return sorted(set(found))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--root", type=pathlib.Path, default=ROOT, help=argparse.SUPPRESS
    )
    parser.add_argument("--write-baseline", action="store_true")
    args = parser.parse_args(argv)
    current = edges(args.root)
    path = args.root / BASELINE
    if args.write_baseline:
        path.write_text(
            "# Plugin imports outside the SDK, written by\n"
            "#   tools/ci/check-plugin-imports.py --write-baseline\n"
            "# Remove a line by moving the library into the plugin that owns it.\n"
            + "".join(f"{edge}\n" for edge in current)
        )
        print(f"plugin imports: wrote {len(current)} edge(s) to {BASELINE}")
        return 0
    allowed = set()
    if path.is_file():
        allowed = {
            line.strip()
            for line in path.read_text().splitlines()
            if line.strip() and not line.startswith("#")
        }
    new = [edge for edge in current if edge not in allowed]
    gone = sorted(allowed - set(current))
    print(
        f"plugin imports: {len(current)} edge(s) outside the SDK, baseline {len(allowed)}"
    )
    for edge in new:
        print(f"  new edge: {edge}")
    if gone:
        print(
            f"  {len(gone)} baselined edge(s) gone: run --write-baseline to ratchet down"
        )
    if new:
        print(
            'A plugin sources the host\'s SDK through "${DOT_SDK:-...}/<file>" '
            f"({', '.join(sorted(SDK_FILES))}) or its own files, nothing else."
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
