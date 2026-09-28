#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Usage: coverage_aggregate.py <lcov.info> <trace-dir> <repo-root> <include-dirs>
# Called by tools/ci/run-coverage.sh; the exit status reports truncated
# trace records for measured files.
"""Aggregate bash xtrace output into lcov.info."""
import os
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

out_path, trace_dir, repo_root, include_dirs_spec = sys.argv[1:5]
include_dirs = [Path(p).resolve() for p in include_dirs_spec.split(":") if p]
trace_dir = Path(trace_dir)
repo_root = Path(repo_root).resolve()

# -----------------------------------------------------------------------------
# Skip-list — paths (relative to repo_root) that the xtrace mechanism
# cannot measure meaningfully in our sandbox. Listed once at the
# aggregator level so individual scripts don't need to be peppered with
# LCOV_EXCL_START/STOP markers. Categories:
#   1. Interactive / animation scripts (matrix, pipes, banner, cmatrix,
#      stopwatch, rainbow, ql) — require a TTY + user input; the
#      function body never returns to xtrace within a test budget.
#   2. Self-reference — run-coverage.sh is the runner itself; the
#      runner traces other scripts but not itself.
#   3. CI-only entry points that mutate real environments (pre-push,
#      release, install, bump, lint, check-deps-dev, validate-ci-config,
#      reliability-audit, coverage-baseline, lint-reusable-pins).
#   4. Top-level system-mutation scripts that need real OS state
#      (rebuild-themes scans wallpapers; apply-gnome-theme drives
#      gsettings; wallpaper-sync pulls from a remote; build-manual
#      shells out to pandoc; chaos.sh and record.sh produce side
#      effects we can't fake under bash xtrace).
# Files here are entirely removed from the lcov denominator (no SF:
# entry emitted). The covered code in the *rest* of the repo is the
# meaningful denominator.
# -----------------------------------------------------------------------------
SKIP_PATHS = {
    # Interactive / animation — require a TTY + user input.
    "defaults/.chezmoitemplates/functions/interactive/matrix.sh",
    "defaults/.chezmoitemplates/functions/interactive/cmatrix.sh",
    "defaults/.chezmoitemplates/functions/interactive/stopwatch.sh",
    "defaults/.chezmoitemplates/functions/interactive/banner.sh",
    "defaults/.chezmoitemplates/functions/interactive/rainbow.sh",
    "defaults/.chezmoitemplates/functions/interactive/pipes.sh",
    "defaults/.chezmoitemplates/functions/misc/pipes.sh",
    "defaults/.chezmoitemplates/functions/misc/view-source.sh",
    "defaults/.chezmoitemplates/functions/misc/caffeine.sh",   # daemon controller, real /tmp/lock
    "defaults/.chezmoitemplates/functions/nav/ql.sh",
    "scripts/tools/pipes.sh",
    "scripts/tools/cmatrix.sh",
    "scripts/demo/record.sh",
    "defaults/dot_local/bin/executable_tmux-sessionizer",
    "defaults/dot_local/bin/executable_myip",
    "defaults/dot_local/bin/executable_tour",                  # requires TTY + gum
    # Self-reference + CI gates
    "tools/ci/run-coverage.sh",
    "tools/ci/check-deps-dev.sh",
    "tools/ci/lint-reusable-pins.sh",
    "tools/ci/validate-chezmoidata.sh",
    "tools/ci/validate-ci-config.sh",
    "tools/ci/check-dangerous-chmod.sh",
    "scripts/git-hooks/pre-push",
    "scripts/qa/reliability-audit.sh",
    "scripts/qa/coverage-baseline.sh",
    "scripts/dot/commands/lint.sh",
    # System mutation — drives real OS state we can't fake under xtrace.
    "scripts/theme/rebuild-themes.sh",
    "scripts/theme/apply-gnome-theme.sh",
    "scripts/theme/wallpaper-sync.sh",
    "scripts/theme/install-catppuccin-themes.sh",
    "scripts/ops/chaos.sh",
    "scripts/ops/release.sh",
    "scripts/ops/heal-tools.sh",
    "scripts/ops/chezmoi-apply.sh",
    "tools/docs/build-manual.sh",
    "scripts/security/manage-secrets.sh",
    "scripts/security/enforce-policies.sh",
    "scripts/security/ssh-cert.sh",
    "scripts/security/firewall.sh",
    "scripts/lib/secrets_provider.sh",                # keychain/gpg/age bindings
    "scripts/ops/setup.sh",                           # post-install bootstrap
    "scripts/theme/wallpaper-rotate.sh",              # cron-driven wallpaper change
    "scripts/git-hooks/pre-commit-audit.sh",          # full hook flow needs real index
    "bin/dot-theme-sync",        # signals live apps
    "bin/dot-bootstrap",
    "defaults/dot_local/bin/executable_update",
    "defaults/dot_local/bin/executable_ai_core",
    "defaults/dot_local/bin/executable_ai-update",
}

