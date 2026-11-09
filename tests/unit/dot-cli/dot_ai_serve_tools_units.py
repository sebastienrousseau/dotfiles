# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Images and tool calls through dot-ai-serve's endpoints (plan P1.2).

Driven by test_dot_ai_serve_tools.sh. Both endpoints run against a mock
`claude` that records its argv and stdin and prints canned stream-json
events, so no real model is called. The units of the gateway's modules are
in dot_ai_serve_shape_units.py.
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
from dot_ai_serve_shape_units import PNG, anthropic_tool, openai_tool  # noqa: E402
from dot_ai_serve_units import load  # noqa: E402

# Canned engine events: a text block, two tool calls in one message, then
# the API's end of turn. The engine then sleeps, as the CLI would go on to
# refuse the calls; the gateway must stop it instead of waiting.
TOOL_TURN = [
    {"type": "assistant", "message": {"id": "m1", "content": [{"type": "text", "text": "Checking."}]}},
    {"type": "assistant", "message": {"id": "m1", "content": [
        {"type": "tool_use", "id": "toolu_1", "name": "mcp__client__get_weather", "input": {"city": "Paris"}}]}},
    {"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": "toolu_1"}]}},
    {"type": "assistant", "message": {"id": "m1", "content": [
        {"type": "tool_use", "id": "toolu_2", "name": "mcp__client__get_weather", "input": {"city": "Rome"}}]}},
    {"type": "assistant", "message": {"id": "m1", "content": [
        {"type": "tool_use", "id": "toolu_3", "name": "Bash", "input": {"command": "id"}}]}},
    {"type": "stream_event", "event": {"type": "message_delta", "delta": {"stop_reason": "tool_use"},
                                       "usage": {"input_tokens": 7, "cache_read_input_tokens": 3, "output_tokens": 11}}},
]


