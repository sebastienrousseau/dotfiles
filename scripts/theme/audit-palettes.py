#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Audit the generated terminal palette catalog against measurable contracts."""

from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import math
import re
import sys
from pathlib import Path
from typing import Any

import tomllib

SCHEMA_VERSION = "1.0"
HEX_COLOR = re.compile(r"^#[0-9a-fA-F]{6}$")
ANSI_CHROMATIC = tuple(range(1, 7)) + tuple(range(9, 15))
SEMANTIC_ROLES = ("error", "warning", "success", "info")
SUPPORT_ROLES = ("accent", "secondary", "tertiary")
SURFACE_TEXT_ROLES = (
    "accent_on_surface",
    "secondary_on_surface",
    "tertiary_on_surface",
)

# Full-severity approximations used as deterministic regression simulations.
# They are not medical diagnostics; they ensure semantic roles do not collapse
# to the same rendered colour under common protan/deutan/tritan transforms.
CVD_MATRICES = {
    "protan": (
        (0.56667, 0.43333, 0.0),
        (0.55833, 0.44167, 0.0),
        (0.0, 0.24167, 0.75833),
    ),
    "deutan": (
        (0.625, 0.375, 0.0),
        (0.7, 0.3, 0.0),
        (0.0, 0.3, 0.7),
    ),
    "tritan": (
        (0.95, 0.05, 0.0),
        (0.0, 0.43333, 0.56667),
        (0.0, 0.475, 0.525),
    ),
}

_XTERM_BASE = (
    (0, 0, 0),
    (128, 0, 0),
    (0, 128, 0),
    (128, 128, 0),
    (0, 0, 128),
    (128, 0, 128),
    (0, 128, 128),
    (192, 192, 192),
    (128, 128, 128),
    (255, 0, 0),
    (0, 255, 0),
    (255, 255, 0),
    (0, 0, 255),
    (255, 0, 255),
    (0, 255, 255),
    (255, 255, 255),
)
_XTERM_LEVELS = (0, 95, 135, 175, 215, 255)
XTERM_256 = (
    _XTERM_BASE
    + tuple(
        (red, green, blue)
        for red in _XTERM_LEVELS
        for green in _XTERM_LEVELS
        for blue in _XTERM_LEVELS
    )
    + tuple((8 + 10 * index,) * 3 for index in range(24))
)


def hex_rgb(value: str) -> tuple[int, int, int]:
    if not HEX_COLOR.fullmatch(value):
        raise ValueError(f"invalid colour: {value!r}")
    return tuple(int(value[index : index + 2], 16) for index in (1, 3, 5))


def linear(component: float) -> float:
    component /= 255.0
    if component <= 0.04045:
        return component / 12.92
    return ((component + 0.055) / 1.055) ** 2.4


def luminance(rgb: tuple[int, int, int]) -> float:
    red, green, blue = (linear(component) for component in rgb)
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue


def contrast(left: tuple[int, int, int], right: tuple[int, int, int]) -> float:
    high, low = sorted((luminance(left), luminance(right)), reverse=True)
    return (high + 0.05) / (low + 0.05)


def rgb_lab(rgb: tuple[int, int, int]) -> tuple[float, float, float]:
    red, green, blue = (linear(component) for component in rgb)
    x = 0.4124564 * red + 0.3575761 * green + 0.1804375 * blue
    y = 0.2126729 * red + 0.7151522 * green + 0.0721750 * blue
    z = 0.0193339 * red + 0.1191920 * green + 0.9503041 * blue

    def transform(value: float) -> float:
        if value > 0.008856:
            return value ** (1.0 / 3.0)
        return 7.787 * value + 16.0 / 116.0

    fx = transform(x / 0.95047)
    fy = transform(y)
    fz = transform(z / 1.08883)
    return 116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz)


def delta_e(left: tuple[int, int, int], right: tuple[int, int, int]) -> float:
    return math.sqrt(
        sum(
            (left_component - right_component) ** 2
            for left_component, right_component in zip(
                rgb_lab(left), rgb_lab(right), strict=True
            )
        )
    )


def simulate_cvd(
    rgb: tuple[int, int, int],
    matrix: tuple[tuple[float, float, float], ...],
) -> tuple[int, int, int]:
    normalized = tuple(component / 255.0 for component in rgb)
    return tuple(
        round(
            255
            * max(
                0.0,
                min(
                    1.0,
                    sum(
                        matrix[row][column] * normalized[column] for column in range(3)
                    ),
                ),
            )
        )
        for row in range(3)
    )


def nearest_xterm(rgb: tuple[int, int, int]) -> tuple[int, int, int]:
    return min(
        XTERM_256,
        key=lambda candidate: sum(
            (candidate[channel] - rgb[channel]) ** 2 for channel in range(3)
        ),
    )


def minimum_pair_distance(colors: list[tuple[int, int, int]]) -> float:
    return min(
        delta_e(left, right) for left, right in itertools.combinations(colors, 2)
    )


def rounded(value: float) -> float:
    return round(value, 3)


