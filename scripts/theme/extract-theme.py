#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# extract-theme.py — Generate a terminal theme from wallpaper dominant colors.
#
# Uses K-Means clustering in CIELAB color space for perceptually accurate
# dominant color extraction. No external dependencies — stdlib only.
# ImageMagick is used for image downsampling and pixel extraction.
#
# Usage:
#   python3 extract-theme.py <image-path> [--name <theme-name>] [--format toml|json]
#   python3 extract-theme.py /System/Library/Desktop\ Pictures/Sonoma.heic
#   python3 extract-theme.py ~/Pictures/Wallpapers/macos-tahoe-dark.heic --name macos-tahoe-dark

import sys
import subprocess  # nosec B404 — used only with fixed magick command, no shell
import math
import random  # nosec B311 — used for K-Means seeding, not security
import json
import os
from typing import List, Tuple, Dict

# ---------------------------------------------------------------------------
# Color space conversions (RGB ↔ XYZ ↔ CIELAB)
# ---------------------------------------------------------------------------

def srgb_to_linear(c: float) -> float:
    """Linearize an sRGB component (0-1)."""
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def linear_to_srgb(c: float) -> float:
    """Gamma-compress a linear component to sRGB (0-1)."""
    c = max(0.0, min(1.0, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1.0 / 2.4)) - 0.055


def rgb_to_xyz(r: int, g: int, b: int) -> Tuple[float, float, float]:
    """Convert sRGB (0-255) to CIE XYZ (D65 illuminant)."""
    rl = srgb_to_linear(r / 255.0)
    gl = srgb_to_linear(g / 255.0)
    bl = srgb_to_linear(b / 255.0)
    x = 0.4124564 * rl + 0.3575761 * gl + 0.1804375 * bl
    y = 0.2126729 * rl + 0.7151522 * gl + 0.0721750 * bl
    z = 0.0193339 * rl + 0.1191920 * gl + 0.9503041 * bl
    return x, y, z


def xyz_to_lab(x: float, y: float, z: float) -> Tuple[float, float, float]:
    """Convert CIE XYZ to CIELAB (D65 reference white)."""
    xn, yn, zn = 0.95047, 1.00000, 1.08883

    def f(t):
        return t ** (1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0

    fx, fy, fz = f(x / xn), f(y / yn), f(z / zn)
    L = 116.0 * fy - 16.0
    a = 500.0 * (fx - fy)
    b = 200.0 * (fy - fz)
    return L, a, b


def lab_to_xyz(L: float, a: float, b: float) -> Tuple[float, float, float]:
    """Convert CIELAB to CIE XYZ (D65 reference white)."""
    xn, yn, zn = 0.95047, 1.00000, 1.08883
    fy = (L + 16.0) / 116.0
    fx = a / 500.0 + fy
    fz = fy - b / 200.0

    def inv_f(t):
        return t ** 3 if t ** 3 > 0.008856 else (t - 16.0 / 116.0) / 7.787

    return inv_f(fx) * xn, inv_f(fy) * yn, inv_f(fz) * zn


def xyz_to_rgb(x: float, y: float, z: float) -> Tuple[int, int, int]:
    """Convert CIE XYZ to sRGB (0-255)."""
    rl = 3.2404542 * x - 1.5371385 * y - 0.4985314 * z
    gl = -0.9692660 * x + 1.8760108 * y + 0.0415561 * z
    bl = 0.0556434 * x - 0.2040259 * y + 1.0572252 * z
    r = int(round(linear_to_srgb(rl) * 255))
    g = int(round(linear_to_srgb(gl) * 255))
    b = int(round(linear_to_srgb(bl) * 255))
    return max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b))


def rgb_to_lab(r: int, g: int, b: int) -> Tuple[float, float, float]:
    return xyz_to_lab(*rgb_to_xyz(r, g, b))


def lab_to_rgb(L: float, a: float, b: float) -> Tuple[int, int, int]:
    return xyz_to_rgb(*lab_to_xyz(L, a, b))


def rgb_to_hex(r: int, g: int, b: int) -> str:
    return f"#{r:02x}{g:02x}{b:02x}"


def hex_to_rgb(h: str) -> Tuple[int, int, int]:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


# ---------------------------------------------------------------------------
# Perceptual utilities
# ---------------------------------------------------------------------------

def lab_distance(a: Tuple[float, ...], b: Tuple[float, ...]) -> float:
    """Euclidean distance in CIELAB (ΔE*ab)."""
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def relative_luminance(r: int, g: int, b: int) -> float:
    """WCAG relative luminance from sRGB."""
    def ch(c):
        s = c / 255.0
        return s / 12.92 if s <= 0.03928 else ((s + 0.055) / 1.055) ** 2.4
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def contrast_ratio(c1: Tuple[int, int, int], c2: Tuple[int, int, int]) -> float:
    l1 = relative_luminance(*c1)
    l2 = relative_luminance(*c2)
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)


def lab_chroma(L: float, a: float, b: float) -> float:
    """Chroma (saturation) in CIELAB."""
    return math.sqrt(a * a + b * b)


def lab_hue(L: float, a: float, b: float) -> float:
    """Hue angle in CIELAB (0-360)."""
    h = math.degrees(math.atan2(b, a))
    return h if h >= 0 else h + 360.0


# ---------------------------------------------------------------------------
# K-Means clustering in CIELAB
# ---------------------------------------------------------------------------

def _kmeans_init(pixels, k, rng):
    """Initialize k centroids using K-Means++ seeding."""
    n = len(pixels)
    centroids = [pixels[rng.randint(0, n - 1)]]
    for _ in range(1, k):
        dists = [min(lab_distance(p, c) ** 2 for c in centroids) for p in pixels]
        total = sum(dists)
        if total == 0:
            centroids.append(pixels[rng.randint(0, n - 1)])
            continue
        r = rng.random() * total
        cumulative = 0.0
        for i, d in enumerate(dists):
            cumulative += d
            if cumulative >= r:
                centroids.append(pixels[i])
                break
    return centroids


