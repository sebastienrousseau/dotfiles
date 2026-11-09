#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""What `dot ai cost show --json` prints is ai/cost-report.v1.

The cockpit's own tests keep its report for a fixed set of transcripts in
defaults/dot_local/share/dot-ai-tui/testdata/cost-report.json (and fail when
it is stale); this validates that report against
schemas/cli/ai-cost-report.v1.schema.json, and checks the schema refuses
what the report must never carry.
"""

import copy
import json
import unittest
from pathlib import Path

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[3]
SCHEMA = json.loads((ROOT / "schemas/cli/ai-cost-report.v1.schema.json").read_text())
REPORT = json.loads((ROOT / "defaults/dot_local/share/dot-ai-tui/testdata/cost-report.json").read_text())
VALIDATOR = Draft202012Validator(SCHEMA)


class CostReport(unittest.TestCase):
    def test_the_report_is_cost_report_v1(self):
        VALIDATOR.validate(REPORT)
        self.assertEqual("ai/cost-report.v1", REPORT["schema"])
        self.assertGreater(len(REPORT["rows"]), 1)

    def test_a_session_report_names_it(self):
        report = {**copy.deepcopy(REPORT), "by": "model", "session": "aaaa1111-0000", "agent": "claude"}
        VALIDATOR.validate(report)

    def test_the_schema_refuses_an_unknown_field(self):
        self.assertFalse(VALIDATOR.is_valid({**REPORT, "prompt": "never"}))
        row = {**REPORT["rows"][0], "prompt": "never"}
        self.assertFalse(VALIDATOR.is_valid({**REPORT, "rows": [row]}))

    def test_a_row_without_its_key_or_a_negative_cost_is_refused(self):
        row = dict(REPORT["rows"][0])
        del row["key"]
        self.assertFalse(VALIDATOR.is_valid({**REPORT, "rows": [row]}))
        self.assertFalse(VALIDATOR.is_valid({**REPORT, "total": {**REPORT["total"], "cost_usd": -1}}))
        self.assertFalse(VALIDATOR.is_valid({**REPORT, "by": "planet"}))


if __name__ == "__main__":
    unittest.main()
