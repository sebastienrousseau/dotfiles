# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""The wire formats dot-ai-serve answers in: Anthropic Messages and OpenAI
chat completions, whole or as server-sent events. Pure: the gateway passes
in what the engine produced and a callback for its metering."""

import json
import time
import uuid


def _usage_pair(usage):
    """Normalize CLI usage into (input_tokens, output_tokens)."""
    inp = usage.get("input_tokens", 0) + usage.get("cache_read_input_tokens", 0)
    inp += usage.get("cache_creation_input_tokens", 0)
    return inp, usage.get("output_tokens", 0)


# ---------------------------------------------------------------------------
# Response builders for each protocol.
# ---------------------------------------------------------------------------
def anthropic_response(model, text, usage):
    inp, out = _usage_pair(usage)
    return {
        "id": f"msg_{uuid.uuid4().hex[:24]}",
        "type": "message",
        "role": "assistant",
        "model": model,
        "content": [{"type": "text", "text": text}],
        "stop_reason": "end_turn",
        "stop_sequence": None,
        "usage": {"input_tokens": inp, "output_tokens": out},
    }


def openai_response(model, text, usage):
    inp, out = _usage_pair(usage)
    return {
        "id": f"chatcmpl-{uuid.uuid4().hex[:24]}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": model,
        "choices": [
            {
                "index": 0,
                "message": {"role": "assistant", "content": text},
                "finish_reason": "stop",
            }
        ],
        "usage": {
            "prompt_tokens": inp,
            "completion_tokens": out,
            "total_tokens": inp + out,
        },
    }


def anthropic_sse(model, gen, on_done):
    """Protocol-correct Anthropic SSE that streams deltas from `gen` live;
    on_done(input_tokens, output_tokens, error) runs once it has ended."""
    mid = f"msg_{uuid.uuid4().hex[:24]}"

    def ev(event, data):
        return f"event: {event}\ndata: {json.dumps(data)}\n\n".encode()

    yield ev(
        "message_start",
        {
            "type": "message_start",
            "message": {
                "id": mid,
                "type": "message",
                "role": "assistant",
                "model": model,
                "content": [],
                "stop_reason": None,
                "usage": {"input_tokens": 0, "output_tokens": 0},
            },
        },
    )
    yield ev(
        "content_block_start",
        {"type": "content_block_start", "index": 0, "content_block": {"type": "text", "text": ""}},
    )
    usage, err = {}, None
    for item in gen:
        if item[0] == "delta":
            yield ev(
                "content_block_delta",
                {
                    "type": "content_block_delta",
                    "index": 0,
                    "delta": {"type": "text_delta", "text": item[1]},
                },
            )
        else:
            _, usage, err = item
    yield ev("content_block_stop", {"type": "content_block_stop", "index": 0})
    inp, out = _usage_pair(usage)
    yield ev(
        "message_delta",
        {
            "type": "message_delta",
            "delta": {"stop_reason": "error" if err else "end_turn"},
            "usage": {"output_tokens": out},
        },
    )
    if err:
        yield ev("error", {"type": "error", "error": {"type": "engine_error", "message": err}})
    yield ev("message_stop", {"type": "message_stop"})
    on_done(inp, out, err)


def openai_sse(model, gen, on_done):
    """OpenAI chat.completion.chunk SSE from `gen`; on_done as for
    anthropic_sse."""
    cid = f"chatcmpl-{uuid.uuid4().hex[:24]}"
    created = int(time.time())

    def chunk(delta, finish=None):
        data = {
            "id": cid,
            "object": "chat.completion.chunk",
            "created": created,
            "model": model,
            "choices": [{"index": 0, "delta": delta, "finish_reason": finish}],
        }
        return f"data: {json.dumps(data)}\n\n".encode()

    yield chunk({"role": "assistant"})
    usage, err = {}, None
    for item in gen:
        if item[0] == "delta":
            yield chunk({"content": item[1]})
        else:
            _, usage, err = item
    yield chunk({}, finish="stop" if not err else "error")
    yield b"data: [DONE]\n\n"
    inp, out = _usage_pair(usage)
    on_done(inp, out, err)
