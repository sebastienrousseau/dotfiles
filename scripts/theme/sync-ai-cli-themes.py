#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Align installed AI CLI themes with the active wallpaper palette."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import tempfile
from collections.abc import Callable
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

import tomllib

MISSING_HASH = "missing"


class ConcurrentModificationError(RuntimeError):
    """Raised when a provider file changes between discovery and commit."""


@dataclass(frozen=True)
class AdapterResult:
    provider: str
    target: str
    status: str
    detail: str = ""


def content_hash(path: Path) -> str:
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except FileNotFoundError:
        return MISSING_HASH


def atomic_text(path: Path, content: str, *, expected_hash: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(tmp_name, path.stat().st_mode & 0o777 if path.exists() else 0o600)
        if content_hash(path) != expected_hash:
            raise ConcurrentModificationError(f"{path} changed before commit")
        os.replace(tmp_name, path)
        try:
            directory_fd = os.open(path.parent, os.O_RDONLY)
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
        except OSError:
            # Directory fsync is unavailable on some Windows filesystems.
            pass
    finally:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass


def merge_json(
    provider: str, path: Path, patch: dict[str, Any], *, create: bool = False
) -> AdapterResult:
    if not path.exists() and not create:
        return AdapterResult(provider, str(path), "not_installed")
    data: dict[str, Any] = {}
    before_hash = content_hash(path)
    if path.exists():
        try:
            loaded = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(loaded, dict):
                return AdapterResult(
                    provider, str(path), "invalid_config", "root must be an object"
                )
            data = loaded
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            return AdapterResult(
                provider, str(path), "invalid_config", error.__class__.__name__
            )

    def merge(target: dict[str, Any], incoming: dict[str, Any]) -> None:
        for key, value in incoming.items():
            if isinstance(value, dict) and isinstance(target.get(key), dict):
                merge(target[key], value)
            else:
                target[key] = value

    before = json.dumps(data, sort_keys=True)
    merge(data, patch)
    if json.dumps(data, sort_keys=True) == before:
        return AdapterResult(provider, str(path), "unchanged")
    try:
        atomic_text(
            path,
            json.dumps(data, indent=2, ensure_ascii=False) + "\n",
            expected_hash=before_hash,
        )
    except ConcurrentModificationError:
        return AdapterResult(provider, str(path), "conflict", "changed before commit")
    except OSError as error:
        return AdapterResult(
            provider, str(path), "write_failed", error.__class__.__name__
        )
    return AdapterResult(provider, str(path), "updated")


def set_codex_theme(path: Path, theme_path: Path) -> AdapterResult:
    provider = "codex"
    if not theme_path.exists():
        return AdapterResult(
            provider, str(path), "not_installed", "theme not installed"
        )
    if not path.exists():
        return AdapterResult(provider, str(path), "not_installed")
    before_hash = content_hash(path)
    try:
        text = path.read_text(encoding="utf-8")
        # Validate the complete document before performing a format-preserving
        # edit. A malformed user-owned file is never rewritten.
        tomllib.loads(text)
    except (OSError, UnicodeError, tomllib.TOMLDecodeError) as error:
        return AdapterResult(
            provider, str(path), "invalid_config", error.__class__.__name__
        )
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
    if rendered == text:
        return AdapterResult(provider, str(path), "unchanged")
    try:
        atomic_text(path, rendered, expected_hash=before_hash)
    except ConcurrentModificationError:
        return AdapterResult(provider, str(path), "conflict", "changed before commit")
    except OSError as error:
        return AdapterResult(
            provider, str(path), "write_failed", error.__class__.__name__
        )
    return AdapterResult(provider, str(path), "updated")


def read_toml(path: Path | None) -> dict[str, Any]:
    if path is None or not path.exists():
        return {}
    try:
        with path.open("rb") as handle:
            loaded = tomllib.load(handle)
        return loaded if isinstance(loaded, dict) else {}
    except (OSError, tomllib.TOMLDecodeError):
        return {}


def feature_policy(
    defaults_path: Path | None, machine_path: Path | None
) -> tuple[bool, dict[str, bool]]:
    defaults = read_toml(defaults_path).get("features", {})
    machine_data = read_toml(machine_path).get("data", {})
    machine = machine_data.get("features", {}) if isinstance(machine_data, dict) else {}
    if not isinstance(defaults, dict):
        defaults = {}
    if not isinstance(machine, dict):
        machine = {}

    enabled = defaults.get("ai_theme_sync", True)
    if isinstance(machine.get("ai_theme_sync"), bool):
        enabled = machine["ai_theme_sync"]

    provider_policy: dict[str, bool] = {}
    default_providers = defaults.get("ai_theme_providers", {})
    machine_providers = machine.get("ai_theme_providers", {})
    if isinstance(default_providers, dict):
        provider_policy.update(
            {
                key: value
                for key, value in default_providers.items()
                if isinstance(value, bool)
            }
        )
    if isinstance(machine_providers, dict):
        provider_policy.update(
            {
                key: value
                for key, value in machine_providers.items()
                if isinstance(value, bool)
            }
        )
    return bool(enabled), provider_policy


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--theme", required=True)
    parser.add_argument("--themes-file", type=Path, required=True)
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--defaults-config", type=Path)
    parser.add_argument("--machine-config", type=Path)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    with args.themes_file.open("rb") as handle:
        themes = tomllib.load(handle).get("themes", {})
    palette = themes.get(args.theme)
    if not isinstance(palette, dict):
        parser.error(f"unknown theme: {args.theme}")
    mode = palette.get("mode", "dark")
    ansi_theme = "ANSI Light" if mode == "light" else "ANSI"
    home = args.home.expanduser()
    enabled, provider_policy = feature_policy(args.defaults_config, args.machine_config)
    results: list[AdapterResult] = []

    def run(provider: str, target: Path, callback: Callable[[], AdapterResult]) -> None:
        if not enabled or not provider_policy.get(provider, True):
            results.append(AdapterResult(provider, str(target), "disabled"))
            return
        results.append(callback())

    codex_theme = home / ".codex/themes/dotfiles.tmTheme"
    codex_config = home / ".codex/config.toml"
    run("codex", codex_config, lambda: set_codex_theme(codex_config, codex_theme))

    claude_config = home / ".claude/settings.json"
    run(
        "claude",
        claude_config,
        lambda: merge_json("claude", claude_config, {"theme": "auto"}),
    )

    gemini_config = home / ".gemini/settings.json"
    run(
        "gemini",
        gemini_config,
        lambda: merge_json(
            "gemini",
            gemini_config,
            {"ui": {"theme": ansi_theme, "autoThemeSwitching": False}},
        ),
    )

    agy_config = home / ".gemini/antigravity-cli/settings.json"
    run(
        "agy",
        agy_config,
        lambda: merge_json("agy", agy_config, {"colorScheme": "terminal"}),
    )

    qwen_config = home / ".qwen/settings.json"
    run(
        "qwen",
        qwen_config,
        lambda: merge_json("qwen", qwen_config, {"ui": {"theme": ansi_theme}}),
    )

    opencode_dir = home / ".config/opencode"
    opencode_config = opencode_dir / "cli.json"
    if opencode_dir.is_dir():
        run(
            "opencode",
            opencode_config,
            lambda: merge_json(
                "opencode",
                opencode_config,
                {
                    "$schema": "https://opencode.ai/v2/cli.json",
                    "theme": {"name": "system", "mode": mode},
                },
                create=True,
            ),
        )
    else:
        results.append(AdapterResult("opencode", str(opencode_config), "not_installed"))

    if args.json:
        print(
            json.dumps(
                {
                    "schema_version": "1.0",
                    "theme": args.theme,
                    "mode": mode,
                    "providers": [asdict(result) for result in results],
                },
                separators=(",", ":"),
            )
        )
    else:
        applied = [
            result.provider
            for result in results
            if result.status in {"updated", "unchanged"}
        ]
        print(",".join(applied))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
