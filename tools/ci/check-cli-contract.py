#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""CLI-contract lint: hold every dot command name to ADR-020.

Reads the registries in schemas/cli/ and the plugin manifests in
plugins/<domain>/dot-plugin.toml, and fails on any name that breaks the
grammar (N1 to N7, N13, N16):

  - each manifest validates against manifest.v1.schema.json, sits in the
    directory of its domain, and that domain is in the family table;
  - every verb is in the closed list, every object is declared and is not
    itself a verb, and each command's effect matches its verb's class;
  - output schema ids carry the domain; deprecated names expire after the
    current release;
  - alias names are unique, shadow no domain or built-in, the shortcuts
    are exactly the ones domains.json declares, and every alias target
    resolves to a declared command;
  - every route in lib/dot/data/routes.txt has a new spelling;
  - lib/dot/data/commands.txt, the table bin/dot resolves names from, is
    what tools/ci/cli_command_table.py generates from the manifests.

It also runs bin/dot against the runtime rules (N9 flags, N10 exit codes).
Today's binary breaks some of them; tools/ci/cli-contract-baseline.txt lists
those by id. A violation not in the baseline fails, and so does a baseline
entry that no longer fails, so the list only shrinks.

    tools/ci/check-cli-contract.py
    tools/ci/check-cli-contract.py --root DIR --dot PATH   # tests
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import subprocess
import sys
import tempfile

import tomllib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import cli_command_table

ROOT = pathlib.Path(__file__).resolve().parents[2]
ALLOWED_EFFECTS = {"read": {"read"}, "change": {"write", "destructive"}, "any": {"read", "write", "destructive"}}


def load_registries(root: pathlib.Path) -> dict:
    cli = root / "schemas" / "cli"
    domains = json.loads((cli / "domains.json").read_text())
    verbs = json.loads((cli / "verbs.json").read_text())
    flags = json.loads((cli / "flags.json").read_text())["flags"]
    return {
        "flags": {f["long"]: f.get("short") for f in flags},
        "domains": {d["name"]: d for d in domains["domains"]},
        "builtins": set(domains.get("builtins", [])),
        "verbs": {v["name"]: v for v in verbs["verbs"]},
        "schema": json.loads((cli / "manifest.v1.schema.json").read_text()),
    }


def load_manifests(root: pathlib.Path) -> tuple[dict, list[str]]:
    found, errors = {}, []
    for path in sorted((root / "plugins").glob("*/dot-plugin.toml")):
        try:
            found[path.parent.name] = tomllib.loads(path.read_text())
        except tomllib.TOMLDecodeError as exc:
            errors.append(f"{path.parent.name}: invalid TOML: {exc}")
    return found, errors


def version_key(text: str) -> tuple[int, ...]:
    return tuple(int(part) for part in text.split("."))


def current_version(root: pathlib.Path) -> str:
    data = tomllib.loads((root / "defaults" / ".chezmoidata.toml").read_text())
    return data["dotfiles_version"]


def check_schema(name: str, manifest: dict, schema: dict) -> list[str]:
    import jsonschema

    validator = jsonschema.Draft202012Validator(schema)
    return [f"{name}: schema: {'/'.join(map(str, e.path)) or '(root)'}: {e.message}"
            for e in validator.iter_errors(manifest)]


def check_identity(name: str, manifest: dict, reg: dict) -> list[str]:
    errors = []
    if manifest.get("domain") != name or manifest.get("name") != name:
        errors.append(f"{name}: name and domain must equal the directory name (N2)")
    if name not in reg["domains"]:
        errors.append(f"{name}: not a domain in schemas/cli/domains.json (N1)")
    return errors


def check_objects(name: str, manifest: dict, reg: dict) -> list[str]:
    errors = []
    for obj in manifest.get("objects", []):
        if obj["name"] in reg["verbs"]:
            errors.append(f"{name}: object '{obj['name']}' is a verb; the grammar would be ambiguous (N3)")
    return errors


def check_command(name: str, cmd: dict, objects: set[str], reg: dict) -> list[str]:
    label = f"{name} {cmd.get('object', '')} {cmd['verb']}".replace("  ", " ")
    verb = reg["verbs"].get(cmd["verb"])
    if verb is None:
        return [f"{label}: '{cmd['verb']}' is not an approved verb (N4, N6)"]
    errors = []
    if "object" in cmd and cmd["object"] not in objects:
        errors.append(f"{label}: object '{cmd['object']}' is not declared in [[objects]] (N3)")
    if cmd["effect"] not in ALLOWED_EFFECTS[verb["effect"]]:
        errors.append(f"{label}: effect '{cmd['effect']}' does not match the verb's class '{verb['effect']}' (N16)")
    if verb.get("confirms") and cmd["effect"] != "destructive":
        errors.append(f"{label}: '{cmd['verb']}' always confirms, so its effect is destructive (N16)")
    output = cmd.get("output", "")
    if output and not output.startswith(f"{name}/"):
        errors.append(f"{label}: output id '{output}' must start with '{name}/' (N13)")
    return errors + check_flags(label, cmd.get("flags", []), reg["flags"])


