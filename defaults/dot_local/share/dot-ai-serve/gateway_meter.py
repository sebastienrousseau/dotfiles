# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""The gateway's counters: requests, tokens, images, tool calls and cost, in
all and per model, against an optional daily budget. /v1/usage
(ai/gateway-usage.v1) and /metrics report them.

Each request is also a line of a usage log, which dot ai cost show reads:
its time, the model's id, its tokens and the CLI's own cost for it (null
when the CLI gave none: the reader prices it). Never a prompt or an answer.
The log is set aside under a dated name once it reaches log_max bytes.

One Meter per gateway: dot-ai-serve makes it with its prices, budget and log
path, so nothing here reads the environment or keeps module-level state.
"""

import json
import os
import threading
import time


class Meter:
    def __init__(self, pricing, daily_budget, log_path=None):
        self.pricing = pricing  # family substring -> (input, output) USD per million
        self.daily = daily_budget  # USD; 0 is no cap
        self.log_path, self.log_max = log_path, 20 << 20
        self.lock = threading.Lock()
        self.metrics = {
            "started": time.time(),
            "requests": 0,
            "errors": 0,
            "streamed": 0,
            "images": 0,
            "tool_calls": 0,
            "input_tokens": 0,
            "output_tokens": 0,
            "cost_usd": 0.0,
            "by_model": {},
        }
        self.budget = {"day": time.strftime("%Y-%m-%d"), "spent": 0.0}

    def price_for(self, model):
        m = model.lower()
        for fam, price in self.pricing.items():
            if fam in m:
                return price
        return self.pricing.get("sonnet", (3.0, 15.0))

    def estimate(self, model, inp, out):
        pin, pout = self.price_for(model)
        return (inp * pin + out * pout) / 1_000_000.0

    def roll_day(self):
        today = time.strftime("%Y-%m-%d")
        if self.budget["day"] != today:
            self.budget["day"], self.budget["spent"] = today, 0.0

    def budget_exceeded(self):
        if self.daily <= 0:
            return False
        with self.lock:
            self.roll_day()
            return self.budget["spent"] >= self.daily

    def count(self, name, n):
        with self.lock:
            self.metrics[name] += n

    def record(self, model, inp, out, streamed, error, usage=None):
        """Fold one request into the counters and the day's spend. Its cost
        is the CLI's own figure (usage["cost_usd"]) when it gave one, else
        the price table's."""
        usage = usage or {}
        reported = usage.get("cost_usd")
        cost = reported if isinstance(reported, float) else self.estimate(model, inp, out)
        m = self.metrics
        with self.lock:
            m["requests"] += 1
            m["errors"] += 1 if error else 0
            m["streamed"] += 1 if streamed else 0
            m["input_tokens"] += inp
            m["output_tokens"] += out
            m["cost_usd"] += cost
            bm = m["by_model"].setdefault(model, {"requests": 0, "input": 0, "output": 0, "cost": 0.0})
            bm["requests"] += 1
            bm["input"] += inp
            bm["output"] += out
            bm["cost"] += cost
            self.roll_day()
            self.budget["spent"] += cost
            self._log(usage.get("model") or model, usage, reported if isinstance(reported, float) else None)
        return cost

    def _log(self, model, usage, cost):
        """Append the request to the usage log (0600); a log that cannot be
        written only goes unrecorded."""
        if not self.log_path:
            return
        cache = usage.get("cache_creation") or {}
        w1h = cache.get("ephemeral_1h_input_tokens", 0) if isinstance(cache, dict) else 0
        tokens = {
            "input": usage.get("input_tokens", 0),
            "cache_write_5m": usage.get("cache_creation_input_tokens", 0) - w1h,
            "cache_write_1h": w1h,
            "cache_read": usage.get("cache_read_input_tokens", 0),
            "output": usage.get("output_tokens", 0),
        }
        line = {"time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "model": model,
                "tokens": tokens, "cost_usd": cost}
        try:
            self._rotate()
            fd = os.open(self.log_path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
            with os.fdopen(fd, "a", encoding="utf-8") as fh:
                fh.write(json.dumps(line, separators=(",", ":")) + "\n")
        except OSError:
            pass

    def _rotate(self):
        try:
            if os.path.getsize(self.log_path) < self.log_max:
                return
        except OSError:
            os.makedirs(os.path.dirname(self.log_path), mode=0o700, exist_ok=True)
            return
        stamp = time.strftime("%Y%m%dT%H%M%S", time.gmtime())
        os.replace(self.log_path, self.log_path[: -len(".jsonl")] + f"-{stamp}-{time.time_ns()}.jsonl")

    def report(self):
        """The counters as ai/gateway-usage.v1."""
        m = self.metrics
        with self.lock:
            self.roll_day()
            return {
                "schema": "ai/gateway-usage.v1",
                "object": "usage",
                "uptime_seconds": int(time.time() - m["started"]),
                **{k: m[k] for k in ("requests", "errors", "streamed", "images", "tool_calls")},
                "input_tokens": m["input_tokens"],
                "output_tokens": m["output_tokens"],
                "cost_usd": round(m["cost_usd"], 6),
                "budget": {"daily_usd": self.daily, "spent_today_usd": round(self.budget["spent"], 6)},
                "by_model": {k: {**v, "cost": round(v["cost"], 6)} for k, v in m["by_model"].items()},
            }

    def prometheus(self):
        """The counters in the Prometheus text format."""
        m = self.metrics
        with self.lock:
            self.roll_day()
            out = [f"dot_ai_uptime_seconds {int(time.time() - m['started'])}"]
            for k in ("requests", "errors", "streamed", "images", "tool_calls", "input_tokens", "output_tokens"):
                out.append(f"dot_ai_{k}_total {m[k]}")
            out += [
                f"dot_ai_cost_usd_total {m['cost_usd']:.6f}",
                f"dot_ai_budget_today_usd {self.budget['spent']:.6f}",
                f"dot_ai_budget_limit_usd {self.daily:.6f}",
            ]
            for model, bm in m["by_model"].items():
                safe = model.replace('"', "").replace("\\", "")
                out.append(f'dot_ai_model_requests_total{{model="{safe}"}} {bm["requests"]}')
                out.append(f'dot_ai_model_cost_usd_total{{model="{safe}"}} {bm["cost"]:.6f}')
        return "\n".join(out) + "\n"
