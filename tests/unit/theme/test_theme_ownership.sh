#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

python3 - "$REPO_ROOT" "${BASH:-bash}" <<'PY'
import json
import os
from pathlib import Path
import re
import subprocess
import sys

root, bash = Path(sys.argv[1]), sys.argv[2]
data = json.loads((root / "schemas/theme-ownership.json").read_text())
schema = json.loads((root / "schemas/theme-ownership.schema.json").read_text())
checks = []
def check(condition, name):
    checks.append((condition, name))

# Validate this deliberately small closed inventory contract, without adding
# a runtime dependency or claiming to implement a general JSON Schema engine.
check(set(data) == set(schema["required"]), "inventory has only declared fields")
for key in ("schema_version", "scope", "rollback"):
    check(data.get(key) == schema["properties"][key]["const"], key + " contract")
target_schema = schema["properties"]["targets"]["items"]
check(bool(data["targets"]), "inventory is nonempty")
identities = []
for target in data["targets"]:
    check(set(target) == set(target_schema["required"]), "target has closed fields")
    for key in ("platform", "adapter", "format", "ownership"):
        check(target.get(key) in target_schema["properties"][key]["enum"], key + " is recognized")
    path = target["path"]
    check(isinstance(path, str) and bool(path) and ".." not in path.split("/"), "path is explicit without traversal")
    keys = target["keys"]
    check(isinstance(keys, list) and all(isinstance(key, str) and key for key in keys)
          and len(keys) == len(set(keys)), "owned keys are unique nonempty names")
    check(bool(keys) == (target["ownership"] == "keys"), "key ownership is explicit")
    check(target["adapter"] != "ai-provider" or target["ownership"] == "keys", "provider configs remain shared")
    identities.append((target["platform"], path))
check(len(identities) == len(set(identities)), "no duplicate ownership entries")

text = (root / "bin/dot-theme-sync").read_text()
functions = "\n".join(re.findall(r"^theme_transaction_targets\(\) \{.*?^\}|^_theme_target_adapter\(\) \{.*?^\}", text, re.M | re.S))
check(len(functions) > 0, "compatibility functions exist")
home = os.environ["HOME"]
config, state = "/DOT_CONFIG", "/DOT_STATE"
replacements = {
    "$CHEZMOI_CFG": config + "/chezmoi/chezmoi.toml",
    "${XDG_CONFIG_HOME:-$HOME/.config}": config,
    "${XDG_STATE_HOME:-$HOME/.local/state}": state,
    "$HOME": home,
}
for platform in ("Darwin", "Linux", "MINGW64_NT"):
    expected = set()
    for target in data["targets"]:
        if target["platform"] not in ("all", "darwin" if platform == "Darwin" else "non-darwin"):
            continue
        path = target["path"]
        for token, value in replacements.items():
            path = path.replace(token, value)
        check("$" not in path, "all path roots are recognized")
        expected.add(target["adapter"] + "|" + path)
    script = functions + '\ntheme_transaction_targets | while IFS= read -r target; do _theme_target_adapter "$target"; printf "%s|%s\\n" "$THEME_TARGET_ADAPTER" "$target"; done\n'
    output = subprocess.run([bash, "-c", script], check=True, capture_output=True, text=True, timeout=10,
                            env=dict(os.environ, PLATFORM=platform, XDG_CONFIG_HOME=config, XDG_STATE_HOME=state,
                                     CHEZMOI_CFG=config + "/chezmoi/chezmoi.toml"))
    check(set(output.stdout.splitlines()) == expected, platform + " inventory matches actual snapshot targets and adapters")

failed = 0
for passed, name in checks:
    if not passed:
        failed += 1
        print("FAIL " + name)
print(f"Validated {len(data['targets'])} ownership entries across three platform selectors")
print(f"RESULTS:{len(checks)}:{len(checks)-failed}:{failed}")
sys.exit(bool(failed))
PY
