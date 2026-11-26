# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""The Python half of vibe-delegate, one subcommand per step of a run.

    run SECONDS SCRIPT   run SCRIPT in a pseudo-TTY, stopped after SECONDS
    stream STATS         print vibe's streamed JSON as readable lines
    tokens LOG STATS     token counts and cost from a vibe session log
    syntax COUNT         syntax-check the changed files listed on stdin
    log                  append the run to ~/.local/share/dotfiles-ai.db

vibe checks for a TTY on startup and hangs without one, so `run` gives it
a pseudo-TTY. It also bounds the run itself (exit 124 on expiry, the whole
process group killed), so vibe-delegate needs neither timeout(1), which
macOS before 27 does not ship, nor perl.
"""

from __future__ import annotations

import json
import os
import pty
import re
import select
import shutil
import signal
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

TIMED_OUT = 124


# ── run ────────────────────────────────────────────────────────────────────
def _exit_code(status: int) -> int:
    code = os.waitstatus_to_exitcode(status)
    return 128 - code if code < 0 else code


def _relay(fd: int, deadline: float) -> bool:
    """Copy the child's output to stdout until EOF; False at the deadline."""
    while True:
        left = deadline - time.monotonic()
        if left <= 0:
            return False
        ready, _, _ = select.select([fd], [], [], min(left, 1.0))
        if not ready:
            continue
        try:
            data = os.read(fd, 4096)
        except OSError:  # EIO: the child closed the terminal
            data = b""
        if not data:
            return True
        os.write(sys.stdout.fileno(), data)


def run(seconds: float, argv: list[str]) -> int:
    pid, fd = pty.fork()
    if pid == 0:
        try:
            os.execvp(argv[0], argv)
        finally:
            os._exit(127)
    finished = _relay(fd, time.monotonic() + seconds)
    if not finished:
        os.killpg(pid, signal.SIGKILL)  # pty.fork made the child a session leader
    _, status = os.waitpid(pid, 0)
    os.close(fd)
    return _exit_code(status) if finished else TIMED_OUT


# ── stream ─────────────────────────────────────────────────────────────────
ANSI_RE = re.compile(r"\x1b\[[0-9;]*[mABCDEFGHJKSTfhilmnprsu]|\x1b\([AB]|\x0f|\x0e")


def _clean(line: str) -> str:
    return ANSI_RE.sub("", line.replace("\r", "")).strip()


def _tool_line(msg: dict, stats: dict) -> str:
    """The display line for one tool message; counts warnings and failures."""
    content = msg.get("content", "") or ""
    first = content.split("\n")[0]
    name = (msg.get("tool", "") or msg.get("name", "")).lower()
    if "write" in name or "edit" in name:
        path = msg.get("path") or msg.get("file_path") or ""
        return f"  [tool]  file: {path or first[:80]}"
    if first.startswith("path:"):
        return f"  [read]  {first[5:].strip()}"
    if "search_replace" in name or "SEARCH" in content:
        failed = "failed" in content.lower()
        stats["search_replace_fails"] += failed
        return f"  [tool]  search_replace [{'FAIL' if failed else 'OK'}] {first[:80]}"
    if first.startswith("error") or "Error" in first or "failed" in first.lower():
        stats["warn_count"] += 1
        return f"  [WARN]  {first[:120]}"
    if "matches:" in first or "grep" in name:
        return f"  [tool]  matches: {first[:100]}"
    if "command" in name:
        return f"  [tool]  command: {first[:100]}"
    return f"  [tool]  {(first or content)[:100]}"


def _message_line(msg: dict, stats: dict) -> str | None:
    role = msg.get("role", "")
    if role == "assistant":
        text = (msg.get("content", "") or "").strip()
        return f"  [vibe] {text[:400]}" if text else None
    if role == "tool":
        stats["tool_calls"] += 1
        return _tool_line(msg, stats)
    return None


def _parse(line: str) -> dict | None:
    try:
        msg = json.loads(line)
    except json.JSONDecodeError:
        return None
    return msg if isinstance(msg, dict) else None


def stream(stats_file: str, lines) -> int:
    stats = {"tool_calls": 0, "warn_count": 0, "search_replace_fails": 0}
    for raw in lines:
        msg = _parse(_clean(raw))
        shown = _message_line(msg, stats) if msg else None
        if shown:
            print(shown, flush=True)
    print(
        f"Tool calls: {stats['tool_calls']}  |  warns: {stats['warn_count']}"
        f"  |  sr_fails: {stats['search_replace_fails']}"
    )
    Path(stats_file).write_text(json.dumps(stats))
    return 0


