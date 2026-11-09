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
import time
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


class UsageLog(Server):
    """$XDG_STATE_HOME/dot/ai/serve/usage.jsonl: a line per request, which
    dot ai cost show reads (dot-ai-tui, costparse.go)."""

    def lines(self):
        log = self.state / "dot" / "ai" / "serve" / "usage.jsonl"
        self.assertEqual(0o600, log.stat().st_mode & 0o777)
        return [json.loads(ln) for ln in log.read_text().splitlines()]

    def test_each_request_is_a_line(self):
        self.post("/v1/messages")
        self.post("/v1/messages", stream=True)
        lines = self.lines()
        self.assertEqual(2, len(lines))
        for ln in lines:
            self.assertEqual({"time", "model", "tokens", "cost_usd"}, set(ln))
            self.assertRegex(ln["time"], r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$")
            self.assertEqual("claude-haiku-5-5", ln["model"], "the model's own id")
            self.assertEqual({"input": 1000, "cache_write_5m": 0, "cache_write_1h": 0, "cache_read": 0, "output": 20},
                             ln["tokens"])
            self.assertEqual(0.0123, ln["cost_usd"])
        self.assertNotIn("hi", (self.state / "dot" / "ai" / "serve" / "usage.jsonl").read_text(), "never the prompt")

    def test_a_full_log_is_set_aside(self):
        self.srv.METER.log_max = 10
        self.post("/v1/messages")
        self.post("/v1/messages")
        logs = sorted(p.name for p in (self.state / "dot" / "ai" / "serve").glob("usage*.jsonl"))
        self.assertEqual(2, len(logs), logs)
        self.assertRegex(logs[0], r"^usage-\d{8}T\d{6}-\d+\.jsonl$")
        self.assertEqual(1, len(self.lines()))

    def test_a_log_that_cannot_be_written_costs_nothing(self):
        (self.state / "dot" / "ai" / "serve").mkdir(parents=True, exist_ok=True)
        (self.state / "dot" / "ai" / "serve" / "usage.jsonl").mkdir()
        self.post("/v1/messages")
        self.assertEqual(1, self.srv.usage_report()["requests"])


class MeterUnits(unittest.TestCase):
    """The Meter itself (gateway_meter.py), without a server."""

    def setUp(self):
        sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "defaults/dot_local/share/dot-ai-serve"))
        from gateway_meter import Meter

        self.tmp = Path(tempfile.mkdtemp())
        self.log = self.tmp / "serve" / "usage.jsonl"
        self.m = Meter({"haiku": (1.0, 2.0)}, 1.0, str(self.log))

    def test_counters_per_model_and_the_budget(self):
        m = self.m
        m.record("haiku", 100_000, 0, False, None)
        m.record("haiku", 0, 200_000, True, "boom", {"cost_usd": 0.5})
        self.assertEqual((2, 1, 1, 100_000, 200_000), tuple(m.metrics[k] for k in
                         ("requests", "errors", "streamed", "input_tokens", "output_tokens")))
        self.assertEqual({"requests": 2, "input": 100_000, "output": 200_000, "cost": 0.6},
                         {**m.metrics["by_model"]["haiku"], "cost": round(m.metrics["by_model"]["haiku"]["cost"], 9)})
        self.assertFalse(m.budget_exceeded(), "0.6 of 1.0")
        m.record("haiku", 400_000, 0, False, None)
        self.assertTrue(m.budget_exceeded(), "1.0 of 1.0")
        m.budget["day"] = "1999-01-01"
        self.assertFalse(m.budget_exceeded(), "a new day starts at 0")
        self.assertEqual(time.strftime("%Y-%m-%d"), m.budget["day"])

    def test_the_log_splits_the_cache_writes(self):
        self.log.parent.mkdir()  # the directory is there, the log not yet
        usage = {"input_tokens": 1, "cache_creation_input_tokens": 50, "cache_read_input_tokens": 7,
                 "output_tokens": 2, "cache_creation": {"ephemeral_1h_input_tokens": 30}}
        self.m.record("haiku", 58, 2, False, None, usage)
        line = json.loads(self.log.read_text())
        self.assertEqual({"input": 1, "cache_write_5m": 20, "cache_write_1h": 30, "cache_read": 7, "output": 2},
                         line["tokens"])

    def test_a_log_is_set_aside_at_exactly_its_limit(self):
        self.m.record("haiku", 1, 1, False, None)
        self.m.log_max = self.log.stat().st_size
        self.m.record("haiku", 1, 1, False, None)
        self.assertEqual(2, len(list(self.log.parent.glob("usage*.jsonl"))))

    def test_prometheus_text(self):
        self.m.record('a"b\\c', 1, 1, False, None)
        text = self.m.prometheus()
        self.assertRegex(text, r"^dot_ai_uptime_seconds \d+\n")
        self.assertIn('dot_ai_model_requests_total{model="abc"} 1\n', text)
        self.assertIn('dot_ai_model_cost_usd_total{model="abc"} ', text)
        self.assertIn("dot_ai_budget_limit_usd 1.000000\n", text)


class CostWithoutClaudesFigure(Server):
    # A turn that ends in tool calls is stopped before its result event.
    events = [TURN[0], {"type": "result", "is_error": False, "result": "ok",
                        "usage": {"input_tokens": 1000, "output_tokens": 20}}]

    def test_the_price_table_applies(self):
        self.post("/v1/messages")
        self.assertAlmostEqual((1000 * 0.10 + 20 * 0.50) / 1e6, self.srv.usage_report()["cost_usd"], places=12)
        # The log leaves the price to its reader, who knows the model.
        log = self.state / "dot" / "ai" / "serve" / "usage.jsonl"
        self.assertIsNone(json.loads(log.read_text())["cost_usd"])


if __name__ == "__main__":
    unittest.main()