def is_skipped(abs_path: Path) -> bool:
    try:
        rel = abs_path.resolve().relative_to(repo_root).as_posix()
    except ValueError:
        return False
    return rel in SKIP_PATHS

# Bash adds one xtrace prefix for each nested execution context. Count both
# top-level `+@COV@` records and `++@COV@`/`+++@COV@` records emitted from
# functions inside command substitutions and subshells.
# `[^:]*` (not `[^:]+`): a `bash -c` top level has no BASH_SOURCE[0], so
# the field is legitimately empty. Those records name no file and are
# skipped below — but they must still MATCH here, or the truncation audit
# would mistake every one of them for a mangled record.
hit_re = re.compile(r"^\++@COV@:(\d+):([^:]*):@")

# A record that starts like ours but has lost its `:@ ` terminator was
# truncated in flight — bash 3.2 cuts the expanded PS4 at 100 characters.
# Such a record is silently unusable, which is exactly the failure mode
# this runner must never have, so they are counted and reported.
record_head_re = re.compile(r"^\++@COV@:(\d+):(.*)$")
truncated_records = Counter()
truncated_by_trace = Counter()

# raw_hits[abs_path][line] = total trace records seen for that physical line
raw_hits = defaultdict(lambda: defaultdict(int))
source_cache = {}

def in_includes(path: Path) -> bool:
    try:
        rp = path.resolve()
    except (OSError, RuntimeError):
        return False
    for inc in include_dirs:
        try:
            rp.relative_to(inc)
            return True
        except ValueError:
            continue
    return False

def normalized_source(src: str):
    """Resolve and classify each distinct xtrace source path once."""
    if src in source_cache:
        return source_cache[src]
    src_path = Path(src)
    if not src_path.is_absolute():
        src_path = repo_root / src_path
    try:
        src_path = src_path.resolve()
    except (OSError, RuntimeError):
        pass
    result = str(src_path) if in_includes(src_path) and not is_skipped(src_path) else None
    source_cache[src] = result
    return result

# Parse every trace file. Each trace can be MBs; iterate line by line.
for trace_path in sorted(trace_dir.glob("*.trace")):
    try:
        with open(trace_path, "r", errors="replace") as f:
            for line in f:
                m = hit_re.match(line)
                if not m:
                    head = record_head_re.match(line)
                    if head:
                        truncated_records[head.group(2)[:80]] += 1
                        truncated_by_trace[trace_path.name] += 1
                    continue
                lineno = int(m.group(1))
                src = m.group(2).strip()
                if not src or src == "main":
                    continue
                # Resolve once per distinct source string. Trace files can
                # contain millions of records but only hundreds of sources.
                # Caching avoids repeated filesystem resolution while still
                # collapsing `..` paths into one canonical lcov SF entry.
                source_path = normalized_source(src)
                if source_path is None:
                    continue
                raw_hits[source_path][lineno] += 1
    except OSError as e:
        print(f"warn: read error {trace_path}: {e}", file=sys.stderr)