# ── tokens ─────────────────────────────────────────────────────────────────
DEFAULT_PRICES = (1.5, 7.5)  # Mistral Medium 3.5, per million tokens in/out
CLAUDE_PRICES = (3.0, 15.0)  # Claude Sonnet 4.6, the comparison


def _prices(model: str) -> tuple[float, float]:
    """Per-model prices from ~/.vibe/config.toml, else the defaults."""
    try:
        import tomllib

        cfg = tomllib.loads(Path("~/.vibe/config.toml").expanduser().read_text())
    except (ImportError, OSError, ValueError):
        return DEFAULT_PRICES
    for m in cfg.get("models", []):
        if model in (m.get("alias"), m.get("name")):
            return m.get("input_price", DEFAULT_PRICES[0]), m.get(
                "output_price", DEFAULT_PRICES[1]
            )
    return DEFAULT_PRICES


def _run_tokens(stats: dict) -> tuple[int, int, int, int, int]:
    """(run total, in, out, last-turn prompt, last-turn completion).

    Each -p invocation is a new session, so session_total_llm_tokens is the
    run's total; last_turn_* covers only the final exchange, which
    undercounts a multi-turn run. Its in/out split is applied to the total.
    """
    prompt = stats.get("last_turn_prompt_tokens", 0)
    completion = stats.get("last_turn_completion_tokens", 0)
    total = stats.get("last_turn_total_tokens", prompt + completion)
    session = stats.get("session_total_llm_tokens", 0)
    run_total = session if session > 0 else total
    if prompt + completion > 0 and run_total > 0:
        tokens_in = round(run_total * prompt / (prompt + completion))
        return run_total, tokens_in, run_total - tokens_in, prompt, completion
    return run_total, prompt, completion, prompt, completion


def _cost(tokens_in: int, tokens_out: int, prices: tuple[float, float]) -> float:
    return (tokens_in * prices[0] + tokens_out * prices[1]) / 1_000_000


def tokens(session_log: str, stats_file: str) -> int:
    try:
        data = json.loads(Path(session_log).read_text())
    except (OSError, ValueError) as e:
        print(f"(token read failed: {e})")
        return 0
    model = data.get("config", {}).get("active_model", "unknown")
    run_total, t_in, t_out, prompt, completion = _run_tokens(data.get("stats", {}))
    run_cost = _cost(t_in, t_out, _prices(model))
    claude = _cost(t_in, t_out, CLAUDE_PRICES)
    print(f"Model               : {model}")
    print(
        f"Delegate tokens (run): {run_total:,}  (last turn: {prompt:,}+{completion:,})"
        f"  |  cost ~${run_cost:.4f}"
    )
    if run_cost > 0:
        print(
            f"Claude Sonnet 4.6 eq: same tokens would cost ~${claude:.4f}"
            f"  (ratio x{claude / run_cost:.1f})"
        )
    else:
        print(f"Claude Sonnet 4.6 eq: ~${claude:.4f}")
    merged = _read_json(stats_file)
    merged.update(
        tokens_in=t_in,
        tokens_out=t_out,
        tokens_total=run_total,
        cost_usd=round(run_cost, 6),
        model=model,
    )
    Path(stats_file).write_text(json.dumps(merged))
    return 0


def _read_json(path: str) -> dict:
    try:
        data = json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


# ── syntax ─────────────────────────────────────────────────────────────────
# Per-file checks: (suffixes, command before the file, tool that must exist).
FILE_CHECKS = [
    ((".py",), ["python3", "-m", "py_compile"], None),
    ((".js", ".mjs", ".cjs"), ["node", "--check"], "node"),
    ((".rb",), ["ruby", "-c"], "ruby"),
    ((".sh", ".bash"), ["bash", "-n"], None),
    ((".php",), ["php", "-l"], "php"),
    (
        (".json",),
        ["python3", "-c", "import json,sys;json.load(open(sys.argv[1]))"],
        None,
    ),
]
# Project checks, run once when a file with one of the suffixes changed.
PROJECT_CHECKS = [
    ((".go",), ["go", "vet", "./..."], "go", "go vet"),
    ((".rs",), ["cargo", "check", "--quiet"], "cargo", "cargo check"),
]


