#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Enforce WCAG 2.2 AAA (7:1) on every colour a theme paints as text.

One pass, shared by the wallpaper generator (extract-theme.py calls
`enforce` on each theme it emits) and by the committed catalog (run this
file with --write). A colour that already passes is returned unchanged; one
that fails keeps its hue and chroma and moves only in CIELAB lightness, away
from the surfaces it is drawn on, until every pairing reaches 7:1.

Text slots and the surfaces they land on:

  term c1-c6, c9-c14   ANSI hues on bg
  term c8              bright black (comments, autosuggestions) on bg
  term c7, c15         white and bright white on a dark bg
  term c0, c7          black and white on a light bg
  term sel_fg          selected text on sel_bg
  term cursor_text     the glyph under the block cursor
  ui *_on_surface      accent/secondary/tertiary text on bg, panel, border
  ui text_muted        de-emphasised text on bg, panel, border
  ui on_secondary_container   the tmux clock on its tinted block

Derived roles: when a theme has no secondary_container, one is made from
ui.secondary's hue: a deep tint on a dark theme, a pale tint on a light one.
on_secondary_container is that hue as text, walked to 7:1 on the tint.

Exempt: c0 on a dark bg and c15 on a light bg. Those are the palette's
background-tone slots (programs paint them as fills, e.g. `tput setab 0`),
and forcing them to 7:1 would invert the neutral ramp. The ramp itself
(c0 < c8 < c7 <= c15 in luminance) is kept: of each adjacent pair, the slot
nearer bg stays at the floor and the other moves further out.

The xterm-256 approximation of the ANSI hues (what tmux sends a terminal
without truecolor) keeps a 4.5:1 floor. Every terminal configured here sets
the 16 slots to exact hex, and the cube cannot reach 7:1 in every hue: its
darkest green, (0,95,0), is 6.96:1 on grey 238, so demanding AAA there drove
light-mode greens to grey.

Usage:
  aaa.py [CATALOG ...]           report how many colours would change (exit 1 if any)
  aaa.py --write [CATALOG ...]   rewrite failing colours in place