# -----------------------------------------------------------------------------
# Source analysis — which physical lines can bash xtrace ever report, and
# which physical line does it report a multi-line statement on?
#
# `set -x` does NOT emit a record for every line that runs. Several
# constructs execute perfectly well and never produce a `+@COV@:` record at
# their own line number, so counting them as "executable" put permanently
# unhittable lines in the denominator and capped per-file coverage well
# below 100%. Every exclusion below was established by running a fixture
# under this runner's own PS4 + `set -x` and observing that no record
# appears for the line; the fixtures live in
# tests/unit/ci/test_run_coverage_aggregator.sh and are asserted on every
# run so this classifier cannot silently drift.
#
# Observed (bash 5.3, and the same on 5.2):
#
#   1. Function-definition headers. `greet() {`, `greet()` + `{` on the
#      next line, and `function greet {` all emit nothing; only the body
#      is traced. A one-line definition (`f() { echo hi; }`) IS traced,
#      because the body is on that line — so it stays in the denominator.
#
#   2. `case` pattern labels. `a | x)`, `"hello world")`, `'')` and `*)`
#      emit nothing even when the arm matches; the arm's body is what
#      gets traced. The old `case_pattern` regex only recognised bare
#      `foo)`, so every label with alternation, quoting or a space was
#      still counted. A label with its body on the same line
#      (`x) echo x ;;`) IS traced and stays.
#
#   3. Interior lines of a multi-line *word*: an unterminated `$( )`,
#      `<( )`, `>( )`, backtick, `name=( )` array assignment, `$(( ))`,
#      or an unterminated quoted string. Nothing inside is ever reported
#      at its own line; bash attributes the whole statement to ONE
#      physical line of the construct — sometimes the first, sometimes
#      the last:
#
#        a=$(          -> record lands on the closing `)` line
#          echo A
#        )
#        echo "$(      -> record lands on the `echo` line
#          echo B
#        )"
#
#      Guessing which end would risk dropping a genuinely covered line,
#      so instead the statement is *folded*: the first physical line is
#      the single denominator entry, and a record on any later physical
#      line of the same statement counts as a hit on it (`alias` below).
#      That is exact — one logical statement, one denominator slot, hit
#      iff bash traced it anywhere — and needs no guess.
#
#   4. Backslash-continuation lines that carry only more words of the
#      same command (`printf '%s' \` / `"one" \` / `"two"`): only the
#      first line is traced. But a continuation that STARTS a new
#      command is traced at its own line (`true && \` / `  echo x`, or
#      `cmd \` / `  || echo fallback`), so those are kept. The
#      discriminator is an operator at the head of the continuation or
#      at the tail of the line before it.
#
#   5. Compound terminators carrying only a redirection: `done <"$f"`,
#      `fi >/dev/null`, `} >/dev/null` emit nothing — the redirection is
#      set up by the compound command, which was already traced at its
#      head. `done | cat` IS traced (the pipeline's next element runs
#      there) and `done < <(cmd)` IS traced (the process substitution's
#      body runs there), so both stay.
#
# Deliberately NOT excluded — see the report in #883 for the evidence:
#   * `(` / `)` of a bare subshell group and `{` / `}` of a brace group:
#     already dropped by the structural rule, and the statements INSIDE
#     such a group are traced at their own lines, so they stay.
#   * Lines that are merely untested (an `if` branch never taken, a
#     function never called). Those are the thing coverage is for.
#   * `x) ;;` — a case label with an empty body on the same line emits
#     nothing, but the shape is indistinguishable from `x) cmd ;;`
#     without a real parser. Left in the denominator; it understates.
# -----------------------------------------------------------------------------
heredoc_re = re.compile(
    r"""<<(-?)\s*(?:"([^"]*)"|'([^']*)'|\\?([A-Za-z_][A-Za-z0-9_.\-]*))"""
)
excl_line_re = re.compile(r"#\s*LCOV_EXCL_LINE")
excl_start_re = re.compile(r"#\s*LCOV_EXCL_START")
excl_stop_re = re.compile(r"#\s*LCOV_EXCL_STOP")
# Scripts that explicitly turn off xtrace can't be measured by this
# mechanism — the bash runtime simply stops emitting trace records.
# Treat everything after `set +x` / `set +o xtrace` as excluded so it
# doesn't sink the denominator.
xtrace_off_re = re.compile(r"^\s*set\s+(\+x|\+o\s+xtrace)\b")
structural_re = re.compile(
    r"^\s*("
    r"fi|done|else|elif|esac|then|do|in|"
    r"\}|\{|\(|"
    r"\)\s*;?;?\s*$|"  # bare `)` (subshell / case-pattern close)
    r";;&?\s*$|"       # `;;` / `;;&` case-clause terminators
    r";&\s*$"          # `;&` fallthrough terminator
    r")\s*(#.*)?$"
)
func_hdr_re = re.compile(
    r"^\s*(function\s+)?[A-Za-z_][A-Za-z0-9_:.+\-]*\s*\(\s*\)\s*(\{\s*)?(#.*)?$"
)
func_hdr_kw_re = re.compile(
    r"^\s*function\s+[A-Za-z_][A-Za-z0-9_:.+\-]*\s*(\{\s*)?(#.*)?$"
)
case_open_re = re.compile(r"^\s*case\b")
esac_re = re.compile(r"^\s*esac\b")
terminator_redir_re = re.compile(
    r"^\s*(done|fi|esac|\}|\))\s+(?P<rest>[0-9]*[<>].*)$"
)
cont_op_head_re = re.compile(r"^\s*(\|\||&&|\||;;?|&)")
# A backslash-continued command whose continuation begins with `&&` or
# `||` is attributed to the OPERATOR line, not its own, on bash 5.2 —
# and to its own line on 5.3. See the note in classify().
cont_andor_re = re.compile(r"^\s*(&&|\|\|)")
cont_op_tail_re = re.compile(
    r"(\|\||&&|\||;|&|\(|\{|!|\bthen\b|\bdo\b|\belse\b)\s*$"
)
WORDISH = ("word", "arith", "btick")

