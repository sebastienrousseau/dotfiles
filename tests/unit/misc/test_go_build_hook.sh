#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

python3 - "$REPO_ROOT" "${BASH:-bash}" <<'PY'
import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(sys.argv[1])
helper = root / "defaults/.chezmoitemplates/go-build-command"
checks = []
with tempfile.TemporaryDirectory(prefix="dot-build-test-") as temporary:
    fixture = Path(temporary)
    (fixture / "bin").mkdir()
    (fixture / "source").mkdir()
    binary = fixture / "output"
    binary.write_text("old binary\n")
    go = fixture / "bin/go"
    go.write_text('''#!/bin/sh
test -d "$GOTMPDIR" || exit 90
test "$1" = build && test "$2" = -o || exit 91
printf 'new binary\n' >"$3"
exit "${BUILD_RC:-0}"
''')
    go.chmod(0o755)
    env = dict(os.environ, PATH=str(fixture / "bin") + os.pathsep + os.environ["PATH"],
               SRC=str(fixture / "source"), OUT=str(binary), GOTMPDIR=str(fixture / "gone"))
    script = 'source "$1"; if dot_build_go_binary; then exit 0; else exit 1; fi'
    for status in (42, 0):
        result = subprocess.run([sys.argv[2], "-c", script, "fixture", str(helper)],
                                env=dict(env, BUILD_RC=str(status)), capture_output=True, text=True)
        checks.append((result.returncode == (1 if status else 0), "build exit status propagates"))
        checks.append((binary.read_text() == ("old binary\n" if status else "new binary\n"),
                       "old binary preserved on failure / replaced on success"))
        checks.append((not list(fixture.glob("output.build.*")), "private build directory cleaned"))
    checks.append((binary.stat().st_mode & 0o777 == 0o755, "successful binary is executable"))
for hook in root.glob("defaults/run_onchange_2[456]-build-*.sh.tmpl"):
    source = hook.read_text()
    checks.append(('{{ template "go-build-command" . }}' in source and "if dot_build_go_binary; then" in source
                   and "exit 1" in source and "build failed (continuing" not in source,
                   hook.name + " uses guarded build and reports failure"))
for passed, label in checks:
    print(("PASS " if passed else "FAIL ") + label)
failed = sum(not passed for passed, _ in checks)
print(f"RESULTS:{len(checks)}:{len(checks)-failed}:{failed}")
sys.exit(bool(failed))
PY
