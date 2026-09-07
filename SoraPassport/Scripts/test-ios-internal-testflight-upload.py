#!/usr/bin/env python3
"""Hermetic contract tests for the internal-only TestFlight upload path."""

from __future__ import annotations

import hashlib
import importlib.util
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
DELIVERY_SPEC = importlib.util.spec_from_file_location(
    "ios_internal_testflight_delivery", DELIVERY_VERIFIER
)
if DELIVERY_SPEC is None or DELIVERY_SPEC.loader is None:
    raise RuntimeError("delivery verifier cannot be loaded")
DELIVERY_MODULE = importlib.util.module_from_spec(DELIVERY_SPEC)
DELIVERY_SPEC.loader.exec_module(DELIVERY_MODULE)


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
            "SORA_IOS_INTERNAL_TESTFLIGHT_BUILD_NUMBER": "2026090704",
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
            "CURRENT_PROJECT_VERSION": "2026090704",
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
            'reviewed_base_revision="e886d7cfacbff119cb9bcb961cfc213882675636"',
            'reviewed_upstream="origin/codex/ios-wallet-upgrade-testflight-2026090704"',
            'reviewed_build_number="2026090704"',
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
            '--xcodebuild-log "${export_log}"',
            '--reviewed-profile "${reviewed_profile_path}"',
            'SORA_MIGRATION_EVIDENCE_SOURCE_REVISION=${source_revision}',
            'SORA_IOS_INTERNAL_TESTFLIGHT_EXPORT_OPTIONS_SHA256=${export_options_sha}',
            '--verify-snapshot "${contract_snapshot}"',
            '--verify-app-runtime-closure "${archived_app}"',
            'archived application runtime dependency closure is incomplete',
            '"appleDeliveryId": delivery_id',
            '"appleUploadState": "success"',
            'testFlightInternalTestingOnly": True',
            'externalTestFlightAuthorized": False',
            'appStorePromotionAuthorized": False',
            'productionRolloutAuthorized": False',
            "-exportArchive",
        ):
            self.assertIn(marker, source)
        self.assertEqual(source.count("-allowProvisioningUpdates"), 1)
        archive_command = source.split("if ! /usr/bin/xcodebuild", 1)[1].split(
            'archive >"${archive_log}"', 1
        )[0]
        for option in ("-disableAutomaticPackageResolution", "-skipPackageUpdates"):
            self.assertEqual(archive_command.count(option), 1)
        self.assertNotIn("ITSAppUsesNonExemptEncryption", source)
        self.assertNotIn("ITSEncryptionExportComplianceCode", source)
        self.assertNotIn('"PROVISIONING_PROFILE_SPECIFIER=', source)
        self.assertNotIn('"CODE_SIGN_IDENTITY=', source)
        self.assertNotIn('"CODE_SIGN_STYLE=', source)
        verifier = VERIFIER.read_text(encoding="utf-8")
        for marker in (
            'rev-parse HEAD 2>/dev/null)" != "${internal_testflight_source_revision}"',
            "rev-parse '@{upstream}' 2>/dev/null",
            "origin/codex/ios-wallet-upgrade-testflight-2026090704",
            "e886d7cfacbff119cb9bcb961cfc213882675636",
            "SORA_IOS_INTERNAL_TESTFLIGHT_BUILD_NUMBER",
            "CURRENT_PROJECT_VERSION",
            "PROVISIONING_PROFILE_SPECIFIER",
            "status --porcelain=v1 --untracked-files=normal",
            "source is not the exact clean pushed revision",
        ):
            self.assertIn(marker, verifier)
        jose_manifest = (ROOT / "VendorPackages" / "JOSESwift" / "Package.swift").read_text(
            encoding="utf-8"
        )
        self.assertTrue(hasattr(DELIVERY_MODULE, "verify_app_runtime_dependency_closure"))
        self.assertIn('type: .static, targets: ["JOSESwift"]', jose_manifest)
        self.assertNotIn('type: .dynamic, targets: ["JOSESwift"]', jose_manifest)

    def test_runtime_dependency_closure_rejects_missing_framework(self) -> None:
        with tempfile.TemporaryDirectory(
            prefix="sora-ios-runtime-closure.", dir="/private/tmp"
        ) as directory:
            root = Path(directory)
            app = root / "RuntimeClosure.app"
            framework_binary = (
                app / "Frameworks" / "JOSESwift.framework" / "JOSESwift"
            )
            framework_binary.parent.mkdir(parents=True)
            executable = app / "RuntimeClosure"
            library_source = root / "jose.c"
            library_source.write_text("int jose_fixture(void) { return 0; }\n", encoding="utf-8")
            main_source = root / "main.c"
            main_source.write_text(
                "extern int jose_fixture(void);\n"
                "int main(void) { return jose_fixture(); }\n",
                encoding="utf-8",
            )
            (app / "Info.plist").write_bytes(
                plistlib.dumps(
                    {
                        "CFBundleExecutable": executable.name,
                        "CFBundleIdentifier": "test.sora.runtime-closure",
                        "CFBundlePackageType": "APPL",
                    },
                    sort_keys=True,
                )
            )
            library_build = run(
                "/usr/bin/clang",
                "-dynamiclib",
                str(library_source),
                "-Wl,-install_name,@rpath/JOSESwift.framework/JOSESwift",
                "-o",
                str(framework_binary),
            )
            self.assertEqual(library_build.returncode, 0, library_build.stderr)
            executable_build = run(
                "/usr/bin/clang",
                str(main_source),
                str(framework_binary),
                "-Wl,-rpath,@executable_path/Frameworks",
                "-o",
                str(executable),
            )
            self.assertEqual(executable_build.returncode, 0, executable_build.stderr)

            DELIVERY_MODULE.verify_app_runtime_dependency_closure(app)
            cli = run(
                "/usr/bin/python3",
                "-I",
                "-S",
                str(DELIVERY_VERIFIER),
                "--verify-app-runtime-closure",
                str(app),
            )
            self.assertEqual(cli.returncode, 0, cli.stderr)
            framework_binary.unlink()
            with self.assertRaisesRegex(
                SystemExit, r"@rpath/JOSESwift\.framework/JOSESwift"
            ):
                DELIVERY_MODULE.verify_app_runtime_dependency_closure(app)

    def test_delivery_verifier_binds_exact_success_profile_and_options(self) -> None:
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
                "CFBundleVersion": "2026090704",
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
                    "uploadedBuildNumber": "2026090704",
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
            reviewed_profile = root / "reviewed.mobileprovision"
            reviewed_profile.write_bytes(b"synthetic reviewed profile\n")
            reviewed_profile_sha256 = hashlib.sha256(reviewed_profile.read_bytes()).hexdigest()
            log_root = root / "SoraPassport_0008-08-11_01-00-00.000.xcdistributionlogs"
            log_root.mkdir(mode=0o700)
            effective_options = dict(DELIVERY_MODULE.EXPECTED_EXPORT_OPTIONS)
            standard_log = log_root / "IDEDistribution.standard.log"
            standard_log.write_text(
                "2026-08-11 01:00:00 +0000 [MT] Starting export with options: "
                + json.dumps(effective_options, separators=(",", ":"), sort_keys=True)
                + "\n",
                encoding="utf-8",
            )
            verbose_log = log_root / "IDEDistribution.verbose.log"
            verbose_template = """2026-08-11 01:00:01 +0000 [MT] Evaluation for SoraPassport.app is <IDEProvisionableStatusEvaluation 0x1:
    Default = \"<_IDEProvisionableConfigurationSnapshot 0x2: provisioningStyle: 0, certificateSigningStyle: 2, team: <IDEProvisioningBasicTeam: 0x3; teamID='YLWWUD25VZ', teamName='(null)'>, bundleIdentifier: co.jp.soramitsu.sora, provisioningPurpose: app-store>\";
Profile:  <DVTEmbeddedProvisioningProfile 0x4: name: iOS Team Store Provisioning Profile: co.jp.soramitsu.sora, UUID: 7ae520bc-599b-48ae-abfa-627eef530f0c, teamName: Soramitsu Co., Ltd., isXcodeManaged: 1, filePath: <DVTFilePath:0x5:'{profile_path}'>>
Identity: 84AB95335BE14CAE9B050A353910F86FF2F9539B
Certificate <DVTSigningCertificate: 0x6; name='Apple Distribution: Soramitsu Co., Ltd. (YLWWUD25VZ)', hash='84AB95335BE14CAE9B050A353910F86FF2F9539B', serialNumber='1'>
2026-08-11 01:00:02 +0000 [MT] Running step: IDEDistributionPackagingStep
""".format(profile_path=reviewed_profile)
            verbose_log.write_text(verbose_template, encoding="utf-8")
            xcodebuild_log = root / "upload.log"
            xcodebuild_log.write_text(
                f'Created bundle at path "{log_root}".\n** EXPORT SUCCEEDED **\n',
                encoding="utf-8",
            )
            receipt_path = root / "receipt.json"
            delivery_id, _ = DELIVERY_MODULE.verify(
                archive_path,
                xcodebuild_log,
                reviewed_profile,
                receipt_path,
                "2026090704",
                expected_profile_sha256=reviewed_profile_sha256,
            )
            self.assertEqual(delivery_id, "12345678-1234-4234-8234-123456789abc")
            receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
            self.assertEqual(receipt["deliveryId"], "12345678-1234-4234-8234-123456789abc")
            self.assertEqual(receipt["provisioningProfileSha256"], reviewed_profile_sha256)
            self.assertTrue(receipt["provisioningProfileIsXcodeManaged"])
            self.assertTrue(receipt["testFlightInternalTestingOnly"])
            archive["Distributions"][0]["certificateSHA1"] = "0" * 40
            archive_path.write_bytes(plistlib.dumps(archive, sort_keys=True))
            with self.assertRaisesRegex(SystemExit, "distribution record identity drifted"):
                DELIVERY_MODULE.verify(
                    archive_path,
                    xcodebuild_log,
                    reviewed_profile,
                    root / "rejected.json",
                    "2026090704",
                    expected_profile_sha256=reviewed_profile_sha256,
                )

            for label, standard_text, verbose_text, profile_hash in (
                (
                    "internal-only option",
                    standard_log.read_text(encoding="utf-8").replace(
                        '"testFlightInternalTestingOnly":true',
                        '"testFlightInternalTestingOnly":false',
                    ),
                    verbose_template,
                    reviewed_profile_sha256,
                ),
                (
                    "profile UUID",
                    standard_log.read_text(encoding="utf-8"),
                    verbose_template.replace(
                        "7ae520bc-599b-48ae-abfa-627eef530f0c",
                        "00000000-0000-4000-8000-000000000000",
                    ),
                    reviewed_profile_sha256,
                ),
                (
                    "managed bit",
                    standard_log.read_text(encoding="utf-8"),
                    verbose_template.replace("isXcodeManaged: 1", "isXcodeManaged: 0"),
                    reviewed_profile_sha256,
                ),
                (
                    "profile name",
                    standard_log.read_text(encoding="utf-8"),
                    verbose_template.replace(
                        "iOS Team Store Provisioning Profile: co.jp.soramitsu.sora",
                        "unreviewed profile",
                    ),
                    reviewed_profile_sha256,
                ),
                (
                    "profile path",
                    standard_log.read_text(encoding="utf-8"),
                    verbose_template.replace(str(reviewed_profile), str(root / "unexpected.mobileprovision")),
                    reviewed_profile_sha256,
                ),
                (
                    "signing identity",
                    standard_log.read_text(encoding="utf-8"),
                    verbose_template.replace(
                        "Identity: 84AB95335BE14CAE9B050A353910F86FF2F9539B",
                        "Identity: 0000000000000000000000000000000000000000",
                    ),
                    reviewed_profile_sha256,
                ),
                (
                    "missing app evaluation",
                    standard_log.read_text(encoding="utf-8"),
                    verbose_template.replace("Evaluation for SoraPassport.app", "Evaluation for Other.app"),
                    reviewed_profile_sha256,
                ),
                (
                    "duplicate app evaluation",
                    standard_log.read_text(encoding="utf-8"),
                    verbose_template + verbose_template,
                    reviewed_profile_sha256,
                ),
                (
                    "profile hash",
                    standard_log.read_text(encoding="utf-8"),
                    verbose_template,
                    "0" * 64,
                ),
            ):
                with self.subTest(label=label):
                    standard_log.write_text(standard_text, encoding="utf-8")
                    verbose_log.write_text(verbose_text, encoding="utf-8")
                    with self.assertRaises(SystemExit):
                        DELIVERY_MODULE.verify_distribution_signing(
                            xcodebuild_log,
                            reviewed_profile,
                            expected_profile_sha256=profile_hash,
                        )
            standard_log.write_text(
                "2026-08-11 01:00:00 +0000 [MT] Starting export with options: "
                + json.dumps(effective_options, separators=(",", ":"), sort_keys=True)
                + "\n",
                encoding="utf-8",
            )
            verbose_log.write_text(verbose_template, encoding="utf-8")

    def test_wrapper_rejects_unreviewed_build_before_xcode(self) -> None:
        result = run(
            "/bin/sh",
            str(WRAPPER),
            "--archive-and-upload",
            "--build-number",
            "2026081602",
            "--app-store-build-lower-bound",
            "2026090703",
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
            ("CURRENT_PROJECT_VERSION", "2026081602"),
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
