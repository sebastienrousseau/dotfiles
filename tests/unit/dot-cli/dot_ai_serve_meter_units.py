# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""What a request through dot-ai-serve costs, as its counters
(gateway_meter.py) and its usage log record it.

Driven by test_dot_ai_serve_tools.sh. Both endpoints, whole and streamed,
run against a mock `claude` that prints canned stream-json events, so no
real model is called.
"""

from __future__ import annotations

import http.client
import json
import sys
import tempfile
import threading
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from dot_ai_serve_units import load  # noqa: E402

# One turn as the CLI reports it: the model's id on its message, and its
# own cost for the run on the result.
TURN = [
    {"type": "assistant", "message": {"id": "m1", "model": "claude-haiku-5-5",
                                      "content": [{"type": "text", "text": "ok"}]}},
    {"type": "result", "is_error": False, "result": "ok", "total_cost_usd": 0.0123,
     "usage": {"input_tokens": 1000, "output_tokens": 20}},
]


class Server(unittest.TestCase):
    events = TURN

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        events = self.tmp / "events.jsonl"
        events.write_text("".join(json.dumps(e) + "\n" for e in self.events))
        engine = self.tmp / "claude"
        engine.write_text(f'#!/bin/sh\ncat >/dev/null\ncat "{events}"\n')
        engine.chmod(0o755)
        self.state = self.tmp / "state"
        self.srv = load({"DOT_AI_CLAUDE_BIN": str(engine), "XDG_STATE_HOME": str(self.state),
                         "DOT_AI_POLICY": str(self.tmp / "no-policy.toml")})
        self.srv.API_KEY = "k"
        self.httpd = self.srv.ThreadingHTTPServer(("127.0.0.1", 0), self.srv.Handler)
        self.srv.PORT = self.httpd.server_address[1]
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()

    def post(self, path, **extra):
        body = {"model": "haiku", "messages": [{"role": "user", "content": "hi"}], **extra}
        conn = http.client.HTTPConnection("127.0.0.1", self.srv.PORT, timeout=20)
        headers = {"Host": f"127.0.0.1:{self.srv.PORT}", "x-api-key": "k", "Content-Type": "application/json"}
        conn.request("POST", path, body=json.dumps(body), headers=headers)
        resp = conn.getresponse()
        data = resp.read()
        conn.close()
        self.assertEqual(200, resp.status, data)
        return data


class Cost(Server):
    def test_claudes_own_cost_is_what_a_request_costs(self):
        self.post("/v1/messages")
        self.post("/v1/chat/completions", stream=True)
        report = self.srv.usage_report()
        self.assertAlmostEqual(0.0246, report["cost_usd"], places=9)
        self.assertAlmostEqual(0.0246, report["budget"]["spent_today_usd"], places=9)
        self.assertAlmostEqual(0.0246, report["by_model"]["haiku"]["cost"], places=9)

    def test_the_fallback_prices_are_the_current_models(self):
        est = self.srv.METER.estimate
        self.assertAlmostEqual(24.0, est("claude-opus-5-5", 1e6, 1e6))
        self.assertAlmostEqual(12.0, est("claude-sonnet-5-5", 1e6, 1e6))
        self.assertAlmostEqual(0.6, est("haiku", 1e6, 1e6))


class CostWithoutClaudesFigure(Server):
    # A turn that ends in tool calls is stopped before its result event.
    events = [TURN[0], {"type": "result", "is_error": False, "result": "ok",
                        "usage": {"input_tokens": 1000, "output_tokens": 20}}]

    def test_the_price_table_applies(self):
        self.post("/v1/messages")
        self.assertAlmostEqual((1000 * 0.10 + 20 * 0.50) / 1e6, self.srv.usage_report()["cost_usd"], places=12)


if __name__ == "__main__":
    unittest.main()
