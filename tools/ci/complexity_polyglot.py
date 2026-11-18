#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Complexity ratchet for the repo's Python and Go code.

The shell ratchet (tools/ci/complexity.py) has the same shape: each
function gets its measures, a function is *complex* when a measure
exceeds its limit, and a per-language baseline lists today's complex
functions with their measures as ceilings. The check fails when a
function not in the baseline becomes complex, or a baselined one gets
worse on a measure that is over its limit. Lower the ceilings after a
refactor with ``--write-baseline``. tools/ci/check-baseline-shrink.py
stops a pull request from adding rows or raising a ceiling.

* **python** (ruff, every tracked ``*.py``): ``cc`` is mccabe C901
  (limit 10), ``branches`` PLR0912 (12), ``statements`` PLR0915 (50).
  The limits must match ruff.toml. ``# noqa`` does not hide a function
  (ruff runs with ``--ignore-noqa``).
* **go** (golangci-lint, every module with a go.mod outside templates/,
  for GOOS linux, darwin and windows): ``cc`` is gocyclo (limit 10),
  ``cog`` gocognit (15), ``nloc`` funlen lines (60). Each module's
  .golangci.yml carries the same limits and an exclusion block, generated
  from the baseline, so the module's own lint job stays green; a
  ``//nolint`` naming these linters fails the check.

Usage:
  tools/ci/complexity_polyglot.py                    # check both (CI)
  tools/ci/complexity_polyglot.py --lang go          # one language
  tools/ci/complexity_polyglot.py --report [-n N]    # worst functions
  tools/ci/complexity_polyglot.py --write-baseline   # also rewrites the
                                                     # .golangci.yml blocks
