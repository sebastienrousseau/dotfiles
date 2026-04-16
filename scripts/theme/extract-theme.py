#!/usr/bin/env python3
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
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

def kmeans_lab(
    pixels: List[Tuple[float, float, float]],
    k: int = 8,
    max_iter: int = 20,
    runs: int = 3,
) -> List[Tuple[Tuple[float, float, float], int]]:
    """K-Means clustering in CIELAB space.

    Returns list of (centroid_lab, population) sorted by population descending.
    Multiple runs with different seeds; best (lowest inertia) is kept.
    """
    n = len(pixels)
    if n == 0:
        return []

    best_centroids = None
    best_labels = None
    best_inertia = float("inf")

    for run_idx in range(runs):
        # K-Means++ initialization (deterministic seeding for reproducibility)
        rng = random.Random(run_idx * 42 + 7)  # nosec B311
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

        labels = [0] * n
        for _ in range(max_iter):
            # Assign pixels to nearest centroid
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

            if changed == 0:
                break

            # Update centroids
            for j, _ in enumerate(centroids):
                members = [pixels[i] for i in range(n) if labels[i] == j]
                if members:
                    centroids[j] = tuple(
                        sum(m[d] for m in members) / len(members) for d in range(3)
                    )

        # Compute inertia
        inertia = sum(lab_distance(pixels[i], centroids[labels[i]]) ** 2 for i in range(n))
        if inertia < best_inertia:
            best_inertia = inertia
            best_centroids = centroids[:]
            best_labels = labels[:]

    # Count populations
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
    # nosec B603 — cmd is a fixed list with validated image_path, no shell
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
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


def _nvim_from_hue(hue: float, is_dark: bool) -> Tuple[str, str]:
    """Map accent hue angle to nearest Neovim colorscheme."""
    if 60 <= hue < 150:
        return ("everforest", "hard" if is_dark else "soft")
    if 210 <= hue < 270:
        return ("tokyonight", "night" if is_dark else "day")
    return ("catppuccin", "mocha" if is_dark else "latte")


def _macos_accent_from_hue(hue: float) -> int:
    """Map accent hue angle to macOS accent color integer."""
    if hue < 30 or hue >= 345:
        return 0   # Red
    if hue < 60:
        return 1   # Orange
    if hue < 105:
        return 2   # Yellow
    if hue < 165:
        return 3   # Green
    if hue < 255:
        return 4   # Blue
    if hue < 300:
        return 5   # Purple
    return 6       # Pink


