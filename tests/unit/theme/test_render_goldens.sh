#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

# Test comparison behavior without requiring chezmoi in every unit-test job.
# The dedicated Theme Contracts job runs the real renderer on Linux/macOS.
python3 - "$REPO_ROOT" <<'PY'
import importlib.util
from pathlib import Path
import sys
import tempfile

sys.dont_write_bytecode = True
root = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("goldens", root / "scripts/theme/check-render-goldens.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
checks = []
with tempfile.TemporaryDirectory() as temporary:
    fixtures = Path(temporary)
    expected = {"linux/maui-dark/kitty.golden": "background #112233\n"}
    checks.append((bool(module.compare(expected, fixtures)), "missing golden fails"))
    checks.append((not module.compare(expected, fixtures, True), "explicit update creates golden"))
    checks.append((not module.compare(expected, fixtures), "identical output passes"))
    changed = {next(iter(expected)): "background #445566\n"}
    checks.append(("+background #445566" in module.compare(changed, fixtures)[0], "changed output produces a reviewable diff"))
    checks.append((not module.compare(expected, fixtures), "check mode never updates goldens"))
    (fixtures / "extra.golden").write_text("unexpected\n")
    checks.append(("unexpected fixture" in module.compare(expected, fixtures)[0], "obsolete golden fails"))

actual = list(module.GOLDENS.rglob("*.golden"))
checks.append((len(actual) == len(module.THEMES) * len(module.PLATFORMS) * len(module.CONSUMERS), "complete 72-case baseline is committed"))
for platform in module.PLATFORMS:
    for family in ("maui", "berlin"):
        for consumer in module.CONSUMERS:
            dark = (module.GOLDENS / platform / (family + "-dark") / (consumer + ".golden")).read_text()
            light = (module.GOLDENS / platform / (family + "-light") / (consumer + ".golden")).read_text()
            checks.append((dark != light, f"{platform}/{family}/{consumer} light and dark differ"))
for passed, label in checks:
    print(("PASS " if passed else "FAIL ") + label)
failed = sum(not passed for passed, _ in checks)
print(f"RESULTS:{len(checks)}:{len(checks)-failed}:{failed}")
sys.exit(bool(failed))
PY