def _assign_labels(pixels, centroids, labels):
    """Assign each pixel to its nearest centroid. Returns number of changed labels."""
    changed = 0
    for i, p in enumerate(pixels):
        best_j = 0
        best_d = lab_distance(p, centroids[0])
        for j in range(1, len(centroids)):
            d = lab_distance(p, centroids[j])
            if d < best_d:
                best_d = d
                best_j = j
        if labels[i] != best_j:
            changed += 1
        labels[i] = best_j
    return changed


def _update_centroids(pixels, labels, centroids):
    """Recompute centroids as the mean of assigned pixels."""
    n = len(pixels)
    for j, _ in enumerate(centroids):
        members = [pixels[i] for i in range(n) if labels[i] == j]
        if members:
            centroids[j] = tuple(
                sum(m[d] for m in members) / len(members) for d in range(3)
            )


def _kmeans_single_run(pixels, k, max_iter, rng):
    """Run one K-Means iteration loop. Returns (centroids, labels, inertia)."""
    centroids = _kmeans_init(pixels, k, rng)
    labels = [0] * len(pixels)
    for _ in range(max_iter):
        changed = _assign_labels(pixels, centroids, labels)
        if changed == 0:
            break
        _update_centroids(pixels, labels, centroids)
    inertia = sum(
        lab_distance(pixels[i], centroids[labels[i]]) ** 2 for i in range(len(pixels))
    )
    return centroids, labels, inertia


def kmeans_lab(
    pixels: List[Tuple[float, float, float]],
    k: int = 8,
    max_iter: int = 20,
    runs: int = 3,
) -> List[Tuple[Tuple[float, float, float], int]]:
    """Run K-Means clustering in CIELAB space with best-of-N initialization."""
    n = len(pixels)
    if n == 0:
        return []

    best_centroids = None
    best_labels = None
    best_inertia = float("inf")

    for run_idx in range(runs):
        rng = random.Random(run_idx * 42 + 7)  # nosec B311
        centroids, labels, inertia = _kmeans_single_run(pixels, k, max_iter, rng)
        if inertia < best_inertia:
            best_inertia = inertia
            best_centroids = centroids[:]
            best_labels = labels[:]

    populations = [0] * k
    for label in best_labels:
        populations[label] += 1

    result = [(best_centroids[j], populations[j]) for j in range(k)]
    result.sort(key=lambda x: x[1], reverse=True)
    return result


# ---------------------------------------------------------------------------
# Pixel extraction via ImageMagick
# ---------------------------------------------------------------------------

def extract_pixels(image_path: str, max_dim: int = 80) -> List[Tuple[int, int, int]]:
    """Downsample image and extract RGB pixels using ImageMagick."""
    # Validate path contains no shell metacharacters (defense in depth)
    base_path = image_path.split("[")[0] if "[" in image_path else image_path
    if not os.path.isfile(base_path):
        raise FileNotFoundError(f"Image not found: {base_path}")
    cmd = [
        "magick", image_path,
        "-resize", f"{max_dim}x{max_dim}>",
        "-depth", "8",
        "txt:-",
    ]
    # cmd is a fixed list with validated image_path, shell=False by default
    result = subprocess.run(  # nosec B603
        cmd, capture_output=True, text=True, timeout=30, check=False
    )
    if result.returncode != 0:
        raise RuntimeError(f"ImageMagick failed: {result.stderr}")

    pixels = []
    for line in result.stdout.splitlines():
        if line.startswith("#"):
            continue
        # Format: "x,y: (R,G,B)  #RRGGBB  srgb(R,G,B)" or with alpha
        parts = line.split("(")
        if len(parts) < 2:
            continue
        color_part = parts[1].split(")")[0]
        components = [c.strip() for c in color_part.split(",")]
        if len(components) >= 3:
            try:
                r, g, b = int(components[0]), int(components[1]), int(components[2])
                pixels.append((r, g, b))
            except ValueError:
                continue
    return pixels


# ---------------------------------------------------------------------------
# Theme generation from dominant colors
# ---------------------------------------------------------------------------

# ANSI hue targets in CIELAB hue angle
ANSI_HUES = {
    "red": 30.0,
    "green": 145.0,
    "yellow": 95.0,
    "blue": 275.0,
    "magenta": 330.0,
    "cyan": 210.0,
}

# Apple HIG increased-contrast system colours (June 2025 specification).
#
# A terminal cannot call NSColor's dynamic semantic APIs, so these are used as
# perceptual calibration anchors, not copied as the final palette. Wallpaper
# hue is preserved while chroma is brought into the same legibility range as
# Apple's independently tuned light and dark appearances.
HIG_INCREASED_CONTRAST = {
    "light": [
        (233, 21, 45), (197, 83, 0), (161, 106, 0), (0, 137, 50),
        (0, 133, 117), (0, 129, 152), (0, 126, 174), (30, 110, 244),
        (86, 74, 222), (176, 47, 194), (231, 18, 77), (149, 109, 81),
    ],
    "dark": [
        (255, 97, 101), (255, 160, 86), (254, 223, 67), (74, 217, 104),
        (84, 223, 203), (59, 221, 236), (109, 217, 255), (92, 184, 255),
        (167, 170, 255), (234, 141, 255), (255, 138, 196), (219, 166, 121),
    ],
}


def find_nearest_hue(hue: float) -> str:
    """Map a CIELAB hue angle to the nearest ANSI color name."""
    best_name = "red"
    best_dist = 360.0
    for name, target in ANSI_HUES.items():
        dist = min(abs(hue - target), 360 - abs(hue - target))
        if dist < best_dist:
            best_dist = dist
            best_name = name
    return best_name


def _hue_distance(left: float, right: float) -> float:
    """Smallest distance between two hue angles."""
    return min(abs(left - right), 360.0 - abs(left - right))


