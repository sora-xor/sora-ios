#!/usr/bin/env python3
"""Strict, fail-closed JSON and IPA validation for the iOS rollout controller.

This helper intentionally uses only the Python standard library. Detached receipt
signatures and the externally pinned controller trust root are verified by the
calling shell script.
"""

from __future__ import annotations

import hashlib
import json
import os
import plistlib
import re
import stat
import sys
import zipfile
from pathlib import Path, PurePosixPath
from typing import Any, Iterable
from urllib.parse import urlsplit


MAX_JSON_BYTES = 262_144
MAX_IPA_ENTRIES = 100_000
MAX_IPA_UNCOMPRESSED_BYTES = 8 * 1024 * 1024 * 1024
MAX_IPA_MEMBER_BYTES = 2 * 1024 * 1024 * 1024
MAX_EXECUTABLE_BYTES = 512 * 1024 * 1024
MAX_STRING_CHARACTERS = 4_096
MAX_SAFE_INTEGER = 9_007_199_254_740_991
MAXIMUM_AUTHORIZATION_DELAY_SECONDS = 30
SORA2_REVISION = "411dcdb70c5c00b21482a44d02334840d5f338c6"
RUNTIME_METADATA_SHA256 = "2b49c3cbf682d8b88985a04a60a958de3ef5de77d282c3622bdae53f7e4fbabf"
SOURCE_ENTITLEMENTS_SHA256 = "97704a8960b4facceef54397a08fb5d0a456247c3627359215aa2a27df22656c"
BUNDLE_IDENTIFIER = "co.jp.soramitsu.sora"
DEVELOPMENT_TEAM = "YLWWUD25VZ"
APPLICATION_IDENTIFIER = f"{DEVELOPMENT_TEAM}.{BUNDLE_IDENTIFIER}"
SORA2_GENESIS_HASH = "7e4e32d0feafd4f9c9414b0be86373f9a1efa904809b683453a9af6856d38ad5"

HEX_64 = re.compile(r"^[0-9a-f]{64}$")
HEX_40 = re.compile(r"^[0-9a-f]{40}$")
UUID = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
    re.IGNORECASE,
)

PRIVACY_KEYS = {
    "aggregateOnly",
    "accountIdentifiersIncluded",
    "addressesIncluded",
    "transactionIdentifiersIncluded",
    "phrasesOrSeedsIncluded",
    "privateKeysIncluded",
    "publicKeysIncluded",
    "rawSignedPayloadsIncluded",
    "perWalletRecordsIncluded",
    "deviceIdentifiersIncluded",
    "ipAddressesIncluded",
    "rawResponsesIncluded",
    "rawErrorsIncluded",
}

IDENTITY_KEYS = {
    "candidateBindingSha256",
    "evaluationBindingSha256",
    "candidateArtifactSha256",
    "artifactIdentityReceiptSha256",
    "productionQualificationReceiptSha256",
    "fundedNexusCanaryAdmissionReceiptSha256",
    "fundedTairaCanaryReceiptSha256",
    "fundedMinamotoCanaryReceiptSha256",
    "tairaDeploymentManifestSha256",
    "tairaDeploymentAdmissionSha256",
    "tairaCurrentChainId",
    "tairaCurrentGenesisHash",
    "piProbeReceiptSha256",
    "piCapturedAtEpochSeconds",
    "sourceRevision",
    "bundleIdentifier",
    "developmentTeam",
    "appVersion",
    "buildNumber",
    "appStoreBuildIdentifier",
    "sora2NetworkRevision",
    "runtimeSpecVersion",
    "runtimeTransactionVersion",
    "runtimeMetadataSha256",
    "capabilitySnapshotSha256",
    "finalizedCheckpointBindingSha256",
    "sora2GenesisHash",
    "sora2FinalizedHeight",
    "sora2FinalizedBlockHash",
    "minamotoGenesisHash",
    "minamotoFinalizedHeight",
    "minamotoFinalizedBlockHash",
    "tairaGenesisHash",
    "tairaFinalizedHeight",
    "tairaFinalizedBlockHash",
}
TAIRA_KNOWN_CHAIN_IDS = {
    "809574f5-fee7-5e69-bfcf-52451e42d50f",
    "fc56984b-2be7-431d-840e-21514d1883f0",
}
TAIRA_DEPLOYMENT: dict[str, Any] | None = None


class ValidationError(Exception):
    pass


def fail(message: str) -> None:
    raise ValidationError(message)


def strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            fail(f"duplicate JSON key after escape decoding: {key}")
        result[key] = value
    return result


def reject_float(value: str) -> Any:
    fail(f"floating-point JSON value is forbidden: {value}")


def reject_constant(value: str) -> Any:
    fail(f"non-finite JSON value is forbidden: {value}")


def parse_integer(value: str) -> int:
    if value == "-0":
        fail("non-canonical negative-zero JSON integer is forbidden")
    return int(value)


def read_stable_regular_file(path_text: str, maximum_bytes: int) -> bytes:
    path = Path(path_text)
    if not path.is_absolute():
        fail(f"input path must be absolute: {path}")
    flags = os.O_RDONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        descriptor = os.open(path, flags)
    except OSError as error:
        fail(f"cannot open regular non-symlink file {path}: {error}")
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode):
            fail(f"input path is not a regular file: {path}")
        if before.st_size <= 0 or before.st_size > maximum_bytes:
            fail(f"input file is empty or exceeds its bound: {path}")
        chunks: list[bytes] = []
        observed = 0
        while True:
            chunk = os.read(descriptor, min(1024 * 1024, maximum_bytes + 1 - observed))
            if not chunk:
                break
            chunks.append(chunk)
            observed += len(chunk)
            if observed > maximum_bytes:
                fail(f"input file exceeds its bound: {path}")
        after = os.fstat(descriptor)
        before_identity = (
            before.st_dev,
            before.st_ino,
            before.st_size,
            before.st_mtime_ns,
            before.st_ctime_ns,
        )
        after_identity = (
            after.st_dev,
            after.st_ino,
            after.st_size,
            after.st_mtime_ns,
            after.st_ctime_ns,
        )
        if observed != before.st_size or before_identity != after_identity:
            fail(f"input file changed while it was read: {path}")
        return b"".join(chunks)
    finally:
        os.close(descriptor)


def load_json(path_text: str) -> dict[str, Any]:
    path = Path(path_text)
    raw = read_stable_regular_file(path_text, MAX_JSON_BYTES)
    try:
        text = raw.decode("utf-8", errors="strict")
    except UnicodeDecodeError as error:
        fail(f"JSON receipt {path} is not strict UTF-8: {error}")
    try:
        value = json.loads(
            text,
            object_pairs_hook=strict_object,
            parse_int=parse_integer,
            parse_float=reject_float,
            parse_constant=reject_constant,
        )
    except (json.JSONDecodeError, ValidationError) as error:
        fail(f"JSON receipt {path} is invalid: {error}")
    if type(value) is not dict:
        fail(f"JSON receipt {path} must contain one top-level object")
    return value


def exact_keys(value: Any, expected: Iterable[str], path: str) -> dict[str, Any]:
    if type(value) is not dict:
        fail(f"{path} must be an object")
    expected_set = set(expected)
    actual_set = set(value.keys())
    if actual_set != expected_set:
        missing = sorted(expected_set - actual_set)
        extra = sorted(actual_set - expected_set)
        fail(f"{path} keys differ; missing={missing}, extra={extra}")
    return value


def require_bool(value: Any, path: str, expected: bool | None = None) -> bool:
    if type(value) is not bool:
        fail(f"{path} must be a boolean")
    if expected is not None and value is not expected:
        fail(f"{path} must be {str(expected).lower()}")
    return value


