#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Randomised property test for tools/docs/build-manual-site.py.
#
# slug() turns heading text into ids on both sides of the build (the
# contents list from Markdown, the ids stamped on rendered HTML), and
# unique() de-duplicates them. The contract only holds if both are total
# and well-formed for any input, so this drives them with a fixed-seed
# generator over ASCII, punctuation, HTML entities/tags and accented and
# non-Latin text. Standard library only; the seed keeps it reproducible.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

GEN="$REPO_ROOT/tools/docs/build-manual-site.py"

run_props() {
  python3 - "$GEN" 2>&1 <<'PY'
import importlib.util, random, re, sys
spec = importlib.util.spec_from_file_location("gen", sys.argv[1])
gen = importlib.util.module_from_spec(spec)
sys.modules["gen"] = gen  # dataclasses resolve annotations through sys.modules
spec.loader.exec_module(gen)

rng = random.Random(20260923)
alphabet = (
    "abcXYZ0189 -_.,:;!?/'\"`*()[]{}<>&#%$@+=~|\\\t"
    "éèàüçñøåßœ" "Ωλπ" "中文" "’— "
)
fragments = ["&amp;", "&#39;", "&quot;", "<code>", "</code>", "<em>x</em>", "`dot`", "**b**"]
failures = []
for i in range(20000):
    parts = [rng.choice(alphabet) for _ in range(rng.randint(0, 40))]
    if rng.random() < 0.3:
        parts.insert(rng.randint(0, len(parts)), rng.choice(fragments))
    text = "".join(parts)
    s = gen.slug(text)
    if not re.fullmatch(r"(?:[a-z0-9]+(?:-[a-z0-9]+)*)?", s):
        failures.append(f"malformed slug {s!r} from {text!r}")
    if gen.slug(s) != s:
        failures.append(f"slug not idempotent: {s!r} -> {gen.slug(s)!r}")
    if failures:
        break

seen = set()
for i in range(5000):
    base = rng.choice(["intro", "usage", "a", "x-2", "flags"])
    got = gen.unique(base, seen)
    if not (got == base or re.fullmatch(re.escape(base) + r"-\d+", got)):
        failures.append(f"unique({base!r}) returned {got!r}")
        break
if len(seen) != 5000:
    failures.append(f"unique() repeated an id: {5000 - len(seen)} duplicates")

print("\n".join(failures[:5]) if failures else "ok")
PY
}

test_start "manual_site_slug_and_unique_properties"
assert_equals "ok" "$(run_props)" "slug() is total, well-formed and idempotent; unique() never repeats"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