"""

from __future__ import annotations

import argparse
import copy
import re
import sys
from pathlib import Path
from typing import Any

import tomllib

MIN_RATIO = 7.0
XTERM_MIN_RATIO = 4.5
# Adjacent neutral slots must differ by at least this much to read as steps.
RAMP_STEP = 1.15
ANSI_HUES = tuple(f"c{i}" for i in (*range(1, 7), *range(9, 15)))
STRUCTURAL = {"dark": ("c8", "c7", "c15"), "light": ("c0", "c8", "c7")}
SURFACE_TEXT = (
    "accent_on_surface",
    "secondary_on_surface",
    "tertiary_on_surface",
    "text_muted",
)

RGB = tuple[int, int, int]
_WHITE = (0.95047, 1.0, 1.08883)
_XTERM_LEVELS = (0, 95, 135, 175, 215, 255)
_XTERM_256 = (
    (
        (0, 0, 0), (128, 0, 0), (0, 128, 0), (128, 128, 0),
        (0, 0, 128), (128, 0, 128), (0, 128, 128), (192, 192, 192),
        (128, 128, 128), (255, 0, 0), (0, 255, 0), (255, 255, 0),
        (0, 0, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255),
    )
    + tuple((r, g, b) for r in _XTERM_LEVELS for g in _XTERM_LEVELS for b in _XTERM_LEVELS)
    + tuple((8 + 10 * i,) * 3 for i in range(24))
)  # fmt: skip


def hex_rgb(value: str) -> RGB:
    return tuple(int(value[i : i + 2], 16) for i in (1, 3, 5))


def rgb_hex(rgb: RGB) -> str:
    return "#{:02x}{:02x}{:02x}".format(*rgb)


def _linear(c: float) -> float:
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _gamma(c: float) -> int:
    c = max(0.0, min(1.0, c))
    c = c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
    return round(c * 255)


def luminance(rgb: RGB) -> float:
    r, g, b = (_linear(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(left: RGB, right: RGB) -> float:
    high, low = sorted((luminance(left), luminance(right)), reverse=True)
    return (high + 0.05) / (low + 0.05)


def _lab(rgb: RGB) -> tuple[float, float, float]:
    r, g, b = (_linear(c) for c in rgb)
    xyz = (
        0.4124564 * r + 0.3575761 * g + 0.1804375 * b,
        0.2126729 * r + 0.7151522 * g + 0.0721750 * b,
        0.0193339 * r + 0.1191920 * g + 0.9503041 * b,
    )
    fx, fy, fz = (
        t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
        for t in (v / w for v, w in zip(xyz, _WHITE, strict=True))
    )
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def _rgb(lightness: float, a: float, b: float) -> RGB:
    fy = (lightness + 16) / 116
    fs = (fy + a / 500, fy, fy - b / 200)
    x, y, z = (
        (f**3 if f**3 > 0.008856 else (f - 16 / 116) / 7.787) * w
        for f, w in zip(fs, _WHITE, strict=True)
    )
    return (
        _gamma(3.2404542 * x - 1.5371385 * y - 0.4985314 * z),
        _gamma(-0.9692660 * x + 1.8760108 * y + 0.0415560 * z),
        _gamma(0.0556434 * x - 0.2040259 * y + 1.0572252 * z),
    )


def nearest_xterm(rgb: RGB) -> RGB:
    return min(_XTERM_256, key=lambda c: sum((c[i] - rgb[i]) ** 2 for i in range(3)))


def _passes(rgb: RGB, surfaces: list[RGB], xterm_bg: RGB | None) -> bool:
    if any(contrast(rgb, s) < MIN_RATIO for s in surfaces):
        return False
    if xterm_bg is None:
        return True
    return contrast(nearest_xterm(rgb), nearest_xterm(xterm_bg)) >= XTERM_MIN_RATIO


def _walk(value: str, lighter: bool, done) -> str:
    """Step `value` in CIELAB lightness (hue and chroma kept) until `done`."""
    lightness, a, b = _lab(hex_rgb(value))
    for _ in range(200):
        lightness = (
            min(100.0, lightness + 0.5) if lighter else max(0.0, lightness - 0.5)
        )
        candidate = _rgb(lightness, a, b)
        if done(candidate):
            return rgb_hex(candidate)
    return "#ffffff" if lighter else "#000000"


def legible(value: str, surfaces: list[str], xterm_bg: str | None = None) -> str:
    """Return `value`, or its nearest lightness that reads at 7:1 on `surfaces`.

    The walk goes away from the surfaces: lighter when the text already sits
    above them in luminance, darker when below. Pure white or black is the
    last resort, and reaches 7:1 on any surface a theme actually uses.
    """
    rgb = hex_rgb(value)
    backs = [hex_rgb(s) for s in surfaces]
    xbg = hex_rgb(xterm_bg) if xterm_bg else None
    if _passes(rgb, backs, xbg):
        return value
    lighter = luminance(rgb) >= max(luminance(s) for s in backs)
    return _walk(value, lighter, lambda c: _passes(c, backs, xbg))


def _beyond(value: str, anchor: str, lighter: bool, step: float) -> str:
    """Keep `value` at least `step` past `anchor`, on the `lighter` side."""
    anchor_lum = luminance(hex_rgb(anchor))

    def done(rgb: RGB) -> bool:
        side = luminance(rgb) > anchor_lum if lighter else luminance(rgb) < anchor_lum
        return side and contrast(rgb, hex_rgb(anchor)) >= step

    return value if done(hex_rgb(value)) else _walk(value, lighter, done)


def _keep_ramp(term: dict[str, str], dark: bool) -> None:
    """Restore c0 < c8 < c7 <= c15 after the floors moved c7 and c8.

    Dark: c8 sits nearest bg, so c7 and then c15 move up. Light: c7 sits
    nearest bg, so c8 and then c0 move down. Moving away from bg only ever
    raises contrast, so the AAA floors still hold afterwards.
    """
    if dark:
        term["c7"] = _beyond(term["c7"], term["c8"], True, RAMP_STEP)
        term["c15"] = _beyond(term["c15"], term["c7"], True, 1.0)
    else:
        term["c8"] = _beyond(term["c8"], term["c7"], False, RAMP_STEP)
        term["c0"] = _beyond(term["c0"], term["c8"], False, 1.0)


def _tint(value: str, lightness: float, chroma_cap: float) -> str:
    """`value`'s hue at a fixed lightness, chroma capped (then gamut-clipped)."""
    _l, a, b = _lab(hex_rgb(value))
    chroma = (a * a + b * b) ** 0.5
    scale = min(1.0, chroma_cap / chroma) if chroma else 0.0
    return rgb_hex(_rgb(lightness, a * scale, b * scale))