def _fit_lab_to_srgb(lab: Tuple[float, float, float]) -> Tuple[float, float, float]:
    """Reduce chroma until a Lab colour survives the sRGB round trip.

    Wallpaper clusters can sit well outside the terminal's sRGB gamut. Raw
    channel clamping makes supposedly different hues collapse to the same
    muddy colour, so fit chroma before emitting the value.
    """
    lightness, _a, _b = lab
    hue = lab_hue(*lab)
    chroma = lab_chroma(*lab)
    for _ in range(48):
        candidate = (
            lightness,
            math.cos(math.radians(hue)) * chroma,
            math.sin(math.radians(hue)) * chroma,
        )
        rendered = rgb_to_lab(*lab_to_rgb(*candidate))
        if lab_distance(candidate, rendered) <= 2.0:
            return rendered
        chroma *= 0.94
    return rgb_to_lab(*lab_to_rgb(lightness, 0.0, 0.0))


def _hig_reference_lab(lab, is_dark):
    """Nearest Apple increased-contrast system colour by perceptual hue."""
    hue = lab_hue(*lab)
    references = [
        rgb_to_lab(*rgb)
        for rgb in HIG_INCREASED_CONTRAST["dark" if is_dark else "light"]
    ]
    return min(references, key=lambda ref: _hue_distance(hue, lab_hue(*ref)))


def _hig_semantic_lab(lab, is_dark):
    """Preserve wallpaper hue with Apple-like mode-specific chroma."""
    hue = lab_hue(*lab)
    reference = _hig_reference_lab(lab, is_dark)
    reference_chroma = lab_chroma(*reference)
    source_chroma = lab_chroma(*lab)
    # Increased-contrast system colours remain visibly chromatic in both
    # appearances. Keep source variation but prevent washed-out or neon ends.
    chroma = max(reference_chroma * 0.86, source_chroma * 1.10)
    chroma = min(chroma, reference_chroma * 1.12)
    radians = math.radians(hue)
    return (lab[0], math.cos(radians) * chroma, math.sin(radians) * chroma)


def adjust_lightness(lab: Tuple[float, float, float], target_L: float) -> Tuple[float, float, float]:
    """Adjust L* while preserving hue and chroma."""
    L, a, b = lab
    if L == 0:
        return (target_L, a, b)
    scale = target_L / L
    return (target_L, a * min(scale, 1.5), b * min(scale, 1.5))


def ensure_contrast(
    fg_rgb: Tuple[int, int, int],
    bg_rgb: Tuple[int, int, int],
    min_ratio: float,
    is_dark: bool,
) -> Tuple[int, int, int]:
    """Adjust fg lightness until contrast ratio meets min_ratio against bg."""
    fl, fa, fb = rgb_to_lab(*fg_rgb)
    for _ in range(80):
        cr = contrast_ratio(lab_to_rgb(fl, fa, fb), bg_rgb)
        if cr >= min_ratio:
            break
        fl += 2.0 if is_dark else -2.0
        fl = max(0.0, min(100.0, fl))
    return lab_to_rgb(fl, fa, fb)


# VS Code theming — Catppuccin only.
#
# The label must match `contributes.themes[].label` in the extension's
# package.json exactly, and the icon id must match `contributes.iconThemes[].id`.
# VS Code cannot resolve an unknown name: it keeps whatever is active and logs
# an error the user never sees, which is how three wrong values here survived.
#
# Verified against catppuccin.catppuccin-vsc 3.19.0 and
# catppuccin.catppuccin-vsc-icons 1.26.0:
#   themes      Catppuccin Mocha | Macchiato | Frappe | Latte
#   iconThemes  catppuccin-mocha | -macchiato | -frappe | -latte
#   productIconThemes  (none — the extension registers none at all)
#
# Neovim still picks per-family (tokyonight/everforest/catppuccin) from the
# wallpaper hue; only the VS Code surface is pinned, because a single editor
# theme that is always installed beats three that mostly are not.
VSCODE_DARK = "Catppuccin Mocha"
VSCODE_LIGHT = "Catppuccin Latte"
VSCODE_ICONS_DARK = "catppuccin-mocha"
VSCODE_ICONS_LIGHT = "catppuccin-latte"


def _nvim_from_hue(hue: float, is_dark: bool) -> Tuple[str, str]:
    """Map accent hue angle to nearest Neovim colorscheme."""
    if 60 <= hue < 150:
        return ("everforest", "hard" if is_dark else "soft")
    if 210 <= hue < 270:
        return ("tokyonight", "night" if is_dark else "day")
    return ("catppuccin", "mocha" if is_dark else "latte")


def _macos_accent_from_hue(hue: float) -> int:
    """Map a CIELAB hue angle to a macOS accent-colour integer.

    Boundaries are calibrated to the CIELAB hues of Apple's own accent
    swatches (not HSL): red≈36°, orange≈67°, yellow≈87°, green≈144°,
    blue≈287°, purple≈317°. The previous HSL-style cutoffs pushed blue
    accents (~283°) into Purple and purple into Pink.
    """
    hue = hue % 360
    if hue < 15 or hue >= 345:
        return 6   # Pink / magenta
    if hue < 50:
        return 0   # Red
    if hue < 77:
        return 1   # Orange
    if hue < 110:
        return 2   # Yellow
    if hue < 200:
        return 3   # Green
    if hue < 300:
        return 4   # Blue (incl. teal-blue and navy)
    return 5       # Purple / indigo (300–345)


def _env_hex(key: str, fallback: str) -> str:
    """A #rrggbb value from env, or the fallback when unset/invalid."""
    v = os.environ.get(key, "")
    if len(v) == 7 and v[0] == "#":
        try:
            hex_to_rgb(v)
            return v
        except ValueError:
            pass
    return fallback