def scan_line(line, st):
    """Advance the shell lexer state across one physical line.

    `st` carries `quote` (None / `'` / `"`) and `stack` (open word-level
    or command-level groupings) across lines, which is what tells us
    whether the next physical line continues this statement.
    """
    quote = st["quote"]
    stack = st["stack"]
    heredocs = []
    has_subst = False
    unmatched_close = 0
    ends_with_backslash = False

    i = 0
    n = len(line)
    while i < n:
        c = line[i]

        if quote == "'":
            if c == "'":
                quote = None
            i += 1
            continue

        if c == "\\":
            # A trailing backslash continues the line everywhere except
            # inside single quotes (handled above).
            if i + 1 >= n:
                ends_with_backslash = True
                i += 1
            else:
                i += 2
            continue

        if quote == '"':
            # `$(`, `$((` and backticks re-open command context inside a
            # double-quoted word; remember the quote so it is restored
            # when the substitution closes.
            if c == '"':
                quote = None
                i += 1
                continue
            if c == "$" and i + 1 < n and line[i + 1] == "(":
                if i + 2 < n and line[i + 2] == "(":
                    stack.append(("arith", quote))
                    i += 3
                else:
                    stack.append(("word", quote))
                    has_subst = True
                    i += 2
                quote = None
                continue
            if c == "`":
                stack.append(("btick", quote))
                has_subst = True
                quote = None
                i += 1
                continue
            i += 1
            continue

        # Unquoted.
        if c == "#" and (i == 0 or line[i - 1] in " \t;&|("):
            break  # comment runs to end of line

        if c == "'":
            quote = "'"
            i += 1
            continue
        if c == '"':
            quote = '"'
            i += 1
            continue
        if c == "`":
            if stack and stack[-1][0] == "btick":
                quote = stack.pop()[1]
            else:
                stack.append(("btick", None))
                has_subst = True
            i += 1
            continue

        if c == "$" and i + 1 < n and line[i + 1] == "(":
            if i + 2 < n and line[i + 2] == "(":
                stack.append(("arith", None))
                i += 3
            else:
                stack.append(("word", None))
                has_subst = True
                i += 2
            continue

        if c in "<>" and i + 1 < n and line[i + 1] == "(":
            stack.append(("word", None))  # process substitution
            has_subst = True
            i += 2
            continue

        if c == "=" and i + 1 < n and line[i + 1] == "(":
            stack.append(("word", None))  # `name=(` / `name+=(` array
            i += 2
            continue

        if c == "(":
            if i + 1 < n and line[i + 1] == "(":
                stack.append(("arith", None))
                i += 2
            else:
                stack.append(("cmd", None))  # subshell group
                i += 1
            continue

        if c == ")":
            if stack:
                kind, saved = stack.pop()
                if kind == "arith" and i + 1 < n and line[i + 1] == ")":
                    i += 1
                quote = saved
            else:
                unmatched_close += 1
            i += 1
            continue

        # `<<<` is a here-string, not a here-document: consume it whole so
        # its word is never mistaken for a here-doc terminator.
        if c == "<" and line[i + 1:i + 3] == "<<":
            i += 3
            continue

        # `<<` opens a here-document, but `1 << 2` inside `$(( ))` is a
        # left shift — the arith guard keeps the two apart.
        if (
            c == "<"
            and i + 1 < n
            and line[i + 1] == "<"
            and not any(k == "arith" for k, _ in stack)
        ):
            m = heredoc_re.match(line, i)
            if m:
                heredocs.append((m.group(2) or m.group(3) or m.group(4),
                                 m.group(1) == "-"))
                i = m.end()
                continue
            i += 2
            continue

        i += 1

    st["quote"] = quote
    return {
        "heredocs": heredocs,
        "has_subst": has_subst,
        "unmatched_close": unmatched_close,
        "ends_with_backslash": ends_with_backslash and quote != "'",
    }

