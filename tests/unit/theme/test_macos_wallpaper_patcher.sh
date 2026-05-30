#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Regression: macOS wallpaper Index.plist patcher.
#
# On macOS Sonoma+, the wallpaper store moved to
#   ~/Library/Application Support/com.apple.wallpaper/Store/Index.plist
# with separate entries per Space and per Display. The old code only
# spoke to the obsolete ~/Library/Preferences/com.apple.desktop.plist
# and to AppleScript's "every desktop" (which is current-Space-scoped),
# so `dot theme` left non-active Spaces untouched.
#
# The Python patcher embedded in scripts/theme/wallpaper-sync.sh is now
# what rewrites every Space/Display node in Index.plist. This test
# extracts that patcher into a tmpfile, runs it against a synthesized
# Index.plist that mirrors the real shapes (Desktop-mode, Linked-mode,
# per-Display sub-entries, plus an Idle node we must NOT touch), and
# verifies the rewrite.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WALLPAPER_SYNC="$REPO_ROOT/scripts/theme/wallpaper-sync.sh"

if ! command -v python3 >/dev/null 2>&1; then
  printf '%b\n' "  ${YELLOW}~${NC} python3 not available — skipping patcher test"
  echo "RESULTS:0:0:0"
  exit 0
fi

# --- Extract the patcher heredoc into a standalone script -------------------
# The patcher lives between `python3 - "$wp" <<'PYEOF'` and `PYEOF` in the
# Darwin branch of apply_wallpaper. awk between the markers gives us the
# body verbatim, which we then write to a temp file and exec.

tmpdir="$(mktemp -d -t patcher-test.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

patcher="$tmpdir/patcher.py"
awk "/python3 - \"\\\$wp\" <<.PYEOF./ {flag=1; next} /^PYEOF\$/ {flag=0} flag" \
  "$WALLPAPER_SYNC" >"$patcher"