def require_int(
    value: Any,
    path: str,
    minimum: int = 0,
    maximum: int = 90_000_000_000_000,
) -> int:
    if type(value) is not int or value < minimum or value > maximum:
        fail(f"{path} must be an integer in [{minimum}, {maximum}]")
    return value


def require_string(
    value: Any,
    path: str,
    expected: str | None = None,
    maximum: int = MAX_STRING_CHARACTERS,
) -> str:
    if type(value) is not str or not value or len(value) > maximum:
        fail(f"{path} must be a non-empty bounded string")
    if expected is not None and value != expected:
        fail(f"{path} must equal {expected}")
    return value


def require_hex64(value: Any, path: str) -> str:
    text = require_string(value, path, maximum=64)
    if HEX_64.fullmatch(text) is None:
        fail(f"{path} must be a lowercase 64-character SHA-256")
    if text == "0" * 64:
        fail(f"{path} must not use the all-zero placeholder")
    return text


def require_binding_string(value: Any, path: str, maximum: int = 256) -> str:
    text = require_string(value, path, maximum=maximum)
    if "=" in text or any(ord(character) < 0x20 or ord(character) == 0x7F for character in text):
        fail(f"{path} contains a non-canonical binding character")
    return text


def require_hex40(value: Any, path: str) -> str:
    text = require_string(value, path, maximum=40)
    if HEX_40.fullmatch(text) is None:
        fail(f"{path} must be a lowercase 40-character source revision")
    if text == "0" * 40:
        fail(f"{path} must not use the all-zero source placeholder")
    return text


def configure_authenticated_taira(path: str) -> None:
    global TAIRA_DEPLOYMENT
    value = load_json(path)
    root = exact_keys(
        value,
        {
            "schemaVersion", "contractId", "status",
            "evaluatedAtEpochSeconds", "manifestSha256",
            "operatorSignatureSha256", "reviewerSignatureSha256",
            "operatorPublicKeySpkiSha256", "reviewerPublicKeySpkiSha256",
            "current", "retired", "pendingRowPolicy",
        },
        "Taira deployment admission",
    )
    require_int(root["schemaVersion"], "Taira admission schemaVersion", 1, 1)
    require_string(root["contractId"], "Taira admission contractId", "sora-ios-taira-deployment-admission-v1")
    require_string(root["status"], "Taira admission status", "admitted")
    require_int(root["evaluatedAtEpochSeconds"], "Taira admission evaluation", 1)
    for key in (
        "manifestSha256", "operatorSignatureSha256",
        "reviewerSignatureSha256", "operatorPublicKeySpkiSha256",
        "reviewerPublicKeySpkiSha256",
    ):
        require_hex64(root[key], f"Taira admission {key}")
    if root["operatorPublicKeySpkiSha256"] == root["reviewerPublicKeySpkiSha256"]:
        fail("Taira deployment authorities are not distinct")
    epoch_keys = {
        "chainId", "role", "deploymentEpoch", "genesisHash",
        "canonicalToriiBaseUrl", "publicMcpEndpoint",
    }
    current = exact_keys(root["current"], epoch_keys, "Taira current deployment")
    retired = exact_keys(root["retired"], epoch_keys, "Taira retired deployment")
    require_string(current["role"], "Taira current role", "current")
    require_string(retired["role"], "Taira retired role", "retired")
    if {current["chainId"], retired["chainId"]} != TAIRA_KNOWN_CHAIN_IDS:
        fail("Taira deployment does not retain both known UUIDs in distinct roles")
    require_int(
        current["deploymentEpoch"],
        "Taira current epoch",
        1,
        MAX_SAFE_INTEGER,
    )
    require_int(
        retired["deploymentEpoch"],
        "Taira retired epoch",
        1,
        MAX_SAFE_INTEGER,
    )
    if current["deploymentEpoch"] <= retired["deploymentEpoch"]:
        fail("current Taira deployment epoch is not newer than retired")
    require_hex64(current["genesisHash"], "Taira current genesis")
    require_hex64(retired["genesisHash"], "Taira retired genesis")
    if current["genesisHash"] == retired["genesisHash"]:
        fail("Taira deployment genesis identities are not distinct")
    if retired["canonicalToriiBaseUrl"] is not None or retired["publicMcpEndpoint"] is not None:
        fail("retired Taira identity authorizes transport")
    base = require_string(current["canonicalToriiBaseUrl"], "Taira canonical Torii origin", maximum=2_048)
    endpoint = require_string(current["publicMcpEndpoint"], "Taira MCP endpoint", maximum=2_060)
    parsed = urlsplit(base)
    if (
        parsed.scheme != "https"
        or parsed.hostname is None
        or parsed.hostname != parsed.hostname.lower()
        or parsed.hostname == "taira.sora.org"
        or "." not in parsed.hostname
        or parsed.username is not None
        or parsed.password is not None
        or parsed.port not in (None, 443)
        or parsed.path
        or parsed.query
        or parsed.fragment
        or endpoint != f"{base}/v1/mcp"
    ):
        fail("Taira deployment lacks one explicit canonical public HTTPS /v1/mcp route")
    policy = exact_keys(
        root["pendingRowPolicy"],
        {
            "schemaVersion", "preserveExactChainUuid",
            "mismatchedCurrentDisposition", "reinterpretationAllowed",
        },
        "Taira pending-row policy",
    )
    if (
        policy["schemaVersion"] != 77
        or policy["preserveExactChainUuid"] is not True
        or policy["mismatchedCurrentDisposition"] != "quarantine-recovery-only"
        or policy["reinterpretationAllowed"] is not False
    ):
        fail("Taira deployment permits schema-77 pending-row reinterpretation")
    TAIRA_DEPLOYMENT = {
        "manifestSha256": root["manifestSha256"],
        "admissionSha256": secure_file_sha256(path, MAX_JSON_BYTES),
        "currentChainId": current["chainId"],
        "currentGenesisHash": current["genesisHash"],
        "canonicalToriiBaseUrl": base,
        "publicMcpEndpoint": endpoint,
    }


def validate_privacy(value: Any, path: str = "privacy") -> None:
    privacy = exact_keys(value, PRIVACY_KEYS, path)
    require_bool(privacy["aggregateOnly"], f"{path}.aggregateOnly", True)
    for key in PRIVACY_KEYS - {"aggregateOnly"}:
        require_bool(privacy[key], f"{path}.{key}", False)


