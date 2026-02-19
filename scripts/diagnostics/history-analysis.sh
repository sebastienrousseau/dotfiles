#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

histfile="${HISTFILE:-$HOME/.zsh_history}"
db="${DOTFILES_HISTORY_DB:-$HOME/.local/share/dotfiles/history.sqlite}"

ui_init

if [[ ! -f "$histfile" ]]; then
  ui_err "History file" "not found: $histfile" >&2
  exit 1
fi

if ! command -v python3 >/dev/null; then
  ui_warn "python3" "not found; falling back to hstats if available" >&2
  if command -v hstats >/dev/null; then
    hstats
    exit 0
  fi
  exit 1
fi

mkdir -p "$(dirname "$db")"

ui_header "History Analysis"

python3 - "$histfile" "$db" <<'PY'
import sys
import sqlite3
import re
from pathlib import Path

histfile = Path(sys.argv[1])
db = Path(sys.argv[2])

conn = sqlite3.connect(db)
cur = conn.cursor()
cur.execute("CREATE TABLE IF NOT EXISTS history (ts INTEGER, cmd TEXT)")
cur.execute("DELETE FROM history")

pattern = re.compile(r"^: (\d+):\d+;(.*)$")

with histfile.open("r", encoding="utf-8", errors="ignore") as f:
    for line in f:
        line = line.rstrip("\n")
        m = pattern.match(line)
        if not m:
            continue
        ts = int(m.group(1))
        cmd = m.group(2).strip()
        if not cmd:
            continue
        cur.execute("INSERT INTO history (ts, cmd) VALUES (?, ?)", (ts, cmd))

conn.commit()

print("\nTop commands:")
for row in cur.execute("""
    SELECT substr(cmd, 1, instr(cmd || ' ', ' ') - 1) AS base, COUNT(*)
    FROM history
    GROUP BY base
    ORDER BY COUNT(*) DESC
    LIMIT 15
"""):
    print(f"{row[1]:>6}  {row[0]}")

print("\nTop directories (cd):")
for row in cur.execute("""
    SELECT trim(substr(cmd, 4)) AS dir, COUNT(*)
    FROM history
    WHERE cmd LIKE 'cd %'
    GROUP BY dir
    ORDER BY COUNT(*) DESC
    LIMIT 10
"""):
    print(f"{row[1]:>6}  {row[0]}")

conn.close()
PY