def check_flags(label: str, flags: list[dict], family: dict) -> list[str]:
    """A command's flags are unique, and a family letter or name keeps its family meaning (N9)."""
    spellings = [s for f in flags for s in (f"--{f['long']}", f.get("short") and f"-{f['short']}") if s]
    errors = [f"{label}: flag {s} is declared twice" for s in sorted(set(spellings)) if spellings.count(s) > 1]
    return errors + [e for f in flags for e in family_meaning(label, f, family)]


def family_meaning(label: str, flag: dict, family: dict) -> list[str]:
    long, short = flag["long"], flag.get("short")
    by_short = {s: name for name, s in family.items() if s}
    if short in by_short and by_short[short] != long:
        return [f"{label}: -{short} means --{by_short[short]} family-wide, not --{long} (N9)"]
    if family.get(long) and short and family[long] != short:
        return [f"{label}: --{long} is a family flag; its short form is -{family[long]}, not -{short} (N9)"]
    return []


def check_cmdlets(name: str, manifest: dict, reg: dict) -> list[str]:
    """Two commands of one noun may share a PowerShell verb only as list and
    show (one Get cmdlet); status has its own noun (N11)."""
    groups: dict[tuple, set] = {}
    for cmd in manifest["commands"]:
        if cmd["verb"] != "status" and cmd["verb"] in reg["verbs"]:
            ps = reg["verbs"][cmd["verb"]]["powershell"]
            groups.setdefault((cmd.get("object"), ps), set()).add(cmd["verb"])
    return [f"{' '.join(filter(None, (name, obj)))}: {', '.join(sorted(verbs))} would share the {ps} cmdlet (N11)"
            for (obj, ps), verbs in sorted(groups.items(), key=str) if len(verbs) > 1 and verbs != {"list", "show"}]


def check_deprecations(name: str, manifest: dict, version: str) -> list[str]:
    return [f"{name}: deprecated alias '{a['name']}' expired at {a['until']} (current {version}) (N7)"
            for a in manifest.get("aliases", [])
            if a.get("kind") == "deprecated" and version_key(a["until"]) <= version_key(version)]


def check_manifest(name: str, manifest: dict, reg: dict, version: str) -> list[str]:
    errors = check_schema(name, manifest, reg["schema"])
    if errors:
        return errors
    errors += check_identity(name, manifest, reg)
    errors += check_objects(name, manifest, reg)
    objects = {o["name"] for o in manifest.get("objects", [])}
    for cmd in manifest["commands"]:
        errors += check_command(name, cmd, objects, reg)
    return errors + check_cmdlets(name, manifest, reg) + check_deprecations(name, manifest, version)


def resolve_target(target: str, manifests: dict, reg: dict) -> str | None:
    """Return why the target does not resolve, or None when it does."""
    words = [w for w in target.split() if not w.startswith("--")]
    head, rest = words[0], words[1:]
    if head in reg["builtins"]:
        return None
    if head not in manifests:
        return f"'{head}' is neither a domain with a manifest nor a built-in"
    return resolve_in_manifest(head, rest, manifests[head])


def resolve_in_manifest(head: str, rest: list[str], manifest: dict) -> str | None:
    """`dot <head> [object] [verb] [args]`: an object (with an optional verb) or a verb."""
    objects = {o["name"] for o in manifest.get("objects", [])}
    pairs = {(c.get("object"), c["verb"]) for c in manifest["commands"]}
    if not rest:
        return None
    if rest[0] in objects:
        if len(rest) == 1 or (rest[0], rest[1]) in pairs:
            return None
        return f"'{head} {rest[0]}' has no verb '{rest[1]}'"
    if (None, rest[0]) in pairs:
        return None
    return f"'{rest[0]}' is neither an object nor a command of '{head}'"


def check_aliases(manifests: dict, reg: dict) -> list[str]:
    errors, owners = [], {}
    for domain, manifest in sorted(manifests.items()):
        for alias in manifest.get("aliases", []):
            alias_name = alias["name"]
            if alias_name in owners:
                errors.append(f"alias '{alias_name}' is declared by both {owners[alias_name]} and {domain} (N7)")
            owners.setdefault(alias_name, domain)
            if alias_name in reg["domains"] or alias_name in reg["builtins"]:
                errors.append(f"{domain}: alias '{alias_name}' shadows a domain or built-in (N7)")
            # A removed name still prints its target as the hint, so it must resolve.
            why = resolve_target(alias["target"], manifests, reg)
            if why:
                errors.append(f"{domain}: alias '{alias_name}' -> '{alias['target']}': {why}")
    return errors