class Checker:
    def __init__(self) -> None:
        self.checked = 0
        self.errors = 0

    def check(self, cmd: list[str], label: str) -> None:
        r = subprocess.run(cmd, capture_output=True, text=True, check=False)
        self.checked += 1
        if r.returncode != 0:
            self.errors += 1
            msg = (r.stderr or r.stdout).strip().split("\n")[0][:120]
            print(f"  [SYNTAX ERROR] {label}: {msg}")


def _file_check(path: str):
    for suffixes, cmd, tool in FILE_CHECKS:
        if path.endswith(suffixes) and (tool is None or shutil.which(tool)):
            return [*cmd, path]
    return None


def _project_checks(live: list[str], checker: Checker) -> None:
    for suffixes, cmd, tool, label in PROJECT_CHECKS:
        if any(f.endswith(suffixes) for f in live) and shutil.which(tool):
            checker.check(cmd, label)
    if not any(f.endswith((".ts", ".tsx")) for f in live):
        return
    if shutil.which("tsc") and os.path.isfile("tsconfig.json"):
        checker.check(["tsc", "--noEmit", "--skipLibCheck"], "tsc --noEmit")
    else:
        print("  [SKIP] tsc — no tsconfig.json found, TypeScript not checked")


def syntax(count_file: str, lines) -> int:
    """Check the changed files (one per line, relative to the cwd)."""
    live = [f for f in (ln.strip() for ln in lines) if f and os.path.isfile(f)]
    checker = Checker()
    for path in live:
        cmd = _file_check(path)
        if cmd:
            checker.check(cmd, path)
    _project_checks(live, checker)
    if checker.checked and checker.errors:
        print(
            f"=== SYNTAX ERRORS: {checker.errors} in {checker.checked} check(s)"
            " — fix before committing ==="
        )
    elif checker.checked:
        print(f"=== SYNTAX OK ({checker.checked} check(s)) ===")
    Path(count_file).write_text(str(checker.errors))
    return 0


# ── log ────────────────────────────────────────────────────────────────────
COLUMNS = (
    ("ts", str),
    ("delegate", str),
    ("model", str),
    ("project", str),
    ("workdir", str),
    ("agent", str),
    ("max_turns", int),
    ("timeout_secs", int),
    ("exit_code", int),
    ("timed_out", bool),
    ("duration_secs", float),
    ("prompt_words", int),
    ("tool_calls", int),
    ("files_changed", int),
    ("wrote_nothing", bool),
    ("warn_count", int),
    ("search_replace_fails", int),
    ("syntax_errors", int),
    ("tokens_in", int),
    ("tokens_out", int),
    ("tokens_total", int),
    ("cost_usd", float),
    ("cost_claude_eq", float),
)
SCHEMA = """CREATE TABLE IF NOT EXISTS runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT NOT NULL DEFAULT "", delegate TEXT NOT NULL DEFAULT "",
    model TEXT NOT NULL DEFAULT "", project TEXT NOT NULL DEFAULT "",
    workdir TEXT DEFAULT "", agent TEXT DEFAULT "default",
    max_turns INTEGER DEFAULT 0, timeout_secs INTEGER DEFAULT 0,
    exit_code INTEGER DEFAULT 0, timed_out INTEGER DEFAULT 0,
    duration_secs REAL DEFAULT 0, prompt_words INTEGER DEFAULT 0,
    tool_calls INTEGER DEFAULT 0, files_changed INTEGER DEFAULT 0,
    wrote_nothing INTEGER DEFAULT 0, warn_count INTEGER DEFAULT 0,
    search_replace_fails INTEGER DEFAULT 0, syntax_errors INTEGER DEFAULT 0,
    tokens_in INTEGER DEFAULT 0, tokens_out INTEGER DEFAULT 0,
    tokens_total INTEGER DEFAULT 0, cost_usd REAL DEFAULT 0,
    cost_claude_eq REAL DEFAULT 0
)"""
INSERT = (
    f"INSERT INTO runs ({','.join(c for c, _ in COLUMNS)}) "
    f"VALUES ({','.join('?' * len(COLUMNS))})"
)
# Read-only agents never write files, so "wrote nothing" is not news there.
READONLY_AGENTS = ("code-reviewer", "code-architect", "planner")


def _row(entry: dict) -> tuple:
    """The INSERT values: missing fields are 0, "" or, for agent, "default"."""

    def cast(col, kind):
        value = entry.get(col) or ("default" if col == "agent" else None)
        if kind is bool:
            return int(bool(value))
        return kind(value or kind())

    return tuple(cast(col, kind) for col, kind in COLUMNS)


