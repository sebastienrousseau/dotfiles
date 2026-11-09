# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""The gateway's counters: requests, tokens, images, tool calls and cost, in
all and per model, against an optional daily budget. /v1/usage
(ai/gateway-usage.v1) and /metrics report them.

One Meter per gateway: dot-ai-serve makes it with its prices and budget, so
nothing here reads the environment or keeps module-level state.
"""

import threading
import time


class Meter:
    def __init__(self, pricing, daily_budget):
        self.pricing = pricing  # family substring -> (input, output) USD per million
        self.daily = daily_budget  # USD; 0 is no cap
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

    def record(self, model, inp, out, streamed, error):
        """Fold one request into the counters and the day's spend."""
        cost = self.estimate(model, inp, out)
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
        return cost

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