def validate_identity(value: Any, path: str, blocked: bool = False) -> None:
    identity = exact_keys(value, IDENTITY_KEYS, path)
    require_string(identity["bundleIdentifier"], f"{path}.bundleIdentifier", BUNDLE_IDENTIFIER)
    require_string(identity["developmentTeam"], f"{path}.developmentTeam", DEVELOPMENT_TEAM)
    require_string(identity["sora2NetworkRevision"], f"{path}.sora2NetworkRevision", SORA2_REVISION)
    require_int(identity["runtimeSpecVersion"], f"{path}.runtimeSpecVersion", 130, 130)
    require_int(identity["runtimeTransactionVersion"], f"{path}.runtimeTransactionVersion", 130, 130)
    require_string(
        identity["runtimeMetadataSha256"],
        f"{path}.runtimeMetadataSha256",
        RUNTIME_METADATA_SHA256,
    )
    unavailable = {
        "candidateBindingSha256",
        "evaluationBindingSha256",
        "candidateArtifactSha256",
        "artifactIdentityReceiptSha256",
        "productionQualificationReceiptSha256",
        "fundedNexusCanaryAdmissionReceiptSha256",
        "fundedTairaCanaryReceiptSha256",
        "fundedMinamotoCanaryReceiptSha256",
        "tairaDeploymentManifestSha256",
        "tairaDeploymentAdmissionSha256",
        "tairaCurrentChainId",
        "tairaCurrentGenesisHash",
        "piProbeReceiptSha256",
        "sourceRevision",
        "appVersion",
        "buildNumber",
        "appStoreBuildIdentifier",
        "capabilitySnapshotSha256",
        "finalizedCheckpointBindingSha256",
        "sora2GenesisHash",
        "sora2FinalizedBlockHash",
        "minamotoGenesisHash",
        "minamotoFinalizedBlockHash",
        "tairaGenesisHash",
        "tairaFinalizedBlockHash",
    }
    if blocked:
        for key in unavailable:
            require_string(identity[key], f"{path}.{key}", "UNAVAILABLE")
        for key in {
            "piCapturedAtEpochSeconds",
            "sora2FinalizedHeight",
            "minamotoFinalizedHeight",
            "tairaFinalizedHeight",
        }:
            require_int(identity[key], f"{path}.{key}", 0, 0)
    else:
        for key in unavailable - {
            "sourceRevision", "appVersion", "buildNumber",
            "appStoreBuildIdentifier", "tairaCurrentChainId",
        }:
            require_hex64(identity[key], f"{path}.{key}")
        require_hex40(identity["sourceRevision"], f"{path}.sourceRevision")
        require_binding_string(identity["appVersion"], f"{path}.appVersion", maximum=128)
        require_binding_string(identity["buildNumber"], f"{path}.buildNumber", maximum=128)
        require_binding_string(
            identity["appStoreBuildIdentifier"],
            f"{path}.appStoreBuildIdentifier",
            maximum=256,
        )
        if TAIRA_DEPLOYMENT is None:
            fail("qualified rollout lacks an authenticated Taira deployment")
        require_string(
            identity["tairaDeploymentManifestSha256"],
            f"{path}.tairaDeploymentManifestSha256",
            TAIRA_DEPLOYMENT["manifestSha256"],
        )
        require_string(
            identity["tairaDeploymentAdmissionSha256"],
            f"{path}.tairaDeploymentAdmissionSha256",
            TAIRA_DEPLOYMENT["admissionSha256"],
        )
        require_string(
            identity["tairaCurrentChainId"],
            f"{path}.tairaCurrentChainId",
            TAIRA_DEPLOYMENT["currentChainId"],
        )
        require_string(
            identity["tairaCurrentGenesisHash"],
            f"{path}.tairaCurrentGenesisHash",
            TAIRA_DEPLOYMENT["currentGenesisHash"],
        )
        for key in {
            "piCapturedAtEpochSeconds",
            "sora2FinalizedHeight",
            "minamotoFinalizedHeight",
            "tairaFinalizedHeight",
        }:
            require_int(identity[key], f"{path}.{key}", 1)


def validate_blocked_rollout(
    value: dict[str, Any],
    *,
    sequence: int,
    from_percent: int,
    target_percent: int,
    warning: str,
    prior: Any,
) -> None:
    expected_keys = {
        "schemaVersion",
        "contractId",
        "status",
        "platform",
        "sequenceNumber",
        "fromCohortPercent",
        "targetCohortPercent",
        "evaluatedAtEpochSeconds",
        "authorizedAtEpochSeconds",
        "identity",
        "privacy",
        "priorReceiptSha256",
        "completedCohort",
        "blockingReasons",
    }
    exact_keys(value, expected_keys, "blocked rollout template")
    require_int(value["schemaVersion"], "schemaVersion", 3, 3)
    require_string(value["contractId"], "contractId", "sora-mobile-production-rollout-v3")
    require_string(value["status"], "status", "blocked-template")
    require_string(value["platform"], "platform", "ios")
    require_int(value["sequenceNumber"], "sequenceNumber", sequence, sequence)
    require_int(value["fromCohortPercent"], "fromCohortPercent", from_percent, from_percent)
    require_int(value["targetCohortPercent"], "targetCohortPercent", target_percent, target_percent)
    require_int(value["evaluatedAtEpochSeconds"], "evaluatedAtEpochSeconds", 0, 0)
    require_int(value["authorizedAtEpochSeconds"], "authorizedAtEpochSeconds", 0, 0)
    validate_identity(value["identity"], "identity", blocked=True)
    validate_privacy(value["privacy"])
    if value["priorReceiptSha256"] != prior:
        fail("blocked rollout template priorReceiptSha256 is not fail-closed")
    if value["completedCohort"] is not None:
        fail("blocked rollout template may not contain fabricated cohort evidence")
    if value["blockingReasons"] != [warning]:
        fail("blocked rollout template warning is not exact")


def validate_trust(value: dict[str, Any], qualified: bool) -> None:
    keys = {
        "schemaVersion",
        "contractId",
        "status",
        "releaseEnabled",
        "controllerId",
        "signatureAlgorithm",
        "publicKeySha256",
        "blockingReasons",
    }
    exact_keys(value, keys, "controller trust root")
    require_int(value["schemaVersion"], "schemaVersion", 1, 1)
    require_string(
        value["contractId"],
        "contractId",
        "sora-ios-production-rollout-controller-trust-v1",
    )
    require_string(value["signatureAlgorithm"], "signatureAlgorithm", "ecdsa-p256-sha256")
    if qualified:
        require_string(value["status"], "status", "qualified")
        require_bool(value["releaseEnabled"], "releaseEnabled", True)
        require_binding_string(value["controllerId"], "controllerId", maximum=256)
        require_hex64(value["publicKeySha256"], "publicKeySha256")
        if value["blockingReasons"] != []:
            fail("qualified controller trust root must have no blocking reasons")
    else:
        require_string(value["status"], "status", "blocked")
        require_bool(value["releaseEnabled"], "releaseEnabled", False)
        if value["controllerId"] is not None or value["publicKeySha256"] is not None:
            fail("blocked controller trust root may not contain fabricated identity or key evidence")
        expected = [
            "No reviewed production rollout controller public key has been supplied by the authorized release system."
        ]
        if value["blockingReasons"] != expected:
            fail("blocked controller trust root warning is not exact")


