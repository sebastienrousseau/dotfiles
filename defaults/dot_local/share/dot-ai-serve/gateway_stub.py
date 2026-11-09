# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""The MCP server through which dot-ai-serve shows a client's tools to the
engine: `python3 gateway_stub.py TOOLS.json`, over stdio.

It lists the tools in TOOLS.json and runs none of them. The engine is not
allowed to call them anyway (no --allowedTools); the gateway stops it at the
end of the model's turn and hands the calls back to the client, which runs
them and sends the results in its next request. A call that does reach this
server is refused.
"""

import json
import sys


def answer(req, tools):
    """The result for one JSON-RPC request."""
    method = req.get("method")
    if method == "initialize":
        version = (req.get("params") or {}).get("protocolVersion", "2025-06-18")
        return {
            "protocolVersion": version,
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "client", "version": "1"},
        }
    if method == "tools/list":
        return {"tools": tools}
    if method == "tools/call":
        text = "This tool runs on the client; the gateway returns the call to it."
        return {"content": [{"type": "text", "text": text}], "isError": True}
    return {}


def main():
    with open(sys.argv[1], encoding="utf-8") as fh:
        tools = json.load(fh)
    for line in sys.stdin:
        try:
            req = json.loads(line)
        except json.JSONDecodeError:
            continue
        if "id" in req:  # notifications get no answer
            res = {"jsonrpc": "2.0", "id": req["id"], "result": answer(req, tools)}
            print(json.dumps(res), flush=True)


if __name__ == "__main__":
    main()
