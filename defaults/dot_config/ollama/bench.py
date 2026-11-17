# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Benchmark qwen3.5-code via the Ollama API, thinking off."""

import json
import sys
import urllib.request

MODEL = sys.argv[1] if len(sys.argv) > 1 else "qwen3.5-code"
PROMPTS = [
    ("warmup", "Say ok."),
    ("rust", "Rust: fn that reverses the word order of a &str. Code only."),
    ("python", "Python: function that groups a list of dicts by a key. Code only."),
    ("go", "Go: function that reads a file line by line and counts words. Code only."),
    ("java", "Java: record Point with a static distance method. Code only."),
]


def run(prompt):
    body = json.dumps(
        {"model": MODEL, "prompt": prompt, "think": False, "stream": False}
    )
    req = urllib.request.Request(
        "http://127.0.0.1:11434/api/generate",
        body.encode(),
        {"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=600) as resp:
        return json.load(resp)


def rate(count, ns):
    return count / (ns / 1e9) if ns else 0.0


for name, prompt in PROMPTS:
    r = run(prompt)
    gen = rate(r["eval_count"], r["eval_duration"])
    pre = rate(r.get("prompt_eval_count", 0), r.get("prompt_eval_duration", 0))
    print(
        f"{name:<7} {gen:5.1f} tok/s gen  {pre:7.1f} tok/s prompt  "
        f"{r['total_duration'] / 1e9:6.1f}s total  {r['eval_count']} tokens",
        flush=True,
    )
    if name == "rust":
        print(r["response"], flush=True)