def validate_artifact(value: dict[str, Any], ipa_path: Path) -> None:
    keys = {
        "schemaVersion",
        "contractId",
        "status",
        "controllerId",
        "recordedAtEpochSeconds",
        "sourceRevision",
        "candidateBuildManifestSha256",
        "productionQualificationReceiptSha256",
        "ipa",
        "application",
        "signing",
        "runtime",
        "tairaDeployment",
        "privacy",
    }
    exact_keys(value, keys, "artifact identity receipt")
    require_int(value["schemaVersion"], "schemaVersion", 2, 2)
    require_string(value["contractId"], "contractId", "sora-ios-production-artifact-identity-v2")
    require_string(value["status"], "status", "qualified")
    require_binding_string(value["controllerId"], "controllerId", maximum=256)
    require_int(value["recordedAtEpochSeconds"], "recordedAtEpochSeconds", 1, 9_999_999_999)
    require_hex40(value["sourceRevision"], "sourceRevision")
    require_hex64(value["candidateBuildManifestSha256"], "candidateBuildManifestSha256")
    require_hex64(
        value["productionQualificationReceiptSha256"],
        "productionQualificationReceiptSha256",
    )
    validate_privacy(value["privacy"])
    if TAIRA_DEPLOYMENT is None:
        fail("artifact validation lacks an authenticated Taira deployment")
    taira_deployment = exact_keys(
        value["tairaDeployment"],
        {
            "manifestSha256", "admissionSha256", "currentChainId",
            "currentGenesisHash", "canonicalToriiBaseUrl",
            "publicMcpEndpoint",
        },
        "artifact Taira deployment",
    )
    for key in taira_deployment:
        require_string(
            taira_deployment[key],
            f"artifact.tairaDeployment.{key}",
            TAIRA_DEPLOYMENT[key],
            maximum=2_060,
        )

    ipa = exact_keys(
        value["ipa"],
        {
            "sha256",
            "bytes",
            "zipEntryCount",
            "uncompressedBytes",
            "zipStructureQualified",
            "singleApplicationBundleQualified",
            "infoPlistSha256",
            "executableSha256",
            "embeddedProvisioningProfileSha256",
        },
        "ipa",
    )
    expected_ipa_sha = require_hex64(ipa["sha256"], "ipa.sha256")
    expected_ipa_bytes = require_int(ipa["bytes"], "ipa.bytes", 1, 4_294_967_296)
    expected_entry_count = require_int(ipa["zipEntryCount"], "ipa.zipEntryCount", 1, MAX_IPA_ENTRIES)
    expected_uncompressed = require_int(
        ipa["uncompressedBytes"],
        "ipa.uncompressedBytes",
        1,
        MAX_IPA_UNCOMPRESSED_BYTES,
    )
    require_bool(ipa["zipStructureQualified"], "ipa.zipStructureQualified", True)
    require_bool(
        ipa["singleApplicationBundleQualified"],
        "ipa.singleApplicationBundleQualified",
        True,
    )
    expected_info_sha = require_hex64(ipa["infoPlistSha256"], "ipa.infoPlistSha256")
    expected_executable_sha = require_hex64(ipa["executableSha256"], "ipa.executableSha256")
    expected_profile_sha = require_hex64(
        ipa["embeddedProvisioningProfileSha256"],
        "ipa.embeddedProvisioningProfileSha256",
    )

    application = exact_keys(
        value["application"],
        {
            "bundleIdentifier",
            "developmentTeam",
            "applicationIdentifier",
            "appVersion",
            "buildNumber",
            "appStoreBuildIdentifier",
        },
        "application",
    )
    require_string(application["bundleIdentifier"], "application.bundleIdentifier", BUNDLE_IDENTIFIER)
    require_string(application["developmentTeam"], "application.developmentTeam", DEVELOPMENT_TEAM)
    require_string(
        application["applicationIdentifier"],
        "application.applicationIdentifier",
        APPLICATION_IDENTIFIER,
    )
    expected_app_version = require_binding_string(application["appVersion"], "application.appVersion", maximum=128)
    expected_build_number = require_binding_string(application["buildNumber"], "application.buildNumber", maximum=128)
    require_binding_string(
        application["appStoreBuildIdentifier"],
        "application.appStoreBuildIdentifier",
        maximum=256,
    )

    signing = exact_keys(
        value["signing"],
        {
            "codesignVerified",
            "nestedCodeVerified",
            "provisioningProfileVerified",
            "distributionCertificateSha256",
            "provisioningProfileUuid",
            "provisioningProfileName",
            "inspectionToolSha256",
            "codesignEvidenceSha256",
            "provisioningEvidenceSha256",
            "sourceEntitlementsSha256",
            "signedEntitlementsSha256",
            "keychainAccessGroupsSha256",
            "applicationIdentifierContinuityReviewed",
            "archivedEntitlementsMatched",
            "keychainAccessGroupsUnchanged",
            "appStoreSigningContinuityReviewed",
        },
        "signing",
    )
    for key in {
        "codesignVerified",
        "nestedCodeVerified",
        "provisioningProfileVerified",
        "applicationIdentifierContinuityReviewed",
        "archivedEntitlementsMatched",
        "keychainAccessGroupsUnchanged",
        "appStoreSigningContinuityReviewed",
    }:
        require_bool(signing[key], f"signing.{key}", True)
    require_hex64(signing["distributionCertificateSha256"], "signing.distributionCertificateSha256")
    profile_uuid = require_string(signing["provisioningProfileUuid"], "signing.provisioningProfileUuid", maximum=64)
    if UUID.fullmatch(profile_uuid) is None:
        fail("signing.provisioningProfileUuid is not a UUID")
    require_string(signing["provisioningProfileName"], "signing.provisioningProfileName", maximum=512)
    require_hex64(signing["inspectionToolSha256"], "signing.inspectionToolSha256")
    require_hex64(signing["codesignEvidenceSha256"], "signing.codesignEvidenceSha256")
    require_hex64(signing["provisioningEvidenceSha256"], "signing.provisioningEvidenceSha256")
    require_string(
        signing["sourceEntitlementsSha256"],
        "signing.sourceEntitlementsSha256",
        SOURCE_ENTITLEMENTS_SHA256,
    )
    require_hex64(signing["signedEntitlementsSha256"], "signing.signedEntitlementsSha256")
    require_hex64(signing["keychainAccessGroupsSha256"], "signing.keychainAccessGroupsSha256")

    runtime = exact_keys(
        value["runtime"],
        {
            "sora2NetworkRevision",
            "runtimeSpecVersion",
            "runtimeTransactionVersion",
            "runtimeMetadataSha256",
            "embeddedRuntimeContractSha256",
        },
        "runtime",
    )
    require_string(runtime["sora2NetworkRevision"], "runtime.sora2NetworkRevision", SORA2_REVISION)
    require_int(runtime["runtimeSpecVersion"], "runtime.runtimeSpecVersion", 130, 130)
    require_int(runtime["runtimeTransactionVersion"], "runtime.runtimeTransactionVersion", 130, 130)
    require_string(
        runtime["runtimeMetadataSha256"],
        "runtime.runtimeMetadataSha256",
        RUNTIME_METADATA_SHA256,
    )
    require_hex64(runtime["embeddedRuntimeContractSha256"], "runtime.embeddedRuntimeContractSha256")

    if not ipa_path.is_absolute():
        fail("actual IPA path must be absolute")
    flags = os.O_RDONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        ipa_descriptor = os.open(ipa_path, flags)
    except OSError as error:
        fail(f"cannot open actual regular non-symlink IPA: {error}")
    try:
        before_ipa = os.fstat(ipa_descriptor)
        actual_ipa_bytes = before_ipa.st_size
        if not stat.S_ISREG(before_ipa.st_mode):
            fail("actual IPA is not a regular file")
        if actual_ipa_bytes <= 0 or actual_ipa_bytes > 4_294_967_296:
            fail("actual IPA is empty or exceeds the four-GiB qualification bound")
        with os.fdopen(os.dup(ipa_descriptor), "rb") as ipa_stream:
            digest = hashlib.sha256()
            while True:
                chunk = ipa_stream.read(1024 * 1024)
                if not chunk:
                    break
                digest.update(chunk)
            actual_ipa_sha = digest.hexdigest()
            if actual_ipa_bytes != expected_ipa_bytes or actual_ipa_sha != expected_ipa_sha:
                fail("artifact receipt does not bind the actual IPA bytes")
            ipa_stream.seek(0)
            with zipfile.ZipFile(ipa_stream, "r", allowZip64=True) as archive:
                infos = archive.infolist()
                if not infos or len(infos) > MAX_IPA_ENTRIES:
                    fail("IPA ZIP entry count is empty or unbounded")
                names: set[str] = set()
                total_uncompressed = 0
                for info in infos:
                    name = info.filename
                    if name in names:
                        fail(f"IPA contains a duplicate ZIP entry: {name}")
                    names.add(name)
                    parts = PurePosixPath(name).parts
                    if (
                        not name
                        or name.startswith("/")
                        or "\\" in name
                        or "\x00" in name
                        or any(part in {"", ".", ".."} for part in parts)
                        or info.flag_bits & 0x1
                    ):
                        fail(f"IPA contains an unsafe or encrypted ZIP entry: {name!r}")
                    mode = (info.external_attr >> 16) & 0xFFFF
                    if stat.S_IFMT(mode) == stat.S_IFLNK:
                        fail(f"IPA contains a symbolic-link entry: {name}")
                    if info.file_size < 0 or info.file_size > MAX_IPA_MEMBER_BYTES:
                        fail(f"IPA member exceeds its bounded size: {name}")
                    total_uncompressed += info.file_size
                    if total_uncompressed > MAX_IPA_UNCOMPRESSED_BYTES:
                        fail("IPA aggregate uncompressed size is unbounded")

                info_plists = [
                    info
                    for info in infos
                    if len(PurePosixPath(info.filename).parts) == 3
                    and PurePosixPath(info.filename).parts[0] == "Payload"
                    and PurePosixPath(info.filename).parts[1].endswith(".app")
                    and PurePosixPath(info.filename).parts[2] == "Info.plist"
                ]
                if len(info_plists) != 1:
                    fail("IPA must contain exactly one Payload/*.app/Info.plist")
                info_entry = info_plists[0]
                app_prefix = "/".join(PurePosixPath(info_entry.filename).parts[:2]) + "/"
                payload_apps = {
                    PurePosixPath(info.filename).parts[1]
                    for info in infos
                    if len(PurePosixPath(info.filename).parts) >= 2
                    and PurePosixPath(info.filename).parts[0] == "Payload"
                    and PurePosixPath(info.filename).parts[1].endswith(".app")
                }
                if len(payload_apps) != 1:
                    fail("IPA must contain exactly one top-level application bundle")
                info_bytes = bounded_zip_read(archive, info_entry, 16 * 1024 * 1024)
                try:
                    info_plist = plistlib.loads(info_bytes)
                except Exception as error:
                    fail(f"IPA Info.plist cannot be decoded: {error}")
                if type(info_plist) is not dict:
                    fail("IPA Info.plist must contain a dictionary")
                if info_plist.get("CFBundleIdentifier") != BUNDLE_IDENTIFIER:
                    fail("IPA CFBundleIdentifier is not the preserved production identifier")
                if info_plist.get("CFBundleShortVersionString") != expected_app_version:
                    fail("artifact receipt app version differs from IPA Info.plist")
                if info_plist.get("CFBundleVersion") != expected_build_number:
                    fail("artifact receipt build number differs from IPA Info.plist")
                embedded_taira = {
                    "manifestSha256": info_plist.get(
                        "SoraTairaDeploymentManifestSha256"
                    ),
                    "admissionSha256": info_plist.get(
                        "SoraTairaDeploymentAdmissionSha256"
                    ),
                    "currentChainId": info_plist.get(
                        "SoraTairaCurrentChainId"
                    ),
                    "currentGenesisHash": info_plist.get(
                        "SoraTairaCurrentGenesisHash"
                    ),
                    "canonicalToriiBaseUrl": info_plist.get(
                        "SoraTairaCanonicalToriiBaseUrl"
                    ),
                    "publicMcpEndpoint": info_plist.get(
                        "SoraTairaPublicMcpEndpoint"
                    ),
                }
                if embedded_taira != taira_deployment:
                    fail(
                        "artifact receipt Taira deployment differs from the signed IPA"
                    )
                executable_name = info_plist.get("CFBundleExecutable")
                if (
                    type(executable_name) is not str
                    or not executable_name
                    or len(executable_name) > 255
                    or "/" in executable_name
                    or "\\" in executable_name
                    or executable_name in {".", ".."}
                ):
                    fail("IPA CFBundleExecutable is unsafe")
                executable_path = app_prefix + executable_name
                profile_path = app_prefix + "embedded.mobileprovision"
                try:
                    executable_entry = archive.getinfo(executable_path)
                    profile_entry = archive.getinfo(profile_path)
                except KeyError as error:
                    fail(f"IPA lacks required signed application content: {error}")
                executable_bytes = bounded_zip_read(archive, executable_entry, MAX_EXECUTABLE_BYTES)
                profile_bytes = bounded_zip_read(archive, profile_entry, 32 * 1024 * 1024)
        after_ipa = os.fstat(ipa_descriptor)
        before_identity = (
            before_ipa.st_dev,
            before_ipa.st_ino,
            before_ipa.st_size,
            before_ipa.st_mtime_ns,
            before_ipa.st_ctime_ns,
        )
        after_identity = (
            after_ipa.st_dev,
            after_ipa.st_ino,
            after_ipa.st_size,
            after_ipa.st_mtime_ns,
            after_ipa.st_ctime_ns,
        )
        if before_identity != after_identity:
            fail("actual IPA changed while its bounded structure was inspected")
        rebound = os.stat(ipa_path, follow_symlinks=False)
        if not stat.S_ISREG(rebound.st_mode) or (
            rebound.st_dev,
            rebound.st_ino,
        ) != (
            before_ipa.st_dev,
            before_ipa.st_ino,
        ):
            fail("actual IPA path was rebound during qualification")
    except (OSError, zipfile.BadZipFile, zipfile.LargeZipFile) as error:
        fail(f"IPA ZIP structure is invalid: {error}")
    finally:
        os.close(ipa_descriptor)

    if len(infos) != expected_entry_count or total_uncompressed != expected_uncompressed:
        fail("artifact receipt ZIP inventory differs from the actual IPA")
    if hashlib.sha256(info_bytes).hexdigest() != expected_info_sha:
        fail("artifact receipt Info.plist hash differs from the actual IPA")
    if hashlib.sha256(executable_bytes).hexdigest() != expected_executable_sha:
        fail("artifact receipt executable hash differs from the actual IPA")
    if hashlib.sha256(profile_bytes).hexdigest() != expected_profile_sha:
        fail("artifact receipt provisioning profile hash differs from the actual IPA")