def strip_comment(line):
    """Drop a trailing unquoted `#` comment."""
    quote = None
    for i, c in enumerate(line):
        if quote:
            if c == quote:
                quote = None
            continue
        if c in "\"'":
            quote = c
        elif c == "#" and (i == 0 or line[i - 1] in " \t;&|("):
            return line[:i]
    return line

def is_case_label(line):
    """True for a `case` pattern label with no command on the line.

    Quote-aware: the line must close exactly one paren it never opened
    and end there, which covers `*)`, `a | x)`, `"hello world")`, `'')`
    and the `(a|b)` form, while rejecting `x) echo x ;;` (traced) and
    ordinary code containing balanced parens.
    """
    body = strip_comment(line).rstrip()
    if not body.endswith(")"):
        return False
    probe = body.strip()
    if probe.startswith("("):
        probe = probe[1:]
    st = {"quote": None, "stack": []}
    info = scan_line(probe, st)
    if st["quote"] or st["stack"]:
        return False
    return info["unmatched_close"] == 1

def classify(line, is_start, cont_reason, prev_code, logical_has_subst,
             case_depth, excluding, xtrace_disabled):
    """Return "exec" (denominator entry), "alias" (fold onto the
    statement's first line) or "skip" (not measurable at all)."""
    if excluding or excl_start_re.search(line) or excl_stop_re.search(line):
        return "skip"
    if excl_line_re.search(line):
        return "skip"
    if xtrace_disabled:
        return "skip"

    if not is_start:
        if cont_reason == "quote":
            return "alias"
        # Backslash continuation: traced only when it begins a new
        # command, which an operator at either join point signals.
        if cont_op_head_re.match(line):
            return "exec"
        tail = strip_comment(prev_code).rstrip()
        if tail.endswith("\\"):
            tail = tail[:-1].rstrip()
        if cont_op_tail_re.search(tail):
            return "exec"
        return "alias"

    if not line or not line.strip():
        return "skip"
    if line.lstrip().startswith("#"):
        return "skip"
    if xtrace_off_re.match(line):
        return "skip"
    if structural_re.match(line):
        return "skip"
    if func_hdr_re.match(line) or func_hdr_kw_re.match(line):
        return "skip"
    if case_depth > 0 and is_case_label(line):
        return "skip"
    m = terminator_redir_re.match(strip_comment(line))
    if m and not logical_has_subst and not re.search(r"(\|\||&&|\||;)",
                                                     m.group("rest")):
        return "skip"
    return "exec"

