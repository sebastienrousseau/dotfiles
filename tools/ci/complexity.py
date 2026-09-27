#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Per-function complexity for the repo's shell code, from the shfmt AST.

Every shell function (and each file's top-level code, reported as
``<top>``) gets four measures:

* **cc** (McCabe cyclomatic): 1 + each ``if``/``elif`` + each loop + each
  ``case`` arm other than a lone ``*)`` + each ``&&``/``||`` (in command
  lists and in ``[[ ]]``).
* **cog** (cognitive, SonarSource rules adapted to shell): ``if``, loops
  and ``case`` cost 1 plus their nesting depth; ``elif``/``else`` cost 1;
  each run of like ``&&``/``||`` operators costs 1. Bodies of ``if``,
  loops, ``case`` arms and nested functions increase the depth.
* **difficulty** (Halstead D = n1/2 * N2/n2; effort E = D * V is reported
  too): operators are keywords, command names, list/test/arithmetic/
  redirection/expansion operators and assignments; operands are literals,
  variable names and assigned names.
* **nloc**: non-blank, non-comment lines in the function's span.
* **file_nloc**: the same count for the whole file, carried by ``<top>``.

A unit is *complex* when any measure exceeds its limit (``LIMITS``). The
ratchet (``tools/ci/complexity-baseline.txt``) lists today's complex units
with their measures; the check fails when a unit not in the baseline
becomes complex, or a baselined unit gets worse on any measure. Lower the
ceilings after a refactor with ``--write-baseline``.

Usage:
  tools/ci/complexity.py                 # ratchet check (CI)
  tools/ci/complexity.py --report [-n N] [--sort cc|cog|difficulty|nloc|file_nloc|effort]
  tools/ci/complexity.py --summary       # totals and distribution
  tools/ci/complexity.py --json          # every unit, machine-readable
  tools/ci/complexity.py --report --files a.sh b.sh   # just these files
  tools/ci/complexity.py --write-baseline