def bounded_zip_read(archive: zipfile.ZipFile, info: zipfile.ZipInfo, maximum: int) -> bytes:
    if info.file_size <= 0 or info.file_size > maximum:
        fail(f"IPA member {info.filename} is empty or exceeds its read bound")
    with archive.open(info, "r") as stream:
        data = stream.read(maximum + 1)
    if len(data) != info.file_size or len(data) > maximum:
        fail(f"IPA member {info.filename} changed size while being decoded")
    return data


def secure_file_sha256(path_text: str, maximum_bytes: int) -> str:
    path = Path(path_text)
    if not path.is_absolute():
        fail("hashed file path must be absolute")
    flags = os.O_RDONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        descriptor = os.open(path, flags)
    except OSError as error:
        fail(f"cannot open regular non-symlink file {path}: {error}")
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode):
            fail(f"hashed path is not a regular file: {path}")
        if before.st_size <= 0 or before.st_size > maximum_bytes:
            fail(f"hashed file is empty or exceeds its bound: {path}")
        digest = hashlib.sha256()
        observed = 0
        while True:
            chunk = os.read(descriptor, min(1024 * 1024, maximum_bytes + 1 - observed))
            if not chunk:
                break
            digest.update(chunk)
            observed += len(chunk)
            if observed > maximum_bytes:
                fail(f"hashed file exceeds its bound: {path}")
        after = os.fstat(descriptor)
        before_identity = (
            before.st_dev,
            before.st_ino,
            before.st_size,
            before.st_mtime_ns,
            before.st_ctime_ns,
        )
        after_identity = (
            after.st_dev,
            after.st_ino,
            after.st_size,
            after.st_mtime_ns,
            after.st_ctime_ns,
        )
        if observed != before.st_size or before_identity != after_identity:
            fail(f"hashed file changed while it was read: {path}")
        return digest.hexdigest()
    finally:
        os.close(descriptor)