def _compute_bg_fg(clusters, is_dark):
    """Terminal background/foreground tinted from the active wallpaper.

    Start from Apple's semantic system-gray hierarchy, then carry enough of the
    wallpaper's dominant hue into them that switching families is immediately
    visible. Lightness remains fixed, preserving predictable contrast; only
    a*/b* move. Override the bases per mode via DOTFILES_TERM_BG_DARK /
    _FG_DARK / _BG_LIGHT / _FG_LIGHT, or set DOTFILES_TERM_TINT=0 to retain
    the untinted bases.
    """
    if is_dark:
        bg_rgb = hex_to_rgb(_env_hex("DOTFILES_TERM_BG_DARK", "#1c1c1e"))
        fg_rgb = hex_to_rgb(_env_hex("DOTFILES_TERM_FG_DARK", "#f5f5f7"))
    else:
        bg_rgb = hex_to_rgb(_env_hex("DOTFILES_TERM_BG_LIGHT", "#f2f2f7"))
        fg_rgb = hex_to_rgb(_env_hex("DOTFILES_TERM_FG_LIGHT", "#1d1d1f"))

    # Tint the engineered neutral toward the wallpaper's dominant hue. A
    # fixed chroma of 4.5 was technically different but perceptually too close
    # to grey: Berlin, Maui and Rose all looked like the same terminal. Scale
    # with the source image instead, bounded so vivid wallpapers remain calm.
    tint_enabled = os.environ.get("DOTFILES_TERM_TINT", "1").lower() not in {
        "0", "false", "no", "off"
    }
    if tint_enabled:
        ranked = sorted(clusters, key=lambda c: c[1] * lab_chroma(*c[0]), reverse=True)
        src = ranked[0][0] if ranked and lab_chroma(*ranked[0][0]) >= 5.0 else None
        if src is not None:
            hue_c = lab_chroma(*src)
            if hue_c > 0:
                # Dark surfaces need more chroma for the tint to remain
                # visible. Foreground tint stays restrained so text remains
                # neutral-looking while belonging to the same palette.
                if is_dark:
                    bg_chroma = max(7.0, min(12.0, hue_c * 0.24))
                    fg_chroma = max(1.5, min(3.0, bg_chroma * 0.24))
                else:
                    bg_chroma = max(3.5, min(7.0, hue_c * 0.16))
                    fg_chroma = max(1.0, min(2.5, bg_chroma * 0.24))
                ua, ub = src[1] / hue_c, src[2] / hue_c
                bl = rgb_to_lab(*bg_rgb)[0]
                fl = rgb_to_lab(*fg_rgb)[0]
                bg_rgb = lab_to_rgb(bl, ua * bg_chroma, ub * bg_chroma)
                fg_rgb = lab_to_rgb(fl, ua * fg_chroma, ub * fg_chroma)

    bg_lab = rgb_to_lab(*bg_rgb)
    return bg_lab, bg_rgb, fg_rgb


def _compute_accent(clusters, is_dark):
    """Select the accent from the wallpaper's DOMINANT chromatic colour.

    Rank clusters by population x chroma so the accent follows the *main*
    colour of the wallpaper (a large, colourful region) rather than the
    single most-saturated cluster — which is often a tiny vivid splash
    that doesn't represent the image. Near-neutral clusters score ~0 and
    are skipped; if the whole image is neutral we fall back to the most
    saturated cluster so the accent still carries a hue. The selected
    colour is then moved toward the opposite end of the terminal surface:
    bright on dark themes and deep on light themes. This is the same design
    principle as tmux-colorful's automatic black/white foreground selection,
    with an explicit AAA contrast guarantee rather than a YIQ threshold."""
    ranked = sorted(clusters, key=lambda c: c[1] * lab_chroma(*c[0]), reverse=True)
    accent_lab = ranked[0][0]
    if lab_chroma(*accent_lab) < 5.0:
        accent_lab = max(clusters, key=lambda c: lab_chroma(*c[0]))[0]
    accent_lab = _aaa_block(accent_lab, is_dark)
    return accent_lab, lab_to_rgb(*accent_lab)


# Minimum perceptual distance between the three support colours, as dE*ab.
#
# This replaced a 12-degree hue-angle check, which let near-identical colours
# through: hue angle is meaningless at low chroma, so three slate blues at
# chroma ~13 could sit 12 degrees apart and still be the same colour to look
# at. forest-dark's accent/secondary/tertiary measured dE 3.6 — against ~2.3
# for "just noticeable" — while passing the hue rule comfortably.
#
# 10 is roughly where two colours read as clearly different rather than as
# shades of one. Measured over the library, 68 of 228 themes had at least one
# pair below it; those now reach further down the cluster ranking for a
# candidate that is actually distinct, and only fall back to a synthetic
# rotation when the wallpaper genuinely has nothing else to offer.
SUPPORT_MIN_DE = 18.0


def _aaa_block(lab, is_dark):
    """Return a vivid block colour with AAA-readable foreground text.

    Dark terminal surfaces get luminous blocks with black text; light
    surfaces get deep blocks with white text. Hue and chroma are unchanged
    while lightness moves only as far as needed for a 7:1 contrast ratio.
    This avoids the old behaviour where every mode darkened accents for white
    text and consequently made dark terminals look uniformly muddy.
    """
    semantic = _hig_semantic_lab(lab, is_dark)
    reference = _hig_reference_lab(lab, is_dark)
    L = (
        max(semantic[0], reference[0], 62.0)
        if is_dark
        else min(semantic[0], reference[0], 38.0)
    )
    a, b = semantic[1], semantic[2]
    text = (0, 0, 0) if is_dark else (255, 255, 255)
    step = 1.5 if is_dark else -1.5
    for _ in range(120):
        if contrast_ratio(text, lab_to_rgb(L, a, b)) >= 7.0:
            break
        L = max(0.0, min(100.0, L + step))
    return _fit_lab_to_srgb((L, a, b))


