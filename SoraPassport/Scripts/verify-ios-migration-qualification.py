#!/usr/bin/env python3
"""Fail-closed authentication for retained iOS wallet-migration evidence."""

from __future__ import annotations

import hashlib
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
import time
import uuid
import zipfile
from pathlib import Path, PurePosixPath
from typing import Any, Optional


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "Fixtures" / "Modernization"
OPENSSL = Path("/usr/bin/openssl")
MAX_JSON_BYTES = 2 * 1024 * 1024
MAX_KEY_BYTES = 16 * 1024
MAX_SIGNATURE_BYTES = 16 * 1024
MAX_XCRESULT_ZIP_BYTES = 1024 * 1024 * 1024
MAX_IPA_BYTES = 4 * 1024 * 1024 * 1024
MAX_ZIP_ENTRIES = 100_000
MAX_ZIP_UNCOMPRESSED_BYTES = 4 * 1024 * 1024 * 1024
MAX_RAW_FILE_BYTES = 4 * 1024 * 1024 * 1024
MAX_RAW_FILES = 200_000
MAX_RAW_BYTES = 16 * 1024 * 1024 * 1024
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SHA1_RE = re.compile(r"^[0-9a-f]{40}$")
KEY_ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{2,127}$")
SAFE_COMPONENT_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9._+@-]{0,255}$")
SAFE_OPENSSL_ENV = {
    "PATH": "/usr/bin:/bin",
    "LANG": "C",
    "LC_ALL": "C",
}
SAFE_COLLECTOR_ENV = {
    "PATH": "/usr/bin:/bin",
    "LANG": "C",
    "LC_ALL": "C",
}
COLLECTOR = ROOT / "SoraPassport/Scripts/collect-ios-migration-evidence.py"
CONTRACT_TOOL = ROOT / "SoraPassport/Scripts/ios-migration-qualification-contract.py"
NONAUTHORIZING_BLOCKER = (
    "Observed collection only: independent review, protected trust pins, detached signatures, "
    "append-only sequence admission, and a schema-8 qualification receipt are absent."
)
FORBIDDEN_KEY_PARTS = (
    "accountid",
    "accountidentifier",
    "address",
    "deviceid",
    "deviceidentifier",
    "mnemonic",
    "phrase",
    "privatekey",
    "publickey",
    "rawkeychain",
    "rawsignedpayload",
    "seed",
    "secret",
    "serialnumber",
    "signature",
    "signedpayload",
    "udid",
    "walletid",
)
SAFE_AGGREGATE_KEYS = {
    "addressparity",
    "keychainidentityunchanged",
    "legacysecretqualified",
    "missingorcorruptsecretqualified",
    "secretfailurecohortcount",
    "sora2addressparityqualified",
    "successfulsecretsourcecohortcount",
    "productioncodesignatureverified",
    "codesignaturedeepstrictverified",
}
IDENTITY_KEYS = {
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
}
IDENTITY_SHA_KEYS = {
    "productionIpaSha256",
    "installedAppRawTreeSha256",
    "installedExecutableSha256",
    "productionCanonicalProjectionSha256",
    "installedCanonicalProjectionSha256",
    "canonicalProjectionReceiptSha256",
    "canonicalProjectorSourceSha256",
}
IDENTITY_COUNT_KEYS = {
    "installedAppRawTreeRecordByteCount",
    "installedExecutableByteCount",
}
RECEIPT_PRIVACY_KEYS = {
    "aggregateOnly",
    "accountIdentifiersIncluded",
    "addressesIncluded",
    "deviceIdentifiersIncluded",
    "secretsIncluded",
    "phrasesOrSeedsIncluded",
    "privateKeysIncluded",
    "publicKeysIncluded",
    "rawKeychainValuesIncluded",
    "signedPayloadsIncluded",
    "rawSignedPayloadsIncluded",
    "perWalletRecordsIncluded",
}
EVIDENCE_PRIVACY_KEYS = RECEIPT_PRIVACY_KEYS - {
    "secretsIncluded",
    "signedPayloadsIncluded",
}
RECEIPT_ROOT_KEYS = {
    "schemaVersion",
    "contractId",
    "platform",
    "status",
    "runId",
    "runChallengeSha256",
    "rawInputSetSha256",
    "qualificationSequenceNumber",
    "sourceRevision",
    "qualifiedAtEpochSeconds",
    "reviewedAtEpochSeconds",
    "trustRootSha256",
    "evidenceManifestSha256",
    "collectionReceiptSha256",
    "deviceEvidenceProducerKeyId",
    "independentReviewerKeyId",
    "identity",
    "privacy",
    "sourceModelVersions",
    "targetModelVersion",
    "retainedCoreDataModelCount",
    "retainedCoreDataCohortCount",
    "singleAccountCohortCount",
    "multiAccountCohortCount",
    "successfulSecretSourceCohortCount",
    "secretFailureCohortCount",
    "currentSchemaSafetySnapshotCohortCount",
    "interruptionPointCohortCount",
    "retainedReleaseSnapshotCount",
    "retainedReleaseSnapshotManifestSha256",
    "executedWalletModernizationTestCount",
    "executedRecoveryCapabilityGateTestCount",
    "executedRecoveryExporterTestCount",
    "executedRetainedDeviceEvidenceTestCount",
    "testFailureCount",
    "testUnexpectedFailureCount",
    "testSkippedCount",
    "testExpectedFailureCount",
    "testResultBundleSha256",
    "keychainEvidenceSha256",
    "deviceExecutionEvidenceSha256",
    "zeroLostAccounts",
    "accountCountParity",
    "selectedWalletParity",
    "preferencesParity",
    "keychainIdentityUnchanged",
    "keychainAccessibilityUnchanged",
    "legacyStoresRetainedForDualRead",
    "sora2SigningParity",
    "coreDataModelSha256",
    "qualificationContractSha256",
    "qualificationChecks",
    "blockingReasons",
}
CORE_DATA_MODEL_KEYS = {"version1", "version2"}
QUALIFICATION_CHECK_KEYS = {
    "allRetainedCoreDataSnapshotsQualified",
    "backupManifestIntegrityQualified",
    "currentSchemaSafetySnapshotQualified",
    "dualReadQualified",
    "explicitRemovalQualified",
    "interruptedMigrationQualified",
    "keychainAccessibilityQualified",
    "legacyContinuationQualified",
    "legacyEmptySuffixQualified",
    "legacySecretQualified",
    "lifecycleConcurrencyQualified",
    "lowStorageQualified",
    "missingOrCorruptSecretQualified",
    "multiAccountQualified",
    "newWalletCommitJournalQualified",
    "pendingMutationDeletionPreflightQualified",
    "rawSeedQualified",
    "retainedFifteenWordMnemonicQualified",
    "recoveryArchiveExportQualified",
    "reinstallUpgradeQualified",
    "rollbackQualified",
    "selectedWalletLegacyMetadataQualified",
    "selectionGraphAtomicityQualified",
    "singleAccountQualified",
    "twelveWordMnemonicQualified",
    "twentyFourWordMnemonicQualified",
    "walSidecarQualified",
    "watchOnlyQualified",
}
EVIDENCE_ROOT_KEYS = {
    "schemaVersion",
    "contractId",
    "platform",
    "status",
    "runId",
    "runChallengeSha256",
    "rawInputSetSha256",
    "qualificationSequenceNumber",
    "sourceRevision",
    "producedAtEpochSeconds",
    "qualificationContractSha256",
    "trustRootSha256",
    "deviceEvidenceProducerKeyId",
    "independentReviewerKeyId",
    "identity",
    "chronology",
    "artifacts",
    "privacy",
    "blockingReasons",
}
CHRONOLOGY_KEYS = {
    "runStartedAtEpochSeconds",
    "runFinishedAtEpochSeconds",
    "snapshotManifestProducedAtEpochSeconds",
    "testResultProducedAtEpochSeconds",
    "keychainEvidenceProducedAtEpochSeconds",
    "deviceExecutionEvidenceProducedAtEpochSeconds",
    "collectionReceiptProducedAtEpochSeconds",
}
ARTIFACT_KEYS = {
    "collectionReceipt",
    "retainedReleaseSnapshotManifest",
    "testResultBundle",
    "keychainEvidence",
    "deviceExecutionEvidence",
}
ARTIFACT_ENTRY_KEYS = {"relativePath", "sha256", "byteCount"}
COLLECTION_ROOT_KEYS = {
    "schemaVersion",
    "contractId",
    "platform",
    "status",
    "releaseAuthorized",
    "runId",
    "runChallengeSha256",
    "sourceRevision",
    "qualificationContractSha256",
    "collectedAtEpochSeconds",
    "rawInputSet",
    "identity",
    "testedApplication",
    "installedClone",
    "privacy",
    "toolchain",
    "artifacts",
    "checks",
    "blockingReasons",
}
COLLECTION_RAW_INPUT_KEYS = {"contractId", "sha256", "fileCount", "byteCount"}
COLLECTION_TESTED_APPLICATION_KEYS = {
    "sha256",
    "byteCount",
    "bundleIdentifier",
    "shortVersion",
    "buildVersion",
    "executableSha256",
    "executableByteCount",
    "productionCodeSignatureVerified",
    "productionApplicationIdentifierVerified",
    "productionTeamIdentifierVerified",
    "productionKeychainAccessGroupVerified",
}
COLLECTION_INSTALLED_CLONE_KEYS = {
    "receiptSha256",
    "rawTreeSha256",
    "rawTreeRecordByteCount",
    "executableSha256",
    "executableByteCount",
    "productionCanonicalProjectionSha256",
    "installedCanonicalProjectionSha256",
    "canonicalProjectionReceiptSha256",
    "canonicalProjectorSourceSha256",
    "codeSignatureDeepStrictVerified",
    "installedAppLaunchVerified",
    "installedRawTreeRecomputed",
    "installedExecutableRecomputed",
    "canonicalProjectionEqualToProduction",
}
COLLECTION_TOOLCHAIN_KEYS = {"xcodeBuildVersion", "xcresultFormatVersion"}
COLLECTION_CHECK_KEYS = {
    "allRawFilesRegular",
    "allRawHashesVerified",
    "testedProductionIpaOpened",
    "signedProductionIdentityVerified",
    "installableCloneReceiptVerified",
    "installedCloneCodeSignatureVerified",
    "installedCloneIdentityBound",
    "canonicalProjectionReceiptVerified",
    "canonicalProjectorSourceVerified",
    "rawXcresultParsed",
    "retainedStoresOpenedReadOnly",
    "keychainObservationsBound",
    "deviceScenarioAttachmentsBound",
    "collectorNonAuthorizing",
}
TRUST_ROOT_KEYS = {
    "schemaVersion",
    "contractId",
    "platform",
    "status",
    "signatureAlgorithm",
    "authorities",
    "replayPolicy",
    "blockingReasons",
}
AUTHORITY_KEYS = {"role", "keyId", "publicKeyPemSha256", "enabled"}
REPLAY_POLICY_KEYS = {
    "maximumQualificationAgeSeconds",
    "maximumRunDurationSeconds",
    "maximumReviewDelaySeconds",
}


class QualificationError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise QualificationError(message)