def _secondary_container(ui: dict[str, str], dark: bool) -> None:
    """Fill the tinted block behind the tmux clock and its text colour."""
    if "secondary" not in ui:
        return
    if "secondary_container" not in ui:
        ui["secondary_container"] = _tint(
            ui["secondary"], 24.0 if dark else 93.0, 26.0 if dark else 12.0
        )
    if "on_secondary_container" not in ui:
        ui["on_secondary_container"] = _tint(
            ui["secondary"], 82.0 if dark else 28.0, 40.0
        )
    ui["on_secondary_container"] = legible(
        ui["on_secondary_container"], [ui["secondary_container"]]
    )


def enforce(theme: dict[str, Any]) -> dict[str, Any]:
    """Return a copy of `theme` whose text colours all reach AAA."""
    out = copy.deepcopy(theme)
    term, ui = out["term"], out["ui"]
    bg = term["bg"]
    for key in ANSI_HUES:
        term[key] = legible(term[key], [bg], xterm_bg=bg)
    for key in STRUCTURAL[out["mode"]]:
        term[key] = legible(term[key], [bg])
    _keep_ramp(term, out["mode"] == "dark")
    term["sel_fg"] = legible(term["sel_fg"], [term["sel_bg"]])
    if "cursor_text" in term:
        term["cursor_text"] = legible(term["cursor_text"], [term["cursor"]])
    surfaces = [bg, ui["panel"], ui["border"]]
    for key in SURFACE_TEXT:
        ui[key] = legible(ui[key], surfaces)
    _secondary_container(ui, out["mode"] == "dark")
    return out


_SECTION = re.compile(r"^\[themes\.([^.\]]+)\.(term|ui)\]\s*$")
_ENTRY = re.compile(r'^(\s*)([a-z0-9_]+)(\s*=\s*)"(#[0-9a-fA-F]{6})"(.*)$')


def _changes(catalog: dict[str, Any]) -> dict[tuple[str, str, str], str]:
    changed = {}
    for name, theme in catalog.get("themes", {}).items():
        if not isinstance(theme, dict) or "term" not in theme or "ui" not in theme:
            continue
        fixed = enforce(theme)
        for table in ("term", "ui"):
            for key, value in fixed[table].items():
                if value != theme[table].get(key):
                    changed[(name, table, key)] = value
    return changed


def _rewrite(text: str, changed: dict[tuple[str, str, str], str]) -> str:
    """Swap changed values in place so comments and alignment survive.

    Keys a table does not have yet (derived roles) go after its last entry.
    """
    lines, section, last = [], None, {}
    pending = dict(changed)
    for line in text.splitlines(keepends=True):
        header = _SECTION.match(line)
        if header:
            section = header.groups()
        elif line.startswith("["):
            section = None
        entry = _ENTRY.match(line)
        if section and entry:
            last[section] = len(lines)
            value = pending.pop((*section, entry.group(2)), None)
            if value is not None:
                indent, key, sep, _old, rest = entry.groups()
                line = f'{indent}{key}{sep}"{value}"{rest}\n'
        lines.append(line)
    # Bottom-up, so an insertion never shifts a position still to be used.
    inserts = sorted(
        (
            (last[(name, table)] + 1, key, value)
            for (name, table, key), value in pending.items()
        ),
        reverse=True,
    )
    for at, key, value in inserts:
        lines.insert(at, f'{key} = "{value}"\n')
    return "".join(lines)


def main(argv: list[str] | None = None) -> int:
    repo = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("catalogs", nargs="*", type=Path)
    parser.add_argument("--write", action="store_true", help="rewrite in place")
    args = parser.parse_args(argv)
    paths = args.catalogs or [
        repo / "defaults/.chezmoidata/themes.toml",
        repo / "scripts/theme/fallback-themes.toml",
    ]
    pending = 0
    for path in paths:
        text = path.read_text(encoding="utf-8")
        changed = _changes(tomllib.loads(text))
        pending += len(changed)
        if args.write and changed:
            path.write_text(_rewrite(text, changed), encoding="utf-8")
        verb = "rewrote" if args.write else "would change"
        print(f"{path.name}: {verb} {len(changed)} colour(s)")
    return 0 if args.write or not pending else 1


if __name__ == "__main__":
    sys.exit(main())
