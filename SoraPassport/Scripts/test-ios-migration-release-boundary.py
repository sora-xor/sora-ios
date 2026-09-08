#!/usr/bin/env python3
"""Regression checks for the iOS migration build/promotion phase boundary."""

from __future__ import annotations

import hashlib
import json
import os
import plistlib
import runpy
import shlex
import stat
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "SoraPassport" / "Scripts"
BUILDER = SCRIPTS / "build-ios-migration-evidence-candidate.sh"
ARCHIVER = SCRIPTS / "archive-ios-migration-candidate.sh"
HANDOFF = SCRIPTS / "create-ios-migration-candidate-handoff.py"
DERIVER = SCRIPTS / "derive-ios-migration-test-host.sh"
CLONE_WRAPPER = SCRIPTS / "create-ios-migration-installable-clone.sh"
EXACT_IPA_WRAPPER = SCRIPTS / "run-ios-migration-exact-ipa-evidence.sh"
COLLECTOR_WRAPPER = SCRIPTS / "collect-ios-migration-evidence.sh"
COLLECTION_RUNNER = SCRIPTS / "run-ios-migration-evidence-collection.sh"
RELEASE_TEST_RUNNER = SCRIPTS / "run-ios-release-tests.sh"
QUALIFICATION_WRAPPER = SCRIPTS / "verify-ios-migration-qualification.sh"
PROJECTOR = SCRIPTS / "derive-ios-migration-test-host.py"
PROJECTOR_HARNESS = SCRIPTS / "test-ios-migration-test-host-derivation.py"
PROMOTION = SCRIPTS / "verify-ios-migration-promotion-ipa.sh"
QUALIFIER = SCRIPTS / "verify-ios-migration-qualification.py"
DEPENDENCIES = SCRIPTS / "verify-modernization-dependencies.sh"
ROLLOUT = SCRIPTS / "verify-production-rollout.sh"
PROJECT = ROOT / "SoraPassport.xcodeproj" / "project.pbxproj"
SCHEME = (
    ROOT
    / "SoraPassport.xcodeproj"
    / "xcshareddata"
    / "xcschemes"
    / "SoraPassportMigrationEvidence.xcscheme"
)
CONTRACT = ROOT / "Fixtures/Modernization/ios-migration-qualification-contract-v1.json"
EXPORT_OPTIONS = ROOT / "SoraPassport/Configs/ios-migration-candidate-export-options.plist"
CI_WORKFLOW = ROOT / ".github/workflows/ios_modernization.yml"
REACHABILITY_MANAGER = (
    ROOT
    / "VendorPackages/shared-features-spm/Sources/SSFUtils/SSFUtils/Classes/Network"
    / "Reachability/ReachabilityManager.swift"
)


def run(*arguments: str, timeout: int = 30) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        list(arguments),
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        timeout=timeout,
    )


def archive_mode_environment() -> dict[str, str]:
    environment = dict(os.environ)
    environment.pop("SORA_IOS_MIGRATION_EVIDENCE_BUILD_MODE", None)
    environment.pop("SORA_IOS_MIGRATION_EVIDENCE_BUILD_ACTION", None)
    environment.update(
        {
            "SORA_IOS_MIGRATION_CANDIDATE_ARCHIVE_MODE": (
                "sora-ios-migration-observed-only-candidate-archive-v1"
            ),
            "SORA_IOS_MIGRATION_CANDIDATE_ARCHIVE_ACTION": "archive",
            "ACTION": "install",
            "CONFIGURATION": "Release",
            "PLATFORM_NAME": "iphoneos",
            "EFFECTIVE_PLATFORM_NAME": "-iphoneos",
            "DEPLOYMENT_LOCATION": "YES",
            "TARGET_NAME": "SoraPassport",
            "PRODUCT_NAME": "SoraPassport",
            "PRODUCT_BUNDLE_IDENTIFIER": "co.jp.soramitsu.sora",
            "DEVELOPMENT_TEAM": "YLWWUD25VZ",
            "CODE_SIGN_ENTITLEMENTS": "SoraPassport/SoraPassport.entitlements",
            "INFOPLIST_FILE": "SoraPassport/Info.plist",
            "SORA_APPLICATION_CONFIG": "Release",
            "SORA_NAME": "SORA",
            "CODE_SIGNING_ALLOWED": "YES",
            "CODE_SIGNING_REQUIRED": "YES",
            "SDK_NAME": "iphoneos26.5",
            "PROJECT_DIR": str(ROOT),
        }
    )
    return environment