analysis_cache = {}

def analyze(path):
    """Return (executable_lines, alias) for one shell file.

    `executable_lines` is the set of physical lines that belong in the
    lcov denominator. `alias` maps every other physical line of a
    multi-line statement (and here-doc bodies) onto that statement's
    denominator line, so a trace record landing on a later physical line
    still counts as a hit for the statement.
    """
    key = str(path)
    if key in analysis_cache:
        return analysis_cache[key]
    try:
        with open(key, "r", errors="replace") as f:
            text = f.read().splitlines()
    except OSError:
        analysis_cache[key] = (set(), {})
        return analysis_cache[key]

    exec_lines = set()
    alias = {}
    st = {"quote": None, "stack": []}
    heredoc_queue = []
    in_heredoc = None
    stmt_start = 1
    cont_reason = None
    prev_code = ""
    logical_has_subst = False
    case_depth = 0
    excluding = False
    xtrace_disabled = False

    for i, line in enumerate(text):
        lineno = i + 1

        if in_heredoc is not None:
            # Here-doc bodies are data, not commands. Fold them onto the
            # statement that opened them so a stray record can't invent
            # a denominator entry.
            alias[lineno] = stmt_start
            term, strip_tabs = in_heredoc
            probe = line.lstrip("\t") if strip_tabs else line
            if probe.strip() == term:
                in_heredoc = heredoc_queue.pop(0) if heredoc_queue else None
            continue

        is_start = cont_reason is None
        if is_start:
            stmt_start = lineno
            logical_has_subst = False

        info = scan_line(line, st)
        logical_has_subst = logical_has_subst or info["has_subst"]

        verdict = classify(line, is_start, cont_reason, prev_code,
                           logical_has_subst, case_depth, excluding,
                           xtrace_disabled)

        # Which bash you run decides where the head of a backslash-joined
        # `&&`/`||` list is reported, so neither answer can be trusted:
        #
        #     true \\
        #       && echo hi
        #
        # bash 5.3 traces `true` at its own line; bash 5.2 — every current
        # Linux runner — traces it at the `&&` line, which then carries two
        # records and leaves the head permanently unhittable. Dropping the
        # head makes the denominator identical on both, at the cost of one
        # covered line on 5.3. The operator line keeps its own entry, so a
        # short-circuited right-hand side is still reported as missed.
        #
        # Narrow on purpose: only the STATEMENT-START head, and only for
        # `&&`/`||`. An intermediate `&& cmd \\` in a longer chain is traced
        # on both (observed), as are `|`, `;` and a trailing-operator join
        # (`true && \\`), so all of those keep their line.
        if (
            verdict == "exec"
            and is_start
            and info["ends_with_backslash"]
            and not st["quote"]
            and not any(k in WORDISH for k, _ in st["stack"])
            and lineno < len(text)
            and cont_andor_re.match(text[lineno])
        ):
            verdict = "skip"

        # `done < <(` whose process substitution spans lines is another
        # version-dependent attribution. bash 5.x runs the substitution's
        # body at the closing paren, which folds onto this line; bash 3.2
        # attributes it to the `while`/`for` header instead, leaving the
        # whole `done < <( … )` region with no record at all. Excluded, so
        # the denominator agrees across versions.
        #
        # The single-line `done < <(cmd)` IS traced on both (observed), so
        # the classify() rule keeps it — only the spanning form is dropped.
        if (
            verdict == "exec"
            and is_start
            and (st["quote"] or any(k in WORDISH for k, _ in st["stack"]))
            and terminator_redir_re.match(strip_comment(line))
        ):
            verdict = "skip"

        if excl_start_re.search(line):
            excluding = True
        elif excl_stop_re.search(line):
            excluding = False
        if is_start and xtrace_off_re.match(line):
            xtrace_disabled = True

        if is_start and not excluding:
            if case_open_re.match(line):
                case_depth += 1
            elif esac_re.match(line):
                case_depth = max(0, case_depth - 1)

        if verdict == "exec":
            exec_lines.add(lineno)
            stmt_start = lineno
        elif verdict == "alias":
            alias[lineno] = stmt_start

        if info["heredocs"]:
            heredoc_queue.extend(info["heredocs"])

        if st["quote"] or any(k in WORDISH for k, _ in st["stack"]):
            cont_reason = "quote"
        elif info["ends_with_backslash"]:
            cont_reason = "backslash"
        else:
            cont_reason = None

        if heredoc_queue:
            in_heredoc = heredoc_queue.pop(0)

        prev_code = line

    analysis_cache[key] = (exec_lines, alias)
    return analysis_cache[key]

