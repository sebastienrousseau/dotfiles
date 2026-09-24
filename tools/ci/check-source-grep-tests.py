#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Reject tests that inspect source text instead of running the code.

A test that greps `scripts/ops/rollback.sh` for a regex proves the
text is there, not that the behaviour holds: it passes with the guard
inverted and fails when the line is merely reworded. The mutation gate
(tools/ci/mutation-test.py) cannot count such a test as a kill, and a
suite built from them reports coverage it does not have.

    tools/ci/check-source-grep-tests.py                   # CI: no regression
    tools/ci/check-source-grep-tests.py --report          # counts only
    tools/ci/check-source-grep-tests.py --write-baseline  # ratchet down

The suite already carries hundreds of these, so the lint is a ratchet:
tools/ci/source-grep-baseline.txt records how many lines each file may
have. A new file, or a file above its recorded count, fails. Fixing a
test and rewriting the baseline lowers the ceiling; it never rises.

A test whose job *is* the source text (a lint, a naming convention, a
header check) declares it in its first 30 lines:

    # test-kind: structural
    # test-kind: structural except scripts/qa/check-version-consistency.sh

The lint skips a structural test, and the mutation gate does not count
its kills (except on the listed sources, which it exercises
behaviourally). The declaration lives in the test, so there is no
separate list to keep in step.

What counts as inspecting source text: a text tool (grep, rg, awk, sed,
cat, head, tail, wc, diff, cmp, shellcheck, shfmt, `bash -n`) or a
file-content assertion (assert_file_contains, assert_file_not_contains)
whose operand is a repository source path: a literal under scripts/,
lib/, bin/, tools/, core/, install/, defaults/, .chezmoitemplates/ or
install.sh, rooted at $REPO_ROOT (or ROOT, PROJECT_ROOT, DOTFILES_ROOT,
SRC_DIR, SOURCE_DIR, or a $SCRIPT_DIR/../.. walk), or a variable the
test assigned such a path to. Running the file (`bash "$X"`, `source`,
`"$X" args`), copying it into a fixture, or testing that it exists is
not inspection.

A second rule covers the feature-matrix suites: a `fm_expect_rc_in 0 1`
row whose test function asserts nothing about the output passes whether
the command worked or failed, so it is reported the same way.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

MARKER_RE = re.compile(r"^#\s*test-kind:\s*structural\b(?:\s+except\s+(.+))?\s*$")

ROOT_VARS = r"(?:REPO_ROOT|ROOT|PROJECT_ROOT|DOTFILES_ROOT|DOTFILES_DIR|SRC_DIR|SOURCE_DIR|REPO)"
SOURCE_DIRS = r"(?:scripts|lib|bin|tools|core|install|defaults|\.chezmoitemplates)/[^\s\"'|;&)]*|install\.sh"
# "$REPO_ROOT/scripts/x.sh", ${ROOT}/lib/y, $SCRIPT_DIR/../../scripts/z
SOURCE_PATH_RE = re.compile(
    r"(?:\$\{?" + ROOT_VARS + r"\}?/|\$\{?SCRIPT_DIR\}?(?:/\.\.)+/)(" + SOURCE_DIRS + r")"
)
ASSIGN_RE = re.compile(r"^\s*(?:local\s+|readonly\s+|declare\s+-?\w*\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$")

TEXT_TOOLS = {
    "grep", "egrep", "fgrep", "rg", "awk", "gawk", "sed", "cat", "head", "tail",
    "wc", "diff", "cmp", "shellcheck", "shfmt", "assert_file_contains",
    "assert_file_not_contains",
}
BASH_SYNTAX_RE = re.compile(r"\bbash\s+-n\b")
# The operand is executed, sourced, copied or existence-tested: fine.
NOT_INSPECTION_RE = re.compile(
    r"(?:^|[\s;&|(])(?:bash|sh|zsh|source|\.|cp|ln|chmod|install|exec|env|command|type|stat|realpath|readlink|dirname|basename|test|\[\[?)\s"
)


def structural(lines: list[str]) -> tuple[bool, list[str]]:
    for ln in lines[:30]:
        m = MARKER_RE.match(ln.strip())
        if m:
            return True, (m.group(1) or "").split()
    return False, []


def split_commands(line: str) -> list[str]:
    """Rough split on pipes and separators outside quotes."""
    out, buf, q = [], [], ""
    i = 0
    while i < len(line):
        c = line[i]
        if q:
            buf.append(c)
            if c == q:
                q = ""
        elif c in "\"'":
            q = c
            buf.append(c)
        elif c in "|;&":
            out.append("".join(buf))
            buf = []
        else:
            buf.append(c)
        i += 1
    out.append("".join(buf))
    return [s.strip() for s in out if s.strip()]


