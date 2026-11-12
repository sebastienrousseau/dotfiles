#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Build the registry modules under registry/modules into archives and index.

Each module is a directory with a module.json (name, version, description,
and optionally repo, tags, maintainer, license) and a files/ tree of plain
chezmoi source files. Its archive, <name>-<version>.tar.gz, holds that tree
under one <name>-<version>/ directory (dot cli install takes a single
top-level directory as the module root, so the tree itself never is), and
is reproducible: entries sorted, times, owners and modes fixed, and no
gzip timestamp, so the same files always give the same SHA-256.

  build_modules.py [--updated TIME]
      writes the archives to docs/registry/modules, which the site serves
      beside the index, and docs/registry.json, each entry pinned to its
      archive's URL and digest
  build_modules.py --check
      fails when docs/registry.json or a committed archive is not what a
      build writes (`updated` aside)

The index is then signed offline (docs/operations/REGISTRY.md).
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
import re
import sys
import tarfile
from datetime import UTC, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ARCHIVES = "docs/registry/modules"
BASE_URL = "https://doc.dotfiles.io/registry/modules"
KEYS = ("name", "version", "description", "repo", "tags", "maintainer", "license")
NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,31}$")
VERSION_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$")


class ModuleError(Exception):
    """A module that cannot be published as it stands."""


def load_meta(module: Path) -> dict:
    """module.json, checked against the index contract."""
    meta = json.loads((module / "module.json").read_text(encoding="utf-8"))
    unknown = sorted(set(meta) - set(KEYS))
    if unknown:
        raise ModuleError(f"{module.name}: unknown key {unknown[0]!r}")
    if meta.get("name") != module.name or not NAME_RE.match(module.name):
        raise ModuleError(f"{module.name}: name must be the directory's, kebab-case")
    if not VERSION_RE.match(str(meta.get("version", ""))):
        raise ModuleError(f"{module.name}: version is not semver")
    if not 0 < len(meta.get("description", "")) <= 200:
        raise ModuleError(f"{module.name}: description must be 1-200 characters")
    return meta


def module_files(module: Path) -> list[Path]:
    """Every file under files/, sorted; a link or an empty tree is refused."""
    tree = module / "files"
    paths = sorted(tree.rglob("*"))
    for path in paths:
        if path.is_symlink():
            raise ModuleError(f"{module.name}: {path.relative_to(tree)} is a link")
    files = [p for p in paths if p.is_file()]
    if not files:
        raise ModuleError(f"{module.name}: files/ is empty")
    return files


def tar_entry(name: str, kind: bytes, mode: int, size: int = 0) -> tarfile.TarInfo:
    info = tarfile.TarInfo(name)
    info.type, info.mode, info.size = kind, mode, size
    info.mtime, info.uid, info.gid, info.uname, info.gname = 0, 0, 0, "", ""
    return info


def archive_bytes(module: Path, top: str) -> bytes:
    """The module's reproducible .tar.gz."""
    tree = module / "files"
    files = [f.relative_to(tree) for f in module_files(module)]
    raw = io.BytesIO()
    with tarfile.open(fileobj=raw, mode="w", format=tarfile.USTAR_FORMAT) as tar:
        for d in sorted({d for f in files for d in f.parents}):
            name = top if d == Path(".") else f"{top}/{d.as_posix()}"
            tar.addfile(tar_entry(name, tarfile.DIRTYPE, 0o755))
        for f in files:
            data = (tree / f).read_bytes()
            tar.addfile(
                tar_entry(f"{top}/{f.as_posix()}", tarfile.REGTYPE, 0o644, len(data)),
                io.BytesIO(data),
            )
    out = io.BytesIO()
    with gzip.GzipFile(
        filename="", mode="wb", fileobj=out, mtime=0, compresslevel=9
    ) as gz:
        gz.write(raw.getvalue())
    return out.getvalue()


def build(modules_dir: Path) -> list[tuple[dict, str, bytes]]:
    """Per module, sorted by name: its index entry, archive name and bytes."""
    built = []
    for module in sorted(
        p for p in modules_dir.iterdir() if (p / "module.json").is_file()
    ):
        meta = load_meta(module)
        top = f"{meta['name']}-{meta['version']}"
        data = archive_bytes(module, top)
        entry = {k: meta[k] for k in KEYS if k in meta}
        entry["archive_url"] = f"{BASE_URL}/{top}.tar.gz"
        entry["sha256"] = hashlib.sha256(data).hexdigest()
        built.append((entry, f"{top}.tar.gz", data))
    return built


def write(root: Path, updated: str) -> None:
    """The archives into docs/registry/modules, the entries into the index."""
    built = build(root / "registry/modules")
    archives = root / ARCHIVES
    archives.mkdir(parents=True, exist_ok=True)
    for _, name, data in built:
        (archives / name).write_bytes(data)
    index = root / "docs/registry.json"
    doc = json.loads(index.read_text(encoding="utf-8"))
    doc["updated"], doc["modules"] = updated, [entry for entry, _, _ in built]
    index.write_text(
        json.dumps(doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )


def stale(root: Path) -> list[str]:
    """What differs from a build: the index's entries, or an archive."""
    built = build(root / "registry/modules")
    index = json.loads((root / "docs/registry.json").read_text(encoding="utf-8"))
    out = (
        []
        if index.get("modules") == [e for e, _, _ in built]
        else ["docs/registry.json"]
    )
    for _, name, data in built:
        path = root / ARCHIVES / name
        if not path.is_file() or path.read_bytes() != data:
            out.append(f"{ARCHIVES}/{name}")
    return out


def check(root: Path) -> int:
    differ = stale(root)
    if not differ:
        print("registry modules: the index and archives match the build")
        return 0
    print(
        f"registry modules: {', '.join(differ)} not what the build writes; "
        "run tools/registry/build_modules.py and re-sign the index",
        file=sys.stderr,
    )
    return 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=Path, default=ROOT, help="repository root")
    parser.add_argument("--updated", help="the index's updated time (default: now)")
    parser.add_argument(
        "--check",
        action="store_true",
        help="compare the index and archives with a build",
    )
    args = parser.parse_args(argv)
    try:
        if args.check:
            return check(args.root)
        write(
            args.root, args.updated or datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
        )
    except ModuleError as err:
        print(f"registry modules: {err}", file=sys.stderr)
        return 1
    print(f"registry modules: {ARCHIVES} and docs/registry.json written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