"""

from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASELINE = ROOT / "tools/ci/complexity-baseline.txt"

# Limits a unit may reach without being "complex": cyclomatic 10, cognitive
# 15, Halstead difficulty 30, 60 lines per function, 500 per file.
LIMITS = {"cc": 10, "cog": 15, "difficulty": 30.0, "nloc": 60, "file_nloc": 500}

def _list_op_codes() -> tuple[int, int]:
    """shfmt's numeric codes for && and ||, read from shfmt itself.

    The codes are internal enum values; asking the installed shfmt keeps
    the tool independent of its version.
    """
    codes = []
    for src in ("a && b", "a || b"):
        out = subprocess.run(["shfmt", "--to-json"], input=src.encode(), capture_output=True, check=True).stdout
        codes.append(json.loads(out)["Stmts"][0]["Cmd"]["Op"])
    return codes[0], codes[1]


AND, OR = _list_op_codes()

KEYWORDS = {
    "IfClause": "if",
    "WhileClause": "while",
    "ForClause": "for",
    "CaseClause": "case",
    "FuncDecl": "function",
    "Subshell": "( )",
    "Block": "{ }",
    "ArithmCmd": "(( ))",
    "TestClause": "[[ ]]",
    "CmdSubst": "$( )",
    "ArithmExp": "$(( ))",
    "ProcSubst": "<( )",
    "DeclClause": "declare",
    "LetClause": "let",
    "TimeClause": "time",
    "CoprocClause": "coproc",
}


@dataclass
class Unit:
    path: str
    name: str
    start: int
    end: int
    cc: int = 1
    cog: int = 0
    operators: dict = field(default_factory=dict)
    operands: dict = field(default_factory=dict)
    nloc: int = 0
    file_nloc: int = 0

    @property
    def key(self) -> str:
        return f"{self.path}::{self.name}"

    @property
    def difficulty(self) -> float:
        n1, n2 = len(self.operators), len(self.operands)
        if n2 == 0:
            return 0.0
        return round((n1 / 2) * (sum(self.operands.values()) / n2), 1)

    @property
    def effort(self) -> float:
        n = len(self.operators) + len(self.operands)
        big_n = sum(self.operators.values()) + sum(self.operands.values())
        if n < 2:
            return 0.0
        return round(big_n * math.log2(n) * self.difficulty, 1)

    def measures(self) -> dict:
        return {
            "cc": self.cc,
            "cog": self.cog,
            "difficulty": self.difficulty,
            "nloc": self.nloc,
            "file_nloc": self.file_nloc,
        }

    def over(self) -> list[str]:
        m = self.measures()
        return [k for k, limit in LIMITS.items() if m[k] > limit]


def _op(unit: Unit, token) -> None:
    unit.operators[token] = unit.operators.get(token, 0) + 1


def _opd(unit: Unit, token) -> None:
    unit.operands[token] = unit.operands.get(token, 0) + 1


def _unwrap(node):
    """A list operand is a Stmt wrapping the command; see through a plain one."""
    if isinstance(node, dict) and "Type" not in node and "Cmd" in node and not node.get("Negated"):
        return node["Cmd"]
    return node


def _is_chain(node) -> bool:
    return isinstance(node, dict) and node.get("Type") in ("BinaryCmd", "BinaryTest") and node.get("Op") in (AND, OR)


def _chain_ops(node) -> list[int]:
    """Operators of an &&/|| chain, left to right, flattening nested ones."""
    node = _unwrap(node)
    if _is_chain(node):
        return _chain_ops(node.get("X")) + [node["Op"]] + _chain_ops(node.get("Y"))
    return []


class Walker:
    def __init__(self, path: str, lines: list[str]):
        self.path = path
        self.lines = lines
        self.units: list[Unit] = []

    # -- entry -----------------------------------------------------------
    def file(self, ast: dict) -> None:
        top = Unit(self.path, "<top>", 1, len(self.lines))
        self.units.append(top)
        self.stmts(ast.get("Stmts") or [], top, 0)
        top.nloc = self._nloc_top()
        top.file_nloc = self._nloc(1, len(self.lines))

    # -- helpers ---------------------------------------------------------
    def stmts(self, stmts, unit: Unit, depth: int) -> None:
        for st in stmts or []:
            self.node(st, unit, depth)

    def node(self, n, unit: Unit, depth: int, in_chain: bool = False) -> None:
        if isinstance(n, list):
            for v in n:
                self.node(v, unit, depth)
            return
        if not isinstance(n, dict):
            return
        t = n.get("Type")

        if t == "FuncDecl":
            self.func(n, unit, depth)
            return
        if t in KEYWORDS:
            _op(unit, KEYWORDS[t])

        if t == "IfClause":
            self.if_clause(n, unit, depth)
            return
        if t in ("WhileClause", "ForClause"):
            if t == "WhileClause" and n.get("Until"):
                _op(unit, "until")
            unit.cc += 1
            unit.cog += 1 + depth
            for k, v in n.items():
                if k == "Do":
                    self.stmts(v, unit, depth + 1)
                elif k not in ("Pos", "End"):
                    self.node(v, unit, depth)
            return
        if t == "CaseClause":
            unit.cog += 1 + depth
            self.node(n.get("Word"), unit, depth)
            for item in n.get("Items") or []:
                pats = item.get("Patterns") or []
                lone_default = len(pats) == 1 and _lit(pats[0]) == "*"
                if not lone_default:
                    unit.cc += 1
                _op(unit, ")")
                for p in pats:
                    self.node(p, unit, depth)
                self.stmts(item.get("Stmts"), unit, depth + 1)
            return
        if t in ("BinaryCmd", "BinaryTest") and n.get("Op") in (AND, OR):
            if not in_chain:
                ops = _chain_ops(n)
                unit.cc += len(ops)
                unit.cog += 1 + sum(1 for a, b in zip(ops, ops[1:]) if a != b)
            _op(unit, "&&" if n["Op"] == AND else "||")
            for side in (n.get("X"), n.get("Y")):
                inner = _unwrap(side)
                # Operands that continue the chain were already counted.
                self.node(inner if _is_chain(inner) else side, unit, depth, in_chain=_is_chain(inner))
            return
        if t in ("BinaryCmd", "BinaryTest", "UnaryTest", "BinaryArithm", "UnaryArithm"):
            _op(unit, f"{t}:{n.get('Op')}")
        if t == "CallExpr":
            args = n.get("Args") or []
            if args:
                _op(unit, "cmd:" + (_lit(args[0]) or "<dynamic>"))
                for a in args[1:]:
                    self.word(a, unit)
            for a in n.get("Assigns") or []:
                self.assign(a, unit, depth)
            return
        if t == "ParamExp":
            _opd(unit, "$" + ((n.get("Param") or {}).get("Value") or "?"))
            if n.get("Exp"):
                _op(unit, f"exp:{n['Exp'].get('Op')}")
        if "Redirs" in n:
            for r in n.get("Redirs") or []:
                _op(unit, f"redir:{r.get('Op')}")
                self.word(r.get("Word"), unit)
        for k, v in n.items():
            if k in ("Redirs", "Pos", "End"):
                continue
            if isinstance(v, (dict, list)):
                self.node(v, unit, depth)
            elif k == "Value" and t == "Lit":
                _opd(unit, v)

    def if_clause(self, n, unit: Unit, depth: int) -> None:
        unit.cc += 1
        unit.cog += 1 + depth
        self.stmts(n.get("Cond"), unit, depth)
        self.stmts(n.get("Then"), unit, depth + 1)
        branch = n.get("Else")
        while branch:
            if branch.get("Cond"):
                _op(unit, "elif")
                unit.cc += 1
                unit.cog += 1
                self.stmts(branch.get("Cond"), unit, depth)
                self.stmts(branch.get("Then"), unit, depth + 1)
                branch = branch.get("Else")
            else:
                _op(unit, "else")
                unit.cog += 1
                self.stmts(branch.get("Then"), unit, depth + 1)
                branch = None

    def func(self, n, parent: Unit, depth: int) -> None:
        name = ((n.get("Name") or {}).get("Value")) or "<anon>"
        start, end = n["Pos"]["Line"], n["End"]["Line"]
        unit = Unit(self.path, name, start, end)
        self.units.append(unit)
        _op(parent, "function")
        self.node(n.get("Body"), unit, depth + 1 if parent.name != "<top>" else 0)
        unit.nloc = self._nloc(start, end)

    def assign(self, a, unit: Unit, depth: int) -> None:
        _op(unit, "=")
        _opd(unit, (a.get("Name") or {}).get("Value") or "?")
        for k in ("Value", "Array", "Index"):
            if a.get(k):
                self.node(a[k], unit, depth)

    def word(self, w, unit: Unit) -> None:
        if w:
            self.node(w, unit, 0)

    # -- line counts -----------------------------------------------------
    def _nloc(self, start: int, end: int) -> int:
        return sum(1 for ln in self.lines[start - 1 : end] if ln.strip() and not ln.strip().startswith("#"))

    def _nloc_top(self) -> int:
        inside = set()
        for u in self.units:
            if u.name != "<top>":
                inside.update(range(u.start, u.end + 1))
        return sum(
            1
            for i, ln in enumerate(self.lines, 1)
            if i not in inside and ln.strip() and not ln.strip().startswith("#")
        )


def _lit(word) -> str | None:
    parts = (word or {}).get("Parts") or []
    if len(parts) == 1 and parts[0].get("Type") == "Lit":
        return parts[0].get("Value")
    return None


# -- file discovery ------------------------------------------------------
def shell_files() -> list[str]:
    out = subprocess.run(
        ["git", "ls-files", "-z", "--", "*.sh", "*.bash", "bin/*", "defaults/dot_local/bin/executable_*"],
        cwd=ROOT,
        capture_output=True,
        check=True,
    ).stdout.decode()
    files = []
    for rel in sorted(set(filter(None, out.split("\0")))):
        if rel.startswith(("tests/", "fuzz/")) or rel.endswith(".tmpl"):
            continue
        p = ROOT / rel
        if not p.is_file():
            continue
        if not rel.endswith((".sh", ".bash")):
            first = p.open("rb").readline().decode("utf-8", "replace")
            if not first.startswith("#!") or not any(s in first for s in ("bash", "/sh", " sh")):
                continue
        files.append(rel)
    return files


def analyse(rel: str) -> list[Unit]:
    text = (ROOT / rel).read_text(encoding="utf-8", errors="replace")  # ROOT / abs == abs
    res = subprocess.run(
        ["shfmt", "--to-json", "-ln", "bash"],
        input=text.encode(),
        capture_output=True,
        check=False,
    )
    if res.returncode != 0:
        raise ValueError(res.stderr.decode().strip())
    walker = Walker(rel, text.splitlines())
    walker.file(json.loads(res.stdout))
    return walker.units


def _analyse_safe(rel: str):
    try:
        return analyse(rel), None
    except ValueError as exc:
        return [], f"{rel}: {exc}"


def collect(files: list[str] | None = None) -> tuple[list[Unit], list[str]]:
    # One shfmt process per file; threads overlap them (the GIL is released
    # while waiting on the subprocess).
    units, errors = [], []
    with ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as pool:
        for got, err in pool.map(_analyse_safe, files or shell_files()):
            units.extend(got)
            if err:
                errors.append(err)
    return units, errors


# -- baseline ratchet ----------------------------------------------------
def read_baseline() -> dict[str, dict]:
    base = {}
    if BASELINE.exists():
        for line in BASELINE.read_text().splitlines():
            if not line.strip() or line.startswith("#"):
                continue
            cc, cog, difficulty, nloc, file_nloc, key = line.split(None, 5)
            base[key] = {
                "cc": int(cc),
                "cog": int(cog),
                "difficulty": float(difficulty),
                "nloc": int(nloc),
                "file_nloc": int(file_nloc),
            }
    return base


def write_baseline(units: list[Unit]) -> int:
    rows = sorted((u for u in units if u.over()), key=lambda u: u.key)
    lines = [
        "# Complexity ceilings per unit, written by",
        "#   tools/ci/complexity.py --write-baseline",
        "# Columns: cc cog difficulty nloc file_nloc path::function (file_nloc on",
        "# <top> only). A unit may only go down;",
        "# refactor it, then rewrite this file. New units must stay under LIMITS.",
    ]
    lines += [f"{u.cc:4d} {u.cog:4d} {u.difficulty:6.1f} {u.nloc:4d} {u.file_nloc:5d} {u.key}" for u in rows]
    BASELINE.write_text("\n".join(lines) + "\n")
    print(f"wrote {len(rows)} complex units to {BASELINE.relative_to(ROOT)}")
    return 0


def check(units: list[Unit]) -> int:
    base = read_baseline()
    problems, improved = [], 0
    for u in units:
        m, over = u.measures(), u.over()
        if u.key in base:
            ceil = base[u.key]
            worse = [k for k in LIMITS if m[k] > ceil[k] and m[k] > LIMITS[k]]
            if worse:
                problems.append(f"{u.key}: worse on {', '.join(f'{k} {ceil[k]}->{m[k]}' for k in worse)}")
            elif any(m[k] < ceil[k] for k in LIMITS):
                improved += 1
        elif over:
            problems.append(f"{u.key}: new complex unit ({', '.join(f'{k}={m[k]}>{LIMITS[k]}' for k in over)})")
    complex_now = sum(1 for u in units if u.over())
    print(f"complexity: {len(units)} units, {complex_now} over limits, baseline {len(base)}")
    if improved:
        print(f"{improved} baselined unit(s) improved: run --write-baseline to ratchet down")
    for p in problems:
        print(f"  {p}")
    return 1 if problems else 0


# -- reports -------------------------------------------------------------
def _sort_key(u: Unit, sort: str):
    return u.effort if sort == "effort" else u.measures()[sort]


def report(units: list[Unit], top: int, sort: str) -> int:
    rows = sorted(units, key=lambda u: _sort_key(u, sort), reverse=True)[:top]
    print(f"{'cc':>4} {'cog':>4} {'diff':>6} {'nloc':>5} {'file':>5} {'effort':>10}  unit")
    for u in rows:
        m = u.measures()
        flag = "*" if u.over() else " "
        print(
            f"{m['cc']:4d} {m['cog']:4d} {m['difficulty']:6.1f} {m['nloc']:5d} {m['file_nloc']:5d} "
            f"{u.effort:10.1f} {flag}{u.key}:{u.start}"
        )
    return 0


def summary(units: list[Unit]) -> int:
    funcs = [u for u in units if u.name != "<top>"]
    print(f"units: {len(units)} ({len(funcs)} functions, {len(units) - len(funcs)} files)")
    for k in LIMITS:
        pool = [u for u in units if u.name == "<top>"] if k == "file_nloc" else units
        vals = sorted(u.measures()[k] for u in pool)
        over = sum(1 for v in vals if v > LIMITS[k])
        pct = lambda q: vals[min(len(vals) - 1, int(q * len(vals)))]  # noqa: E731
        print(
            f"  {k:6} total={sum(vals):.0f} p50={pct(0.5)} p90={pct(0.9)} p95={pct(0.95)} max={vals[-1]} over({LIMITS[k]})={over}"
        )
    print(f"  complex units (any limit): {sum(1 for u in units if u.over())}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--summary", action="store_true")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--write-baseline", action="store_true")
    ap.add_argument("-n", type=int, default=25)
    ap.add_argument("--sort", choices=[*LIMITS, "effort"], default="cog")
    ap.add_argument("--files", nargs="+", metavar="PATH", help="measure these files instead of the repo")
    args = ap.parse_args()

    units, errors = collect([str(Path(f).resolve()) for f in args.files] if args.files else None)
    for e in errors:
        print(f"parse error: {e}", file=sys.stderr)
    if args.json:
        json.dump(
            [{"unit": u.key, "line": u.start, **u.measures(), "effort": u.effort} for u in units], sys.stdout, indent=1
        )
        print()
        return 0
    if args.summary:
        return summary(units)
    if args.report:
        return report(units, args.n, args.sort)
    if args.write_baseline:
        return write_baseline(units)
    return 1 if errors else check(units)


if __name__ == "__main__":
    sys.exit(main())
