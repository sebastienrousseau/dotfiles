#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

# An inherited pipe with no reader deterministically reproduces SIGPIPE,
# without a terminal, sleep race, or a real dot-ui/upgrade subprocess.
python3 - "$REPO_ROOT" "${BASH:-bash}" <<'PY'
import os
from pathlib import Path
import subprocess
import sys

root, bash = sys.argv[1:]
read_fd, write_fd = os.pipe()
os.close(read_fd)
try:
    script = '''
set -euo pipefail
source "$1/lib/dot/ui.sh"
trap 'echo caller-pipe-trap >&2' PIPE
_UI_STEPS_FD="$2"
_UI_STEPS_ACTIVE=1
_UI_STEPS_RICH=1
_ui_step_label_set phase "Neovim plugins"
ui_step phase "" fail "fixture error"
printf 'rich=%s\n' "$_UI_STEPS_RICH"
printf 'stderr-survived\n' >&2
trap -p PIPE
ui_steps_end "1 step failed"
echo summary-survived
'''
    result = subprocess.run(
        [bash, '-c', script, 'fixture', root, str(write_fd)],
        pass_fds=(write_fd,), capture_output=True, text=True, timeout=10,
    )
finally:
    os.close(write_fd)

checks = [
    (result.returncode == 0, "closed renderer cannot terminate caller"),
    ("rich=0" in result.stdout, "closed renderer selects plain fallback"),
    ("Neovim plugins" in result.stdout and "fixture error" in result.stdout,
     "fallback retains step label and failure detail"),
    ("summary-survived" in result.stdout, "caller reaches final summary"),
    ("stderr-survived" in result.stderr, "caller stderr stays open"),
    ("caller-pipe-trap" in result.stdout, "caller PIPE handler is preserved"),
    ("caller-pipe-trap" not in result.stderr, "PIPE is contained in writer"),
]
for passed, label in checks:
    print(("PASS " if passed else "FAIL ") + label)
failed = sum(not passed for passed, _ in checks)
if failed:
    print(result.stdout, result.stderr)
print(f"RESULTS:{len(checks)}:{len(checks)-failed}:{failed}")
sys.exit(bool(failed))
PY
