#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Freeze real chezmoi render outputs without applying workstation configuration."""

from __future__ import annotations

import argparse
import difflib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
GOLDENS = REPO / "tests/fixtures/theme-render"
CONSUMERS = {
    "ghostty": "dot_config/ghostty/config.tmpl",
    "kitty": "dot_config/kitty/kitty.conf.tmpl",
    "alacritty": "dot_config/alacritty/alacritty.toml.tmpl",
    "wezterm": "dot_config/wezterm/wezterm.lua.tmpl",
    "foot": "dot_config/foot/foot.ini.tmpl",
    "tmux": "dot_config/tmux/tmux.conf.tmpl",
}
THEMES = ("maui-dark", "maui-light", "berlin-dark", "berlin-light")
PLATFORMS = ("darwin", "linux", "wsl")


def fixture_data(theme: str, platform: str) -> dict:
    """Fix every host-dependent input used by these six templates."""
    return {
        "dotfiles_version": "0.0.0",
        "theme": theme,
        "theme_family": theme.rsplit("-", 1)[0],
        "theme_mode": theme.rsplit("-", 1)[1],
        "terminal_font_family": "JetBrainsMono Nerd Font",
        "terminal_font_size": 20,
        "default_shell": "bash",
        "features": {"linux_desktop": platform == "linux", "niri": False},
        "chezmoi": {
            "os": "linux" if platform == "wsl" else platform,
            "arch": "amd64",
            "homeDir": "/DOT_HOME",
            "sourceDir": "/DOT_SOURCE",
            "username": "dot-fixture",
            "hostname": "dot-host",
            "kernel": {
                "osrelease": "microsoft-standard-WSL2"
                if platform == "wsl"
                else "fixture"
            },
        },
    }


def render_all(chezmoi: str) -> dict[str, str]:
    result = {}
    with tempfile.TemporaryDirectory(prefix="dot-theme-render-") as temporary:
        work = Path(temporary)
        source = work / "source"
        source.mkdir()
        # Copy only trusted render inputs. No user's config, hooks, externals,
        # secrets, or source checkout mutation participates in the fixture.
        (source / ".chezmoidata").mkdir()
        (source / ".chezmoitemplates").mkdir()
        shutil.copyfile(
            REPO / "defaults/.chezmoidata/themes.toml",
            source / ".chezmoidata/themes.toml",
        )
        shutil.copyfile(
            REPO / "defaults/.chezmoitemplates/theme-name",
            source / ".chezmoitemplates/theme-name",
        )
        config = work / "chezmoi.json"
        config.write_text("{}\n", encoding="utf-8")
        for platform in PLATFORMS:
            for theme in THEMES:
                for consumer, template in CONSUMERS.items():
                    command = [
                        chezmoi,
                        "--config",
                        str(config),
                        "--source",
                        str(source),
                        "--destination",
                        str(work / "destination"),
                        "--cache",
                        str(work / "cache"),
                        "--persistent-state",
                        str(work / "state.boltdb"),
                        "execute-template",
                    ]
                    # Set fixture fields inside the template so the same
                    # harness works with the CI-pinned older chezmoi, which
                    # predates --override-data. The palette catalogue stays
                    # supplied by the real source-data loader.
                    fixture = json.dumps(json.dumps(fixture_data(theme, platform)))
                    prefix = (
                        "{{- $fixture := fromJson " + fixture + " -}}"
                        "{{- range $key, $value := $fixture -}}"
                        "{{- $_ := set $ $key $value -}}{{- end -}}"
                    )
                    rendered = subprocess.run(
                        command,
                        input=prefix
                        + (REPO / "defaults" / template).read_text(encoding="utf-8"),
                        check=True,
                        capture_output=True,
                        text=True,
                        encoding="utf-8",
                        timeout=15,
                        env={
                            "PATH": "/bin",
                            "HOME": os.environ["HOME"],
                            "LANG": "C",
                            "LC_ALL": "C",
                        },
                    ).stdout
                    if (
                        not rendered.strip()
                        or "{{" in rendered
                        or "<no value>" in rendered
                    ):
                        raise ValueError(
                            f"incomplete render: {platform}/{theme}/{consumer}"
                        )
                    result[f"{platform}/{theme}/{consumer}.golden"] = rendered
    return result


def compare(rendered: dict[str, str], root: Path, update: bool = False) -> list[str]:
    expected = set(rendered)
    existing = {str(path.relative_to(root)) for path in root.rglob("*.golden")}
    failures = [f"unexpected fixture: {name}" for name in sorted(existing - expected)]
    for name, actual in rendered.items():
        target = root / name
        if update:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(actual, encoding="utf-8")
        elif not target.is_file():
            failures.append(f"missing fixture: {name}")
        elif target.read_text(encoding="utf-8") != actual:
            failures.append(
                "".join(
                    difflib.unified_diff(
                        target.read_text(encoding="utf-8").splitlines(keepends=True),
                        actual.splitlines(keepends=True),
                        fromfile=name,
                        tofile="rendered/" + name,
                    )
                )
            )
    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--update", action="store_true", help="explicitly regenerate reviewable goldens"
    )
    args = parser.parse_args()
    chezmoi = shutil.which("chezmoi")
    if not chezmoi:
        parser.error("chezmoi is required; this gate never silently skips")
    try:
        rendered = render_all(chezmoi)
        failures = compare(rendered, GOLDENS, args.update)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"theme-render: {error}", file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError):
            print(error.stderr, file=sys.stderr)
        return 1
    if failures:
        print("\n".join(failures), file=sys.stderr)
        print(
            "Review changes, then run scripts/theme/check-render-goldens.py --update",
            file=sys.stderr,
        )
        return 1
    print(
        f"theme-render: {len(rendered)} rendered config goldens {'updated' if args.update else 'matched'}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