def snapshot_stable_file(source_text: str, destination_text: str, maximum_bytes: int) -> str:
    destination = Path(destination_text)
    if not destination.is_absolute():
        fail("snapshot destination path must be absolute")
    raw = read_stable_regular_file(source_text, maximum_bytes)
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        descriptor = os.open(destination, flags, 0o400)
    except OSError as error:
        fail(f"cannot create private evidence snapshot {destination}: {error}")
    try:
        offset = 0
        while offset < len(raw):
            written = os.write(descriptor, raw[offset:])
            if written <= 0:
                fail(f"cannot complete private evidence snapshot {destination}")
            offset += written
        os.fchmod(descriptor, 0o400)
        os.fsync(descriptor)
        observed = os.fstat(descriptor)
        if not stat.S_ISREG(observed.st_mode) or observed.st_size != len(raw):
            fail(f"private evidence snapshot is incomplete: {destination}")
    finally:
        os.close(descriptor)
    return hashlib.sha256(raw).hexdigest()


def validate_qualification(value: dict[str, Any]) -> None:
    keys = {
        "schemaVersion",
        "contractId",
        "status",
        "controllerId",
        "recordedAtEpochSeconds",
        "sourceRevision",
        "candidateBuildManifestSha256",
        "qualificationEvidenceManifestSha256",
        "releaseConfiguration",
        "hardGates",
        "privacy",
    }
    exact_keys(value, keys, "production qualification receipt")
    require_int(value["schemaVersion"], "schemaVersion", 2, 2)
    require_string(value["contractId"], "contractId", "sora-ios-production-qualification-v2")
    require_string(value["status"], "status", "qualified")
    require_binding_string(value["controllerId"], "controllerId", maximum=256)
    require_int(value["recordedAtEpochSeconds"], "recordedAtEpochSeconds", 1, 9_999_999_999)
    require_hex40(value["sourceRevision"], "sourceRevision")
    require_hex64(value["candidateBuildManifestSha256"], "candidateBuildManifestSha256")
    require_hex64(
        value["qualificationEvidenceManifestSha256"],
        "qualificationEvidenceManifestSha256",
    )
    require_string(value["releaseConfiguration"], "releaseConfiguration", "Release")
    gates = exact_keys(
        value["hardGates"],
        {
            "walletMigrationQualified",
            "sora2Runtime130Qualified",
            "minamotoSendQualified",
            "tairaSendQualified",
            "piIndexerQualified",
            "polkamarktQualified",
            "dependencyProvenanceQualified",
            "productionSignerQualified",
            "nativeCanaryQualified",
            "productionSigningQualified",
            "privacyTelemetryQualified",
        },
        "hardGates",
    )
    for key, gate in gates.items():
        require_bool(gate, f"hardGates.{key}", True)
    validate_privacy(value["privacy"])


def validate_checkpoint(
    value: Any,
    path: str,
    *,
    network_id: str,
    chain_id: str,
    torii: str,
    discriminant: int,
) -> None:
    checkpoint = exact_keys(
        value,
        {
            "networkId",
            "chainId",
            "toriiEndpoint",
            "i105Discriminant",
            "genesisHash",
            "finalizedHeight",
            "finalizedBlockHash",
            "canonicalToriiMatched",
        },
        path,
    )
    require_string(checkpoint["networkId"], f"{path}.networkId", network_id)
    require_string(checkpoint["chainId"], f"{path}.chainId", chain_id)
    require_string(checkpoint["toriiEndpoint"], f"{path}.toriiEndpoint", torii)
    require_int(checkpoint["i105Discriminant"], f"{path}.i105Discriminant", discriminant, discriminant)
    require_hex64(checkpoint["genesisHash"], f"{path}.genesisHash")
    require_int(checkpoint["finalizedHeight"], f"{path}.finalizedHeight", 1)
    require_hex64(checkpoint["finalizedBlockHash"], f"{path}.finalizedBlockHash")
    require_bool(checkpoint["canonicalToriiMatched"], f"{path}.canonicalToriiMatched", True)


def validate_pi(value: dict[str, Any]) -> None:
    keys = {
        "schemaVersion",
        "contractId",
        "status",
        "controllerId",
        "capturedAtEpochSeconds",
        "endpoint",
        "privacy",
        "health",
        "capabilities",
        "networkCheckpoints",
    }
    exact_keys(value, keys, "PI production probe receipt")
    require_int(value["schemaVersion"], "schemaVersion", 3, 3)
    require_string(value["contractId"], "contractId", "sora-pi-production-capability-probe-v3")
    require_string(value["status"], "status", "qualified")
    require_binding_string(value["controllerId"], "controllerId", maximum=256)
    require_int(value["capturedAtEpochSeconds"], "capturedAtEpochSeconds", 1, 9_999_999_999)
    require_string(value["endpoint"], "endpoint", "https://pi.soramitsu.io/graphql")
    validate_privacy(value["privacy"])
    health = exact_keys(
        value["health"],
        {
            "serviceId",
            "ecosystem",
            "chainId",
            "network",
            "readOnly",
            "workerReady",
            "genesisHash",
            "runtimeSpecVersion",
            "runtimeTransactionVersion",
            "runtimeMetadataSha256",
            "workerLatestFinalizedBlock",
            "workerLatestFinalizedBlockHash",
            "canonicalRpcFinalizedBlockHash",
            "workerLatestIndexedBlock",
            "workerLatestIndexedBlockHash",
            "workerLag",
            "workerLastSuccessfulIndexTimestamp",
            "canonicalRpcCheckpointMatched",
        },
        "health",
    )
    require_string(health["serviceId"], "health.serviceId", "pi.soramitsu.io")
    require_string(health["ecosystem"], "health.ecosystem", "sora2")
    require_string(health["chainId"], "health.chainId", "sora:mainnet")
    require_string(health["network"], "health.network", "mainnet")
    require_bool(health["readOnly"], "health.readOnly", True)
    require_bool(health["workerReady"], "health.workerReady", True)
    require_string(health["genesisHash"], "health.genesisHash", SORA2_GENESIS_HASH)
    require_int(health["runtimeSpecVersion"], "health.runtimeSpecVersion", 130, 130)
    require_int(health["runtimeTransactionVersion"], "health.runtimeTransactionVersion", 130, 130)
    require_string(
        health["runtimeMetadataSha256"],
        "health.runtimeMetadataSha256",
        RUNTIME_METADATA_SHA256,
    )
    finalized = require_int(health["workerLatestFinalizedBlock"], "health.workerLatestFinalizedBlock", 1)
    indexed = require_int(health["workerLatestIndexedBlock"], "health.workerLatestIndexedBlock", 1)
    lag = require_int(health["workerLag"], "health.workerLag", 0)
    finalized_hash = require_hex64(
        health["workerLatestFinalizedBlockHash"],
        "health.workerLatestFinalizedBlockHash",
    )
    canonical_hash = require_hex64(
        health["canonicalRpcFinalizedBlockHash"],
        "health.canonicalRpcFinalizedBlockHash",
    )
    indexed_hash = require_hex64(
        health["workerLatestIndexedBlockHash"],
        "health.workerLatestIndexedBlockHash",
    )
    require_int(
        health["workerLastSuccessfulIndexTimestamp"],
        "health.workerLastSuccessfulIndexTimestamp",
        1,
        9_999_999_999,
    )
    require_bool(
        health["canonicalRpcCheckpointMatched"],
        "health.canonicalRpcCheckpointMatched",
        True,
    )
    if finalized != indexed or lag != 0 or finalized_hash != canonical_hash or indexed_hash != finalized_hash:
        fail("PI finalized/indexed/canonical checkpoint is incoherent")

    capabilities = exact_keys(
        value["capabilities"],
        {
            "configRevision",
            "capturedAtEpochSeconds",
            "mobileConfigHealthBound",
            "historyBlockHeightContractDeployed",
            "nexusAvailable",
            "nexusSendsAvailable",
            "polkamarktVisible",
            "polkamarktMutationsAvailable",
            "tairaDefaultVisible",
        },
        "capabilities",
    )
    require_binding_string(capabilities["configRevision"], "capabilities.configRevision", maximum=256)
    if require_int(
        capabilities["capturedAtEpochSeconds"],
        "capabilities.capturedAtEpochSeconds",
        1,
        9_999_999_999,
    ) != value["capturedAtEpochSeconds"]:
        fail("PI mobileConfig capture is not atomic with the health probe")
    require_bool(
        capabilities["mobileConfigHealthBound"],
        "capabilities.mobileConfigHealthBound",
        True,
    )
    require_bool(
        capabilities["historyBlockHeightContractDeployed"],
        "capabilities.historyBlockHeightContractDeployed",
        True,
    )
    for key in {
        "nexusAvailable",
        "nexusSendsAvailable",
        "polkamarktVisible",
        "polkamarktMutationsAvailable",
        "tairaDefaultVisible",
    }:
        require_bool(capabilities[key], f"capabilities.{key}", True)

    checkpoints = exact_keys(
        value["networkCheckpoints"],
        {"minamoto", "taira"},
        "networkCheckpoints",
    )
    validate_checkpoint(
        checkpoints["minamoto"],
        "networkCheckpoints.minamoto",
        network_id="minamoto",
        chain_id="00000000-0000-0000-0000-000000000753",
        torii="https://minamoto.sora.org",
        discriminant=753,
    )
    if TAIRA_DEPLOYMENT is None:
        fail("PI Taira checkpoint lacks an authenticated deployment admission")
    validate_checkpoint(
        checkpoints["taira"],
        "networkCheckpoints.taira",
        network_id="taira",
        chain_id=TAIRA_DEPLOYMENT["currentChainId"],
        torii=TAIRA_DEPLOYMENT["canonicalToriiBaseUrl"],
        discriminant=369,
    )
    require_string(
        checkpoints["taira"]["genesisHash"],
        "networkCheckpoints.taira.genesisHash",
        TAIRA_DEPLOYMENT["currentGenesisHash"],
    )