def audit_theme(name: str, theme: dict[str, Any]) -> dict[str, Any]:
    failures: list[dict[str, Any]] = []

    def require(check: str, actual: float, minimum: float) -> None:
        if actual + 1e-9 < minimum:
            failures.append(
                {"check": check, "actual": rounded(actual), "minimum": minimum}
            )

    try:
        mode = theme["mode"]
        if mode not in {"dark", "light"}:
            raise ValueError(f"invalid mode: {mode!r}")
        term = theme["term"]
        ui = theme["ui"]
        background = hex_rgb(term["bg"])
        foreground = hex_rgb(term["fg"])
        accent_text = hex_rgb(ui["accent_text"])
        panel = hex_rgb(ui["panel"])
        border = hex_rgb(ui["border"])

        text_contrast = contrast(foreground, background)
        selection_contrast = contrast(hex_rgb(term["sel_fg"]), hex_rgb(term["sel_bg"]))
        focus_contrast = min(
            contrast(hex_rgb(ui["accent"]), background),
            contrast(hex_rgb(term["cursor"]), background),
        )
        status_text_contrast = min(
            contrast(accent_text, hex_rgb(ui[role])) for role in SEMANTIC_ROLES
        )
        surface_text_contrast = min(
            contrast(hex_rgb(ui[role]), surface)
            for role in SURFACE_TEXT_ROLES
            for surface in (background, panel, border)
        )
        muted_text_contrast = min(
            contrast(hex_rgb(ui["text_muted"]), surface) for surface in (panel, border)
        )
        ansi_colors = [hex_rgb(term[f"c{index}"]) for index in ANSI_CHROMATIC]
        ansi_truecolor_contrast = min(
            contrast(color, background) for color in ansi_colors
        )
        mapped_background = nearest_xterm(background)
        ansi_256_contrast = min(
            contrast(nearest_xterm(color), mapped_background) for color in ansi_colors
        )
        support_distance = minimum_pair_distance(
            [hex_rgb(ui[role]) for role in SUPPORT_ROLES]
        )
        cvd_distances = {
            vision: minimum_pair_distance(
                [simulate_cvd(hex_rgb(ui[role]), matrix) for role in SEMANTIC_ROLES]
            )
            for vision, matrix in CVD_MATRICES.items()
        }
        semantic_cvd_distance = min(cvd_distances.values())

        metrics = {
            "text_contrast": rounded(text_contrast),
            "status_text_contrast": rounded(status_text_contrast),
            "focus_contrast": rounded(focus_contrast),
            "selection_contrast": rounded(selection_contrast),
            "surface_text_contrast": rounded(surface_text_contrast),
            "muted_text_contrast": rounded(muted_text_contrast),
            "ansi_truecolor_contrast": rounded(ansi_truecolor_contrast),
            "ansi_256_contrast": rounded(ansi_256_contrast),
            "support_delta_e": rounded(support_distance),
            "semantic_cvd_delta_e": rounded(semantic_cvd_distance),
            "semantic_cvd": {
                vision: rounded(value)
                for vision, value in sorted(cvd_distances.items())
            },
        }

        require("text_contrast", text_contrast, 7.0)
        require("status_text_contrast", status_text_contrast, 7.0)
        require("focus_contrast", focus_contrast, 3.0)
        require("selection_contrast", selection_contrast, 4.5)
        require("surface_text_contrast", surface_text_contrast, 4.5)
        require("muted_text_contrast", muted_text_contrast, 4.5)
        require(
            "ansi_truecolor_contrast",
            ansi_truecolor_contrast,
            4.5 if mode == "dark" else 7.0,
        )
        require("ansi_256_contrast", ansi_256_contrast, 4.5)
        require("support_delta_e", support_distance, 18.0)
        require("semantic_cvd_delta_e", semantic_cvd_distance, 8.0)
    except (KeyError, TypeError, ValueError) as error:
        mode = str(theme.get("mode", "unknown"))
        metrics = {}
        failures.append(
            {
                "check": "schema",
                "actual": str(error),
                "minimum": "complete valid palette",
            }
        )

    return {
        "theme": name,
        "mode": mode,
        "passed": not failures,
        "metrics": metrics,
        "failures": failures,
    }


def build_report(path: Path, selected_theme: str | None) -> dict[str, Any]:
    raw = path.read_bytes()
    catalog = tomllib.loads(raw.decode("utf-8"))
    themes = catalog.get("themes", {})
    if not isinstance(themes, dict):
        raise TypeError("catalog does not contain a [themes] table")
    if selected_theme is not None:
        if selected_theme not in themes:
            raise ValueError(f"unknown theme: {selected_theme}")
        themes = {selected_theme: themes[selected_theme]}

    results = [
        audit_theme(name, theme)
        for name, theme in sorted(themes.items())
        if isinstance(theme, dict) and "term" in theme
    ]
    failure_count = sum(len(result["failures"]) for result in results)
    return {
        "schema_version": SCHEMA_VERSION,
        "catalog": str(path),
        "catalog_sha256": hashlib.sha256(raw).hexdigest(),
        "summary": {
            "themes": len(results),
            "passed": sum(result["passed"] for result in results),
            "failed": sum(not result["passed"] for result in results),
            "failures": failure_count,
        },
        "results": results,
    }


def print_human(report: dict[str, Any]) -> None:
    summary = report["summary"]
    for result in report["results"]:
        for failure in result["failures"]:
            print(
                f"FAIL {result['theme']} {failure['check']}: "
                f"{failure['actual']} < {failure['minimum']}"
            )
    print(
        "Palette audit: "
        f"{summary['passed']}/{summary['themes']} themes passed; "
        f"{summary['failures']} contract failure(s)"
    )


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(
        description="Audit terminal palettes for contrast and perceptual separation."
    )
    parser.add_argument(
        "catalog",
        nargs="?",
        type=Path,
        default=repo_root / "defaults/.chezmoidata/themes.toml",
    )
    parser.add_argument("--theme", help="audit one named theme")
    parser.add_argument(
        "--json", action="store_true", help="emit the versioned JSON report"
    )
    args = parser.parse_args()

    try:
        report = build_report(args.catalog, args.theme)
    except (
        OSError,
        TypeError,
        UnicodeError,
        tomllib.TOMLDecodeError,
        ValueError,
    ) as error:
        parser.error(str(error))

    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print_human(report)
    return 1 if report["summary"]["failures"] else 0


if __name__ == "__main__":
    sys.exit(main())
