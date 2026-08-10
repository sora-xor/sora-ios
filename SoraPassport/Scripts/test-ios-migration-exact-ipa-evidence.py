#!/usr/bin/env python3
"""Hermetic contract tests for the exact-IPA retained-device controller."""

from __future__ import annotations

import base64
import importlib.util
import plistlib
import stat
import subprocess
import tempfile
import time
import unittest
import uuid
import zipfile
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).with_name("run-ios-migration-exact-ipa-evidence.py")
SPEC = importlib.util.spec_from_file_location("ios_exact_ipa_controller", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("exact-IPA controller cannot be loaded")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ExactIpaControllerTests(unittest.TestCase):
    def test_artifact_paths_allow_only_internal_ascii_spaces(self):
        valid = zipfile.ZipInfo(
            "Payload/SoraPassport.app/UserDataModel.momd/UserDataModel 2.mom"
        )
        valid.external_attr = (stat.S_IFREG | 0o644) << 16
        self.assertEqual(
            MODULE.safe_zip_path(valid).as_posix(),
            valid.filename,
        )

        for unsafe in (
            "Payload/SoraPassport.app/ leading.mom",
            "Payload/SoraPassport.app/trailing.mom ",
            "Payload/SoraPassport.app/control\tname.mom",
            "Payload/SoraPassport.app/../escaped.mom",
            "Payload\\SoraPassport.app\\escaped.mom",
        ):
            entry = zipfile.ZipInfo(unsafe)
            entry.external_attr = (stat.S_IFREG | 0o644) << 16
            with self.assertRaisesRegex(MODULE.ControllerError, "unsafe member"):
                MODULE.safe_zip_path(entry)

        with tempfile.TemporaryDirectory(prefix="sora-spaced-app-tree-") as temp:
            app = Path(temp) / "SoraPassport.app"
            model = app / "UserDataModel.momd"
            model.mkdir(parents=True)
            (model / "UserDataModel 2.mom").write_bytes(b"model")
            tree_sha, tree_bytes, file_count = MODULE.complete_tree_record(
                app,
                MODULE.RAW_APP_TREE_PREFIX,
                "spaced production app tree",
            )
            self.assertRegex(tree_sha, r"^[0-9a-f]{64}$")
            self.assertGreater(tree_bytes, 0)
            self.assertEqual(file_count, 1)

        application_id = f"{MODULE.TEAM_IDENTIFIER}.{MODULE.BUNDLE_IDENTIFIER}"
        info = {
            "CFBundleIdentifier": MODULE.BUNDLE_IDENTIFIER,
            "CFBundleShortVersionString": "3.8.7",
            "CFBundleVersion": "2026081001",
        }
        signed = {
            "application-identifier": application_id,
            "com.apple.developer.team-identifier": MODULE.TEAM_IDENTIFIER,
            "get-task-allow": False,
            "beta-reports-active": True,
        }
        profile = {
            "application-identifier": f"{MODULE.TEAM_IDENTIFIER}.*",
            "com.apple.developer.team-identifier": MODULE.TEAM_IDENTIFIER,
            "keychain-access-groups": [
                f"{MODULE.TEAM_IDENTIFIER}.*",
                "com.apple.token",
            ],
        }
        identity = MODULE.validate_production_entitlement_identity(
            info, profile, signed
        )
        self.assertEqual(identity["effectiveKeychainAccessGroups"], [application_id])
        self.assertEqual(
            identity["cloneSigningEntitlements"],
            {
                "application-identifier": application_id,
                "com.apple.developer.team-identifier": MODULE.TEAM_IDENTIFIER,
            },
        )
        explicit_default = dict(signed)
        explicit_default["keychain-access-groups"] = [application_id]
        self.assertEqual(
            MODULE.validate_production_entitlement_identity(
                info, profile, explicit_default
            )["keychainAccessGroupsSha256"],
            identity["keychainAccessGroupsSha256"],
        )
        ordered_hashes = []
        for groups in (
            [f"{MODULE.TEAM_IDENTIFIER}.shared.sora", application_id],
            [application_id, f"{MODULE.TEAM_IDENTIFIER}.shared.sora"],
        ):
            ordered = dict(signed)
            ordered["keychain-access-groups"] = groups
            ordered_hashes.append(
                MODULE.validate_production_entitlement_identity(
                    info, profile, ordered
                )["keychainAccessGroupsSha256"]
            )
        self.assertNotEqual(*ordered_hashes)
        token_only_profile = dict(profile)
        token_only_profile["keychain-access-groups"] = ["com.apple.token"]
        with self.assertRaisesRegex(MODULE.ControllerError, "authorize"):
            MODULE.validate_production_entitlement_identity(
                info, token_only_profile, signed
            )

    def request(self, *, case_kind: str = "keychain", case_id: str = "watch-only"):
        now = int(time.time())
        return {
            "schemaVersion": 3,
            "contractId": MODULE.REQUEST_CONTRACT_ID,
            "platform": "ios",
            "purpose": "retained-wallet-migration-observation",
            "releaseAuthorized": False,
            "authorizationId": str(uuid.uuid4()),
            "authorizationKeyId": "protected-controller-2026",
            "signatureAlgorithm": "ecdsa-p256-sha256",
            "runId": str(uuid.uuid4()),
            "runChallengeSha256": "1" * 64,
            "sourceRevision": "2" * 40,
            "qualificationContractSha256": "3" * 64,
            "productionIpaSha256": "4" * 64,
            "installedAppRawTreeSha256": "5" * 64,
            "installedExecutableSha256": "6" * 64,
            "productionCanonicalProjectionSha256": "7" * 64,
            "installedCanonicalProjectionSha256": "7" * 64,
            "canonicalProjectionReceiptSha256": "8" * 64,
            "canonicalProjectorSourceSha256": "9" * 64,
            "preparedWalletInputTreeSha256": "a" * 64,
            "enrollmentNonceSha256": "b" * 64,
            "caseKind": case_kind,
            "caseId": case_id,
            "issuedAtEpochSeconds": now - 1,
            "expiresAtEpochSeconds": now + 3_600,
            "maximumLaunchCount": 2,
        }

    def clone_receipt(self):
        request = self.request()
        return {
            "schemaVersion": 1,
            "contractId": MODULE.INSTALLABLE_CLONE_CONTRACT_ID,
            "platform": "ios",
            "status": "observed",
            "releaseAuthorized": False,
            "qualificationContractSha256": request[
                "qualificationContractSha256"
            ],
            "productionIpaSha256": request["productionIpaSha256"],
            "productionCanonicalProjectionSha256": request[
                "productionCanonicalProjectionSha256"
            ],
            "installedAppRawTreeSha256": request["installedAppRawTreeSha256"],
            "installedAppRawTreeRecordByteCount": 4096,
            "installedAppFileCount": 20,
            "installedCanonicalProjectionSha256": request[
                "installedCanonicalProjectionSha256"
            ],
            "installedExecutableSha256": request["installedExecutableSha256"],
            "installedExecutableByteCount": 2048,
            "canonicalProjectionReceiptSha256": request[
                "canonicalProjectionReceiptSha256"
            ],
            "canonicalProjectorSourceSha256": (
                MODULE.canonical_projector_source_sha256()
            ),
            "registeredDeviceProvisioningProfileSha256": "c" * 64,
            "registeredDeviceSigningCertificateSha1": "d" * 40,
            "registeredDeviceUdidSha256": MODULE.hashlib.sha256(
                b"00008110-001234567890001E"
            ).hexdigest(),
            "checks": {
                "exactProductionIpaExtracted": True,
                "registeredDeviceProfileVerified": True,
                "productionIdentityPreserved": True,
                "canonicalProjectionEqual": True,
                "installedCloneCodeSignatureDeepStrictVerified": True,
                "rebuiltApplicationAccepted": False,
                "qualificationCreated": False,
            },
            "blockingReasons": [MODULE.INSTALLABLE_CLONE_NONAUTHORIZING_BLOCKER],
        }

    def application_receipt(self, request, request_sha):
        case_id = request["caseId"]
        checkpoint = MODULE.INTERRUPTION_CHECKPOINTS.get(case_id)
        recovery = case_id in MODULE.RECOVERY_ROUTE_CASES
        receipt = {
            "schemaVersion": 3,
            "contractId": (
                "sora-ios-wallet-migration-case-operation-receipt-v3"
            ),
            "platform": "ios",
            "status": "observed",
            "releaseAuthorized": False,
            "authorizationId": request["authorizationId"],
            "authorizationKeyId": request["authorizationKeyId"],
            "authorizationRequestSha256": request_sha,
            "runId": request["runId"],
            "runChallengeSha256": request["runChallengeSha256"],
            "sourceRevision": request["sourceRevision"],
            "qualificationContractSha256": request[
                "qualificationContractSha256"
            ],
            "productionIpaSha256": request["productionIpaSha256"],
            "installedAppRawTreeSha256": request[
                "installedAppRawTreeSha256"
            ],
            "installedExecutableSha256": request["installedExecutableSha256"],
            "productionCanonicalProjectionSha256": request[
                "productionCanonicalProjectionSha256"
            ],
            "installedCanonicalProjectionSha256": request[
                "installedCanonicalProjectionSha256"
            ],
            "canonicalProjectionReceiptSha256": request[
                "canonicalProjectionReceiptSha256"
            ],
            "canonicalProjectorSourceSha256": request[
                "canonicalProjectorSourceSha256"
            ],
            "preparedWalletInputTreeSha256": request[
                "preparedWalletInputTreeSha256"
            ],
            "caseKind": request["caseKind"],
            "caseId": case_id,
            "outcome": "passed" if request["caseKind"] == "keychain" else "observed",
            "startedAtEpochSeconds": request["issuedAtEpochSeconds"],
            "finishedAtEpochSeconds": request["issuedAtEpochSeconds"] + 1,
            "launchCount": 2 if checkpoint else 1,
            "harnessStateSha256": "f" * 64,
            "checkpointSequence": [checkpoint] if checkpoint else [],
            "applicationRoute": (
                "recovery" if recovery else "local-authentication"
            ),
        }
        if request["caseKind"] == "keychain":
            signing_expected, signing_succeeded = (
                MODULE.KEYCHAIN_SIGNING_EXPECTATIONS[case_id]
            )
            receipt["keychainObservation"] = {
                "identifierSetUnchanged": True,
                "valuesByteForByteUnchanged": True,
                "accessibilityUnchanged": True,
                "credentialRewriteObserved": False,
                "credentialBehaviorProbePassed": True,
                "signingExpected": signing_expected,
                "signingSucceeded": signing_succeeded,
                "recoveryRouteEntered": recovery,
            }
            return receipt
        observation = {
            "recoveryRouteEntered": recovery,
            "recoveryArchiveExportVerified": (
                case_id == "recovery-archive-export"
            ),
            "processDeathRestartObserved": case_id == "process-death-restart",
            "controllerValidationRequired": True,
        }
        if case_id == "rollback":
            observation.update(
                {
                    "rollbackInjectionObserved": True,
                    "rollbackRestorationVerified": True,
                    "rollbackBeforeStoreTreeSha256": "1" * 64,
                    "rollbackReplacementStoreTreeSha256": "2" * 64,
                    "rollbackRestoredStoreTreeSha256": "1" * 64,
                }
            )
        if case_id == "interruption-before-secret-retention":
            observation.update(
                {
                    "retainedKeychainIdentifierSetUnchanged": True,
                    "retainedKeychainValuesUnchanged": True,
                    "retainedKeychainAccessibilityUnchanged": True,
                }
            )
        if case_id == "low-storage":
            observation["lowStorageConditionObserved"] = True
        receipt["deviceObservation"] = observation
        return receipt

    def write_wallet_snapshot(self, root, content=b"retained-store"):
        core_data = root / "Documents" / "CoreData"
        preferences = root / "Library" / "Preferences"
        core_data.mkdir(parents=True)
        preferences.mkdir(parents=True)
        (core_data / "UserDataModel.sqlite").write_bytes(content)
        (preferences / "co.jp.soramitsu.sora.plist").write_bytes(
            b"retained-settings"
        )

    def write_generated_xctestrun(self, path):
        path.write_bytes(
            plistlib.dumps(
                {
                    "SoraPassportTests-stale": {
                        "BlueprintName": "SoraPassportTests",
                        "TestHostPath": (
                            "__TESTROOT__/Release-iphoneos/"
                            "SoraPassport.app/SoraPassport"
                        ),
                    },
                    "SoraPassportUITests-reviewed": {
                        "BlueprintName": "SoraPassportUITests",
                        "TestTargetName": "SoraPassportUITests",
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
                            "SoraPassportUITests-Runner.app/"
                            "SoraPassportUITests-Runner"
                        ),
                        "TestingEnvironmentVariables": {
                            "DYLD_FRAMEWORK_PATH": "__TESTROOT__"
                        },
                        "DependentProductPaths": [
                            "__TESTROOT__/Release-iphoneos/SoraPassport.app",
                            "__TESTROOT__/Release-iphoneos/"
                            "SoraPassportUITests-Runner.app",
                        ],
                    },
                    "__xctestrun_metadata__": {"FormatVersion": 1},
                },
                fmt=plistlib.FMT_XML,
                sort_keys=True,
            )
        )

    def protected_clone_artifact_fixture(self, root):
        clone_root = root / "artifact-clone"
        clone_root.mkdir(mode=0o700)
        app = (
            clone_root
            / "installable-app"
            / "Payload"
            / "SoraPassport.app"
        )
        app.mkdir(parents=True)
        (app / "Info.plist").write_bytes(
            plistlib.dumps(
                {
                    "CFBundleIdentifier": MODULE.BUNDLE_IDENTIFIER,
                    "CFBundleExecutable": "SoraPassport",
                },
                fmt=plistlib.FMT_BINARY,
            )
        )
        executable = app / "SoraPassport"
        executable.write_bytes(b"archive-derived-clone-executable")
        tree_sha, tree_bytes, file_count = MODULE.complete_tree_record(
            app,
            MODULE.RAW_APP_TREE_PREFIX,
            "test protected clone tree",
        )
        executable_sha, executable_bytes = MODULE.hash_extracted_regular(
            executable,
            MODULE.MAX_FILE_BYTES,
            "test protected clone executable",
        )
        projection_sha = "7" * 64
        projection = {
            "schemaVersion": 2,
            "contractId": (
                "sora-ios-wallet-migration-test-host-derivation-v2"
            ),
            "platform": "ios",
            "status": "observed",
            "releaseAuthorized": False,
            "promotionAuthorized": False,
            "qualificationContractSha256": "3" * 64,
            "projectionContract": {},
            "cryptographicValidityBoundary": {},
            "productionIpa": {
                "sha256": "4" * 64,
                "canonicalProjection": {"recordSha256": projection_sha},
            },
            "releaseTestHost": {
                "canonicalProjection": {"recordSha256": projection_sha},
                "rawTree": {"recordSha256": tree_sha},
                "rawExecutableSha256": executable_sha,
            },
            "derivation": {
                "canonicalProjectionEqual": True,
                "canonicalExecutableEqual": True,
                "productionIdentityPreserved": True,
            },
            "checks": {
                "completeProjectionMatched": True,
                "secondCompleteInspectionMatched": True,
                "controllerNonAuthorizing": True,
            },
            "blockingReasons": ["observed-only"],
        }
        projection_raw = MODULE.canonical_json(projection)
        (clone_root / "canonical-projection-receipt-v2.json").write_bytes(
            projection_raw
        )
        receipt = {
            "schemaVersion": 1,
            "contractId": MODULE.INSTALLABLE_CLONE_CONTRACT_ID,
            "platform": "ios",
            "status": "observed",
            "releaseAuthorized": False,
            "qualificationContractSha256": "3" * 64,
            "productionIpaSha256": "4" * 64,
            "productionCanonicalProjectionSha256": projection_sha,
            "installedAppRawTreeSha256": tree_sha,
            "installedAppRawTreeRecordByteCount": tree_bytes,
            "installedAppFileCount": file_count,
            "installedCanonicalProjectionSha256": projection_sha,
            "installedExecutableSha256": executable_sha,
            "installedExecutableByteCount": executable_bytes,
            "canonicalProjectionReceiptSha256": MODULE.hashlib.sha256(
                projection_raw
            ).hexdigest(),
            "canonicalProjectorSourceSha256": (
                MODULE.canonical_projector_source_sha256()
            ),
            "registeredDeviceProvisioningProfileSha256": "c" * 64,
            "registeredDeviceSigningCertificateSha1": "d" * 40,
            "registeredDeviceUdidSha256": MODULE.hashlib.sha256(
                b"00008110-001234567890001E"
            ).hexdigest(),
            "checks": {
                "exactProductionIpaExtracted": True,
                "registeredDeviceProfileVerified": True,
                "productionIdentityPreserved": True,
                "canonicalProjectionEqual": True,
                "installedCloneCodeSignatureDeepStrictVerified": True,
                "rebuiltApplicationAccepted": False,
                "qualificationCreated": False,
            },
            "blockingReasons": [MODULE.INSTALLABLE_CLONE_NONAUTHORIZING_BLOCKER],
        }
        receipt_raw = MODULE.canonical_json(receipt)
        receipt_path = clone_root / "installable-clone-receipt-v1.json"
        receipt_path.write_bytes(receipt_raw)
        receipt_sha = MODULE.hashlib.sha256(receipt_raw).hexdigest()
        (clone_root / ".complete").write_bytes(
            MODULE.canonical_json(
                {
                    "schemaVersion": 1,
                    "contractId": (
                        "sora-ios-wallet-migration-installable-clone-complete-v1"
                    ),
                    "installableCloneReceiptSha256": receipt_sha,
                    "releaseAuthorized": False,
                }
            )
        )
        return receipt_path, receipt, receipt_sha, executable

    def execute_case_with_fakes(
        self,
        root,
        *,
        clone_after_changed=False,
        omit_receipt=False,
        omit_test_receipt=False,
        prepared_mismatch=False,
        device="00008110-001234567890001E",
    ):
        clone_app = (
            root
            / "protected-clone"
            / "installable-app"
            / "Payload"
            / "SoraPassport.app"
        )
        clone_app.mkdir(parents=True)
        clone_receipt_path = (
            root / "protected-clone" / "installable-clone-receipt-v1.json"
        )
        generated = root / "generated.xctestrun"
        self.write_generated_xctestrun(generated)

        baseline = root / "baseline-wallet"
        self.write_wallet_snapshot(baseline)
        prepared_sha = MODULE.wallet_input_tree_record(baseline)[0]
        request = self.request(
            case_kind="device",
            case_id="reinstall-upgrade",
        )
        nonce_raw = bytes(range(32))
        request["enrollmentNonceSha256"] = MODULE.hashlib.sha256(
            nonce_raw
        ).hexdigest()
        request["preparedWalletInputTreeSha256"] = (
            "e" * 64 if prepared_mismatch else prepared_sha
        )
        request_raw = MODULE.canonical_json(request)
        request_sha = MODULE.hashlib.sha256(request_raw).hexdigest()
        signature_raw = b"reviewed-signature"
        application_receipt_raw = MODULE.canonical_json(
            self.application_receipt(request, request_sha)
        )
        application_receipt_sha = MODULE.hashlib.sha256(
            application_receipt_raw
        ).hexdigest()
        clone_receipt = self.clone_receipt()
        clone_identity = {
            "appPath": str(clone_app),
            "installedAppRawTreeSha256": request[
                "installedAppRawTreeSha256"
            ],
            "installedAppRawTreeRecordByteCount": 4096,
            "installedAppFileCount": 20,
            "installedExecutableSha256": request["installedExecutableSha256"],
            "installedExecutableByteCount": 2048,
            "productionCanonicalProjectionSha256": request[
                "productionCanonicalProjectionSha256"
            ],
            "installedCanonicalProjectionSha256": request[
                "installedCanonicalProjectionSha256"
            ],
            "canonicalProjectionReceiptSha256": request[
                "canonicalProjectionReceiptSha256"
            ],
            "canonicalProjectorSourceSha256": request[
                "canonicalProjectorSourceSha256"
            ],
        }
        changed_identity = dict(clone_identity)
        changed_identity["installedExecutableSha256"] = "e" * 64
        rechecks = [
            clone_identity,
            clone_identity,
            changed_identity if clone_after_changed else clone_identity,
        ]
        admitted = {
            "request": request,
            "requestRaw": request_raw,
            "requestSha256": request_sha,
            "requestByteCount": len(request_raw),
            "signatureRaw": signature_raw,
            "signatureSha256": MODULE.hashlib.sha256(
                signature_raw
            ).hexdigest(),
            "signatureByteCount": len(signature_raw),
            "installableCloneReceipt": clone_receipt,
            "installableCloneReceiptSha256": "c" * 64,
            "installableCloneReceiptByteCount": 4096,
            "identity": {"ipaSha256": request["productionIpaSha256"]},
        }
        events = []

        def fake_run(argv, **_kwargs):
            if argv[:2] == ["/usr/bin/xcrun", "xcresulttool"]:
                events.append("extract-test-receipt")
                attachment_root = Path(
                    argv[argv.index("--output-path") + 1]
                )
                attachment_root.mkdir()
                attachments = []
                if not omit_test_receipt:
                    exported_name = "case-operation-receipt.json"
                    (attachment_root / exported_name).write_bytes(
                        application_receipt_raw
                    )
                    attachments.append(
                        {
                            "exportedFileName": exported_name,
                            "suggestedHumanReadableName": (
                                "case-operation-receipt-v3-"
                                f"{application_receipt_sha}.json"
                            ),
                            "isAssociatedWithFailure": False,
                            "configurationName": "Test Scheme Action",
                            "deviceName": "Registered iPhone",
                            "deviceId": device,
                        }
                    )
                (attachment_root / "manifest.json").write_bytes(
                    MODULE.json.dumps(
                        [
                            {
                                "testIdentifier": (
                                    "RetainedMigrationEvidenceUITests/"
                                    "testExecuteAuthorizedRetainedMigrationCase()"
                                ),
                                "attachments": attachments,
                            }
                        ]
                    ).encode("utf-8")
                )
            elif argv[:2] == ["/usr/bin/xcrun", "devicectl"]:
                json_output = Path(argv[argv.index("--json-output") + 1])
                step = json_output.name[: -len(".devicectl.json")]
                events.append(step)
                if "copy" in argv and "from" in argv:
                    destination = Path(argv[argv.index("--destination") + 1])
                    if step == "copy-pre-execution-enrollment":
                        evidence = destination / "SoraWalletMigrationEvidence"
                        evidence.mkdir(parents=True)
                        (evidence / MODULE.ENROLLMENT_NONCE_NAME).write_bytes(
                            nonce_raw
                        )
                    elif step == "copy-pre-execution-wallet":
                        self.write_wallet_snapshot(destination)
                    elif step == "copy-post-execution-evidence":
                        evidence = destination / "SoraWalletMigrationEvidence"
                        evidence.mkdir(parents=True)
                        (evidence / MODULE.ENROLLMENT_NONCE_NAME).write_bytes(
                            nonce_raw
                        )
                        (evidence / MODULE.AUTHORIZATION_NAME).write_bytes(
                            request_raw
                        )
                        (
                            evidence / MODULE.AUTHORIZATION_SIGNATURE_NAME
                        ).write_bytes(signature_raw)
                        if not omit_receipt:
                            (
                                evidence / MODULE.APPLICATION_RECEIPT_NAME
                            ).write_bytes(application_receipt_raw)
                            (
                                evidence / MODULE.APPLICATION_RECEIPT_SHA_NAME
                            ).write_bytes(
                                f"{application_receipt_sha}\n".encode("ascii")
                            )
                    elif step == "copy-post-execution-wallet":
                        self.write_wallet_snapshot(
                            destination,
                            content=b"migrated-store",
                        )
            elif argv[0] == "/usr/bin/xcodebuild":
                events.append("test-without-building")
                result_bundle = Path(argv[argv.index("-resultBundlePath") + 1])
                result_bundle.mkdir()
                (result_bundle / "Info.plist").write_bytes(b"result")
            else:
                raise AssertionError(f"unexpected command: {argv}")
            return subprocess.CompletedProcess(argv, 0, b"", b"")

        with mock.patch.object(
            MODULE,
            "validate_signed_request",
            return_value=admitted,
        ), mock.patch.object(
            MODULE,
            "recheck_installable_clone_artifacts",
            side_effect=rechecks,
        ), mock.patch.object(MODULE.subprocess, "run", side_effect=fake_run):
            result = MODULE.execute_case(
                device=device,
                ipa_path=str(root / "production.ipa"),
                clone_receipt_path=str(clone_receipt_path),
                xctestrun_path=str(generated),
                request_path=str(root / "authorization-request-v3.json"),
                signature_path=str(root / "authorization-request-v3.sig"),
                output_raw=str(root / "execution"),
            )
        return result, events, root / "execution", clone_app

    def test_exact_eight_keychain_and_ten_device_cases(self):
        self.assertEqual(len(MODULE.REQUEST_KEYS), 26)
        self.assertEqual(set(self.request()), MODULE.REQUEST_KEYS)
        self.assertEqual(len(MODULE.KEYCHAIN_CASES), 8)
        self.assertEqual(len(MODULE.DEVICE_CASES), 10)
        for case_id in MODULE.KEYCHAIN_CASES:
            raw = MODULE.canonical_json(self.request(case_id=case_id))
            self.assertEqual(MODULE.validate_authorization_request(raw)["caseId"], case_id)
        for case_id in MODULE.DEVICE_CASES:
            raw = MODULE.canonical_json(
                self.request(case_kind="device", case_id=case_id)
            )
            self.assertEqual(MODULE.validate_authorization_request(raw)["caseId"], case_id)

    def test_stale_22_field_authorization_is_rejected(self):
        request = self.request()
        request["extracted" + "AppRawTreeSha256"] = request.pop(
            "installedAppRawTreeSha256"
        )
        for key in (
            "productionCanonicalProjectionSha256",
            "installedCanonicalProjectionSha256",
            "canonicalProjectionReceiptSha256",
            "canonicalProjectorSourceSha256",
        ):
            request.pop(key)
        self.assertEqual(len(request), 22)
        with self.assertRaises(MODULE.ControllerError):
            MODULE.validate_authorization_request(MODULE.canonical_json(request))

    def test_clone_receipt_binds_every_clone_authorization_field(self):
        request = self.request()
        receipt = self.clone_receipt()
        request["canonicalProjectorSourceSha256"] = receipt[
            "canonicalProjectorSourceSha256"
        ]
        validated = MODULE.validate_installable_clone_receipt(
            MODULE.canonical_json(receipt)
        )
        identity = {
            "authorityKeyId": request["authorizationKeyId"],
            "sourceRevision": request["sourceRevision"],
            "qualificationContractSha256": request[
                "qualificationContractSha256"
            ],
            "ipaSha256": request["productionIpaSha256"],
        }
        MODULE.validate_authorization_clone_binding(request, identity, validated)
        for key in MODULE.CLONE_BOUND_AUTHORIZATION_KEYS:
            mismatched = dict(request)
            mismatched[key] = "e" * 64
            with self.subTest(key=key), self.assertRaises(MODULE.ControllerError):
                MODULE.validate_authorization_clone_binding(
                    mismatched,
                    identity,
                    validated,
                )

    def test_clone_receipt_rejects_stale_shape_and_unequal_projection(self):
        receipt = self.clone_receipt()
        receipt["installedCanonicalProjectionSha256"] = "e" * 64
        with self.assertRaises(MODULE.ControllerError):
            MODULE.validate_installable_clone_receipt(MODULE.canonical_json(receipt))
        receipt = self.clone_receipt()
        receipt["checks"]["canonicalProjectionEqual"] = 1
        with self.assertRaises(MODULE.ControllerError):
            MODULE.validate_installable_clone_receipt(MODULE.canonical_json(receipt))
        receipt = self.clone_receipt()
        receipt["legacyInstalledTreeSha256"] = receipt.pop(
            "installedAppRawTreeSha256"
        )
        with self.assertRaises(MODULE.ControllerError):
            MODULE.validate_installable_clone_receipt(MODULE.canonical_json(receipt))

    def test_clone_receipt_rejects_different_projector_source(self):
        receipt = self.clone_receipt()
        receipt["canonicalProjectorSourceSha256"] = "e" * 64
        with self.assertRaises(MODULE.ControllerError):
            MODULE.validate_installable_clone_receipt(MODULE.canonical_json(receipt))

    def test_clone_artifact_recheck_rejects_post_receipt_byte_drift(self):
        with tempfile.TemporaryDirectory(prefix="sora-clone-recheck-") as temp:
            receipt_path, receipt, receipt_sha, executable = (
                self.protected_clone_artifact_fixture(Path(temp).resolve())
            )
            result = MODULE.recheck_installable_clone_artifacts(
                str(receipt_path),
                receipt,
                receipt_sha,
            )
            self.assertEqual(
                result["installedExecutableSha256"],
                receipt["installedExecutableSha256"],
            )
            executable.write_bytes(b"mutated-clone-executable")
            with self.assertRaises(MODULE.ControllerError):
                MODULE.recheck_installable_clone_artifacts(
                    str(receipt_path),
                    receipt,
                    receipt_sha,
                )

    def test_application_receipt_enforces_all_eight_and_ten_case_contracts(self):
        for case_kind, cases in (
            ("keychain", MODULE.KEYCHAIN_CASES),
            ("device", MODULE.DEVICE_CASES),
        ):
            for case_id in cases:
                with self.subTest(case_id=case_id):
                    request = self.request(case_kind=case_kind, case_id=case_id)
                    request_sha = "c" * 64
                    receipt = self.application_receipt(request, request_sha)
                    validated = MODULE.validate_application_case_receipt(
                        MODULE.canonical_json(receipt),
                        request,
                        request_sha,
                    )
                    self.assertEqual(validated["caseId"], case_id)

    def test_operation_specific_receipt_failures_are_rejected(self):
        mutations = (
            (
                "rollback",
                lambda receipt: receipt["deviceObservation"].update(
                    rollbackRestoredStoreTreeSha256="3" * 64
                ),
            ),
            (
                "low-storage",
                lambda receipt: receipt["deviceObservation"].update(
                    lowStorageConditionObserved=False
                ),
            ),
            (
                "recovery-archive-export",
                lambda receipt: receipt["deviceObservation"].update(
                    recoveryArchiveExportVerified=False
                ),
            ),
            (
                "reinstall-upgrade",
                lambda receipt: receipt.update(applicationRoute="recovery"),
            ),
            (
                "interruption-after-core-data-commit",
                lambda receipt: receipt.update(checkpointSequence=[]),
            ),
            (
                "process-death-restart",
                lambda receipt: receipt["deviceObservation"].update(
                    processDeathRestartObserved=False
                ),
            ),
        )
        for case_id, mutate in mutations:
            with self.subTest(case_id=case_id):
                request = self.request(case_kind="device", case_id=case_id)
                request_sha = "c" * 64
                receipt = self.application_receipt(request, request_sha)
                mutate(receipt)
                with self.assertRaises(MODULE.ControllerError):
                    MODULE.validate_application_case_receipt(
                        MODULE.canonical_json(receipt),
                        request,
                        request_sha,
                    )

    def test_signed_request_admits_only_the_protected_clone_receipt_binding(self):
        request = self.request()
        receipt = self.clone_receipt()
        request["canonicalProjectorSourceSha256"] = receipt[
            "canonicalProjectorSourceSha256"
        ]
        request_raw = MODULE.canonical_json(request)
        receipt_raw = MODULE.canonical_json(receipt)
        signature_raw = b"reviewed-signature"
        identity = {
            "authorityKeyId": request["authorizationKeyId"],
            "authorityPublicPoint": b"reviewed-public-point",
            "sourceRevision": request["sourceRevision"],
            "qualificationContractSha256": request[
                "qualificationContractSha256"
            ],
            "ipaSha256": request["productionIpaSha256"],
        }
        with tempfile.TemporaryDirectory(
            prefix="sora-protected-clone-receipt-test-"
        ) as temp:
            root = Path(temp).resolve()
            request_path = root / "authorization-request-v3.json"
            signature_path = root / "authorization-request-v3.sig"
            receipt_path = root / "installable-clone-receipt-v1.json"
            request_path.write_bytes(request_raw)
            signature_path.write_bytes(signature_raw)
            receipt_path.write_bytes(receipt_raw)
            with mock.patch.object(
                MODULE,
                "inspect_and_extract_ipa",
                return_value=identity,
            ), mock.patch.object(MODULE, "verify_authorization_signature") as verify:
                result = MODULE.validate_signed_request(
                    str(root / "production.ipa"),
                    str(receipt_path),
                    str(request_path),
                    str(signature_path),
                    root,
                )
            verify.assert_called_once_with(
                request_raw,
                signature_raw,
                identity["authorityPublicPoint"],
            )
            self.assertEqual(
                result["installableCloneReceiptSha256"],
                MODULE.hashlib.sha256(receipt_raw).hexdigest(),
            )

    def test_execute_case_orders_clone_install_immediately_before_test(self):
        with tempfile.TemporaryDirectory(prefix="sora-execute-case-order-") as temp:
            root = Path(temp).resolve()
            result, events, output, clone_app = self.execute_case_with_fakes(root)
            self.assertEqual(
                events,
                [
                    "copy-pre-execution-enrollment",
                    "copy-pre-execution-wallet",
                    "copy-authorization-request",
                    "copy-authorization-signature",
                    "install-archive-derived-clone",
                    "test-without-building",
                    "extract-test-receipt",
                    "copy-post-execution-evidence",
                    "copy-post-execution-wallet",
                ],
            )
            install_index = events.index("install-archive-derived-clone")
            self.assertEqual(events[install_index + 1], "test-without-building")
            sanitized = plistlib.loads(
                (output / "exact-ipa-retained-case.xctestrun").read_bytes()
            )
            sanitizer = MODULE.load_xctestrun_sanitizer()
            sanitizer.verify_sanitized_value(sanitized, clone_app)
            self.assertFalse(
                sanitizer.contains_rebuilt_host_path(sanitized, clone_app)
            )
            self.assertRegex(
                result["caseControllerReceiptSha256"],
                r"^[0-9a-f]{64}$",
            )
            self.assertTrue(
                (output / "test-receipt-attachments" / "manifest.json").is_file()
            )
            controller_receipt = MODULE.parse_canonical_json(
                (output / MODULE.CONTROLLER_RECEIPT_NAME).read_bytes(),
                "test controller receipt",
            )
            self.assertTrue(
                controller_receipt["checks"][
                    "cloneReinstalledImmediatelyBeforeTest"
                ]
            )
            self.assertNotEqual(
                controller_receipt["preExecutionWalletInputTreeSha256"],
                controller_receipt["postExecutionWalletInputTreeSha256"],
            )

    def test_execute_case_fails_closed_on_clone_recheck_drift(self):
        with tempfile.TemporaryDirectory(prefix="sora-execute-case-clone-drift-") as temp:
            with self.assertRaises(MODULE.ControllerError):
                self.execute_case_with_fakes(
                    Path(temp).resolve(),
                    clone_after_changed=True,
                )

    def test_execute_case_rejects_device_outside_clone_receipt_binding(self):
        with tempfile.TemporaryDirectory(prefix="sora-execute-case-device-binding-") as temp:
            root = Path(temp).resolve()
            with self.assertRaises(MODULE.ControllerError):
                self.execute_case_with_fakes(
                    root,
                    device="00008110-00FFFFFFFFFFFFFF",
                )
            self.assertFalse(
                (root / "execution" / "operation-receipts").exists()
            )

    def test_execute_case_fails_closed_on_missing_receipt(self):
        with tempfile.TemporaryDirectory(prefix="sora-execute-case-no-receipt-") as temp:
            with self.assertRaises(MODULE.ControllerError):
                self.execute_case_with_fakes(
                    Path(temp).resolve(),
                    omit_receipt=True,
                )

    def test_execute_case_fails_closed_on_missing_xcresult_receipt(self):
        with tempfile.TemporaryDirectory(prefix="sora-execute-case-no-test-receipt-") as temp:
            with self.assertRaises(MODULE.ControllerError):
                self.execute_case_with_fakes(
                    Path(temp).resolve(),
                    omit_test_receipt=True,
                )

    def test_execute_case_fails_before_install_on_wallet_tree_drift(self):
        with tempfile.TemporaryDirectory(prefix="sora-execute-case-wallet-drift-") as temp:
            root = Path(temp).resolve()
            clone_app = (
                root
                / "protected-clone"
                / "installable-app"
                / "Payload"
                / "SoraPassport.app"
            )
            with self.assertRaises(MODULE.ControllerError):
                self.execute_case_with_fakes(root, prepared_mismatch=True)
            operation_root = root / "execution" / "operation-receipts"
            self.assertFalse(
                (operation_root / "install-archive-derived-clone.json").exists()
            )
            self.assertTrue(clone_app.is_dir())

    def test_watch_only_is_successful_but_not_a_signing_claim(self):
        request = MODULE.validate_authorization_request(
            MODULE.canonical_json(self.request(case_id="watch-only"))
        )
        self.assertEqual(request["caseId"], "watch-only")
        self.assertNotIn("signingSucceeded", request)

    def test_unknown_bool_and_noncanonical_json_are_rejected(self):
        request = self.request()
        request["schemaVersion"] = True
        with self.assertRaises(MODULE.ControllerError):
            MODULE.validate_authorization_request(MODULE.canonical_json(request))
        raw = MODULE.canonical_json(self.request()).replace(b'"platform":"ios"', b'"platform": "ios"')
        with self.assertRaises(MODULE.ControllerError):
            MODULE.validate_authorization_request(raw)

    def test_expired_or_cross_kind_case_is_rejected(self):
        request = self.request(case_kind="device", case_id="watch-only")
        with self.assertRaises(MODULE.ControllerError):
            MODULE.validate_authorization_request(MODULE.canonical_json(request))
        request = self.request()
        request["issuedAtEpochSeconds"] = 1_600_000_000
        request["expiresAtEpochSeconds"] = 1_600_000_100
        with self.assertRaises(MODULE.ControllerError):
            MODULE.validate_authorization_request(MODULE.canonical_json(request))

    def test_der_signature_verifies_exact_canonical_request(self):
        request = MODULE.canonical_json(self.request())
        with tempfile.TemporaryDirectory(prefix="sora-ios-controller-signature-test-") as temp:
            root = Path(temp)
            private_key = root / "private.pem"
            public_key = root / "public.der"
            request_path = root / "request.json"
            signature_path = root / "request.sig"
            request_path.write_bytes(request)
            subprocess.run(
                [
                    "/usr/bin/openssl",
                    "ecparam",
                    "-name",
                    "prime256v1",
                    "-genkey",
                    "-noout",
                    "-out",
                    str(private_key),
                ],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=MODULE.SAFE_TOOL_ENV,
            )
            subprocess.run(
                [
                    "/usr/bin/openssl",
                    "ec",
                    "-in",
                    str(private_key),
                    "-pubout",
                    "-outform",
                    "DER",
                    "-out",
                    str(public_key),
                ],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=MODULE.SAFE_TOOL_ENV,
            )
            subprocess.run(
                [
                    "/usr/bin/openssl",
                    "dgst",
                    "-sha256",
                    "-sign",
                    str(private_key),
                    "-out",
                    str(signature_path),
                    str(request_path),
                ],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=MODULE.SAFE_TOOL_ENV,
            )
            public_der = public_key.read_bytes()
            self.assertTrue(public_der.endswith(b"\x04" + public_der[-64:]))
            point = public_der[-65:]
            signature = signature_path.read_bytes()
            binding = MODULE.validate_authority_binding(
                "protected-controller-2026",
                base64.b64encode(point).decode("ascii"),
                "a" * 40,
            )
            self.assertEqual(binding["sourceRevision"], "a" * 40)
            self.assertEqual(
                binding["authorizationPublicPointSha256"],
                MODULE.hashlib.sha256(point).hexdigest(),
            )
            MODULE.verify_authorization_signature(request, signature, point)
            with self.assertRaises(MODULE.ControllerError):
                MODULE.verify_authorization_signature(request + b" ", signature, point)

    def test_controller_contains_no_signing_or_promotion_cli(self):
        source = SCRIPT.read_text(encoding="utf-8")
        self.assertNotIn("--create-signature", source)
        self.assertNotIn("--promote", source)
        self.assertNotIn("upload", " ".join(MODULE.__dict__.get("USAGE", [])))
        self.assertEqual(
            MODULE.NONAUTHORIZING_BLOCKER,
            "Observed exact-IPA case only: this controller cannot sign, review, qualify, "
            "sequence, promote, upload, or enable a release.",
        )

    def test_preparation_cli_is_non_authorizing_and_exactly_scoped(self):
        source = SCRIPT.read_text(encoding="utf-8")
        self.assertIn('argv[3] == "--installable-clone-receipt"', source)
        self.assertIn('argv[0] == "--prepare-case"', source)
        self.assertIn('argv[13] == "--output-root"', source)
        self.assertIn('"authorizationCreated": False', source)
        self.assertIn('"qualificationCreated": False', source)
        self.assertIn("wallet_input_tree_record", source)
        self.assertNotIn("--authorization-private-key", source)
        self.assertNotIn("--qualification-sequence", source)

    def test_prepared_wallet_record_requires_real_wallet_inputs(self):
        with tempfile.TemporaryDirectory(prefix="sora-wallet-input-record-") as temp:
            root = Path(temp)
            core_data = root / "Documents" / "CoreData"
            preferences = root / "Library" / "Preferences"
            networks = root / "Library" / "Application Support" / "SORA" / "WalletNetworks"
            commits = root / "Library" / "Application Support" / "SORA" / "WalletAccountCommits"
            for directory in (core_data, preferences, networks, commits):
                directory.mkdir(parents=True)
            (core_data / "UserDataModel.sqlite").write_bytes(b"retained-store")
            (preferences / "co.jp.soramitsu.sora.plist").write_bytes(b"retained-settings")
            digest, byte_count, counts, paths = MODULE.wallet_input_tree_record(root)
            MODULE.validate_prepared_wallet_paths(paths, "mnemonic-12")
            self.assertRegex(digest, r"^[0-9a-f]{64}$")
            self.assertGreater(byte_count, len(MODULE.WALLET_INPUT_TREE_PREFIX))
            self.assertEqual(counts["Documents/CoreData"], 1)
            with self.assertRaises(MODULE.ControllerError):
                MODULE.validate_prepared_wallet_paths(paths, "recovery-archive-export")

            attempt = core_data / "WalletMigrationSafety" / str(uuid.uuid4()).upper()
            attempt.mkdir(parents=True)
            (attempt / "journal.json").write_bytes(b"{}")
            staging = attempt / "staging"
            staging.mkdir()
            stale_staging = staging / "UserDataModel.sqlite"
            stale_staging.write_bytes(b"wrong-model-name")
            _, _, _, stale_paths = MODULE.wallet_input_tree_record(root)
            with self.assertRaises(MODULE.ControllerError):
                MODULE.validate_prepared_wallet_paths(
                    stale_paths, "recovery-archive-export"
                )
            stale_staging.rename(staging / "UserDataModel 2.sqlite")
            _, _, _, recovery_paths = MODULE.wallet_input_tree_record(root)
            MODULE.validate_prepared_wallet_paths(
                recovery_paths, "recovery-archive-export"
            )

            (preferences / "co.jp.soramitsu.sora.plist").unlink()
            _, _, _, missing_preferences = MODULE.wallet_input_tree_record(root)
            with self.assertRaises(MODULE.ControllerError):
                MODULE.validate_prepared_wallet_paths(
                    missing_preferences, "mnemonic-12"
                )

    def test_enrollment_snapshot_rejects_stale_case_state(self):
        with tempfile.TemporaryDirectory(prefix="sora-enrollment-snapshot-") as temp:
            evidence = Path(temp) / "SoraWalletMigrationEvidence"
            evidence.mkdir()
            nonce = evidence / MODULE.ENROLLMENT_NONCE_NAME
            nonce.write_bytes(bytes(range(32)))
            digest, size = MODULE.require_enrollment_snapshot(Path(temp))
            self.assertEqual(size, 32)
            self.assertEqual(digest, MODULE.hashlib.sha256(bytes(range(32))).hexdigest())
            (evidence / MODULE.HARNESS_STATE_NAME).write_bytes(b"{}")
            with self.assertRaises(MODULE.ControllerError):
                MODULE.require_enrollment_snapshot(Path(temp))


if __name__ == "__main__":
    unittest.main(verbosity=2)
