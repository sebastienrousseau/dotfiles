#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""tools/ci/check-cli-contract.py passes the repository and fails each planted violation."""
import importlib.util
import os
import shutil
import tempfile
import textwrap
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("cli_contract", ROOT / "tools/ci/check-cli-contract.py")
lint_mod = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(lint_mod)

# Keeps the runtime rules: -V and --version print the version, -v alone warns
# and prints it, -v before a command passes on, an unknown command exits 127.
GOOD_DOT = """#!/bin/sh
case "$1" in
  -V|--version) echo "dot 0.2.537" ;;
  -v) [ -n "$2" ] && shift && exec "$0" "$@"; echo "use -V" >&2; echo "dot 0.2.537" ;;
  *) echo "Unknown command: $1" >&2; exit 127 ;;
esac
"""
# Behaves like bin/dot before N0.3: no -V, -v is the version, unknown exits 1.
OLD_DOT = """#!/bin/sh
case "$1" in
  -v|--version) echo "dot 0.2.536" ;;
  *) echo "Unknown command: $1" >&2; exit 1 ;;
esac
"""


class Fixture(unittest.TestCase):
    """A copy of the inputs the lint reads, edited per test."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp)
        for rel in ("schemas/cli", "plugins"):
            shutil.copytree(ROOT / rel, self.tmp / rel)
        for rel in ("lib/dot/data/routes.txt", "lib/dot/data/commands.txt", "lib/dot/data/commands.json", "defaults/.chezmoidata.toml", "tools/ci/cli-contract-baseline.txt"):
            (self.tmp / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(ROOT / rel, self.tmp / rel)
        self.dot = self.fake_dot(GOOD_DOT)

    def fake_dot(self, body):
        path = self.tmp / "dot"
        path.write_text(body)
        os.chmod(path, 0o755)
        return path

    def manifest(self, domain):
        return self.tmp / "plugins" / domain / "dot-plugin.toml"

    def edit(self, domain, old, new):
        path = self.manifest(domain)
        text = path.read_text()
        self.assertIn(old, text, f"fixture text not found in {domain}")
        path.write_text(text.replace(old, new, 1))

    def append(self, domain, toml):
        path = self.manifest(domain)
        path.write_text(path.read_text() + "\n" + textwrap.dedent(toml))

    def errors(self):
        return lint_mod.lint(self.tmp, self.dot)

    def assertFails(self, fragment):
        errors = self.errors()
        self.assertTrue(any(fragment in e for e in errors), f"no error containing {fragment!r}: {errors}")


class Passes(Fixture):
    def test_repository_passes_with_the_real_binary(self):
        self.assertEqual(lint_mod.lint(ROOT, ROOT / "bin/dot"), [])

    def test_fixture_passes(self):
        self.assertEqual(self.errors(), [])

    def test_seventeen_manifests_one_per_domain(self):
        manifests, errors = lint_mod.load_manifests(ROOT)
        self.assertEqual(errors, [])
        self.assertEqual(set(manifests), set(lint_mod.load_registries(ROOT)["domains"]))


class Manifests(Fixture):
    def test_schema_violation(self):
        self.edit("mcp", 'default = "list"', 'default = "serve"')
        self.assertFails("mcp: schema: default")

    def test_directory_must_match_domain(self):
        self.edit("mcp", 'domain = "mcp"', 'domain = "fleet"')
        self.assertFails("must equal the directory name")

    def test_unknown_domain(self):
        shutil.copytree(self.tmp / "plugins/mcp", self.tmp / "plugins/proxy")
        self.edit("proxy", 'name = "mcp"\ndomain = "mcp"', 'name = "proxy"\ndomain = "proxy"')
        self.assertFails("proxy: not a domain")

    def test_unapproved_verb(self):
        self.edit("mcp", 'verb = "check"', 'verb = "doctor"')
        self.assertFails("'doctor' is not an approved verb")

    def test_object_must_be_declared(self):
        self.append("mcp", '[[commands]]\nobject = "server"\nverb = "list"\neffect = "read"\nsummary = "x"\n')
        self.assertFails("object 'server' is not declared")

    def test_object_must_not_be_a_verb(self):
        self.append("mcp", '[[objects]]\nname = "check"\nsummary = "x"\ndefault = "show"\n')
        self.assertFails("object 'check' is a verb")

    def test_effect_must_match_the_verb_class(self):
        self.edit("mcp", 'verb = "check"\neffect = "read"', 'verb = "check"\neffect = "write"')
        self.assertFails("does not match the verb's class 'read'")

    def test_uninstall_is_destructive(self):
        self.edit("config", 'verb = "uninstall"\neffect = "destructive"', 'verb = "uninstall"\neffect = "write"')
        self.assertFails("always confirms")

    def test_output_id_carries_the_domain(self):
        self.edit("mcp", 'summary = "Configured MCP servers"', 'summary = "x"\noutput = "fleet/list.v1"')
        self.assertFails("must start with 'mcp/'")

    def flagged(self, *flags):
        body = '[[commands]]\nverb = "show"\neffect = "read"\nsummary = "x"\n'
        for long, short in flags:
            body += f'\n[[commands.flags]]\nlong = "{long}"\n' + (f'short = "{short}"\n' if short else "") + 'summary = "x"\n'
        self.append("mcp", body)

    def test_flag_declared_twice(self):
        self.flagged(("all", "a"), ("every", "a"))
        self.assertFails("mcp show: flag -a is declared twice")

    def test_family_letter_keeps_its_meaning(self):
        self.flagged(("vendor", "v"))
        self.assertFails("-v means --verbose family-wide, not --vendor (N9)")

    def test_family_flag_keeps_its_letter(self):
        self.flagged(("yes", "Y"))
        self.assertFails("--yes is a family flag; its short form is -y, not -Y (N9)")

    def test_local_letter_for_a_family_flag_without_one(self):
        self.flagged(("json", "j"))
        self.assertEqual([e for e in self.errors() if "mcp show" in e], [])

    def test_two_verbs_sharing_a_cmdlet(self):
        self.append("secret", '[[commands]]\nverb = "apply"\neffect = "write"\nsummary = "x"\n')
        self.assertFails("secret: apply, set would share the Set cmdlet (N11)")

    def test_list_and_show_may_share_get(self):
        self.assertEqual([e for e in self.errors() if "Get cmdlet" in e], [])

    def test_expired_deprecation(self):
        self.edit("fleet", 'kind = "removed"\nuntil = "0.2.538"', 'kind = "deprecated"\nuntil = "0.2.536"')
        self.assertFails("deprecated alias 'teleport' expired")


class Aliases(Fixture):
    def test_duplicate_alias(self):
        self.append("mcp", '[[aliases]]\nname = "teleport"\ntarget = "mcp list"\nkind = "removed"\n')
        self.assertFails("alias 'teleport' is declared by both")

    def test_alias_shadowing_a_domain(self):
        self.append("mcp", '[[aliases]]\nname = "fleet"\ntarget = "mcp list"\nkind = "removed"\n')
        self.assertFails("alias 'fleet' shadows a domain")

    def test_target_with_unknown_command(self):
        self.edit("fleet", 'target = "fleet push"', 'target = "fleet deploy"')
        self.assertFails("'deploy' is neither an object nor a command of 'fleet'")

    def test_target_with_unknown_object_verb(self):
        self.edit("secret", 'target = "secret key new"', 'target = "secret key remove"')
        self.assertFails("'secret key' has no verb 'remove'")

    def test_target_with_unknown_domain(self):
        self.edit("fleet", 'target = "fleet push"', 'target = "host push"')
        self.assertFails("'host' is neither a domain")

    def test_missing_shortcut(self):
        self.edit("system", 'name = "update"\ntarget = "system update"\nkind = "shortcut"',
                  'name = "up"\ntarget = "system update"\nkind = "removed"')
        self.assertFails("shortcut 'update' -> 'system update' is in domains.json but not in the manifest")

    def test_undeclared_shortcut(self):
        self.edit("fleet", 'kind = "removed"\nuntil = "0.2.538"', 'kind = "shortcut"')
        self.assertFails("shortcut 'teleport' -> 'fleet push' is not declared in domains.json")

    def test_route_without_a_new_spelling(self):
        routes = self.tmp / "lib/dot/data/routes.txt"
        routes.write_text(routes.read_text() + "frobnicate|meta\n")
        self.assertFails("route 'frobnicate' has no new spelling")


class Entries(Fixture):
    """A plugin with an [entry] (theme) ships it and keeps no legacy routes (N2)."""

    def test_entry_must_be_named_after_the_domain(self):
        self.edit("theme", 'command = "dot-theme"', 'command = "dot-themes"')
        self.assertFails("theme: entry command must be 'dot-theme'")

    def test_entry_must_be_executable(self):
        os.chmod(self.tmp / "plugins/theme/dot-theme", 0o644)
        self.assertFails("theme: entry plugins/theme/dot-theme is missing or not executable")

    def test_entry_must_exist(self):
        (self.tmp / "plugins/theme/dot-theme").unlink()
        self.assertFails("theme: entry plugins/theme/dot-theme is missing or not executable")

    def test_entry_plugin_names_no_legacy_route(self):
        self.edit("theme", 'verb = "list"\n', 'verb = "list"\nlegacy = "theme list"\n')
        self.assertFails("theme: a plugin with an entry runs its own commands; drop 'legacy'")

    def test_object_fallback_needs_entry_fallback(self):
        self.edit("security", 'name = "disk"\nsummary = "disk encryption"\ndefault = "show"\n',
                  'name = "disk"\nsummary = "disk encryption"\ndefault = "show"\nfallback = true\n')
        self.assertFails("security: object 'disk' has fallback, which needs [entry] fallback = true")

    def test_planned_needs_an_entry(self):
        self.edit("config", 'summary = "What apply would change"\n',
                  'summary = "What apply would change"\nplanned = true\n')
        self.assertFails("config: 'planned' needs an [entry]")


class TableRoutes(Fixture):
    """Every route the command table names is one bin/dot can run."""

    def test_a_record_naming_a_missing_route_fails(self):
        routes = self.tmp / "lib/dot/data/routes.txt"
        routes.write_text("".join(ln for ln in routes.read_text().splitlines(True) if not ln.startswith("registry|")))
        self.assertFails("'cli list --available' runs route 'registry', which lib/dot/data/routes.txt does not have")


class Table(Fixture):
    def test_stale_table_fails(self):
        self.edit("system", 'summary = "Update everything, asking first"', 'summary = "Update all"')
        self.assertFails("lib/dot/data/commands.txt is stale")


class Runtime(Fixture):
    def test_each_old_behaviour_fails(self):
        self.dot = self.fake_dot(OLD_DOT)
        for fragment in ("runtime N10-unknown-127: an unknown command exits 1",
                         "runtime N9-short-version: 'dot -V' exits",
                         "runtime N9-v-is-verbose"):
            self.assertFails(fragment)

    def test_bare_v_must_warn(self):
        self.dot = self.fake_dot(GOOD_DOT.replace('echo "use -V" >&2; ', ""))
        self.assertFails("'dot -v' prints the version without the -V warning")

    def test_v_must_pass_on_to_the_command(self):
        self.dot = self.fake_dot(GOOD_DOT.replace('[ -n "$2" ] && shift && exec "$0" "$@"; ', ""))
        self.assertFails("-v must pass on to the command")

    def test_fixed_violation_must_leave_the_baseline(self):
        baseline = self.tmp / "tools/ci/cli-contract-baseline.txt"
        baseline.write_text(baseline.read_text() + "N9-short-version\n")
        self.assertFails("runtime N9-short-version: fixed; remove it")


if __name__ == "__main__":
    unittest.main()
