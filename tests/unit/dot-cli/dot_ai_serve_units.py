# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Unit tests for defaults/dot_local/bin/executable_dot-ai-serve.

Driven by tests/unit/dot-cli/test_dot_ai_serve_units.sh. The gateway is a
script, not a module, so it is loaded from its path; each test that needs
different environment-derived globals loads a fresh copy. Nothing binds a
non-loopback address or talks to a real `claude`: a mock engine is written
into a temporary directory per test.
"""

from __future__ import annotations

import http.client
import importlib.util
import os
import sys
import tempfile
import threading
import time
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[3]
GATEWAY = REPO / "defaults" / "dot_local" / "bin" / "executable_dot-ai-serve"


def load(env: dict[str, str] | None = None):
    """A fresh copy of the gateway module with `env` applied at import."""
    name = f"dot_ai_serve_{time.monotonic_ns()}"
    loader = SourceFileLoader(name, str(GATEWAY))
    spec = importlib.util.spec_from_loader(name, loader)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    with mock.patch.dict(os.environ, env or {}, clear=False):
        loader.exec_module(mod)
    return mod


def mock_engine(tmp: Path, body: str) -> str:
    path = tmp / "claude"
    path.write_text("#!/bin/sh\n" + body + "\n", encoding="utf-8")
    path.chmod(0o755)
    return str(path)


class Token(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.srv = load()

    def test_creates_private_token_once(self):
        path = self.tmp / "state" / "gateway.token"
        tok = self.srv.load_or_create_token(str(path))
        self.assertEqual(43, len(tok))
        self.assertEqual(0o600, path.stat().st_mode & 0o777)
        self.assertEqual(tok, self.srv.load_or_create_token(str(path)))

    def test_empty_file_is_replaced_not_looped(self):
        path = self.tmp / "gateway.token"
        path.write_text("", encoding="utf-8")
        tok = self.srv.load_or_create_token(str(path))
        self.assertEqual(43, len(tok))
        self.assertEqual(tok, path.read_text(encoding="utf-8").strip())

    def test_lost_race_uses_the_winners_token(self):
        path = self.tmp / "gateway.token"
        real_open = os.open

        def racing_open(p, flags, *a):
            if str(p) == str(path) and flags & os.O_EXCL:
                path.write_text("winner-token\n", encoding="utf-8")
                raise FileExistsError(p)
            return real_open(p, flags, *a)

        with mock.patch.object(self.srv.os, "open", side_effect=racing_open):
            self.assertEqual("winner-token", self.srv.load_or_create_token(str(path)))


class Config(unittest.TestCase):
    def test_bad_pricing_and_model_map_json_are_ignored(self):
        srv = load({"DOT_AI_PRICING": "{not json", "DOT_AI_MODEL_MAP": "[broken"})
        self.assertIn("sonnet", srv.PRICING)
        self.assertEqual("haiku", srv.MODEL_ALIASES["cheap"])

    def test_pricing_override_and_family_fallback(self):
        srv = load({"DOT_AI_PRICING": '{"opus": [1, 2]}'})
        self.assertEqual((1.0, 2.0), tuple(float(x) for x in srv._price_for("opus")))
        with mock.patch.object(srv, "resolve_model", return_value="mystery-model"):
            self.assertEqual(srv.PRICING["sonnet"], srv._price_for("x"))

    def test_budget_rolls_over_a_new_day(self):
        srv = load({"DOT_AI_DAILY_BUDGET": "1"})
        srv._BUDGET.update(day="1999-01-01", spent=5.0)
        srv._roll_day()
        self.assertEqual(0.0, srv._BUDGET["spent"])

    def test_allowed_hosts(self):
        srv = load({"DOT_AI_PORT": "4000", "DOT_AI_ALLOWED_HOSTS": "Proxy.Local:443, "})
        self.assertEqual(
            {"127.0.0.1:4000", "localhost:4000", "[::1]:4000", "proxy.local:443"},
            srv.allowed_hosts(),
        )
        srv = load({"DOT_AI_PORT": "4000", "DOT_AI_HOST": "10.0.0.5"})
        self.assertIn("10.0.0.5:4000", srv.allowed_hosts())
        srv = load({"DOT_AI_PORT": "4000", "DOT_AI_HOST": "fd00::1"})
        self.assertIn("[fd00::1]:4000", srv.allowed_hosts())
        srv = load({"DOT_AI_PORT": "4000", "DOT_AI_HOST": "0.0.0.0"})
        self.assertNotIn("0.0.0.0:4000", srv.allowed_hosts())


class Shaping(unittest.TestCase):
    def setUp(self):
        self.srv = load()

    def test_text_of_block_kinds(self):
        text = self.srv._text_of(
            [
                {"type": "text", "text": "a"},
                {"type": "image", "source": {}},
                {"type": "tool_result", "content": "b"},
                "c",
                {"type": "other"},
            ]
        )
        self.assertEqual("a\n[image attached — not forwarded; the engine is text-only]\nb\nc", text)
        self.assertEqual("", self.srv._text_of(42))

    def test_shape_request_turns_and_system(self):
        model, system, prompt = self.srv.shape_request(
            {
                "model": "opus",
                "system": "be brief",
                "messages": [
                    {"role": "system", "content": "sys2"},
                    {"role": "user", "content": "q1"},
                    {"role": "assistant", "content": "a1"},
                    {"role": "user", "content": ""},
                    {"role": "user", "content": "q2"},
                ],
            }
        )
        self.assertEqual("opus", model)
        self.assertEqual("be brief\n\nsys2", system)
        self.assertEqual("User: q1\n\nAssistant: a1\n\nUser: q2\n\nAssistant:", prompt)


class Engine(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def run_engine(self, body: str, env: dict[str, str] | None = None):
        env = {"DOT_AI_CLAUDE_BIN": mock_engine(self.tmp, body), **(env or {})}
        srv = load(env)
        with mock.patch.dict(os.environ, env):  # DOT_AI_TIMEOUT is read per call
            return srv, list(srv.stream_claude("sonnet", "sys", "hi"))

    def test_missing_engine(self):
        srv = load({"DOT_AI_CLAUDE_BIN": str(self.tmp / "absent")})
        self.assertEqual([("done", {}, f"claude CLI not found ({self.tmp / 'absent'})")],
                         list(srv.stream_claude("sonnet", "", "hi")))

    def test_noise_lines_are_skipped_and_stderr_reported(self):
        _, events = self.run_engine("cat >/dev/null; echo; echo 'not json'; echo 'boom detail' >&2")
        self.assertEqual(("done", {}, "boom detail"), events[-1])

    def test_silent_engine(self):
        _, events = self.run_engine("cat >/dev/null")
        self.assertEqual(("done", {}, "no output from claude"), events[-1])

    def test_timeout(self):
        _, events = self.run_engine("cat >/dev/null; exec sleep 5", {"DOT_AI_TIMEOUT": "1"})
        self.assertEqual("claude CLI timed out", events[-1][2])

    def test_engine_error_in_anthropic_stream(self):
        srv, _ = self.run_engine(
            "cat >/dev/null; echo '{\"type\":\"result\",\"is_error\":true,\"result\":\"nope\",\"usage\":{}}'"
        )
        chunks = b"".join(srv.anthropic_sse("sonnet", "sonnet", srv.stream_claude("sonnet", "", "hi")))
        self.assertIn(b"engine_error", chunks)
        self.assertIn(b"message_stop", chunks)


class Http(unittest.TestCase):
    """The request handler, served in-process on an ephemeral port."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        engine = mock_engine(
            self.tmp,
            "cat >/dev/null; echo '{\"type\":\"result\",\"is_error\":false,\"result\":\"ok\",\"usage\":{}}'",
        )
        self.srv = load({"DOT_AI_CLAUDE_BIN": engine})
        self.srv.API_KEY = "k"
        self.httpd = self.srv.ThreadingHTTPServer(("127.0.0.1", 0), self.srv.Handler)
        self.srv.PORT = self.httpd.server_address[1]
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()

    def req(self, method, path, body=None, key="k", host=None):
        conn = http.client.HTTPConnection("127.0.0.1", self.srv.PORT, timeout=10)
        headers = {"Host": host or f"127.0.0.1:{self.srv.PORT}"}
        if key:
            headers["x-api-key"] = key
        if body is not None:
            headers["Content-Type"] = "application/json"
        conn.request(method, path, body=body, headers=headers)
        resp = conn.getresponse()
        return resp.status, resp.read()

    def test_get_routes(self):
        self.assertEqual(200, self.req("GET", "/")[0])
        self.assertEqual(404, self.req("GET", "/nope")[0])
        self.assertEqual(401, self.req("GET", "/v1/usage", key=None)[0])
        self.assertEqual(200, self.req("GET", "/v1/usage")[0])
        self.assertEqual(200, self.req("GET", "/metrics")[0])

    def test_post_errors(self):
        self.assertEqual(400, self.req("POST", "/v1/messages", body="{bad")[0])
        self.assertEqual(404, self.req("POST", "/v1/other", body="{}")[0])
        self.assertEqual(400, self.req("POST", "/v1/messages", body='{"messages":[]}')[0])

    def test_no_key_configured_fails_closed(self):
        self.srv.API_KEY = ""
        self.assertEqual(401, self.req("POST", "/v1/messages", body="{}", key="")[0])


