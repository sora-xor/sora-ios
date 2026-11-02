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

    def framework(self, code=""):
        directory = self.app / "Frameworks/blake2lib.framework"
        directory.mkdir(parents=True)
        (directory / "Info.plist").write_bytes(plistlib.dumps({"CFBundleExecutable": "blake2lib"}))
        source = self.root / "library.c"
        source.write_text(code)
        subprocess.run(["xcrun", "clang", "-dynamiclib", str(source),
                        "-Wl,-install_name,@rpath/blake2lib.framework/blake2lib",
                        "-o", str(directory / "blake2lib")], check=True, capture_output=True)
        return directory

    def test_removes_only_empty_stubs_and_preserves_custom_language(self):
        directory = self.framework()
        resources.prepare(self.app, self.localizations)
        self.assertFalse(directory.exists())
        self.assertFalse((self.app / "egy-Egyp.lproj").exists())
        for file in (self.localizations / "egy-Egyp.lproj").iterdir():
            self.assertEqual((self.app / "AppLanguages/egy-Egyp" / file.name).read_bytes(), file.read_bytes())
        resources.prepare(self.app, self.localizations)  # Incremental builds.

    def test_refuses_a_framework_with_real_code(self):
        directory = self.framework("int value(void) { return 42; }")
        with self.assertRaisesRegex(ValueError, "contains code or data"):
            resources.prepare(self.app, self.localizations)
        self.assertTrue(directory.exists())

    def test_refuses_a_framework_with_resources(self):
        directory = self.framework()
        (directory / "PrivacyInfo.xcprivacy").write_bytes(plistlib.dumps({"NSPrivacyTracking": False}))
        with self.assertRaisesRegex(ValueError, "contains resources"):
            resources.prepare(self.app, self.localizations)
        self.assertTrue((directory / "PrivacyInfo.xcprivacy").exists())

    def test_refuses_a_runtime_dependency(self):
        directory = self.framework("int value(void) { return 42; }")
        source = self.root / "app.c"
        source.write_text("extern int value(void); int main(void) { return value(); }")
        subprocess.run(["xcrun", "clang", str(source), "-F", str(directory.parent),
                        "-framework", "blake2lib", "-o", str(self.app / "SoraPassport")],
                       check=True, capture_output=True)
        with self.assertRaisesRegex(ValueError, "runtime dependency"):
            resources.prepare(self.app, self.localizations)
        self.assertTrue(directory.exists())

    def test_refuses_to_advertise_custom_language_to_apple(self):
        (self.app / "egy-Egyp.lproj").mkdir()
        with self.assertRaisesRegex(ValueError, "not an Apple locale"):
            resources.prepare(self.app, self.localizations)


if __name__ == "__main__":
    unittest.main()