"""

from __future__ import annotations

import argparse
import ast
import json
import os
import re
import subprocess
import sys
import tempfile
import tomllib
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CI = ROOT / "tools/ci"

LIMITS = {
    "python": {"cc": 10, "branches": 12, "statements": 50},
    "go": {"cc": 10, "cog": 15, "nloc": 60},
}
BASELINES = {lang: CI / f"complexity-baseline-{lang}.txt" for lang in LIMITS}

RUFF_RULES = {"C901": "cc", "PLR0912": "branches", "PLR0915": "statements"}
RUFF_SETTINGS = {
    "cc": ("mccabe", "max-complexity"),
    "branches": ("pylint", "max-branches"),
    "statements": ("pylint", "max-statements"),
}
GO_LINTERS = {"gocyclo": "cc", "gocognit": "cog", "funlen": "nloc"}
GO_SETTINGS = {"cc": "gocyclo:\n      min-complexity: {}", "cog": "gocognit:\n      min-complexity: {}",
               "nloc": "funlen:\n      lines: {}"}
GO_CONFIG = CI / "golangci-complexity.yml"
GOOS_LIST = ("linux", "darwin", "windows")
# "(12 > 10)" (ruff, funlen) or "complexity 12 of func" (gocyclo, gocognit).
MEASURE = re.compile(r"\((\d+) > \d+\)|complexity (\d+) of func")
GO_FUNC = re.compile(r"^func\s*(?:\(\s*(?:\w+\s+)?(\*?)\s*(\w+)(?:\[[^\]]*\])?\s*\)\s*)?(\w+)")
GO_KEY = re.compile(r"^\((\*?)(\w+)\)\.(\w+)$")
NOLINT = re.compile(r"//\s*nolint(?::\S*\b(?:gocyclo|gocognit|funlen)\b|\s|$)")
# The versions CI installs (.github/workflows/ci-enforced.yml, lint-complexity
# and lint-complexity-go); keep in step. Measures can shift between linter
# releases, so the baselines are written with these.
PINNED = {"python": ("ruff", ["ruff", "--version"], "0.17.3"),
          "go": ("golangci-lint", ["golangci-lint", "version"], "2.13.2")}
BEGIN = "# BEGIN complexity baseline"
END = "# END complexity baseline"


@dataclass
class Unit:
    lang: str
    path: str
    name: str
    line: int
    measures: dict = field(default_factory=dict)

    @property
    def key(self) -> str:
        return f"{self.path}::{self.name}"

    def over(self) -> list[str]:
        return [k for k, limit in LIMITS[self.lang].items() if self.measures.get(k, 0) > limit]


def _git_files(*patterns: str) -> list[str]:
    """Tracked files, plus untracked ones git does not ignore (new work)."""
    cmd = ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", *patterns]
    out = subprocess.run(cmd, cwd=ROOT, capture_output=True, check=True)
    return sorted({f for f in out.stdout.decode().split("\0") if f and (ROOT / f).is_file()})


def _value(message: str) -> int:
    m = MEASURE.search(message)
    if not m:
        raise RuntimeError(f"no measure in linter message: {message!r}")
    return int(m.group(1) or m.group(2))


def _merge(units: dict, unit: Unit) -> None:
    """Fold a measurement into ``units``; a key seen twice keeps the maximum."""
    have = units.setdefault(unit.key, unit)
    for k, v in unit.measures.items():
        have.measures[k] = max(have.measures.get(k, 0), v)


# -- python ----------------------------------------------------------------
def ruff_limits() -> dict:
    """The C901/PLR0912/PLR0915 limits ruff.toml sets for editors and ruff runs."""
    data = tomllib.loads((ROOT / "ruff.toml").read_text())
    lint = data.get("lint", {})
    return {k: lint.get(sec, {}).get(name) for k, (sec, name) in RUFF_SETTINGS.items()}


def qualnames(source: str) -> dict[int, str]:
    """Line of each ``def`` -> dotted name (Class.method, outer.inner)."""
    names: dict[int, str] = {}

    def visit(node, prefix: str) -> None:
        for child in ast.iter_child_nodes(node):
            if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                qual = f"{prefix}{child.name}"
                if not isinstance(child, ast.ClassDef):
                    names[child.lineno] = qual
                visit(child, qual + ".")
            else:
                visit(child, prefix)

    visit(ast.parse(source), "")
    return names


def ruff_issues(files: list[str]) -> list[dict]:
    measure_all = [f"lint.{sec}.{name} = 0" for sec, name in RUFF_SETTINGS.values()]
    cmd = ["ruff", "check", "--isolated", "--no-cache", "--ignore-noqa", "--exit-zero", "--output-format", "json",
           "--select", ",".join(RUFF_RULES)]
    for setting in measure_all:
        cmd += ["--config", setting]
    res = subprocess.run([*cmd, *files], cwd=ROOT, capture_output=True, check=True)
    return json.loads(res.stdout)


def measure_python(files: list[str] | None = None) -> list[Unit]:
    files = files if files is not None else _git_files("*.py")
    units: dict[str, Unit] = {}
    names: dict[str, dict[int, str]] = {}
    for issue in ruff_issues(files):
        rel = os.path.relpath(issue["filename"], ROOT)
        if rel not in names:
            names[rel] = qualnames((ROOT / rel).read_text(encoding="utf-8"))
        row = issue["location"]["row"]
        value = _value(issue["message"])
        unit = Unit("python", rel, names[rel].get(row, f"<line {row}>"), row, {RUFF_RULES[issue["code"]]: value})
        _merge(units, unit)
    return sorted(units.values(), key=lambda u: u.key)


# -- go --------------------------------------------------------------------
def go_modules() -> list[str]:
    return [str(Path(m).parent) for m in _git_files("go.mod", "*/go.mod") if not m.startswith("templates/")]


def go_func_name(line: str) -> str:
    m = GO_FUNC.match(line.strip())
    if not m:
        return "<unknown>"
    star, recv, name = m.groups()
    return f"({star}{recv}).{name}" if recv else name


def golangci_issues(module: str, goos: str) -> list[dict]:
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "issues.json"
        cmd = ["golangci-lint", "run", "--config", str(GO_CONFIG), "--issues-exit-code", "0", "--allow-parallel-runners",
               "--output.json.path", str(out), "--output.text.path", os.devnull, "./..."]
        env = {**os.environ, "GOOS": goos, "CGO_ENABLED": "0"}
        res = subprocess.run(cmd, cwd=ROOT / module, env=env, capture_output=True, text=True, check=False)
        if res.returncode != 0:
            raise RuntimeError(f"golangci-lint failed in {module} (GOOS={goos}):\n{res.stderr.strip()}")
        return json.loads(out.read_text()).get("Issues") or []


def _go_unit(issue: dict, lines: dict[str, list[str]]) -> Unit:
    rel, row = issue["Pos"]["Filename"], issue["Pos"]["Line"]
    if rel not in lines:
        lines[rel] = (ROOT / rel).read_text(encoding="utf-8").splitlines()
    value = _value(issue["Text"])
    return Unit("go", rel, go_func_name(lines[rel][row - 1]), row, {GO_LINTERS[issue["FromLinter"]]: value})


def measure_go(modules: list[str] | None = None) -> list[Unit]:
    jobs = [(m, goos) for m in (modules or go_modules()) for goos in GOOS_LIST]
    units: dict[str, Unit] = {}
    lines: dict[str, list[str]] = {}
    with ThreadPoolExecutor(max_workers=3) as pool:
        for issues in pool.map(lambda job: golangci_issues(*job), jobs):
            for issue in issues:
                _merge(units, _go_unit(issue, lines))
    return sorted(units.values(), key=lambda u: u.key)


def nolint_problems() -> list[str]:
    found = []
    for rel in _git_files("*.go"):
        for i, line in enumerate((ROOT / rel).read_text(encoding="utf-8").splitlines(), 1):
            if NOLINT.search(line):
                found.append(f"{rel}:{i}: //nolint hides a complexity linter; refactor instead")
    return found


# -- golangci exclusion blocks -----------------------------------------------
def go_source_regex(name: str) -> str:
    m = GO_KEY.match(name)
    if m:
        star, recv, method = m.groups()
        return rf"^func \((\w+ )?{re.escape(star)}{recv}(\[[^\]]*\])?\) {method}\b"
    return rf"^func {name}\b"


def render_block(module: str, keys: list[str]) -> str:
    out = [f"      {BEGIN}: generated from tools/ci/complexity-baseline-go.txt",
           "      # by tools/ci/complexity_polyglot.py --write-baseline; do not edit."]
    for key in keys:
        path, name = key.split("::", 1)
        rel = os.path.relpath(path, module).replace(".", r"\.")
        out += [f"      - path: ^{rel}$", f"        source: '{go_source_regex(name)}'",
                "        linters: [funlen, gocognit, gocyclo]"]
    out.append(f"      {END}")
    return "\n".join(out)


def _module_keys(module: str, base: dict) -> list[str]:
    return sorted(k for k in base if k.startswith(module + "/"))


def sync_go_configs(base: dict, write: bool) -> list[str]:
    """Check (or rewrite) each module's generated block and its limits."""
    problems = []
    pattern = re.compile(rf"^ *{re.escape(BEGIN)}.*?{re.escape(END)}$", re.DOTALL | re.MULTILINE)
    for module in go_modules():
        cfg = ROOT / module / ".golangci.yml"
        text = cfg.read_text() if cfg.exists() else ""
        want = render_block(module, _module_keys(module, base))
        current = pattern.search(text)
        problems += [f"{cfg.relative_to(ROOT)}: missing {s!r}" for s in _go_settings() if s not in text]
        if current is None:
            problems.append(f"{cfg.relative_to(ROOT)}: no '{BEGIN}' block")
        elif current.group(0) != want and write:
            cfg.write_text(text[: current.start()] + want + text[current.end() :])
        elif current.group(0) != want:
            problems.append(f"{cfg.relative_to(ROOT)}: exclusion block out of date; run --write-baseline")
    return problems