def _displayed(lab, is_dark):
    """The LAB of the colour that will actually be SHOWN.

    Cluster centroids routinely land outside sRGB — Tang's top three sit at
    chroma 197, 119 and 98, where sRGB tops out near 130 — and `lab_to_rgb`
    clamps them. Comparing the raw LAB values said those three were dE 79 and
    49 apart; after clamping they were #a80000 and #b00000, dE 3.3. The
    distance test has to run on the clamped colour or it is measuring
    something the user never sees.
    """
    return rgb_to_lab(*lab_to_rgb(*_aaa_block(lab, is_dark)))


def _compute_support_colours(clusters, accent_lab, is_dark):
    """The wallpaper's SECOND and THIRD chromatic colours, as UI accents.

    `_compute_accent` takes the top of the population x chroma ranking and
    throws the rest away, so a wallpaper contributed exactly one colour to
    the UI and everything else — status bars, separators, inactive states —
    fell back to fixed neutrals. These are the next two ranked clusters,
    put through the same mode-aware AAA mapping as the accent.

    Clusters within 12 degrees of a colour already chosen are skipped: two
    near-identical blues give no more information than one, and the point of
    a secondary is that it reads as different.
    """
    ranked = [c for c in sorted(clusters, key=lambda c: c[1] * lab_chroma(*c[0]), reverse=True)
              if lab_chroma(*c[0]) >= 5.0]
    # Compare the colours as they will be SHOWN, not as the clusters arrived:
    # the AAA block mapping moves lightness, which moves perceptual distance.
    picked, chosen = [], [rgb_to_lab(*lab_to_rgb(*accent_lab))]
    for lab, _pop in ranked:
        final = _displayed(lab, is_dark)
        if any(lab_distance(final, o) < SUPPORT_MIN_DE for o in chosen):
            continue
        picked.append(lab)
        chosen.append(final)
        if len(picked) == 2:
            break
    # A wallpaper with only one usable hue still needs two support colours, so
    # the accent's hue is rotated to invent them. Rotating blindly does not
    # work: a rotated hue at high chroma often falls outside sRGB, and
    # lab_to_rgb clamps it. Two different angles then clamp to nearly the same
    # colour — tang-light produced #695600 and #685600, dE 0.5 apart, both at
    # chroma 45. The fallback was the one path not checking its own output.
    #
    # So search: walk angles away from the accent, and drop chroma until the
    # result survives a round trip through sRGB (proof it is in gamut) and is
    # far enough from everything already chosen.
    while len(picked) < 2:
        base = picked[-1] if picked else accent_lab
        best = None
        for deg in (120, 90, 150, 60, 180, 40, 210, 30, 240, 270, 300):
            for scale in (1.0, 0.85, 0.7, 0.55, 0.4):
                c = lab_chroma(*base) * scale
                rad = math.radians((lab_hue(*base) + deg) % 360.0)
                cand_lab = (base[0], math.cos(rad) * c, math.sin(rad) * c)
                final = _displayed(cand_lab, is_dark)
                rgb = lab_to_rgb(*_aaa_block(cand_lab, is_dark))
                # Round trip: if the colour was out of gamut it was clamped,
                # and the clamped value will not convert back to what we asked
                # for. That is exactly how the duplicates were produced.
                if lab_distance(rgb_to_lab(*rgb), final) > 3.0:
                    continue
                d = min(lab_distance(final, o) for o in chosen)
                if d >= SUPPORT_MIN_DE:
                    best = cand_lab
                    break
                if best is None or d > min(lab_distance(_displayed(best, is_dark), o) for o in chosen):
                    best = cand_lab
            if best is not None and min(
                lab_distance(_displayed(best, is_dark), o) for o in chosen
            ) >= SUPPORT_MIN_DE:
                break
        if best is None:
            best = (base[0], -base[1], -base[2])  # last resort: opposite hue
        picked.append(best)
        chosen.append(_displayed(best, is_dark))

    return (lab_to_rgb(*_aaa_block(picked[0], is_dark)),
            lab_to_rgb(*_aaa_block(picked[1], is_dark)))


def _on_surface(lab, surfaces, is_dark, min_ratio=4.5):
    """The same hue, readable as text on every terminal surface.

    Walk lightness away from the surface: upward for a dark terminal and
    downward for a light one. This retains the wallpaper hue and keeps text
    accents legible independently of their block-background counterparts.
    """
    L, a, b = lab
    step = 1.5 if is_dark else -1.5
    for _ in range(120):
        rgb = lab_to_rgb(L, a, b)
        if all(contrast_ratio(rgb, s) >= min_ratio for s in surfaces):
            return rgb
        if (is_dark and L >= 100.0) or (not is_dark and L <= 0.0):
            break
        L = max(0.0, min(100.0, L + step))
    return lab_to_rgb(L, a, b)


def _muted_text(panel_rgb, border_rgb, bg_lab, is_dark):
    """Readable de-emphasised text — 4.5:1 against every surface it lands on.

    Not `term.c8`. c8 is ANSI bright-black and is supposed to be dim; its
    floor is 2.5:1 against bg, and tmux was painting the clock and the
    inactive window names with it at 2.12:1 and 2.45:1. Raising c8 would
    have made every terminal's dim colour less dim in order to fix a status
    bar, so this is a separate slot.

    Floored against BOTH panel and border, not just panel: the two differ in
    lightness, tmux draws muted text on each of them, and flooring against
    only the friendlier one left the other at 4.40:1 — a near miss is still
    a miss.
    """
    start = 62.0 if is_dark else 42.0
    seed = lab_to_rgb(start, bg_lab[1] * 0.5, bg_lab[2] * 0.5)
    out = seed
    for surface in (panel_rgb, border_rgb):
        out = ensure_contrast(out, surface, 4.5, is_dark)
    # ensure_contrast against the second surface can walk back toward the
    # first, so confirm rather than assume, and step until both hold.
    for _ in range(80):
        if all(contrast_ratio(out, s) >= 4.5 for s in (panel_rgb, border_rgb)):
            break
        l, a, b = rgb_to_lab(*out)
        l = min(100.0, l + 2.0) if is_dark else max(0.0, l - 2.0)
        out = lab_to_rgb(l, a, b)
    return out


