#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""The ADR-020 naming registries and manifest v1 schema hold their rules."""
import copy
import json
from pathlib import Path
import re
import tomllib
import unittest

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[3]
CLI = ROOT / "schemas/cli"


def load(name):
    return json.loads((CLI / name).read_text())


REGISTRY = load("registry.v1.schema.json")
MANIFEST = load("manifest.v1.schema.json")
DOMAINS = load("domains.json")
VERBS = load("verbs.json")
FLAGS = load("flags.json")
EXAMPLE = tomllib.loads((CLI / "examples/dot-plugin.toml").read_text())

# Output of `(Get-Verb).Verb` on PowerShell 7.6. Generated cmdlets (N11)
# must use one of these or PowerShell warns on import.
PS_APPROVED = set("""
Add Clear Close Copy Enter Exit Find Format Get Hide Join Lock Move New Open
Optimize Push Pop Redo Remove Rename Reset Resize Search Select Set Show Skip
Split Step Switch Undo Unlock Watch Connect Disconnect Read Receive Send Write
Backup Checkpoint Compare Compress Convert ConvertFrom ConvertTo Dismount Edit
Expand Export Group Import Initialize Limit Merge Mount Out Publish Restore
Save Sync Unpublish Update Debug Measure Ping Repair Resolve Test Trace Approve
Assert Build Complete Confirm Deny Deploy Disable Enable Install Invoke
Register Request Restart Resume Start Stop Submit Suspend Uninstall Unregister
Wait Use Block Grant Protect Revoke Unblock Unprotect
""".split())


def names(items, key="name"):
    return [item[key] for item in items]


class Schemas(unittest.TestCase):
    def test_schemas_are_valid(self):
        Draft202012Validator.check_schema(REGISTRY)
        Draft202012Validator.check_schema(MANIFEST)

    def test_registries_validate(self):
        v = Draft202012Validator(REGISTRY)
        for doc in (DOMAINS, VERBS, FLAGS):
            self.assertEqual(list(v.iter_errors(doc)), [], doc["schema"])

    def test_registry_rejects_bad_domain_names(self):
        v = Draft202012Validator(REGISTRY)
        for bad in ["secrets-x", "Secret", "d", "security1", "observability"]:
            doc = copy.deepcopy(DOMAINS)
            doc["domains"][0]["name"] = bad
            self.assertFalse(v.is_valid(doc), bad)


class Domains(unittest.TestCase):
    def test_seventeen_unique_domains(self):
        self.assertEqual(len(DOMAINS["domains"]), 17)
        self.assertEqual(len(set(names(DOMAINS["domains"]))), 17)

    def test_repo_is_dot_domain(self):
        for d in DOMAINS["domains"]:
            self.assertEqual(d["repo"], f"dot-{d['name']}")

    def test_every_group_is_declared_and_used(self):
        declared = names(DOMAINS["groups"], "id")
        used = {d["group"] for d in DOMAINS["domains"]}
        self.assertEqual(set(declared), used)

    def test_builtins_are_help_and_version_only(self):
        self.assertEqual(DOMAINS["builtins"], ["help", "version"])
        self.assertFalse(set(DOMAINS["builtins"]) & set(names(DOMAINS["domains"])))

    def test_shortcuts_are_the_seven_from_n7(self):
        shortcuts = {s["name"]: s["target"] for d in DOMAINS["domains"] for s in d["shortcuts"]}
        self.assertEqual(shortcuts, {
            "apply": "config apply", "sync": "config sync", "diff": "config diff",
            "status": "config status", "edit": "config edit",
            "cd": "config path", "update": "system update"})

    def test_shortcuts_do_not_shadow_domains_or_builtins(self):
        taken = set(names(DOMAINS["domains"])) | set(DOMAINS["builtins"])
        for d in DOMAINS["domains"]:
            for s in d["shortcuts"]:
                self.assertNotIn(s["name"], taken)
                self.assertIn(s["target"].split()[0], taken)