def validate_rollout(value: dict[str, Any], target: int) -> None:
    transitions = {1: (1, 0), 5: (2, 1), 25: (3, 5), 100: (4, 25)}
    if target not in transitions:
        fail("rollout target must be 1, 5, 25, or 100")
    sequence, from_percent = transitions[target]
    keys = {
        "schemaVersion",
        "contractId",
        "status",
        "platform",
        "controllerId",
        "sequenceNumber",
        "fromCohortPercent",
        "targetCohortPercent",
        "evaluatedAtEpochSeconds",
        "authorizedAtEpochSeconds",
        "identity",
        "privacy",
        "priorReceiptSha256",
        "completedCohort",
        "blockingReasons",
    }
    exact_keys(value, keys, "rollout qualification receipt")
    require_int(value["schemaVersion"], "schemaVersion", 3, 3)
    require_string(value["contractId"], "contractId", "sora-mobile-production-rollout-v3")
    require_string(value["status"], "status", "qualified")
    require_string(value["platform"], "platform", "ios")
    require_binding_string(value["controllerId"], "controllerId", maximum=256)
    require_int(value["sequenceNumber"], "sequenceNumber", sequence, sequence)
    require_int(value["fromCohortPercent"], "fromCohortPercent", from_percent, from_percent)
    require_int(value["targetCohortPercent"], "targetCohortPercent", target, target)
    evaluated_at = require_int(
        value["evaluatedAtEpochSeconds"],
        "evaluatedAtEpochSeconds",
        1,
        9_999_999_999,
    )
    authorized_at = require_int(
        value["authorizedAtEpochSeconds"],
        "authorizedAtEpochSeconds",
        1,
        9_999_999_999,
    )
    if (
        authorized_at < evaluated_at
        or authorized_at - evaluated_at > MAXIMUM_AUTHORIZATION_DELAY_SECONDS
    ):
        fail("rollout authorization must follow evaluation by no more than 30 seconds")
    validate_identity(value["identity"], "identity", blocked=False)
    validate_privacy(value["privacy"])
    if value["blockingReasons"] != []:
        fail("qualified rollout receipt may not contain blocking reasons")
    if target == 1:
        if value["priorReceiptSha256"] is not None or value["completedCohort"] is not None:
            fail("target 1 must have no prior receipt or fabricated cohort evidence")
    else:
        require_hex64(value["priorReceiptSha256"], "priorReceiptSha256")
        validate_completed_cohort(value["completedCohort"], from_percent)
        cohort = value["completedCohort"]
        if cohort["candidateBindingSha256"] != value["identity"]["candidateBindingSha256"]:
            fail("completed cohort is bound to a different candidate")
        if cohort["endedAtEpochSeconds"] > evaluated_at:
            fail("completed cohort ends after rollout evaluation")


def validate_completed_cohort(value: Any, expected_percent: int) -> None:
    cohort = exact_keys(
        value,
        {
            "cohortPercent",
            "startedAtEpochSeconds",
            "endedAtEpochSeconds",
            "candidateBindingSha256",
            "distributionPlatformAttestationSha256",
            "telemetryAttestationSha256",
            "telemetry",
        },
        "completedCohort",
    )
    require_int(cohort["cohortPercent"], "completedCohort.cohortPercent", expected_percent, expected_percent)
    started_at = require_int(
        cohort["startedAtEpochSeconds"],
        "completedCohort.startedAtEpochSeconds",
        1,
        9_999_999_999,
    )
    ended_at = require_int(
        cohort["endedAtEpochSeconds"],
        "completedCohort.endedAtEpochSeconds",
        1,
        9_999_999_999,
    )
    if ended_at < started_at:
        fail("completed cohort ends before it starts")
    require_hex64(cohort["candidateBindingSha256"], "completedCohort.candidateBindingSha256")
    require_hex64(
        cohort["distributionPlatformAttestationSha256"],
        "completedCohort.distributionPlatformAttestationSha256",
    )
    require_hex64(
        cohort["telemetryAttestationSha256"],
        "completedCohort.telemetryAttestationSha256",
    )
    validate_telemetry_payload(cohort["telemetry"], "completedCohort.telemetry")


def validate_telemetry_payload(value: Any, path: str) -> dict[str, Any]:
    telemetry = exact_keys(
        value,
        {
            "datasetSha256",
            "telemetryCompletenessQualified",
            "outcomesMutuallyExclusiveQualified",
            "eligibleDevices",
            "reportingDevices",
            "upgradedWalletsObserved",
            "accountsObserved",
            "confirmedMissingWalletEvents",
            "confirmedMissingAccountEvents",
            "addressMismatchEvents",
            "signatureMismatchEvents",
            "crossNetworkRoutingEvents",
            "terminalTransactionsObserved",
            "terminalSuccessEvents",
            "excludedUserCancellationEvents",
            "excludedInsufficientFundsEvents",
            "eligibleTerminalTransactionsObserved",
            "eligibleTerminalFailureEvents",
        },
        path,
    )
    require_hex64(telemetry["datasetSha256"], f"{path}.datasetSha256")
    require_bool(
        telemetry["telemetryCompletenessQualified"],
        f"{path}.telemetryCompletenessQualified",
        True,
    )
    require_bool(
        telemetry["outcomesMutuallyExclusiveQualified"],
        f"{path}.outcomesMutuallyExclusiveQualified",
        True,
    )
    counters: dict[str, int] = {}
    for key in set(telemetry.keys()) - {
        "datasetSha256",
        "telemetryCompletenessQualified",
        "outcomesMutuallyExclusiveQualified",
    }:
        counters[key] = require_int(telemetry[key], f"{path}.{key}")
    if counters["eligibleDevices"] <= 0 or counters["reportingDevices"] != counters["eligibleDevices"]:
        fail("telemetry does not attest complete reporting-device coverage")
    if (
        counters["upgradedWalletsObserved"] <= 0
        or counters["accountsObserved"] < counters["upgradedWalletsObserved"]
    ):
        fail("telemetry lacks coherent nonzero wallet/account observations")
    for key in {
        "confirmedMissingWalletEvents",
        "confirmedMissingAccountEvents",
        "addressMismatchEvents",
        "signatureMismatchEvents",
        "crossNetworkRoutingEvents",
    }:
        if counters[key] != 0:
            fail(f"rollout hard-stop counter is nonzero: {key}")
    terminal = counters["terminalTransactionsObserved"]
    success = counters["terminalSuccessEvents"]
    cancellation = counters["excludedUserCancellationEvents"]
    insufficient = counters["excludedInsufficientFundsEvents"]
    eligible = counters["eligibleTerminalTransactionsObserved"]
    failures = counters["eligibleTerminalFailureEvents"]
    if terminal <= 0 or eligible <= 0:
        fail("telemetry lacks nonzero terminal and eligible outcomes")
    if terminal != success + cancellation + insufficient + failures:
        fail("terminal outcome classes are not exact, disjoint, and exhaustive")
    if eligible != success + failures:
        fail("eligible terminal outcome count is inconsistent")
    if failures * 100 > eligible:
        fail("eligible terminal transaction failure rate is above one percent")
    return telemetry


