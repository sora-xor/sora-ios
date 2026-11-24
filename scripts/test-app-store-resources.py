#!/usr/bin/env python3
"""Exercise packaging against real Mach-O binaries without signing or uploading."""
import importlib.util
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "resources", ROOT / "SoraPassport/Scripts/prepare-app-store-resources.py")
resources = importlib.util.module_from_spec(spec)
spec.loader.exec_module(resources)


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="sora-packaging-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / "SoraPassport.app"
        self.app.mkdir()
        (self.app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleExecutable": "SoraPassport"}))
        shutil.copyfile("/usr/bin/true", self.app / "SoraPassport")
        self.localizations = ROOT / "SoraPassport/SoraLocalizable"

    def framework(self):
        """A real framework with code, like the source-built crypto libraries."""
        directory = self.app / "Frameworks/blake2lib.framework"
        directory.mkdir(parents=True)
        (directory / "Info.plist").write_bytes(plistlib.dumps({"CFBundleExecutable": "blake2lib"}))
        source = self.root / "blake2.c"
        source.write_text("int blake2b(void) { return 0; }")
        subprocess.run(["xcrun", "clang", "-dynamiclib", str(source),
                        "-Wl,-install_name,@rpath/blake2lib.framework/blake2lib",
                        "-o", str(directory / "blake2lib")], check=True, capture_output=True)
        return directory

    def test_packages_custom_language_and_leaves_frameworks_alone(self):
        directory = self.framework()
        before = (directory / "blake2lib").read_bytes()
        resources.prepare(self.app, self.localizations)
        self.assertEqual((directory / "blake2lib").read_bytes(), before)
        self.assertFalse((self.app / "egy-Egyp.lproj").exists())
        for file in (self.localizations / "egy-Egyp.lproj").iterdir():
            self.assertEqual((self.app / "AppLanguages/egy-Egyp" / file.name).read_bytes(), file.read_bytes())
        resources.prepare(self.app, self.localizations)  # Incremental builds.

    def test_refuses_something_that_is_not_an_app(self):
        with self.assertRaisesRegex(ValueError, "Expected a built .app directory"):
            resources.prepare(self.root, self.localizations)

    def test_refuses_to_advertise_custom_language_to_apple(self):
        (self.app / "egy-Egyp.lproj").mkdir()
        with self.assertRaisesRegex(ValueError, "not an Apple locale"):
            resources.prepare(self.app, self.localizations)


if __name__ == "__main__":
    unittest.main()