class Verbs(unittest.TestCase):
    def test_thirty_seven_unique_verbs(self):
        self.assertEqual(len(VERBS["verbs"]), 37)
        self.assertEqual(len(set(names(VERBS["verbs"]))), 37)

    def test_powershell_verbs_are_approved(self):
        for v in VERBS["verbs"]:
            self.assertIn(v["powershell"], PS_APPROVED, v["name"])

    def test_one_spelling(self):
        # N6: a replaced word maps to exactly one verb and is never a verb itself.
        replaced = [w for v in VERBS["verbs"] for w in v["replaces"]]
        self.assertEqual(len(replaced), len(set(replaced)))
        self.assertFalse(set(replaced) & set(names(VERBS["verbs"])))

    def test_shared_powershell_verbs_are_declared(self):
        # N11: two verbs that would generate the same cmdlet need a rule.
        by_ps = {}
        for v in VERBS["verbs"]:
            by_ps.setdefault((v["powershell"], v.get("ps_suffix", "")), []).append(v["name"])
        shared = {(s["powershell"], ""): sorted(s["verbs"]) for s in VERBS["ps_shared"]}
        clashes = {k: sorted(v) for k, v in by_ps.items() if len(v) > 1}
        self.assertEqual(clashes, shared)

    def test_only_uninstall_always_confirms(self):
        self.assertEqual([v["name"] for v in VERBS["verbs"] if v.get("confirms")], ["uninstall"])

    def test_read_verbs_cover_the_safe_defaults(self):
        read = {v["name"] for v in VERBS["verbs"] if v["effect"] == "read"}
        defaults = set(MANIFEST["$defs"]["default"]["enum"]) - {"tui"}
        self.assertLessEqual(defaults, read)


class Flags(unittest.TestCase):
    def test_family_short_options(self):
        short = {f["short"]: f["long"] for f in FLAGS["flags"] if "short" in f}
        self.assertEqual(short, {"h": "help", "V": "version", "v": "verbose",
                                 "q": "quiet", "y": "yes", "n": "dry-run"})

    def test_long_options_unique(self):
        longs = names(FLAGS["flags"], "long")
        self.assertEqual(len(longs), len(set(longs)))

    def test_exit_codes(self):
        self.assertEqual(names(FLAGS["exit_codes"], "code"), [0, 1, 2, 64, 75, 127, 130])


class Manifest(unittest.TestCase):
    v = Draft202012Validator(MANIFEST)

    def test_example_is_valid(self):
        self.assertEqual(list(self.v.iter_errors(EXAMPLE)), [])

    def test_example_uses_registered_words(self):
        verbs = set(names(VERBS["verbs"]))
        self.assertIn(EXAMPLE["domain"], names(DOMAINS["domains"]))
        self.assertEqual(EXAMPLE["name"], EXAMPLE["domain"])
        for c in EXAMPLE["commands"]:
            self.assertIn(c["verb"], verbs)

    def test_rejects_planted_violations(self):
        cases = [
            ("domain", "Secret"), ("domain", "dot-secret"), ("domain", "observability"),
            ("default", "apply"), ("schema", "cli/manifest.v2"), ("unknown", True),
        ]
        for key, value in cases:
            self.assertFalse(self.v.is_valid(dict(EXAMPLE, **{key: value})), key)

    def test_rejects_bad_commands_and_aliases(self):
        mutations = [
            lambda m: m["commands"][0].update(effect="delete"),
            lambda m: m["commands"][0].update(verb="Status"),
            lambda m: m["commands"][0].update(summary="x" * 61),
            lambda m: m["commands"][0].update(output="status-v1"),
            lambda m: m["aliases"][0].pop("until"),
            lambda m: m["aliases"][0].update(kind="hidden"),
            lambda m: m["aliases"][0].update(target="dot secret key new"),
            lambda m: m.update(commands=[]),
        ]
        for i, mutate in enumerate(mutations):
            bad = copy.deepcopy(EXAMPLE)
            mutate(bad)
            self.assertFalse(self.v.is_valid(bad), i)

    def test_summary_is_one_line(self):
        self.assertTrue(re.fullmatch(MANIFEST["$defs"]["summary"]["pattern"], "one line"))
        self.assertFalse(self.v.is_valid(dict(EXAMPLE, summary="two\nlines")))


if __name__ == "__main__":
    unittest.main()
