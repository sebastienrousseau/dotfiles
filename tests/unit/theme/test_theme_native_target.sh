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

source = (Path(sys.argv[1]) / "bin/dot-theme-sync").read_text()
names = ("_theme_target_adapter", "_theme_chezmoi_apply", "apply_theme_configs")
functions = "\n".join(re.search(r"^" + name + r"\(\) \{.*?^\}", source, re.M | re.S)[0] for name in names)
# Substitute only the home-root token in these pure fixture functions, leaving
# the process's real HOME and all application state untouched.
functions = functions.replace("$HOME", "$TEST_HOME")
checks = []
with tempfile.TemporaryDirectory(prefix="dot-native-target-") as temporary:
    root = Path(temporary)
    native = root / "Library/Application Support/com.mitchellh.ghostty/config"
    managed = root / ".config/kitty/kitty.conf"
    for target in (native, managed):
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("original\n")
    script = '''
set -euo pipefail
_ok() { printf '%s: %s\n' "$1" "$2"; }
_err() { printf '%s: %s\n' "$1" "$2"; }
_skip() { printf '%s: %s\n' "$1" "$2"; }
theme_transaction_targets() { printf '%s\n' "$MANAGED" "$NATIVE"; }
chezmoi() {
  printf '%s\n' "$@" >>"$CALLS"
  printf 'CONFIGURATION_CONTENT_MUST_NOT_LEAK\n'
  if [[ $FAIL_RENDER == 1 ]]; then
    printf 'fixture template error: kitty.conf\n' >&2
    return 17
  fi
}
''' + functions + '\nif apply_theme_configs; then exit 0; else exit 1; fi\n'
    env = dict(os.environ, TEST_HOME=str(root), PLATFORM="Darwin", CHEZMOI_CFG=str(root / "chezmoi.toml"),
               CHEZMOI_SRC=str(root), SRC_DIR=str(root), THEME_TXN_OPERATION_DIR=str(root),
               MANAGED=str(managed), NATIVE=str(native), CALLS=str(root / "calls"))
    for failing in (False, True):
        (root / "calls").write_text("")
        result = subprocess.run([sys.argv[2], "-c", script], env=dict(env, FAIL_RENDER=str(int(failing))),
                                capture_output=True, text=True)
        calls = (root / "calls").read_text()
        checks.append((result.returncode == int(failing), "render outcome propagates"))
        checks.append((str(managed) in calls and str(native) not in calls, "native mirror is never passed to chezmoi"))
        checks.append(("CONFIGURATION_CONTENT_MUST_NOT_LEAK" not in result.stdout + result.stderr,
                       "rendered configuration stdout is suppressed"))
        if failing:
            checks.append(("fixture template error: kitty.conf" in result.stderr, "actual renderer diagnostic is surfaced"))
            checks.append(("fixture template error: kitty.conf" in (root / "chezmoi.log").read_text(),
                           "renderer diagnostic retained with transaction"))
            checks.append((calls.count("apply\n") == 1, "failed validation never reaches apply"))
    checks.append((native.read_text() == "original\n", "preflight leaves native mirror intact"))
for passed, label in checks:
    print(("PASS " if passed else "FAIL ") + label)
failed = sum(not passed for passed, _ in checks)
print(f"RESULTS:{len(checks)}:{len(checks)-failed}:{failed}")
sys.exit(bool(failed))
PY
