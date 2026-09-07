#!/usr/bin/env python3
"""Hermetic standard-library regressions for the non-authorizing collector."""

from __future__ import annotations

import importlib.util
import hashlib
import json
import os
import pathlib
import re
import shutil
import sqlite3
import stat
import subprocess
import tempfile
import time
import unittest
import zipfile
import xml.etree.ElementTree as ElementTree


ROOT = pathlib.Path(__file__).resolve().parents[2]


def load_module(name: str, path: pathlib.Path):
    specification = importlib.util.spec_from_file_location(name, path)
    if specification is None or specification.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


COLLECTOR = load_module(
    "ios_migration_collector",
    ROOT / "SoraPassport/Scripts/collect-ios-migration-evidence.py",
)
CONTRACT = load_module(
    "ios_migration_contract",
    ROOT / "SoraPassport/Scripts/ios-migration-qualification-contract.py",
)
VALIDATOR = load_module(
    "ios_migration_validator",
    ROOT / "SoraPassport/Scripts/verify-ios-migration-qualification.py",
)


def contract_entry_map() -> dict[str, tuple[str, int]]:
    _, entries = CONTRACT.calculate_contract(ROOT)
    return {
        entry["relativePath"]: (entry["sha256"], entry["byteCount"])
        for entry in entries
    }


def create_common_tables(connection: sqlite3.Connection) -> None:
    connection.executescript(
        """
        CREATE TABLE ZCDCONNECTIONITEM (
          Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
          ZNETWORKTYPE INTEGER, ZORDER INTEGER, ZIDENTIFIER VARCHAR, ZTITLE VARCHAR
        );
        CREATE TABLE Z_METADATA (
          Z_VERSION INTEGER PRIMARY KEY, Z_UUID VARCHAR(255), Z_PLIST BLOB
        );
        CREATE TABLE Z_PRIMARYKEY (
          Z_ENT INTEGER PRIMARY KEY, Z_NAME VARCHAR, Z_SUPER INTEGER, Z_MAX INTEGER
        );
        """
    )


def create_model(connection: sqlite3.Connection, version: int) -> None:
    create_common_tables(connection)
    if version == 1:
        connection.execute(
            """CREATE TABLE ZCDACCOUNTITEM (
              Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
              ZCRYPTOTYPE INTEGER, ZNETWORKTYPE INTEGER, ZORDER INTEGER,
              ZIDENTIFIER VARCHAR, ZPUBLICKEY BLOB, ZUSERNAME VARCHAR
            )"""
        )
    else:
        connection.executescript(
            """
            CREATE TABLE ZCDACCOUNTITEM (
              Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
              ZCRYPTOTYPE INTEGER, ZNETWORKTYPE INTEGER, ZORDER INTEGER,
              ZISSELECTED INTEGER, ZSETTINGS INTEGER,
              ZIDENTIFIER VARCHAR, ZPUBLICKEY BLOB, ZUSERNAME VARCHAR
            );
            CREATE TABLE ZCDACCOUNTSETTINGS (
              Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
              ZFAVOURITEASSETS BLOB, ZLOCALE VARCHAR,
              ZORDEREDASSETS BLOB, ZVISIBLEASSETS BLOB
            );
            """
        )