def duplicate_rejecting_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            fail(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_json_bytes(raw: bytes, label: str) -> dict[str, Any]:
    if raw.startswith(b"\xef\xbb\xbf"):
        fail(f"{label} must not contain a UTF-8 BOM")
    try:
        text = raw.decode("utf-8", errors="strict")
        value = json.loads(
            text,
            object_pairs_hook=duplicate_rejecting_object,
            parse_constant=lambda constant: fail(
                f"{label} contains non-finite JSON number: {constant}"
            ),
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fail(f"{label} is not strict JSON: {error}")
    if type(value) is not dict:
        fail(f"{label} must contain one JSON object")
    validate_json_bounds(value, label)
    return value


def validate_json_bounds(value: Any, label: str, depth: int = 0) -> None:
    if depth > 32:
        fail(f"{label} exceeds the maximum JSON depth")
    if type(value) is dict:
        if len(value) > 512:
            fail(f"{label} contains too many object fields")
        for key, child in value.items():
            if type(key) is not str or not key or len(key.encode("utf-8")) > 256:
                fail(f"{label} contains an invalid JSON key")
            validate_json_bounds(child, f"{label}.{key}", depth + 1)
    elif type(value) is list:
        if len(value) > 20_000:
            fail(f"{label} contains too many array items")
        for index, child in enumerate(value):
            validate_json_bounds(child, f"{label}[{index}]", depth + 1)
    elif type(value) is str:
        if len(value.encode("utf-8")) > 16_384:
            fail(f"{label} contains an oversized string")
    elif type(value) is int and not (-9_999_999_999_999 <= value <= 9_999_999_999_999):
        fail(f"{label} contains an out-of-range integer")
    elif type(value) is float:
        fail(f"{label} contains an unsupported floating-point value")
    elif value is not None and type(value) not in (bool, int):
        fail(f"{label} contains an unsupported JSON value")


def exact_keys(value: Any, expected: set[str], label: str) -> None:
    if type(value) is not dict or set(value) != expected:
        fail(f"{label} contains missing or unreviewed fields")


def require_types(value: Any, allowed: tuple[type, ...], label: str) -> None:
    if type(value) not in allowed:
        fail(f"{label} has an invalid wire type")


def validate_wire_shapes(
    receipt: dict[str, Any], evidence: dict[str, Any], trust: dict[str, Any]
) -> None:
    exact_keys(receipt, RECEIPT_ROOT_KEYS, "migration receipt")
    exact_keys(receipt["identity"], IDENTITY_KEYS, "migration receipt.identity")
    exact_keys(receipt["privacy"], RECEIPT_PRIVACY_KEYS, "migration receipt.privacy")
    exact_keys(
        receipt["coreDataModelSha256"],
        CORE_DATA_MODEL_KEYS,
        "migration receipt.coreDataModelSha256",
    )
    exact_keys(
        receipt["qualificationChecks"],
        QUALIFICATION_CHECK_KEYS,
        "migration receipt.qualificationChecks",
    )
    for key in (
        "schemaVersion",
        "qualificationSequenceNumber",
        "qualifiedAtEpochSeconds",
        "reviewedAtEpochSeconds",
        "retainedCoreDataModelCount",
        "retainedCoreDataCohortCount",
        "singleAccountCohortCount",
        "multiAccountCohortCount",
        "successfulSecretSourceCohortCount",
        "secretFailureCohortCount",
        "currentSchemaSafetySnapshotCohortCount",
        "interruptionPointCohortCount",
        "retainedReleaseSnapshotCount",
        "executedWalletModernizationTestCount",
        "executedRecoveryCapabilityGateTestCount",
        "executedRecoveryExporterTestCount",
        "executedRetainedDeviceEvidenceTestCount",
        "testFailureCount",
        "testUnexpectedFailureCount",
        "testSkippedCount",
        "testExpectedFailureCount",
    ):
        require_types(receipt[key], (int,), f"migration receipt.{key}")
    for key in ("contractId", "platform", "status", "targetModelVersion"):
        require_types(receipt[key], (str,), f"migration receipt.{key}")
    for key in (
        "runId",
        "runChallengeSha256",
        "rawInputSetSha256",
        "sourceRevision",
        "trustRootSha256",
        "evidenceManifestSha256",
        "collectionReceiptSha256",
        "deviceEvidenceProducerKeyId",
        "independentReviewerKeyId",
        "retainedReleaseSnapshotManifestSha256",
        "testResultBundleSha256",
        "keychainEvidenceSha256",
        "deviceExecutionEvidenceSha256",
        "qualificationContractSha256",
    ):
        require_types(receipt[key], (type(None), str), f"migration receipt.{key}")
    for key in (
        "zeroLostAccounts",
        "accountCountParity",
        "selectedWalletParity",
        "preferencesParity",
        "keychainIdentityUnchanged",
        "keychainAccessibilityUnchanged",
        "legacyStoresRetainedForDualRead",
        "sora2SigningParity",
    ):
        require_types(receipt[key], (bool,), f"migration receipt.{key}")
    require_types(receipt["sourceModelVersions"], (list,), "migration receipt.sourceModelVersions")
    require_types(receipt["blockingReasons"], (list,), "migration receipt.blockingReasons")
    for key in IDENTITY_SHA_KEYS:
        require_types(
            receipt["identity"][key],
            (type(None), str),
            f"migration receipt.identity.{key}",
        )
    for key in IDENTITY_COUNT_KEYS:
        require_types(
            receipt["identity"][key],
            (int,),
            f"migration receipt.identity.{key}",
        )
    for key in ("deviceClasses", "operatingSystemBuilds"):
        require_types(receipt["identity"][key], (list,), f"migration receipt.identity.{key}")
    for key in RECEIPT_PRIVACY_KEYS:
        require_types(receipt["privacy"][key], (bool,), f"migration receipt.privacy.{key}")
    for key in CORE_DATA_MODEL_KEYS:
        require_types(
            receipt["coreDataModelSha256"][key],
            (type(None), str),
            f"migration receipt.coreDataModelSha256.{key}",
        )
    for key in QUALIFICATION_CHECK_KEYS:
        require_types(
            receipt["qualificationChecks"][key],
            (bool,),
            f"migration receipt.qualificationChecks.{key}",
        )

    exact_keys(evidence, EVIDENCE_ROOT_KEYS, "migration evidence manifest")
    exact_keys(evidence["identity"], IDENTITY_KEYS, "migration evidence manifest.identity")
    exact_keys(
        evidence["chronology"],
        CHRONOLOGY_KEYS,
        "migration evidence manifest.chronology",
    )
    exact_keys(evidence["artifacts"], ARTIFACT_KEYS, "migration evidence manifest.artifacts")
    for artifact_name in ARTIFACT_KEYS:
        exact_keys(
            evidence["artifacts"][artifact_name],
            ARTIFACT_ENTRY_KEYS,
            f"migration evidence manifest.artifacts.{artifact_name}",
        )
    exact_keys(
        evidence["privacy"],
        EVIDENCE_PRIVACY_KEYS,
        "migration evidence manifest.privacy",
    )
    for key in ("schemaVersion", "qualificationSequenceNumber", "producedAtEpochSeconds"):
        require_types(evidence[key], (int,), f"migration evidence manifest.{key}")
    for key in ("contractId", "platform", "status"):
        require_types(evidence[key], (str,), f"migration evidence manifest.{key}")
    for key in (
        "runId",
        "runChallengeSha256",
        "rawInputSetSha256",
        "sourceRevision",
        "qualificationContractSha256",
        "trustRootSha256",
        "deviceEvidenceProducerKeyId",
        "independentReviewerKeyId",
    ):
        require_types(
            evidence[key], (type(None), str), f"migration evidence manifest.{key}"
        )
    for key in IDENTITY_SHA_KEYS:
        require_types(
            evidence["identity"][key],
            (type(None), str),
            f"migration evidence manifest.identity.{key}",
        )
    for key in IDENTITY_COUNT_KEYS:
        require_types(
            evidence["identity"][key],
            (int,),
            f"migration evidence manifest.identity.{key}",
        )
    for key in ("deviceClasses", "operatingSystemBuilds"):
        require_types(
            evidence["identity"][key],
            (list,),
            f"migration evidence manifest.identity.{key}",
        )
    for key in CHRONOLOGY_KEYS:
        require_types(
            evidence["chronology"][key],
            (int,),
            f"migration evidence manifest.chronology.{key}",
        )
    for artifact_name in ARTIFACT_KEYS:
        require_types(
            evidence["artifacts"][artifact_name]["relativePath"],
            (str,),
            f"migration evidence manifest.artifacts.{artifact_name}.relativePath",
        )
        require_types(
            evidence["artifacts"][artifact_name]["sha256"],
            (type(None), str),
            f"migration evidence manifest.artifacts.{artifact_name}.sha256",
        )
        require_types(
            evidence["artifacts"][artifact_name]["byteCount"],
            (int,),
            f"migration evidence manifest.artifacts.{artifact_name}.byteCount",
        )
    for key in EVIDENCE_PRIVACY_KEYS:
        require_types(
            evidence["privacy"][key],
            (bool,),
            f"migration evidence manifest.privacy.{key}",
        )
    require_types(
        evidence["blockingReasons"], (list,), "migration evidence manifest.blockingReasons"
    )

    exact_keys(trust, TRUST_ROOT_KEYS, "migration trust root")
    exact_keys(
        trust["authorities"],
        {"deviceEvidenceProducer", "independentReviewer"},
        "migration trust root.authorities",
    )
    for authority_name in ("deviceEvidenceProducer", "independentReviewer"):
        exact_keys(
            trust["authorities"][authority_name],
            AUTHORITY_KEYS,
            f"migration trust root.authorities.{authority_name}",
        )
    exact_keys(
        trust["replayPolicy"],
        REPLAY_POLICY_KEYS,
        "migration trust root.replayPolicy",
    )
    for key in ("schemaVersion",):
        require_types(trust[key], (int,), f"migration trust root.{key}")
    for key in ("contractId", "platform", "status", "signatureAlgorithm"):
        require_types(trust[key], (str,), f"migration trust root.{key}")
    for authority_name in ("deviceEvidenceProducer", "independentReviewer"):
        authority = trust["authorities"][authority_name]
        require_types(
            authority["role"],
            (str,),
            f"migration trust root.authorities.{authority_name}.role",
        )
        for key in ("keyId", "publicKeyPemSha256"):
            require_types(
                authority[key],
                (type(None), str),
                f"migration trust root.authorities.{authority_name}.{key}",
            )
        require_types(
            authority["enabled"],
            (bool,),
            f"migration trust root.authorities.{authority_name}.enabled",
        )
    for key in REPLAY_POLICY_KEYS:
        require_types(
            trust["replayPolicy"][key],
            (int,),
            f"migration trust root.replayPolicy.{key}",
        )
    require_types(trust["blockingReasons"], (list,), "migration trust root.blockingReasons")


def validate_blocked_projection(
    value: Any,
    allowed_literals: dict[tuple[str, ...], Any],
    label: str,
    path: tuple[str, ...] = (),
) -> None:
    if path in allowed_literals:
        if value != allowed_literals[path] or type(value) is not type(allowed_literals[path]):
            fail(f"{label} differs from the immutable blocked contract at {'.'.join(path)}")
        return
    if type(value) is dict:
        for key, child in value.items():
            validate_blocked_projection(child, allowed_literals, label, path + (key,))
        return
    if value is None or value is False or value == 0 or value == []:
        return
    fail(f"{label} carries fabricated qualification material at {'.'.join(path)}")


def require_current_qualified_schemas(
    receipt: dict[str, Any], evidence: dict[str, Any]
) -> None:
    if (
        receipt.get("schemaVersion") != 8
        or receipt.get("contractId")
        != "sora-ios-wallet-migration-qualification-v8"
        or receipt.get("platform") != "ios"
        or receipt.get("status") != "qualified"
        or receipt.get("blockingReasons") != []
    ):
        fail("migration receipt is not exact qualified v8")
    if (
        evidence.get("schemaVersion") != 4
        or evidence.get("contractId") != "sora-ios-wallet-migration-evidence-v4"
        or evidence.get("platform") != "ios"
        or evidence.get("status") != "qualified"
        or evidence.get("blockingReasons") != []
    ):
        fail("migration evidence manifest is not exact qualified v4")


def require_current_collection_raw_schemas(collection: dict[str, Any]) -> None:
    raw_input = collection.get("rawInputSet")
    if (
        collection.get("schemaVersion") != 3
        or collection.get("contractId")
        != "sora-ios-wallet-migration-collection-receipt-v3"
        or type(raw_input) is not dict
        or raw_input.get("contractId")
        != "sora-ios-wallet-migration-raw-input-set-v3"
    ):
        fail("migration collection/raw wire is not exact v3")


def require_current_public_aggregate_schema(
    record: dict[str, Any], contract_id: str
) -> None:
    allowed = {
        "sora-ios-wallet-migration-retained-snapshot-manifest-v4",
        "sora-ios-wallet-migration-keychain-evidence-v4",
        "sora-ios-wallet-migration-device-execution-evidence-v4",
    }
    if (
        contract_id not in allowed
        or record.get("schemaVersion") != 4
        or record.get("contractId") != contract_id
    ):
        fail("migration public aggregate wire is not exact v4")


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def canonical_json(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("utf-8")


def sha256_file(path: Path, maximum: int, label: str) -> str:
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_CLOEXEC", 0)
    try:
        descriptor = os.open(path, flags)
    except OSError as error:
        fail(f"{label} cannot be opened for hashing: {error}")
    digest = hashlib.sha256()
    size = 0
    try:
        before = os.fstat(descriptor)
        if (
            not stat.S_ISREG(before.st_mode)
            or before.st_nlink != 1
            or before.st_size <= 0
            or before.st_size > maximum
        ):
            fail(f"{label} is not a bounded unique regular file")
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                break
            size += len(chunk)
            if size > maximum:
                fail(f"{label} exceeds its byte bound")
            digest.update(chunk)
        after = os.fstat(descriptor)
        if (
            size != before.st_size
            or (
                after.st_dev,
                after.st_ino,
                after.st_size,
                after.st_mtime_ns,
                after.st_nlink,
            )
            != (
                before.st_dev,
                before.st_ino,
                before.st_size,
                before.st_mtime_ns,
                before.st_nlink,
            )
        ):
            fail(f"{label} changed while being hashed")
        return digest.hexdigest()
    finally:
        os.close(descriptor)


def required_protected_raw_root(name: str) -> Path:
    raw = required_env(name)
    path = Path(raw)
    if (
        not path.is_absolute()
        or path == Path("/")
        or str(path) != raw
        or any(part in ("", ".", "..") for part in path.parts[1:])
    ):
        fail(f"protected raw input root must be a canonical absolute path: {name}")
    if ROOT == path or ROOT in path.parents or path in ROOT.parents:
        fail("protected raw migration inputs must remain outside the repository")
    return path


def open_anchored_external_directory(path: Path, label: str) -> int:
    if not hasattr(os, "O_NOFOLLOW") or not hasattr(os, "O_DIRECTORY"):
        fail("this platform cannot enforce protected raw-tree path safety")
    flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY
    if hasattr(os, "O_CLOEXEC"):
        flags |= os.O_CLOEXEC
    descriptor = os.open("/", flags)
    try:
        for component in path.parts[1:]:
            child = os.open(component, flags, dir_fd=descriptor)
            opened = os.fstat(child)
            if not stat.S_ISDIR(opened.st_mode):
                os.close(child)
                fail(f"{label} traverses a non-directory component")
            os.close(descriptor)
            descriptor = child
        root_metadata = os.fstat(descriptor)
        if (
            root_metadata.st_uid != os.getuid()
            or stat.S_IMODE(root_metadata.st_mode) & 0o077
        ):
            fail(f"{label} must be an owner-only protected directory")
        return descriptor
    except Exception:
        os.close(descriptor)
        raise


def inventory_raw_tree(
    root: Path, label: str
) -> tuple[list[dict[str, Any]], str, int, int]:
    root_descriptor = open_anchored_external_directory(root, label)
    entries: list[dict[str, Any]] = []
    seen_inodes: set[tuple[int, int]] = set()
    total_bytes = 0

    def inspect_directory(directory_fd: int, prefix: PurePosixPath) -> None:
        nonlocal total_bytes
        before_directory = os.fstat(directory_fd)
        try:
            names = sorted(os.listdir(directory_fd))
        except OSError as error:
            fail(f"{label} cannot be enumerated: {error}")
        for name in names:
            if SAFE_COMPONENT_RE.fullmatch(name) is None:
                fail(f"{label} contains an unsafe path component")
            try:
                metadata = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
            except OSError as error:
                fail(f"{label} cannot inspect {name}: {error}")
            relative = prefix / name
            if stat.S_ISLNK(metadata.st_mode):
                fail(f"{label} contains a symbolic link")
            if stat.S_ISDIR(metadata.st_mode):
                child_fd = os.open(
                    name,
                    os.O_RDONLY
                    | os.O_DIRECTORY
                    | os.O_NOFOLLOW
                    | getattr(os, "O_CLOEXEC", 0),
                    dir_fd=directory_fd,
                )
                try:
                    opened = os.fstat(child_fd)
                    if (opened.st_dev, opened.st_ino) != (
                        metadata.st_dev,
                        metadata.st_ino,
                    ):
                        fail(f"{label} directory changed during anchored open")
                    inspect_directory(child_fd, relative)
                finally:
                    os.close(child_fd)
                continue
            if (
                not stat.S_ISREG(metadata.st_mode)
                or metadata.st_nlink != 1
                or metadata.st_size > MAX_RAW_FILE_BYTES
            ):
                fail(f"{label} contains a special, hard-linked, or oversized file")
            identity = (metadata.st_dev, metadata.st_ino)
            if identity in seen_inodes:
                fail(f"{label} contains an inode alias")
            seen_inodes.add(identity)
            file_fd = os.open(
                name,
                os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0),
                dir_fd=directory_fd,
            )
            digest = hashlib.sha256()
            copied = 0
            try:
                before = os.fstat(file_fd)
                if (
                    not stat.S_ISREG(before.st_mode)
                    or before.st_nlink != 1
                    or (
                        before.st_dev,
                        before.st_ino,
                        before.st_size,
                        before.st_mtime_ns,
                    )
                    != (
                        metadata.st_dev,
                        metadata.st_ino,
                        metadata.st_size,
                        metadata.st_mtime_ns,
                    )
                ):
                    fail(f"{label} file changed during anchored open")
                while True:
                    chunk = os.read(file_fd, 1024 * 1024)
                    if not chunk:
                        break
                    copied += len(chunk)
                    total_bytes += len(chunk)
                    if total_bytes > MAX_RAW_BYTES:
                        fail(f"{label} exceeds the raw byte bound")
                    digest.update(chunk)
                after = os.fstat(file_fd)
                if (
                    copied != before.st_size
                    or (
                        after.st_dev,
                        after.st_ino,
                        after.st_size,
                        after.st_mtime_ns,
                        after.st_nlink,
                    )
                    != (
                        before.st_dev,
                        before.st_ino,
                        before.st_size,
                        before.st_mtime_ns,
                        before.st_nlink,
                    )
                ):
                    fail(f"{label} file changed while it was hashed")
            finally:
                os.close(file_fd)
            entries.append(
                {
                    "relativePath": relative.as_posix(),
                    "modeClass": (
                        "executable"
                        if stat.S_IMODE(metadata.st_mode) & 0o111
                        else "non-executable"
                    ),
                    "sha256": digest.hexdigest(),
                    "size": copied,
                }
            )
            if len(entries) > MAX_RAW_FILES:
                fail(f"{label} exceeds the raw file bound")
        after_directory = os.fstat(directory_fd)
        try:
            names_after = sorted(os.listdir(directory_fd))
        except OSError as error:
            fail(f"{label} cannot be re-enumerated: {error}")
        if names_after != names or (
            after_directory.st_dev,
            after_directory.st_ino,
            after_directory.st_mtime_ns,
            after_directory.st_ctime_ns,
        ) != (
            before_directory.st_dev,
            before_directory.st_ino,
            before_directory.st_mtime_ns,
            before_directory.st_ctime_ns,
        ):
            fail(f"{label} changed during its anchored inventory")

    try:
        inspect_directory(root_descriptor, PurePosixPath())
    finally:
        os.close(root_descriptor)
    ordered = sorted(entries, key=lambda value: value["relativePath"])
    projection = {
        "schemaVersion": 3,
        "contractId": "sora-ios-wallet-migration-raw-input-set-v3",
        "files": ordered,
    }
    return ordered, sha256_bytes(canonical_json(projection)), len(ordered), total_bytes


FD_PYTHON_BOOTSTRAP = (
    "import os,sys;"
    "fd=int(sys.argv.pop(1));"
    "path=sys.argv.pop(1);"
    "raw=os.fdopen(fd,'rb',closefd=False).read();"
    "exec(compile(raw,path,'exec'),{'__name__':'__main__','__file__':path})"
)


def run_repository_python(
    script: Path,
    arguments: list[str],
    label: str,
    *,
    timeout: int,
    maximum_source_bytes: int = 8 * 1024 * 1024,
) -> subprocess.CompletedProcess[bytes]:
    descriptor, before = open_repository_regular(script, maximum_source_bytes, label)
    before_digest = hashlib.sha256()
    while True:
        chunk = os.read(descriptor, 1024 * 1024)
        if not chunk:
            break
        before_digest.update(chunk)
    os.lseek(descriptor, 0, os.SEEK_SET)
    try:
        result = subprocess.run(
            [
                "/usr/bin/python3",
                "-I",
                "-S",
                "-c",
                FD_PYTHON_BOOTSTRAP,
                str(descriptor),
                str(script),
                *arguments,
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            env=SAFE_COLLECTOR_ENV,
            timeout=timeout,
            pass_fds=(descriptor,),
        )
    except (OSError, subprocess.SubprocessError) as error:
        fail(f"{label} could not be executed: {error}")
    finally:
        os.close(descriptor)
    recheck, after = open_repository_regular(script, maximum_source_bytes, f"{label} recheck")
    after_digest = hashlib.sha256()
    try:
        while True:
            chunk = os.read(recheck, 1024 * 1024)
            if not chunk:
                break
            after_digest.update(chunk)
    finally:
        os.close(recheck)
    if (
        (
            after.st_dev,
            after.st_ino,
            after.st_size,
            after.st_mtime_ns,
            after.st_nlink,
        )
        != (
            before.st_dev,
            before.st_ino,
            before.st_size,
            before.st_mtime_ns,
            before.st_nlink,
        )
        or after_digest.hexdigest() != before_digest.hexdigest()
    ):
        fail(f"{label} changed while it was executing")
    if result.returncode != 0:
        detail = result.stderr.decode("utf-8", errors="replace").strip()[-1024:]
        fail(f"{label} rejected the input{': ' + detail if detail else ''}")
    return result


def run_qualification_contract_tool(arguments: list[str]) -> str:
    result = run_repository_python(
        CONTRACT_TOOL,
        ["--repository-root", str(ROOT), *arguments],
        "migration qualification source-contract tool",
        timeout=120,
    )
    digest = result.stdout.decode("ascii", errors="strict").strip()
    return require_sha256(digest, "migration qualification source-contract tool result")


def read_unique_regular(path: Path, maximum: int, label: str) -> bytes:
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_CLOEXEC", 0)
    try:
        descriptor = os.open(path, flags)
    except OSError as error:
        fail(f"{label} cannot be opened without following aliases: {error}")
    result = bytearray()
    try:
        before = os.fstat(descriptor)
        if (
            not stat.S_ISREG(before.st_mode)
            or before.st_nlink != 1
            or before.st_size <= 0
            or before.st_size > maximum
        ):
            fail(f"{label} is not a bounded unique regular file")
        while True:
            chunk = os.read(descriptor, min(1024 * 1024, maximum - len(result) + 1))
            if not chunk:
                break
            result.extend(chunk)
            if len(result) > maximum:
                fail(f"{label} exceeds its byte bound")
        after = os.fstat(descriptor)
        if (
            len(result) != before.st_size
            or (
                after.st_dev,
                after.st_ino,
                after.st_size,
                after.st_mtime_ns,
                after.st_nlink,
            )
            != (
                before.st_dev,
                before.st_ino,
                before.st_size,
                before.st_mtime_ns,
                before.st_nlink,
            )
        ):
            fail(f"{label} changed while being read")
        return bytes(result)
    finally:
        os.close(descriptor)


def hash_anchored_named_regular(
    directory_fd: int, name: str, maximum: int, label: str
) -> tuple[str, int]:
    if SAFE_COMPONENT_RE.fullmatch(name) is None:
        fail(f"{label} has an unsafe leaf name")
    try:
        admitted = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
        descriptor = os.open(
            name,
            os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0),
            dir_fd=directory_fd,
        )
    except OSError as error:
        fail(f"{label} cannot be opened below its anchored directory: {error}")
    digest = hashlib.sha256()
    size = 0
    try:
        before = os.fstat(descriptor)
        if (
            not stat.S_ISREG(admitted.st_mode)
            or not stat.S_ISREG(before.st_mode)
            or admitted.st_nlink != 1
            or before.st_nlink != 1
            or before.st_size <= 0
            or before.st_size > maximum
            or (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns)
            != (
                admitted.st_dev,
                admitted.st_ino,
                admitted.st_size,
                admitted.st_mtime_ns,
            )
        ):
            fail(f"{label} is not the admitted bounded unique regular file")
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                break
            size += len(chunk)
            if size > maximum:
                fail(f"{label} exceeds its byte bound")
            digest.update(chunk)
        after = os.fstat(descriptor)
        named_after = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
        if (
            size != before.st_size
            or (
                after.st_dev,
                after.st_ino,
                after.st_size,
                after.st_mtime_ns,
                after.st_nlink,
            )
            != (
                before.st_dev,
                before.st_ino,
                before.st_size,
                before.st_mtime_ns,
                before.st_nlink,
            )
            or (
                named_after.st_dev,
                named_after.st_ino,
                named_after.st_size,
                named_after.st_mtime_ns,
                named_after.st_nlink,
            )
            != (
                before.st_dev,
                before.st_ino,
                before.st_size,
                before.st_mtime_ns,
                before.st_nlink,
            )
        ):
            fail(f"{label} changed during anchored hashing")
        return digest.hexdigest(), size
    finally:
        os.close(descriptor)


def recheck_input_digest(
    original: Path,
    expected_sha256: str,
    maximum: int,
    label: str,
    *,
    repository_owned: bool = False,
) -> None:
    descriptor, opened = open_regular(original, maximum, label, repository_owned)
    digest = hashlib.sha256()
    compared = 0
    try:
        while True:
            current_chunk = os.read(descriptor, 1024 * 1024)
            if not current_chunk:
                break
            compared += len(current_chunk)
            if compared > maximum:
                fail(f"{label} exceeded its byte bound during final recheck")
            digest.update(current_chunk)
        after = os.fstat(descriptor)
        if (
            compared != opened.st_size
            or digest.hexdigest() != expected_sha256
            or (
                after.st_dev,
                after.st_ino,
                after.st_size,
                after.st_mtime_ns,
                after.st_nlink,
            )
            != (
                opened.st_dev,
                opened.st_ino,
                opened.st_size,
                opened.st_mtime_ns,
                opened.st_nlink,
            )
        ):
            fail(f"{label} changed after authentication")
    finally:
        os.close(descriptor)


def require_sha256(value: Any, label: str, expected: Optional[str] = None) -> str:
    if type(value) is not str or SHA256_RE.fullmatch(value) is None:
        fail(f"{label} must be lowercase SHA-256")
    if expected is not None and value != expected:
        fail(f"{label} differs from its independently protected identity")
    return value


def require_source_revision(value: Any, label: str, expected: Optional[str] = None) -> str:
    if type(value) is not str or SHA1_RE.fullmatch(value) is None or set(value) == {"0"}:
        fail(f"{label} must be a nonzero lowercase 40-hex source revision")
    if expected is not None and value != expected:
        fail(f"{label} differs from the protected release source revision")
    return value


def require_positive_int(value: Any, label: str) -> int:
    if type(value) is not int or value <= 0:
        fail(f"{label} must be a positive integer")
    return value


def require_uuid(value: Any, label: str, expected: Optional[str] = None) -> str:
    if type(value) is not str:
        fail(f"{label} must be a canonical UUID")
    try:
        canonical = str(uuid.UUID(value))
    except (ValueError, AttributeError):
        fail(f"{label} must be a canonical UUID")
    if value != canonical or value == "00000000-0000-0000-0000-000000000000":
        fail(f"{label} must be a lowercase canonical UUID")
    if expected is not None and value != expected:
        fail(f"{label} differs from the protected qualification run")
    return value


def required_env(name: str) -> str:
    value = os.environ.get(name, "")
    if not value:
        fail(f"required protected environment value is absent: {name}")
    return value


def required_absolute_path_env(name: str) -> Path:
    path = Path(required_env(name))
    if not path.is_absolute():
        fail(f"protected evidence path must be absolute: {name}")
    return path


def open_repository_regular(
    path: Path, maximum: int, label: str
) -> tuple[int, os.stat_result]:
    if ROOT.anchor != "/" or not path.is_absolute():
        fail(f"{label} is not anchored below the canonical repository root")
    try:
        relative = path.relative_to(ROOT)
    except ValueError:
        fail(f"{label} escapes the canonical repository root")
    if not relative.parts or any(part in ("", ".", "..") for part in relative.parts):
        fail(f"{label} has an unsafe repository-relative path")
    if not hasattr(os, "O_NOFOLLOW") or not hasattr(os, "O_DIRECTORY"):
        fail("this platform cannot enforce repository path component safety")

    directory_flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY
    file_flags = os.O_RDONLY | os.O_NOFOLLOW
    if hasattr(os, "O_CLOEXEC"):
        directory_flags |= os.O_CLOEXEC
        file_flags |= os.O_CLOEXEC

    directory_descriptor: Optional[int] = None
    try:
        directory_descriptor = os.open("/", directory_flags)
        directory_components = ROOT.parts[1:] + relative.parts[:-1]
        for component in directory_components:
            next_descriptor = os.open(
                component, directory_flags, dir_fd=directory_descriptor
            )
            os.close(directory_descriptor)
            directory_descriptor = next_descriptor
        descriptor = os.open(
            relative.parts[-1], file_flags, dir_fd=directory_descriptor
        )
    except OSError as error:
        fail(f"{label} could not be opened below a non-symbolic repository path: {error}")
    finally:
        if directory_descriptor is not None:
            os.close(directory_descriptor)

    opened = os.fstat(descriptor)
    if not stat.S_ISREG(opened.st_mode):
        os.close(descriptor)
        fail(f"{label} must be a regular repository file")
    if opened.st_size <= 0 or opened.st_size > maximum:
        os.close(descriptor)
        fail(f"{label} has an invalid byte size")
    return descriptor, opened


def open_regular(
    path: Path, maximum: int, label: str, repository_owned: bool = False
) -> tuple[int, os.stat_result]:
    if repository_owned:
        return open_repository_regular(path, maximum, label)
    try:
        before = path.lstat()
    except FileNotFoundError:
        fail(f"{label} is absent: {path}")
    if stat.S_ISLNK(before.st_mode) or not stat.S_ISREG(before.st_mode):
        fail(f"{label} must be a regular non-symlink file")
    if before.st_size <= 0 or before.st_size > maximum:
        fail(f"{label} has an invalid byte size")
    flags = os.O_RDONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        descriptor = os.open(path, flags)
    except OSError as error:
        fail(f"{label} could not be opened safely: {error}")
    opened = os.fstat(descriptor)
    if not stat.S_ISREG(opened.st_mode) or (opened.st_dev, opened.st_ino) != (
        before.st_dev,
        before.st_ino,
    ):
        os.close(descriptor)
        fail(f"{label} changed during admission")
    return descriptor, opened


def snapshot_input(
    path: Path,
    maximum: int,
    label: str,
    directory: Path,
    name: str,
    repository_owned: bool = False,
) -> Path:
    descriptor, opened = open_regular(path, maximum, label, repository_owned)
    destination = directory / name
    digest = hashlib.sha256()
    copied = 0
    try:
        with os.fdopen(descriptor, "rb", closefd=True) as source, destination.open("xb") as target:
            while True:
                chunk = source.read(1024 * 1024)
                if not chunk:
                    break
                copied += len(chunk)
                if copied > maximum:
                    fail(f"{label} exceeded its byte bound while snapshotting")
                digest.update(chunk)
                target.write(chunk)
    except Exception:
        destination.unlink(missing_ok=True)
        raise
    if copied != opened.st_size:
        fail(f"{label} changed length while snapshotting")
    descriptor_after, after = open_regular(path, maximum, label, repository_owned)
    digest_after = hashlib.sha256()
    rechecked = 0
    with os.fdopen(descriptor_after, "rb", closefd=True) as source:
        while True:
            chunk = source.read(1024 * 1024)
            if not chunk:
                break
            rechecked += len(chunk)
            if rechecked > maximum:
                fail(f"{label} exceeded its byte bound while rechecking")
            digest_after.update(chunk)
    if (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns) != (
        opened.st_dev,
        opened.st_ino,
        opened.st_size,
        opened.st_mtime_ns,
    ) or digest_after.hexdigest() != digest.hexdigest():
        fail(f"{label} changed during snapshotting")
    return destination


def snapshot_json(
    path: Path,
    label: str,
    directory: Path,
    name: str,
    repository_owned: bool = False,
) -> tuple[Path, bytes, dict[str, Any]]:
    snapshot = snapshot_input(
        path, MAX_JSON_BYTES, label, directory, name, repository_owned
    )
    raw = read_unique_regular(snapshot, MAX_JSON_BYTES, f"{label} snapshot")
    return snapshot, raw, load_json_bytes(raw, label)


def validate_privacy(value: Any, label: str, include_signed_payload_flag: bool) -> None:
    expected = {
        "aggregateOnly",
        "accountIdentifiersIncluded",
        "addressesIncluded",
        "deviceIdentifiersIncluded",
        "phrasesOrSeedsIncluded",
        "privateKeysIncluded",
        "publicKeysIncluded",
        "rawKeychainValuesIncluded",
        "rawSignedPayloadsIncluded",
        "perWalletRecordsIncluded",
    }
    if include_signed_payload_flag:
        expected |= {"secretsIncluded", "signedPayloadsIncluded"}
    exact_keys(value, expected, label)
    if value["aggregateOnly"] is not True:
        fail(f"{label} must be aggregate-only")
    for key in expected - {"aggregateOnly"}:
        if value[key] is not False:
            fail(f"{label}.{key} must be false")


def recursive_privacy_scan(value: Any, label: str) -> None:
    if type(value) is dict:
        for key, child in value.items():
            normalized = re.sub(r"[^a-z0-9]", "", key.lower())
            forbidden = any(part in normalized for part in FORBIDDEN_KEY_PARTS)
            allowed_aggregate = normalized in SAFE_AGGREGATE_KEYS and type(child) in (bool, int)
            if forbidden and not (
                (normalized.endswith("included") and child is False) or allowed_aggregate
            ):
                fail(f"{label} contains prohibited field: {key}")
            recursive_privacy_scan(child, f"{label}.{key}")
    elif type(value) is list:
        for index, child in enumerate(value):
            recursive_privacy_scan(child, f"{label}[{index}]")


def validate_identity(value: Any, label: str, expected_app: str) -> None:
    exact_keys(value, IDENTITY_KEYS, label)
    require_sha256(
        value["productionIpaSha256"],
        f"{label}.productionIpaSha256",
        expected_app,
    )
    for key in IDENTITY_SHA_KEYS - {"productionIpaSha256"}:
        require_sha256(value[key], f"{label}.{key}")
    if (
        value["productionCanonicalProjectionSha256"]
        != value["installedCanonicalProjectionSha256"]
    ):
        fail(f"{label} has unequal production and installed projections")
    for key in IDENTITY_COUNT_KEYS:
        require_positive_int(value[key], f"{label}.{key}")
    for key in ("deviceClasses", "operatingSystemBuilds"):
        items = value[key]
        if type(items) is not list or not items or len(items) > 64:
            fail(f"{label}.{key} must be a nonempty bounded array")
        if any(type(item) is not str or not item or len(item.encode("utf-8")) > 128 for item in items):
            fail(f"{label}.{key} contains an invalid value")
        if len(set(items)) != len(items):
            fail(f"{label}.{key} contains duplicate values")
        for item in items:
            lowered = item.lower()
            allowed_format = (
                re.fullmatch(
                    r"(?:iPhone|iPad|iPod|AppleTV|Mac|Simulator)[A-Za-z0-9 ,._()\/-]{0,63}",
                    item,
                )
                if key == "deviceClasses"
                else re.fullmatch(
                    r"(?:iOS|iPadOS|macOS|tvOS|Simulator) [0-9]+(?:\.[0-9]+){1,2} \([0-9A-Za-z.-]{1,32}\)",
                    item,
                )
            )
            if (
                allowed_format is None
                or re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", lowered)
                or re.fullmatch(
                    r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
                    lowered,
                )
                or any(
                    marker in lowered
                    for marker in ("device-id", "identifier", "serial", "udid")
                )
            ):
                fail(f"{label}.{key} contains a device-specific identifier")


def validate_key_id(value: Any, label: str, required_prefix: str) -> str:
    suffix = value[len(required_prefix) :] if type(value) is str and value.startswith(required_prefix) else ""
    if (
        type(value) is not str
        or KEY_ID_RE.fullmatch(value) is None
        or not value.startswith(required_prefix)
        or re.fullmatch(r"[a-z][a-z0-9._-]{2,23}", suffix) is None
        or SHA1_RE.fullmatch(suffix) is not None
        or SHA256_RE.fullmatch(suffix) is not None
        or (
            re.fullmatch(
                r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
                suffix,
            )
            is not None
        )
    ):
        fail(f"{label} is not a canonical key ID")
    return value


def validate_p256_key(raw: bytes, expected_sha: str, label: str) -> bytes:
    require_sha256(sha256_bytes(raw), f"{label} SHA-256", expected_sha)
    if not OPENSSL.is_file():
        fail("/usr/bin/openssl is required for migration evidence verification")
    checked = subprocess.run(
        [str(OPENSSL), "ec", "-pubin", "-in", "/dev/stdin", "-noout"],
        input=raw,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
        env=SAFE_OPENSSL_ENV,
    )
    if checked.returncode != 0:
        fail(f"{label} is not a valid EC public key")
    described = subprocess.run(
        [str(OPENSSL), "ec", "-pubin", "-in", "/dev/stdin", "-text", "-noout"],
        input=raw,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
        env=SAFE_OPENSSL_ENV,
    )
    if described.returncode != 0 or not (
        b"ASN1 OID: prime256v1" in described.stdout
        or b"NIST CURVE: P-256" in described.stdout
    ):
        fail(f"{label} must use ECDSA P-256")
    canonical = subprocess.run(
        [
            str(OPENSSL),
            "ec",
            "-pubin",
            "-in",
            "/dev/stdin",
            "-pubout",
            "-conv_form",
            "uncompressed",
            "-param_enc",
            "named_curve",
            "-outform",
            "DER",
        ],
        input=raw,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
        env=SAFE_OPENSSL_ENV,
    )
    if canonical.returncode != 0 or not canonical.stdout:
        fail(f"{label} could not be canonicalized as SPKI DER")
    return canonical.stdout


def verify_signature(
    payload_raw: bytes,
    signature_raw: bytes,
    key_raw: bytes,
    expected_key_sha: str,
    label: str,
) -> None:
    require_sha256(
        sha256_bytes(key_raw), f"{label} verification key SHA-256", expected_key_sha
    )
    with tempfile.TemporaryFile() as key_file, tempfile.TemporaryFile() as signature_file:
        key_file.write(key_raw)
        key_file.flush()
        key_file.seek(0)
        signature_file.write(signature_raw)
        signature_file.flush()
        signature_file.seek(0)
        result = subprocess.run(
            [
                str(OPENSSL),
                "dgst",
                "-sha256",
                "-verify",
                f"/dev/fd/{key_file.fileno()}",
                "-signature",
                f"/dev/fd/{signature_file.fileno()}",
            ],
            input=payload_raw,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
            env=SAFE_OPENSSL_ENV,
            pass_fds=(key_file.fileno(), signature_file.fileno()),
        )
    if result.returncode != 0:
        fail(f"{label} detached P-256 signature is invalid")


def validate_test_result_zip(
    path: Path,
    receipt: dict[str, Any],
    run_id: str,
    run_challenge: str,
    raw_input_set_sha: str,
    source_revision: str,
    produced_at: int,
    identity: dict[str, Any],
) -> None:
    summary_name = "ios-migration-test-summary.json"
    try:
        with zipfile.ZipFile(path, "r") as archive:
            entries = archive.infolist()
            if not entries or len(entries) > MAX_ZIP_ENTRIES:
                fail("migration test-result ZIP has an invalid entry count")
            names: set[str] = set()
            total = 0
            for entry in entries:
                name = entry.filename
                pure = PurePosixPath(name)
                if (
                    not name
                    or name.startswith("/")
                    or "\\" in name
                    or any(part in ("", ".", "..") for part in pure.parts)
                    or name in names
                ):
                    fail("migration test-result ZIP contains an unsafe or duplicate path")
                names.add(name)
                mode = (entry.external_attr >> 16) & 0xFFFF
                if mode and stat.S_ISLNK(mode):
                    fail("migration test-result ZIP contains a symbolic link")
                total += entry.file_size
                if total > MAX_ZIP_UNCOMPRESSED_BYTES:
                    fail("migration test-result ZIP exceeds the uncompressed byte bound")
            if archive.testzip() is not None:
                fail("migration test-result ZIP integrity check failed")
            if names != {summary_name}:
                fail("migration test-result ZIP must contain only its aggregate summary")
            summary_info = archive.getinfo(summary_name)
            if summary_info.file_size <= 0 or summary_info.file_size > MAX_JSON_BYTES:
                fail("migration test-result summary has an invalid byte size")
            summary = load_json_bytes(
                archive.read(summary_info), "migration test-result summary"
            )
    except (
        zipfile.BadZipFile,
        zipfile.LargeZipFile,
        OSError,
        RuntimeError,
        NotImplementedError,
    ) as error:
        fail(f"migration test-result bundle is not a valid ZIP: {error}")

    exact_keys(
        summary,
        {
            "schemaVersion",
            "contractId",
            "platform",
            "status",
            "releaseAuthorized",
            "runId",
            "runChallengeSha256",
            "sourceRevision",
            "producedAtEpochSeconds",
            "rawInputSetSha256",
            "identity",
            "privacy",
            "blockingReasons",
            "executedWalletModernizationTestCount",
            "executedRecoveryCapabilityGateTestCount",
            "executedRecoveryExporterTestCount",
            "executedRetainedDeviceEvidenceTestCount",
            "testFailureCount",
            "testUnexpectedFailureCount",
            "testSkippedCount",
            "testExpectedFailureCount",
            "xcresultTreeSha256",
            "executedTestIdentifierSetSha256",
        },
        "migration test-result summary",
    )
    for key in (
        "schemaVersion",
        "producedAtEpochSeconds",
        "executedWalletModernizationTestCount",
        "executedRecoveryCapabilityGateTestCount",
        "executedRecoveryExporterTestCount",
        "executedRetainedDeviceEvidenceTestCount",
        "testFailureCount",
        "testUnexpectedFailureCount",
        "testSkippedCount",
        "testExpectedFailureCount",
    ):
        require_types(summary[key], (int,), f"migration test-result summary.{key}")
    require_types(
        summary["releaseAuthorized"],
        (bool,),
        "migration test-result summary.releaseAuthorized",
    )
    for key in (
        "contractId",
        "platform",
        "status",
        "runId",
        "runChallengeSha256",
        "sourceRevision",
        "rawInputSetSha256",
        "xcresultTreeSha256",
        "executedTestIdentifierSetSha256",
    ):
        require_types(summary[key], (str,), f"migration test-result summary.{key}")
    if (
        summary["schemaVersion"] != 4
        or summary["contractId"] != "sora-ios-wallet-migration-test-summary-v4"
        or summary["platform"] != "ios"
        or summary["status"] != "observed"
        or summary["releaseAuthorized"] is not False
        or summary["runId"] != run_id
        or summary["runChallengeSha256"] != run_challenge
        or summary["rawInputSetSha256"] != raw_input_set_sha
        or summary["sourceRevision"] != source_revision
        or summary["producedAtEpochSeconds"] != produced_at
        or summary["identity"] != identity
        or summary["blockingReasons"] != [NONAUTHORIZING_BLOCKER]
    ):
        fail("migration test-result summary identity is invalid")
    validate_privacy(
        summary["privacy"],
        "migration test-result summary privacy",
        include_signed_payload_flag=False,
    )
    for key in (
        "executedWalletModernizationTestCount",
        "executedRecoveryCapabilityGateTestCount",
        "executedRecoveryExporterTestCount",
        "executedRetainedDeviceEvidenceTestCount",
        "testFailureCount",
        "testUnexpectedFailureCount",
        "testSkippedCount",
        "testExpectedFailureCount",
    ):
        if summary[key] != receipt[key]:
            fail(f"migration test-result summary differs from receipt: {key}")
    require_sha256(
        summary["xcresultTreeSha256"], "migration test-result xcresult tree"
    )
    require_sha256(
        summary["executedTestIdentifierSetSha256"],
        "migration test-result identifier set",
    )
    recursive_privacy_scan(summary, "migration test-result summary")


def validate_aggregate_artifact(
    record: dict[str, Any],
    label: str,
    contract_id: str,
    run_id: str,
    run_challenge: str,
    raw_input_set_sha: str,
    source_revision: str,
    produced_at: int,
    identity: dict[str, Any],
) -> None:
    require_current_public_aggregate_schema(record, contract_id)
    exact_keys(
        record,
        {
            "schemaVersion",
            "contractId",
            "platform",
            "status",
            "releaseAuthorized",
            "runId",
            "runChallengeSha256",
            "sourceRevision",
            "producedAtEpochSeconds",
            "rawInputSetSha256",
            "identity",
            "privacy",
            "aggregate",
            "blockingReasons",
        },
        label,
    )
    require_types(record["schemaVersion"], (int,), f"{label}.schemaVersion")
    require_types(
        record["producedAtEpochSeconds"],
        (int,),
        f"{label}.producedAtEpochSeconds",
    )
    require_types(record["releaseAuthorized"], (bool,), f"{label}.releaseAuthorized")
    for key in (
        "contractId",
        "platform",
        "status",
        "runId",
        "runChallengeSha256",
        "sourceRevision",
        "rawInputSetSha256",
    ):
        require_types(record[key], (str,), f"{label}.{key}")
    if record["schemaVersion"] != 4 or record["contractId"] != contract_id:
        fail(f"{label} uses an incompatible schema")
    if (
        record["platform"] != "ios"
        or record["status"] != "observed"
        or record["releaseAuthorized"] is not False
        or record["blockingReasons"] != [NONAUTHORIZING_BLOCKER]
    ):
        fail(f"{label} is not exact non-authorizing observed iOS evidence")
    if (
        record["runId"] != run_id
        or record["runChallengeSha256"] != run_challenge
        or record["rawInputSetSha256"] != raw_input_set_sha
        or record["sourceRevision"] != source_revision
        or record["producedAtEpochSeconds"] != produced_at
        or record["identity"] != identity
    ):
        fail(f"{label} differs from the signed evidence identity")
    validate_privacy(record["privacy"], f"{label}.privacy", include_signed_payload_flag=False)
    if type(record["aggregate"]) is not dict or not record["aggregate"]:
        fail(f"{label}.aggregate must contain reviewed aggregate evidence")
    recursive_privacy_scan(record, label)


def validate_collection_receipt(
    collection: dict[str, Any],
    *,
    run_id: str,
    run_challenge: str,
    raw_input_set_sha: str,
    source_revision: str,
    qualification_contract_sha: str,
    identity: dict[str, Any],
    expected_app: str,
    expected_artifacts: dict[str, tuple[str, str, int]],
) -> int:
    require_current_collection_raw_schemas(collection)
    exact_keys(collection, COLLECTION_ROOT_KEYS, "migration collection receipt")
    exact_keys(
        collection["rawInputSet"],
        COLLECTION_RAW_INPUT_KEYS,
        "migration collection receipt.rawInputSet",
    )
    exact_keys(
        collection["identity"],
        IDENTITY_KEYS,
        "migration collection receipt.identity",
    )
    exact_keys(
        collection["testedApplication"],
        COLLECTION_TESTED_APPLICATION_KEYS,
        "migration collection receipt.testedApplication",
    )
    exact_keys(
        collection["installedClone"],
        COLLECTION_INSTALLED_CLONE_KEYS,
        "migration collection receipt.installedClone",
    )
    exact_keys(
        collection["toolchain"],
        COLLECTION_TOOLCHAIN_KEYS,
        "migration collection receipt.toolchain",
    )
    exact_keys(
        collection["artifacts"],
        set(expected_artifacts),
        "migration collection receipt.artifacts",
    )
    exact_keys(
        collection["checks"],
        COLLECTION_CHECK_KEYS,
        "migration collection receipt.checks",
    )
    if (
        type(collection["schemaVersion"]) is not int
        or collection["schemaVersion"] != 3
        or collection["contractId"]
        != "sora-ios-wallet-migration-collection-receipt-v3"
        or collection["platform"] != "ios"
        or collection["status"] != "observed"
        or collection["releaseAuthorized"] is not False
        or collection["runId"] != run_id
        or collection["runChallengeSha256"] != run_challenge
        or collection["sourceRevision"] != source_revision
        or collection["qualificationContractSha256"]
        != qualification_contract_sha
        or collection["identity"] != identity
        or collection["blockingReasons"] != [NONAUTHORIZING_BLOCKER]
    ):
        fail("migration collection receipt identity or authority boundary is invalid")
    validate_identity(
        collection["identity"], "migration collection receipt.identity", expected_app
    )
    validate_privacy(
        collection["privacy"],
        "migration collection receipt.privacy",
        include_signed_payload_flag=False,
    )
    raw_input = collection["rawInputSet"]
    if (
        raw_input["contractId"] != "sora-ios-wallet-migration-raw-input-set-v3"
        or require_sha256(
            raw_input["sha256"],
            "migration collection raw input set",
            raw_input_set_sha,
        )
        != raw_input_set_sha
        or require_positive_int(
            raw_input["fileCount"], "migration collection raw file count"
        )
        <= 0
        or require_positive_int(
            raw_input["byteCount"], "migration collection raw byte count"
        )
        <= 0
    ):
        fail("migration collection raw input-set identity is invalid")
    tested = collection["testedApplication"]
    for key in (
        "productionCodeSignatureVerified",
        "productionApplicationIdentifierVerified",
        "productionTeamIdentifierVerified",
        "productionKeychainAccessGroupVerified",
    ):
        if tested[key] is not True:
            fail(f"migration collection testedApplication.{key} is not true")
    if (
        require_sha256(
            tested["sha256"], "migration collection tested IPA", expected_app
        )
        != expected_app
        or require_positive_int(
            tested["byteCount"], "migration collection tested IPA byte count"
        )
        <= 0
        or require_sha256(
            tested["executableSha256"],
            "migration collection tested executable",
        )
        == "0" * 64
        or require_positive_int(
            tested["executableByteCount"],
            "migration collection tested executable byte count",
        )
        <= 0
        or tested["bundleIdentifier"] != "co.jp.soramitsu.sora"
        or type(tested["shortVersion"]) is not str
        or not tested["shortVersion"]
        or type(tested["buildVersion"]) is not str
        or not tested["buildVersion"]
    ):
        fail("migration collection tested application identity is invalid")
    installed = collection["installedClone"]
    for key in (
        "codeSignatureDeepStrictVerified",
        "installedAppLaunchVerified",
        "installedRawTreeRecomputed",
        "installedExecutableRecomputed",
        "canonicalProjectionEqualToProduction",
    ):
        if installed[key] is not True:
            fail(f"migration collection installedClone.{key} is not true")
    if (
        require_sha256(
            installed["receiptSha256"],
            "migration collection installable-clone receipt",
        )
        == "0" * 64
        or require_sha256(
            installed["rawTreeSha256"],
            "migration collection installed-clone raw tree",
            identity["installedAppRawTreeSha256"],
        )
        != identity["installedAppRawTreeSha256"]
        or require_positive_int(
            installed["rawTreeRecordByteCount"],
            "migration collection installed-clone raw-tree record byte count",
        )
        != identity["installedAppRawTreeRecordByteCount"]
        or require_sha256(
            installed["executableSha256"],
            "migration collection installed-clone executable",
            identity["installedExecutableSha256"],
        )
        != identity["installedExecutableSha256"]
        or require_positive_int(
            installed["executableByteCount"],
            "migration collection installed-clone executable byte count",
        )
        != identity["installedExecutableByteCount"]
        or require_sha256(
            installed["productionCanonicalProjectionSha256"],
            "migration collection production canonical projection",
            identity["productionCanonicalProjectionSha256"],
        )
        != identity["productionCanonicalProjectionSha256"]
        or require_sha256(
            installed["installedCanonicalProjectionSha256"],
            "migration collection installed canonical projection",
            identity["installedCanonicalProjectionSha256"],
        )
        != identity["installedCanonicalProjectionSha256"]
        or require_sha256(
            installed["canonicalProjectionReceiptSha256"],
            "migration collection canonical projection receipt",
            identity["canonicalProjectionReceiptSha256"],
        )
        != identity["canonicalProjectionReceiptSha256"]
        or require_sha256(
            installed["canonicalProjectorSourceSha256"],
            "migration collection canonical projector source",
            identity["canonicalProjectorSourceSha256"],
        )
        != identity["canonicalProjectorSourceSha256"]
    ):
        fail("migration collection installed-clone identity is invalid")
    toolchain = collection["toolchain"]
    if (
        type(toolchain["xcodeBuildVersion"]) is not str
        or not toolchain["xcodeBuildVersion"].startswith("Xcode ")
        or len(toolchain["xcodeBuildVersion"]) > 128
        or toolchain["xcresultFormatVersion"] != "0.1.0"
    ):
        fail("migration collection toolchain identity is invalid")
    for key in COLLECTION_CHECK_KEYS:
        if collection["checks"][key] is not True:
            fail(f"migration collection check is not exact true: {key}")
    for key, (relative_path, expected_sha, expected_size) in expected_artifacts.items():
        entry = collection["artifacts"][key]
        exact_keys(
            entry,
            {"relativePath", "sha256", "byteCount"},
            f"migration collection artifact {key}",
        )
        if (
            entry["relativePath"] != relative_path
            or require_sha256(
                entry["sha256"], f"migration collection artifact {key} hash"
            )
            != expected_sha
            or type(entry["byteCount"]) is not int
            or entry["byteCount"] != expected_size
        ):
            fail(f"migration collection artifact {key} differs from opened evidence")
    recursive_privacy_scan(collection, "migration collection receipt")
    return require_positive_int(
        collection["collectedAtEpochSeconds"], "migration collection time"
    )


def validate_templates() -> None:
    def read_template(name: str, label: str) -> dict[str, Any]:
        descriptor, _ = open_regular(
            FIXTURES / name, MAX_JSON_BYTES, label, repository_owned=True
        )
        with os.fdopen(descriptor, "rb", closefd=True) as source:
            return load_json_bytes(source.read(MAX_JSON_BYTES + 1), label)

    receipt = read_template(
        "ios-migration-qualification.blocked.json", "blocked receipt template"
    )
    evidence = read_template(
        "ios-migration-qualification-evidence.blocked.json",
        "blocked evidence template",
    )
    trust = read_template(
        "ios-migration-qualification-trust.blocked.json", "blocked trust template"
    )
    validate_wire_shapes(receipt, evidence, trust)
    validate_blocked_projection(
        receipt,
        {
            ("schemaVersion",): 8,
            ("contractId",): "sora-ios-wallet-migration-qualification-v8",
            ("platform",): "ios",
            ("status",): "blocked-template",
            ("privacy", "aggregateOnly"): True,
            ("sourceModelVersions",): ["UserDataModel", "UserDataModel 2"],
            ("targetModelVersion",): "UserDataModel 2",
            (
                "blockingReasons",
            ): [
                "Template only: no wallet-migration qualification receipt may be published before the fixed-path evidence bundle is produced on retained release snapshots and independently reviewed."
            ],
        },
        "blocked migration receipt template",
    )
    validate_blocked_projection(
        evidence,
        {
            ("schemaVersion",): 4,
            ("contractId",): "sora-ios-wallet-migration-evidence-v4",
            ("platform",): "ios",
            ("status",): "blocked-template",
            ("privacy", "aggregateOnly"): True,
            (
                "artifacts",
                "collectionReceipt",
                "relativePath",
            ): "Fixtures/Modernization/ios-migration-collection-receipt.json",
            (
                "artifacts",
                "retainedReleaseSnapshotManifest",
                "relativePath",
            ): "Fixtures/Modernization/ios-migration-retained-snapshot-manifest.json",
            (
                "artifacts",
                "testResultBundle",
                "relativePath",
            ): "Fixtures/Modernization/ios-migration-tests.xcresult.zip",
            (
                "artifacts",
                "keychainEvidence",
                "relativePath",
            ): "Fixtures/Modernization/ios-migration-keychain-evidence.json",
            (
                "artifacts",
                "deviceExecutionEvidence",
                "relativePath",
            ): "Fixtures/Modernization/ios-migration-device-execution-evidence.json",
            (
                "blockingReasons",
            ): [
                "Template only: publish no evidence manifest until the complete retained-device run, observed collection receipt, and all four fixed-path aggregate artifacts exist and independently reproduce."
            ],
        },
        "blocked migration evidence template",
    )
    validate_blocked_projection(
        trust,
        {
            ("schemaVersion",): 1,
            (
                "contractId",
            ): "sora-ios-wallet-migration-qualification-trust-v1",
            ("platform",): "ios",
            ("status",): "blocked",
            ("signatureAlgorithm",): "ecdsa-p256-sha256",
            (
                "authorities",
                "deviceEvidenceProducer",
                "role",
            ): "device-evidence-producer",
            (
                "authorities",
                "independentReviewer",
                "role",
            ): "independent-reviewer",
            ("replayPolicy", "maximumQualificationAgeSeconds"): 604800,
            ("replayPolicy", "maximumRunDurationSeconds"): 172800,
            ("replayPolicy", "maximumReviewDelaySeconds"): 86400,
            (
                "blockingReasons",
            ): [
                "No independently reviewed device-evidence-producer or reviewer public-key pins have been supplied by the retained-device qualification authority."
            ],
        },
        "blocked migration trust template",
    )


def open_non_symbolic_directory(path: Path, label: str) -> int:
    if path.anchor != "/" or not path.is_absolute():
        fail(f"{label} must be a canonical absolute directory")
    if any(component in ("", ".", "..") for component in path.parts[1:]):
        fail(f"{label} contains an unsafe path component")
    if not hasattr(os, "O_NOFOLLOW") or not hasattr(os, "O_DIRECTORY"):
        fail("this platform cannot enforce completed-IPA path safety")
    flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY
    if hasattr(os, "O_CLOEXEC"):
        flags |= os.O_CLOEXEC
    descriptor: Optional[int] = None
    try:
        descriptor = os.open("/", flags)
        for component in path.parts[1:]:
            child = os.open(component, flags, dir_fd=descriptor)
            opened = os.fstat(child)
            if not stat.S_ISDIR(opened.st_mode):
                os.close(child)
                fail(f"{label} traverses a non-directory component")
            os.close(descriptor)
            descriptor = child
        return descriptor
    except OSError as error:
        if descriptor is not None:
            os.close(descriptor)
        fail(f"{label} cannot be opened without following aliases: {error}")
    except Exception:
        if descriptor is not None:
            os.close(descriptor)
        raise


def completed_ipa_identity(metadata: os.stat_result) -> tuple[int, ...]:
    return (
        metadata.st_dev,
        metadata.st_ino,
        metadata.st_mode,
        metadata.st_size,
        metadata.st_mtime_ns,
        metadata.st_ctime_ns,
        metadata.st_nlink,
    )


def hash_completed_ipa(path: Path, expected_sha256: str) -> tuple[str, int]:
    label = "completed post-archive IPA"
    if (
        path.anchor != "/"
        or not path.is_absolute()
        or path == Path("/")
        or path.parent == Path("/")
        or any(component in ("", ".", "..") for component in path.parts[1:])
        or SAFE_COMPONENT_RE.fullmatch(path.name) is None
        or path.suffix != ".ipa"
    ):
        fail(f"{label} path must be canonical, absolute, non-root, and end in .ipa")
    require_sha256(expected_sha256, f"{label} expected SHA-256")

    parent = open_non_symbolic_directory(path.parent, f"{label} parent")
    descriptor: Optional[int] = None
    try:
        parent_before = os.fstat(parent)
        admitted = os.stat(path.name, dir_fd=parent, follow_symlinks=False)
        file_flags = os.O_RDONLY | os.O_NOFOLLOW
        if hasattr(os, "O_CLOEXEC"):
            file_flags |= os.O_CLOEXEC
        descriptor = os.open(path.name, file_flags, dir_fd=parent)
        before = os.fstat(descriptor)
        if (
            not stat.S_ISREG(admitted.st_mode)
            or not stat.S_ISREG(before.st_mode)
            or admitted.st_nlink != 1
            or before.st_nlink != 1
            or before.st_size <= 0
            or before.st_size > MAX_IPA_BYTES
            or completed_ipa_identity(admitted) != completed_ipa_identity(before)
        ):
            fail(f"{label} is not one bounded unique regular file")

        def hash_pass() -> tuple[str, int]:
            os.lseek(descriptor, 0, os.SEEK_SET)
            digest = hashlib.sha256()
            size = 0
            while True:
                chunk = os.read(descriptor, 1024 * 1024)
                if not chunk:
                    break
                size += len(chunk)
                if size > MAX_IPA_BYTES:
                    fail(f"{label} exceeds its byte bound")
                digest.update(chunk)
            return digest.hexdigest(), size

        first_sha, first_size = hash_pass()
        middle = os.fstat(descriptor)
        second_sha, second_size = hash_pass()
        after = os.fstat(descriptor)
        named_after = os.stat(path.name, dir_fd=parent, follow_symlinks=False)
        if (
            first_sha != expected_sha256
            or second_sha != expected_sha256
            or first_size != before.st_size
            or second_size != before.st_size
            or completed_ipa_identity(middle) != completed_ipa_identity(before)
            or completed_ipa_identity(after) != completed_ipa_identity(before)
            or completed_ipa_identity(named_after) != completed_ipa_identity(before)
        ):
            fail(f"{label} bytes or identity differ from authenticated migration evidence")

        final_parent = open_non_symbolic_directory(path.parent, f"{label} parent recheck")
        try:
            parent_after = os.fstat(final_parent)
            rebound = os.stat(path.name, dir_fd=final_parent, follow_symlinks=False)
        finally:
            os.close(final_parent)
        if (
            (parent_after.st_dev, parent_after.st_ino)
            != (parent_before.st_dev, parent_before.st_ino)
            or completed_ipa_identity(rebound) != completed_ipa_identity(before)
        ):
            fail(f"{label} path was rebound during admission")
        return first_sha, first_size
    except OSError as error:
        fail(f"{label} cannot be admitted safely: {error}")
    finally:
        if descriptor is not None:
            os.close(descriptor)
        os.close(parent)


def verify_qualified() -> str:
    expected_source = require_source_revision(
        required_env("IOS_MIGRATION_QUALIFICATION_SOURCE_REVISION"),
        "protected source revision",
    )
    expected_run = require_uuid(
        required_env("IOS_MIGRATION_QUALIFICATION_RUN_ID"), "protected run ID"
    )
    try:
        expected_sequence = int(
            required_env("IOS_MIGRATION_QUALIFICATION_SEQUENCE_NUMBER"), 10
        )
    except ValueError:
        fail("protected qualification sequence is not an integer")
    if expected_sequence <= 0:
        fail("protected qualification sequence must be positive")
    expected_app = require_sha256(
        required_env("IOS_MIGRATION_QUALIFICATION_APP_BUILD_IDENTITY_SHA256"),
        "protected app build identity",
    )
    expected_trust_sha = require_sha256(
        required_env("IOS_MIGRATION_QUALIFICATION_TRUST_SHA256"),
        "protected trust root",
    )
    expected_producer_key_sha = require_sha256(
        required_env(
            "IOS_MIGRATION_QUALIFICATION_DEVICE_PRODUCER_PUBLIC_KEY_SHA256"
        ),
        "protected producer key",
    )
    expected_reviewer_key_sha = require_sha256(
        required_env("IOS_MIGRATION_QUALIFICATION_REVIEWER_PUBLIC_KEY_SHA256"),
        "protected reviewer key",
    )
    expected_raw_root = required_protected_raw_root(
        "IOS_MIGRATION_QUALIFICATION_RAW_INPUT_ROOT"
    )
    expected_raw_input_sha = require_sha256(
        required_env("IOS_MIGRATION_QUALIFICATION_RAW_INPUT_SET_SHA256"),
        "protected raw input-set identity",
    )
    expected_run_challenge = require_sha256(
        required_env("IOS_MIGRATION_QUALIFICATION_RUN_CHALLENGE_SHA256"),
        "protected run challenge",
    )
    expected_collection_sha = require_sha256(
        required_env("IOS_MIGRATION_QUALIFICATION_COLLECTION_RECEIPT_SHA256"),
        "protected collection receipt",
    )
    for value, label in (
        (expected_app, "app build identity"),
        (expected_raw_input_sha, "raw input-set identity"),
        (expected_run_challenge, "run challenge"),
        (expected_collection_sha, "collection receipt"),
    ):
        if value == "0" * 64:
            fail(f"protected {label} must be nonzero")

    with tempfile.TemporaryDirectory(
        prefix="sora-ios-migration-qualification."
    ) as temporary:
        directory = Path(temporary)
        os.chmod(directory, 0o700)
        receipt_original = FIXTURES / "ios-migration-qualification.json"
        evidence_original = FIXTURES / "ios-migration-qualification-evidence.json"
        trust_original = FIXTURES / "ios-migration-qualification-trust.json"
        receipt_path, receipt_raw, receipt = snapshot_json(
            receipt_original,
            "migration receipt",
            directory,
            "receipt.json",
            repository_owned=True,
        )
        evidence_path, evidence_raw, evidence = snapshot_json(
            evidence_original,
            "migration evidence manifest",
            directory,
            "evidence.json",
            repository_owned=True,
        )
        trust_path, trust_raw, trust = snapshot_json(
            trust_original,
            "migration trust root",
            directory,
            "trust.json",
            repository_owned=True,
        )
        validate_wire_shapes(receipt, evidence, trust)

        receipt_signature_original = required_absolute_path_env(
            "IOS_MIGRATION_QUALIFICATION_RECEIPT_SIGNATURE_PATH"
        )
        producer_signature_original = required_absolute_path_env(
            "IOS_MIGRATION_QUALIFICATION_EVIDENCE_PRODUCER_SIGNATURE_PATH"
        )
        reviewer_signature_original = required_absolute_path_env(
            "IOS_MIGRATION_QUALIFICATION_EVIDENCE_REVIEWER_SIGNATURE_PATH"
        )
        producer_key_original = required_absolute_path_env(
            "IOS_MIGRATION_QUALIFICATION_DEVICE_PRODUCER_PUBLIC_KEY_PATH"
        )
        reviewer_key_original = required_absolute_path_env(
            "IOS_MIGRATION_QUALIFICATION_REVIEWER_PUBLIC_KEY_PATH"
        )
        receipt_signature = snapshot_input(
            receipt_signature_original,
            MAX_SIGNATURE_BYTES,
            "migration receipt signature",
            directory,
            "receipt.sig",
        )
        producer_signature = snapshot_input(
            producer_signature_original,
            MAX_SIGNATURE_BYTES,
            "migration evidence producer signature",
            directory,
            "evidence-producer.sig",
        )
        reviewer_signature = snapshot_input(
            reviewer_signature_original,
            MAX_SIGNATURE_BYTES,
            "migration evidence reviewer signature",
            directory,
            "evidence-reviewer.sig",
        )
        producer_key = snapshot_input(
            producer_key_original,
            MAX_KEY_BYTES,
            "migration evidence producer key",
            directory,
            "producer.pem",
        )
        reviewer_key = snapshot_input(
            reviewer_key_original,
            MAX_KEY_BYTES,
            "migration independent reviewer key",
            directory,
            "reviewer.pem",
        )
        receipt_signature_raw = read_unique_regular(
            receipt_signature, MAX_SIGNATURE_BYTES, "migration receipt signature snapshot"
        )
        producer_signature_raw = read_unique_regular(
            producer_signature,
            MAX_SIGNATURE_BYTES,
            "migration evidence producer signature snapshot",
        )
        reviewer_signature_raw = read_unique_regular(
            reviewer_signature,
            MAX_SIGNATURE_BYTES,
            "migration evidence reviewer signature snapshot",
        )
        producer_key_raw = read_unique_regular(
            producer_key, MAX_KEY_BYTES, "migration evidence producer key snapshot"
        )
        reviewer_key_raw = read_unique_regular(
            reviewer_key, MAX_KEY_BYTES, "migration independent reviewer key snapshot"
        )

        trust_sha = require_sha256(
            sha256_bytes(trust_raw),
            "migration trust root SHA-256",
            expected_trust_sha,
        )
        if (
            trust["schemaVersion"] != 1
            or trust["contractId"]
            != "sora-ios-wallet-migration-qualification-trust-v1"
            or trust["platform"] != "ios"
            or trust["status"] != "qualified"
            or trust["signatureAlgorithm"] != "ecdsa-p256-sha256"
            or trust["blockingReasons"] != []
        ):
            fail("migration trust root is not exact qualified v1")
        authorities = trust["authorities"]
        producer = authorities["deviceEvidenceProducer"]
        reviewer = authorities["independentReviewer"]
        for authority, role, label, key_prefix in (
            (
                producer,
                "device-evidence-producer",
                "producer",
                "ios-migration-device-producer-",
            ),
            (
                reviewer,
                "independent-reviewer",
                "reviewer",
                "ios-migration-independent-reviewer-",
            ),
        ):
            if authority["role"] != role or authority["enabled"] is not True:
                fail(f"migration {label} authority is not qualified")
            validate_key_id(
                authority["keyId"], f"migration {label} key ID", key_prefix
            )
        if (
            producer["keyId"] == reviewer["keyId"]
            or producer["publicKeyPemSha256"]
            == reviewer["publicKeyPemSha256"]
        ):
            fail("migration evidence producer and reviewer authorities must be distinct")
        require_sha256(
            producer["publicKeyPemSha256"],
            "producer key pin",
            expected_producer_key_sha,
        )
        require_sha256(
            reviewer["publicKeyPemSha256"],
            "reviewer key pin",
            expected_reviewer_key_sha,
        )
        producer_spki = validate_p256_key(
            producer_key_raw,
            expected_producer_key_sha,
            "migration evidence producer key",
        )
        reviewer_spki = validate_p256_key(
            reviewer_key_raw,
            expected_reviewer_key_sha,
            "migration independent reviewer key",
        )
        if producer_spki == reviewer_spki:
            fail("migration evidence producer and reviewer must use distinct P-256 public keys")

        # Authentication is deliberately complete before source-contract hashing,
        # repository artifact parsing, or any access to the protected raw tree.
        verify_signature(
            receipt_raw,
            receipt_signature_raw,
            reviewer_key_raw,
            expected_reviewer_key_sha,
            "migration qualification receipt",
        )
        verify_signature(
            evidence_raw,
            producer_signature_raw,
            producer_key_raw,
            expected_producer_key_sha,
            "migration evidence producer attestation",
        )
        verify_signature(
            evidence_raw,
            reviewer_signature_raw,
            reviewer_key_raw,
            expected_reviewer_key_sha,
            "migration evidence independent review",
        )

        require_current_qualified_schemas(receipt, evidence)
        receipt_sha = sha256_bytes(receipt_raw)
        evidence_sha = sha256_bytes(evidence_raw)
        if receipt["runId"] != expected_run or evidence["runId"] != expected_run:
            fail("migration evidence run differs from the protected run ID")
        if (
            receipt["runChallengeSha256"] != expected_run_challenge
            or evidence["runChallengeSha256"] != expected_run_challenge
        ):
            fail("migration evidence challenge differs from the protected run challenge")
        if (
            receipt["rawInputSetSha256"] != expected_raw_input_sha
            or evidence["rawInputSetSha256"] != expected_raw_input_sha
        ):
            fail("migration evidence raw input set differs from the protected identity")
        if (
            receipt["qualificationSequenceNumber"] != expected_sequence
            or evidence["qualificationSequenceNumber"] != expected_sequence
        ):
            fail("migration evidence sequence differs from the protected sequence")
        require_source_revision(
            receipt["sourceRevision"], "receipt source revision", expected_source
        )
        require_source_revision(
            evidence["sourceRevision"], "evidence source revision", expected_source
        )
        require_sha256(receipt["trustRootSha256"], "receipt trust root", trust_sha)
        require_sha256(evidence["trustRootSha256"], "evidence trust root", trust_sha)
        require_sha256(
            receipt["evidenceManifestSha256"],
            "receipt evidence manifest",
            evidence_sha,
        )
        require_sha256(
            receipt["collectionReceiptSha256"],
            "receipt collection receipt",
            expected_collection_sha,
        )
        if (
            receipt["deviceEvidenceProducerKeyId"] != producer["keyId"]
            or evidence["deviceEvidenceProducerKeyId"] != producer["keyId"]
            or receipt["independentReviewerKeyId"] != reviewer["keyId"]
            or evidence["independentReviewerKeyId"] != reviewer["keyId"]
        ):
            fail("migration receipt/evidence key-role binding is invalid")
        validate_identity(receipt["identity"], "receipt.identity", expected_app)
        validate_identity(evidence["identity"], "evidence.identity", expected_app)
        if receipt["identity"] != evidence["identity"]:
            fail("migration receipt and evidence identities differ")
        validate_privacy(
            receipt["privacy"], "receipt.privacy", include_signed_payload_flag=True
        )
        validate_privacy(
            evidence["privacy"],
            "evidence.privacy",
            include_signed_payload_flag=False,
        )
        recursive_privacy_scan(receipt, "migration receipt")
        recursive_privacy_scan(evidence, "migration evidence")

        contract_snapshot = directory / "qualification-contract-snapshot.json"
        current_contract_sha = run_qualification_contract_tool(
            ["--snapshot", str(contract_snapshot)]
        )
        require_sha256(
            receipt["qualificationContractSha256"],
            "receipt qualification contract",
            current_contract_sha,
        )
        require_sha256(
            evidence["qualificationContractSha256"],
            "evidence qualification contract",
            current_contract_sha,
        )

        model_sources = {
            "version1": ROOT
            / "SoraPassport/Common/Storage/UserDataModel.xcdatamodeld/UserDataModel.xcdatamodel/contents",
            "version2": ROOT
            / "SoraPassport/Common/Storage/UserDataModel.xcdatamodeld/UserDataModel 2.xcdatamodel/contents",
        }
        model_snapshots: dict[str, Path] = {}
        for model_key, source in model_sources.items():
            model_snapshot = snapshot_input(
                source,
                MAX_JSON_BYTES,
                f"migration Core Data model {model_key}",
                directory,
                f"model-{model_key}",
                repository_owned=True,
            )
            require_sha256(
                receipt["coreDataModelSha256"][model_key],
                f"migration receipt Core Data model {model_key}",
                sha256_file(
                    model_snapshot,
                    MAX_JSON_BYTES,
                    f"migration Core Data model {model_key} snapshot",
                ),
            )
            model_snapshots[model_key] = model_snapshot
        if (
            receipt["sourceModelVersions"]
            != ["UserDataModel", "UserDataModel 2"]
            or receipt["targetModelVersion"] != "UserDataModel 2"
        ):
            fail("migration receipt Core Data model contract is not exact")

        chronology = evidence["chronology"]
        started = require_positive_int(
            chronology["runStartedAtEpochSeconds"], "run start"
        )
        finished = require_positive_int(
            chronology["runFinishedAtEpochSeconds"], "run finish"
        )
        artifact_times = {
            "retainedReleaseSnapshotManifest": require_positive_int(
                chronology["snapshotManifestProducedAtEpochSeconds"],
                "snapshot manifest time",
            ),
            "testResultBundle": require_positive_int(
                chronology["testResultProducedAtEpochSeconds"], "test result time"
            ),
            "keychainEvidence": require_positive_int(
                chronology["keychainEvidenceProducedAtEpochSeconds"],
                "Keychain evidence time",
            ),
            "deviceExecutionEvidence": require_positive_int(
                chronology["deviceExecutionEvidenceProducedAtEpochSeconds"],
                "device execution evidence time",
            ),
            "collectionReceipt": require_positive_int(
                chronology["collectionReceiptProducedAtEpochSeconds"],
                "collection receipt time",
            ),
        }
        evidence_produced = require_positive_int(
            evidence["producedAtEpochSeconds"], "evidence produced time"
        )
        reviewed = require_positive_int(
            receipt["reviewedAtEpochSeconds"], "receipt review time"
        )
        qualified = require_positive_int(
            receipt["qualifiedAtEpochSeconds"], "receipt qualification time"
        )
        now = int(time.time())
        policy = trust["replayPolicy"]
        if policy != {
            "maximumQualificationAgeSeconds": 604800,
            "maximumRunDurationSeconds": 172800,
            "maximumReviewDelaySeconds": 86400,
        }:
            fail("migration replay policy differs from the reviewed v1 contract")
        produced_times = list(artifact_times.values())
        if not (
            started <= min(produced_times)
            and max(produced_times) <= finished
            and finished <= evidence_produced <= reviewed <= qualified <= now
        ):
            fail("migration evidence chronology is invalid")
        if (
            finished - started > policy["maximumRunDurationSeconds"]
            or evidence_produced - finished
            > policy["maximumReviewDelaySeconds"]
            or reviewed - evidence_produced
            > policy["maximumReviewDelaySeconds"]
            or qualified - reviewed > policy["maximumReviewDelaySeconds"]
            or now - qualified > policy["maximumQualificationAgeSeconds"]
        ):
            fail("migration evidence violates the reviewed age/duration policy")

        expected_paths = {
            "collectionReceipt": "Fixtures/Modernization/ios-migration-collection-receipt.json",
            "retainedReleaseSnapshotManifest": "Fixtures/Modernization/ios-migration-retained-snapshot-manifest.json",
            "testResultBundle": "Fixtures/Modernization/ios-migration-tests.xcresult.zip",
            "keychainEvidence": "Fixtures/Modernization/ios-migration-keychain-evidence.json",
            "deviceExecutionEvidence": "Fixtures/Modernization/ios-migration-device-execution-evidence.json",
        }
        artifact_snapshots: dict[str, tuple[Path, str, int, int]] = {}
        for key, relative in expected_paths.items():
            entry = evidence["artifacts"][key]
            if entry["relativePath"] != relative:
                fail(f"migration artifact {key} path is not fixed")
            expected_hash = require_sha256(
                entry["sha256"], f"migration artifact {key} hash"
            )
            expected_size = require_positive_int(
                entry["byteCount"], f"migration artifact {key} byte count"
            )
            maximum = (
                MAX_XCRESULT_ZIP_BYTES if key == "testResultBundle" else MAX_JSON_BYTES
            )
            artifact_snapshot = snapshot_input(
                ROOT / relative,
                maximum,
                f"migration artifact {key}",
                directory,
                f"artifact-{key}",
                repository_owned=True,
            )
            actual_hash = sha256_file(
                artifact_snapshot, maximum, f"migration artifact {key} snapshot"
            )
            actual_size = os.stat(
                artifact_snapshot, follow_symlinks=False
            ).st_size
            if actual_hash != expected_hash or actual_size != expected_size:
                fail(f"migration artifact {key} differs from the signed evidence manifest")
            artifact_snapshots[key] = (
                artifact_snapshot,
                actual_hash,
                actual_size,
                maximum,
            )
        if artifact_snapshots["collectionReceipt"][1] != expected_collection_sha:
            fail("opened collection receipt differs from its protected identity")
        receipt_artifact_fields = {
            "collectionReceipt": "collectionReceiptSha256",
            "retainedReleaseSnapshotManifest": "retainedReleaseSnapshotManifestSha256",
            "testResultBundle": "testResultBundleSha256",
            "keychainEvidence": "keychainEvidenceSha256",
            "deviceExecutionEvidence": "deviceExecutionEvidenceSha256",
        }
        for key, receipt_field in receipt_artifact_fields.items():
            require_sha256(
                receipt[receipt_field],
                f"migration receipt {key}",
                artifact_snapshots[key][1],
            )

        collection = load_json_bytes(
            read_unique_regular(
                artifact_snapshots["collectionReceipt"][0],
                MAX_JSON_BYTES,
                "migration collection receipt snapshot",
            ),
            "migration collection receipt",
        )
        collection_artifacts = {
            key: (
                expected_paths[key],
                artifact_snapshots[key][1],
                artifact_snapshots[key][2],
            )
            for key in (
                "retainedReleaseSnapshotManifest",
                "testResultBundle",
                "keychainEvidence",
                "deviceExecutionEvidence",
            )
        }
        collected_at = validate_collection_receipt(
            collection,
            run_id=expected_run,
            run_challenge=expected_run_challenge,
            raw_input_set_sha=expected_raw_input_sha,
            source_revision=expected_source,
            qualification_contract_sha=current_contract_sha,
            identity=receipt["identity"],
            expected_app=expected_app,
            expected_artifacts=collection_artifacts,
        )
        if collected_at != artifact_times["collectionReceipt"]:
            fail("collection receipt chronology differs from signed evidence")

        initial_raw_entries, initial_raw_sha, initial_raw_count, initial_raw_bytes = (
            inventory_raw_tree(expected_raw_root, "protected migration raw input root")
        )
        if (
            initial_raw_sha != expected_raw_input_sha
            or collection["rawInputSet"]["fileCount"] != initial_raw_count
            or collection["rawInputSet"]["byteCount"] != initial_raw_bytes
        ):
            fail("protected raw input root differs from the signed collection identity")

        derived_root = directory / "independently-derived-observed-output"
        collector_process = run_repository_python(
            COLLECTOR,
            [
                "--collect",
                "--input-root",
                str(expected_raw_root),
                "--output-root",
                str(derived_root),
            ],
            "iOS migration raw-evidence collector",
            timeout=21600,
        )
        if len(collector_process.stdout) > MAX_JSON_BYTES:
            fail("migration collector result exceeds its JSON byte bound")
        collector_result = load_json_bytes(
            collector_process.stdout, "migration collector result"
        )
        exact_keys(
            collector_result,
            {
                "schemaVersion",
                "contractId",
                "runId",
                "runChallengeSha256",
                "sourceRevision",
                "qualificationContractSha256",
                "rawInputSetSha256",
                "runStartedAtEpochSeconds",
                "runFinishedAtEpochSeconds",
                "collectionReceiptSha256",
                "outputRoot",
                "artifactCount",
            },
            "migration collector result",
        )
        for key in (
            "schemaVersion",
            "runStartedAtEpochSeconds",
            "runFinishedAtEpochSeconds",
            "artifactCount",
        ):
            require_types(
                collector_result[key], (int,), f"migration collector result.{key}"
            )
        for key in (
            "contractId",
            "runId",
            "runChallengeSha256",
            "sourceRevision",
            "qualificationContractSha256",
            "rawInputSetSha256",
            "collectionReceiptSha256",
            "outputRoot",
        ):
            require_types(
                collector_result[key], (str,), f"migration collector result.{key}"
            )
        if (
            collector_result["schemaVersion"] != 2
            or collector_result["contractId"]
            != "sora-ios-wallet-migration-collector-result-v2"
            or collector_result["runId"] != expected_run
            or collector_result["runChallengeSha256"] != expected_run_challenge
            or collector_result["sourceRevision"] != expected_source
            or collector_result["qualificationContractSha256"]
            != current_contract_sha
            or collector_result["rawInputSetSha256"] != expected_raw_input_sha
            or collector_result["runStartedAtEpochSeconds"] != started
            or collector_result["runFinishedAtEpochSeconds"] != finished
            or collector_result["collectionReceiptSha256"]
            != expected_collection_sha
            or collector_result["outputRoot"] != str(derived_root)
            or collector_result["artifactCount"] != 5
        ):
            fail("independent migration collector result differs from signed identity")
        derived_names = {
            "collectionReceipt": "ios-migration-collection-receipt.json",
            "retainedReleaseSnapshotManifest": "ios-migration-retained-snapshot-manifest.json",
            "testResultBundle": "ios-migration-tests.xcresult.zip",
            "keychainEvidence": "ios-migration-keychain-evidence.json",
            "deviceExecutionEvidence": "ios-migration-device-execution-evidence.json",
        }
        derived_directory_fd = open_anchored_external_directory(
            derived_root, "independent migration collector output"
        )
        try:
            derived_directory_before = os.fstat(derived_directory_fd)
            actual_derived_names = set(os.listdir(derived_directory_fd))
            if actual_derived_names != set(derived_names.values()):
                fail("independent migration collector output inventory is not exact")
            for key, name in derived_names.items():
                derived_hash, derived_size = hash_anchored_named_regular(
                    derived_directory_fd,
                    name,
                    artifact_snapshots[key][3],
                    f"independently derived migration artifact {key}",
                )
                if (
                    derived_hash != artifact_snapshots[key][1]
                    or derived_size != artifact_snapshots[key][2]
                ):
                    fail(
                        f"migration artifact {key} does not byte-reproduce from protected raw input"
                    )
            derived_directory_after = os.fstat(derived_directory_fd)
            if (
                set(os.listdir(derived_directory_fd)) != actual_derived_names
                or (
                    derived_directory_after.st_dev,
                    derived_directory_after.st_ino,
                    derived_directory_after.st_mtime_ns,
                )
                != (
                    derived_directory_before.st_dev,
                    derived_directory_before.st_ino,
                    derived_directory_before.st_mtime_ns,
                )
            ):
                fail("independent migration collector output changed during comparison")
        finally:
            os.close(derived_directory_fd)

        aggregate_contracts = {
            "retainedReleaseSnapshotManifest": (
                "sora-ios-wallet-migration-retained-snapshot-manifest-v4",
                artifact_times["retainedReleaseSnapshotManifest"],
            ),
            "keychainEvidence": (
                "sora-ios-wallet-migration-keychain-evidence-v4",
                artifact_times["keychainEvidence"],
            ),
            "deviceExecutionEvidence": (
                "sora-ios-wallet-migration-device-execution-evidence-v4",
                artifact_times["deviceExecutionEvidence"],
            ),
        }
        aggregate_records: dict[str, dict[str, Any]] = {}
        for key, (contract_id, produced_at) in aggregate_contracts.items():
            record = load_json_bytes(
                read_unique_regular(
                    artifact_snapshots[key][0],
                    MAX_JSON_BYTES,
                    f"migration artifact {key} snapshot",
                ),
                f"migration artifact {key}",
            )
            validate_aggregate_artifact(
                record,
                f"migration artifact {key}",
                contract_id,
                expected_run,
                expected_run_challenge,
                expected_raw_input_sha,
                expected_source,
                produced_at,
                receipt["identity"],
            )
            aggregate_records[key] = record

        snapshot_aggregate = aggregate_records["retainedReleaseSnapshotManifest"][
            "aggregate"
        ]
        exact_keys(
            snapshot_aggregate,
            {
                "retainedReleaseSnapshotCount",
                "sourceModelVersions",
                "walBearingSnapshotCount",
                "walSensitiveSnapshotCount",
                "allSnapshotFilesRegular",
                "allSnapshotHashesVerified",
                "allSnapshotStoresOpenedReadOnly",
                "walSidecarsOpenedReadOnly",
                "reviewedSettingsParity",
                "accountCountParity",
                "selectedWalletParity",
                "snapshotsSha256",
            },
            "retained snapshot aggregate",
        )
        if (
            snapshot_aggregate["retainedReleaseSnapshotCount"]
            != receipt["retainedReleaseSnapshotCount"]
            or snapshot_aggregate["sourceModelVersions"]
            != receipt["sourceModelVersions"]
            or require_positive_int(
                snapshot_aggregate["walBearingSnapshotCount"],
                "retained snapshot WAL-bearing count",
            )
            < 1
            or require_positive_int(
                snapshot_aggregate["walSensitiveSnapshotCount"],
                "retained snapshot WAL-sensitive count",
            )
            < 1
            or any(
                snapshot_aggregate[key] is not True
                for key in (
                    "allSnapshotFilesRegular",
                    "allSnapshotHashesVerified",
                    "allSnapshotStoresOpenedReadOnly",
                    "walSidecarsOpenedReadOnly",
                    "reviewedSettingsParity",
                    "accountCountParity",
                    "selectedWalletParity",
                )
            )
            or require_sha256(
                snapshot_aggregate["snapshotsSha256"],
                "retained snapshot projection",
            )
            == "0" * 64
        ):
            fail("retained snapshot aggregate differs from the qualified receipt")

        keychain_aggregate = aggregate_records["keychainEvidence"]["aggregate"]
        exact_keys(
            keychain_aggregate,
            {
                "successfulSecretSourceCohortCount",
                "secretFailureCohortCount",
                "identityUnchanged",
                "accessibilityUnchanged",
                "noCredentialRewrite",
                "rawValuesExcluded",
                "observationProjectionSha256",
            },
            "Keychain aggregate evidence",
        )
        if (
            keychain_aggregate["successfulSecretSourceCohortCount"]
            != receipt["successfulSecretSourceCohortCount"]
            or keychain_aggregate["secretFailureCohortCount"]
            != receipt["secretFailureCohortCount"]
            or keychain_aggregate["identityUnchanged"]
            != receipt["keychainIdentityUnchanged"]
            or keychain_aggregate["accessibilityUnchanged"]
            != receipt["keychainAccessibilityUnchanged"]
            or keychain_aggregate["noCredentialRewrite"] is not True
            or keychain_aggregate["rawValuesExcluded"] is not True
            or require_sha256(
                keychain_aggregate["observationProjectionSha256"],
                "Keychain observation projection",
            )
            == "0" * 64
        ):
            fail("Keychain aggregate evidence differs from the qualified receipt")

        device_aggregate = aggregate_records["deviceExecutionEvidence"]["aggregate"]
        exact_keys(
            device_aggregate,
            {
                "retainedCoreDataCohortCount",
                "interruptionPointCohortCount",
                "reinstallUpgradeQualified",
                "rollbackQualified",
                "lowStorageQualified",
                "recoveryArchiveExportQualified",
                "processDeathRestartQualified",
                "eventProjectionSha256",
            },
            "device execution aggregate evidence",
        )
        if (
            device_aggregate["retainedCoreDataCohortCount"]
            != receipt["retainedCoreDataCohortCount"]
            or device_aggregate["interruptionPointCohortCount"]
            != receipt["interruptionPointCohortCount"]
            or device_aggregate["reinstallUpgradeQualified"]
            != receipt["qualificationChecks"]["reinstallUpgradeQualified"]
            or device_aggregate["rollbackQualified"]
            != receipt["qualificationChecks"]["rollbackQualified"]
            or device_aggregate["lowStorageQualified"]
            != receipt["qualificationChecks"]["lowStorageQualified"]
            or device_aggregate["recoveryArchiveExportQualified"]
            != receipt["qualificationChecks"]["recoveryArchiveExportQualified"]
            or device_aggregate["processDeathRestartQualified"] is not True
            or require_sha256(
                device_aggregate["eventProjectionSha256"],
                "device event projection",
            )
            == "0" * 64
        ):
            fail("device execution aggregate differs from the qualified receipt")

        validate_test_result_zip(
            artifact_snapshots["testResultBundle"][0],
            receipt,
            expected_run,
            expected_run_challenge,
            expected_raw_input_sha,
            expected_source,
            artifact_times["testResultBundle"],
            receipt["identity"],
        )

        exact_counts = {
            "retainedCoreDataModelCount": 2,
            "retainedCoreDataCohortCount": 4,
            "singleAccountCohortCount": 2,
            "multiAccountCohortCount": 2,
            "successfulSecretSourceCohortCount": 6,
            "secretFailureCohortCount": 2,
            "currentSchemaSafetySnapshotCohortCount": 2,
            "interruptionPointCohortCount": 5,
            "executedWalletModernizationTestCount": 198,
            "executedRecoveryCapabilityGateTestCount": 11,
            "executedRecoveryExporterTestCount": 12,
            "executedRetainedDeviceEvidenceTestCount": 3,
            "testFailureCount": 0,
            "testUnexpectedFailureCount": 0,
            "testSkippedCount": 0,
            "testExpectedFailureCount": 0,
        }
        if any(receipt[key] != value for key, value in exact_counts.items()):
            fail("migration receipt count matrix is not exact v7")
        if not 4 <= receipt["retainedReleaseSnapshotCount"] <= 256:
            fail("migration receipt retained snapshot count is outside the reviewed bound")
        for key in (
            "zeroLostAccounts",
            "accountCountParity",
            "selectedWalletParity",
            "preferencesParity",
            "keychainIdentityUnchanged",
            "keychainAccessibilityUnchanged",
            "legacyStoresRetainedForDualRead",
            "sora2SigningParity",
        ):
            if receipt[key] is not True:
                fail(f"migration receipt assertion is not exact true: {key}")
        for key in QUALIFICATION_CHECK_KEYS:
            if receipt["qualificationChecks"][key] is not True:
                fail(f"migration qualification check is not exact true: {key}")

        for original, expected_digest, maximum, label, repository_owned in (
            (
                receipt_original,
                sha256_bytes(receipt_raw),
                MAX_JSON_BYTES,
                "migration receipt",
                True,
            ),
            (
                evidence_original,
                sha256_bytes(evidence_raw),
                MAX_JSON_BYTES,
                "migration evidence manifest",
                True,
            ),
            (
                trust_original,
                sha256_bytes(trust_raw),
                MAX_JSON_BYTES,
                "migration trust root",
                True,
            ),
            (
                receipt_signature_original,
                sha256_bytes(receipt_signature_raw),
                MAX_SIGNATURE_BYTES,
                "migration receipt signature",
                False,
            ),
            (
                producer_signature_original,
                sha256_bytes(producer_signature_raw),
                MAX_SIGNATURE_BYTES,
                "migration evidence producer signature",
                False,
            ),
            (
                reviewer_signature_original,
                sha256_bytes(reviewer_signature_raw),
                MAX_SIGNATURE_BYTES,
                "migration evidence reviewer signature",
                False,
            ),
            (
                producer_key_original,
                sha256_bytes(producer_key_raw),
                MAX_KEY_BYTES,
                "migration evidence producer key",
                False,
            ),
            (
                reviewer_key_original,
                sha256_bytes(reviewer_key_raw),
                MAX_KEY_BYTES,
                "migration independent reviewer key",
                False,
            ),
        ):
            recheck_input_digest(
                original,
                expected_digest,
                maximum,
                label,
                repository_owned=repository_owned,
            )
        for key, relative in expected_paths.items():
            recheck_input_digest(
                ROOT / relative,
                artifact_snapshots[key][1],
                artifact_snapshots[key][3],
                f"migration artifact {key}",
                repository_owned=True,
            )
        for model_key, source in model_sources.items():
            recheck_input_digest(
                source,
                receipt["coreDataModelSha256"][model_key],
                MAX_JSON_BYTES,
                f"migration Core Data model {model_key}",
                repository_owned=True,
            )
        final_raw_entries, final_raw_sha, final_raw_count, final_raw_bytes = (
            inventory_raw_tree(
                expected_raw_root, "protected migration raw input root final recheck"
            )
        )
        if (
            final_raw_entries != initial_raw_entries
            or final_raw_sha != initial_raw_sha
            or final_raw_count != initial_raw_count
            or final_raw_bytes != initial_raw_bytes
        ):
            fail("protected migration raw input root changed during admission")
        if (
            run_qualification_contract_tool(
                [
                    "--verify-snapshot",
                    str(contract_snapshot),
                    "--expected-sha",
                    current_contract_sha,
                ]
            )
            != current_contract_sha
        ):
            fail("migration qualification source contract changed during admission")
        return receipt_sha


def verify_qualified_ipa(raw_path: str) -> tuple[str, str]:
    candidate = Path(raw_path)
    if str(candidate) != raw_path:
        fail("completed post-archive IPA path must be canonical")

    # The complete signed v8/v4/raw-v3 qualification is authenticated and
    # rechecked before the completed IPA path is opened or hashed.
    receipt_sha = verify_qualified()
    expected_ipa_sha = require_sha256(
        required_env("IOS_MIGRATION_QUALIFICATION_APP_BUILD_IDENTITY_SHA256"),
        "protected completed IPA identity",
    )
    actual_ipa_sha, _ = hash_completed_ipa(candidate, expected_ipa_sha)
    return receipt_sha, actual_ipa_sha


def main(argv: list[str]) -> int:
    try:
        if argv == ["--lint-templates"]:
            validate_templates()
            return 0
        if argv == ["--verify-qualified"]:
            validate_templates()
            receipt_sha = verify_qualified()
            print(f"receiptSha256={receipt_sha}")
            return 0
        if len(argv) == 2 and argv[0] == "--verify-qualified-ipa":
            validate_templates()
            receipt_sha, ipa_sha = verify_qualified_ipa(argv[1])
            print(f"receiptSha256={receipt_sha} ipaSha256={ipa_sha}")
            return 0
        fail(
            "usage: verify-ios-migration-qualification.py "
            "--lint-templates|--verify-qualified|--verify-qualified-ipa /absolute/completed.ipa"
        )
    except QualificationError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
