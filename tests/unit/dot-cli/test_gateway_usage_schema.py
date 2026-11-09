#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""What dot-ai-serve serves at /v1/usage (and `dot ai gateway show --json`
prints) is ai/gateway-usage.v1.

The gateway is loaded from its path with a mock engine, answers a few
requests in-process, and its report is validated against
schemas/cli/ai-gateway-usage.v1.schema.json, before and after.
"""

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[3]
SCHEMA = (ROOT / "schemas/cli/ai-gateway-usage.v1.schema.json").read_text()
sys.path.insert(0, str(Path(__file__).resolve().parent))
from dot_ai_serve_units import load  # noqa: E402

VALIDATOR = Draft202012Validator(json.loads(SCHEMA))


class GatewayUsage(unittest.TestCase):
    def test_the_report_is_gateway_usage_v1(self):
        with tempfile.TemporaryDirectory() as tmp:
            engine = Path(tmp) / "claude"
            engine.write_text(
                "#!/bin/sh\ncat >/dev/null\n"
                "echo '{\"type\":\"result\",\"result\":\"ok\",\"usage\":{\"input_tokens\":5,\"output_tokens\":2}}'\n"
            )
            engine.chmod(0o755)
            srv = load({"DOT_AI_CLAUDE_BIN": str(engine), "DOT_AI_DAILY_BUDGET": "2"})
            VALIDATOR.validate(srv.usage_report())
            os.environ["DOT_AI_TIMEOUT"] = "20"
            text, usage, err, _ = srv.run_claude("haiku", "", "hi")
            srv.record("haiku", 5, 2, False, err)
            report = srv.usage_report()
            VALIDATOR.validate(report)
            self.assertEqual(("ok", 1), (text, report["by_model"]["haiku"]["requests"]))

    def test_the_schema_refuses_an_unknown_field(self):
        srv = load()
        report = {**srv.usage_report(), "prompt": "never"}
        self.assertFalse(VALIDATOR.is_valid(report))


if __name__ == "__main__":
    unittest.main(verbosity=1)
