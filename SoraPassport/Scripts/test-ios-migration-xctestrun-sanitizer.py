#!/usr/bin/env python3
"""Hermetic tests for the retained-device xctestrun sanitizer."""

from __future__ import annotations

import importlib.util
import os
import plistlib
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("sanitize-ios-migration-xctestrun.py")
SPEC = importlib.util.spec_from_file_location("ios_xctestrun_sanitizer", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("xctestrun sanitizer cannot be loaded")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class XctestrunSanitizerTests(unittest.TestCase):
    def fixture(self, root: Path, *, format_version: int = 1):
        clone = root / "protected-clone" / "Payload" / "SoraPassport.app"
        clone.mkdir(parents=True)
        generated = root / "generated.xctestrun"
        sanitized = root / "sanitized.xctestrun"
        ui_target = {
            "BlueprintName": MODULE.TARGET_NAME,
            "TestTargetName": MODULE.TARGET_NAME,
            "IsUITestBundle": True,
            "IsAppHostedTestBundle": False,
            "UITargetAppPath": (
                "__TESTROOT__/Release-iphoneos/SoraPassport.app"
            ),
            "UITargetAppBundleIdentifier": MODULE.BUNDLE_IDENTIFIER,
            "TestBundlePath": (
                "__TESTHOST__/PlugIns/SoraPassportUITests.xctest"
            ),
            "TestHostPath": (
                "__TESTROOT__/Release-iphoneos/"
                "SoraPassportUITests-Runner.app/SoraPassportUITests-Runner"
            ),
            "TestingEnvironmentVariables": {"DYLD_FRAMEWORK_PATH": "__TESTROOT__"},
            "DependentProductPaths": [
                "__TESTROOT__/Release-iphoneos/SoraPassport.app",
                "__TESTROOT__/Release-iphoneos/SoraPassportUITests-Runner.app",
            ],
        }
        unit_target = {
            "BlueprintName": "SoraPassportTests",
            "TestHostPath": (
                "__TESTROOT__/Release-iphoneos/SoraPassport.app/SoraPassport"
            ),
        }
        metadata = {"FormatVersion": format_version}
        if format_version == 1:
            value = {
                "SoraPassportTests-deadbeef": unit_target,
                "SoraPassportUITests-feedface": ui_target,
                "__xctestrun_metadata__": metadata,
            }
        else:
            value = {
                "TestConfigurations": [
                    {
                        "Name": "Test Scheme Action",
                        "IsEnabled": True,
                        "TestTargets": [unit_target, ui_target],
                    }
                ],
                "__xctestrun_metadata__": metadata,
            }
        generated.write_bytes(
            plistlib.dumps(value, fmt=plistlib.FMT_BINARY, sort_keys=True)
        )
        return clone, generated, sanitized, value

    def test_format_one_removes_every_rebuilt_host_install_path(self):
        with tempfile.TemporaryDirectory(prefix="sora-xctestrun-v1-") as temp:
            root = Path(temp).resolve()
            clone, generated, output, _ = self.fixture(root)
            result = MODULE.sanitize_xctestrun(generated, clone, output)
            self.assertTrue(result["rebuiltHostInstallDisabled"])
            retained = plistlib.loads(output.read_bytes())
            MODULE.verify_sanitized_value(retained, clone)
            targets = MODULE.extract_targets(retained)
            self.assertEqual(len(targets), 1)
            target = targets[0]
            self.assertEqual(target["UITargetAppPath"], str(clone))
            self.assertEqual(target["OnlyTestIdentifiers"], [MODULE.TARGET_TEST])
            self.assertNotIn(
                "__TESTROOT__/Release-iphoneos/SoraPassport.app",
                target["DependentProductPaths"],
            )
            self.assertFalse(MODULE.contains_rebuilt_host_path(retained, clone))

    def test_format_two_retains_only_the_exact_ui_test(self):
        with tempfile.TemporaryDirectory(prefix="sora-xctestrun-v2-") as temp:
            root = Path(temp).resolve()
            clone, generated, output, _ = self.fixture(root, format_version=2)
            result = MODULE.sanitize_xctestrun(generated, clone, output)
            MODULE.verify_sanitized_xctestrun(
                output,
                clone,
                result["sanitizedXctestrunSha256"],
            )
            retained = plistlib.loads(output.read_bytes())
            self.assertEqual(len(retained["TestConfigurations"]), 1)
            self.assertEqual(
                len(retained["TestConfigurations"][0]["TestTargets"]),
                1,
            )

    def test_unknown_nested_rebuilt_host_path_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix="sora-xctestrun-unsafe-") as temp:
            root = Path(temp).resolve()
            clone, generated, output, value = self.fixture(root)
            value["SoraPassportUITests-feedface"]["EnvironmentVariables"] = {
                "UNREVIEWED_HOST": (
                    "__TESTROOT__/Release-iphoneos/SoraPassport.app/SoraPassport"
                )
            }
            generated.write_bytes(plistlib.dumps(value, fmt=plistlib.FMT_XML))
            with self.assertRaises(MODULE.SanitizerError):
                MODULE.sanitize_xctestrun(generated, clone, output)

    def test_ambiguous_or_stale_test_inventory_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix="sora-xctestrun-stale-") as temp:
            root = Path(temp).resolve()
            clone, generated, output, value = self.fixture(root)
            value["SoraPassportUITests-second"] = dict(
                value["SoraPassportUITests-feedface"]
            )
            generated.write_bytes(plistlib.dumps(value, fmt=plistlib.FMT_XML))
            with self.assertRaises(MODULE.SanitizerError):
                MODULE.sanitize_xctestrun(generated, clone, output)

    def test_symlinked_input_and_mutated_output_fail_closed(self):
        with tempfile.TemporaryDirectory(prefix="sora-xctestrun-mutation-") as temp:
            root = Path(temp).resolve()
            clone, generated, output, _ = self.fixture(root)
            link = root / "linked.xctestrun"
            os.symlink(generated.name, link)
            with self.assertRaises((MODULE.SanitizerError, OSError)):
                MODULE.sanitize_xctestrun(link, clone, output)
            result = MODULE.sanitize_xctestrun(generated, clone, output)
            output.write_bytes(output.read_bytes() + b"\n")
            with self.assertRaises(MODULE.SanitizerError):
                MODULE.verify_sanitized_xctestrun(
                    output,
                    clone,
                    result["sanitizedXctestrunSha256"],
                )

    def test_contract_lint_is_stable(self):
        MODULE.lint_contract()
        self.assertEqual(
            MODULE.CONTRACT_ID,
            "sora-ios-wallet-migration-xctestrun-sanitizer-v1",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