def _compute_panel_border(bg_lab, bg_rgb, is_dark):
    """Compute Apple's primary/secondary/tertiary surface hierarchy.

    The offsets mirror system gray 6 -> gray 5 -> gray 4: elevation gets
    lighter in dark mode and darker in light mode. Chroma recedes with each
    layer so large surfaces remain calm while accents carry the wallpaper.
    """
    if is_dark:
        panel_lab = (min(bg_lab[0] + 8, 100), bg_lab[1] * 0.85, bg_lab[2] * 0.85)
        border_lab = (min(bg_lab[0] + 14, 100), bg_lab[1] * 0.65, bg_lab[2] * 0.65)
    else:
        panel_lab = (max(bg_lab[0] - 5, 0), bg_lab[1] * 0.85, bg_lab[2] * 0.85)
        border_lab = (max(bg_lab[0] - 12, 0), bg_lab[1] * 0.65, bg_lab[2] * 0.65)
    panel_rgb = lab_to_rgb(*panel_lab)
    for _ in range(20):
        pr = contrast_ratio(panel_rgb, bg_rgb)
        if 1.08 <= pr <= 2.0:
            break
        if pr < 1.08:
            panel_lab = (panel_lab[0] + (2 if is_dark else -2), panel_lab[1], panel_lab[2])
        else:
            panel_lab = (panel_lab[0] + (-1 if is_dark else 1), panel_lab[1], panel_lab[2])
        panel_lab = (max(0, min(100, panel_lab[0])), panel_lab[1], panel_lab[2])
        panel_rgb = lab_to_rgb(*panel_lab)
    return panel_rgb, lab_to_rgb(*border_lab)


def _build_ansi_color(base_lab, accent_lab, bg_rgb, is_dark):
    """Build normal + bright ANSI variant from a base Lab color."""
    reference = _hig_reference_lab(base_lab, is_dark)
    base_lab = _hig_semantic_lab(base_lab, is_dark)
    normal_L = (
        max(65.0, min(82.0, reference[0])) if is_dark
        else max(30.0, min(50.0, base_lab[0]))
    )
    normal = _fit_lab_to_srgb((normal_L, base_lab[1], base_lab[2]))
    if is_dark:
        # Dark bg: the bright variant pops by getting lighter.
        bright = _fit_lab_to_srgb((min(92.0, normal_L + 10), base_lab[1], base_lab[2]))
        bright_min = 4.5
    else:
        # Light bg: a lighter bright would wash out against near-white, so
        # brighten by vividness at equal lightness instead — the bright is
        # never darker than the normal (matches Apple's light ANSI ramp,
        # where brights read as more saturated, not muddier).
        bright = _fit_lab_to_srgb((normal[0], normal[1] * 1.15, normal[2] * 1.15))
        bright_min = 7.0
    # WCAG AAA (7:1) for the chromatic slots on a light bg so coloured text
    # (paths, syntax) is unambiguously legible — AA (4.5:1) still read as washed
    # out on cream. Brights stay AAA too and differ from normals by saturation
    # (Apple's light ramp), not lightness. Dark mode keeps its lower floor
    # (light text on dark reads comfortably at a lower ratio).
    normal_min = 4.5 if is_dark else 7.0
    normal_rgb = ensure_contrast(lab_to_rgb(*normal), bg_rgb, normal_min, is_dark)
    bright_rgb = ensure_contrast(lab_to_rgb(*bright), bg_rgb, bright_min, is_dark)
    return normal_rgb, bright_rgb


def _ansi_palette(clusters, accent_lab, bg_rgb, is_dark):
    """Generate the 6 chromatic ANSI hues (red, green, yellow, blue, magenta, cyan)."""
    chromatic = [(c, pop) for c, pop in clusters if lab_chroma(*c) > 10]
    hue_assignments: Dict[str, List[Tuple[float, float, float]]] = {h: [] for h in ANSI_HUES}
    for c_lab, _ in chromatic:
        hue_assignments[find_nearest_hue(lab_hue(*c_lab))].append(c_lab)

    accent_chroma = lab_chroma(*accent_lab)
    ansi = {}
    for hue_name, target_hue in ANSI_HUES.items():
        candidates = hue_assignments[hue_name]
        if candidates:
            base = max(candidates, key=lambda c: lab_chroma(*c))
        else:
            new_a = accent_chroma * math.cos(math.radians(target_hue))
            new_b = accent_chroma * math.sin(math.radians(target_hue))
            base = (50.0, new_a, new_b)
        ansi[hue_name] = _build_ansi_color(base, accent_lab, bg_rgb, is_dark)
    return ansi


def _structural_colors(bg_lab, bg_rgb, is_dark):
    """Compute c0, c7, c8, c15 structural ANSI colors."""
    if is_dark:
        return (
            ensure_contrast(lab_to_rgb(bg_lab[0] + 10, bg_lab[1], bg_lab[2]), bg_rgb, 1.5, True),
            ensure_contrast(lab_to_rgb(75.0, bg_lab[1] * 0.1, bg_lab[2] * 0.1), bg_rgb, 5.0, True),
            ensure_contrast(lab_to_rgb(bg_lab[0] + 25, bg_lab[1], bg_lab[2]), bg_rgb, 2.5, True),
            ensure_contrast(lab_to_rgb(90.0, bg_lab[1] * 0.05, bg_lab[2] * 0.05), bg_rgb, 7.0, True),
        )
    # Light bg: the neutral ramp increases in lightness (c0 < c8 < c7 < c15).
    # c0/c8/c7 stay readable (>= AA); c15 ("bright white") is the LIGHTEST tone,
    # strictly lighter than c7 — bright-white text legibility is gated by fg, not
    # c15, and forcing c15 to the same floor as c7 made them converge (c15 ended
    # a hair darker, breaking the ramp). Start c15 well above c7 with only a mild
    # floor so it stays the lightest. (Terminals render the dark palette; this
    # ramp only feeds non-terminal light-palette consumers.)
    return (
        ensure_contrast(lab_to_rgb(18.0, bg_lab[1] * 0.2, bg_lab[2] * 0.2), bg_rgb, 7.0, False),
        ensure_contrast(lab_to_rgb(50.0, bg_lab[1] * 0.15, bg_lab[2] * 0.15), bg_rgb, 4.5, False),
        ensure_contrast(lab_to_rgb(35.0, bg_lab[1] * 0.2, bg_lab[2] * 0.2), bg_rgb, 4.5, False),
        ensure_contrast(lab_to_rgb(64.0, bg_lab[1] * 0.08, bg_lab[2] * 0.08), bg_rgb, 2.5, False),
    )


