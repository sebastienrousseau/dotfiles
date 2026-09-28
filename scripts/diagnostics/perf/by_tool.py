#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Per-tool startup timing report for `dot perf --by-tool`.

Aggregates eval-timings.jsonl (written by _cached_eval when
EVALCACHE_TIMING=1) and prints which tools dominate shell startup.
Usage: by_tool.py <eval-timings.jsonl>
"""
import json, sys
from collections import defaultdict

def percentile(sorted_vals, p):
    """Linear-interpolation percentile, matching numpy.percentile defaults."""
    if not sorted_vals:
        return 0
    if len(sorted_vals) == 1:
        return sorted_vals[0]
    k = (len(sorted_vals) - 1) * (p / 100.0)
    f = int(k)
    c = min(f + 1, len(sorted_vals) - 1)
    if f == c:
        return sorted_vals[f]
    return sorted_vals[f] + (sorted_vals[c] - sorted_vals[f]) * (k - f)

samples = defaultdict(list)        # label -> [ms, ms, ...]
shells_by_label = defaultdict(set) # label -> {shell, ...}

with open(sys.argv[1]) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except Exception:
            continue
        label = ev.get("label", "?")
        try:
            ms = int(ev.get("ms", 0) or 0)
        except (TypeError, ValueError):
            continue
        samples[label].append(ms)
        shells_by_label[label].add(ev.get("shell", "?"))

rows = []
for label, vals in samples.items():
    vals_sorted = sorted(vals)
    rows.append({
        "label":  label,
        "count":  len(vals_sorted),
        "total":  sum(vals_sorted),
        "mean":   sum(vals_sorted) // max(len(vals_sorted), 1),
        "min":    vals_sorted[0],
        "max":    vals_sorted[-1],
        "p50":    int(percentile(vals_sorted, 50)),
        "p95":    int(percentile(vals_sorted, 95)),
        "p99":    int(percentile(vals_sorted, 99)),
        "shells": ",".join(sorted(shells_by_label[label])),
    })

rows.sort(key=lambda r: r["total"], reverse=True)
header = (f"  {'label':<20} {'calls':>5} {'total':>8} "
          f"{'mean':>7} {'p50':>5} {'p95':>5} {'p99':>5}  shells")
print(header)
print("  " + "-" * (len(header) - 2))
for r in rows:
    print(f"  {r['label']:<20} {r['count']:>5} {r['total']:>6}ms "
          f"{r['mean']:>5}ms {r['p50']:>3}ms {r['p95']:>3}ms {r['p99']:>3}ms  {r['shells']}")
