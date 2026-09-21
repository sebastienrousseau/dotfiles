#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

python3 - "$REPO_ROOT" "${BASH:-bash}" <<'PY'
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

root, bash = sys.argv[1:]
source = (Path(root) / "scripts/dot/commands/meta.sh").read_text()
functions = "\n".join(re.findall(r"^_upgrade_last_line\(\) \{.*?^\}|^cmd_upgrade\(\) \{.*?^\}", source, re.M | re.S))
checks = []
with tempfile.TemporaryDirectory(prefix="dot-upgrade-test-") as temporary:
    work = Path(temporary)
    repo = work / "repo"
    repo.mkdir()
    env = dict(os.environ, UPGRADE_FIXTURE=str(repo), UPGRADE_MARKER=str(work / "updated"),
               TMPDIR=str(work), DOTFILES_NO_TUI="1", NO_COLOR="1")
    def git(*args):
        return subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True, text=True)
    git("init", "-b", "main")
    git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
        "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null",
        "commit", "--allow-empty", "-m", "fixture")
    script = '''
set -euo pipefail
source "$1/lib/dot/ui.sh"
require_source_dir() { printf '%s\n' "$UPGRADE_FIXTURE"; }
has_command() { return 1; }
chezmoi() {
  if [[ $1 == source-path ]]; then printf '%s\n' "$UPGRADE_FIXTURE";
  else printf 'updated\n' >"$UPGRADE_MARKER"; printf 'updated\n'; fi
}
''' + functions + '\ncmd_upgrade\n'
    def run():
        return subprocess.run([bash, "-c", script, "fixture", root], env=env,
                              capture_output=True, text=True, timeout=10)
    result = run()
    checks += [(result.returncode == 1 and "has no upstream" in result.stdout,
                "untracked branch fails with actionable explanation"),
               (not (work / "updated").exists(), "untracked branch never invokes update"),
               ("Logs" in result.stdout, "failure keeps and reports private logs")]
    git("config", "branch.main.remote", ".")
    git("config", "branch.main.merge", "refs/heads/main")
    (repo / "pending").write_text("uncommitted\n")
    result = run()
    checks += [(result.returncode == 1 and "uncommitted changes" in result.stdout,
                "dirty checkout is preserved"),
               (not (work / "updated").exists(), "dirty checkout never invokes update")]
    (repo / "pending").unlink()
    git("checkout", "--detach")
    result = run()
    checks += [(result.returncode == 1 and "detached" in result.stdout,
                "detached checkout fails before update")]
    git("checkout", "main")
    result = run()
    checks += [(result.returncode == 0 and (work / "updated").is_file(),
                "clean tracked checkout can update")]
for passed, label in checks:
    print(("PASS " if passed else "FAIL ") + label)
failed = sum(not passed for passed, _ in checks)
print(f"RESULTS:{len(checks)}:{len(checks)-failed}:{failed}")
sys.exit(bool(failed))
PY
