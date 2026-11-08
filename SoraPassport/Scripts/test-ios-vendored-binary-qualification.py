#!/usr/bin/env python3
"""Tests for the no-prebuilt-binaries check (verify-ios-vendored-binary-qualification)."""

from __future__ import annotations

import importlib.util
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "SoraPassport" / "Scripts" / "verify-ios-vendored-binary-qualification.py"
WRAPPER = ROOT / "SoraPassport" / "Scripts" / "verify-ios-vendored-binary-qualification.sh"

spec = importlib.util.spec_from_file_location("vendored", SCRIPT)
vendored = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vendored)


class NoPrebuiltBinariesTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="sora-no-binaries-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "Sources").mkdir()
        (self.root / "Sources" / "main.c").write_text("int main(void) { return 0; }\n")

    def findings(self) -> list:
        return vendored.binary_findings(self.root, vendored.walked_files(self.root))

    def test_repository_has_no_prebuilt_binaries(self) -> None:
        # The dependency gate runs this suite on every build; this is where the
        # repository scan is enforced (--lint-templates does not scan).
        self.assertEqual(vendored.scan(ROOT), [])
        result = subprocess.run(["/bin/sh", str(WRAPPER), "--scan-repository"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")

    def test_source_only_tree_passes(self) -> None:
        self.assertEqual(self.findings(), [])

    def test_xcframework_and_framework_directories_are_rejected(self) -> None:
        for directory in ("Binaries/sr25519lib.xcframework", "Vendor/Foo.framework"):
            path = self.root / directory
            path.mkdir(parents=True)
            (path / "Info.plist").write_text("<plist/>")
        joined = "\n".join(self.findings())
        self.assertIn("sr25519lib.xcframework", joined)
        self.assertIn("Foo.framework", joined)

    def test_libraries_and_objects_are_rejected_by_name(self) -> None:
        for name in ("libsr25519crust.a", "libfoo.dylib", "libbar.so", "baz.o"):
            (self.root / name).write_text("not really a binary")
        self.assertEqual(len(self.findings()), 4)

    def test_mach_o_elf_and_ar_images_are_rejected_by_content(self) -> None:
        compiled = self.root / "harmless-looking.txt"
        subprocess.run(
            ["xcrun", "clang", "-x", "c", "-c", "-", "-o", str(compiled)],
            input=b"int x;", check=True, capture_output=True,
        )
        (self.root / "elf.bin").write_bytes(b"\x7fELF\x02\x01\x01" + bytes(57))
        (self.root / "archive.dat").write_bytes(b"!<arch>\nmember")
        joined = "\n".join(self.findings())
        for name in ("harmless-looking.txt", "elf.bin", "archive.dat"):
            self.assertIn(f"binary executable image: {name}", joined)

    def test_swiftpm_binary_targets_are_rejected(self) -> None:
        (self.root / "Package.swift").write_text(
            'let package = Package(targets: [.binaryTarget(name: "X", path: "X.xcframework")])\n'
        )
        self.assertEqual(self.findings(), ["SwiftPM binary target: Package.swift"])

    def test_closed_source_package_pins_are_rejected(self) -> None:
        resolved = {
            "pins": [
                {"identity": "snapkit", "location": "https://github.com/SnapKit/SnapKit.git"},
                {"identity": "googleappmeasurement", "location": "https://github.com/google/GoogleAppMeasurement.git"},
                {"identity": "firebase-ios-sdk", "location": "https://github.com/firebase/firebase-ios-sdk.git"},
            ],
            "version": 3,
        }
        (self.root / "Package.resolved").write_text(json.dumps(resolved))
        joined = "\n".join(self.findings())
        self.assertIn("googleappmeasurement", joined)
        self.assertIn("firebase-ios-sdk", joined)
        self.assertNotIn("snapkit", joined)

    def test_build_outputs_and_local_copies_are_not_scanned(self) -> None:
        for directory in ("build/Products", "DerivedData/x", ".local/snapshot", "SourcePackages/artifacts"):
            path = self.root / directory / "Thing.xcframework"
            path.mkdir(parents=True)
            (path / "Info.plist").write_text("<plist/>")
        self.assertEqual(self.findings(), [])

    def test_lint_templates_succeeds_silently_on_the_repository(self) -> None:
        result = subprocess.run(["/bin/sh", str(WRAPPER), "--lint-templates"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")
        digest = subprocess.run(
            ["/bin/sh", str(WRAPPER), "--print-contract-sha256"], capture_output=True, text=True, check=True
        ).stdout.strip()
        self.assertRegex(digest, r"^[0-9a-f]{64}$")

    def test_production_promotion_fails_closed_without_a_receipt(self) -> None:
        result = subprocess.run(["/bin/sh", str(WRAPPER), "--verify-qualified"], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("receiptSha256=", result.stdout)
        self.assertIn("no vendored-binary promotion receipt", result.stderr)


if __name__ == "__main__":
    unittest.main()