test_start "patcher_extracted_from_wallpaper_sync"
if [[ -s "$patcher" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: extracted $(wc -l <"$patcher" | tr -d ' ') lines"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: extraction failed — patcher heredoc moved?"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 1
fi

# --- Synthesize an Index.plist that exercises every shape ------------------
# Shapes covered:
#   * AllSpacesAndDisplays.Desktop       (legacy global default)
#   * Displays[UUID].Desktop             (per-display)
#   * Spaces[UUID].Default.Desktop       (per-Space, classic mode)
#   * Spaces[UUID].Default.Linked        (per-Space, screensaver+wallpaper shared)
#   * Spaces[UUID].Displays[UUID].Desktop (per-Space, per-Display)
#   * Spaces[UUID].Default.Idle          (screensaver — MUST NOT be touched)

fixture="$tmpdir/Index.plist"
python3 - "$fixture" <<'PYEOF'
import plistlib, sys
out = sys.argv[1]

def cfg(uri):
    return plistlib.dumps(
        {"type": "imageFile", "url": {"relative": uri}},
        fmt=plistlib.FMT_BINARY,
    )

def node(uri):
    return {
        "Content": {
            "Choices": [{
                "Configuration": cfg(uri),
                "Provider": "com.apple.wallpaper.choice.image",
                "Files": [],
            }],
            "Shuffle": "$null",
        },
    }

ORIG = "file:///tmp/original.png"
IDLE = "file:///tmp/screensaver.png"

data = {
    "AllSpacesAndDisplays": {
        "Desktop": node(ORIG),
        "Type": "individual",
    },
    "Displays": {
        "DISPLAY-A": {"Desktop": node(ORIG), "Type": "individual"},
    },
    "Spaces": {
        "SPACE-DESKTOP": {
            "Default": {"Desktop": node(ORIG), "Type": "individual"},
            "Displays": {"DISPLAY-A": {"Desktop": node(ORIG)}},
        },
        "SPACE-LINKED": {
            "Default": {"Linked": node(ORIG), "Type": "linked"},
            "Displays": {"DISPLAY-A": {"Linked": node(ORIG)}},
        },
        "SPACE-WITH-IDLE": {
            "Default": {
                "Desktop": node(ORIG),
                "Idle": node(IDLE),
                "Type": "individual",
            },
        },
    },
}

with open(out, "wb") as f:
    plistlib.dump(data, f, fmt=plistlib.FMT_BINARY)
PYEOF

# --- Run the extracted patcher against the fixture -------------------------
# The patcher expects ~/Library/Application Support/com.apple.wallpaper/Store/
# Index.plist, so we point HOME at our tmpdir and stage the fixture there.

fake_home="$tmpdir/home"
store_dir="$fake_home/Library/Application Support/com.apple.wallpaper/Store"
mkdir -p "$store_dir"
cp "$fixture" "$store_dir/Index.plist"

NEW_WP="/Users/test/Pictures/Wallpapers/new-theme.heic"
NEW_URI="file://$NEW_WP"

HOME="$fake_home" python3 "$patcher" "$NEW_WP" >"$tmpdir/patcher.out" 2>"$tmpdir/patcher.err" || true

test_start "patcher_runs_without_error"
if [[ ! -s "$tmpdir/patcher.err" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
  printf '%b\n' "    stderr: $(cat "$tmpdir/patcher.err")"
fi

test_start "patcher_reports_updated_count"
count="$(tr -d '[:space:]' <"$tmpdir/patcher.out")"
# Expected: AllSpacesAndDisplays.Desktop (1) + Displays[A].Desktop (1) +
#   Spaces[DESKTOP].Default.Desktop (1) + Spaces[DESKTOP].Displays[A].Desktop (1) +
#   Spaces[LINKED].Default.Linked (1) + Spaces[LINKED].Displays[A].Linked (1) +
#   Spaces[IDLE].Default.Desktop (1) = 7. Idle is skipped.
if [[ "$count" == "7" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: patched 7 nodes (every Desktop/Linked, Idle skipped)"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected 7, got '$count'"
fi

# --- Verify the new URL landed in every Desktop/Linked node ----------------
verify_out="$tmpdir/verify.json"
python3 - "$store_dir/Index.plist" "$NEW_URI" "$verify_out" <<'PYEOF'
import plistlib, sys, json

store, want_uri, verify_out = sys.argv[1], sys.argv[2], sys.argv[3]
with open(store, "rb") as f:
    data = plistlib.load(f)

result = {
    "patched": [],   # path → URI (should all equal want_uri)
    "untouched": [], # path → URI (should be original)
    "want_uri": want_uri,
}

def url_of(node):
    cfg = node["Content"]["Choices"][0]["Configuration"]
    return plistlib.loads(cfg)["url"]["relative"]

def walk(n, k=None, p=""):
    if isinstance(n, dict):
        if k in ("Desktop", "Linked") and "Content" in n:
            result["patched"].append({"path": p, "uri": url_of(n)})
        elif k == "Idle" and "Content" in n:
            result["untouched"].append({"path": p, "uri": url_of(n)})
        else:
            for kk, vv in n.items():
                walk(vv, kk, p + "/" + kk)
    elif isinstance(n, list):
        for i, item in enumerate(n):
            walk(item, k, p + f"[{i}]")

walk(data)
with open(verify_out, "w") as f:
    json.dump(result, f, indent=2)
PYEOF

# Every patched node must equal NEW_URI.
test_start "every_desktop_linked_node_was_rewritten"
mismatches="$(python3 -c '
import json, sys
with open(sys.argv[1]) as f: r = json.load(f)
bad = [p for p in r["patched"] if p["uri"] != r["want_uri"]]
for p in bad: print(p["path"], "→", p["uri"])
' "$verify_out")"
if [[ -z "$mismatches" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all 7 nodes point to the new wallpaper"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: some nodes were not rewritten:"
  printf '%b\n' "$mismatches"
fi

# Idle nodes must be untouched (screensaver wallpaper is a separate user choice).
test_start "idle_nodes_preserved"
idle_changed="$(python3 -c '
import json, sys
with open(sys.argv[1]) as f: r = json.load(f)
bad = [p for p in r["untouched"] if p["uri"] != "file:///tmp/screensaver.png"]
for p in bad: print(p["path"], "→", p["uri"])
' "$verify_out")"
if [[ -z "$idle_changed" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: screensaver wallpaper was not clobbered"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: Idle nodes were modified:"
  printf '%b\n' "$idle_changed"
fi

# Safety backup must be written before any mutation.
test_start "safety_backup_written"
if [[ -f "$store_dir/Index.plist.dot-bak" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: Index.plist.dot-bak exists"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: backup file was not written"
fi

# The backup must contain the *original* (pre-patch) state, so a user
# can revert if a future change breaks something.
test_start "backup_contains_original_state"
backup_uris="$(
  python3 - "$store_dir/Index.plist.dot-bak" <<'PYEOF'
import plistlib, sys
with open(sys.argv[1], "rb") as f: d = plistlib.load(f)
def url_of(n):
    return plistlib.loads(n["Content"]["Choices"][0]["Configuration"])["url"]["relative"]
def walk(n, k=None):
    if isinstance(n, dict):
        if k in ("Desktop", "Linked") and "Content" in n:
            print(url_of(n))
        else:
            for kk, vv in n.items(): walk(vv, kk)
walk(d)
PYEOF
)"
if [[ -z "$(echo "$backup_uris" | grep -v 'original\.png' || true)" ]] && [[ -n "$backup_uris" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: backup holds pre-patch URIs"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: backup state unexpected:"
  printf '%b\n' "$backup_uris"
fi

# No-op when the store doesn't exist (e.g. running on Linux): patcher
# must exit cleanly without creating the file or printing anything bad.
test_start "no_op_when_store_missing"
empty_home="$tmpdir/empty-home"
mkdir -p "$empty_home"
HOME="$empty_home" python3 "$patcher" "$NEW_WP" >"$tmpdir/empty.out" 2>"$tmpdir/empty.err" || true
if [[ ! -s "$tmpdir/empty.err" ]] && [[ ! -f "$empty_home/Library/Application Support/com.apple.wallpaper/Store/Index.plist" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: noop when store missing"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: patcher misbehaved against missing store"
  printf '%b\n' "    stderr: $(cat "$tmpdir/empty.err")"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
