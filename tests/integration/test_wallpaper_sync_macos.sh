#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Integration: wallpaper-sync.sh end-to-end on macOS.
#
# Stages a sandboxed chezmoi-root layout, a fake Index.plist with
# multiple Spaces (Desktop + Linked + per-Display nodes), a wallpaper
# directory with a matching image, and mocks killall + wallpaper +
# osascript so we don't kill the user's real WallpaperAgent. Runs
# wallpaper-sync.sh and verifies the new wallpaper landed in every
# Desktop/Linked node in the staged Index.plist.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf '%b\n' "  ${YELLOW}~${NC} not macOS — skipping wallpaper-sync end-to-end test"
  echo "RESULTS:0:0:0"
  exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf '%b\n' "  ${YELLOW}~${NC} python3 not available — skipping"
  echo "RESULTS:0:0:0"
  exit 0
fi

WALLPAPER_SYNC="$REPO_ROOT/scripts/theme/wallpaper-sync.sh"

# --- Sandbox: chezmoi-root layout + fake HOME + mock bin -------------------
sandbox="$(mktemp -d -t wallpaper-sync-e2e.XXXXXX)"
trap 'rm -rf "$sandbox"' EXIT

home="$sandbox/home"
mkdir -p "$home/.config" "$home/.local/state" "$home/.cache" \
  "$sandbox/defaults/.chezmoidata" \
  "$home/Library/Application Support/com.apple.wallpaper/Store" \
  "$home/Pictures/Wallpapers" \
  "$sandbox/mock-bin"

# Wire the sandbox layout
printf 'defaults\n' >"$sandbox/.chezmoiroot"
THEME="testroom-dark"
cat >"$sandbox/defaults/.chezmoidata.toml" <<EOF
theme = "${THEME}"
EOF
cat >"$sandbox/defaults/.chezmoidata/themes.toml" <<EOF
[themes.${THEME}]
family = "testroom"
mode = "dark"
wallpaper = ""
EOF

# Symlink lib/scripts so the script can source ui.sh
ln -s "$REPO_ROOT/lib" "$sandbox/lib"
ln -s "$REPO_ROOT/scripts" "$sandbox/scripts"
ln -s "$sandbox" "$home/.dotfiles"

# Wallpaper file the script will pick
WP_FILE="$home/Pictures/Wallpapers/testroom-dark.png"
# Tiny 1x1 PNG (valid header) is enough — wallpaper-sync just passes the
# path through.
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xf8\xcf\xc0\xc0\xc0\x00\x00\x00\x05\x00\x01\xa5\xf6E\x40\x00\x00\x00\x00IEND\xaeB\x60\x82' >"$WP_FILE"

# Fake Index.plist that mirrors the structure on a real Sequoia/Tahoe box
python3 - "$home/Library/Application Support/com.apple.wallpaper/Store/Index.plist" <<'PYEOF'
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

ORIG = "file:///tmp/originally-applied.png"
IDLE = "file:///tmp/screensaver-original.png"

data = {
    "AllSpacesAndDisplays": {"Desktop": node(ORIG), "Type": "individual"},
    "Displays": {
        "DISPLAY-1": {"Desktop": node(ORIG)},
    },
    "Spaces": {
        "SPACE-A": {
            "Default": {"Desktop": node(ORIG), "Idle": node(IDLE), "Type": "individual"},
            "Displays": {"DISPLAY-1": {"Desktop": node(ORIG)}},
        },
        "SPACE-B": {
            "Default": {"Linked": node(ORIG), "Type": "linked"},
            "Displays": {"DISPLAY-1": {"Linked": node(ORIG)}},
        },
    },
}

with open(out, "wb") as f:
    plistlib.dump(data, f, fmt=plistlib.FMT_BINARY)
PYEOF

# Mock binaries so the script doesn't touch the host. killall and
# `wallpaper` log their invocations so we can assert on them.
mockbin="$sandbox/mock-bin"
log="$sandbox/calls.log"
for cmd in killall wallpaper osascript dms gsettings swaybg feh magick \
  heif-convert convert desktoppr; do
  cat >"$mockbin/$cmd" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "$cmd" "\$*" >>"$log"
exit 0
EOF
  chmod +x "$mockbin/$cmd"
done

# Run wallpaper-sync against the sandbox.
out="$(PATH="$mockbin:$PATH" HOME="$home" \
  XDG_CONFIG_HOME="$home/.config" \
  XDG_STATE_HOME="$home/.local/state" \
  XDG_CACHE_HOME="$home/.cache" \
  DOTFILES_WALLPAPER_DIR="$home/Pictures/Wallpapers" \
  bash "$WALLPAPER_SYNC" 2>&1)"

# --- Assertions ------------------------------------------------------------

test_start "script_completes_without_error"
if [[ "$out" == *"Applied wallpaper"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: output:"
  printf '%b\n' "$out"
fi

# Every wallpaper node in the staged Index.plist must point at the
# new file. We tolerate the per-Display nodes under each Space being
# left at the original URI ONLY if the per-Space Default node was
# patched — but our patcher walks all of them, so we expect 0
# stragglers.
test_start "index_plist_updated_for_every_desktop_linked_node"
result="$(
  python3 - "$home/Library/Application Support/com.apple.wallpaper/Store/Index.plist" "file://$WP_FILE" <<'PYEOF'
import plistlib, sys
store, want = sys.argv[1], sys.argv[2]
with open(store, "rb") as f: d = plistlib.load(f)
def uri(node):
    return plistlib.loads(node["Content"]["Choices"][0]["Configuration"])["url"]["relative"]
bad = []
def walk(n, k=None, p=""):
    if isinstance(n, dict):
        if k in ("Desktop", "Linked") and "Content" in n:
            actual = uri(n)
            if actual != want:
                bad.append((p, actual))
        else:
            for kk, vv in n.items(): walk(vv, kk, p + "/" + kk)
walk(d)
for p, u in bad: print(p, "→", u)
PYEOF
)"
if [[ -z "$result" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: every Space + Display now points to the new wallpaper"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: stragglers remain:"
  printf '%b\n' "$result"
fi

# Idle (screensaver) node must NOT have been touched.
test_start "screensaver_node_preserved"
idle_uri="$(
  python3 - "$home/Library/Application Support/com.apple.wallpaper/Store/Index.plist" <<'PYEOF'
import plistlib, sys
with open(sys.argv[1], "rb") as f: d = plistlib.load(f)
n = d["Spaces"]["SPACE-A"]["Default"]["Idle"]
print(plistlib.loads(n["Content"]["Choices"][0]["Configuration"])["url"]["relative"])
PYEOF
)"
if [[ "$idle_uri" == "file:///tmp/screensaver-original.png" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: Idle now points to '$idle_uri'"
fi

# Safety backup was written.
test_start "backup_written_alongside_store"
if [[ -f "$home/Library/Application Support/com.apple.wallpaper/Store/Index.plist.dot-bak" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: backup missing"
fi

# WallpaperAgent restart was triggered.
test_start "killall_wallpaper_agent_invoked"
if grep -q '^killall WallpaperAgent' "$log"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: log:"
  cat "$log" 2>/dev/null || true
fi

# Public-API nudge for the active Space happened too.
test_start "wallpaper_cli_called_for_active_space"
if grep -q "^wallpaper set" "$log"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: log:"
  cat "$log" 2>/dev/null || true
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