def check_shortcuts(manifests: dict, reg: dict) -> list[str]:
    declared = {(d, s["name"], s["target"]) for d, entry in reg["domains"].items() for s in entry.get("shortcuts", [])}
    present = {(d, a["name"], a["target"]) for d, m in manifests.items()
               for a in m.get("aliases", []) if a["kind"] == "shortcut"}
    errors = [f"{d}: shortcut '{n}' -> '{t}' is in domains.json but not in the manifest (N7)"
              for d, n, t in sorted(declared - present) if d in manifests]
    errors += [f"{d}: shortcut '{n}' -> '{t}' is not declared in domains.json (N7)"
               for d, n, t in sorted(present - declared)]
    return errors


def check_routes(root: pathlib.Path, manifests: dict, reg: dict) -> list[str]:
    spelled = set(reg["domains"]) | reg["builtins"]
    spelled |= {a["name"] for m in manifests.values() for a in m.get("aliases", [])}
    errors = []
    for line in (root / "lib" / "dot" / "data" / "routes.txt").read_text().splitlines():
        route = line.split("|", 1)[0].strip()
        if route and not route.startswith("-") and route not in spelled:
            errors.append(f"route '{route}' has no new spelling: add an alias to the owning manifest")
    return errors


def run_dot_err(dot: pathlib.Path, *args: str) -> tuple[int, str, str]:
    with tempfile.TemporaryDirectory() as home:
        env = {"HOME": home, "PATH": os.environ.get("PATH", "/usr/bin:/bin"), "NO_COLOR": "1", "TERM": "dumb"}
        proc = subprocess.run([str(dot), *args], env=env, capture_output=True, text=True,
                              stdin=subprocess.DEVNULL, timeout=60, check=False)
    return proc.returncode, proc.stdout, proc.stderr


def run_dot(dot: pathlib.Path, *args: str) -> tuple[int, str]:
    rc, out, _ = run_dot_err(dot, *args)
    return rc, out


def check_table(root: pathlib.Path) -> list[str]:
    return [f"{rel} is stale: run tools/ci/cli_command_table.py"
            for rel, text in cli_command_table.expected(root).items()
            if not (root / rel).is_file() or (root / rel).read_text() != text]


def runtime_violations(dot: pathlib.Path) -> dict[str, str]:
    """Runtime rules by id; each value says what is wrong today."""
    found = {}
    rc, _ = run_dot(dot, "-V")
    if rc != 0:
        found["N9-short-version"] = f"'dot -V' exits {rc}; -V is the version flag"
    _, long_out = run_dot(dot, "--version")
    _, short_out, short_err = run_dot_err(dot, "-v")
    if short_out.strip() and short_out == long_out and "-V" not in short_err:
        found["N9-v-is-verbose"] = "'dot -v' prints the version without the -V warning; -v means --verbose"
    rc, _ = run_dot(dot, "-v", "no-such-command-n10")
    if rc != 127:
        found["N9-v-is-verbose"] = f"'dot -v <unknown>' exits {rc}, not 127; -v must pass on to the command"
    rc, _ = run_dot(dot, "no-such-command-n10")
    if rc != 127:
        found["N10-unknown-127"] = f"an unknown command exits {rc}, not 127"
    return found


def read_baseline(path: pathlib.Path) -> set[str]:
    if not path.exists():
        return set()
    return {ln.split("#", 1)[0].strip() for ln in path.read_text().splitlines()} - {""}


def check_runtime(dot: pathlib.Path, baseline: set[str]) -> list[str]:
    found = runtime_violations(dot)
    errors = [f"runtime {rid}: {why}" for rid, why in sorted(found.items()) if rid not in baseline]
    errors += [f"runtime {rid}: fixed; remove it from tools/ci/cli-contract-baseline.txt"
               for rid in sorted(baseline - set(found))]
    return errors


def lint(root: pathlib.Path, dot: pathlib.Path) -> list[str]:
    reg = load_registries(root)
    manifests, errors = load_manifests(root)
    version = current_version(root)
    for name, manifest in manifests.items():
        errors += check_manifest(name, manifest, reg, version)
    if errors:
        return errors
    errors += check_aliases(manifests, reg)
    errors += check_shortcuts(manifests, reg)
    errors += check_routes(root, manifests, reg)
    errors += check_table(root)
    return errors + check_runtime(dot, read_baseline(root / "tools" / "ci" / "cli-contract-baseline.txt"))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=pathlib.Path, default=ROOT)
    parser.add_argument("--dot", type=pathlib.Path, help="dot binary (default: <root>/bin/dot)")
    args = parser.parse_args(argv)
    errors = lint(args.root, args.dot or args.root / "bin" / "dot")
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    if errors:
        print(f"CLI contract: {len(errors)} violation(s)", file=sys.stderr)
        return 1
    print("CLI contract: pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
