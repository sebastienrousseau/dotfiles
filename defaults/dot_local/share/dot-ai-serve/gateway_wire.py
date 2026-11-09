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
# Response builders for each protocol. The engine's events are ("delta",
# text), ("tool", {"id", "name", "input"}) for each tool call the model
# made, then ("done", usage, error). A turn with tool calls ends with them.
# ---------------------------------------------------------------------------
def _stop(calls, err, ok):
    """The stop or finish reason: error, the tool-call reason, or ok."""
    if err:
        return "error"
    return {"anthropic": "tool_use", "openai": "tool_calls"}[ok[0]] if calls else ok[1]


def _openai_call(call, index=None):
    out = {
        "id": call["id"],
        "type": "function",
        "function": {"name": call["name"], "arguments": json.dumps(call["input"])},
    }
    return out if index is None else {"index": index, **out}


def anthropic_response(model, text, usage, calls=()):
    inp, out = _usage_pair(usage)
    content = [{"type": "text", "text": text}] if text or not calls else []
    content += [{"type": "tool_use", **c} for c in calls]
    return {
        "id": f"msg_{uuid.uuid4().hex[:24]}",
        "type": "message",
        "role": "assistant",
        "model": model,
        "content": content,
        "stop_reason": _stop(calls, None, ("anthropic", "end_turn")),
        "stop_sequence": None,
        "usage": {"input_tokens": inp, "output_tokens": out},
    }


def openai_response(model, text, usage, calls=()):
    inp, out = _usage_pair(usage)
    message = {"role": "assistant", "content": text if text or not calls else None}
    if calls:
        message["tool_calls"] = [_openai_call(c) for c in calls]
    return {
        "id": f"chatcmpl-{uuid.uuid4().hex[:24]}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": model,
        "choices": [
            {"index": 0, "message": message, "finish_reason": _stop(calls, None, ("openai", "stop"))}
        ],
        "usage": {"prompt_tokens": inp, "completion_tokens": out, "total_tokens": inp + out},
    }


def _event(event, data):
    return f"event: {event}\ndata: {json.dumps({'type': event, **data})}\n\n".encode()


def _anthropic_tool_block(index, call):
    """The three events that stream one tool_use block."""
    start = {"type": "tool_use", "id": call["id"], "name": call["name"], "input": {}}
    yield _event("content_block_start", {"index": index, "content_block": start})
    delta = {"type": "input_json_delta", "partial_json": json.dumps(call["input"])}
    yield _event("content_block_delta", {"index": index, "delta": delta})
    yield _event("content_block_stop", {"index": index})


def anthropic_sse(model, gen, on_done):
    """Protocol-correct Anthropic SSE that streams deltas from `gen` live;
    on_done(input_tokens, output_tokens, error) runs once it has ended."""
    message = {
        "id": f"msg_{uuid.uuid4().hex[:24]}",
        "type": "message",
        "role": "assistant",
        "model": model,
        "content": [],
        "stop_reason": None,
        "usage": {"input_tokens": 0, "output_tokens": 0},
    }
    yield _event("message_start", {"message": message})
    yield _event("content_block_start", {"index": 0, "content_block": {"type": "text", "text": ""}})
    usage, err, calls, text_open = {}, None, [], True
    for item in gen:
        if item[0] == "delta":
            yield _event("content_block_delta", {"index": 0, "delta": {"type": "text_delta", "text": item[1]}})
        elif item[0] == "tool":
            if text_open:
                yield _event("content_block_stop", {"index": 0})
                text_open = False
            calls.append(item[1])
            yield from _anthropic_tool_block(len(calls), item[1])
        else:
            _, usage, err = item
    if text_open:
        yield _event("content_block_stop", {"index": 0})
    inp, out = _usage_pair(usage)
    stop = _stop(calls, err, ("anthropic", "end_turn"))
    yield _event("message_delta", {"delta": {"stop_reason": stop}, "usage": {"output_tokens": out}})
    if err:
        yield _event("error", {"error": {"type": "engine_error", "message": err}})
    yield _event("message_stop", {})
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
    usage, err, calls = {}, None, 0
    for item in gen:
        if item[0] == "delta":
            yield chunk({"content": item[1]})
        elif item[0] == "tool":
            yield chunk({"tool_calls": [_openai_call(item[1], calls)]})
            calls += 1
        else:
            _, usage, err = item
    yield chunk({}, finish=_stop(calls, err, ("openai", "stop")))
    yield b"data: [DONE]\n\n"
    inp, out = _usage_pair(usage)
    on_done(inp, out, err)
