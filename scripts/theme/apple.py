#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Apple system colours for terminal palettes, resolved to WCAG AAA (7:1).

Values are Apple's published iOS/macOS system colours, from the Human
Interface Guidelines colour page (system colour table, June 9 2025 update):
https://developer.apple.com/design/human-interface-guidelines/color

Resolution rule, per colour and use:
  1. Apple's Default value for the mode, if it reaches 7:1;
  2. else Apple's Increased contrast value, if that does;
  3. else the Increased contrast hue, moved only in lightness until 7:1.

Light mode almost always needs step 3 for text: none of the 12 colours, in
either variant, reaches 7:1 on a light background (Default blue on white is
3.52:1). Dark mode reaches 7:1 exactly or via Increased contrast for every
colour as a block, and for 11 of 12 as text.

Where the palette uses them:
  term c1-c14      ANSI hues (the terminal content)
  ui accent/secondary/tertiary   the wallpaper's leading colours, snapped to
                   the nearest distinct Apple hue, as blocks under accent_text
  ui error/warning/success/info  pink, orange, green, blue blocks, labelled
                   in ui.status_text (black)
  sessions         one block per tmux session, each with its own label
"""

from __future__ import annotations

import functools
import math
import sys
from pathlib import Path
from typing import Any

import aaa

# name: (Default light, Default dark, Increased contrast light, Increased contrast dark)
SYSTEM = {
    "red": ("#ff383c", "#ff4245", "#e9152d", "#ff6165"),
    "orange": ("#ff8d28", "#ff9230", "#c55300", "#ffa056"),
    "yellow": ("#ffcc00", "#ffd600", "#a16a00", "#fedf43"),
    "green": ("#34c759", "#30d158", "#008932", "#4ad968"),
    "mint": ("#00c8b3", "#00dac3", "#008575", "#54dfcb"),
    "teal": ("#00c3d0", "#00d2e0", "#008198", "#3bddec"),
    "cyan": ("#00c0e8", "#3cd3fe", "#007eae", "#6dd9ff"),
    "blue": ("#0088ff", "#0091ff", "#1e6ef4", "#5cb8ff"),
    "indigo": ("#6155f5", "#6d7cff", "#564ade", "#a7aaff"),
    "purple": ("#cb30e0", "#db34f2", "#b02fc2", "#ea8dff"),
    "pink": ("#ff2d55", "#ff375f", "#e7124d", "#ff8ac4"),
    "brown": ("#ac7f5e", "#b78a66", "#956d51", "#dba679"),
}

# ANSI slot -> Apple colour. Normal and bright take different Apple hues so
# they never collapse; c13 is the one repeat, purple one step further out.
ANSI = {
    "c1": "red",
    "c2": "green",
    "c3": "yellow",
    "c4": "blue",
    "c5": "purple",
    "c6": "cyan",
    "c9": "pink",
    "c10": "mint",
    "c11": "orange",
    "c12": "indigo",
    "c13": "purple",
    "c14": "teal",
}
# Error is pink, not red: Apple red and orange merge under protan/deutan
# simulation, and pink/orange/green/blue with black labels are the most
# conventional Apple set that keeps all four apart for colour-blind readers
# in both modes (worst pair dE 31 dark, 12 light; the audit floor is 8).
STATUS = {"error": "pink", "warning": "orange", "success": "green", "info": "blue"}
LEADS = ("accent", "secondary", "tertiary")
BLACK, WHITE = "#000000", "#ffffff"
# WCAG 1.4.6 AAA for large-scale text (18pt, or 14pt bold): 4.5:1. The tmux
# bar labels are terminal text; at the default 20pt they are large, so the
# session blocks can be Apple's exact Default values (lowest: light purple
# with white, 5.04:1). The template falls back to the 7:1 table below 18pt.
LARGE_TEXT_RATIO = 4.5
# Normal text (WCAG 1.4.6); equals aaa.MIN_RATIO, spelled out because
# default arguments are evaluated while aaa may still be importing apple.
TEXT_RATIO = 7.0
# The 256-colour approximation keeps the audit's 4.5:1 floor (see aaa.py).
SUPPORT_MIN_DE = 18.0


def variants(name: str, dark: bool) -> tuple[str, str]:
    """(Default, Increased contrast) for the mode."""
    default_l, default_d, ic_l, ic_d = SYSTEM[name]
    return (default_d, ic_d) if dark else (default_l, ic_l)


def text(
    name: str, dark: bool, surfaces: list[str], xterm_bg: str | None = None
) -> str:
    """The Apple colour `name` as text reading 7:1 on every surface."""
    for value in variants(name, dark):
        if aaa.legible(value, surfaces, xterm_bg) == value:
            return value
    return aaa.legible(variants(name, dark)[1], surfaces, xterm_bg)


@functools.cache
def block(
    name: str, dark: bool, label: str | None = None, ratio: float = TEXT_RATIO
) -> tuple[str, str]:
    """The Apple colour `name` as a block, and a label reading `ratio` on it.

    With `label` fixed the block adapts to it; otherwise black or white
    (the stronger one), whichever lets the block stay closest to Apple's value.
    """
    labels = [label] if label else [BLACK, WHITE]
    for value in variants(name, dark):
        passing = [
            (aaa.contrast(aaa.hex_rgb(value), aaa.hex_rgb(lab)), lab)
            for lab in labels
            if aaa.contrast(aaa.hex_rgb(value), aaa.hex_rgb(lab)) >= ratio
        ]
        if passing:
            return value, max(passing)[1]
    default, ic = variants(name, dark)
    moved = [(aaa.legible(ic, [lab]), lab) for lab in labels]
    return min(moved, key=lambda pair: _delta_e(pair[0], default))


def _delta_e(left: str, right: str) -> float:
    a, b = aaa._lab(aaa.hex_rgb(left)), aaa._lab(aaa.hex_rgb(right))
    return math.dist(a, b)


def _hue(value: str) -> float:
    _l, a, b = aaa._lab(aaa.hex_rgb(value))
    return math.degrees(math.atan2(b, a)) % 360


def nearest(value: str, dark: bool, taken: list[str]) -> list[str]:
    """Apple colour names by hue distance from `value`, skipping `taken`."""
    hue = _hue(value)

    def gap(name: str) -> float:
        diff = abs(_hue(variants(name, dark)[0]) - hue) % 360
        return min(diff, 360 - diff)

    return sorted((n for n in SYSTEM if n not in taken), key=gap)


def _leads(ui: dict[str, str], dark: bool) -> dict[str, str]:
    """Snap accent/secondary/tertiary to distinct, well-separated Apple hues."""
    chosen: dict[str, str] = {}
    shown: list[str] = []
    # A colour that already IS a resolved Apple block keeps its name: moving
    # lightness to reach 7:1 shifts CIELAB hue (light blue drifts to indigo),
    # so re-snapping by hue alone would flip it on every pass.
    resolved = {block(n, dark, ui["accent_text"])[0]: n for n in SYSTEM}
    for role in LEADS:
        taken = list(chosen.values())
        known = (
            [resolved[ui[role]]] if resolved.get(ui[role]) not in (None, *taken) else []
        )
        for name in known + nearest(ui[role], dark, taken):
            value, _lab = block(name, dark, ui["accent_text"])
            if all(_delta_e(value, other) >= SUPPORT_MIN_DE for other in shown):
                chosen[role] = name
                shown.append(value)
                break
    return chosen


def _ansi(term: dict[str, str], dark: bool) -> None:
    bg = term["bg"]
    for slot, name in ANSI.items():
        term[slot] = text(name, dark, [bg], xterm_bg=bg)
    step = aaa._beyond(term["c13"], term["c5"], dark, aaa.RAMP_STEP)
    term["c13"] = step


def apply(theme: dict[str, Any]) -> dict[str, Any]:
    """Return a copy of `theme` using Apple system colours, AAA-resolved."""
    import copy

    out = copy.deepcopy(theme)
    term, ui = out["term"], out["ui"]
    dark = out["mode"] == "dark"
    _ansi(term, dark)
    surfaces = [term["bg"], ui["panel"], ui["border"]]
    for role, name in _leads(ui, dark).items():
        ui[role], _lab = block(name, dark, ui["accent_text"])
        if f"{role}_on_surface" in ui:
            ui[f"{role}_on_surface"] = text(name, dark, surfaces)
    ui["status_text"] = BLACK
    for role, name in STATUS.items():
        ui[role], _lab = block(name, dark, BLACK)
    term["cursor"] = ui["accent"]
    return out


# The tmux bars' right-hand blocks (indicators, time) are always this colour,
# so no session may take it, or any colour that sits beside it on the same
# bar without reading as different (dE < SUPPORT_MIN_DE in either mode:
# teal is 16.0 from cyan in light mode).
BAR_COLOUR = "cyan"


def _near_bar(name: str) -> bool:
    return any(
        _delta_e(variants(name, dark)[0], variants(BAR_COLOUR, dark)[0])
        < SUPPORT_MIN_DE
        for dark in (True, False)
    )


def sessions(dark: bool, ratio: float = TEXT_RATIO) -> list[tuple[str, str]]:
    """One (block, label) per Apple colour distinct from the bar's."""
    return [block(name, dark, None, ratio) for name in SYSTEM if not _near_bar(name)]


