#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

# Execute the actual composite-action install block with an isolated binary
# and verified-installer stub. No GitHub expression, network or real install.
python3 - "$REPO_ROOT" "${BASH:-bash}" <<'PY'
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import textwrap

root = Path(sys.argv[1])
action = (root / ".github/actions/setup-chezmoi/action.yml").read_text()
step = action.split("    - name: Install chezmoi (cache miss)\n", 1)[1]
script = textwrap.dedent(step.split("      run: |\n", 1)[1])
cases = [
    ("current", "chezmoi version v2.47.1, commit abc, built at 2024-01-01", 0, False),
    ("version-only", "chezmoi version v2.47.1", 0, False),
    ("legacy", "chezmoi v2.47.1", 0, False),
    ("without-v", "chezmoi version 2.47.1", 0, False),
    ("mismatch", "chezmoi version v2.72.0, commit abc", 0, True),
    ("unrecognized", "unexpected version output", 0, True),
    ("prerelease", "chezmoi version v2.47.1-rc1", 0, True),
    ("failing-binary", "chezmoi version v2.47.1", 1, True),
    ("missing", None, 0, True),
]
checks = []
for name, output, status, reinstall in cases:
    with tempfile.TemporaryDirectory(prefix="dot-chezmoi-cache-") as temporary:
        fixture = Path(temporary)
        bin_dir = fixture / "bin"
        bin_dir.mkdir()
        binary = bin_dir / "chezmoi"
        expected = "#!/bin/sh\nprintf '%s\\n' 'chezmoi version v2.47.1, commit installed'\n"
        if output is not None:
            binary.write_text(f"#!/bin/sh\nprintf '%s\\n' {shlex.quote(output)}\nexit {status}\n")
            binary.chmod(0o755)
        original = binary.read_bytes() if binary.exists() else None
        installer = fixture / "tools/ci/install-chezmoi-verified.sh"
        installer.parent.mkdir(parents=True)
        marker = fixture / "installed"
        installer.write_text(
            "#!/bin/sh\nset -eu\n"
            'test "$1" = 2.47.1\n'
            f"touch {shlex.quote(str(marker))}\n"
            f"printf '%s' {shlex.quote(expected)} > \"$2/chezmoi\"\n"
            'chmod 755 "$2/chezmoi"\n'
        )
        installer.chmod(0o755)
        rendered = script.replace("${{ steps.resolve.outputs.bin_dir }}", str(bin_dir))
        rendered = rendered.replace("${{ steps.resolve.outputs.version }}", "2.47.1")
        env = dict(os.environ, GITHUB_WORKSPACE=str(fixture), GITHUB_PATH=str(fixture / "path"))
        result = subprocess.run([sys.argv[2], "-c", rendered], env=env, text=True, capture_output=True)
        passed = result.returncode == 0 and marker.exists() == reinstall
        passed = passed and (fixture / "path").exists() and binary.exists()
        if passed:
            passed = (fixture / "path").read_text() == str(bin_dir) + "\n"
            passed = passed and binary.read_bytes() == (expected.encode() if reinstall else original)
        checks.append(passed)
        print(("PASS " if passed else "FAIL ") + name)
        if not passed:
            print(result.stdout + result.stderr)
failed = checks.count(False)
print(f"RESULTS:{len(checks)}:{len(checks)-failed}:{failed}")
sys.exit(bool(failed))
PY
