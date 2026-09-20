#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Align installed AI CLI themes with the active wallpaper palette."""

from __future__ import annotations

import argparse
import json
import os
import re
import tempfile
from pathlib import Path
from typing import Any

import tomllib


def atomic_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(content)
        os.chmod(tmp_name, path.stat().st_mode & 0o777 if path.exists() else 0o600)
        os.replace(tmp_name, path)
    finally:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass


def merge_json(path: Path, patch: dict[str, Any], *, create: bool = False) -> bool:
    if not path.exists() and not create:
        return False
    data: dict[str, Any] = {}
    if path.exists():
        try:
            loaded = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(loaded, dict):
                return False
            data = loaded
        except (OSError, json.JSONDecodeError):
            return False

    def merge(target: dict[str, Any], incoming: dict[str, Any]) -> None:
        for key, value in incoming.items():
            if isinstance(value, dict) and isinstance(target.get(key), dict):
                merge(target[key], value)
            else:
                target[key] = value

    before = json.dumps(data, sort_keys=True)
    merge(data, patch)
    if json.dumps(data, sort_keys=True) == before:
        return True
    atomic_text(path, json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    return True


def set_codex_theme(path: Path) -> bool:
    if not path.exists():
        return False
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    section_index = next(
        (i for i, line in enumerate(lines) if line.strip() == "[tui]"), None
    )
    child_index = next(
        (i for i, line in enumerate(lines) if re.match(r"^\[tui\.", line.strip())), None
    )

    if section_index is None:
        insert_at = child_index if child_index is not None else len(lines)
        block = ["[tui]", 'theme = "dotfiles"', ""]
        if insert_at and lines[insert_at - 1].strip():
            block.insert(0, "")
        lines[insert_at:insert_at] = block
    else:
        end = next(
            (
                i
                for i in range(section_index + 1, len(lines))
                if lines[i].lstrip().startswith("[")
            ),
            len(lines),
        )
        theme_index = next(
            (
                i
                for i in range(section_index + 1, end)
                if re.match(r"^\s*theme\s*=", lines[i])
            ),
            None,
        )
        if theme_index is None:
            lines.insert(section_index + 1, 'theme = "dotfiles"')
        else:
            lines[theme_index] = 'theme = "dotfiles"'

    rendered = "\n".join(lines).rstrip() + "\n"
    if rendered != text:
        atomic_text(path, rendered)
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--theme", required=True)
    parser.add_argument("--themes-file", type=Path, required=True)
    parser.add_argument("--home", type=Path, default=Path.home())
    args = parser.parse_args()

    with args.themes_file.open("rb") as handle:
        themes = tomllib.load(handle).get("themes", {})
    palette = themes.get(args.theme)
    if not isinstance(palette, dict):
        parser.error(f"unknown theme: {args.theme}")
    mode = palette.get("mode", "dark")
    ansi_theme = "ANSI Light" if mode == "light" else "ANSI"
    home = args.home.expanduser()
    updated: list[str] = []

    codex_theme = home / ".codex/themes/dotfiles.tmTheme"
    if codex_theme.exists() and set_codex_theme(home / ".codex/config.toml"):
        updated.append("codex")

    if merge_json(home / ".claude/settings.json", {"theme": "auto"}):
        updated.append("claude")

    if merge_json(
        home / ".gemini/settings.json",
        {"ui": {"theme": ansi_theme, "autoThemeSwitching": False}},
    ):
        updated.append("gemini")

    if merge_json(
        home / ".gemini/antigravity-cli/settings.json",
        {"colorScheme": "terminal"},
    ):
        updated.append("agy")

    if merge_json(home / ".qwen/settings.json", {"ui": {"theme": ansi_theme}}):
        updated.append("qwen")

    opencode_dir = home / ".config/opencode"
    if opencode_dir.is_dir() and merge_json(
        opencode_dir / "cli.json",
        {
            "$schema": "https://opencode.ai/v2/cli.json",
            "theme": {"name": "system", "mode": mode},
        },
        create=True,
    ):
        updated.append("opencode")

    print(",".join(updated))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
