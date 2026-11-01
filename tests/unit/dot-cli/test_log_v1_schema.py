#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""What lib/dot/log.sh writes is cli/log.v1 (schemas/cli/log.v1.schema.json).

Each case runs the real dot_log, dot_metric, agent session and fleet event
writers in a bash with a temporary XDG_STATE_HOME, then validates every
line against the schema. Hostile values (quotes, backslashes, newlines,
control bytes, a key with `=` in its value) must still yield one valid
JSON line each, holding the value as given.
"""
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[3]
SCHEMA = json.loads((ROOT / "schemas/cli/log.v1.schema.json").read_text())
VALIDATOR = Draft202012Validator(SCHEMA)


def run(snippet: str, state: Path, **env: str) -> None:
    base = {"PATH": "/usr/bin:/bin", "HOME": str(state), "XDG_STATE_HOME": str(state),
            "DOT_TRACE_ID": "trace-1", "DOT_COMMAND": "test"}
    subprocess.run(["bash", "-c", f'set -euo pipefail; source "$1/lib/dot/log.sh"; {snippet}', "_", str(ROOT)],
                   check=True, env={**base, **env})


def records(state: Path, domain: str) -> list[dict]:
    lines = (state / "dot" / domain / "log.jsonl").read_text().splitlines()
    return [json.loads(line) for line in lines]


class LogV1(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.state = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def assertValid(self, rec):
        errors = [e.message for e in VALIDATOR.iter_errors(rec)]
        self.assertEqual(errors, [], rec)

    def test_schema_is_valid(self):
        Draft202012Validator.check_schema(SCHEMA)

    def test_hostile_values_stay_one_valid_line(self):
        run("dot_log warn odd 'quote=a \"b\" c' 'slash=x\\y' $'nl=one\\ntwo' $'ctl=a\\x01b\\x7f' 'eq=k=v' bare",
            self.state)
        (rec,) = records(self.state, "cli")
        self.assertValid(rec)
        self.assertEqual(rec["data"], {"quote": 'a "b" c', "slash": "x\\y", "nl": "one\ntwo",
                                       "ctl": "ab", "eq": "k=v", "bare": ""})
        self.assertEqual((rec["level"], rec["event"], rec["trace_id"]), ("warn", "odd", "trace-1"))

    def test_each_writer_is_log_v1_in_its_domain(self):
        run("dot_metric startup 142; dot_agent_session_log start plan ok tool=claude", self.state,
            DOT_LOG_DOMAIN="doctor")
        doctor, agent = records(self.state, "doctor"), records(self.state, "agent")
        for rec in doctor + agent:
            self.assertValid(rec)
        self.assertEqual(doctor[0]["data"], {"name": "startup", "value": "142", "unit": "ms"})
        self.assertEqual((agent[0]["domain"], agent[0]["event"]), ("agent", "session_start"))

    def test_a_bad_domain_falls_back_to_cli(self):
        run("dot_log info escape", self.state, DOT_LOG_DOMAIN="../../etc")
        self.assertEqual(records(self.state, "cli")[0]["domain"], "cli")
        self.assertEqual(sorted(p.name for p in (self.state / "dot").iterdir()), ["cli"])

    def test_levels_below_the_threshold_are_dropped(self):
        run("dot_log debug quiet; dot_log info kept", self.state)
        run("dot_log debug loud", self.state, DOT_VERBOSE="1")
        run("dot_log warn quiet2; dot_log error kept2", self.state, DOT_LOG_LEVEL="error")
        self.assertEqual([r["event"] for r in records(self.state, "cli")], ["kept", "loud", "kept2"])

    def test_prune_keeps_the_retention_window(self):
        log = self.state / "dot" / "theme" / "log.jsonl"
        log.parent.mkdir(parents=True)
        old = {"schema": "cli/log.v1", "time": "2020-01-01T00:00:00Z", "level": "info", "domain": "theme",
               "event": "old", "command": "t", "trace_id": "t", "pid": 1, "data": {}}
        log.write_text(json.dumps(old, separators=(",", ":")) + "\n")
        run("DOT_LOG_DOMAIN=theme dot_log info new; dot_log_prune", self.state)
        self.assertEqual([r["event"] for r in records(self.state, "theme")], ["new"])
        run('rc=0; dot_log_prune soon || rc=$?; [ "$rc" = 64 ]', self.state)
        self.assertEqual([r["event"] for r in records(self.state, "theme")], ["new"],
                         "a retention that is not a number is refused, and nothing is pruned")


if __name__ == "__main__":
    unittest.main()
