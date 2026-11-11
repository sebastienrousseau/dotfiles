# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""The headless `claude` CLI's stream-json events, read into the gateway's
own: ("delta", text) as text arrives and ("tool", call) for each call the
model makes to a client tool.

A turn that calls client tools ends at the API's message_delta with
stop_reason "tool_use" (a stream event, there when the engine runs with
--include-partial-messages). By then every call of the turn has arrived,
and that event carries the turn's usage, so the reader says to stop: the
gateway ends the engine there and returns the calls to the client.
"""

CLIENT_PREFIX = "mcp__client__"


class EventReader:
    def __init__(self):
        self.text = ""  # all text so far; the CLI may resend it whole
        self.usage = {}
        self.error = None
        self.calls = []
        self.model = ""  # the model's own id, from its messages

    def feed(self, evt):
        """(events for the client, whether the engine should stop now)."""
        etype = evt.get("type")
        if etype == "assistant":
            return self._assistant(evt.get("message") or {}), False
        if etype == "stream_event":
            return self._stream(evt.get("event") or {})
        if etype == "result":
            return self._result(evt), False
        return [], False

    def _delta(self, cur):
        delta = cur[len(self.text) :] if cur.startswith(self.text) else cur
        self.text = cur
        return [("delta", delta)] if delta else []

    def _assistant(self, message):
        self.model = message.get("model") or self.model
        out, cur = [], self.text
        for block in message.get("content") or []:
            if block.get("type") == "text":
                cur = block.get("text", cur)
            elif block.get("type") == "tool_use" and block.get("name", "").startswith(CLIENT_PREFIX):
                call = {
                    "id": block.get("id", ""),
                    "name": block["name"][len(CLIENT_PREFIX) :],
                    "input": block.get("input") or {},
                }
                self.calls.append(call)
                out.append(("tool", call))
        return self._delta(cur) + out

    def _stream(self, event):
        if event.get("type") != "message_delta" or not self.calls:
            return [], False
        if (event.get("delta") or {}).get("stop_reason") != "tool_use":
            return [], False
        self._finish(event.get("usage"), None)
        return [], True

    def _finish(self, usage, cost):
        """The turn's usage, with the model's id and, when the CLI reported
        one, its own cost for the run (cost_usd); only the gateway's meter
        reads those two."""
        self.usage = dict(usage or {})
        if self.model:
            self.usage["model"] = self.model
        if isinstance(cost, (int, float)) and not isinstance(cost, bool) and cost >= 0:
            self.usage["cost_usd"] = float(cost)

    def _result(self, evt):
        self._finish(evt.get("usage"), evt.get("total_cost_usd"))
        if evt.get("is_error"):
            self.error = evt.get("result") or "claude reported an error"
            return []
        final = evt.get("result", self.text)
        if isinstance(final, str) and final.startswith(self.text) and len(final) > len(self.text):
            return self._delta(final)
        return []