def sessions_toml() -> str:
    """The committed .chezmoidata/apple.toml: session blocks for both modes."""
    lines = [
        "# Generated by scripts/theme/apple.py --write-data; do not edit.",
        "# Apple system colours as tmux session blocks, each with the black or",
        "# white label that reads on it (format: block/label). <mode>_bar is the",
        "# cyan of the bars' right-hand blocks, kept out of the session lists.",
    ]
    tables = (
        ("apple_sessions", TEXT_RATIO, "7:1 labels, for fonts under 18pt"),
        (
            "apple_sessions_large",
            LARGE_TEXT_RATIO,
            "Apple's exact Default values; WCAG AAA large text (4.5:1)",
        ),
    )
    for table, ratio, note in tables:
        lines += ["", f"# {note}", f"[{table}]"]
        for mode in ("dark", "light"):
            pairs = ", ".join(
                f'"{b}/{lab}"' for b, lab in sessions(mode == "dark", ratio)
            )
            lines.append(f"{mode} = [{pairs}]")
            bar, lab = block(BAR_COLOUR, mode == "dark", None, ratio)
            lines.append(f'{mode}_bar = "{bar}/{lab}"')
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    path = Path(__file__).resolve().parents[2] / "defaults/.chezmoidata/apple.toml"
    want = sessions_toml()
    if "--write-data" in argv:
        path.write_text(want, encoding="utf-8")
        print(f"wrote {path}")
        return 0
    current = path.read_text(encoding="utf-8") if path.exists() else ""
    print(f"{path.name}: {'up to date' if current == want else 'stale'}")
    return 0 if current == want else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
