#!/usr/bin/env python3
"""Hermetic contract tests for the internal-only TestFlight upload path."""

from __future__ import annotations

import hashlib
import json
import os
import plistlib
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "SoraPassport" / "Scripts"
WRAPPER = SCRIPTS / "upload-ios-internal-testflight.sh"
VERIFIER = SCRIPTS / "verify-modernization-dependencies.sh"
DELIVERY_VERIFIER = SCRIPTS / "verify-ios-internal-testflight-delivery.py"
EXPORT_OPTIONS = (
    ROOT / "SoraPassport" / "Configs" / "ios-internal-testflight-export-options.plist"
)


def run(*arguments: str, environment: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        list(arguments),
        cwd=ROOT,
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        timeout=30,
    )


def capability_environment() -> dict[str, str]:
    environment = dict(os.environ)
    for key in (
        "SORA_IOS_MIGRATION_CANDIDATE_ARCHIVE_MODE",
        "SORA_IOS_MIGRATION_CANDIDATE_ARCHIVE_ACTION",
        "SORA_IOS_MIGRATION_EVIDENCE_BUILD_MODE",
        "SORA_IOS_MIGRATION_EVIDENCE_BUILD_ACTION",
        "SORA_IOS_NONPROMOTING_RELEASE_TEST_MODE",
        "SORA_IOS_NONPROMOTING_RELEASE_TEST_ACTION",
    ):
        environment.pop(key, None)
    revision = "a" * 40
    environment.update(
        {
            "SORA_IOS_INTERNAL_TESTFLIGHT_UPLOAD_MODE": "sora-ios-internal-testflight-upload-v1",
            "SORA_IOS_INTERNAL_TESTFLIGHT_UPLOAD_ACTION": "archive",
            "SORA_IOS_INTERNAL_TESTFLIGHT_BUILD_NUMBER": "2026081002",
            "SORA_IOS_INTERNAL_TESTFLIGHT_SOURCE_REVISION": revision,
            "SORA_IOS_INTERNAL_TESTFLIGHT_EXPORT_OPTIONS_SHA256": hashlib.sha256(
                EXPORT_OPTIONS.read_bytes()
            ).hexdigest(),
            "SORA_MIGRATION_EVIDENCE_SOURCE_REVISION": revision,
            "ACTION": "install",
            "CONFIGURATION": "Release",
            "PLATFORM_NAME": "iphoneos",
            "EFFECTIVE_PLATFORM_NAME": "-iphoneos",
            "DEPLOYMENT_LOCATION": "YES",
            "TARGET_NAME": "SoraPassport",
            "PRODUCT_NAME": "SoraPassport",
            "PRODUCT_BUNDLE_IDENTIFIER": "co.jp.soramitsu.sora",
            "DEVELOPMENT_TEAM": "YLWWUD25VZ",
            "CODE_SIGN_IDENTITY": "iPhone Developer",
            "CODE_SIGN_STYLE": "Automatic",
            "CURRENT_PROJECT_VERSION": "2026081002",
            "PROVISIONING_PROFILE_SPECIFIER": "",
            "CODE_SIGN_ENTITLEMENTS": "SoraPassport/SoraPassport.entitlements",
            "INFOPLIST_FILE": "SoraPassport/Info.plist",
            "SORA_APPLICATION_CONFIG": "Release",
            "SORA_NAME": "SORA",
            "CODE_SIGNING_ALLOWED": "YES",
            "CODE_SIGNING_REQUIRED": "YES",
            "SDK_NAME": "iphoneos26.6",
            "PROJECT_DIR": str(ROOT),
        }
    )
    return environment


