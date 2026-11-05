#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""What `dot cli hook run` writes is cli/agent-event.v1.

Each case runs plugins/cli/libexec/hook.sh with a hook payload in a
temporary XDG_STATE_HOME and validates the state file against
schemas/cli/agent-event.v1.schema.json, including a hostile cwd (quotes,
backslashes, a newline, control bytes) that must stay one valid record.
"""

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[3]
SCHEMA = json.loads((ROOT / "schemas/cli/agent-event.v1.schema.json").read_text())
VALIDATOR = Draft202012Validator(SCHEMA)
HOOK = ROOT / "plugins/cli/libexec/hook.sh"


class AgentEvent(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.state = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def hook(self, payload: dict, *args: str) -> dict:
        env = {
            "PATH": "/usr/bin:/bin",
            "HOME": str(self.state),
            "XDG_STATE_HOME": str(self.state),
        }
        done = subprocess.run(
            ["bash", str(HOOK), *args],
            input=json.dumps(payload),
            env=env,
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertEqual((done.stdout, done.stderr), ("", ""))
        agent = args[1] if args[:1] == ("--agent",) else "claude"
        return json.loads(
            (
                self.state / "dot/cli/agents" / agent / f"{payload['session_id']}.json"
            ).read_text()
        )

    def test_schema_is_valid(self):
        Draft202012Validator.check_schema(SCHEMA)

    def test_every_state_is_a_valid_record(self):
        for event, state in [
            ("UserPromptSubmit", "running"),
            ("PermissionRequest", "blocked"),
            ("Stop", "idle"),
            ("StopFailure", "error"),
            ("SessionEnd", "gone"),
        ]:
            rec = self.hook(
                {
                    "session_id": "s1",
                    "hook_event_name": event,
                    "cwd": "/w",
                    "prompt": "secret",
                }
            )
            self.assertEqual(list(VALIDATOR.iter_errors(rec)), [], rec)
            self.assertEqual((rec["state"], rec["event"]), (state, event))
            self.assertNotIn("secret", json.dumps(rec))

    def test_a_hostile_cwd_stays_one_valid_record(self):
        cwd = '/w/a "q" b\\c\nd\x01e'
        rec = self.hook(
            {"session_id": "s2", "hook_event_name": "Stop", "cwd": cwd},
            "--agent",
            "gemini",
        )
        self.assertEqual(list(VALIDATOR.iter_errors(rec)), [], rec)
        self.assertEqual(rec["cwd"], '/w/a "q" b\\cde')
        self.assertEqual(rec["agent"], "gemini")


if __name__ == "__main__":
    unittest.main()