class Endpoints(unittest.TestCase):
    """Both endpoints, whole and streamed, against the mock engine."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        events = self.tmp / "events.jsonl"
        events.write_text("".join(json.dumps(e) + "\n" for e in TOOL_TURN))
        engine = self.tmp / "claude"
        engine.write_text(
            "#!/bin/sh\n"
            f'printf "%s\\n" "$@" >"{self.tmp}/argv"\n'
            f'cat >"{self.tmp}/stdin"\n'
            f'cat "{events}"\n'
            "exec sleep 30\n"
        )
        engine.chmod(0o755)
        self.srv = load({"DOT_AI_CLAUDE_BIN": str(engine), "XDG_STATE_HOME": str(self.tmp / "state")})
        self.srv.API_KEY = "k"
        self.httpd = self.srv.ThreadingHTTPServer(("127.0.0.1", 0), self.srv.Handler)
        self.srv.PORT = self.httpd.server_address[1]
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()

    def post(self, path, body):
        conn = http.client.HTTPConnection("127.0.0.1", self.srv.PORT, timeout=20)
        headers = {"Host": f"127.0.0.1:{self.srv.PORT}", "x-api-key": "k", "Content-Type": "application/json"}
        started = time.monotonic()
        conn.request("POST", path, body=json.dumps(body), headers=headers)
        resp = conn.getresponse()
        data = resp.read()
        conn.close()
        self.assertLess(time.monotonic() - started, 10, "the engine is stopped at the end of the turn")
        return resp.status, data

    def body(self, tools, **extra):
        return {"model": "sonnet", "messages": [{"role": "user", "content": "weather?"}], "tools": tools, **extra}

    def test_anthropic_returns_the_tool_calls(self):
        status, data = self.post("/v1/messages", self.body([anthropic_tool()]))
        self.assertEqual(200, status, data)
        msg = json.loads(data)
        self.assertEqual("tool_use", msg["stop_reason"])
        self.assertEqual(
            [
                {"type": "text", "text": "Checking."},
                {"type": "tool_use", "id": "toolu_1", "name": "get_weather", "input": {"city": "Paris"}},
                {"type": "tool_use", "id": "toolu_2", "name": "get_weather", "input": {"city": "Rome"}},
            ],
            msg["content"],
        )
        self.assertEqual({"input_tokens": 10, "output_tokens": 11}, msg["usage"])

    def test_openai_returns_the_tool_calls(self):
        status, data = self.post("/v1/chat/completions", self.body([openai_tool()]))
        self.assertEqual(200, status, data)
        choice = json.loads(data)["choices"][0]
        self.assertEqual("tool_calls", choice["finish_reason"])
        self.assertEqual("Checking.", choice["message"]["content"])
        self.assertEqual(
            [
                {"id": "toolu_1", "type": "function", "function": {"name": "get_weather", "arguments": '{"city": "Paris"}'}},
                {"id": "toolu_2", "type": "function", "function": {"name": "get_weather", "arguments": '{"city": "Rome"}'}},
            ],
            choice["message"]["tool_calls"],
        )

    def test_engine_gets_the_tools_and_the_images(self):
        src = {"type": "base64", "media_type": "image/png", "data": PNG}
        body = self.body([anthropic_tool()])
        body["messages"] = [{"role": "user", "content": [{"type": "text", "text": "hi"}, {"type": "image", "source": src}]}]
        self.post("/v1/messages", body)
        argv = (self.tmp / "argv").read_text().splitlines()
        self.assertIn("--include-partial-messages", argv)
        self.assertEqual("stream-json", argv[argv.index("--input-format") + 1])
        self.assertEqual("", argv[argv.index("--tools") + 1], "the CLI's own tools stay off")
        self.assertNotIn("--allowedTools", argv, "the client's tools are never allowed to run")
        server = json.loads(argv[argv.index("--mcp-config") + 1])["mcpServers"]["client"]
        self.assertEqual(sys.executable, server["command"])
        self.assertTrue(server["args"][0].endswith("gateway_stub.py"))
        self.assertNotIn("get_weather", argv[argv.index("--mcp-config") + 1], "tools go in a file, not argv")
        sent = json.loads((self.tmp / "stdin").read_text())
        self.assertEqual({"type": "image", "source": src}, sent["message"]["content"][1])

    def test_no_tools_means_no_mcp_server(self):
        self.post("/v1/messages", self.body([]))
        argv = (self.tmp / "argv").read_text().splitlines()
        self.assertEqual({"mcpServers": {}}, json.loads(argv[argv.index("--mcp-config") + 1]))
        self.assertNotIn("--include-partial-messages", argv)

    def test_anthropic_stream_has_tool_use_blocks(self):
        status, data = self.post("/v1/messages", self.body([anthropic_tool()], stream=True))
        events = [json.loads(line[6:]) for line in data.decode().splitlines() if line.startswith("data: ")]
        starts = [e["content_block"] for e in events if e["type"] == "content_block_start"]
        self.assertEqual(["text", "tool_use", "tool_use"], [b["type"] for b in starts])
        self.assertEqual({"type": "tool_use", "id": "toolu_2", "name": "get_weather", "input": {}}, starts[2])
        partial = [e["delta"]["partial_json"] for e in events if e.get("delta", {}).get("type") == "input_json_delta"]
        self.assertEqual(['{"city": "Paris"}', '{"city": "Rome"}'], partial)
        stops = [e["index"] for e in events if e["type"] == "content_block_stop"]
        self.assertEqual([0, 1, 2], stops)
        delta = next(e for e in events if e["type"] == "message_delta")
        self.assertEqual("tool_use", delta["delta"]["stop_reason"])

    def test_openai_stream_has_tool_call_deltas(self):
        status, data = self.post("/v1/chat/completions", self.body([openai_tool()], stream=True))
        chunks = [json.loads(line[6:]) for line in data.decode().splitlines()
                  if line.startswith("data: {")]
        calls = [c["choices"][0]["delta"]["tool_calls"][0] for c in chunks if "tool_calls" in c["choices"][0]["delta"]]
        self.assertEqual([0, 1], [c["index"] for c in calls])
        self.assertEqual({"name": "get_weather", "arguments": '{"city": "Rome"}'}, calls[1]["function"])
        self.assertEqual("tool_calls", chunks[-1]["choices"][0]["finish_reason"])

    def test_bad_input_is_a_400(self):
        status, data = self.post("/v1/messages", self.body([anthropic_tool("bad name")]))
        self.assertEqual(400, status)
        self.assertIn(b"tool name", data)

    def test_a_line_that_is_not_an_object_is_skipped(self):
        events_file = self.tmp / "events.jsonl"
        events_file.write_text("42\n" + events_file.read_text())
        status, data = self.post("/v1/messages", self.body([anthropic_tool()]))
        self.assertEqual("tool_use", json.loads(data)["stop_reason"])

    def test_streamed_tool_calls_are_counted(self):
        self.post("/v1/messages", self.body([anthropic_tool()], stream=True))
        report = self.srv.usage_report()
        self.assertEqual((2, 1), (report["tool_calls"], report["streamed"]))

    def test_metrics_count_images_and_tool_calls(self):
        src = {"type": "base64", "media_type": "image/png", "data": PNG}
        body = self.body([anthropic_tool()])
        body["messages"] = [{"role": "user", "content": [{"type": "image", "source": src}]}]
        self.post("/v1/messages", body)
        report = self.srv.usage_report()
        self.assertEqual((1, 2, 0), (report["images"], report["tool_calls"], report["streamed"]))
        text = self.srv.metrics_text()
        self.assertIn("dot_ai_images_total 1\n", text)
        self.assertIn("dot_ai_tool_calls_total 2\n", text)


if __name__ == "__main__":
    unittest.main(verbosity=1)