def _go_settings() -> list[str]:
    return [tmpl.format(LIMITS["go"][k]) for k, tmpl in GO_SETTINGS.items()]


# -- baseline ratchet ----------------------------------------------------------
def read_baseline(lang: str) -> dict[str, dict]:
    cols, base = list(LIMITS[lang]), {}
    path = BASELINES[lang]
    for line in path.read_text().splitlines() if path.exists() else []:
        if line.strip() and not line.startswith("#"):
            *values, key = line.split(None, len(cols))
            base[key] = {c: int(v) for c, v in zip(cols, values)}
    return base


def write_baseline(lang: str, units: list[Unit]) -> None:
    cols = list(LIMITS[lang])
    rows = [u for u in units if u.over()]
    lines = [
        "# Complexity ceilings per function, written by",
        f"#   tools/ci/complexity_polyglot.py --lang {lang} --write-baseline",
        f"# Columns: {' '.join(cols)} path::function. Limits: "
        + ", ".join(f"{k} {v}" for k, v in LIMITS[lang].items()) + ".",
        "# A row may only go down or go away; new functions must stay under the limits.",
    ]
    lines += [" ".join(f"{u.measures.get(c, 0):4d}" for c in cols) + f" {u.key}" for u in rows]
    BASELINES[lang].write_text("\n".join(lines) + "\n")
    print(f"wrote {len(rows)} complex {lang} functions to {BASELINES[lang].relative_to(ROOT)}")


