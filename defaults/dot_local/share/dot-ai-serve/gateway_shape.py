# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Request shaping for dot-ai-serve: an Anthropic or OpenAI request becomes
one prompt, its images and its tools, for one headless `claude` run.

The engine takes a single user message, so earlier turns are written out
as a transcript. Images (base64, or a URL the API fetches) go with that
message as content blocks, and each is marked [image N] where it was in
the conversation. The client's tools are handed to the engine as MCP tools
(see gateway_stub.py); its earlier tool calls and results are written into
the transcript. Anything the engine cannot take is a ValueError, which the
gateway answers with a 400.
"""

import json
import re
from typing import NamedTuple

IMAGE_TYPES = ("image/png", "image/jpeg", "image/gif", "image/webp")
TOOL_NAME = re.compile(r"[A-Za-z0-9_-]{1,64}")
DATA_URL = re.compile(r"data:([^;,]+);base64,(.+)", re.S)


class Shaped(NamedTuple):
    model: str
    system: str
    prompt: str
    images: list
    tools: list


def _base64_image(media_type, data):
    if media_type not in IMAGE_TYPES:
        raise ValueError(f"unsupported image type {media_type!r} (png, jpeg, gif or webp)")
    if not data:
        raise ValueError("an image has no data")
    return {"type": "image", "source": {"type": "base64", "media_type": media_type, "data": data}}


def _url_image(url):
    m = DATA_URL.fullmatch(url)
    if m:
        return _base64_image(m.group(1), m.group(2))
    if not url.startswith(("https://", "http://")):
        raise ValueError("an image URL must be http(s) or a base64 data URL")
    return {"type": "image", "source": {"type": "url", "url": url}}


def image_of(block):
    """The Anthropic image block for an Anthropic or OpenAI image block."""
    if block.get("type") == "image_url":
        ref = block.get("image_url")
        return _url_image(ref.get("url", "") if isinstance(ref, dict) else str(ref or ""))
    src = block.get("source") or {}
    if src.get("type") == "base64":
        return _base64_image(src.get("media_type"), src.get("data"))
    if src.get("type") == "url":
        return _url_image(src.get("url") or "")
    raise ValueError(f"unsupported image source {src.get('type')!r}")


def _result_text(block, images):
    """A tool_result block as one transcript line."""
    kind = "tool error" if block.get("is_error") else "tool result"
    body = text_of(block.get("content", ""), images)
    return f"[{kind} (id {block.get('tool_use_id', '')}): {body}]"


def _block_text(block, images):
    btype = block.get("type")
    if btype in ("image", "image_url"):
        images.append(image_of(block))
        return f"[image {len(images)}]"
    if btype == "tool_use":
        args = json.dumps(block.get("input", {}))
        return f"[tool call {block.get('name', '')} (id {block.get('id', '')}): {args}]"
    if btype == "tool_result":
        return _result_text(block, images)
    if btype in ("text", None) and "text" in block:
        return block["text"]
    return block.get("content") if isinstance(block.get("content"), str) else None


def text_of(content, images):
    """Plain text of a string or a list of content blocks; images found on
    the way are appended to `images` and marked in the text."""
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    parts = []
    for block in content:
        text = _block_text(block, images) if isinstance(block, dict) else block
        if isinstance(text, str):
            parts.append(text)
    return "\n".join(parts)


def _openai_calls(msg):
    """An OpenAI assistant message's tool_calls, as transcript lines."""
    lines = []
    for call in msg.get("tool_calls") or []:
        fn = call.get("function") or {}
        lines.append(f"[tool call {fn.get('name', '')} (id {call.get('id', '')}): {fn.get('arguments', '')}]")
    return lines