class CollectorContractTests(unittest.TestCase):
    def test_retained_mnemonic_and_iroha_pair_cohorts_cannot_be_omitted(self) -> None:
        # The pre-fix eight-cohort run could qualify without exercising any of
        # these three released credential formats. Keep this input independent
        # of the collector's cohort declaration so shrinking it is detected.
        success_cohorts = [
            "mnemonic-12", "mnemonic-15-retained", "mnemonic-18-retained",
            "mnemonic-21-retained", "mnemonic-24", "iroha-v1-paired-keys",
            "raw-seed", "legacy-secret", "watch-only",
        ]
        failure_cohorts = ["missing-secret", "corrupt-secret"]
        new_cohorts = {
            "mnemonic-18-retained", "mnemonic-21-retained", "iroha-v1-paired-keys",
        }
        record = {
            **{key: "isolated-test-binding" for key in COLLECTOR.EXACT_CLONE_BINDING_KEYS},
            "schemaVersion": 3,
            "contractId": "sora-ios-wallet-migration-keychain-observations-v3",
            "platform": "ios",
            "runId": "isolated-test-run",
            "runChallengeSha256": "1" * 64,
            "sourceRevision": "2" * 40,
            "producerTestIdentifier": (
                "WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedKeychainCohortEvidence()"
            ),
            "observations": [{
                "cohortId": cohort,
                "outcome": "success" if cohort in success_cohorts else "recovery",
                "identifierSetUnchanged": True,
                "valuesByteForByteUnchanged": True,
                "accessibilityUnchanged": True,
                "credentialRewriteObserved": False,
                "signingProbePassed": cohort in success_cohorts,
                "recoveryRouteEntered": cohort in failure_cohorts,
            } for cohort in success_cohorts + failure_cohorts],
        }
        aggregate = COLLECTOR.inspect_keychain(record)
        self.assertEqual(aggregate["successfulSecretSourceCohortCount"], 9)
        self.assertEqual(aggregate["secretFailureCohortCount"], 2)
        stale = {**record, "observations": [
            item for item in record["observations"] if item["cohortId"] not in new_cohorts
        ]}
        with self.assertRaises(COLLECTOR.CollectionError):
            COLLECTOR.inspect_keychain(stale)
        for cohort in sorted(new_cohorts):
            for mutation in ("omitted", "duplicate", "signing-failed", "keys-changed"):
                with self.subTest(cohort=cohort, mutation=mutation):
                    changed = json.loads(json.dumps(record))
                    item = next(x for x in changed["observations"] if x["cohortId"] == cohort)
                    if mutation == "omitted":
                        changed["observations"].remove(item)
                    elif mutation == "duplicate":
                        item["cohortId"] = "mnemonic-15-retained"
                    elif mutation == "signing-failed":
                        item["signingProbePassed"] = False
                    else:
                        item["valuesByteForByteUnchanged"] = False
                    with self.assertRaises(COLLECTOR.CollectionError):
                        COLLECTOR.inspect_keychain(changed)

    def test_contract_snapshot_binds_parsed_manifest_bytes(self) -> None:
        digest, entries = CONTRACT.calculate_contract(ROOT)
        self.assertRegex(digest, r"^[0-9a-f]{64}$")
        self.assertGreater(len(entries), 50)
        self.assertEqual(
            entries[0]["relativePath"],
            CONTRACT.MANIFEST_RELATIVE_PATH.as_posix(),
        )

        application_id = "YLWWUD25VZ.co.jp.soramitsu.sora"
        info = {
            "CFBundleIdentifier": "co.jp.soramitsu.sora",
            "CFBundleExecutable": "SoraPassport",
            "CFBundleShortVersionString": "3.8.7",
            "CFBundleVersion": "2026081001",
        }
        signed = {
            "application-identifier": application_id,
            "com.apple.developer.team-identifier": "YLWWUD25VZ",
            "get-task-allow": False,
            "beta-reports-active": True,
        }
        profile = {
            "application-identifier": "YLWWUD25VZ.*",
            "com.apple.developer.team-identifier": "YLWWUD25VZ",
            "keychain-access-groups": ["YLWWUD25VZ.*", "com.apple.token"],
        }
        self.assertEqual(
            COLLECTOR.validate_production_entitlement_identity(
                info, profile, signed
            ),
            [application_id],
        )
        explicit_default = dict(signed)
        explicit_default["keychain-access-groups"] = [application_id]
        self.assertEqual(
            COLLECTOR.validate_production_entitlement_identity(
                info, profile, explicit_default
            ),
            [application_id],
        )
        shared_first = dict(signed)
        shared_first["keychain-access-groups"] = [
            "YLWWUD25VZ.shared.sora",
            application_id,
        ]
        app_first = dict(signed)
        app_first["keychain-access-groups"] = [
            application_id,
            "YLWWUD25VZ.shared.sora",
        ]
        self.assertNotEqual(
            COLLECTOR.validate_production_entitlement_identity(
                info, profile, shared_first
            ),
            COLLECTOR.validate_production_entitlement_identity(
                info, profile, app_first
            ),
        )
        token_only_profile = dict(profile)
        token_only_profile["keychain-access-groups"] = ["com.apple.token"]
        with self.assertRaisesRegex(COLLECTOR.CollectionError, "authorize"):
            COLLECTOR.validate_production_entitlement_identity(
                info, token_only_profile, signed
            )

    def test_reviewed_settings_inventory_is_source_derived(self) -> None:
        keys = COLLECTOR.reviewed_settings_keys(contract_entry_map())
        self.assertEqual(len(keys), 30)
        self.assertIn("selectedAccount", keys)
        self.assertIn("walletMigrationRecoveryRequired", keys)
        self.assertNotIn("selectedAddress", keys)

    def test_point_of_use_source_reads_require_admitted_digest(self) -> None:
        entries = contract_entry_map()
        self.assertEqual(len(COLLECTOR.expected_test_identifiers(entries)), 233)
        settings = "SoraPassport/Common/Extensions/SettingsExtension.swift"
        _, byte_count = entries[settings]
        entries[settings] = ("f" * 64, byte_count)
        with self.assertRaises(COLLECTOR.CollectionError):
            COLLECTOR.reviewed_settings_keys(entries)

    def test_device_event_projection_binds_reviewed_chronology(self) -> None:
        now = int(time.time())
        events = []
        for index, scenario in enumerate(sorted(COLLECTOR.EXPECTED_DEVICE_SCENARIOS)):
            events.append(
                {
                    "scenario": scenario,
                    "outcome": "passed",
                    "startedAtEpochSeconds": now - 1000 + index,
                    "finishedAtEpochSeconds": now - 999 + index,
                    "assertions": sorted(
                        COLLECTOR.EXPECTED_SCENARIO_ASSERTIONS[scenario]
                    ),
                }
            )
        record = {
            "schemaVersion": 3,
            "contractId": "sora-ios-wallet-migration-device-events-v3",
            "platform": "ios",
            "runId": "00000000-0000-4000-8000-000000000001",
            "runChallengeSha256": "1" * 64,
            "sourceRevision": "1" * 40,
            "productionIpaSha256": "2" * 64,
            "installedAppRawTreeSha256": "3" * 64,
            "installedAppRawTreeRecordByteCount": 123,
            "installedExecutableSha256": "4" * 64,
            "installedExecutableByteCount": 125,
            "productionCanonicalProjectionSha256": "5" * 64,
            "installedCanonicalProjectionSha256": "5" * 64,
            "canonicalProjectionReceiptSha256": "6" * 64,
            "canonicalProjectorSourceSha256": "7" * 64,
            "installedAppLaunchVerified": True,
            "installedRawTreeRecomputed": True,
            "installedExecutableRecomputed": True,
            "canonicalProjectionReceiptVerified": True,
            "canonicalProjectorSourceVerified": True,
            "canonicalProjectionEqualToProduction": True,
            "producerTestIdentifier": (
                "WalletMigrationRetainedDeviceEvidenceTests/"
                "testEmitRetainedDeviceScenarioEvidence()"
            ),
            "events": events,
        }
        aggregate, started, finished = COLLECTOR.inspect_device_events(
            record, now - 900, now - 100
        )
        self.assertEqual(started, now - 1000)
        self.assertEqual(finished, now - 100)
        original_projection = aggregate["eventProjectionSha256"]
        stale = dict(record)
        stale["schemaVersion"] = 2
        stale["contractId"] = "sora-ios-wallet-migration-device-events-v2"
        with self.assertRaises(COLLECTOR.CollectionError):
            COLLECTOR.inspect_device_events(stale, now - 900, now - 100)
        record["events"][0]["startedAtEpochSeconds"] += 1
        changed, _, _ = COLLECTOR.inspect_device_events(record, now - 900, now - 100)
        self.assertNotEqual(original_projection, changed["eventProjectionSha256"])
        record["events"][0]["finishedAtEpochSeconds"] = now
        with self.assertRaises(COLLECTOR.CollectionError):
            COLLECTOR.inspect_device_events(record, now - 900, now - 100)

    def test_installable_clone_receipt_replaces_legacy_test_host_wire(self) -> None:
        derived = {
            "ipaSha256": "1" * 64,
            "testHostRawTreeSha256": "2" * 64,
            "testHostRawTreeRecordByteCount": 4096,
            "canonicalProjectionSha256": "3" * 64,
            "canonicalProjectionRecordByteCount": 2048,
            "testHostExecutableSha256": "4" * 64,
            "testHostExecutableByteCount": 1024,
            "derivationReceiptSha256": "5" * 64,
        }
        receipt = {
            "schemaVersion": 1,
            "contractId": "sora-ios-wallet-migration-installable-clone-v1",
            "platform": "ios",
            "status": "observed",
            "releaseAuthorized": False,
            "qualificationContractSha256": "6" * 64,
            "productionIpaSha256": "1" * 64,
            "productionCanonicalProjectionSha256": "3" * 64,
            "installedAppRawTreeSha256": "2" * 64,
            "installedAppRawTreeRecordByteCount": 4096,
            "installedAppFileCount": 20,
            "installedCanonicalProjectionSha256": "3" * 64,
            "installedExecutableSha256": "4" * 64,
            "installedExecutableByteCount": 1024,
            "canonicalProjectionReceiptSha256": "5" * 64,
            "canonicalProjectorSourceSha256": "7" * 64,
            "registeredDeviceProvisioningProfileSha256": "8" * 64,
            "registeredDeviceSigningCertificateSha1": "9" * 40,
            "registeredDeviceUdidSha256": "a" * 64,
            "checks": {
                "exactProductionIpaExtracted": True,
                "registeredDeviceProfileVerified": True,
                "productionIdentityPreserved": True,
                "canonicalProjectionEqual": True,
                "installedCloneCodeSignatureDeepStrictVerified": True,
                "rebuiltApplicationAccepted": False,
                "qualificationCreated": False,
            },
            "blockingReasons": [
                "Observed installable clone only: no rebuilt app is accepted; this controller cannot "
                "authorize, review, qualify, sequence, promote, upload, or enable a release."
            ],
        }
        with tempfile.TemporaryDirectory(prefix="ios-migration-clone-receipt-") as temp:
            path = pathlib.Path(temp) / "installable-clone-receipt-v1.json"
            path.write_bytes(COLLECTOR.canonical_json(receipt))
            admitted = COLLECTOR.validate_installable_clone_receipt(
                path,
                derived,
                "6" * 64,
                "7" * 64,
            )
            self.assertEqual(admitted["installedAppRawTreeSha256"], "2" * 64)
            self.assertEqual(admitted["installedExecutableSha256"], "4" * 64)
            self.assertEqual(
                admitted["productionCanonicalProjectionSha256"],
                admitted["installedCanonicalProjectionSha256"],
            )

            stale = dict(receipt)
            stale["testHostRawTreeSha256"] = stale.pop(
                "installedAppRawTreeSha256"
            )
            path.unlink()
            path.write_bytes(COLLECTOR.canonical_json(stale))
            with self.assertRaises(COLLECTOR.CollectionError):
                COLLECTOR.validate_installable_clone_receipt(
                    path,
                    derived,
                    "6" * 64,
                    "7" * 64,
                )

    def test_signature_admission_consumes_captured_bytes(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ios-migration-signature-") as temp:
            directory = pathlib.Path(temp)
            private_key = directory / "private.pem"
            public_key = directory / "public.pem"
            signature_path = directory / "payload.sig"
            payload = b"descriptor-bound-migration-evidence"
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
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            subprocess.run(
                [
                    "/usr/bin/openssl",
                    "ec",
                    "-in",
                    str(private_key),
                    "-pubout",
                    "-out",
                    str(public_key),
                ],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
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
                ],
                input=payload,
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            key = public_key.read_bytes()
            signature = signature_path.read_bytes()
            key_digest = hashlib.sha256(key).hexdigest()
            self.assertTrue(
                VALIDATOR.validate_p256_key(key, key_digest, "test producer key")
            )
            VALIDATOR.verify_signature(
                payload, signature, key, key_digest, "test migration evidence"
            )
            with self.assertRaises(VALIDATOR.QualificationError):
                VALIDATOR.verify_signature(
                    payload + b"-changed",
                    signature,
                    key,
                    key_digest,
                    "mutated migration evidence",
                )

    def test_account_item_decoder_accepts_only_real_codable_shapes(self) -> None:
        required = {
            "address": "retained-wallet",
            "cryptoType": 0,
            "username": "SORA",
            "publicKeyData": "AQID",
        }
        self.assertEqual(
            COLLECTOR.decoded_selected_account_address(
                json.dumps(required).encode(), "selected"
            ),
            "retained-wallet",
        )
        malformed = dict(required, cryptoType=True)
        with self.assertRaises(COLLECTOR.CollectionError):
            COLLECTOR.decoded_selected_account_address(
                json.dumps(malformed).encode(), "selected"
            )
        unknown = dict(required, secret="forbidden")
        with self.assertRaises(COLLECTOR.CollectionError):
            COLLECTOR.decoded_selected_account_address(
                json.dumps(unknown).encode(), "selected"
            )

    def test_exact_v1_and_v2_model_fingerprints(self) -> None:
        for version, expected in ((1, "UserDataModel"), (2, "UserDataModel 2")):
            connection = sqlite3.connect(":memory:")
            try:
                create_model(connection, version)
                self.assertEqual(
                    COLLECTOR.reviewed_core_data_model(connection, f"v{version}"),
                    expected,
                )
                connection.execute("ALTER TABLE ZCDACCOUNTITEM ADD COLUMN ZUNREVIEWED BLOB")
                with self.assertRaises(COLLECTOR.CollectionError):
                    COLLECTOR.reviewed_core_data_model(connection, f"v{version}-drift")
            finally:
                connection.close()

    def test_duplicate_wallet_identifiers_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ios-migration-db-") as temp:
            path = pathlib.Path(temp) / "UserDataModel.sqlite"
            connection = sqlite3.connect(path)
            create_model(connection, 2)
            connection.executemany(
                """INSERT INTO ZCDACCOUNTITEM (
                  Z_PK,Z_ENT,Z_OPT,ZCRYPTOTYPE,ZNETWORKTYPE,ZORDER,ZISSELECTED,
                  ZSETTINGS,ZIDENTIFIER,ZPUBLICKEY,ZUSERNAME
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
                [
                    (1, 1, 1, 0, 69, 0, 1, None, "same", b"a", "one"),
                    (2, 1, 1, 0, 69, 1, 0, None, "same", b"b", "two"),
                ],
            )
            connection.commit()
            connection.close()
            with self.assertRaises(COLLECTOR.CollectionError):
                COLLECTOR.sqlite_accounts(path, "duplicate-wallets")

    def test_ipa_entry_names_reject_normalized_and_casefold_collisions(self) -> None:
        regular_mode = (stat.S_IFREG | 0o600) << 16
        entries = [
            zipfile.ZipInfo("Payload/Sora.app/Info.plist"),
            zipfile.ZipInfo("Payload/Sora.app/./Info.plist"),
        ]
        for entry in entries:
            entry.external_attr = regular_mode
        with self.assertRaises(COLLECTOR.CollectionError):
            COLLECTOR.validate_zip_entry_inventory(entries, "IPA", 10, 1024)
        entries = [
            zipfile.ZipInfo("Payload/Sora.app/A"),
            zipfile.ZipInfo("Payload/Sora.app/a"),
        ]
        for entry in entries:
            entry.external_attr = regular_mode
        with self.assertRaises(COLLECTOR.CollectionError):
            COLLECTOR.validate_zip_entry_inventory(entries, "IPA", 10, 1024)

    def test_anchored_snapshot_rejects_symlink_and_hardlink_aliases(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ios-migration-raw-") as source_temp:
            with tempfile.TemporaryDirectory(prefix="ios-migration-stage-") as stage_temp:
                source = pathlib.Path(source_temp).resolve()
                stage = pathlib.Path(stage_temp).resolve()
                original = source / "request.json"
                original.write_bytes(b"{}")
                os.link(original, source / "alias.json")
                with self.assertRaises(COLLECTOR.CollectionError):
                    COLLECTOR.snapshot_anchored_tree(
                        source, stage, "hard-linked raw input"
                    )
        with tempfile.TemporaryDirectory(prefix="ios-migration-raw-") as source_temp:
            with tempfile.TemporaryDirectory(prefix="ios-migration-stage-") as stage_temp:
                source = pathlib.Path(source_temp).resolve()
                stage = pathlib.Path(stage_temp).resolve()
                original = source / "request.json"
                original.write_bytes(b"{}")
                os.symlink(original.name, source / "alias.json")
                with self.assertRaises(COLLECTOR.CollectionError):
                    COLLECTOR.snapshot_anchored_tree(
                        source, stage, "symbolic raw input"
                    )

    def test_fixed_layout_rejects_unreviewed_sidecars(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ios-migration-layout-") as temp:
            root = pathlib.Path(temp)
            (root / "request.json").write_bytes(b"{}")
            (root / "application").mkdir()
            (root / "application/Sora.ipa").write_bytes(b"x")
            (root / "tests").mkdir()
            (root / "tests/Migration.xcresult").mkdir()
            (root / "snapshots").mkdir()
            (root / "snapshots/index.json").write_bytes(b"{}")
            (root / "snapshots/data").mkdir()
            with self.assertRaises(COLLECTOR.CollectionError):
                COLLECTOR.validate_fixed_raw_layout(root)
            (root / "application/SoraPassport.app").mkdir()
            (root / "application/canonical-projection-receipt-v2.json").write_bytes(b"{}")
            (root / "application/installable-clone-receipt-v1.json").write_bytes(b"{}")
            COLLECTOR.validate_fixed_raw_layout(root)
            (root / "caller-claims.json").write_bytes(b"{}")
            with self.assertRaises(COLLECTOR.CollectionError):
                COLLECTOR.validate_fixed_raw_layout(root)

    def test_collector_contract_is_non_authorizing(self) -> None:
        COLLECTOR.lint_contract()
        source = (
            ROOT / "SoraPassport/Scripts/collect-ios-migration-evidence.py"
        ).read_text(encoding="utf-8")
        self.assertIn('"status": "observed"', source)
        self.assertIn('"releaseAuthorized": False', source)
        self.assertNotIn('"status": "qualified"', source)

    def test_retained_device_evidence_scheme_and_producers_are_exact(self) -> None:
        producer_path = (
            ROOT
            / "SoraPassportIntegrationTests/WalletMigrationRetainedDeviceEvidenceTests.swift"
        )
        producer = producer_path.read_text(encoding="utf-8")
        methods = re.findall(
            r"^[ \t]+func[ \t]+(test[A-Za-z0-9_]+)[ \t]*\(",
            producer,
            re.MULTILINE,
        )
        self.assertEqual(
            methods,
            [
                "testEmitRetainedDeviceRunBinding",
                "testEmitRetainedKeychainCohortEvidence",
                "testEmitRetainedDeviceScenarioEvidence",
            ],
        )
        for marker in (
            "#if targetEnvironment(simulator)",
            "#if DEBUG",
            'private static let productionBundleIdentifier = "co.jp.soramitsu.sora"',
            'private static let directoryName = "SoraWalletMigrationEvidence"',
            'private static let fileName = "retained-device-observation-ledger-v3.json"',
            '"SORA-IOS-MIGRATION-RAW-APP-TREE-V1\\0"',
            '"canonicalProjectionEqualToProduction": true',
            '"canonicalProjectionReceiptVerified": true',
            '"canonicalProjectorSourceVerified": true',
            "O_RDONLY | O_CLOEXEC | O_NOFOLLOW",
            "protection == .complete",
            "attachment.lifetime = .keepAlways",
        ):
            self.assertIn(marker, producer)

        scheme_path = (
            ROOT
            / "SoraPassport.xcodeproj/xcshareddata/xcschemes/SoraPassportMigrationEvidence.xcscheme"
        )
        scheme = ElementTree.parse(scheme_path).getroot()
        test_action = scheme.find("TestAction")
        self.assertIsNotNone(test_action)
        assert test_action is not None
        self.assertEqual(test_action.attrib.get("buildConfiguration"), "Release")
        self.assertEqual(test_action.attrib.get("shouldUseLaunchSchemeArgsEnv"), "YES")
        selected = {
            element.attrib["Identifier"]
            for element in test_action.findall("./Testables/TestableReference/SelectedTests/Test")
        }
        self.assertEqual(
            selected,
            {
                "WalletModernizationTests",
                "WalletRecoveryCapabilityGateTests",
                "WalletRecoveryExporterTests",
                "WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedDeviceRunBinding()",
                "WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedKeychainCohortEvidence()",
                "WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedDeviceScenarioEvidence()",
            },
        )
        self.assertEqual(
            len(COLLECTOR.expected_test_identifiers(contract_entry_map())), 233
        )

    def test_collection_job_cannot_promote_or_sign(self) -> None:
        runner = (
            ROOT / "SoraPassport/Scripts/run-ios-migration-evidence-collection.sh"
        ).read_text(encoding="utf-8")
        job = (ROOT / "Jenkinsfile.migration-evidence").read_text(encoding="utf-8")
        combined = runner + "\n" + job
        for forbidden in (
            "--verify-qualified",
            "withCredentials",
            "sshagent",
            "IOS_MIGRATION_QUALIFICATION_DEVICE_EVIDENCE_PRODUCER_PRIVATE_KEY=",
            "IOS_MIGRATION_QUALIFICATION_INDEPENDENT_REVIEWER_PRIVATE_KEY=",
        ):
            self.assertNotIn(forbidden, combined)
        for marker in (
            "IOS_MIGRATION_QUALIFICATION_SEQUENCE_NUMBER",
            "IOS_MIGRATION_QUALIFICATION_RECEIPT_REVIEWER_SIGNATURE_PATH",
            "IOS_MIGRATION_QUALIFICATION_EVIDENCE_DEVICE_SIGNATURE_PATH",
            "IOS_MIGRATION_QUALIFICATION_EVIDENCE_REVIEWER_SIGNATURE_PATH",
            "IOS_PRODUCTION_MUTATIONS_ENABLED",
            "--lint-contract",
            "--collect",
        ):
            self.assertIn(marker, runner)
        self.assertEqual(
            job.count("run-ios-migration-evidence-collection.sh"),
            2,
        )
        self.assertIn('/usr/bin/diff -rq "${first}" "${second}"', job)
        self.assertIn("archiveArtifacts(", job)
        for artifact in COLLECTOR.OUTPUT_NAMES.values():
            self.assertEqual(job.count(artifact), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