def generate_theme(
    clusters: List[Tuple[Tuple[float, float, float], int]],
    name: str,
    is_dark: bool,
) -> Dict:
    """Generate a full theme definition from clustered dominant colors."""
    # Separate clusters by lightness
    sorted_by_L = sorted(clusters, key=lambda c: c[0][0])
    sorted_by_chroma = sorted(clusters, key=lambda c: lab_chroma(*c[0]), reverse=True)

    # Background: darkest cluster for dark mode, lightest for light mode
    if is_dark:
        bg_lab = sorted_by_L[0][0]
        # Ensure bg is sufficiently dark
        bg_lab = (min(bg_lab[0], 15.0), bg_lab[1] * 0.3, bg_lab[2] * 0.3)
    else:
        bg_lab = sorted_by_L[-1][0]
        # Ensure bg is sufficiently light
        bg_lab = (max(bg_lab[0], 92.0), bg_lab[1] * 0.15, bg_lab[2] * 0.15)

    bg_rgb = lab_to_rgb(*bg_lab)

    # Foreground: high contrast against bg
    if is_dark:
        fg_lab = (88.0, bg_lab[1] * 0.1, bg_lab[2] * 0.1)
    else:
        fg_lab = (18.0, bg_lab[1] * 0.15, bg_lab[2] * 0.15)
    fg_rgb = ensure_contrast(lab_to_rgb(*fg_lab), bg_rgb, 7.0, is_dark)

    # Accent: most saturated cluster
    accent_lab = sorted_by_chroma[0][0]
    if is_dark:
        accent_lab = (max(accent_lab[0], 35.0), accent_lab[1], accent_lab[2])
    else:
        accent_lab = (min(accent_lab[0], 45.0), accent_lab[1], accent_lab[2])
    accent_rgb = lab_to_rgb(*accent_lab)
    # Darken accent until white text has 7:1 contrast (AAA)
    _al, _aa, _ab = accent_lab
    for _ in range(80):
        if contrast_ratio((255, 255, 255), lab_to_rgb(_al, _aa, _ab)) >= 7.0:
            break
        _al = max(0.0, _al - 2.0)
    accent_lab = (_al, _aa, _ab)
    accent_rgb = lab_to_rgb(*accent_lab)
    accent_text = (255, 255, 255)

    # Cursor
    cursor_rgb = accent_rgb

    # Selection background
    if is_dark:
        sel_lab = (bg_lab[0] + 15, accent_lab[1] * 0.4, accent_lab[2] * 0.4)
    else:
        sel_lab = (bg_lab[0] - 12, accent_lab[1] * 0.3, accent_lab[2] * 0.3)
    sel_rgb = lab_to_rgb(*sel_lab)

    # Panel (slightly darker/lighter than bg, within 1.03-2.0 contrast)
    if is_dark:
        # Dark bg: panel should be slightly lighter for subtle contrast
        panel_lab = (min(bg_lab[0] + 3, 100), bg_lab[1], bg_lab[2])
    else:
        panel_lab = (max(bg_lab[0] - 3, 0), bg_lab[1], bg_lab[2])
    panel_rgb = lab_to_rgb(*panel_lab)
    # Ensure panel/bg is within 1.03-2.0 range
    for _ in range(20):
        pr = contrast_ratio(panel_rgb, bg_rgb)
        if 1.03 <= pr <= 2.0:
            break
        if pr < 1.03:
            panel_lab = (panel_lab[0] + (2 if is_dark else -2), panel_lab[1], panel_lab[2])
        else:
            panel_lab = (panel_lab[0] + (-1 if is_dark else 1), panel_lab[1], panel_lab[2])
        panel_lab = (max(0, min(100, panel_lab[0])), panel_lab[1], panel_lab[2])
        panel_rgb = lab_to_rgb(*panel_lab)

    # Border
    if is_dark:
        border_lab = (bg_lab[0] + 8, bg_lab[1] * 0.5, bg_lab[2] * 0.5)
    else:
        border_lab = (bg_lab[0] - 6, bg_lab[1] * 0.3, bg_lab[2] * 0.3)
    border_rgb = lab_to_rgb(*border_lab)

    # --- Generate 16 ANSI colors ---
    # Use dominant colors mapped to nearest ANSI hue slots
    chromatic_clusters = [
        (c, pop) for c, pop in clusters if lab_chroma(*c) > 10
    ]

    # Assign each chromatic cluster to its nearest ANSI hue
    hue_assignments: Dict[str, List[Tuple[float, float, float]]] = {
        h: [] for h in ANSI_HUES
    }
    for c_lab, _ in chromatic_clusters:
        hue = lab_hue(*c_lab)
        nearest = find_nearest_hue(hue)
        hue_assignments[nearest].append(c_lab)

    # Build ANSI colors
    ansi = {}
    for hue_name, target_hue in ANSI_HUES.items():
        candidates = hue_assignments[hue_name]
        if candidates:
            # Use the most chromatic candidate
            base = max(candidates, key=lambda c: lab_chroma(*c))
        else:
            # Synthesize from accent chroma projected to target hue
            accent_chroma = lab_chroma(*accent_lab)
            new_a = accent_chroma * math.cos(math.radians(target_hue))
            new_b = accent_chroma * math.sin(math.radians(target_hue))
            base = (50.0, new_a, new_b)

        # Normal variant (c1-c6 range)
        if is_dark:
            normal_L = max(55.0, min(75.0, base[0]))
        else:
            normal_L = max(30.0, min(50.0, base[0]))
        normal = adjust_lightness(base, normal_L)
        normal_rgb = ensure_contrast(lab_to_rgb(*normal), bg_rgb, 3.0, is_dark)

        # Bright variant (c9-c14 range)
        if is_dark:
            bright_L = normal_L + 12
        else:
            bright_L = normal_L - 8
        bright = adjust_lightness(base, bright_L)
        bright_rgb = ensure_contrast(lab_to_rgb(*bright), bg_rgb, 4.5, is_dark)

        ansi[hue_name] = (normal_rgb, bright_rgb)

    # c0 (black) and c7 (white) — structural colors
    if is_dark:
        c0_rgb = ensure_contrast(lab_to_rgb(bg_lab[0] + 10, bg_lab[1], bg_lab[2]), bg_rgb, 1.5, True)
        c7_rgb = ensure_contrast(lab_to_rgb(75.0, bg_lab[1] * 0.1, bg_lab[2] * 0.1), bg_rgb, 5.0, True)
        c8_rgb = ensure_contrast(lab_to_rgb(bg_lab[0] + 25, bg_lab[1], bg_lab[2]), bg_rgb, 2.5, True)
        c15_rgb = ensure_contrast(lab_to_rgb(90.0, bg_lab[1] * 0.05, bg_lab[2] * 0.05), bg_rgb, 7.0, True)
    else:
        c0_rgb = ensure_contrast(lab_to_rgb(18.0, bg_lab[1] * 0.2, bg_lab[2] * 0.2), bg_rgb, 7.0, False)
        c7_rgb = ensure_contrast(lab_to_rgb(bg_lab[0] - 8, bg_lab[1], bg_lab[2]), bg_rgb, 1.3, False)
        c8_rgb = ensure_contrast(lab_to_rgb(35.0, bg_lab[1] * 0.2, bg_lab[2] * 0.2), bg_rgb, 4.5, False)
        c15_rgb = ensure_contrast(lab_to_rgb(8.0, 0, 0), bg_rgb, 10.0, False)

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
            "error": rgb_to_hex(*ansi["red"][0]),
            "warning": rgb_to_hex(*ansi["yellow"][0]),
            "success": rgb_to_hex(*ansi["green"][0]),
            "info": rgb_to_hex(*ansi["blue"][0]),
            "panel": rgb_to_hex(*panel_rgb),
            "border": rgb_to_hex(*border_rgb),
        },
        "app": {
            "nvim": nvim_theme[0],
            "nvim_style": nvim_theme[1],
            "lualine": nvim_theme[0],
            "gtk_theme": "Adwaita-dark" if is_dark else "Adwaita",
            "gtk_icon": "Papirus-Dark" if is_dark else "Papirus-Light",
            "gnome_shell": "",
            "gnome_gtk": "Adwaita-dark" if is_dark else "Adwaita",
            "vscode": f"{nvim_theme[0].replace('-', ' ').title()} {'Mocha' if is_dark else 'Latte'}",
            "vscode_dark": f"{nvim_theme[0].replace('-', ' ').title()} Mocha",
            "vscode_light": f"{nvim_theme[0].replace('-', ' ').title()} Latte",
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
    for key in ["accent", "accent_text", "error", "warning", "success", "info", "panel", "border"]:
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
    theme["wallpaper"] = os.path.abspath(wp_base)
    theme["source"] = args.source

    # Output
    if args.format == "json":
        print(json.dumps(theme, indent=2))
    else:
        print(theme_to_toml(theme))


if __name__ == "__main__":
    main()