def _env_int(name: str) -> int:
    try:
        return int(os.environ.get(name, "") or 0)
    except ValueError:
        return 0


def _entry(stats: dict) -> dict:
    env = os.environ.get
    start, end = _env_int("DELEGATE_START_NS"), _env_int("DELEGATE_END_NS")
    entry = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "delegate": env("DELEGATE_NAME", "vibe"),
        "workdir": env("DELEGATE_WORKDIR", ""),
        "project": os.path.basename(env("DELEGATE_WORKDIR", "")),
        "prompt_words": _env_int("DELEGATE_PROMPT_WORDS"),
        "agent": env("DELEGATE_AGENT", "default"),
        "max_turns": _env_int("DELEGATE_MAX_TURNS"),
        "timeout_secs": _env_int("DELEGATE_TIMEOUT"),
        "exit_code": _env_int("DELEGATE_EXIT"),
        "timed_out": env("DELEGATE_EXIT") == str(TIMED_OUT),
        "files_changed": _env_int("DELEGATE_FILES_CHANGED"),
        "syntax_errors": _env_int("DELEGATE_SYNTAX_ERRORS"),
        "duration_secs": round((end - start) / 1e9, 1) if start and end else 0,
        "warn_count": stats.get("warn_count", 0),
        "search_replace_fails": stats.get("search_replace_fails", 0),
    }
    entry.update(stats)
    entry["cost_claude_eq"] = round(
        _cost(entry.get("tokens_in", 0), entry.get("tokens_out", 0), CLAUDE_PRICES), 6
    )
    # Tool calls but no file written: a vague prompt, or the work was done.
    entry["wrote_nothing"] = (
        entry.get("files_changed", 0) == 0
        and entry.get("tool_calls", 0) >= 3
        and entry.get("exit_code", 0) == 0
        and entry.get("agent", "default") not in READONLY_AGENTS
    )
    return entry


def _migrate_jsonl(db: sqlite3.Connection, jsonl: Path) -> None:
    """Import the old JSONL run log once."""
    if db.execute("SELECT 1 FROM _meta WHERE key='jsonl_migrated'").fetchone():
        return
    lines = jsonl.read_text().splitlines() if jsonl.exists() else []
    for line in lines:
        record = _parse(line.strip()) if line.strip() else None
        if record is None:
            continue
        try:
            db.execute(INSERT, _row(record))
        except (TypeError, ValueError, sqlite3.Error):
            continue
    db.execute("INSERT OR REPLACE INTO _meta VALUES ('jsonl_migrated','1')")


def log(stats_file: str) -> int:
    share = Path.home() / ".local" / "share"
    db_path = share / "dotfiles-ai.db"
    share.mkdir(parents=True, exist_ok=True)
    entry = _entry(_read_json(stats_file))
    db = sqlite3.connect(str(db_path), timeout=10, isolation_level=None)
    db.execute("PRAGMA journal_mode=WAL")
    db.execute("PRAGMA synchronous=NORMAL")
    db.execute(SCHEMA)
    db.execute("CREATE TABLE IF NOT EXISTS _meta (key TEXT PRIMARY KEY, value TEXT)")
    _migrate_jsonl(db, share / "delegate-runs.jsonl")
    db.execute(INSERT, _row(entry))
    db.close()
    saved = entry["cost_claude_eq"] - entry.get("cost_usd", 0)
    saved_str = f", saved ~${saved:.4f} vs Claude" if saved > 0 else ""
    print(
        f"[log] → {db_path}  ({entry.get('tokens_total', '?')} tokens,"
        f" exit {entry['exit_code']}, {entry['duration_secs']}s{saved_str})"
    )
    return 0


# ── entry point ────────────────────────────────────────────────────────────
def main(argv: list[str]) -> int:
    commands = {
        "run": lambda a: run(float(a[0]), a[1:]),
        "stream": lambda a: stream(a[0], sys.stdin),
        "tokens": lambda a: tokens(a[0], a[1]),
        "syntax": lambda a: syntax(a[0], sys.stdin),
        "log": lambda a: log(a[0]),
    }
    if not argv or argv[0] not in commands:
        print(
            f"usage: vibe_delegate.py {{{'|'.join(commands)}}} ARGS...", file=sys.stderr
        )
        return 2
    return commands[argv[0]](argv[1:])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
