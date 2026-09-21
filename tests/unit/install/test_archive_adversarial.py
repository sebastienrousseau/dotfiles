#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Exercise the real shell guard with archives; never extract hostile fixtures."""
import io
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[3]


class Archives(unittest.TestCase):
    def guard(self, kind, path):
        return subprocess.run([
            "bash", "-c",
            'die() { echo "$*" >&2; exit 1; }; source "$1"; archive_paths_are_safe "$2" "$3"',
            "fixture", str(ROOT / "install/lib/installers.sh"), kind, str(path),
        ], capture_output=True, text=True, timeout=10)

    def test_tar_matrix(self):
        cases = ["valid", "absolute", "traversal", "symlink", "hardlink",
                 "fifo", "device", "duplicate", "backslash", "drive", "corrupt",
                 "parent", "alias", "double-slash"]
        with tempfile.TemporaryDirectory() as directory:
            for case in cases:
                with self.subTest(case=case):
                    path = Path(directory) / f"{case}.tar"
                    name = {"absolute": "/escape", "traversal": "../escape",
                            "backslash": "..\\escape", "drive": "C:/escape",
                            "parent": "..", "alias": "bin/./tool", "double-slash": "bin//tool"}.get(case, "bin/tool")
                    with tarfile.open(path, "w") as archive:
                        entry = tarfile.TarInfo(name)
                        entry.mode = 0o755
                        entry.type = {"symlink": tarfile.SYMTYPE, "hardlink": tarfile.LNKTYPE,
                                      "fifo": tarfile.FIFOTYPE, "device": tarfile.CHRTYPE}.get(case, tarfile.REGTYPE)
                        if case in ("symlink", "hardlink"):
                            entry.linkname = "../../escape"
                        if entry.isfile():
                            entry.size = 4
                        archive.addfile(entry, io.BytesIO(b"safe") if entry.isfile() else None)
                        if case == "duplicate":
                            archive.addfile(entry, io.BytesIO(b"evil"))
                    if case == "corrupt":
                        path.write_bytes(b"not an archive")
                    result = self.guard("tar", path)
                    self.assertEqual(result.returncode == 0, case == "valid", result.stderr)

    def test_zip_matrix(self):
        with tempfile.TemporaryDirectory() as directory:
            for case in ("valid", "traversal", "absolute", "symlink", "backslash", "drive", "corrupt",
                         "parent", "alias", "double-slash"):
                with self.subTest(case=case):
                    path = Path(directory) / f"{case}.zip"
                    name = {"absolute": "/escape", "traversal": "../escape",
                            "backslash": "..\\escape", "drive": "C:/escape",
                            "parent": "..", "alias": "bin/./tool", "double-slash": "bin//tool"}.get(case, "bin/tool")
                    with zipfile.ZipFile(path, "w") as archive:
                        entry = zipfile.ZipInfo(name)
                        entry.create_system = 3
                        entry.external_attr = (0o120777 if case == "symlink" else 0o100755) << 16
                        archive.writestr(entry, "../../escape" if case == "symlink" else "safe")
                    if case == "corrupt":
                        path.write_bytes(b"bad zip")
                    result = self.guard("zip", path)
                    self.assertEqual(result.returncode == 0, case == "valid", result.stderr)


if __name__ == "__main__":
    unittest.main()
