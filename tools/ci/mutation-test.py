#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Mutation testing for the shell code base.

Line coverage says a line ran. A mutation score says whether the suite
would notice if that line were wrong. For every eligible line this plants
one small, plausible bug (a mutant): drop a regex anchor, flip an exit
code, swap a comparison. Then it runs the behavioural tests that exercise
the file. A mutant that no test fails on has *survived*: that behaviour is
unprotected.

    tools/ci/mutation-test.py --base origin/main --min-score 80   # PR gate
    tools/ci/mutation-test.py --full scripts/ops/rollback.sh       # one file
    tools/ci/mutation-test.py --list-mutants --full FILE           # dry run

Rules that keep the score honest:
  * one mutant per line (Google's model: more add noise, not signal);
  * kills only count from behavioural tests: a test that greps sources or
    lints declares `# test-kind: structural` in its first 30 lines (or
    lives under tests/structural/) and would "kill" any edit, so its kills
    are ignored, except on sources it names after `except`;
  * every selected test must pass on the unmutated tree first, or it is
    dropped and reported;
  * a mutant with no related test counts as survived;
  * a timeout counts as killed (the mutant hung the code), and is labelled.

A line that cannot be meaningfully mutated (an equivalent mutant) is
opted out in place with `# mutation: ignore <reason>`; the reason is
mandatory.
"""

from __future__ import annotations

import argparse
import concurrent.futures as cf
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path

# ---------------------------------------------------------------------------
# Operators. Order is priority: the first operator that applies to a line
# is the one mutant for that line. Each is (name, pattern, replacement,
# description). Patterns only match outside quoted strings.
# ---------------------------------------------------------------------------
OPERATORS: list[tuple[str, re.Pattern[str], str, str]] = [
    ("anchor", re.compile(r"=~ \^"), "=~ ", "drop the regex start anchor"),
    ("anchor", re.compile(r"=~ \(\^"), "=~ (", "drop the regex start anchor"),
    (
        "exit-code",
        re.compile(r"\breturn [1-9]\b"),
        "return 0",
        "failure return becomes success",
    ),
    (
        "exit-code",
        re.compile(r"\bexit [1-9][0-9]*\b"),
        "exit 0",
        "failure exit becomes success",
    ),
    ("negation", re.compile(r"\[\[ ! "), "[[ ", "drop a test negation"),
    ("negation", re.compile(r"\bif ! "), "if ", "drop a command negation"),
    ("equality", re.compile(r" != "), " == ", "!= becomes =="),
    ("equality", re.compile(r" == "), " != ", "== becomes !="),
    ("boundary", re.compile(r" -ge "), " -gt ", "-ge becomes -gt"),
    ("boundary", re.compile(r" -gt "), " -ge ", "-gt becomes -ge"),
    ("boundary", re.compile(r" -le "), " -lt ", "-le becomes -lt"),
    ("boundary", re.compile(r" -lt "), " -le ", "-lt becomes -le"),
    ("relation", re.compile(r" -eq "), " -ne ", "-eq becomes -ne"),
    ("relation", re.compile(r" -ne "), " -eq ", "-ne becomes -eq"),
    ("logic", re.compile(r" \|\| "), " && ", "|| becomes &&"),
    ("logic", re.compile(r" && "), " || ", "&& becomes ||"),
    ("arith", re.compile(r"\+ 1\b"), "+ 0", "increment dropped"),
    (
        "success",
        re.compile(r"\breturn 0\b"),
        "return 1",
        "success return becomes failure",
    ),
]

IGNORE_RE = re.compile(r"#\s*mutation:\s*ignore\b(.*)$")
HEREDOC_RE = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")
SHEBANG_RE = re.compile(r"^#!.*\b(ba)?sh\b")
NOOP_RHS_RE = re.compile(r"\s*(true|:)\s*($|[;)#&|])")
RESULTS_FAIL_RE = re.compile(r"^RESULTS:[0-9]+:[0-9]+:[1-9]", re.MULTILINE)


@dataclass
class Mutant:
    id: str
    path: str
    line: int
    operator: str
    description: str
    original: str
    mutated: str
    status: str = "pending"  # killed | timeout | survived | no-tests | ignored
    killer: str = ""
    tests_run: int = 0
    seconds: float = 0.0


@dataclass
class Report:
    mutants: list[Mutant] = field(default_factory=list)
    dropped_tests: dict[str, str] = field(default_factory=dict)
    ignored_without_reason: list[str] = field(default_factory=list)

    def counts(self) -> dict[str, int]:
        c: dict[str, int] = {}
        for m in self.mutants:
            c[m.status] = c.get(m.status, 0) + 1
        return c

    def score(self) -> float | None:
        c = self.counts()
        killed = c.get("killed", 0) + c.get("timeout", 0)
        total = killed + c.get("survived", 0) + c.get("no-tests", 0)
        return None if total == 0 else 100.0 * killed / total


# ---------------------------------------------------------------------------
# Mutant generation
# ---------------------------------------------------------------------------
def unquoted_spans(line: str) -> list[tuple[int, int]]:
    """Return [start, end) spans of `line` that are outside quotes and
    before an unquoted comment."""
    spans, start, i, quote = [], 0, 0, ""
    while i < len(line):
        ch = line[i]
        if quote:
            if ch == "\\" and quote == '"':
                i += 2
                continue
            if ch == quote:
                quote, start = "", i + 1
        elif ch == "\\":
            i += 2
            continue
        elif ch in "'\"":
            spans.append((start, i))
            quote = ch
        elif ch == "#" and (i == 0 or line[i - 1] in " \t;"):
            spans.append((start, i))
            return [s for s in spans if s[0] < s[1]]
        i += 1
    if not quote:
        spans.append((start, len(line)))
    return [s for s in spans if s[0] < s[1]]


def mutate_line(line: str) -> tuple[str, str, str] | None:
    """Return (operator, description, mutated_line) for the first operator
    that applies outside quotes, or None."""
    spans = unquoted_spans(line)
    for name, pat, repl, desc in OPERATORS:
        for s, e in spans:
            for m in pat.finditer(line, s, e):
                if name == "logic" and NOOP_RHS_RE.match(line, m.end()):
                    continue  # `x || true` vs `x && true`: equivalent
                return name, desc, line[: m.start()] + repl + line[m.end() :]
    return None


def is_shell_file(path: Path) -> bool:
    if path.suffix == ".tmpl":
        return False
    if path.suffix in (".sh", ".bash"):
        return True
    try:
        with path.open("rb") as fh:
            first = fh.readline(200).decode("utf-8", "replace")
    except OSError:
        return False
    return bool(SHEBANG_RE.match(first)) and "python" not in first


def eligible(rel: str, root: Path) -> bool:
    if rel.startswith(("tests/", "fuzz/", "docs/", "archive", ".github/")):
        return False
    p = root / rel
    return p.is_file() and is_shell_file(p)


def generate(
    root: Path, rel: str, lines: set[int] | None, report: Report
) -> list[Mutant]:
    text = (root / rel).read_text(encoding="utf-8", errors="replace").split("\n")
    out: list[Mutant] = []
    heredoc_end: str | None = None
    for n, line in enumerate(text, 1):
        if heredoc_end is not None:
            if line.strip() == heredoc_end:
                heredoc_end = None
            continue
        hd = HEREDOC_RE.search(line)
        stripped = line.strip()
        if n == 1 and stripped.startswith("#!"):
            continue
        if not stripped or stripped.startswith("#"):
            pass
        elif lines is None or n in lines:
            ig = IGNORE_RE.search(line)
            if ig:
                if not ig.group(1).strip():
                    report.ignored_without_reason.append(f"{rel}:{n}")
                else:
                    continue
            res = mutate_line(line)
            if res:
                op, desc, mutated = res
                mid = hashlib.sha1(f"{rel}:{n}:{op}".encode()).hexdigest()[:8]
                out.append(Mutant(mid, rel, n, op, desc, line, mutated))
        if hd and not re.search(r"<<<", line):
            heredoc_end = hd.group(2)
    return out


def changed_lines(root: Path, base: str) -> dict[str, set[int]]:
    diff = subprocess.run(
        [
            "git",
            "-C",
            str(root),
            "diff",
            "-U0",
            "--no-color",
            "--no-ext-diff",
            f"{base}...HEAD",
        ],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    res: dict[str, set[int]] = {}
    cur = None
    for ln in diff.splitlines():
        if ln.startswith("+++ "):
            cur = ln[6:] if ln.startswith("+++ b/") else None
            if cur is not None:
                res.setdefault(cur, set())
        elif ln.startswith("@@") and cur is not None:
            m = re.match(r"@@ -\S+ \+(\d+)(?:,(\d+))? @@", ln)
            if m:
                start, count = int(m.group(1)), int(m.group(2) or 1)
                res[cur].update(range(start, start + count))
    return {k: v for k, v in res.items() if v}


# ---------------------------------------------------------------------------
# Test selection
# ---------------------------------------------------------------------------
def needles_for(rel: str) -> list[str]:
    p = Path(rel)
    parts = p.parts
    out = {rel}
    if len(parts) >= 2:
        out.add("/".join(parts[-2:]))
    name = p.name
    if name.startswith("executable_"):
        deployed = name[len("executable_") :]
        out.update({f"bin/{deployed}", f"/{deployed}"})
    if len(parts) >= 2 and parts[-2] == "commands" and name.endswith(".sh"):
        cmd = name[:-3]
        out.update({f"dot {cmd}", f"cmd_{cmd}"})
    if rel == "bin/dot":
        out.add("bin/dot")
    return sorted(out)


def load_list(path: Path) -> list[str]:
    if not path.is_file():
        return []
    return [
        ln.split("#", 1)[0].strip()
        for ln in path.read_text().splitlines()
        if ln.split("#", 1)[0].strip()
    ]


def load_map(path: Path) -> dict[str, list[str]]:
    res: dict[str, list[str]] = {}
    for ln in load_list(path):
        key, *rest = ln.split()
        res.setdefault(key, []).extend(rest)
    return res


STRUCTURAL_MARKER_RE = re.compile(
    r"^#\s*test-kind:\s*structural\b(?:\s+except\s+(.+))?\s*$"
)


def structural_marker(text: str) -> tuple[bool, list[str]]:
    """(declared structural, sources it is still behavioural for)."""
    for ln in text.split("\n")[:30]:
        m = STRUCTURAL_MARKER_RE.match(ln.strip())
        if m:
            return True, (m.group(1) or "").split()
    return False, []


class TestIndex:
    def __init__(self, root: Path, extra: dict[str, list[str]]):
        self.root = root
        self.extra = extra
        self.files = sorted(
            str(p.relative_to(root))
            for p in (root / "tests").rglob("test_*.sh")
            if p.is_file() and "framework" not in p.parts and "fixtures" not in p.parts
        )
        self._text: dict[str, str] = {}

    def is_structural(self, t: str, rel: str) -> bool:
        if t.startswith("tests/structural/"):
            return True
        declared, behavioural_for = structural_marker(self.text(t))
        return declared and rel not in behavioural_for

    def text(self, t: str) -> str:
        if t not in self._text:
            self._text[t] = (self.root / t).read_text(
                encoding="utf-8", errors="replace"
            )
        return self._text[t]

    def related(self, rel: str) -> list[str]:
        needles = needles_for(rel)
        out = [t for t in self.files if any(n in self.text(t) for n in needles)]
        out += [t for t in self.extra.get(rel, []) if (self.root / t).is_file()]
        return sorted({t for t in out if not self.is_structural(t, rel)})


# ---------------------------------------------------------------------------
# Execution
# ---------------------------------------------------------------------------
def copy_tree(root: Path, dest: Path) -> None:
    files = subprocess.run(
        [
            "git",
            "-C",
            str(root),
            "ls-files",
            "-z",
            "--cached",
            "--others",
            "--exclude-standard",
        ],
        check=True,
        capture_output=True,
    ).stdout.split(b"\0")
    for f in files:
        if not f:
            continue
        rel = f.decode()
        src = root / rel
        if not src.exists() and not src.is_symlink():
            continue
        dst = dest / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        if src.is_symlink():
            os.symlink(os.readlink(src), dst)
        else:
            shutil.copy2(src, dst)
    subprocess.run(["git", "init", "-q", str(dest)], check=False)


def run_test(repo: Path, test: str, timeout: int) -> tuple[str, float]:
    """Run one test in a throwaway HOME. Returns (pass|fail|timeout, secs)."""
    home = Path(tempfile.mkdtemp(prefix="muthome."))
    for d in (".config", ".local/bin", ".cache", ".local/share", ".local/state"):
        (home / d).mkdir(parents=True, exist_ok=True)
    (home / ".dotfiles").symlink_to(repo)
    env = {
        "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        "HOME": str(home),
        "TMPDIR": str(home),
        "REPO_ROOT": str(repo),
        "TESTS_DIR": str(repo / "tests"),
        "FRAMEWORK_DIR": str(repo / "tests/framework"),
        "NO_COLOR": "1",
        "LANG": os.environ.get("LANG", "C.UTF-8"),
        "TERM": "dumb",
        "CI": "true",
    }
    t0 = time.monotonic()
    try:
        p = subprocess.run(
            ["bash", str(repo / test)],
            cwd=repo,
            env=env,
            stdin=subprocess.DEVNULL,
            check=False,
            capture_output=True,
            text=True,
            errors="replace",
            timeout=timeout,
            start_new_session=True,
        )
        failed = p.returncode != 0 or bool(RESULTS_FAIL_RE.search(p.stdout + p.stderr))
        verdict = "fail" if failed else "pass"
    except subprocess.TimeoutExpired:
        verdict = "timeout"
    finally:
        subprocess.run(
            ["chmod", "-R", "u+w", str(home)], capture_output=True, check=False
        )
        shutil.rmtree(home, ignore_errors=True)
    return verdict, time.monotonic() - t0


class Pool:
    """N private copies of the repo, handed out one per running mutant."""

    def __init__(self, root: Path, n: int, workdir: Path):
        self.free: list[Path] = []
        self.lock = threading.Lock()
        self.cv = threading.Condition(self.lock)
        for i in range(n):
            d = workdir / f"slot{i}"
            copy_tree(root, d)
            self.free.append(d)

    def acquire(self) -> Path:
        with self.cv:
            while not self.free:
                self.cv.wait()
            return self.free.pop()

    def release(self, d: Path) -> None:
        with self.cv:
            self.free.append(d)
            self.cv.notify()


def baseline(
    pool: Pool, tests: list[str], timeout: int, jobs: int, report: Report
) -> dict[str, float]:
    durations: dict[str, float] = {}

    def one(t: str) -> None:
        d = pool.acquire()
        try:
            verdict, secs = run_test(d, t, timeout)
        finally:
            pool.release(d)
        if verdict == "pass":
            durations[t] = secs
        else:
            report.dropped_tests[t] = f"{verdict} on the unmutated tree"

    with cf.ThreadPoolExecutor(jobs) as ex:
        list(ex.map(one, tests))
    return durations


def run_mutant(pool: Pool, m: Mutant, tests: list[str], timeout: int) -> None:
    d = pool.acquire()
    target = d / m.path
    original = target.read_bytes()
    t0 = time.monotonic()
    try:
        lines = original.decode("utf-8", "replace").split("\n")
        assert lines[m.line - 1] == m.original, f"{m.path}:{m.line} drifted"
        lines[m.line - 1] = m.mutated
        target.write_bytes("\n".join(lines).encode())
        m.status = "survived" if tests else "no-tests"
        for t in tests:
            m.tests_run += 1
            verdict, _ = run_test(d, t, timeout)
            if verdict != "pass":
                m.status = "killed" if verdict == "fail" else "timeout"
                m.killer = t
                break
    finally:
        target.write_bytes(original)
        m.seconds = round(time.monotonic() - t0, 1)
        pool.release(d)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def select_sample(mutants: list[Mutant], cap: int) -> list[Mutant]:
    if cap <= 0 or len(mutants) <= cap:
        return mutants
    return sorted(
        mutants, key=lambda m: hashlib.sha1(f"{m.path}:{m.line}".encode()).hexdigest()
    )[:cap]


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("files", nargs="*", help="limit to these repo-relative files")
    ap.add_argument("--root", default=".", help="repository root (default: .)")
    ap.add_argument("--base", help="mutate only lines changed since BASE (git ref)")
    ap.add_argument("--full", action="store_true", help="mutate every eligible line")
    ap.add_argument(
        "--min-score", type=float, default=0.0, help="fail below this score (percent)"
    )
    ap.add_argument(
        "--max-mutants", type=int, default=0, help="deterministic sample cap (0 = all)"
    )
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2) // 2))
    ap.add_argument("--timeout", type=int, default=180, help="seconds per test run")
    ap.add_argument("--json", help="write the full report here")
    ap.add_argument(
        "--github", action="store_true", help="emit GitHub annotations for survivors"
    )
    ap.add_argument(
        "--list-mutants", action="store_true", help="print mutants and exit"
    )
    args = ap.parse_args(argv)

    root = Path(args.root).resolve()
    if not args.base and not args.full:
        ap.error("pass --base REF (changed lines) or --full (every line)")
    report = Report()

    if args.base:
        scope = changed_lines(root, args.base)
        if args.files:
            scope = {k: v for k, v in scope.items() if k in args.files}
    else:
        if args.files:
            names = args.files
        else:
            names = subprocess.run(
                ["git", "-C", str(root), "ls-files"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.split()
        scope = {f: None for f in names}  # type: ignore[misc]
    scope = {f: ln for f, ln in scope.items() if eligible(f, root)}

    mutants: list[Mutant] = []
    for f in sorted(scope):
        mutants += generate(root, f, scope[f], report)
    if report.ignored_without_reason:
        for loc in report.ignored_without_reason:
            print(f"error: {loc}: '# mutation: ignore' needs a reason", file=sys.stderr)
        return 2
    mutants = select_sample(mutants, args.max_mutants)

    if args.list_mutants:
        for m in mutants:
            print(f"{m.path}:{m.line}\t{m.operator}\t{m.mutated.strip()}")
        return 0

    report.mutants = mutants
    if not mutants:
        print("mutation: no eligible mutants in scope")
        return _finish(report, args)

    extra = load_map(root / "tools/ci/mutation-map.txt")
    index = TestIndex(root, extra)
    per_file = {f: index.related(f) for f in {m.path for m in mutants}}
    all_tests = sorted({t for ts in per_file.values() for t in ts})
    print(
        f"mutation: {len(mutants)} mutants in {len(per_file)} files, {len(all_tests)} related tests"
    )

    with tempfile.TemporaryDirectory(prefix="mutation.") as wd:
        pool = Pool(root, args.jobs, Path(wd))
        durations = baseline(pool, all_tests, args.timeout, args.jobs, report)
        for t, why in sorted(report.dropped_tests.items()):
            print(f"  dropped {t}: {why}")
        ordered = {
            f: sorted((t for t in ts if t in durations), key=lambda t: durations[t])
            for f, ts in per_file.items()
        }
        done = 0
        lock = threading.Lock()

        def work(m: Mutant) -> None:
            nonlocal done
            run_mutant(pool, m, ordered[m.path], args.timeout)
            with lock:
                done += 1
                print(
                    f"  [{done}/{len(mutants)}] {m.status:9} {m.path}:{m.line} ({m.operator})",
                    flush=True,
                )

        with cf.ThreadPoolExecutor(args.jobs) as ex:
            list(ex.map(work, mutants))

    return _finish(report, args)


def _finish(report: Report, args: argparse.Namespace) -> int:
    c = report.counts()
    score = report.score()
    survivors = [m for m in report.mutants if m.status in ("survived", "no-tests")]
    for m in sorted(survivors, key=lambda m: (m.path, m.line)):
        print(f"SURVIVED {m.path}:{m.line} [{m.operator}] {m.description}")
        print(f"   - {m.original.strip()}")
        print(
            f"   + {m.mutated.strip()}"
            + ("   (no related tests)" if m.status == "no-tests" else "")
        )
        if args.github:
            msg = f"{m.description}: `{m.mutated.strip()}` passes every related test"
            if m.status == "no-tests":
                msg = f"{m.description}: no behavioural test exercises this file"
            print(
                f"::error file={m.path},line={m.line},title=Surviving mutant ({m.operator})::{msg}"
            )
    shown = "n/a" if score is None else f"{score:.1f}%"
    print(
        f"mutation score: {shown}  killed={c.get('killed', 0)} timeout={c.get('timeout', 0)} "
        f"survived={c.get('survived', 0)} no-tests={c.get('no-tests', 0)}"
    )
    if args.json:
        Path(args.json).write_text(
            json.dumps(
                {
                    "score": score,
                    "counts": c,
                    "dropped_tests": report.dropped_tests,
                    "mutants": [asdict(m) for m in report.mutants],
                },
                indent=2,
            )
        )
    if score is not None and score < args.min_score:
        print(
            f"mutation: score {score:.1f}% is below the {args.min_score:g}% gate",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