class InternalTestFlightUploadTests(unittest.TestCase):
    def test_wrapper_lints_and_shell_parses(self) -> None:
        syntax = run("/bin/sh", "-n", str(WRAPPER))
        self.assertEqual(syntax.returncode, 0, syntax.stderr)
        lint = run("/bin/sh", str(WRAPPER), "--lint-contract")
        self.assertEqual(lint.returncode, 0, lint.stderr)
        self.assertEqual(lint.stderr, "")
        self.assertEqual(
            lint.stdout,
            "iOS internal-only TestFlight upload contract: OK\n",
        )

    def test_export_options_are_permanently_internal_only(self) -> None:
        with EXPORT_OPTIONS.open("rb") as source:
            options = plistlib.load(source)
        self.assertEqual(
            options,
            {
                "destination": "upload",
                "manageAppVersionAndBuildNumber": False,
                "method": "app-store-connect",
                "signingStyle": "automatic",
                "stripSwiftSymbols": True,
                "teamID": "YLWWUD25VZ",
                "testFlightInternalTestingOnly": True,
                "uploadSymbols": False,
            },
        )

    def test_wrapper_binds_source_and_stays_non_authorizing(self) -> None:
        source = WRAPPER.read_text(encoding="utf-8")
        for marker in (
            'status --porcelain=v1 --untracked-files=normal',
            "rev-parse '@{upstream}'",
            'reviewed_base_revision="70553b0227ccf1d2564c0ca7cac0c52929aaf3d8"',
            'reviewed_upstream="origin/modernize"',
            'reviewed_build_number="2026081002"',
            'reviewed_signing_certificate_sha1="84AB95335BE14CAE9B050A353910F86FF2F9539B"',
            'reviewed_signing_certificate_sha256="d830d54bce8e583089f2ed8cf927fc12b60c9d591e560ffe6f5d2a71c91317fb"',
            'reviewed_archive_signing_certificate_sha1="1F57A04EB10B3665696663CDA0DBD893CF7FE886"',
            'reviewed_archive_signing_certificate_sha256="b479b9064f19cf90085926479768088416407c9e99e1537662014ba6805c179d"',
            'reviewed_profile_uuid="7ae520bc-599b-48ae-abfa-627eef530f0c"',
            'reviewed_archive_profile_uuid="908dc5a8-2b34-4617-94bb-f4a58ed5f4da"',
            '"embeddedProfileName": "iOS Team Provisioning Profile: co.jp.soramitsu.sora"',
            'reviewed_profile_sha256="19073a93bc09fe061e2346470b57aae1961aa38ad4c6b4922e0140bf8061bf93"',
            'reviewed_archive_profile_sha256="ede945565f09b23b4d92eca0752cb6ad52fe47b8a6ebb0e38f424ce64de79235"',
            '/bin/chmod 400 "${export_options_snapshot}"',
            'sha256_file "${export_options_snapshot}"',
            'delivery_verifier="${root}/SoraPassport/Scripts/verify-ios-internal-testflight-delivery.py"',
            '--archive-info "${archive_path}/Info.plist"',
            'SORA_MIGRATION_EVIDENCE_SOURCE_REVISION=${source_revision}',
            'SORA_IOS_INTERNAL_TESTFLIGHT_EXPORT_OPTIONS_SHA256=${export_options_sha}',
            '--verify-snapshot "${contract_snapshot}"',
            '"appleDeliveryId": delivery_id',
            '"appleUploadState": "success"',
            'testFlightInternalTestingOnly": True',
            'externalTestFlightAuthorized": False',
            'appStorePromotionAuthorized": False',
            'productionRolloutAuthorized": False',
            "-allowProvisioningUpdates",
            "-exportArchive",
        ):
            self.assertIn(marker, source)
        self.assertNotIn("ITSAppUsesNonExemptEncryption", source)
        self.assertNotIn("ITSEncryptionExportComplianceCode", source)
        self.assertNotIn('"PROVISIONING_PROFILE_SPECIFIER=', source)
        self.assertNotIn('"CODE_SIGN_IDENTITY=', source)
        self.assertNotIn('"CODE_SIGN_STYLE=', source)
        verifier = VERIFIER.read_text(encoding="utf-8")
        for marker in (
            'rev-parse HEAD 2>/dev/null)" != "${internal_testflight_source_revision}"',
            "rev-parse '@{upstream}' 2>/dev/null",
            "origin/modernize",
            "f1a2cab5debfa6213adfe087972dfc70d4d8688e",
            "SORA_IOS_INTERNAL_TESTFLIGHT_BUILD_NUMBER",
            "CURRENT_PROJECT_VERSION",
            "PROVISIONING_PROFILE_SPECIFIER",
            "status --porcelain=v1 --untracked-files=normal",
            "source is not the exact clean pushed revision",
        ):
            self.assertIn(marker, verifier)

    def test_delivery_verifier_accepts_exact_success_and_rejects_cert_drift(self) -> None:
        prepared = {
            "date": "2026-08-11T01:00:00Z",
            "errors": [],
            "infoMessages": [],
            "shortTitle": "Prepared",
            "state": "success",
            "title": "Prepared archive for uploading",
            "warnings": [],
        }
        uploaded = {
            "date": "2026-08-11T01:01:00Z",
            "errors": [],
            "infoMessages": [],
            "shortTitle": "Uploaded",
            "state": "success",
            "title": "Uploaded to Apple",
            "warnings": [],
        }
        archive = {
            "ApplicationProperties": {
                "CFBundleIdentifier": "co.jp.soramitsu.sora",
                "CFBundleShortVersionString": "3.8.7",
                "CFBundleVersion": "2026081002",
                "SigningIdentity": "Apple Development: Makoto Takemiya (6A4BK72ZFV)",
                "Team": "YLWWUD25VZ",
            },
            "ArchiveVersion": 2,
            "Distributions": [
                {
                    "adamId": "1457566711",
                    "certificateSHA1": "84AB95335BE14CAE9B050A353910F86FF2F9539B",
                    "destination": "upload",
                    "identifier": "12345678-1234-4234-8234-123456789abc",
                    "preparationEvent": prepared,
                    "providerId": "69a6de8e-8bb9-47e3-e053-5b8c7c11a4d1",
                    "task": "distribute",
                    "teamID": "YLWWUD25VZ",
                    "uploadDestination": "App Store",
                    "uploadedBuildNumber": "2026081002",
                    "uploadEvent": uploaded,
                }
            ],
            "Name": "SoraPassport",
            "SchemeName": "SoraPassport",
        }
        with tempfile.TemporaryDirectory(
            prefix="sora-ios-internal-testflight-delivery.", dir="/private/tmp"
        ) as directory:
            root = Path(directory)
            archive_path = root / "ArchiveInfo.plist"
            archive_path.write_bytes(plistlib.dumps(archive, sort_keys=True))
            receipt_path = root / "receipt.json"
            result = run(
                "/usr/bin/python3",
                "-I",
                "-S",
                str(DELIVERY_VERIFIER),
                "--archive-info",
                str(archive_path),
                "--receipt",
                str(receipt_path),
                "--build-number",
                "2026081002",
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("appleUploadState=success", result.stdout)
            receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
            self.assertEqual(receipt["deliveryId"], "12345678-1234-4234-8234-123456789abc")
            archive["Distributions"][0]["certificateSHA1"] = "0" * 40
            archive_path.write_bytes(plistlib.dumps(archive, sort_keys=True))
            rejected = run(
                "/usr/bin/python3",
                "-I",
                "-S",
                str(DELIVERY_VERIFIER),
                "--archive-info",
                str(archive_path),
                "--receipt",
                str(root / "rejected.json"),
                "--build-number",
                "2026081002",
            )
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("distribution record identity drifted", rejected.stderr)

    def test_wrapper_rejects_unreviewed_build_before_xcode(self) -> None:
        result = run(
            "/bin/sh",
            str(WRAPPER),
            "--archive-and-upload",
            "--build-number",
            "2026081003",
            "--app-store-build-lower-bound",
            "2026081001",
            "--derived-data-path",
            "/private/tmp/never-created-DerivedData",
            "--archive-path",
            "/private/tmp/never-created.xcarchive",
            "--export-path",
            "/private/tmp/never-created-upload",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("build number is not the reviewed one-time value", result.stderr)
        self.assertNotIn("xcodebuild", result.stderr)

    def test_capability_rejects_mode_action_and_platform_drift(self) -> None:
        for key, value in (
            ("SORA_IOS_INTERNAL_TESTFLIGHT_UPLOAD_MODE", "unreviewed"),
            ("SORA_IOS_INTERNAL_TESTFLIGHT_UPLOAD_ACTION", "export"),
            ("CURRENT_PROJECT_VERSION", "2026081003"),
            ("PLATFORM_NAME", "iphonesimulator"),
        ):
            with self.subTest(key=key):
                environment = capability_environment()
                environment[key] = value
                result = run("/bin/sh", str(VERIFIER), environment=environment)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(
                    "internal-only TestFlight archive capability is invalid",
                    result.stderr,
                )

    def test_action_without_capability_fails_closed(self) -> None:
        environment = dict(os.environ)
        environment.pop("SORA_IOS_INTERNAL_TESTFLIGHT_UPLOAD_MODE", None)
        environment["SORA_IOS_INTERNAL_TESTFLIGHT_UPLOAD_ACTION"] = "archive"
        result = run("/bin/sh", str(VERIFIER), environment=environment)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("action lacks its exact capability", result.stderr)


if __name__ == "__main__":
    unittest.main()