def lint_file(path: Path) -> list[tuple[int, str]]:
    lines = path.read_text(encoding="utf-8", errors="replace").split("\n")
    is_structural, _ = structural(lines)
    if is_structural:
        return []
    source_vars: set[str] = set()
    findings: list[tuple[int, str]] = []
    for n, raw in enumerate(lines, 1):
        line = raw.split("#", 1)[0] if not raw.lstrip().startswith("#") else ""
        if not line.strip():
            continue
        m = ASSIGN_RE.match(line)
        if m and SOURCE_PATH_RE.search(m.group(2)):
            source_vars.add(m.group(1))
            continue
        for cmd in split_commands(line):
            words = cmd.split()
            if not words:
                continue
            tool = words[0]
            # `x=$(head -n 1 "$SRC")` and `x="$(grep … "$SRC")"`: the text tool
            # sits inside a command substitution on the right of an
            # assignment. Look at the substituted command instead.
            m2 = re.match(r'^[A-Za-z_][A-Za-z0-9_]*=\$?"?\$\((.*)$', cmd)
            if m2:
                inner = m2.group(1).split()
                if inner:
                    tool = inner[0]
                    cmd = m2.group(1)
            if tool not in TEXT_TOOLS and not BASH_SYNTAX_RE.search(cmd):
                continue
            operand = None
            if SOURCE_PATH_RE.search(cmd):
                operand = SOURCE_PATH_RE.search(cmd).group(1)
            else:
                for v in source_vars:
                    if re.search(r"\$\{?" + re.escape(v) + r"\}?(?![A-Za-z0-9_])", cmd):
                        operand = f"${v}"
                        break
            if operand is None:
                continue
            if NOT_INSPECTION_RE.search(" " + cmd) and tool not in TEXT_TOOLS:
                continue
            how = "bash -n" if tool not in TEXT_TOOLS else tool
            findings.append((n, f"{how} reads source {operand}"))
            break
    findings += permissive_rows(lines)
    return sorted(findings)


FM_FUNC_RE = re.compile(r"^test_fm_\w+\(\)\s*\{")
FM_PERMISSIVE_RE = re.compile(r"^\s*fm_expect_rc_in\s+0\s+1\s*(?:#.*)?$")
FM_OUTCOME_RE = re.compile(r"\bfm_expect_(?:out|err|file|stdout|stderr|any)\w*\b")


def permissive_rows(lines: list[str]) -> list[tuple[int, str]]:
    """`fm_expect_rc_in 0 1` rows in a function with no outcome assertion."""
    out: list[tuple[int, str]] = []
    start = None
    blocks: list[tuple[int, int]] = []
    for i, ln in enumerate(lines):
        if FM_FUNC_RE.match(ln):
            if start is not None:
                blocks.append((start, i))
            start = i
    if start is not None:
        blocks.append((start, len(lines)))
    for a, b in blocks:
        body = lines[a:b]
        if any(FM_OUTCOME_RE.search(x) for x in body):
            continue
        for j, x in enumerate(body):
            if FM_PERMISSIVE_RE.match(x):
                out.append((a + j + 1, "fm_expect_rc_in 0 1 with no outcome assertion"))
    return out


def load_baseline(path: Path) -> dict[str, int]:
    out: dict[str, int] = {}
    if path.is_file():
        for ln in path.read_text().splitlines():
            ln = ln.split("#", 1)[0].strip()
            if ln:
                count, file = ln.split(None, 1)
                out[file.strip()] = int(count)
    return out


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--root", default=".")
    ap.add_argument(
        "--baseline",
        default="tools/ci/source-grep-baseline.txt",
        help="per-file ceilings (repo-relative); absent means every finding fails",
    )
    ap.add_argument("--report", action="store_true", help="print counts, never fail")
    ap.add_argument(
        "--write-baseline", action="store_true", help="record current counts as the ceiling"
    )
    ap.add_argument("files", nargs="*", help="limit to these test files")
    args = ap.parse_args(argv)
    root = Path(args.root).resolve()
    if args.files:
        tests = [root / f for f in args.files]
    else:
        tests = sorted(
            p for p in (root / "tests").rglob("test_*.sh")
            if p.is_file() and "framework" not in p.parts and "fixtures" not in p.parts
        )
    counts: dict[str, list[tuple[int, str]]] = {}
    for t in tests:
        f = lint_file(t)
        if f:
            counts[str(t.relative_to(root))] = f
    total = sum(len(v) for v in counts.values())

    baseline_path = root / args.baseline
    if args.write_baseline:
        body = "\n".join(f"{len(v):4d} {k}" for k, v in sorted(counts.items()))
        baseline_path.write_text(
            "# Source-grep ceilings per test file, written by\n"
            "#   tools/ci/check-source-grep-tests.py --write-baseline\n"
            "# A file may only go down. Fix a test, then rewrite this file.\n"
            + body + ("\n" if body else "")
        )
        print(f"baseline: {len(counts)} file(s), {total} line(s) -> {args.baseline}")
        return 0

    print(
        f"source-grep tests: {len(counts)} file(s), {total} line(s) inspect source text "
        f"({len(tests)} tests scanned)",
        file=sys.stderr,
    )
    if args.report:
        return 0

    baseline = load_baseline(baseline_path)
    failed = 0
    slack = 0
    for file, f in sorted(counts.items()):
        ceiling = baseline.get(file)
        if ceiling is not None and len(f) <= ceiling:
            slack += ceiling - len(f)
            continue
        failed += 1
        for n, why in f:
            print(f"{file}:{n}: {why}")
        if ceiling is None:
            print(f"{file}: not in the baseline; a new test must run the code", file=sys.stderr)
        else:
            print(f"{file}: {len(f)} line(s), ceiling {ceiling}", file=sys.stderr)
    if failed:
        print(
            "Rewrite each case to run the code and assert the outcome, or declare\n"
            "`# test-kind: structural` in the file's first 30 lines if inspecting\n"
            "source text is the test's purpose.",
            file=sys.stderr,
        )
        return 1
    if slack:
        print(
            f"{slack} line(s) below the ceiling: run --write-baseline to ratchet down",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