def _turn(msg, images):
    """(role label, text) for one message; the label is None for system."""
    role = msg.get("role", "user")
    if role == "tool":  # OpenAI: a tool's result, sent by the client
        block = {"tool_use_id": msg.get("tool_call_id", ""), "content": msg.get("content", "")}
        return "User", _result_text(block, images)
    text = "\n".join(t for t in [text_of(msg.get("content") or "", images), *_openai_calls(msg)] if t)
    label = {"system": None, "assistant": "Assistant"}.get(role, "User")
    return label, text


def _tool(spec):
    """An MCP tool for an Anthropic or OpenAI tool definition."""
    if not isinstance(spec, dict):
        raise ValueError("a tool must be an object")
    fn = spec.get("function") if spec.get("type") == "function" else spec
    if spec.get("type") not in (None, "custom", "function"):
        raise ValueError(f"tool type {spec.get('type')!r} is not supported; only client tools are")
    name = (fn or {}).get("name") or ""
    if not TOOL_NAME.fullmatch(name):
        raise ValueError(f"tool name {name!r} must be 1-64 letters, digits, _ or -")
    schema = fn.get("input_schema") or fn.get("parameters") or {"type": "object"}
    return {"name": name, "description": fn.get("description") or "", "inputSchema": schema}


def _choice(choice):
    """("none" | "auto" | "any" | "tool", tool name or None)."""
    if isinstance(choice, str):
        return {"required": "any"}.get(choice, choice), None
    choice = choice or {}
    if choice.get("type") == "function":
        return "tool", (choice.get("function") or {}).get("name")
    return choice.get("type", "auto"), choice.get("name")


def shape_tools(body):
    """(MCP tools, system note) for the request's tools and tool_choice."""
    tools = [_tool(t) for t in body.get("tools") or []]
    names = [t["name"] for t in tools]
    if len(set(names)) != len(names):
        raise ValueError("two tools have the same name")
    kind, name = _choice(body.get("tool_choice"))
    if kind == "none" or not tools:
        return [], ""
    if kind == "tool":
        if name not in names:
            raise ValueError(f"tool_choice names {name!r}, which is not in tools")
        return tools, f"You must call the tool {name} before you answer."
    if kind == "any":
        return tools, "You must call one of the tools before you answer."
    return tools, ""


def _prompt(turns):
    if len(turns) == 1 and turns[0][0] == "User":
        return turns[0][1]
    prompt = "\n\n".join(f"{label}: {text}" for label, text in turns)
    if turns and turns[-1][0] == "User":
        prompt += "\n\nAssistant:"
    return prompt


def shape_request(body, default_model):
    """The Shaped request for a parsed Anthropic or OpenAI body."""
    images, system, turns = [], [], []
    if body.get("system"):
        system.append(text_of(body["system"], images))
    for msg in body.get("messages") or []:
        label, text = _turn(msg, images)
        if not text:
            continue
        if label is None:
            system.append(text)
        else:
            turns.append((label, text))
    tools, note = shape_tools(body)
    system.append(note)
    system_prompt = "\n\n".join(c for c in system if c).strip()
    return Shaped(body.get("model") or default_model, system_prompt, _prompt(turns), images, tools)


# Tokens an image is estimated at: about what the API charges for one of
# about a megapixel, the most it keeps without scaling down.
IMAGE_TOKENS = 1600


def _engine_text(shaped):
    return f"{shaped.system}\n\n{shaped.prompt}" if shaped.system else shaped.prompt


def estimate_tokens(shaped):
    """A rough count of the request's input tokens, for the policy's cap:
    four characters a token for the text and the tool schemas, rounded up,
    and IMAGE_TOKENS an image."""
    chars = len(_engine_text(shaped)) + (len(json.dumps(shaped.tools)) if shaped.tools else 0)
    return -(-chars // 4) + IMAGE_TOKENS * len(shaped.images)


def engine_message(shaped):
    """The one stream-json user message the engine reads: the system prompt
    and the prompt as text, then the images."""
    content = [{"type": "text", "text": _engine_text(shaped)}, *shaped.images]
    return json.dumps({"type": "user", "message": {"role": "user", "content": content}})