class Main(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def test_token_path_with_explicit_key(self):
        srv = load({"DOT_AI_API_KEY": "explicit", "XDG_STATE_HOME": str(self.tmp)})
        with mock.patch.object(sys, "argv", ["dot-ai-serve", "--token-path"]), \
                mock.patch("builtins.print") as printed:
            srv.main()
        printed.assert_called_once_with(srv.TOKEN_FILE)
        self.assertFalse(Path(srv.TOKEN_FILE).exists(), "no token is created when a key is given")

    def test_unknown_arguments(self):
        srv = load()
        with mock.patch.object(sys, "argv", ["dot-ai-serve", "--bogus"]):
            with self.assertRaises(SystemExit) as exit_:
                srv.main()
        self.assertEqual(64, exit_.exception.code)

    def test_refuses_non_loopback_without_key(self):
        srv = load({"DOT_AI_HOST": "0.0.0.0", "DOT_AI_API_KEY": "", "DOT_AI_CLAUDE_BIN": "absent-claude"})
        with mock.patch.object(sys, "argv", ["dot-ai-serve"]):
            with self.assertRaises(SystemExit) as exit_:
                srv.main()
        self.assertEqual(2, exit_.exception.code)

    def test_serves_until_interrupted(self):
        srv = load({"XDG_STATE_HOME": str(self.tmp), "DOT_AI_API_KEY": "", "DOT_AI_DAILY_BUDGET": "3"})
        fake = mock.MagicMock()
        fake.return_value.serve_forever.side_effect = KeyboardInterrupt
        with mock.patch.object(sys, "argv", ["dot-ai-serve"]), mock.patch.object(srv, "ThreadingHTTPServer", fake):
            srv.main()
        fake.return_value.server_close.assert_called_once()
        self.assertTrue((self.tmp / "dotfiles" / "ai-serve" / "gateway.token").is_file())


if __name__ == "__main__":
    unittest.main(verbosity=1)
