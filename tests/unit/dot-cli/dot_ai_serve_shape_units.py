# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Images and tool calls through dot-ai-serve (plan P1.2): request shaping,
the engine's events, the response builders and the MCP stub, tested on the
gateway's modules directly. Driven by test_dot_ai_serve_tools.sh, with the
endpoint tests in dot_ai_serve_tools_units.py.
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
SHARE = REPO / "defaults" / "dot_local" / "share" / "dot-ai-serve"
sys.path.insert(0, str(SHARE))
import gateway_events as events  # noqa: E402
import gateway_shape as shape  # noqa: E402

PNG = "iVBORw0KGgo="
WEATHER = {"type": "object", "properties": {"city": {"type": "string"}}}


def anthropic_tool(name="get_weather"):
    return {"name": name, "description": "Weather for a city", "input_schema": WEATHER}


def openai_tool(name="get_weather"):
    fn = {"name": name, "description": "Weather for a city", "parameters": WEATHER}
    return {"type": "function", "function": fn}


class Images(unittest.TestCase):
    def test_anthropic_base64_image_is_forwarded(self):
        src = {"type": "base64", "media_type": "image/png", "data": PNG}
        s = shape.shape_request(
            {"messages": [{"role": "user", "content": [{"type": "text", "text": "what?"}, {"type": "image", "source": src}]}]},
            "sonnet",
        )
        self.assertEqual([{"type": "image", "source": src}], s.images)
        self.assertEqual("what?\n[image 1]", s.prompt)

    def test_openai_data_url_and_http_url(self):
        content = [
            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{PNG}"}},
            {"type": "image_url", "image_url": "https://example.com/a.png"},
        ]
        s = shape.shape_request({"messages": [{"role": "user", "content": content}]}, "sonnet")
        self.assertEqual(
            [
                {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": PNG}},
                {"type": "image", "source": {"type": "url", "url": "https://example.com/a.png"}},
            ],
            s.images,
        )
        self.assertEqual("[image 1]\n[image 2]", s.prompt)

    def test_anthropic_url_image(self):
        block = {"type": "image", "source": {"type": "url", "url": "https://example.com/a.png"}}
        self.assertEqual(block, shape.image_of(block))

    def test_refusals_say_why(self):
        def refusal(content=None, **body):
            msgs = [{"role": "user", "content": content or "hi"}]
            with self.assertRaises(ValueError) as cm:
                shape.shape_request({"messages": msgs, **body}, "sonnet")
            return str(cm.exception)
        img = lambda src: [{"type": "image", "source": src}]  # noqa: E731
        self.assertEqual("unsupported image type 'image/tiff' (png, jpeg, gif or webp)",
                         refusal(img({"type": "base64", "media_type": "image/tiff", "data": PNG})))
        self.assertEqual("an image has no data", refusal(img({"type": "base64", "media_type": "image/png"})))
        self.assertEqual("an image URL must be http(s) or a base64 data URL", refusal(img({"type": "url", "url": "ftp://x"})))
        self.assertEqual("unsupported image source 'file'", refusal(img({"type": "file"})))
        self.assertEqual("two tools have the same name", refusal(tools=[anthropic_tool(), anthropic_tool()]))
        self.assertEqual("tool_choice names 'x', which is not in tools",
                         refusal(tools=[anthropic_tool()], tool_choice={"type": "tool", "name": "x"}))
        self.assertEqual("tool type 'bash_20250124' is not supported; only client tools are",
                         refusal(tools=[{"type": "bash_20250124", "name": "bash"}]))
        self.assertEqual("tool name 'a b' must be 1-64 letters, digits, _ or -", refusal(tools=[anthropic_tool("a b")]))

    def test_a_block_with_string_content_gives_it(self):
        self.assertEqual("d", shape.text_of([{"type": "document", "content": "d"}], []))
        self.assertEqual("", shape.text_of([{"type": "document", "content": ["d"]}], []))

    def test_bad_images_are_refused(self):
        for block in (
            {"type": "image", "source": {"type": "base64", "media_type": "image/tiff", "data": PNG}},
            {"type": "image", "source": {"type": "file", "file_id": "f"}},
            {"type": "image_url", "image_url": {"url": "data:text/plain;base64,QQ=="}},
            {"type": "image_url", "image_url": {"url": "file:///etc/passwd"}},
            {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": ""}},
        ):
            with self.subTest(block=block), self.assertRaises(ValueError):
                shape.shape_request({"messages": [{"role": "user", "content": [block]}]}, "sonnet")


class Tools(unittest.TestCase):
    def tools_of(self, body):
        return shape.shape_request({"messages": [{"role": "user", "content": "hi"}], **body}, "sonnet")

    def test_both_tool_shapes_become_mcp_tools(self):
        want = [{"name": "get_weather", "description": "Weather for a city", "inputSchema": WEATHER}]
        self.assertEqual(want, self.tools_of({"tools": [anthropic_tool()]}).tools)
        self.assertEqual(want, self.tools_of({"tools": [openai_tool()]}).tools)

    def test_a_tool_with_no_schema_gets_an_empty_object(self):
        s = self.tools_of({"tools": [{"name": "ping"}]})
        self.assertEqual([{"name": "ping", "description": "", "inputSchema": {"type": "object"}}], s.tools)

    def test_unusable_tools_are_refused(self):
        for tools in (
            [anthropic_tool("bad name")],
            [anthropic_tool("x" * 65)],
            [{"type": "web_search_20250305", "name": "web_search"}],
            [anthropic_tool(), anthropic_tool()],
            ["get_weather"],
        ):
            with self.subTest(tools=tools), self.assertRaises(ValueError):
                self.tools_of({"tools": tools})

    def test_tool_choice(self):
        tools = {"tools": [anthropic_tool()]}
        self.assertEqual([], self.tools_of({**tools, "tool_choice": {"type": "none"}}).tools)
        self.assertEqual([], self.tools_of({**tools, "tool_choice": "none"}).tools)
        for choice in ({"type": "any"}, "required"):
            self.assertIn("must call one of the tools", self.tools_of({**tools, "tool_choice": choice}).system)
        for choice in ({"type": "tool", "name": "get_weather"}, {"type": "function", "function": {"name": "get_weather"}}):
            self.assertIn("must call the tool get_weather", self.tools_of({**tools, "tool_choice": choice}).system)
        self.assertEqual("", self.tools_of({**tools, "tool_choice": "auto"}).system)
        with self.assertRaises(ValueError):
            self.tools_of({**tools, "tool_choice": {"type": "tool", "name": "other"}})

    def test_anthropic_tool_turns_are_kept_in_the_transcript(self):
        s = shape.shape_request(
            {
                "messages": [
                    {"role": "user", "content": "weather?"},
                    {"role": "assistant", "content": [
                        {"type": "text", "text": "Checking."},
                        {"type": "tool_use", "id": "t1", "name": "get_weather", "input": {"city": "Paris"}},
                    ]},
                    {"role": "user", "content": [
                        {"type": "tool_result", "tool_use_id": "t1", "content": [{"type": "text", "text": "sunny"}]},
                        {"type": "tool_result", "tool_use_id": "t2", "is_error": True, "content": "down"},
                    ]},
                ]
            },
            "sonnet",
        )
        self.assertEqual(
            "User: weather?\n\n"
            'Assistant: Checking.\n[tool call get_weather (id t1): {"city": "Paris"}]\n\n'
            "User: [tool result (id t1): sunny]\n[tool error (id t2): down]\n\nAssistant:",
            s.prompt,
        )

    def test_openai_tool_turns_are_kept_in_the_transcript(self):
        call = {"id": "c1", "type": "function", "function": {"name": "get_weather", "arguments": '{"city":"Rome"}'}}
        s = shape.shape_request(
            {
                "messages": [
                    {"role": "user", "content": "weather?"},
                    {"role": "assistant", "content": None, "tool_calls": [call]},
                    {"role": "tool", "tool_call_id": "c1", "content": "rain"},
                ]
            },
            "sonnet",
        )
        self.assertEqual(
            "User: weather?\n\n"
            'Assistant: [tool call get_weather (id c1): {"city":"Rome"}]\n\n'
            "User: [tool result (id c1): rain]\n\nAssistant:",
            s.prompt,
        )

    def test_engine_message_carries_the_prompt_then_the_images(self):
        src = {"type": "base64", "media_type": "image/png", "data": PNG}
        s = shape.Shaped("sonnet", "be brief", "look", [{"type": "image", "source": src}], [])
        msg = json.loads(shape.engine_message(s))
        self.assertEqual("user", msg["type"])
        self.assertEqual(
            [{"type": "text", "text": "be brief\n\nlook"}, {"type": "image", "source": src}],
            msg["message"]["content"],
        )


class Events(unittest.TestCase):
    """EventReader: the engine's events, read into the gateway's."""

    def delta(stop, usage=None):
        return {"type": "stream_event", "event": {"type": "message_delta", "delta": {"stop_reason": stop}, "usage": usage or {}}}

    def call(name="mcp__client__ping"):
        return {"type": "assistant", "message": {"content": [{"type": "tool_use", "id": "t", "name": name, "input": {}}]}}

    def test_only_a_tool_turn_with_client_calls_stops(self):
        r = events.EventReader()
        self.assertEqual(([], False), r.feed(Events.delta("tool_use")), "no client call yet")
        r.feed(Events.call("Bash"))
        self.assertEqual(([], False), r.feed(Events.delta("tool_use")), "the CLI's own tools do not count")
        self.assertEqual([("tool", {"id": "t", "name": "ping", "input": {}})], r.feed(Events.call())[0])
        self.assertEqual(([], False), r.feed(Events.delta("end_turn")), "a turn that ends otherwise goes on")
        self.assertEqual(([], False), r.feed({"type": "stream_event", "event": {"type": "message_stop"}}))
        self.assertEqual(([], True), r.feed(Events.delta("tool_use", {"output_tokens": 5})))
        self.assertEqual({"output_tokens": 5}, r.usage)

    def test_a_result_gives_the_usage_and_any_error(self):
        r = events.EventReader()
        r.feed({"type": "result", "result": "", "usage": {"output_tokens": 3}})
        self.assertEqual(({"output_tokens": 3}, None), (r.usage, r.error))
        r.feed({"type": "result", "is_error": True})
        self.assertEqual(({}, "claude reported an error"), (r.usage, r.error))
        r.feed({"type": "result", "is_error": True, "result": "overloaded", "usage": None})
        self.assertEqual(({}, "overloaded"), (r.usage, r.error))
        self.assertFalse(r.feed({"type": "result", "result": "x"})[1], "a result never stops the engine early")

    def test_text_is_sent_once(self):
        r = events.EventReader()
        text = {"type": "assistant", "message": {"content": [{"type": "text", "text": "Hello"}]}}
        self.assertEqual([("delta", "Hello")], r.feed(text)[0])
        self.assertEqual([], r.feed({"type": "result", "result": "Hello"})[0], "a result that adds nothing")
        self.assertEqual([], r.feed({"type": "result", "result": "Other"})[0], "nor one that is not a continuation")
        self.assertEqual([("delta", " world")], r.feed({"type": "result", "result": "Hello world"})[0])
        self.assertEqual([], r.feed({"type": "system"})[0])


class Tokens(unittest.TestCase):
    def test_estimate_counts_text_tools_and_images(self):
        img = {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": PNG}}
        tool = {"name": "t", "description": "", "inputSchema": {"type": "object"}}
        self.assertEqual(3, shape.estimate_tokens(shape.Shaped("m", "abcd", "efgh", [], [])), "4 characters a token, rounded up")
        self.assertEqual(1, shape.estimate_tokens(shape.Shaped("m", "", "a", [], [])))
        with_tool = shape.estimate_tokens(shape.Shaped("m", "", "", [], [tool]))
        self.assertEqual(-(-len(json.dumps([tool])) // 4), with_tool)
        self.assertEqual(1600, shape.estimate_tokens(shape.Shaped("m", "", "", [img], [])))


class Stub(unittest.TestCase):
    """gateway_stub.py: the MCP server the engine loads the client's tools
    from. It lists them and refuses every call."""

    def test_lists_the_tools_and_refuses_calls(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools = Path(tmp) / "tools.json"
            tools.write_text(json.dumps([{"name": "ping", "inputSchema": {"type": "object"}}]))
            reqs = [
                {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-03-26"}},
                {"jsonrpc": "2.0", "id": 5, "method": "initialize"},
                {"jsonrpc": "2.0", "method": "notifications/initialized"},
                {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
                {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "ping"}},
                {"jsonrpc": "2.0", "id": 4, "method": "ping"},
            ]
            out = subprocess.run(
                [sys.executable, str(SHARE / "gateway_stub.py"), str(tools)],
                input="\n".join(json.dumps(r) for r in reqs) + "\nnot json\n",
                capture_output=True, text=True, timeout=10, check=True,
            ).stdout
        lines = list(map(json.loads, out.splitlines()))
        self.assertEqual({"2.0"}, {r["jsonrpc"] for r in lines})
        res = {r["id"]: r["result"] for r in lines}
        self.assertEqual([1, 2, 3, 4, 5], sorted(res))
        self.assertEqual("2025-03-26", res[1]["protocolVersion"], "the client's version")
        self.assertEqual("2025-06-18", res[5]["protocolVersion"], "else this one")
        self.assertEqual("client", res[1]["serverInfo"]["name"], "the tools show as mcp__client__<name>")
        self.assertIn("runs on the client", res[3]["content"][0]["text"])
        self.assertEqual({"tools": {}}, res[1]["capabilities"])
        self.assertEqual([{"name": "ping", "inputSchema": {"type": "object"}}], res[2]["tools"])
        self.assertTrue(res[3]["isError"])
        self.assertEqual({}, res[4])


def sse_events(chunks):
    """(event, data) for each Anthropic SSE event in `chunks`."""
    out = []
    for block in b"".join(chunks).decode().split("\n\n"):
        if block:
            event, data = block.split("\n")
            out.append((event.removeprefix("event: "), json.loads(data.removeprefix("data: "))))
    return out


class Wire(unittest.TestCase):
    """The response builders, on canned engine events."""

    def setUp(self):
        sys.path.insert(0, str(SHARE))
        import gateway_wire

        self.wire = gateway_wire
        self.done = []

    def test_anthropic_text_stream(self):
        gen = iter([("delta", "Good "), ("delta", "day"), ("done", {"input_tokens": 4, "output_tokens": 2}, None)])
        evs = sse_events(self.wire.anthropic_sse("m", gen, lambda *a: self.done.append(a)))
        self.assertEqual(
            ["message_start", "content_block_start", "content_block_delta", "content_block_delta",
             "content_block_stop", "message_delta", "message_stop"],
            [e for e, _ in evs],
        )
        self.assertTrue(all(d["type"] == e for e, d in evs), "each data names its event")
        start = evs[0][1]["message"]
        self.assertEqual(("message", "assistant", "m", []), (start["type"], start["role"], start["model"], start["content"]))
        self.assertTrue(start["id"].startswith("msg_"))
        self.assertEqual({"type": "text_delta", "text": "day"}, evs[3][1]["delta"])
        self.assertEqual(0, evs[4][1]["index"])
        self.assertEqual({"stop_reason": "end_turn"}, evs[5][1]["delta"])
        self.assertEqual({"output_tokens": 2}, evs[5][1]["usage"])
        self.assertEqual([(4, 2, None)], self.done)

    def test_anthropic_error_stream(self):
        evs = sse_events(self.wire.anthropic_sse("m", iter([("done", {}, "boom")]), lambda *a: None))
        self.assertEqual(["message_start", "content_block_start", "content_block_stop", "message_delta", "error", "message_stop"],
                         [e for e, _ in evs])
        self.assertEqual({"type": "engine_error", "message": "boom"}, evs[4][1]["error"])
        self.assertEqual("error", evs[3][1]["delta"]["stop_reason"])

    def test_openai_text_stream(self):
        gen = iter([("delta", "Hi"), ("done", {"input_tokens": 1, "cache_read_input_tokens": 2, "output_tokens": 3}, None)])
        raw = b"".join(self.wire.openai_sse("m", gen, lambda *a: self.done.append(a))).decode()
        self.assertTrue(raw.endswith("data: [DONE]\n\n"))
        chunks = [json.loads(x.removeprefix("data: ")) for x in raw.split("\n\n") if x.startswith("data: {")]
        self.assertEqual([{"role": "assistant"}, {"content": "Hi"}, {}], [c["choices"][0]["delta"] for c in chunks])
        self.assertEqual([None, None, "stop"], [c["choices"][0]["finish_reason"] for c in chunks])
        self.assertEqual({"chat.completion.chunk"}, {c["object"] for c in chunks})
        self.assertEqual(1, len({c["id"] for c in chunks}), "one id for the whole stream")
        self.assertTrue(chunks[0]["id"].startswith("chatcmpl-"))
        self.assertEqual([(3, 3, None)], self.done, "cache reads count as input")

    def test_whole_responses(self):
        a = self.wire.anthropic_response("m", "hi", {"input_tokens": 1, "cache_creation_input_tokens": 1, "output_tokens": 2})
        self.assertEqual(([{"type": "text", "text": "hi"}], "end_turn", {"input_tokens": 2, "output_tokens": 2}),
                         (a["content"], a["stop_reason"], a["usage"]))
        o = self.wire.openai_response("m", "", {})
        self.assertEqual(({"role": "assistant", "content": ""}, "stop", 0),
                         (o["choices"][0]["message"], o["choices"][0]["finish_reason"], o["choices"][0]["index"]))
        call = {"id": "t", "name": "n", "input": {}}
        self.assertEqual([{"type": "tool_use", **call}], self.wire.anthropic_response("m", "", {}, [call])["content"])

if __name__ == "__main__":
    unittest.main(verbosity=1)
