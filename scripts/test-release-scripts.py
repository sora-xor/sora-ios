#!/usr/bin/env python3
"""Exercise release guards without signing, uploading, or invoking real Xcode."""
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ReleaseScriptTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="sora-release-tests-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.repo = self.base / "checkout"
        (self.repo / "scripts").mkdir(parents=True)
        shutil.copy(ROOT / "scripts/archive-app-store.sh", self.repo / "scripts")
        config = self.repo / "SoraPassport/Configs"
        config.mkdir(parents=True)
        shutil.copy(ROOT / "SoraPassport/Configs/ExportOptions.app-store-connect.plist", config)
        self.pin = self.repo / "Package.resolved"
        self.pin.write_text("pinned\n")
        self.git("init", "-q")
        self.git("add", ".")
        self.git("-c", "user.name=Release Test", "-c", "user.email=test@example.invalid",
                 "commit", "-qm", "fixture")
        binary = self.base / "bin"
        binary.mkdir()
        xcode = binary / "xcodebuild"
        xcode.write_text('''#!/usr/bin/env python3
import json, os, pathlib, plistlib, sys
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as log:
    log.write(json.dumps(args) + '\\n')
if 'archive' in args:
    app = pathlib.Path(args[args.index('-archivePath')+1]) / 'Products/Applications/SoraPassport.app'
    app.mkdir(parents=True)
    with (app/'Info.plist').open('wb') as output:
        plistlib.dump({'CFBundleIdentifier':'co.jp.soramitsu.sora',
                      'GIDClientID':'fixture.apps.googleusercontent.com',
                      'CFBundleURLTypes':[{'CFBundleURLSchemes':['com.googleusercontent.apps.fixture']}]}, output)
    if os.environ.get('SIMULATE_PIN_DRIFT'):
        pathlib.Path('Package.resolved').write_text('changed by build')
else:
    pathlib.Path(args[args.index('-exportPath')+1]).mkdir()
''')
        xcode.chmod(0o755)
        self.calls = self.base / "calls.jsonl"
        self.env = dict(os.environ, PATH=f"{binary}:{os.environ['PATH']}",
                        CALLS=str(self.calls), SORA_ARCHIVE_PATH=str(self.base / "candidate.xcarchive"),
                        SORA_EXPORT_PATH=str(self.base / "export"))
        for key in ["SORA_MIGRATION_EVIDENCE_HARNESS", "SORA_EVIDENCE_HARNESS_CONDITION",
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS", "OTHER_SWIFT_FLAGS", "SORA_EXPORT_OPTIONS_PLIST"]:
            self.env.pop(key, None)

    def git(self, *args):
        subprocess.run(["git", *args], cwd=self.repo, check=True, capture_output=True)

    def archive(self, **env):
        return subprocess.run(["bash", "scripts/archive-app-store.sh"], cwd=self.repo,
                              env=dict(self.env, **env), text=True, capture_output=True)

    def invocations(self):
        return [json.loads(line) for line in self.calls.read_text().splitlines()] if self.calls.exists() else []

    def test_archive_and_export_use_pins_and_release_only(self):
        result = self.archive()
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.invocations()
        self.assertEqual(len(calls), 2)
        for call in calls:
            self.assertIn("-onlyUsePackageVersionsFromResolvedFile", call)
        self.assertEqual(calls[0][calls[0].index("-scheme")+1], "SoraPassport")
        self.assertEqual(calls[0][calls[0].index("-configuration")+1], "Release")
        self.assertIn("GIDClientID: fixture", result.stdout)

    def test_changed_pins_prevent_export(self):
        result = self.archive(SIMULATE_PIN_DRIFT="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.invocations()), 1)
        self.assertFalse(Path(self.env["SORA_EXPORT_PATH"]).exists())

    def test_dirty_checkout_prevents_archive(self):
        self.pin.write_text("unreviewed")
        self.assertNotEqual(self.archive().returncode, 0)
        self.assertEqual(self.invocations(), [])

    def test_harness_prevents_archive(self):
        result = self.archive(SWIFT_ACTIVE_COMPILATION_CONDITIONS="SORA_MIGRATION_EVIDENCE_HARNESS")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.invocations(), [])

    def test_export_options_cannot_upload(self):
        options = self.base / "upload.plist"
        with options.open('wb') as stream:
            plistlib.dump({'destination': 'upload'}, stream)
        self.assertNotEqual(self.archive(SORA_EXPORT_OPTIONS_PLIST=str(options)).returncode, 0)
        self.assertEqual(self.invocations(), [])

    def crashlytics(self, **values):
        env = dict(self.env)
        for key in ["ACTION", "BUILD_DIR", "PROJECT_TEMP_DIR", "TARGET_TEMP_DIR", "PROJECT_DIR",
                    "SORA_SOURCE_PACKAGES_PATH"]:
            env.pop(key, None)
        env.update(values)
        return subprocess.run(["sh", str(ROOT / "SoraPassport/Scripts/run-crashlytics.sh")],
                              env=env, text=True, capture_output=True)

    def test_crashlytics_never_runs_for_build_or_test(self):
        self.assertEqual(self.crashlytics(ACTION="build").returncode, 0)
        self.assertEqual(self.crashlytics(ACTION="test").returncode, 0)

    def test_crashlytics_rejects_harness_archive(self):
        result = self.crashlytics(ACTION="install", SORA_EVIDENCE_HARNESS_CONDITION="SORA_MIGRATION_EVIDENCE_HARNESS")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("harness", result.stderr)

    def test_crashlytics_propagates_upload_failure_from_explicit_cache(self):
        package = self.base / "packages"
        run = package / "checkouts/firebase-ios-sdk/Crashlytics/run"
        run.parent.mkdir(parents=True)
        run.write_text("#!/bin/sh\nexit 17\n")
        result = self.crashlytics(ACTION="install", SORA_SOURCE_PACKAGES_PATH=str(package))
        self.assertEqual(result.returncode, 17, result.stderr)


if __name__ == "__main__":
    unittest.main()