def generate_theme(
    clusters: List[Tuple[Tuple[float, float, float], int]],
    name: str,
    is_dark: bool,
) -> Dict:
    """Generate a full theme definition from clustered dominant colors."""
    bg_lab, bg_rgb, fg_rgb = _compute_bg_fg(clusters, is_dark)
    accent_lab, accent_rgb = _compute_accent(clusters, is_dark)
    accent_text = (0, 0, 0) if is_dark else (255, 255, 255)
    cursor_rgb = accent_rgb

    # Selection background
    if is_dark:
        sel_lab = (bg_lab[0] + 15, accent_lab[1] * 0.4, accent_lab[2] * 0.4)
    else:
        sel_lab = (bg_lab[0] - 12, accent_lab[1] * 0.3, accent_lab[2] * 0.3)
    sel_rgb = lab_to_rgb(*sel_lab)

    panel_rgb, border_rgb = _compute_panel_border(bg_lab, bg_rgb, is_dark)
    secondary_rgb, tertiary_rgb = _compute_support_colours(clusters, accent_lab, is_dark)
    muted_rgb = _muted_text(panel_rgb, border_rgb, bg_lab, is_dark)
    # Text-safe versions of the three chromatic colours, for consumers that
    # paint them as foreground on panel/border rather than as a block.
    _surfaces = (panel_rgb, border_rgb, bg_rgb)
    accent_on_rgb = _on_surface(rgb_to_lab(*accent_rgb), _surfaces, is_dark)
    secondary_on_rgb = _on_surface(rgb_to_lab(*secondary_rgb), _surfaces, is_dark)
    tertiary_on_rgb = _on_surface(rgb_to_lab(*tertiary_rgb), _surfaces, is_dark)
    ansi = _ansi_palette(clusters, accent_lab, bg_rgb, is_dark)
    c0_rgb, c7_rgb, c8_rgb, c15_rgb = _structural_colors(bg_lab, bg_rgb, is_dark)
    status_rgb = {
        colour: lab_to_rgb(*_aaa_block(rgb_to_lab(*ansi[colour][0]), is_dark))
        for colour in ("red", "yellow", "green", "blue")
    }

    accent_hue = lab_hue(*accent_lab)
    nvim_theme = _nvim_from_hue(accent_hue, is_dark)
    macos_accent = _macos_accent_from_hue(accent_hue)

    mode = "dark" if is_dark else "light"

    return {
        "name": name,
        "mode": mode,
        "family": name.rsplit("-", 1)[0] if name.endswith(f"-{mode}") else name,
        "macos_accent": macos_accent,
        "wallpaper": "",  # Set by caller
        "source": "custom",  # Set by caller
        "term": {
            "bg": rgb_to_hex(*bg_rgb),
            "fg": rgb_to_hex(*fg_rgb),
            "cursor": rgb_to_hex(*cursor_rgb),
            "cursor_text": rgb_to_hex(*bg_rgb),
            "sel_bg": rgb_to_hex(*sel_rgb),
            "sel_fg": rgb_to_hex(*fg_rgb),
            "c0": rgb_to_hex(*c0_rgb),
            "c1": rgb_to_hex(*ansi["red"][0]),
            "c2": rgb_to_hex(*ansi["green"][0]),
            "c3": rgb_to_hex(*ansi["yellow"][0]),
            "c4": rgb_to_hex(*ansi["blue"][0]),
            "c5": rgb_to_hex(*ansi["magenta"][0]),
            "c6": rgb_to_hex(*ansi["cyan"][0]),
            "c7": rgb_to_hex(*c7_rgb),
            "c8": rgb_to_hex(*c8_rgb),
            "c9": rgb_to_hex(*ansi["red"][1]),
            "c10": rgb_to_hex(*ansi["green"][1]),
            "c11": rgb_to_hex(*ansi["yellow"][1]),
            "c12": rgb_to_hex(*ansi["blue"][1]),
            "c13": rgb_to_hex(*ansi["magenta"][1]),
            "c14": rgb_to_hex(*ansi["cyan"][1]),
            "c15": rgb_to_hex(*c15_rgb),
        },
        "ui": {
            "accent": rgb_to_hex(*accent_rgb),
            "accent_text": rgb_to_hex(*accent_text),
            "error": rgb_to_hex(*status_rgb["red"]),
            "warning": rgb_to_hex(*status_rgb["yellow"]),
            "success": rgb_to_hex(*status_rgb["green"]),
            "info": rgb_to_hex(*status_rgb["blue"]),
            "panel": rgb_to_hex(*panel_rgb),
            "border": rgb_to_hex(*border_rgb),
            # The wallpaper's 2nd and 3rd chromatic colours. Black text sits
            # on dark-mode blocks and white text on light-mode blocks at 7:1.
            "secondary": rgb_to_hex(*secondary_rgb),
            "tertiary": rgb_to_hex(*tertiary_rgb),
            # De-emphasised text that is still text: 4.5:1 against `panel`.
            "text_muted": rgb_to_hex(*muted_rgb),
            # Same hues, lightened until they are legible AS TEXT on panel,
            # border and bg (>= 4.5:1 on all three).
            "accent_on_surface": rgb_to_hex(*accent_on_rgb),
            "secondary_on_surface": rgb_to_hex(*secondary_on_rgb),
            "tertiary_on_surface": rgb_to_hex(*tertiary_on_rgb),
        },
        "app": {
            "nvim": nvim_theme[0],
            "nvim_style": nvim_theme[1],
            "lualine": nvim_theme[0],
            "gtk_theme": "Adwaita-dark" if is_dark else "Adwaita",
            "gtk_icon": "Papirus-Dark" if is_dark else "Papirus-Light",
            "gnome_shell": "",
            "gnome_gtk": "Adwaita-dark" if is_dark else "Adwaita",
            "vscode": VSCODE_DARK if is_dark else VSCODE_LIGHT,
            "vscode_dark": VSCODE_DARK,
            "vscode_light": VSCODE_LIGHT,
            "vscode_icons": VSCODE_ICONS_DARK if is_dark else VSCODE_ICONS_LIGHT,
            "cat_wallpaper": "",
            "starship_palette": f"catppuccin_{'mocha' if is_dark else 'latte'}",
        },
    }