def _unit_problem(u: Unit, base: dict) -> tuple[str | None, bool]:
    """(problem, improved) for one measured function against the baseline."""
    limits, over = LIMITS[u.lang], u.over()
    if u.key not in base:
        detail = ", ".join(f"{k}={u.measures[k]}>{limits[k]}" for k in over)
        return (f"{u.key}: new complex function ({detail})" if over else None), False
    ceil = base[u.key]
    worse = [k for k in limits if u.measures.get(k, 0) > max(ceil[k], limits[k])]
    if worse:
        detail = ", ".join(f"{k} {ceil[k]}->{u.measures[k]}" for k in worse)
        return f"{u.key}: worse on {detail}", False
    return None, any(u.measures.get(k, 0) < ceil[k] for k in limits)


def check(lang: str, units: list[Unit]) -> list[str]:
    base = read_baseline(lang)
    results = [_unit_problem(u, base) for u in units]
    problems = [p for p, _ in results if p]
    improved = sum(1 for _, better in results if better)
    complex_now = sum(1 for u in units if u.over())
    print(f"complexity[{lang}]: {len(units)} functions, {complex_now} over limits, baseline {len(base)}")
    if improved:
        print(f"{improved} baselined {lang} function(s) improved: run --write-baseline to ratchet down")
    return problems


def report(lang: str, units: list[Unit], top: int) -> None:
    cols = list(LIMITS[lang])
    print(f"[{lang}] " + " ".join(f"{c:>10}" for c in cols) + "  function")

    def excess(u: Unit) -> float:
        return max(u.measures.get(c, 0) / LIMITS[lang][c] for c in cols)

    for u in sorted(units, key=excess, reverse=True)[:top]:
        flag = "*" if u.over() else " "
        print("       " + " ".join(f"{u.measures.get(c, 0):10d}" for c in cols) + f" {flag}{u.key}:{u.line}")


def config_problems(lang: str, write: bool) -> list[str]:
    if lang == "python":
        got = ruff_limits()
        return [f"ruff.toml: {k} limit {got[k]} != {LIMITS['python'][k]}" for k in got if got[k] != LIMITS["python"][k]]
    return sync_go_configs(read_baseline("go"), write) + nolint_problems()


def warn_unpinned(lang: str) -> None:
    name, cmd, want = PINNED[lang]
    res = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if not re.search(rf"\b{re.escape(want)}\b", res.stdout):
        print(f"warning: {name} is not {want} (CI's pin); measures may differ: {res.stdout.strip()}", file=sys.stderr)


def run(lang: str, args) -> list[str]:
    warn_unpinned(lang)
    units = measure_python() if lang == "python" else measure_go()
    if args.report:
        report(lang, units, args.n)
        return []
    if args.write_baseline:
        write_baseline(lang, units)
        return config_problems(lang, write=True)
    return config_problems(lang, write=False) + check(lang, units)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--lang", choices=[*LIMITS, "all"], default="all")
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--write-baseline", action="store_true")
    ap.add_argument("-n", type=int, default=10)
    args = ap.parse_args()
    problems = []
    try:
        for lang in LIMITS if args.lang == "all" else [args.lang]:
            problems += run(lang, args)
    except (RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"complexity: measurement failed: {exc}", file=sys.stderr)
        return 2
    for p in problems:
        print(f"  {p}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
