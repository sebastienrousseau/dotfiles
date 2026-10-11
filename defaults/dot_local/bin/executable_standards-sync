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


def get_repo_root() -> Path:
    """Return repository root path."""
    return Path(__file__).resolve().parent.parent


def get_target_dirs(repo_root: Path) -> list[tuple[str, Path]]:
    """Return configured sync target directories with descriptive labels."""
    home = Path.home()
    code_dir = repo_root.parent.parent.parent

    targets: list[tuple[str, Path]] = [
        ("Workspace Root", code_dir),
        ("Chezmoi Dotfiles", home / ".dotfiles" / "defaults" / "Code"),
        ("Dotfiles Workspace", code_dir / "Public" / "Shell" / "dotfiles" / "defaults" / "Code"),
    ]
    return [(label, p) for label, p in targets if p.parent.exists()]


def compute_hash(path: Path) -> str:
    """Compute SHA-256 digest of a file."""
    if not path.is_file():
        return ""
    h = hashlib.sha256()
    with path.open("rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def check_target_file(src: Path, dst: Path, fname: str, label: str, quiet: bool) -> bool:
    """Check a single target file against source. Return True if drifted."""
    src_hash = compute_hash(src)
    dst_hash = compute_hash(dst)

    if not dst.exists():
        if not quiet:
            print(f"  [MISSING] {fname}")
        return True
    if src_hash != dst_hash:
        if not quiet:
            print(f"  [DRIFTED] {fname}")
            src_lines = src.read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
            dst_lines = dst.read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
            diff = difflib.unified_diff(
                src_lines, dst_lines,
                fromfile=f"standards/{fname}",
                tofile=f"{label}/{fname}",
                n=2,
            )
            print("".join(list(diff)[:15]))
        return True
    if not quiet:
        print(f"  [OK]      {fname}")
    return False


def check_sync(repo_root: Path, targets: list[tuple[str, Path]], quiet: bool = False) -> int:
    """Verify all targets match repo files byte-for-byte. Return 0 if in sync, 1 if drifted."""
    drift_count = 0
    if not quiet:
        print(f"Checking synchronization for {len(STANDARD_FILES)} standard files across {len(targets)} targets...\n")

    for label, target_dir in targets:
        if not quiet:
            print(f"Target: {label} ({target_dir})")
        if not target_dir.exists():
            if not quiet:
                print(f"  [MISSING] Target directory does not exist: {target_dir}\n")
            drift_count += 1
            continue

        for fname in STANDARD_FILES:
            if check_target_file(repo_root / fname, target_dir / fname, fname, label, quiet):
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


def push_sync(repo_root: Path, targets: list[tuple[str, Path]]) -> int:
    """Propagate canonical repo files to all target destinations."""
    print(f"Synchronizing {len(STANDARD_FILES)} standard files to {len(targets)} targets...\n")
    for label, target_dir in targets:
        target_dir.mkdir(parents=True, exist_ok=True)
        print(f"Updating: {label} ({target_dir})")
        for fname in STANDARD_FILES:
            src = repo_root / fname
            dst = target_dir / fname
            if not src.is_file():
                continue
            shutil.copy2(src, dst)
            print(f"  [COPIED] {fname}")
        print()
    print("Push synchronization complete.")
    return 0


def pull_sync(repo_root: Path) -> int:
    """Pull edited files from workspace root (~/Code) into canonical repo."""
    code_dir = repo_root.parent.parent.parent
    print(f"Pulling standards from workspace root ({code_dir}) into repo...\n")
    for fname in STANDARD_FILES:
        src = code_dir / fname
        dst = repo_root / fname
        if not src.is_file():
            continue
        shutil.copy2(src, dst)
        print(f"  [PULLED] {fname}")
    print("\nPull complete. Running push to update dotfiles mirrors...")
    targets = [t for t in get_target_dirs(repo_root) if t[0] != "Workspace Root"]
    return push_sync(repo_root, targets)


def install_hooks(repo_root: Path) -> int:
    """Install git post-commit and post-merge hooks to auto-sync on commit/pull."""
    hooks_dir = repo_root / ".git" / "hooks"
    if not hooks_dir.exists():
        print(f"Git hooks directory not found at {hooks_dir}")
        return 1

    hook_content = (
        "#!/bin/sh\n"
        "# Auto-sync standards to workspace root and dotfiles\n"
        "python3 scripts/sync.py --push\n"
    )

    for hook_name in ("post-commit", "post-merge"):
        hook_path = hooks_dir / hook_name
        hook_path.write_text(hook_content, encoding="utf-8")
        hook_path.chmod(0o755)
        print(f"Installed hook: {hook_path}")

    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check for drift without modifying files")
    parser.add_argument("-q", "--quiet", action="store_true", help="Quiet mode: suppress output unless drift detected")
    parser.add_argument("--push", action="store_true", help="Push canonical repo standards to all targets")
    parser.add_argument("--pull", action="store_true", help="Pull standards from workspace root into repo")
    parser.add_argument("--install-hooks", action="store_true", help="Install git post-commit and post-merge hooks")
    args = parser.parse_args()

    repo_root = get_repo_root()
    targets = get_target_dirs(repo_root)

    if args.install_hooks:
        return install_hooks(repo_root)
    if args.pull:
        return pull_sync(repo_root)
    if args.check:
        return check_sync(repo_root, targets, quiet=args.quiet)

    return push_sync(repo_root, targets)


if __name__ == "__main__":
    sys.exit(main())