# ---------------------------------------------------------------------------
# TOML output
# ---------------------------------------------------------------------------

def theme_to_toml(theme: Dict) -> str:
    """Render a theme dict as TOML sections."""
    name = theme["name"]
    lines = []
    lines.append(f'[themes.{name}]')
    lines.append(f'mode = "{theme["mode"]}"')
    lines.append(f'family = "{theme["family"]}"')
    lines.append(f'macos_accent = {theme["macos_accent"]}')
    lines.append(f'wallpaper = "{theme["wallpaper"]}"')
    lines.append(f'source = "{theme["source"]}"')
    lines.append("")

    lines.append(f"[themes.{name}.term]")
    for key in ["bg", "fg", "cursor", "cursor_text", "sel_bg", "sel_fg"]:
        lines.append(f'{key} = "{theme["term"][key]}"')
    for i in range(16):
        key = f"c{i}"
        pad = " " * (4 - len(key))
        lines.append(f'{key}{pad}= "{theme["term"][key]}"')
    lines.append("")

    lines.append(f"[themes.{name}.ui]")
    for key in ["accent", "accent_text", "secondary", "tertiary", "text_muted",
                "accent_on_surface", "secondary_on_surface", "tertiary_on_surface",
                "error", "warning", "success", "info", "panel", "border"]:
        lines.append(f'{key} = "{theme["ui"][key]}"')
    lines.append("")

    lines.append(f"[themes.{name}.app]")
    for key, val in theme["app"].items():
        lines.append(f'{key} = "{val}"')

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def determine_mode(pixels: List[Tuple[int, int, int]]) -> bool:
    """Determine if image is dark (True) or light (False) from average luminance."""
    if not pixels:
        return True
    avg_lum = sum(relative_luminance(*p) for p in pixels) / len(pixels)
    return avg_lum < 0.35


def derive_name(image_path: str) -> str:
    """Derive a theme name from the image filename."""
    base = os.path.splitext(os.path.basename(image_path))[0]
    # Normalize: lowercase, replace spaces with hyphens, strip non-alphanum
    name = base.lower().replace(" ", "-").replace("_", "-")
    name = "".join(c for c in name if c.isalnum() or c == "-")
    # Remove consecutive hyphens
    while "--" in name:
        name = name.replace("--", "-")
    return name.strip("-")


def main():
    import argparse

    parser = argparse.ArgumentParser(
        description="Extract a terminal theme from a wallpaper image."
    )
    parser.add_argument("image", help="Path to wallpaper image")
    parser.add_argument("--name", help="Theme name (default: derived from filename)")
    parser.add_argument("--format", choices=["toml", "json"], default="toml")
    parser.add_argument("--clusters", type=int, default=8, help="Number of K-Means clusters")
    parser.add_argument("--source", choices=["system", "custom"], default="custom", help="Wallpaper source type")
    args = parser.parse_args()

    # Extract pixels
    try:
        pixels = extract_pixels(args.image)
    except FileNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
    if not pixels:
        print("Error: no pixels extracted", file=sys.stderr)
        sys.exit(1)

    # Derive name
    name = args.name or derive_name(args.image)

    # Determine dark/light: trust name suffix if present, else detect from pixels
    if name.endswith("-dark"):
        is_dark = True
    elif name.endswith("-light"):
        is_dark = False
    else:
        is_dark = determine_mode(pixels)
        name += "-dark" if is_dark else "-light"

    # Subsample for speed — 2000 pixels is enough for accurate K-Means
    if len(pixels) > 2000:
        rng = random.Random(42)  # nosec B311 — deterministic sampling
        pixels = rng.sample(pixels, 2000)

    # Convert to CIELAB
    lab_pixels = [rgb_to_lab(*p) for p in pixels]

    # Filter near-black and near-white to avoid muddy palettes
    filtered = [p for p in lab_pixels if 5 < p[0] < 95]
    if len(filtered) < len(lab_pixels) * 0.1:
        filtered = lab_pixels  # Image is mostly black/white, use all

    # K-Means clustering
    clusters = kmeans_lab(filtered, k=args.clusters, runs=3)

    # Generate theme
    theme = generate_theme(clusters, name, is_dark)
    wp_base = args.image.split("[")[0] if "[" in args.image else args.image
    wp_abs = os.path.abspath(wp_base)
    # Store home-relative with a `~` so the committed themes.toml is not tied to
    # one machine's username. Consumers (wallpaper-sync.sh) expand `~/`. System
    # wallpapers (/System/..., /usr/share/...) stay absolute — identical on
    # every host anyway.
    home = os.path.expanduser("~")
    if wp_abs == home or wp_abs.startswith(home + os.sep):
        wp_abs = "~" + wp_abs[len(home):]
    theme["wallpaper"] = wp_abs
    theme["source"] = args.source

    # Output
    if args.format == "json":
        print(json.dumps(theme, indent=2))
    else:
        print(theme_to_toml(theme))


if __name__ == "__main__":
    main()
