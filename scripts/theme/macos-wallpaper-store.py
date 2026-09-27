#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Point every macOS desktop at one image by rewriting WallpaperAgent's store.

Usage: macos-wallpaper-store.py <image-path>
Called by scripts/theme/wallpaper-sync.sh; see the comment there.
"""
import plistlib, os, sys
wp = sys.argv[1]
uri = "file://" + wp
store = os.path.expanduser(
    "~/Library/Application Support/com.apple.wallpaper/Store/Index.plist"
)
if not os.path.exists(store):
    sys.exit(0)

def make_config(uri):
    return plistlib.dumps(
        {"type": "imageFile", "url": {"relative": uri}},
        fmt=plistlib.FMT_BINARY,
    )

def patch_node(node, uri):
    """Patch a Desktop/Linked node in-place. Returns 1 if patched."""
    content = node.get("Content")
    if not isinstance(content, dict):
        return 0
    choices = content.get("Choices")
    if not isinstance(choices, list) or not choices:
        return 0
    first = choices[0]
    if not isinstance(first, dict):
        return 0
    first["Configuration"] = make_config(uri)
    first["Provider"] = "com.apple.wallpaper.choice.image"
    first["Files"] = []
    content["Choices"] = [first]
    content["Shuffle"] = "$null"
    # Leave EncodedOptionValues alone — it stores crop/color and is per-image.
    return 1

# Recursively patch every wallpaper-bearing node. A node qualifies when it
# has a Content.Choices list — this matches Desktop and Linked entries
# wherever they appear (top-level Displays, AllSpacesAndDisplays, Spaces[*]
# .Default, Spaces[*].Displays[*], etc.) and ignores Idle (screensaver) so
# we don't clobber the user's lock-screen wallpaper.
def walk(node, uri, key=None):
    count = 0
    if isinstance(node, dict):
        if key in ("Desktop", "Linked") and "Content" in node:
            count += patch_node(node, uri)
        else:
            for k, v in node.items():
                count += walk(v, uri, k)
    elif isinstance(node, list):
        for item in node:
            count += walk(item, uri)
    return count

with open(store, "rb") as f:
    data = plistlib.load(f)

# Safety backup before mutating.
try:
    with open(store + ".dot-bak", "wb") as f:
        plistlib.dump(data, f, fmt=plistlib.FMT_BINARY)
except Exception:
    pass

updated = walk(data, uri)

if updated:
    with open(store, "wb") as f:
        plistlib.dump(data, f, fmt=plistlib.FMT_BINARY)

print(updated)