# Sweep through include-dirs so the lcov percentage reflects the total
# source surface, not just the files a test happened to touch.
candidates = set(raw_hits)
for inc in include_dirs:
    if not inc.exists():
        continue
    for path in inc.rglob("*.sh"):
        if not is_skipped(path):
            candidates.add(str(path.resolve()))
    for path in inc.rglob("*"):
        # also include shebanged shell scripts without an extension
        if not path.is_file() or path.suffix or path.stat().st_size == 0:
            continue
        if is_skipped(path):
            continue
        try:
            with open(path, "r", errors="replace") as f:
                first = f.readline()
        except OSError:
            continue
        if first.startswith("#!") and ("bash" in first or "sh" in first):
            candidates.add(str(path.resolve()))

# files[abs_path][line] = hits, restricted to the measurable denominator.
files = {}
for ap in candidates:
    exec_lines, alias = analyze(ap)
    counts = dict.fromkeys(exec_lines, 0)
    for lineno, n_hits in raw_hits.get(ap, {}).items():
        target = alias.get(lineno, lineno)
        if target in counts:
            counts[target] += n_hits
    files[ap] = counts

# Emit lcov.info
with open(out_path, "w") as out:
    for filename in sorted(files):
        out.write(f"SF:{filename}\n")
        for ln in sorted(files[filename]):
            out.write(f"DA:{ln},{files[filename][ln]}\n")
        out.write("end_of_record\n")

# Summary
total_files = len(files)
total_lines = sum(len(lines) for lines in files.values())
covered = sum(1 for lines in files.values() for h in lines.values() if h > 0)
pct = (covered * 100.0 / total_lines) if total_lines else 0.0
print(f"Aggregated: {total_files} files, {covered}/{total_lines} lines = {pct:.2f}%",
      file=sys.stderr)

# Truncation audit. A mangled record is a lost record, so say so. It is a
# hard error only when the lost record could have been for a measured
# file — i.e. its surviving prefix overlaps the repo root. Records for
# paths outside the repo (a $TMPDIR sandbox script, say) never entered
# the denominator, so they are reported without failing the run.
if truncated_records:
    n = sum(truncated_records.values())
    root = str(repo_root)
    fatal = any(root.startswith(p) or p.startswith(root)
                for p in truncated_records)
    level = "error" if fatal else "warning"
    print(f"::{level}::{n} trace record(s) were truncated and could not be "
          f"parsed — bash 3.2 cuts the expanded PS4 at 100 characters",
          file=sys.stderr)
    for name, count in truncated_by_trace.most_common(10):
        print(f"::{level}::truncated records in {name}: {count}", file=sys.stderr)
    for prefix, count in truncated_records.most_common(5):
        print(f"  {count} record(s) truncated at: {prefix!r}", file=sys.stderr)
    print(f"truncated-trace-records: {n} record(s) in "
          f"{len(truncated_by_trace)} trace file(s)", file=sys.stderr)
    if fatal:
        sys.exit(4)
else:
    print("truncated-trace-records: 0", file=sys.stderr)