class MigrationReleaseBoundaryTests(unittest.TestCase):
    def test_shell_entry_points_parse(self) -> None:
        for path in (
            BUILDER,
            ARCHIVER,
            DERIVER,
            CLONE_WRAPPER,
            EXACT_IPA_WRAPPER,
            COLLECTOR_WRAPPER,
            COLLECTION_RUNNER,
            RELEASE_TEST_RUNNER,
            QUALIFICATION_WRAPPER,
            PROMOTION,
            DEPENDENCIES,
            ROLLOUT,
        ):
            result = run("/bin/sh", "-n", str(path))
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_canonical_test_host_derivation_is_fixed_and_non_authorizing(self) -> None:
        lint = run("/bin/sh", str(DERIVER), "--lint-contract")
        self.assertEqual(lint.returncode, 0, lint.stderr)
        self.assertEqual(
            lint.stdout,
            "iOS migration observed test-host derivation wrapper: OK\n",
        )
        source = PROJECTOR.read_text(encoding="utf-8")
        wrapper = DERIVER.read_text(encoding="utf-8")
        for marker in (
            'CONTRACT_ID = "sora-ios-wallet-migration-test-host-derivation-v2"',
            'PROJECTION_CONTRACT_ID = "sora-ios-wallet-migration-canonical-app-projection-v2"',
            'RAW_TREE_CONTRACT_ID = "sora-ios-wallet-migration-raw-app-tree-v1"',
            '"releaseAuthorized": False',
            '"canonicalDerivedTestHostAccepted": True',
            '"exactExclusionRules": list(EXCLUSION_RULES)',
            '"derEntitlementDecoder": der_decoder',
            '"allNonSignatureFileRangesPrecedeTerminalSignature": True',
        ):
            self.assertIn(marker, source)
        self.assertIn("--verify-raw", wrapper)
        self.assertIn("qualification source contract changed", wrapper)
        self.assertNotIn("--verify-qualified", wrapper)
        self.assertNotIn("xcodebuild", wrapper)
        self.assertTrue(PROJECTOR_HARNESS.is_file())
        # This command runs a full 30-test child suite, which can exceed the
        # ordinary command allowance during a Release build. Keep it bounded.
        regressions = run(
            "/usr/bin/python3", "-B", "-I", "-S", str(PROJECTOR_HARNESS), timeout=120
        )
        self.assertEqual(regressions.returncode, 0, regressions.stderr)
        self.assertIn("Ran 30 tests", regressions.stderr)

    def test_observed_only_builder_contract_is_non_archivable(self) -> None:
        result = run("/bin/sh", str(BUILDER), "--lint-contract")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout,
            "iOS migration observed-only build contract: OK\n",
        )
        builder_source = BUILDER.read_text(encoding="utf-8")
        project_source = PROJECT.read_text(encoding="utf-8")
        self.assertEqual(
            project_source.count('COMPILER_FLAGS = "-warnings-as-errors";'),
            4,
        )
        for build_file in (
            "A10000E00000000000000001",
            "E71D0A010000000000000003",
            "B66B00012F5B000000000020",
            "E71D0A010000000000000005",
        ):
            line = next(
                item for item in project_source.splitlines()
                if item.lstrip().startswith(build_file)
            )
            self.assertIn('COMPILER_FLAGS = "-warnings-as-errors";', line)
        self.assertNotIn("SWIFT_TREAT_WARNINGS_AS_ERRORS=YES", builder_source)
        self.assertNotIn("GCC_TREAT_WARNINGS_AS_ERRORS=YES", builder_source)
        self.assertIn("-allowProvisioningUpdates", builder_source)
        self.assertIn("ENABLE_TESTABILITY=YES", builder_source)
        self.assertIn("build-for-testing", builder_source)
        self.assertNotIn("-exportArchive", builder_source)

        scheme = ET.parse(SCHEME).getroot()
        entries = scheme.findall("./BuildAction/BuildActionEntries/BuildActionEntry")
        self.assertEqual(len(entries), 3)
        self.assertTrue(all(entry.get("buildForArchiving") == "NO" for entry in entries))
        selected = [
            node.get("Identifier")
            for node in scheme.findall(
                "./TestAction/Testables/TestableReference/SelectedTests/Test"
            )
        ]
        self.assertEqual(len(selected), 6)
        self.assertFalse(any("Simulator" in value for value in selected if value))

    def test_builder_rejects_simulator_and_repository_output(self) -> None:
        simulator = run(
            "/bin/sh",
            str(BUILDER),
            "--build-for-testing",
            "--destination",
            "platform=iOS Simulator,id=ABCDEF12",
            "--derived-data-path",
            "/private/tmp/never-created",
        )
        self.assertNotEqual(simulator.returncode, 0)
        self.assertIn("physical iOS device", simulator.stderr)

        repository_output = run(
            "/bin/sh",
            str(BUILDER),
            "--build-for-testing",
            "--destination",
            "platform=iOS,id=00008110-001234567890001E",
            "--derived-data-path",
            str(ROOT / "DerivedData-forbidden"),
        )
        self.assertNotEqual(repository_output.returncode, 0)
        self.assertIn("outside the repository", repository_output.stderr)
        self.assertFalse((ROOT / "DerivedData-forbidden").exists())

    def test_candidate_archive_route_is_fixed_and_nonpromoting(self) -> None:
        lint = run("/bin/sh", str(ARCHIVER), "--lint-contract")
        self.assertEqual(lint.returncode, 0, lint.stderr)
        source = ARCHIVER.read_text(encoding="utf-8")
        self.assertIn("-scheme SoraPassport", source)
        self.assertIn("-configuration Release", source)
        self.assertIn("-destination 'generic/platform=iOS'", source)
        self.assertIn("-exportArchive", source)
        self.assertIn('--snapshot-export-options "${export_options_snapshot}"', source)
        self.assertIn('-exportOptionsPlist "${export_options_snapshot}"', source)
        self.assertIn('--verify-snapshot "${qualification_contract_snapshot}"', source)
        self.assertIn('--verify-export-options-source "${export_options_sha}"', source)
        self.assertIn('--export-options-sha "${export_options_sha}"', source)
        self.assertIn('SORA_IOS_MIGRATION_CANDIDATE_ARCHIVE_ACTION=archive', source)
        self.assertNotIn("SWIFT_TREAT_WARNINGS_AS_ERRORS=YES", source)
        self.assertNotIn("GCC_TREAT_WARNINGS_AS_ERRORS=YES", source)
        self.assertIn('--archive-and-export-reproducible', source)
        self.assertIn('-derivedDataPath "${derived_data_path}"', source)
        self.assertIn('--capture-build-manifest', source)
        self.assertIn('--signing-receipt "${signing_receipt_snapshot}"', source)
        self.assertIn('/usr/bin/install -m 600', source)
        self.assertIn('"${IOS_SIGNING_IDENTITY_RECEIPT_PATH}"', source)
        self.assertEqual(source.count('CODE_SIGN_STYLE=Manual'), 2)
        self.assertEqual(
            source.count(
                '"CODE_SIGN_IDENTITY=${production_distribution_certificate_sha1}"'
            ),
            2,
        )
        self.assertEqual(
            source.count(
                '"PROVISIONING_PROFILE_SPECIFIER=${production_provisioning_profile_uuid}"'
            ),
            2,
        )
        self.assertEqual(source.count('"CURRENT_PROJECT_VERSION=${build_number}"'), 2)
        self.assertIn('IOS_APP_STORE_BUILD_NUMBER_LOWER_BOUND', source)
        self.assertIn('--build-number "${build_number}"', source)
        self.assertIn(
            '--app-store-build-lower-bound "${app_store_build_number_lower_bound}"',
            source,
        )
        self.assertIn('plutil -extract CFBundleVersion raw -expect string', source)
        self.assertIn('plutil -extract ipa.buildVersion raw -expect string', source)
        self.assertIn('status --porcelain=v1 --untracked-files=normal', source)
        self.assertIn('IOS_MIGRATION_EVIDENCE_AUTHORIZATION_KEY_ID', source)
        self.assertIn('IOS_MIGRATION_EVIDENCE_AUTHORIZATION_PUBLIC_KEY_X963_BASE64', source)
        self.assertIn('IOS_MIGRATION_EVIDENCE_SOURCE_REVISION', source)
        self.assertIn('--validate-authority-binding', source)
        self.assertIn('SORA_MIGRATION_EVIDENCE_QUALIFICATION_CONTRACT_SHA256=${qualification_contract_sha}', source)
        self.assertNotIn("-upload", source)
        self.assertNotIn("altool", source)
        self.assertNotIn("notarytool", source)
        self.assertNotIn("verify-production-rollout", source)

        environment = dict(os.environ)
        environment["IOS_APP_STORE_BUILD_NUMBER_LOWER_BOUND"] = "2026081001"
        repository_output = subprocess.run(
            [
                "/bin/sh",
                str(ARCHIVER),
                "--archive-and-export",
                "--build-number",
                "2026081002",
                "--archive-path",
                str(ROOT / "forbidden.xcarchive"),
                "--export-path",
                str(ROOT / "forbidden-export"),
            ],
            cwd=ROOT,
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            timeout=30,
        )
        self.assertNotEqual(repository_output.returncode, 0)
        self.assertIn("mode 0700", repository_output.stderr)
        self.assertFalse((ROOT / "forbidden.xcarchive").exists())
        self.assertFalse((ROOT / "forbidden-export").exists())

        stale_environment = dict(os.environ)
        stale_environment["IOS_APP_STORE_BUILD_NUMBER_LOWER_BOUND"] = "2026081002"
        stale_build = subprocess.run(
            [
                "/bin/sh",
                str(ARCHIVER),
                "--archive-and-export",
                "--build-number",
                "2026081002",
                "--archive-path",
                "/private/tmp/never-created.xcarchive",
                "--export-path",
                "/private/tmp/never-created-export",
            ],
            cwd=ROOT,
            env=stale_environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            timeout=30,
        )
        self.assertNotEqual(stale_build.returncode, 0)
        self.assertIn("greater than the controller-provided App Store lower bound", stale_build.stderr)

    def test_candidate_archive_capability_rejects_action_config_and_platform_drift(self) -> None:
        for key, value in (
            ("ACTION", "build"),
            ("CONFIGURATION", "Debug"),
            ("PLATFORM_NAME", "iphonesimulator"),
        ):
            environment = archive_mode_environment()
            environment[key] = value
            result = subprocess.run(
                ["/bin/sh", str(DEPENDENCIES)],
                cwd=ROOT,
                env=environment,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
                timeout=10,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(
                "observed-only candidate archive capability is invalid",
                result.stderr,
            )

    def test_candidate_handoff_binds_exact_ipa_and_stays_blocked(self) -> None:
        with tempfile.TemporaryDirectory(
            prefix="sora-ios-migration-handoff.", dir="/private/tmp"
        ) as temporary:
            export_root = Path(temporary) / "candidate-export"
            export_root.mkdir(mode=0o700)
            ipa = export_root / "Sora.ipa"
            info = plistlib.dumps(
                {
                    "CFBundleExecutable": "SoraPassport",
                    "CFBundleIdentifier": "co.jp.soramitsu.sora",
                    "CFBundleShortVersionString": "1.2.3",
                    "CFBundleVersion": "123",
                },
                fmt=plistlib.FMT_BINARY,
            )
            executable = b"synthetic-archived-application" * 32
            with zipfile.ZipFile(ipa, "w", compression=zipfile.ZIP_STORED) as archive:
                for name, raw in (
                    ("Payload/SoraPassport.app/Info.plist", info),
                    ("Payload/SoraPassport.app/SoraPassport", executable),
                ):
                    entry = zipfile.ZipInfo(name)
                    entry.external_attr = (stat.S_IFREG | 0o644) << 16
                    archive.writestr(entry, raw)
            contract_sha = hashlib.sha256(b"source-contract").hexdigest()
            export_options_sha = hashlib.sha256(EXPORT_OPTIONS.read_bytes()).hexdigest()
            result = run(
                "/usr/bin/python3",
                "-I",
                "-S",
                str(HANDOFF),
                "--create",
                "--export-root",
                str(export_root),
                "--qualification-contract-sha",
                contract_sha,
                "--export-options-sha",
                export_options_sha,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            handoff_path = export_root / "ios-migration-candidate-handoff.json"
            handoff = json.loads(handoff_path.read_text(encoding="utf-8"))
            self.assertEqual(handoff["status"], "observed")
            self.assertIs(handoff["releaseAuthorized"], False)
            self.assertIs(handoff["promotionAuthorized"], False)
            self.assertEqual(handoff["exportOptionsSha256"], export_options_sha)
            self.assertEqual(handoff["ipa"]["sha256"], hashlib.sha256(ipa.read_bytes()).hexdigest())
            self.assertEqual(
                handoff["ipa"]["executableSha256"],
                hashlib.sha256(executable).hexdigest(),
            )
            self.assertEqual(handoff["exactAppTestHandoff"]["status"], "pending")
            self.assertIs(
                handoff["exactAppTestHandoff"]["rebuiltTestHostAccepted"], False
            )
            self.assertEqual(len(handoff["blockingReasons"]), 1)

            handoff_path.unlink()
            unexpected_directory = export_root / "unexpected"
            unexpected_directory.mkdir()
            unsafe_export = run(
                "/usr/bin/python3",
                "-I",
                "-S",
                str(HANDOFF),
                "--create",
                "--export-root",
                str(export_root),
                "--qualification-contract-sha",
                contract_sha,
                "--export-options-sha",
                export_options_sha,
            )
            self.assertNotEqual(unsafe_export.returncode, 0)
            self.assertIn("symbolic, special, linked, or nested", unsafe_export.stderr)
            unexpected_directory.rmdir()

            ipa.unlink()
            with zipfile.ZipFile(ipa, "w", compression=zipfile.ZIP_STORED) as archive:
                unsafe = zipfile.ZipInfo("../Payload/SoraPassport.app/Info.plist")
                unsafe.external_attr = (stat.S_IFREG | 0o644) << 16
                archive.writestr(unsafe, info)
            unsafe_ipa = run(
                "/usr/bin/python3",
                "-I",
                "-S",
                str(HANDOFF),
                "--create",
                "--export-root",
                str(export_root),
                "--qualification-contract-sha",
                contract_sha,
                "--export-options-sha",
                export_options_sha,
            )
            self.assertNotEqual(unsafe_ipa.returncode, 0)
            self.assertIn("unsafe ZIP member", unsafe_ipa.stderr)

    def test_export_options_snapshot_is_exact_and_rechecked(self) -> None:
        self.assertEqual(
            plistlib.loads(EXPORT_OPTIONS.read_bytes()),
            {
                "destination": "export",
                "manageAppVersionAndBuildNumber": False,
                "method": "app-store-connect",
                "provisioningProfiles": {
                    "co.jp.soramitsu.sora":
                        "7ae520bc-599b-48ae-abfa-627eef530f0c",
                },
                "signingCertificate":
                    "84AB95335BE14CAE9B050A353910F86FF2F9539B",
                "signingStyle": "manual",
                "stripSwiftSymbols": True,
                "teamID": "YLWWUD25VZ",
                "uploadSymbols": False,
            },
        )
        with tempfile.TemporaryDirectory(
            prefix="sora-ios-migration-export-options.", dir="/private/tmp"
        ) as temporary:
            snapshot = Path(temporary) / "export-options.plist"
            expected_sha = hashlib.sha256(EXPORT_OPTIONS.read_bytes()).hexdigest()
            captured = run(
                "/usr/bin/python3",
                "-I",
                "-S",
                str(HANDOFF),
                "--snapshot-export-options",
                str(snapshot),
            )
            self.assertEqual(captured.returncode, 0, captured.stderr)
            self.assertEqual(captured.stdout, f"exportOptionsSha256={expected_sha}\n")
            admitted = run(
                "/usr/bin/python3",
                "-I",
                "-S",
                str(HANDOFF),
                "--verify-export-options-snapshot",
                str(snapshot),
                expected_sha,
            )
            self.assertEqual(admitted.returncode, 0, admitted.stderr)
            self.assertEqual(admitted.stdout, f"exportOptionsSha256={expected_sha}\n")

            snapshot.write_bytes(snapshot.read_bytes() + b"\n")
            changed = run(
                "/usr/bin/python3",
                "-I",
                "-S",
                str(HANDOFF),
                "--verify-export-options-snapshot",
                str(snapshot),
                expected_sha,
            )
            self.assertNotEqual(changed.returncode, 0)
            self.assertIn("protected digest", changed.stderr)

    def test_promotion_wrapper_rejects_nonabsolute_ipa_before_admission(self) -> None:
        result = run(
            "/bin/sh",
            str(PROMOTION),
            "--verify-qualified-ipa",
            "relative/Sora.ipa",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must be absolute", result.stderr)

    def test_promotion_contract_and_descriptor_hash_are_fail_closed(self) -> None:
        lint = run("/bin/sh", str(PROMOTION), "--lint-contract")
        self.assertEqual(lint.returncode, 0, lint.stderr)
        namespace = runpy.run_path(str(QUALIFIER))
        hash_completed_ipa = namespace["hash_completed_ipa"]
        with tempfile.TemporaryDirectory(
            prefix="sora-ios-migration-release-boundary.", dir="/private/tmp"
        ) as temporary:
            candidate = Path(temporary) / "Sora.ipa"
            raw = b"completed-ipa-regression\x00" * 127
            candidate.write_bytes(raw)
            expected = hashlib.sha256(raw).hexdigest()
            self.assertEqual(hash_completed_ipa(candidate, expected), (expected, len(raw)))

            alias = Path(temporary) / "Sora-alias.ipa"
            os.link(candidate, alias)
            with self.assertRaises(RuntimeError):
                hash_completed_ipa(candidate, expected)
            alias.unlink()

            link_parent = Path(temporary).with_name(Path(temporary).name + "-link")
            link_parent.symlink_to(Path(temporary), target_is_directory=True)
            try:
                with self.assertRaises(RuntimeError):
                    hash_completed_ipa(link_parent / "Sora.ipa", expected)
            finally:
                link_parent.unlink()

    def test_qualification_rejects_stale_v7_v3_and_mixed_wire_schemas(self) -> None:
        namespace = runpy.run_path(str(QUALIFIER))
        require_current = namespace["require_current_qualified_schemas"]
        receipt = {
            "schemaVersion": 8,
            "contractId": "sora-ios-wallet-migration-qualification-v8",
            "platform": "ios",
            "status": "qualified",
            "blockingReasons": [],
        }
        evidence = {
            "schemaVersion": 4,
            "contractId": "sora-ios-wallet-migration-evidence-v4",
            "platform": "ios",
            "status": "qualified",
            "blockingReasons": [],
        }
        require_current(receipt, evidence)
        for version in range(1, 8):
            stale_receipt = dict(
                receipt,
                schemaVersion=version,
                contractId=f"sora-ios-wallet-migration-qualification-v{version}",
            )
            with self.subTest(receipt_version=version), self.assertRaises(RuntimeError):
                require_current(stale_receipt, evidence)
        for version in range(1, 4):
            stale_evidence = dict(
                evidence,
                schemaVersion=version,
                contractId=f"sora-ios-wallet-migration-evidence-v{version}",
            )
            with self.subTest(evidence_version=version), self.assertRaises(RuntimeError):
                require_current(receipt, stale_evidence)

        self.assertEqual(
            namespace["IDENTITY_KEYS"],
            {
                "productionIpaSha256",
                "installedAppRawTreeSha256",
                "installedAppRawTreeRecordByteCount",
                "installedExecutableSha256",
                "installedExecutableByteCount",
                "productionCanonicalProjectionSha256",
                "installedCanonicalProjectionSha256",
                "canonicalProjectionReceiptSha256",
                "canonicalProjectorSourceSha256",
                "deviceClasses",
                "operatingSystemBuilds",
            },
        )
        self.assertIn("installedClone", namespace["COLLECTION_ROOT_KEYS"])
        self.assertNotIn("derivedTestHost", namespace["COLLECTION_ROOT_KEYS"])

        require_collection = namespace["require_current_collection_raw_schemas"]
        current_collection = {
            "schemaVersion": 3,
            "contractId": "sora-ios-wallet-migration-collection-receipt-v3",
            "rawInputSet": {
                "contractId": "sora-ios-wallet-migration-raw-input-set-v3"
            },
        }
        require_collection(current_collection)
        for version in (1, 2):
            stale_collection = dict(
                current_collection,
                schemaVersion=version,
                contractId=f"sora-ios-wallet-migration-collection-receipt-v{version}",
            )
            with self.subTest(collection_version=version), self.assertRaises(RuntimeError):
                require_collection(stale_collection)
            stale_raw = dict(current_collection)
            stale_raw["rawInputSet"] = {
                "contractId": f"sora-ios-wallet-migration-raw-input-set-v{version}"
            }
            with self.subTest(raw_version=version), self.assertRaises(RuntimeError):
                require_collection(stale_raw)

        require_aggregate = namespace["require_current_public_aggregate_schema"]
        for stem in (
            "retained-snapshot-manifest",
            "keychain-evidence",
            "device-execution-evidence",
        ):
            current_id = f"sora-ios-wallet-migration-{stem}-v4"
            require_aggregate(
                {"schemaVersion": 4, "contractId": current_id},
                current_id,
            )
            for version in range(1, 4):
                stale_id = f"sora-ios-wallet-migration-{stem}-v{version}"
                with self.subTest(
                    aggregate=stem,
                    aggregate_version=version,
                ), self.assertRaises(RuntimeError):
                    require_aggregate(
                        {"schemaVersion": version, "contractId": stale_id},
                        current_id,
                    )

    def test_nonpromoting_release_simulator_runner_is_exact_and_non_authorizing(
        self,
    ) -> None:
        lint = run("/bin/sh", str(RELEASE_TEST_RUNNER), "--lint-contract")
        self.assertEqual(lint.returncode, 0, lint.stderr)
        self.assertEqual(
            lint.stdout,
            "iOS non-promoting Release simulator test contract: OK\n",
        )

        runner = RELEASE_TEST_RUNNER.read_text(encoding="utf-8")
        action = runner.split("exec /usr/bin/xcodebuild", 1)[1]
        for required in (
            "\n    test \\",
            "\n    -project \"${project}\" \\",
            "\n    -scheme SoraPassport \\",
            "\n    -configuration Release \\",
            "\n    -destination \"${destination}\" \\",
            "\n    -derivedDataPath \"${derived_data_path}\" \\",
            "\n    -resultBundlePath \"${result_bundle_path}\" \\",
            "-skip-testing:SoraPassportIntegrationTests/WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedDeviceRunBinding",
            "-skip-testing:SoraPassportIntegrationTests/WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedDeviceScenarioEvidence",
            "-skip-testing:SoraPassportIntegrationTests/WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedKeychainCohortEvidence",
            "-skip-testing:SoraPassportUITests/RetainedMigrationEvidenceUITests/testExecuteAuthorizedRetainedMigrationCase",
            "SORA_IOS_NONPROMOTING_RELEASE_TEST_MODE=sora-ios-nonpromoting-release-simulator-test-v1",
            "SORA_IOS_NONPROMOTING_RELEASE_TEST_ACTION=test",
            "CODE_SIGNING_ALLOWED=NO",
            "CODE_SIGNING_REQUIRED=NO",
            "ENABLE_TESTABILITY=YES",
            "ONLY_ACTIVE_ARCH=YES",
            "ARCHS=arm64",
            "EXCLUDED_ARCHS=x86_64",
        ):
            self.assertIn(required, action)
        self.assertEqual(action.count("-skip-testing:"), 4)
        for forbidden in (
            " archive ",
            "-exportArchive",
            "-exportOptionsPlist",
            "upload",
            "allowProvisioningUpdates",
        ):
            self.assertNotIn(forbidden, action)
        self.assertIn("must be a fresh path", runner)
        self.assertIn("parent must have mode 0700", runner)
        self.assertIn("must stay outside the repository", runner)
        self.assertIn("result-bundle path must end in .xcresult", runner)

        source = DEPENDENCIES.read_text(encoding="utf-8")
        branch = source.index('if [ -n "${release_test_mode}" ]; then')
        self.assertLess(branch, source.index("# Every configuration executes"))
        self.assertEqual(source.count('[ -n "${release_test_mode}" ] ||'), 3)
        for required in (
            '[ "${release_test_mode}" != "sora-ios-nonpromoting-release-simulator-test-v1" ]',
            '[ "${release_test_action}" != "test" ]',
            '[ "${ACTION:-}" != "build" ]',
            '[ "${CONFIGURATION:-}" != "Release" ]',
            '[ "${PLATFORM_NAME:-}" != "iphonesimulator" ]',
            '[ "${EFFECTIVE_PLATFORM_NAME:-}" != "-iphonesimulator" ]',
            '[ "${DEPLOYMENT_LOCATION:-NO}" != "NO" ]',
            '[ "${CODE_SIGNING_ALLOWED:-YES}" != "NO" ]',
            '[ "${CODE_SIGNING_REQUIRED:-YES}" != "NO" ]',
            '[ "${ENABLE_TESTABILITY:-NO}" != "YES" ]',
            '[ "${ONLY_ACTIVE_ARCH:-NO}" != "YES" ]',
            '[ "${ARCHS:-}" != "arm64" ]',
            '[ "${EXCLUDED_ARCHS:-}" != "x86_64" ]',
            "optimized simulator XCTest build is non-authorizing",
        ):
            self.assertIn(required, source)
        self.assertIn(
            '[ "$(/usr/bin/printf \'%s\\n\' "${ios_gate_release_test_action}" | /usr/bin/grep -Fc -- \'-skip-testing:\')" -ne 4 ]',
            source,
        )

        info_plist_dependency = "$(TARGET_BUILD_DIR)/$(INFOPLIST_PATH)"
        project_source = PROJECT.read_text(encoding="utf-8")
        self.assertEqual(project_source.count(f'"{info_plist_dependency}",'), 2)
        canonical_dependency = run(
            "/bin/sh",
            str(DEPENDENCIES),
            "--lint-ios-google-signin-phase-dependencies",
            str(PROJECT),
        )
        self.assertEqual(canonical_dependency.returncode, 0, canonical_dependency.stderr)
        self.assertIn(
            'verify_google_signin_info_plist_phase_dependencies "${ios_gate_project}"',
            source,
        )

        dependency_offsets = []
        search_offset = 0
        while True:
            dependency_offset = project_source.find(
                info_plist_dependency, search_offset
            )
            if dependency_offset < 0:
                break
            dependency_offsets.append(dependency_offset)
            search_offset = dependency_offset + len(info_plist_dependency)
        self.assertEqual(len(dependency_offsets), 2)
        for mutation_index, dependency_offset in enumerate(dependency_offsets):
            with self.subTest(mutation_index=mutation_index), tempfile.TemporaryDirectory(
                prefix="sora-google-signin-phase-mutation."
            ) as mutation_directory:
                mutated_source = (
                    project_source[:dependency_offset]
                    + "$(TARGET_BUILD_DIR)/Wrong-Info.plist"
                    + project_source[dependency_offset + len(info_plist_dependency) :]
                )
                mutated_project = Path(mutation_directory) / "project.pbxproj"
                mutated_project.write_text(mutated_source, encoding="utf-8")
                rejected = run(
                    "/bin/sh",
                    str(DEPENDENCIES),
                    "--lint-ios-google-signin-phase-dependencies",
                    str(mutated_project),
                )
                self.assertNotEqual(rejected.returncode, 0)
                self.assertIn(
                    "must declare the exact processed Info.plist input dependency",
                    rejected.stderr,
                )

        reachability_source = REACHABILITY_MANAGER.read_text(encoding="utf-8")
        canonical_reachability = run(
            "/bin/sh",
            str(DEPENDENCIES),
            "--lint-ios-reachability-listener-synchronization",
            str(REACHABILITY_MANAGER),
        )
        self.assertEqual(
            canonical_reachability.returncode,
            0,
            canonical_reachability.stderr,
        )
        self.assertIn(
            'verify_reachability_listener_synchronization "${ios_gate_reachability_manager}"',
            source,
        )
        reachability_mutations = (
            (
                "missing-lock",
                reachability_source.replace(
                    "        listenersLock.lock()",
                    "        // listener lock removed by mutation",
                    1,
                ),
            ),
            (
                "unpruned-snapshot",
                reachability_source.replace(
                    "            return listeners.compactMap { $0.listener }",
                    "            return []",
                    1,
                ),
            ),
            (
                "callback-under-lock",
                reachability_source.replace(
                    "        liveListeners.forEach { $0.didChangeReachability(by: self) }",
                    "        withListenersLock { liveListeners.forEach { $0.didChangeReachability(by: self) } }",
                    1,
                ),
            ),
            (
                "unserialized-notifier",
                reachability_source.replace(
                    "        notifierLock.lock()",
                    "        // notifier lock removed by mutation",
                    1,
                ),
            ),
        )
        for mutation_name, mutated_source in reachability_mutations:
            with self.subTest(mutation_name=mutation_name), tempfile.TemporaryDirectory(
                prefix="sora-reachability-listener-mutation."
            ) as mutation_directory:
                self.assertNotEqual(mutated_source, reachability_source)
                mutated_manager = Path(mutation_directory) / "ReachabilityManager.swift"
                mutated_manager.write_text(mutated_source, encoding="utf-8")
                rejected = run(
                    "/bin/sh",
                    str(DEPENDENCIES),
                    "--lint-ios-reachability-listener-synchronization",
                    str(mutated_manager),
                )
                self.assertNotEqual(rejected.returncode, 0)
                self.assertIn("ReachabilityManager", rejected.stderr)

        physical = run(
            "/bin/sh",
            str(RELEASE_TEST_RUNNER),
            "--test",
            "--destination",
            "platform=iOS,id=physical-device,arch=arm64",
            "--derived-data-path",
            "/private/tmp/sora-release-test-derived",
            "--result-bundle-path",
            "/private/tmp/sora-release-test.xcresult",
        )
        self.assertNotEqual(physical.returncode, 0)
        self.assertIn("require an iOS Simulator destination", physical.stderr)

        with tempfile.TemporaryDirectory(
            prefix=".sora-release-test-boundary.", dir=ROOT
        ) as repository_output:
            os.chmod(repository_output, stat.S_IRWXU)
            rejected = run(
                "/bin/sh",
                str(RELEASE_TEST_RUNNER),
                "--test",
                "--destination",
                "platform=iOS Simulator,name=iPhone 16 Pro,OS=18.4,arch=arm64",
                "--derived-data-path",
                str(Path(repository_output) / "DerivedData"),
                "--result-bundle-path",
                str(Path(repository_output) / "Release.xcresult"),
            )
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("must stay outside the repository", rejected.stderr)

    def test_release_build_exception_is_exact_and_observed_only(self) -> None:
        source = DEPENDENCIES.read_text(encoding="utf-8")
        archive_source = ARCHIVER.read_text(encoding="utf-8")
        mode = "sora-ios-migration-observed-only-build-v1"
        self.assertEqual(source.split('manifest="${root}', 1)[0].count(mode), 1)
        self.assertIn('[ "${ACTION:-}" != "build" ]', source)
        self.assertIn('[ "${CONFIGURATION:-}" != "Release" ]', source)
        self.assertIn('[ "${PLATFORM_NAME:-}" != "iphoneos" ]', source)
        self.assertIn('[ "${DEPLOYMENT_LOCATION:-NO}" != "NO" ]', source)
        self.assertLess(
            source.index("migration_evidence_build_mode="),
            source.index("# Every configuration executes"),
        )
        self.assertEqual(
            source.count(
                '/bin/sh "${migration_qualification_validator}" --verify-qualified'
            ),
            1,
        )
        self.assertIn(
            'sora-ios-migration-observed-only-candidate-archive-v1', source
        )
        self.assertIn('[ "${ACTION:-}" != "install" ]', source)
        self.assertIn(
            'if [ "${migration_candidate_archive_active}" = "true" ]; then', source
        )
        self.assertIn(
            "migration and IPA-bound post-export admission are deferred", source
        )
        self.assertIn(
            "--lint-ios-migration-release-source-gate", source
        )
        self.assertIn(
            "iOS migration Release source gate: OK (94 migration tests + 8 internal-TestFlight tests + 17 Release-package tests + 15 Taira-admission tests + 10 vendored-binary tests + 10 signing-identity tests + 20 production-promotion tests, 13 lints, shell/Swift parse)",
            source,
        )
        for suite, expected in (
            ("ios_gate_projector_suite", 30),
            ("ios_gate_clone_suite", 3),
            ("ios_gate_controller_suite", 24),
            ("ios_gate_sanitizer_suite", 6),
            ("ios_gate_collector_suite", 16),
            ("ios_gate_boundary_suite", 15),
            ("ios_gate_production_promotion_suite", 20),
        ):
            self.assertIn(
                f'run_exact_ios_migration_suite "${{{suite}}}" {expected}',
                source,
            )
        self.assertIn('[ "${ios_gate_test_total}" -eq 94 ]', source)
        self.assertIn(
            'run_exact_ios_migration_suite "${ios_gate_release_package_suite}" 17 release-reproducibility-package',
            source,
        )
        self.assertIn(
            'run_exact_ios_migration_suite "${ios_gate_taira_deployment_suite}" 15 taira-deployment-admission',
            source,
        )
        self.assertIn(
            'run_exact_ios_migration_suite "${ios_gate_vendored_binary_suite}" 10 vendored-binary-qualification',
            source,
        )
        self.assertIn(
            'run_exact_ios_migration_suite "${ios_gate_signing_identity_suite}" 10 production-signing-identity',
            source,
        )
        self.assertIn(
            '/usr/bin/xcrun swiftc -frontend -parse "${ios_gate_swift}"',
            source,
        )
        self.assertIn(
            'ios_gate_account_creation_helper="${root}/SoraPassportTests/Helpers/AccountCreationHelper.swift"',
            source,
        )
        self.assertIn(
            "'SelectedWalletSettings.shared' \"${ios_gate_account_creation_helper}\"",
            source,
        )
        self.assertIn(
            '! verify_ios_migration_shared_lifecycle_test_scope "${ios_gate_modernization_tests}"',
            source,
        )
        lifecycle_function = "verify_ios_migration_shared_lifecycle_test_scope() {" + source.split(
            "verify_ios_migration_shared_lifecycle_test_scope() {", 1
        )[1].split("\nrun_ios_migration_release_source_gate()", 1)[0]
        lifecycle_tests = (
            ROOT / "SoraPassportTests/Common/Modernization/WalletModernizationTests.swift"
        ).read_text()
        lifecycle_cases = {
            "production-startup-regressions": (lifecycle_tests, True),
            "missing-probe": (lifecycle_tests.replace(
                "WalletLifecycleCoordinator.shared.tryAcquire()", "isolated.tryAcquire()", 1
            ), False),
            "changed-operation": (lifecycle_tests.replace(
                "WalletLifecycleCoordinator.shared.tryAcquire()", "WalletLifecycleCoordinator.shared.acquire()", 1
            ), False),
            "unrelated-test": (lifecycle_tests + "\n    func testUnrelatedSharedUse() {\n"
                "        let lease = WalletLifecycleCoordinator.shared.acquire()\n    }\n", False),
            "duplicate-probe": (lifecycle_tests.replace(
                "let competing = WalletLifecycleCoordinator.shared.tryAcquire()",
                "let competing = WalletLifecycleCoordinator.shared.tryAcquire()\n"
                "                    let competing = WalletLifecycleCoordinator.shared.tryAcquire()", 1
            ), False),
        }
        with tempfile.TemporaryDirectory(prefix="startup-lifecycle-scope-") as temporary:
            fixture = Path(temporary) / "WalletModernizationTests.swift"
            for case, (contents, accepted) in lifecycle_cases.items():
                with self.subTest(lifecycle_scope=case):
                    fixture.write_text(contents)
                    checked = run("/bin/sh", "-c", lifecycle_function +
                        '\nverify_ios_migration_shared_lifecycle_test_scope "$1"', "scope-check", str(fixture))
                    self.assertEqual(checked.returncode == 0, accepted, checked.stderr)
        self.assertIn(
            "'Task { [weak self] in' \"${ios_gate_websocket_engine}\"",
            source,
        )
        self.assertIn('ios_gate_authorization_key_count', source)
        project_source = PROJECT.read_text(encoding="utf-8")
        self.assertEqual(
            project_source.count('COMPILER_FLAGS = "-warnings-as-errors";'),
            4,
        )
        self.assertNotIn('SWIFT_TREAT_WARNINGS_AS_ERRORS=YES', archive_source)
        self.assertNotIn('GCC_TREAT_WARNINGS_AS_ERRORS=YES', archive_source)
        self.assertIn('--signing-receipt "${signing_receipt_snapshot}"', archive_source)
        self.assertIn('--signing-receipt-sha "${signing_identity_sha}"', archive_source)
        self.assertIn('--vendored-receipt-sha "${vendored_binary_sha}"', archive_source)
        self.assertEqual(
            archive_source.count(
                '/bin/sh "${signing_identity_tool}" --verify-qualified'
            ),
            2,
        )
        self.assertEqual(
            archive_source.count(
                '/bin/sh "${vendored_binary_tool}" --verify-qualified'
            ),
            2,
        )
        self.assertIn('inspect_production_signature_identity', source)
        self.assertIn('installable clone was not reinstalled immediately before XCTest', source)
        branch_marker = '\nif [ "${migration_candidate_archive_active}" = "true" ]; then\n'
        self.assertEqual(source.count(branch_marker), 1)
        deferral_marker = (
            '\nfi\n\nif [ "${migration_post_export_admission_deferred}" '
            '= "true" ]; then\n'
        )
        receipt_section, post_receipt_gates = source.split(branch_marker, 1)[1].split(
            deferral_marker, 1
        )
        candidate_arm, qualified_arm = receipt_section.split("\nelse\n", 1)
        self.assertNotIn("exit 0", candidate_arm)
        self.assertNotIn("--verify-qualified", candidate_arm)
        self.assertNotIn("migration_qualification_snapshot", candidate_arm)
        self.assertNotIn("migration_authenticated_sha256", candidate_arm)
        self.assertIn("qualification_contract_sha256", candidate_arm)
        self.assertIn("verify_qualification_contract_unchanged", candidate_arm)
        self.assertIn("modernization_test_count", candidate_arm)
        self.assertIn("migration_post_export_admission_deferred=true", candidate_arm)
        self.assertIn(
            '/bin/sh "${migration_qualification_validator}" --verify-qualified',
            qualified_arm,
        )
        self.assertIn(
            'migration_qualification="${migration_qualification_snapshot}"',
            qualified_arm,
        )
        self.assertIn("migration_authenticated_sha256", qualified_arm)
        self.assertNotIn("migration_authenticated_sha256", post_receipt_gates)
        deferred_arm, candidate_bound_and_downstream = post_receipt_gates.split(
            "\nelse\n", 1
        )
        candidate_bound_arm, downstream_prerequisites = (
            candidate_bound_and_downstream.split(
                '\nfi\n\nfor nexus_chain_admission_marker in', 1
            )
        )
        self.assertIn(
            "funded-canary and rollout receipt admission require the exported IPA",
            deferred_arm,
        )
        self.assertNotIn('"${taira_canary}"', deferred_arm)
        self.assertNotIn('"${minamoto_canary}"', deferred_arm)
        self.assertIn('"${taira_canary}"', candidate_bound_arm)
        self.assertIn('"${minamoto_canary}"', candidate_bound_arm)
        self.assertIn("pendingStore.requireCurrentChainMutationAdmission()", downstream_prerequisites)
        migration_branch_index = source.index(branch_marker)
        for prerequisite in (
            "authenticated iOS vendored-binary admission is missing or fail-open",
            "iOS production bundle, team, signing, or entitlements identity drifted",
            "production vendored XCFramework evidence is not independently authenticated",
            "production staged-rollout advancement gate is missing or fail-open",
            "canonical Polkamarkt web behavior or reviewed runtime/extrinsic parity is incomplete",
        ):
            self.assertLess(source.index(prerequisite), migration_branch_index)
        self.assertGreater(
            source.index("Nexus prepare/send/pre-sign/pre-transport chain admission is incomplete"),
            source.index(deferral_marker),
        )
        candidate_probe = f"""
set -eu
migration_candidate_archive_active=true
migration_post_export_admission_deferred=false
modernization_tests={shlex.quote(str(ROOT / "SoraPassportTests/Common/Modernization/WalletModernizationTests.swift"))}
recovery_gate_tests={shlex.quote(str(ROOT / "SoraPassportTests/Common/Modernization/WalletRecoveryCapabilityGateTests.swift"))}
recovery_export_tests={shlex.quote(str(ROOT / "SoraPassportTests/Common/Modernization/WalletRecoveryExporterTests.swift"))}
migration_evidence_tests={shlex.quote(str(ROOT / "SoraPassportIntegrationTests/WalletMigrationRetainedDeviceEvidenceTests.swift"))}
qualification_contract_sha256() {{
    /usr/bin/printf '%064d\n' 0
}}
verify_qualification_contract_unchanged() {{
    return 0
}}
if [ "${{migration_candidate_archive_active}}" = "true" ]; then
{candidate_arm}
else
    exit 90
fi
[ "${{migration_post_export_admission_deferred}}" = "true" ]
if [ "${{migration_post_export_admission_deferred}}" = "true" ]; then
{deferred_arm}
else
    exit 91
fi
/usr/bin/printf 'candidate-deferral-ok\n'
"""
        probe = run("/bin/sh", "-c", candidate_probe)
        self.assertEqual(probe.returncode, 0, probe.stderr)
        self.assertEqual(probe.stdout, "candidate-deferral-ok\n")
        self.assertIn("dependency, signing, runtime, and source gates remain active", probe.stderr)
        self.assertIn("require the exported IPA", probe.stderr)

    def test_rollout_requires_post_archive_exact_ipa_admission(self) -> None:
        rollout = ROLLOUT.read_text(encoding="utf-8")
        candidate = rollout.index('candidate_ipa="${PRODUCTION_ROLLOUT_IPA_PATH:-}"')
        admission = rollout.index(
            '/bin/sh "${migration_promotion_admission}" --verify-qualified-ipa "${candidate_ipa}"'
        )
        cohort = rollout.index('if [ "${target}" != "1" ]; then')
        self.assertLess(candidate, admission)
        self.assertLess(admission, cohort)
        builder_action = BUILDER.read_text(encoding="utf-8").split(
            "exec /usr/bin/xcodebuild", 1
        )[1]
        self.assertIn("build-for-testing", builder_action)
        self.assertNotIn("SWIFT_TREAT_WARNINGS_AS_ERRORS=YES", builder_action)
        self.assertNotIn("GCC_TREAT_WARNINGS_AS_ERRORS=YES", builder_action)
        self.assertNotIn("-exportArchive", builder_action)
        self.assertNotIn("\n    archive", builder_action)
        self.assertIn(
            '[ "${candidate_sha}" = "${migration_admitted_ipa_sha256}" ]',
            rollout,
        )
        self.assertIn(
            '[ "${final_candidate_sha}" = "${migration_admitted_ipa_sha256}" ]',
            rollout,
        )

    def test_phase_boundary_sources_are_contract_bound(self) -> None:
        manifest = json.loads(CONTRACT.read_text(encoding="utf-8"))
        paths = manifest["paths"]
        for relative in (
            ".github/workflows/ios_modernization.yml",
            "Jenkinsfile.production-promotion",
            "Fixtures/Modernization/ios-production-promotion-README.md",
            "SoraPassport/Scripts/build-ios-migration-evidence-candidate.sh",
            "SoraPassport/Scripts/archive-ios-migration-candidate.sh",
            "SoraPassport/Scripts/create-ios-migration-candidate-handoff.py",
            "SoraPassport/Scripts/derive-ios-migration-test-host.py",
            "SoraPassport/Scripts/derive-ios-migration-test-host.sh",
            "SoraPassport/Scripts/run-ios-migration-exact-ipa-evidence.py",
            "SoraPassport/Scripts/run-ios-migration-exact-ipa-evidence.sh",
            "SoraPassport/Scripts/run-ios-release-tests.sh",
            "SoraPassport/Scripts/run-ios-production-promotion.py",
            "SoraPassport/Scripts/sanitize-ios-migration-xctestrun.py",
            "SoraPassport/Scripts/test-ios-migration-exact-ipa-evidence.py",
            "SoraPassport/Scripts/test-ios-migration-release-boundary.py",
            "SoraPassport/Scripts/test-ios-production-promotion.py",
            "SoraPassport/Scripts/test-ios-release-reproducibility-package.py",
            "SoraPassport/Scripts/test-ios-migration-test-host-derivation.py",
            "SoraPassport/Scripts/test-ios-migration-xctestrun-sanitizer.py",
            "SoraPassport/Scripts/verify-ios-migration-promotion-ipa.sh",
            "SoraPassport/Scripts/verify-ios-release-reproducibility-package.py",
            "SoraPassport/Scripts/verify-production-rollout.sh",
            "SoraPassport/Configs/ios-migration-candidate-export-options.plist",
            "SoraPassport/Configs/SoraPassport.release.xcconfig",
            "SoraPassport/Info.plist",
            "SoraPassport/Common/MigrationEvidence/RetainedMigrationEvidenceHarness.swift",
            "SoraPassportTests/Helpers/AccountCreationHelper.swift",
            "VendorPackages/shared-features-spm/Sources/SSFUtils/SSFUtils/Classes/Network/WebSocketEngine.swift",
            "SoraPassport.xcodeproj/xcshareddata/xcschemes/SoraPassportMigrationEvidenceUI.xcscheme",
            "SoraPassportUITests/RetainedMigrationEvidenceUITests.swift",
        ):
            self.assertIn(relative, paths)
        workflow = CI_WORKFLOW.read_text(encoding="utf-8")
        for marker in (
            "pull_request:",
            "contents: read",
            "Modernization Source Contract",
            "Full Release XCTest Closure",
            "--lint-ios-migration-release-source-gate",
            "run-ios-release-tests.sh",
            "actions/upload-artifact@v4",
            "if-no-files-found: error",
        ):
            self.assertIn(marker, workflow)
        self.assertNotIn("pull_request_target:", workflow)
        qualifier = QUALIFIER.read_text(encoding="utf-8")
        self.assertIn("--verify-qualified-ipa", qualifier)
        self.assertIn("verify_qualified_ipa", qualifier)
        for checkout_portable_lint in (
            "create-ios-migration-installable-clone.py",
            "run-ios-migration-exact-ipa-evidence.py",
            "sanitize-ios-migration-xctestrun.py",
        ):
            self.assertNotIn(
                'ROOT.name != "sora-ios"',
                (SCRIPTS / checkout_portable_lint).read_text(encoding="utf-8"),
            )
        promotion = PROMOTION.read_text(encoding="utf-8")
        self.assertIn("IOS_RELEASE_QUALIFIED_IPA_PACKAGE_PATH", promotion)
        self.assertEqual(promotion.count("--verify-download"), 2)
        self.assertLess(
            promotion.index('package_result="$({'),
            promotion.index('qualification_result="$({'),
        )
        self.assertIn(
            '[ "${qualification_receipt_sha}" = "${package_receipt_sha}" ]',
            promotion,
        )
        self.assertEqual(
            promotion.count(
                '/bin/sh "${signing_identity_validator}" --verify-qualified'
            ),
            2,
        )
        self.assertEqual(
            promotion.count(
                '/bin/sh "${vendored_binary_validator}" --verify-qualified'
            ),
            2,
        )
        self.assertIn(
            '[ "${package_signing_sha}" = "${signing_receipt_sha}" ]',
            promotion,
        )
        self.assertIn(
            '[ "${package_vendored_sha}" = "${vendored_receipt_sha}" ]',
            promotion,
        )
        self.assertIn(
            '[ "${qualification_ipa_sha}" = "${package_candidate_sha}" ]',
            promotion,
        )
        self.assertIn(
            '[ "${package_final_result}" = "${package_result}" ]',
            promotion,
        )


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(MigrationReleaseBoundaryTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if result.wasSuccessful() else 1)
