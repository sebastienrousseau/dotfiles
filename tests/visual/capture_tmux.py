#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Real Kitty/X11 + tmux captures, not HTML reconstructions or native macOS claims.

Run in tests/visual/Dockerfile; mount the repo read-only and a private /output dir.
Every capture includes geometry/state/foreground/background evidence. Images are
review artifacts, not claimed native coverage for Ghostty/WezTerm/Windows terminals.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

from PIL import Image

REPO = Path(__file__).resolve().parents[2]


def run(*args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, text=True,
                          timeout=20, **kwargs).stdout.strip()


def wait_for(fn):
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        try:
            value = fn()
            if value:
                return value
        except (subprocess.SubprocessError, OSError):
            pass
        time.sleep(.1)
    raise RuntimeError("visual fixture did not become ready")


def focus(window):
    run("xdotool", "windowfocus", window)
    return True


def capture(output, quick=False):
    output.mkdir(parents=True, exist_ok=True)
    reports = []
    subprocess.run(["fc-cache", "-f"], check=True, timeout=30)
    fonts = [("fallback", "DejaVu Sans Mono"), ("nerd", "JetBrainsMono Nerd Font Mono")]
    for label, font in fonts:
        found = run("fc-match", "-f", "%{family}", font)
        if label == "nerd" and "Nerd" not in found:
            raise RuntimeError("Nerd font fixture absent; do not silently substitute")
    with tempfile.TemporaryDirectory(prefix="dot-visual-") as temporary:
        work = Path(temporary)
        project = work / "project"
        project.mkdir()
        socket = str(work / "tmux.sock")
        tmux = ["/usr/bin/tmux", "-S", socket]
        helper = work / "tmux-status"
        shutil.copyfile(REPO / "defaults/dot_local/bin/executable_tmux-status", helper)
        helper.chmod(0o700)
        wrapper = work / "tmux"
        wrapper.write_text(f'#!/bin/sh\nexec /usr/bin/tmux -S "{socket}" "$@"\n')
        wrapper.chmod(0o700)
        env = dict(os.environ, PATH=str(work) + ":" + os.environ["PATH"])
        processes = []
        try:
            run(*tmux, "-f", "/dev/null", "new-session", "-d", "-s", "DOT", "-c", str(project), "bash --noprofile --norc", env=env)
            run(*tmux, "set", "-g", "prefix", "C-a")
            run(*tmux, "set", "-g", "focus-events", "on")
            run(*tmux, "split-window", "-h", "-t", "DOT", "-c", str(project), "bash --noprofile --norc")
            run(*tmux, "new-session", "-d", "-s", "ssg-themes", "-c", str(project), "bash --noprofile --norc")
            for label, font in fonts:
                remote = str(work / (label + ".sock"))
                proc = subprocess.Popen([
                    "kitty", "--class", "dot-visual", "--title", "DOT visual fixture",
                    "--config", "/dev/null", "--listen-on", "unix:" + remote,
                    "-o", "allow_remote_control=yes", "-o", "linux_display_server=x11",
                    "-o", "font_family=" + font, "-o", "font_size=12",
                    "-o", "window_padding_width=8", "-o", "confirm_os_window_close=0",
                    *tmux, "attach", "-t", "DOT",
                ], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                processes.append(proc)
                remote_cmd = ["kitty", "@", "--to", "unix:" + remote]
                wait_for(lambda: run(*remote_cmd, "ls"))
                windows = run("xdotool", "search", "--class", "dot-visual").splitlines()
                window = windows[-1]
                for family in (["maui"] if quick else ["maui", "berlin"]):
                    for mode in ("dark", "light"):
                        theme = family + "-" + mode
                        goldens = REPO / "tests/fixtures/theme-render/linux" / theme
                        kitty = (goldens / "kitty.golden").read_text()
                        colors = work / "colors.conf"
                        colors.write_text("\n".join(line for line in kitty.splitlines()
                                                    if re.match(r"^(background |foreground |cursor |selection_|color\d+ )", line)))
                        run(*remote_cmd, "set-colors", str(colors))
                        source = (goldens / "tmux.golden").read_text()
                        theme_config = source.split("# --- Status Bar ---", 1)[1].split("# --- LINUX SPECIFIC ---", 1)[0]
                        # No plugin manager or desktop/user hooks are loaded. The
                        # actual status rules and helper operate on our private server.
                        theme_config = theme_config.replace("~/.local/bin/tmux-status", str(helper))
                        if label == "fallback":
                            for icon, replacement in {"": "KEY", "": "TMX", "": "DIR", "": "[Z]"}.items():
                                theme_config = theme_config.replace(icon, replacement)
                        config = work / "tmux.conf"
                        config.write_text(theme_config)
                        run(*tmux, "source-file", str(config), env=env)
                        # Metrics/time are deterministic fixtures; session colors,
                        # paths, window flags, prefix and zoom remain real tmux state.
                        right = run(*tmux, "show", "-gv", "status-right")
                        right = right.replace(f"#({helper} system)", "CPU 12% MEM 24%").replace("%H:%M", "12:34").replace("%d %b", "21 Sep")
                        run(*tmux, "set", "-g", "status-right", right)
                        for width in ([80] if quick else [80, 100, 120, 160]):
                            # Kitty versions differ in whether cell-based window
                            # resize includes padding. Verify the actual client grid.
                            requested = width
                            for attempt in range(4):
                                run(*remote_cmd, "resize-os-window", "--action", "resize", "--unit", "cells", "--width", str(requested), "--height", "24")
                                time.sleep(.25)
                                actual = int(run(*tmux, "list-clients", "-F", "#{client_width}"))
                                if actual == width:
                                    break
                                requested += width - actual
                            else:
                                raise AssertionError(f"requested {width} columns, got {actual}")
                            for state in ("normal", "prefix", "zoom", "unfocused"):
                                run("xdotool", "windowfocus", window)
                                if state == "zoom":
                                    run(*tmux, "resize-pane", "-Z", "-t", "DOT")
                                if state == "prefix":
                                    run(*remote_cmd, "send-text", "\\x01")
                                    wait_for(lambda: run(*tmux, "list-clients", "-F", "#{client_prefix}") == "1")
                                other = None
                                if state == "unfocused":
                                    other = subprocess.Popen(["xterm", "-title", "focus-target", "-geometry", "10x2+2400+1200"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                                    other_window = wait_for(lambda: run("xdotool", "search", "--onlyvisible", "--name", "^focus-target$").splitlines()[-1])
                                    wait_for(lambda: focus(other_window))
                                run(*tmux, "refresh-client", "-S")
                                time.sleep(.18)
                                screen = run(*remote_cmd, "get-text", "--extent", "screen")
                                if "DOT" not in screen or "project" not in screen:
                                    raise AssertionError(f"identity/location missing: {theme}/{label}/{width}/{state}: {screen[-250:]}")
                                if "bg=#" in screen or "fg=#" in screen:
                                    raise AssertionError("unrendered tmux style escaped into text")
                                filename = f"{theme}-{label}-{width}-{state}.png"
                                target = output / filename
                                run("import", "-window", window, str(target))
                                image = Image.open(target).convert("RGB")
                                if image.width < width * 5 or image.height < 200:
                                    raise AssertionError("invalid screenshot geometry")
                                reports.append({"file": filename, "theme": theme, "font": font,
                                                "columns": width, "state": state, "pixels": list(image.size),
                                                "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
                                                "status_text": screen.splitlines()[-1]})
                                if state == "prefix":
                                    run(*remote_cmd, "send-text", "\\x1b")
                                if state == "zoom":
                                    run(*tmux, "resize-pane", "-Z", "-t", "DOT")
                                if other:
                                    other.terminate()
                                    other.wait(timeout=5)
                proc.terminate()
                proc.wait(timeout=5)
            (output / "manifest.json").write_text(json.dumps({"renderer": "real Kitty X11 + tmux",
                "native_platform": "Linux container", "native_other_terminals": False,
                "fallback_icons": "ASCII substitutions in fixture only", "captures": reports}, indent=2) + "\n")
        finally:
            subprocess.run([*tmux, "kill-server"], capture_output=True, timeout=5)
            for proc in processes:
                if proc.poll() is None:
                    proc.kill()
                    proc.wait()
    print(f"PASS: {len(reports)} real terminal captures; manifest in {output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("/output"))
    parser.add_argument("--quick", action="store_true")
    args = parser.parse_args()
    capture(args.output, args.quick)