def validate_distribution_attestation(value: dict[str, Any]) -> None:
    keys = {
        "schemaVersion",
        "contractId",
        "status",
        "controllerId",
        "candidateBindingSha256",
        "cohortPercent",
        "startedAtEpochSeconds",
        "endedAtEpochSeconds",
        "appStoreBuildIdentifier",
        "cohortAssignmentQualified",
        "privacy",
    }
    exact_keys(value, keys, "distribution platform attestation")
    require_int(value["schemaVersion"], "schemaVersion", 1, 1)
    require_string(
        value["contractId"],
        "contractId",
        "sora-ios-distribution-cohort-attestation-v1",
    )
    require_string(value["status"], "status", "qualified")
    require_binding_string(value["controllerId"], "controllerId", maximum=256)
    require_hex64(value["candidateBindingSha256"], "candidateBindingSha256")
    require_int(value["cohortPercent"], "cohortPercent", 1, 25)
    require_int(value["startedAtEpochSeconds"], "startedAtEpochSeconds", 1, 9_999_999_999)
    require_int(value["endedAtEpochSeconds"], "endedAtEpochSeconds", 1, 9_999_999_999)
    require_string(value["appStoreBuildIdentifier"], "appStoreBuildIdentifier", maximum=256)
    require_bool(value["cohortAssignmentQualified"], "cohortAssignmentQualified", True)
    validate_privacy(value["privacy"])


def validate_telemetry_attestation(value: dict[str, Any]) -> None:
    keys = {
        "schemaVersion",
        "contractId",
        "status",
        "controllerId",
        "candidateBindingSha256",
        "cohortPercent",
        "capturedAtEpochSeconds",
        "telemetry",
        "privacy",
    }
    exact_keys(value, keys, "telemetry attestation")
    require_int(value["schemaVersion"], "schemaVersion", 1, 1)
    require_string(
        value["contractId"],
        "contractId",
        "sora-ios-rollout-telemetry-attestation-v1",
    )
    require_string(value["status"], "status", "qualified")
    require_binding_string(value["controllerId"], "controllerId", maximum=256)
    require_hex64(value["candidateBindingSha256"], "candidateBindingSha256")
    require_int(value["cohortPercent"], "cohortPercent", 1, 25)
    require_int(value["capturedAtEpochSeconds"], "capturedAtEpochSeconds", 1, 9_999_999_999)
    validate_telemetry_payload(value["telemetry"], "telemetry")
    validate_privacy(value["privacy"])


def validate_attestation_match(
    rollout: dict[str, Any],
    telemetry: dict[str, Any],
    distribution: dict[str, Any],
    target: int,
) -> None:
    validate_rollout(rollout, target)
    validate_telemetry_attestation(telemetry)
    validate_distribution_attestation(distribution)
    cohort = rollout["completedCohort"]
    if cohort is None:
        fail("attestation matching is invalid for target 1")
    expected = {
        "controllerId": rollout["controllerId"],
        "candidateBindingSha256": rollout["identity"]["candidateBindingSha256"],
        "cohortPercent": rollout["fromCohortPercent"],
    }
    for key, expected_value in expected.items():
        if telemetry[key] != expected_value or distribution[key] != expected_value:
            fail(f"external cohort attestation differs from rollout receipt: {key}")
    if telemetry["capturedAtEpochSeconds"] != cohort["endedAtEpochSeconds"]:
        fail("telemetry attestation capture does not equal completed cohort end")
    if (
        distribution["startedAtEpochSeconds"] != cohort["startedAtEpochSeconds"]
        or distribution["endedAtEpochSeconds"] != cohort["endedAtEpochSeconds"]
    ):
        fail("distribution attestation dwell differs from rollout receipt")
    if telemetry["telemetry"] != cohort["telemetry"]:
        fail("telemetry attestation counters differ from rollout receipt")
    if distribution["appStoreBuildIdentifier"] != rollout["identity"]["appStoreBuildIdentifier"]:
        fail("distribution attestation names a different App Store build")


def main(argv: list[str]) -> int:
    try:
        if len(argv) < 2:
            fail("missing validator mode")
        mode = argv[1]
        if mode == "templates" and len(argv) == 5:
            validate_blocked_rollout(
                load_json(argv[2]),
                sequence=1,
                from_percent=0,
                target_percent=1,
                warning=(
                    "Template only: a reviewed post-export release controller must bind the actual signed IPA, "
                    "upstream qualification, and fresh PI checkpoint; never infer or fabricate candidate evidence."
                ),
                prior=None,
            )
            validate_blocked_rollout(
                load_json(argv[3]),
                sequence=2,
                from_percent=1,
                target_percent=5,
                warning=(
                    "Template only: append only a controller-signed prior gate, distribution attestation, and "
                    "complete aggregate telemetry after the prior cohort dwell; never infer or fabricate evidence."
                ),
                prior="UNAVAILABLE",
            )
            trust = load_json(argv[4])
            trust_status = trust.get("status")
            if trust_status == "blocked":
                validate_trust(trust, qualified=False)
            elif trust_status == "qualified":
                validate_trust(trust, qualified=True)
            else:
                fail("controller trust root status must be blocked or qualified")
        elif mode == "trust" and len(argv) == 3:
            validate_trust(load_json(argv[2]), qualified=True)
        elif mode == "artifact" and len(argv) == 5:
            configure_authenticated_taira(argv[4])
            validate_artifact(load_json(argv[2]), Path(argv[3]))
        elif mode == "qualification" and len(argv) == 3:
            validate_qualification(load_json(argv[2]))
        elif mode == "pi" and len(argv) == 4:
            configure_authenticated_taira(argv[3])
            validate_pi(load_json(argv[2]))
        elif mode == "rollout" and len(argv) == 5:
            configure_authenticated_taira(argv[4])
            validate_rollout(load_json(argv[2]), int(argv[3]))
        elif mode == "attestations" and len(argv) == 7:
            configure_authenticated_taira(argv[6])
            validate_attestation_match(
                load_json(argv[2]),
                load_json(argv[3]),
                load_json(argv[4]),
                int(argv[5]),
            )
        elif mode == "hash" and len(argv) == 4:
            maximum = int(argv[3])
            if maximum <= 0:
                fail("hash byte bound must be positive")
            print(secure_file_sha256(argv[2], maximum))
        elif mode == "snapshot" and len(argv) == 5:
            maximum = int(argv[4])
            if maximum <= 0:
                fail("snapshot byte bound must be positive")
            print(snapshot_stable_file(argv[2], argv[3], maximum))
        else:
            fail("invalid validator mode or argument count")
    except (ValidationError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
