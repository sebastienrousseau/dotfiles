#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Sebastien Rousseau
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Standards synchronization and integrity verification utility.

Maintains strict synchronization between the canonical standards repository,
the active workspace root (~/Code), and dotfiles (chezmoi distribution).
"""

from __future__ import annotations

import argparse
import difflib
import hashlib
import os
import shutil
import sys
from pathlib import Path

STANDARD_FILES = (
    "AGENTS.md",
    "GEMINI.md",
    "PR-TEMPLATE.md",
    "README-TEMPLATE.md",
    "REPO-STANDARD.md",
)


def find_canonical_source() -> Path | None:
    """Locate the canonical source directory containing the standard files."""
    if "STANDARDS_REPO" in os.environ:
        try:
            custom = Path(os.environ["STANDARDS_REPO"])
            if custom.is_dir() and (custom / "AGENTS.md").is_file():
                return custom
        except (OSError, PermissionError):
            pass

    # First check if invoked from within a dotfiles or standards git checkout
    curr = Path(__file__).resolve()
    for p in curr.parents:
        for sub in ("defaults/Code", ""):
            candidate = p / sub if sub else p
            try:
                if candidate.is_dir() and (candidate / "AGENTS.md").is_file():
                    with (candidate / "AGENTS.md").open("rb") as f:
                        f.read(1)
                    return candidate
            except (OSError, PermissionError):
                continue

    home = Path.home()
    candidates = [
        home / "Code" / "Public" / "Other" / "standards",
        home / "Code",
        home / ".dotfiles" / "defaults" / "Code",
        home / ".local" / "share" / "chezmoi" / "defaults" / "Code",
    ]
    for c in candidates:
        try:
            if c.is_dir() and (c / "AGENTS.md").is_file():
                with (c / "AGENTS.md").open("rb") as f:
                    f.read(1)
                return c
        except (OSError, PermissionError):
            continue

    return None


def get_target_dirs(src_dir: Path) -> list[tuple[str, Path]]:
    """Return configured sync target directories with descriptive labels."""
    if "STANDARDS_TARGETS" in os.environ:
        custom_targets: list[tuple[str, Path]] = []
        for item in os.environ["STANDARDS_TARGETS"].split(os.pathsep):
            if item.strip():
                p = Path(item.strip())
                custom_targets.append((p.name or "Custom Target", p))
        return custom_targets

    home = Path.home()
    code_dir = home / "Code"

    all_targets: list[tuple[str, Path]] = [
        ("Workspace Root", code_dir),
        ("Chezmoi Dotfiles", home / ".dotfiles" / "defaults" / "Code"),
        ("Dotfiles Workspace", code_dir / "Public" / "Shell" / "dotfiles" / "defaults" / "Code"),
        ("Chezmoi Local Share", home / ".local" / "share" / "chezmoi" / "defaults" / "Code"),
    ]

    try:
        src_resolved = src_dir.resolve()
    except Exception:
        src_resolved = src_dir

    targets: list[tuple[str, Path]] = []
    seen: set[Path] = {src_resolved}

    for label, p in all_targets:
        try:
            p_resolved = p.resolve()
        except Exception:
            p_resolved = p
        if p_resolved in seen:
            continue
        try:
            if p.exists() or (p.parent.exists() and p.name == "Code"):
                seen.add(p_resolved)
                targets.append((label, p))
        except (OSError, PermissionError):
            continue
    return targets


def compute_hash(path: Path) -> str:
    """Compute SHA-256 digest of a file."""
    try:
        if not path.is_file():
            return ""
        h = hashlib.sha256()
        with path.open("rb") as f:
            while chunk := f.read(65536):
                h.update(chunk)
        return h.hexdigest()
    except (OSError, PermissionError):
        return ""


def check_target_file(src: Path, dst: Path, fname: str, label: str, quiet: bool) -> bool:
    """Check a single target file against source. Return True if drifted."""
    try:
        if not src.is_file():
            return False
    except (OSError, PermissionError):
        return False

    src_hash = compute_hash(src)
    if not src_hash:
        return False

    try:
        if not dst.exists():
            if not quiet:
                print(f"  [MISSING] {fname}")
            return True
    except (OSError, PermissionError):
        return False

    dst_hash = compute_hash(dst)
    if not dst_hash:
        return False

    if src_hash != dst_hash:
        if not quiet:
            print(f"  [DRIFTED] {fname}")
            try:
                src_lines = src.read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
                dst_lines = dst.read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
                diff = difflib.unified_diff(
                    src_lines, dst_lines,
                    fromfile=f"standards/{fname}",
                    tofile=f"{label}/{fname}",
                    n=2,
                )
                print("".join(list(diff)[:15]))
            except Exception:
                pass
        return True
    if not quiet:
        print(f"  [OK]      {fname}")
    return False


def check_sync(src_dir: Path | None, targets: list[tuple[str, Path]], quiet: bool = False) -> int:
    """Verify all targets match source files byte-for-byte. Return 0 if in sync, 1 if drifted."""
    if src_dir is None:
        if not quiet:
            print("No standards source directory located.")
        return 0

    drift_count = 0
    if not quiet:
        print(f"Checking synchronization for {len(STANDARD_FILES)} standard files across {len(targets)} targets...\n")

    for label, target_dir in targets:
        if not quiet:
            print(f"Target: {label} ({target_dir})")
        try:
            if not target_dir.exists():
                if not quiet:
                    print(f"  [MISSING] Target directory does not exist: {target_dir}\n")
                drift_count += 1
                continue
        except (OSError, PermissionError):
            continue

        for fname in STANDARD_FILES:
            if check_target_file(src_dir / fname, target_dir / fname, fname, label, quiet):
                drift_count += 1
        if not quiet:
            print()

    if drift_count == 0:
        if not quiet:
            print("All standards are synchronized.")
        return 0

    if quiet:
        print(f"\033[0;33m⚠️  [standards] Drift detected across ~/Code or dotfiles ({drift_count} discrepancy).\033[0m")
        print("   Run 'standards-sync' to auto-heal or 'standards-sync --check' to inspect diffs.")
    else:
        print(f"Synchronization check failed with {drift_count} drift(s).")
    return 1


def push_sync(src_dir: Path | None, targets: list[tuple[str, Path]]) -> int:
    """Propagate canonical repo files to all target destinations."""
    if src_dir is None:
        print("Cannot push: no standards source directory located.")
        return 1

    print(f"Synchronizing {len(STANDARD_FILES)} standard files to {len(targets)} targets...\n")
    for label, target_dir in targets:
        try:
            target_dir.mkdir(parents=True, exist_ok=True)
        except (OSError, PermissionError) as e:
            print(f"Cannot update {label} ({target_dir}): {e}")
            continue

        print(f"Updating: {label} ({target_dir})")
        for fname in STANDARD_FILES:
            src = src_dir / fname
            dst = target_dir / fname
            try:
                if not src.is_file():
                    continue
                shutil.copy2(src, dst)
                print(f"  [COPIED] {fname}")
            except (OSError, PermissionError) as e:
                print(f"  [ERROR] {fname}: {e}")
        print()
    print("Push synchronization complete.")
    return 0


def pull_sync(src_dir: Path | None) -> int:
    """Pull edited files from workspace root (~/Code) into canonical repo."""
    if src_dir is None:
        print("Cannot pull: no standards destination directory located.")
        return 1

    code_dir = Path.home() / "Code"
    if not code_dir.exists():
        print(f"Workspace root not found: {code_dir}")
        return 1

    print(f"Pulling standards from workspace root ({code_dir}) into repo...\n")
    for fname in STANDARD_FILES:
        src = code_dir / fname
        dst = src_dir / fname
        try:
            if not src.is_file():
                continue
            shutil.copy2(src, dst)
            print(f"  [PULLED] {fname}")
        except (OSError, PermissionError) as e:
            print(f"  [ERROR] {fname}: {e}")
    print("\nPull complete. Running push to update dotfiles mirrors...")
    targets = [t for t in get_target_dirs(src_dir) if t[0] != "Workspace Root"]
    return push_sync(src_dir, targets)


def install_hooks(src_dir: Path | None) -> int:
    """Install git post-commit and post-merge hooks to auto-sync on commit/pull."""
    if src_dir is None:
        print("Cannot install hooks: no standards directory located.")
        return 1

    hooks_dir = src_dir / ".git" / "hooks"
    if not hooks_dir.exists():
        print(f"Git hooks directory not found at {hooks_dir}")
        return 1

    hook_content = (
        "#!/bin/sh\n"
        "# Auto-sync standards to workspace root and dotfiles\n"
        "standards-sync --push\n"
    )

    for hook_name in ("post-commit", "post-merge"):
        hook_path = hooks_dir / hook_name
        try:
            hook_path.write_text(hook_content, encoding="utf-8")
            hook_path.chmod(0o755)
            print(f"Installed hook: {hook_path}")
        except (OSError, PermissionError) as e:
            print(f"Cannot install hook {hook_name}: {e}")
            return 1

    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check for drift without modifying files")
    parser.add_argument("-q", "--quiet", action="store_true", help="Quiet mode: suppress output unless drift detected")
    parser.add_argument("--push", action="store_true", help="Push canonical repo standards to all targets")
    parser.add_argument("--pull", action="store_true", help="Pull standards from workspace root into repo")
    parser.add_argument("--install-hooks", action="store_true", help="Install git post-commit and post-merge hooks")
    args = parser.parse_args()

    src_dir = find_canonical_source()
    targets = get_target_dirs(src_dir) if src_dir else []

    if args.install_hooks:
        return install_hooks(src_dir)
    if args.pull:
        return pull_sync(src_dir)
    if args.check:
        return check_sync(src_dir, targets, quiet=args.quiet)

    return push_sync(src_dir, targets)


if __name__ == "__main__":
    sys.exit(main())
