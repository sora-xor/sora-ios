#!/usr/bin/env python3
"""Strict JSON and cross-evidence validation for funded iOS Nexus canaries.

Cryptographic P-256 signature verification and stable private snapshots are
performed by verify-funded-nexus-canary.sh. This helper rejects ambiguous JSON,
validates every exact schema, recomputes bindings, and compares the actual IPA
and evidence bytes rather than trusting paths or receipt-provided digests.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import stat
import sys
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import urlsplit


MAX_JSON_BYTES = 262_144
MAX_IPA_BYTES = 4_294_967_296
MAX_SAFE_INTEGER = 9_007_199_254_740_991
MAX_STRING_CHARACTERS = 256
MAX_BLOCKING_REASONS = 16
MAX_BLOCKING_REASON_CHARACTERS = 240
MAX_CANARY_DURATION_SECONDS = 2 * 60 * 60
MAX_CANARY_AGE_SECONDS = 7 * 24 * 60 * 60
MAX_RECORD_DELAY_SECONDS = 24 * 60 * 60
MAX_PI_AGE_AT_START_SECONDS = 5 * 60
MAX_FUTURE_SKEW_SECONDS = 30

SORA2_REVISION = "411dcdb70c5c00b21482a44d02334840d5f338c6"
SORA2_GENESIS = "7e4e32d0feafd4f9c9414b0be86373f9a1efa904809b683453a9af6856d38ad5"
RUNTIME_METADATA_SHA256 = "2b49c3cbf682d8b88985a04a60a958de3ef5de77d282c3622bdae53f7e4fbabf"
RUNTIME_TYPES_SHA256 = "e87760d7a566d1b1b3d21a1e76ad70990fd54e14e6af3ba27dd4440461063601"
BUNDLE_IDENTIFIER = "co.jp.soramitsu.sora"
DEVELOPMENT_TEAM = "YLWWUD25VZ"
ATTESTATION_ROUTE = "/v1/bridge/finality/attestation/{height}"
BUNDLE_ROUTE = "/v1/bridge/finality/bundle/{height}"

HEX_64 = re.compile(r"^[0-9a-f]{64}$")
HEX_40 = re.compile(r"^[0-9a-f]{40}$")
SAFE_IDENTIFIER = re.compile(r"^[a-z0-9][a-z0-9._:-]{2,127}$")
CANONICAL_QUANTITY = re.compile(r"^(?:0|[1-9][0-9]*)(?:\.[0-9]*[1-9])?$")
CONTROL_CHARACTERS = re.compile(r"[\u0000-\u001f\u007f-\u009f]")

NETWORKS = {
    "taira": {
        # Blocked-template placeholder only. Qualified mode replaces every
        # Taira identity below from the freshly authenticated admission.
        "chainId": "UNAVAILABLE",
        "i105Discriminant": 369,
        "toriiBaseUrl": "UNAVAILABLE",
        "explorerBaseUrl": "https://taira-explorer.sora.org",
        "isTestnet": True,
    },
    "minamoto": {
        "chainId": "00000000-0000-0000-0000-000000000753",
        "i105Discriminant": 753,
        "toriiBaseUrl": "https://minamoto.sora.org",
        "explorerBaseUrl": "https://minamoto-explorer.sora.org",
        "isTestnet": False,
    },
}
TAIRA_KNOWN_CHAIN_IDS = {
    "809574f5-fee7-5e69-bfcf-52451e42d50f",
    "fc56984b-2be7-431d-840e-21514d1883f0",
}
TAIRA_DEPLOYMENT: dict[str, Any] | None = None

PRIVACY_KEYS = {
    "redactedAggregateEvidenceOnly",
    "accountIdentifiersIncluded",
    "addressesIncluded",
    "transactionIdentifiersIncluded",
    "phrasesOrSeedsIncluded",
    "privateKeysIncluded",
    "rawSignedPayloadsIncluded",
    "rawNetworkResponsesIncluded",
    "deviceIdentifiersIncluded",
    "operatorNamesIncluded",
}

STAGE_ASSERTIONS = {
    "receive": {
        "networkScopedAddressValidated": True,
        "discriminantValidated": True,
        "fundedXorObserved": True,
    },
    "sendValidation": {
        "recipientNetworkValidated": True,
        "amountPrecisionValidated": True,
        "xorBalanceValidated": True,
        "xorFeeBalanceValidated": True,
    },
    "fee": {
        "positiveFeeObserved": True,
        "feeBoundToCanonicalPayload": True,
        "feeRevalidatedBeforeSigning": True,
    },
    "signing": {
        "candidateSignerBindingMatched": True,
        "oneUseReservationMatched": True,
        "osSecuredSigningObserved": True,
        "privateKeyExportObserved": False,
        "selectedWalletRevalidated": True,
        "selectedNetworkRevalidated": True,
        "selectedAccountRevalidated": True,
        "walletDeletionInactive": True,
        "liveFeatureFlagsRevalidated": True,
        "quoteIdentityRevalidated": True,
    },
    "submission": {
        "singleHandoffObserved": True,
        "oneUseReservationMatched": True,
        "localHashMatchedToriiReceipt": True,
        "durablePendingJournalObserved": True,
        "selectedNetworkRevalidated": True,
        "selectedAccountRevalidated": True,
        "walletDeletionInactive": True,
        "liveFeatureFlagsRevalidated": True,
        "exactSignedPayloadHandoffObserved": True,
        "failureClassification": "none",
    },
    "terminalStatusReadback": {
        "exactHashStatusQueried": True,
        "committedTerminalStatusObserved": True,
        "globalStateResolutionObserved": True,
        "positiveCommittedBlockHeightObserved": True,
    },
    "finalityReadback": {
        "freshChallengeBoundAttestationVerified": True,
        "canonicalNoritoRoundTripVerified": True,
        "attestationRouteMatched": True,
        "bundleRouteMatched": True,
        "reviewedVerifierBindingMatched": True,
        "trustedContextReceiptMatched": True,
        "genesisAndTipProofsVerified": True,
        "nodeAndAggregateSignaturesVerified": True,
        "singleStateViewVerified": True,
        "liveBoundedSequentialStatefulSuccessorChainVerified": True,
        "receiptBlockReadBack": True,
    },
    "balanceReadback": {
        "senderDeltaReconciled": True,
        "receiverDeltaReconciled": True,
        "feeDeltaReconciled": True,
    },
    "explorerReconciliation": {
        "networkScopedExplorerUsed": True,
        "committedTransactionObserved": True,
    },
    "historyReconciliation": {
        "completeFanoutObserved": True,
        "exactTransactionObservedOnce": True,
        "networkAssetAmountDirectionMatched": True,
    },
    "restartRecovery": {
        "coldRestartPerformed": True,
        "statusOnlyRecoveryObserved": True,
        "readOnlyCapabilityBoundaryObserved": True,
        "signingDuringRecoveryObserved": False,
        "resubmissionDuringRecoveryObserved": False,
    },
}
STAGE_NAMES = tuple(STAGE_ASSERTIONS.keys())


class ValidationError(Exception):
    pass


def fail(message: str) -> None:
    raise ValidationError(message)


def strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, child in pairs:
        if key in value:
            fail(f"duplicate JSON key after escape decoding: {key}")
        value[key] = child
    return value


def reject_float(token: str) -> Any:
    fail(f"floating-point JSON number is forbidden: {token}")


def reject_constant(token: str) -> Any:
    fail(f"non-finite JSON number is forbidden: {token}")


def parse_integer(token: str) -> int:
    if token == "-0":
        fail("non-canonical negative-zero JSON integer is forbidden")
    value = int(token)
    if abs(value) > MAX_SAFE_INTEGER:
        fail("JSON integer exceeds the exact safe-integer bound")
    return value


def read_regular(path_text: str, maximum_bytes: int) -> bytes:
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
            fail(f"input is not a regular file: {path}")
        if before.st_size <= 0 or before.st_size > maximum_bytes:
            fail(f"input is empty or exceeds its byte bound: {path}")
        chunks: list[bytes] = []
        observed = 0
        while True:
            chunk = os.read(descriptor, min(1024 * 1024, maximum_bytes + 1 - observed))
            if not chunk:
                break
            chunks.append(chunk)
            observed += len(chunk)
            if observed > maximum_bytes:
                fail(f"input exceeds its byte bound: {path}")
        after = os.fstat(descriptor)
        before_identity = (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns)
        after_identity = (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns)
        if observed != before.st_size or before_identity != after_identity:
            fail(f"input changed while it was read: {path}")
        rebound = os.stat(path, follow_symlinks=False)
        if not stat.S_ISREG(rebound.st_mode) or (rebound.st_dev, rebound.st_ino) != (before.st_dev, before.st_ino):
            fail(f"input path was rebound while it was read: {path}")
        return b"".join(chunks)
    finally:
        os.close(descriptor)


def hash_regular(path_text: str, maximum_bytes: int) -> tuple[str, int]:
    path = Path(path_text)
    if not path.is_absolute():
        fail(f"hashed input path must be absolute: {path}")
    flags = os.O_RDONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        descriptor = os.open(path, flags)
    except OSError as error:
        fail(f"cannot open regular non-symlink file {path}: {error}")
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode) or before.st_size <= 0 or before.st_size > maximum_bytes:
            fail(f"hashed input is not one bounded regular file: {path}")
        digest = hashlib.sha256()
        observed = 0
        while True:
            chunk = os.read(descriptor, min(1024 * 1024, maximum_bytes + 1 - observed))
            if not chunk:
                break
            digest.update(chunk)
            observed += len(chunk)
            if observed > maximum_bytes:
                fail(f"hashed input exceeds its byte bound: {path}")
        after = os.fstat(descriptor)
        before_identity = (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns)
        after_identity = (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns)
        if observed != before.st_size or before_identity != after_identity:
            fail(f"hashed input changed while it was read: {path}")
        rebound = os.stat(path, follow_symlinks=False)
        if not stat.S_ISREG(rebound.st_mode) or (rebound.st_dev, rebound.st_ino) != (before.st_dev, before.st_ino):
            fail(f"hashed input path was rebound while it was read: {path}")
        return digest.hexdigest(), observed
    finally:
        os.close(descriptor)


def validate_tree(value: Any, path: str = "$", string_limit: int = MAX_STRING_CHARACTERS) -> None:
    if type(value) is str:
        if len(value) > string_limit or CONTROL_CHARACTERS.search(value):
            fail(f"{path} contains an overlong string or decoded control character")
    elif type(value) is int:
        if abs(value) > MAX_SAFE_INTEGER:
            fail(f"{path} exceeds the safe-integer bound")
    elif type(value) is list:
        if len(value) > 64:
            fail(f"{path} contains an unbounded array")
        for index, child in enumerate(value):
            validate_tree(child, f"{path}[{index}]", string_limit)
    elif type(value) is dict:
        if len(value) > 128:
            fail(f"{path} contains an unbounded object")
        for key, child in value.items():
            if CONTROL_CHARACTERS.search(key) or len(key) > 128:
                fail(f"{path} contains an unsafe key")
            validate_tree(child, f"{path}.{key}", string_limit)
    elif value is not None and type(value) is not bool:
        fail(f"{path} contains an unsupported JSON value")


def load_json_record(
    path_text: str,
    maximum_bytes: int = MAX_JSON_BYTES,
    *,
    string_limit: int = MAX_STRING_CHARACTERS,
) -> tuple[dict[str, Any], bytes]:
    raw = read_regular(path_text, maximum_bytes)
    try:
        text = raw.decode("utf-8", errors="strict")
    except UnicodeDecodeError as error:
        fail(f"JSON is not strict UTF-8: {error}")
    try:
        value = json.loads(
            text,
            object_pairs_hook=strict_object,
            parse_int=parse_integer,
            parse_float=reject_float,
            parse_constant=reject_constant,
        )
    except (json.JSONDecodeError, ValidationError) as error:
        fail(f"JSON is invalid or contains trailing data: {error}")
    if type(value) is not dict:
        fail("JSON must contain exactly one top-level object")
    validate_tree(value, string_limit=string_limit)
    return value, raw


def exact_keys(value: Any, expected: Iterable[str], path: str) -> dict[str, Any]:
    if type(value) is not dict:
        fail(f"{path} must be an object")
    expected_set = set(expected)
    actual = set(value.keys())
    if actual != expected_set:
        fail(f"{path} keys differ; missing={sorted(expected_set - actual)}, extra={sorted(actual - expected_set)}")
    return value


def require_bool(value: Any, path: str, expected: bool | None = None) -> bool:
    if type(value) is not bool:
        fail(f"{path} must be a boolean")
    if expected is not None and value is not expected:
        fail(f"{path} must be {str(expected).lower()}")
    return value


def require_int(value: Any, path: str, minimum: int = 0, maximum: int = MAX_SAFE_INTEGER) -> int:
    if type(value) is not int or value < minimum or value > maximum:
        fail(f"{path} must be an integer in [{minimum}, {maximum}]")
    return value


def require_string(value: Any, path: str, expected: str | None = None) -> str:
    if type(value) is not str or not value or len(value) > MAX_STRING_CHARACTERS or CONTROL_CHARACTERS.search(value):
        fail(f"{path} must be a non-empty bounded control-free string")
    if expected is not None and value != expected:
        fail(f"{path} must equal {expected}")
    return value


def require_hex(value: Any, path: str, pattern: re.Pattern[str]) -> str:
    text = require_string(value, path)
    if pattern.fullmatch(text) is None or set(text) == {"0"}:
        fail(f"{path} is not a canonical nonzero lowercase identity")
    return text


def require_hex64(value: Any, path: str) -> str:
    return require_hex(value, path, HEX_64)


def require_hex40(value: Any, path: str) -> str:
    return require_hex(value, path, HEX_40)


def require_identifier(value: Any, path: str) -> str:
    text = require_string(value, path)
    if SAFE_IDENTIFIER.fullmatch(text) is None:
        fail(f"{path} is not a canonical identifier")
    return text


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def canonical_sha256(lines: Iterable[str]) -> str:
    return sha256_bytes("\n".join(lines).encode("utf-8"))


def scalar(value: Any) -> str:
    if value is True:
        return "true"
    if value is False:
        return "false"
    if type(value) in {str, int}:
        return str(value)
    fail("canonical projection contains a non-scalar value")


def configure_authenticated_taira(admission_path: str) -> None:
    global TAIRA_DEPLOYMENT
    admission, raw = load_json_record(admission_path, 128 * 1024, string_limit=2_048)
    admission_sha256 = sha256_bytes(raw)
    expected_admission_sha256 = os.environ.get(
        "IOS_TAIRA_DEPLOYMENT_VERIFIED_ADMISSION_SHA256", ""
    )
    if (
        HEX_64.fullmatch(expected_admission_sha256) is None
        or expected_admission_sha256 == "0" * 64
        or admission_sha256 != expected_admission_sha256
    ):
        fail("Taira deployment admission bytes differ from the verifier-pinned snapshot")
    root = exact_keys(
        admission,
        {
            "schemaVersion", "contractId", "status",
            "evaluatedAtEpochSeconds", "manifestSequenceNumber", "manifestSha256",
            "operatorSignatureSha256", "reviewerSignatureSha256",
            "operatorPublicKeySpkiSha256", "reviewerPublicKeySpkiSha256",
            "current", "retired", "pendingRowPolicy",
        },
        "Taira deployment admission",
    )
    require_int(root["schemaVersion"], "Taira admission schemaVersion", 1, 1)
    require_string(
        root["contractId"],
        "Taira admission contractId",
        "sora-ios-taira-deployment-admission-v2",
    )
    require_string(root["status"], "Taira admission status", "admitted")
    require_int(root["evaluatedAtEpochSeconds"], "Taira admission evaluation", 1)
    require_int(root["manifestSequenceNumber"], "Taira admission manifest sequence", 1, MAX_SAFE_INTEGER)
    for key in (
        "manifestSha256", "operatorSignatureSha256",
        "reviewerSignatureSha256", "operatorPublicKeySpkiSha256",
        "reviewerPublicKeySpkiSha256",
    ):
        require_hex64(root[key], f"Taira admission {key}")
    if root["operatorPublicKeySpkiSha256"] == root["reviewerPublicKeySpkiSha256"]:
        fail("Taira deployment operator and reviewer keys are not distinct")
    epoch_keys = {
        "chainId", "role", "deploymentEpoch", "genesisHash",
        "canonicalToriiBaseUrl", "publicMcpEndpoint", "explorerBaseUrl",
    }
    current = exact_keys(root["current"], epoch_keys, "Taira admission current")
    retired = exact_keys(root["retired"], epoch_keys, "Taira admission retired")
    require_string(current["role"], "Taira current role", "current")
    require_string(retired["role"], "Taira retired role", "retired")
    if {current["chainId"], retired["chainId"]} != TAIRA_KNOWN_CHAIN_IDS:
        fail("Taira admission must retain both known UUIDs in distinct roles")
    require_int(current["deploymentEpoch"], "Taira current deployment epoch", 1)
    require_int(retired["deploymentEpoch"], "Taira retired deployment epoch", 1)
    if current["deploymentEpoch"] <= retired["deploymentEpoch"]:
        fail("current Taira deployment epoch is not newer than retired")
    require_hex64(current["genesisHash"], "Taira current genesis")
    require_hex64(retired["genesisHash"], "Taira retired genesis")
    if current["genesisHash"] == retired["genesisHash"]:
        fail("Taira deployment genesis identities are not distinct")
    if any(retired[key] is not None for key in (
        "canonicalToriiBaseUrl", "publicMcpEndpoint", "explorerBaseUrl",
    )):
        fail("retired Taira deployment identity authorizes transport")
    base = require_string(current["canonicalToriiBaseUrl"], "Taira canonical Torii origin")
    endpoint = require_string(current["publicMcpEndpoint"], "Taira public MCP endpoint")
    explorer = require_string(current["explorerBaseUrl"], "Taira explorer origin")
    parsed = urlsplit(base)
    parsed_explorer = urlsplit(explorer)
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
        or parsed_explorer.scheme != "https"
        or parsed_explorer.hostname is None
        or parsed_explorer.hostname != parsed_explorer.hostname.lower()
        or parsed_explorer.hostname == "taira.sora.org"
        or "." not in parsed_explorer.hostname
        or parsed_explorer.username is not None
        or parsed_explorer.password is not None
        or parsed_explorer.port not in (None, 443)
        or parsed_explorer.path
        or parsed_explorer.query
        or parsed_explorer.fragment
    ):
        fail("Taira admission does not designate one explicit canonical public HTTPS /v1/mcp route")
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
        fail("Taira admission permits schema-77 pending-row reinterpretation")
    TAIRA_DEPLOYMENT = {
        "manifestSha256": root["manifestSha256"],
        "manifestSequenceNumber": str(root["manifestSequenceNumber"]),
        "admissionSha256": admission_sha256,
        "currentChainId": current["chainId"],
        "currentGenesisHash": current["genesisHash"],
        "canonicalToriiBaseUrl": base,
        "publicMcpEndpoint": endpoint,
        "explorerBaseUrl": explorer,
    }
    NETWORKS["taira"] = {
        "chainId": current["chainId"],
        "i105Discriminant": 369,
        "toriiBaseUrl": base,
        "explorerBaseUrl": explorer,
        "isTestnet": True,
    }


def validate_privacy(value: Any, path: str = "privacy") -> None:
    privacy = exact_keys(value, PRIVACY_KEYS, path)
    require_bool(privacy["redactedAggregateEvidenceOnly"], f"{path}.redactedAggregateEvidenceOnly", True)
    for key in PRIVACY_KEYS - {"redactedAggregateEvidenceOnly"}:
        require_bool(privacy[key], f"{path}.{key}", False)


def validate_blocking_reasons(value: Any, *, blocked: bool) -> None:
    if type(value) is not list or len(value) > MAX_BLOCKING_REASONS:
        fail("blockingReasons must be a bounded array")
    for reason in value:
        if type(reason) is not str or not reason or len(reason) > MAX_BLOCKING_REASON_CHARACTERS or CONTROL_CHARACTERS.search(reason):
            fail("blockingReasons contains an unsafe reason")
    if blocked and not value:
        fail("blocked evidence must state at least one reason")
    if not blocked and value:
        fail("qualified evidence may not contain blocking reasons")


def same_shape(value: Any, template: Any, path: str = "$") -> None:
    if type(template) is dict:
        exact_keys(value, template.keys(), path)
        for key in template:
            same_shape(value[key], template[key], f"{path}.{key}")
    elif type(template) is list:
        if type(value) is not list:
            fail(f"{path} must be an array")
    elif value is not None and type(value) in {dict, list}:
        fail(f"{path} has the wrong container type")


def validate_quantity(value: Any, path: str) -> str:
    text = require_string(value, path)
    if len(text) > 256 or text == "0" or CANONICAL_QUANTITY.fullmatch(text) is None:
        fail(f"{path} must be a positive canonical Nexus decimal string")
    if len(text.partition(".")[2]) > 254:
        fail(f"{path} has more than 254 fractional digits")
    return text


def compare_quantities(left: str, right: str) -> int:
    left_integer, _, left_fraction = left.partition(".")
    right_integer, _, right_fraction = right.partition(".")
    if len(left_integer) != len(right_integer):
        return -1 if len(left_integer) < len(right_integer) else 1
    if left_integer != right_integer:
        return -1 if left_integer < right_integer else 1
    width = max(len(left_fraction), len(right_fraction))
    left_normalized = left_fraction.ljust(width, "0")
    right_normalized = right_fraction.ljust(width, "0")
    if left_normalized == right_normalized:
        return 0
    return -1 if left_normalized < right_normalized else 1


def validate_trust(value: dict[str, Any], *, qualified: bool) -> None:
    trust = exact_keys(
        value,
        {
            "schemaVersion",
            "contractId",
            "platform",
            "assessedAt",
            "status",
            "signatureAlgorithm",
            "ledgerStoreId",
            "authorities",
            "blockingReasons",
        },
        "funded canary trust root",
    )
    require_int(trust["schemaVersion"], "trust.schemaVersion", 1, 1)
    require_string(trust["contractId"], "trust.contractId", "sora-ios-funded-nexus-canary-trust-v1")
    require_string(trust["platform"], "trust.platform", "ios")
    assessed_at = require_string(trust["assessedAt"], "trust.assessedAt")
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", assessed_at) is None:
        fail("trust.assessedAt must be an ISO calendar date")
    require_string(trust["signatureAlgorithm"], "trust.signatureAlgorithm", "ecdsa-p256-sha256")
    authorities = exact_keys(
        trust["authorities"],
        {"releaseOperator", "independentApprover", "independentReviewer", "consumptionLedger"},
        "trust.authorities",
    )
    roles = {
        "releaseOperator": "release-operator",
        "independentApprover": "independent-approver",
        "independentReviewer": "independent-reviewer",
        "consumptionLedger": "approval-consumption-ledger",
    }
    fingerprints: list[str] = []
    key_ids: list[str] = []
    for name, role in roles.items():
        authority = exact_keys(
            authorities[name],
            {"role", "keyId", "publicKeyPemSha256", "enabled"},
            f"trust.authorities.{name}",
        )
        require_string(authority["role"], f"trust.authorities.{name}.role", role)
        if qualified:
            require_bool(authority["enabled"], f"trust.authorities.{name}.enabled", True)
            key_ids.append(require_identifier(authority["keyId"], f"trust.authorities.{name}.keyId"))
            fingerprints.append(require_hex64(authority["publicKeyPemSha256"], f"trust.authorities.{name}.publicKeyPemSha256"))
        else:
            require_bool(authority["enabled"], f"trust.authorities.{name}.enabled", False)
            if authority["keyId"] is not None or authority["publicKeyPemSha256"] is not None:
                fail("blocked trust root may not contain fabricated authority identity")
    if qualified:
        require_string(trust["status"], "trust.status", "qualified")
        require_identifier(trust["ledgerStoreId"], "trust.ledgerStoreId")
        validate_blocking_reasons(trust["blockingReasons"], blocked=False)
        if len(set(key_ids)) != len(key_ids) or len(set(fingerprints)) != len(fingerprints):
            fail("funded canary authorities must use four distinct keys")
    else:
        require_string(trust["status"], "trust.status", "blocked")
        if trust["ledgerStoreId"] is not None:
            fail("blocked trust root may not name an unreviewed ledger")
        validate_blocking_reasons(trust["blockingReasons"], blocked=True)


def validate_network(value: Any, network_id: str, path: str = "network") -> None:
    expected = NETWORKS[network_id]
    network = exact_keys(
        value,
        {
            "networkId",
            "chainId",
            "i105Discriminant",
            "toriiBaseUrl",
            "explorerBaseUrl",
            "assetSymbol",
            "xorAssetAlias",
            "isTestnet",
        },
        path,
    )
    require_string(network["networkId"], f"{path}.networkId", network_id)
    require_string(network["chainId"], f"{path}.chainId", expected["chainId"])
    require_int(network["i105Discriminant"], f"{path}.i105Discriminant", expected["i105Discriminant"], expected["i105Discriminant"])
    require_string(network["toriiBaseUrl"], f"{path}.toriiBaseUrl", expected["toriiBaseUrl"])
    require_string(network["explorerBaseUrl"], f"{path}.explorerBaseUrl", expected["explorerBaseUrl"])
    require_string(network["assetSymbol"], f"{path}.assetSymbol", "XOR")
    require_string(network["xorAssetAlias"], f"{path}.xorAssetAlias", "xor#universal")
    require_bool(network["isTestnet"], f"{path}.isTestnet", expected["isTestnet"])


def validate_runtime(value: Any) -> None:
    runtime = exact_keys(
        value,
        {"sourceRevision", "specVersion", "transactionVersion", "genesisHash", "metadataSha256", "typesSha256"},
        "sora2Runtime",
    )
    require_string(runtime["sourceRevision"], "sora2Runtime.sourceRevision", SORA2_REVISION)
    require_int(runtime["specVersion"], "sora2Runtime.specVersion", 130, 130)
    require_int(runtime["transactionVersion"], "sora2Runtime.transactionVersion", 130, 130)
    require_string(runtime["genesisHash"], "sora2Runtime.genesisHash", SORA2_GENESIS)
    require_string(runtime["metadataSha256"], "sora2Runtime.metadataSha256", RUNTIME_METADATA_SHA256)
    require_string(runtime["typesSha256"], "sora2Runtime.typesSha256", RUNTIME_TYPES_SHA256)


def validate_blocked_template(receipt: dict[str, Any], template: dict[str, Any], network_id: str) -> None:
    same_shape(receipt, template)
    exact_keys(
        receipt,
        {
            "schemaVersion",
            "contractId",
            "status",
            "platform",
            "receiptRecordedAtEpochSeconds",
            "candidate",
            "sora2Runtime",
            "network",
            "featureFlags",
            "signer",
            "finality",
            "operatorApproval",
            "execution",
            "privacy",
            "blockingReasons",
        },
        "blocked canary template",
    )
    require_int(receipt["schemaVersion"], "schemaVersion", 1, 1)
    require_string(receipt["contractId"], "contractId", "sora-ios-funded-nexus-canary-v1")
    require_string(receipt["status"], "status", "blocked")
    require_string(receipt["platform"], "platform", "ios")
    require_int(receipt["receiptRecordedAtEpochSeconds"], "receiptRecordedAtEpochSeconds", 0, 0)
    validate_runtime(receipt["sora2Runtime"])
    validate_network(receipt["network"], network_id)
    validate_privacy(receipt["privacy"])
    validate_blocking_reasons(receipt["blockingReasons"], blocked=True)
    finality = receipt["execution"]["finalityReadback"]
    require_string(finality["networkId"], "execution.finalityReadback.networkId", network_id)
    require_string(finality["chainId"], "execution.finalityReadback.chainId", NETWORKS[network_id]["chainId"])
    if receipt["signer"]["dirtyLocalDebugArtifactAccepted"] is not False:
        fail("blocked template must explicitly reject a dirty local debug signer artifact")
    flags = receipt["featureFlags"]
    if flags["localNexusSendsQualified"] is not False or any(
        flags[key] is not None for key in set(flags) - {"localNexusSendsQualified"}
    ):
        fail("blocked template contains fabricated feature-capability evidence")
    signer = receipt["signer"]
    require_string(signer["status"], "signer.status", "blocked")
    require_int(signer["requiredNativeAbi"], "signer.requiredNativeAbi", 21, 21)
    if any(
        signer[key] is not None
        for key in set(signer) - {"status", "requiredNativeAbi", "dirtyLocalDebugArtifactAccepted"}
    ):
        fail("blocked template contains fabricated signer evidence")
    finality_contract = receipt["finality"]
    require_string(finality_contract["status"], "finality.status", "blocked")
    require_string(finality_contract["attestationRoute"], "finality.attestationRoute", ATTESTATION_ROUTE)
    require_string(finality_contract["bundleRoute"], "finality.bundleRoute", BUNDLE_ROUTE)
    if any(
        finality_contract[key] is not None
        for key in set(finality_contract) - {"status", "attestationRoute", "bundleRoute"}
    ):
        fail("blocked template contains fabricated finality evidence")
    approval = receipt["operatorApproval"]
    require_string(approval["scopeNetworkId"], "operatorApproval.scopeNetworkId", network_id)
    if any(approval[key] is not None for key in set(approval) - {"scopeNetworkId"}):
        fail("blocked template contains fabricated approval evidence")
    candidate = exact_keys(
        receipt["candidate"],
        {
            "bundleIdentifier",
            "developmentTeam",
            "appVersion",
            "buildNumber",
            "appStoreBuildIdentifier",
            "sourceRevision",
            "ipaSha256",
            "ipaBytes",
            "artifactIdentityReceiptSha256",
            "tairaDeploymentManifestSha256",
            "tairaDeploymentAdmissionSha256",
            "tairaCurrentChainId",
            "tairaCurrentGenesisHash",
            "candidateBindingSha256",
        },
        "candidate",
    )
    require_string(candidate["bundleIdentifier"], "candidate.bundleIdentifier", BUNDLE_IDENTIFIER)
    require_string(candidate["developmentTeam"], "candidate.developmentTeam", DEVELOPMENT_TEAM)
    if any(candidate[key] is not None for key in set(candidate) - {"bundleIdentifier", "developmentTeam"}):
        fail("blocked template contains fabricated candidate evidence")
    execution = receipt["execution"]
    for key in (
        "startedAtEpochSeconds",
        "completedAtEpochSeconds",
        "canaryRunId",
        "evidenceBundleSha256",
        "consumptionReceiptSha256",
        "sendAmountCanonical",
        "feeAmountCanonical",
        "submissionAttemptCount",
        "automaticRetryAttempted",
        "ambiguousSubmissionObserved",
        "terminalStatus",
    ):
        if execution[key] is not None:
            fail("blocked template contains fabricated execution evidence")
    for stage_name in STAGE_NAMES:
        stage = execution[stage_name]
        require_string(stage["status"], f"execution.{stage_name}.status", "missing")
        if stage["observedAtEpochSeconds"] is not None or stage["evidenceSha256"] is not None:
            fail("blocked template contains fabricated stage evidence")
        for key, value in stage.items():
            if key in {"status", "observedAtEpochSeconds", "evidenceSha256", "networkId", "chainId"}:
                continue
            if value is not None:
                fail("blocked template contains a fabricated stage assertion")


def validate_approval(value: dict[str, Any], receipt: dict[str, Any], policy_sha: str, trust: dict[str, Any]) -> None:
    approval = exact_keys(
        value,
        {
            "schemaVersion",
            "contractId",
            "platform",
            "networkId",
            "candidateBindingSha256",
            "lowValuePolicySha256",
            "approvalNonce",
            "approvedAtEpochSeconds",
            "expiresAtEpochSeconds",
            "operatorRole",
            "operatorKeyId",
            "independentApproverRole",
            "independentApproverKeyId",
            "privacy",
        },
        "approval receipt",
    )
    network_id = receipt["network"]["networkId"]
    require_int(approval["schemaVersion"], "approval.schemaVersion", 1, 1)
    require_string(approval["contractId"], "approval.contractId", "sora-ios-funded-nexus-canary-approval-v1")
    require_string(approval["platform"], "approval.platform", "ios")
    require_string(approval["networkId"], "approval.networkId", network_id)
    require_string(approval["candidateBindingSha256"], "approval.candidateBindingSha256", receipt["candidate"]["candidateBindingSha256"])
    require_string(approval["lowValuePolicySha256"], "approval.lowValuePolicySha256", policy_sha)
    require_hex64(approval["approvalNonce"], "approval.approvalNonce")
    require_int(approval["approvedAtEpochSeconds"], "approval.approvedAtEpochSeconds", 1, 9_999_999_999)
    require_int(approval["expiresAtEpochSeconds"], "approval.expiresAtEpochSeconds", 1, 9_999_999_999)
    require_string(approval["operatorRole"], "approval.operatorRole", "release-operator")
    require_string(approval["operatorKeyId"], "approval.operatorKeyId", trust["authorities"]["releaseOperator"]["keyId"])
    require_string(approval["independentApproverRole"], "approval.independentApproverRole", "independent-approver")
    require_string(approval["independentApproverKeyId"], "approval.independentApproverKeyId", trust["authorities"]["independentApprover"]["keyId"])
    validate_privacy(approval["privacy"], "approval.privacy")


def validate_policy(
    value: dict[str, Any],
    network_id: str,
) -> tuple[str, str, int, int, int]:
    policy = exact_keys(
        value,
        {
            "schemaVersion",
            "contractId",
            "platform",
            "networkId",
            "assetAlias",
            "maximumAmountCanonical",
            "maximumFeeCanonical",
            "maximumExecutions",
            "validFromEpochSeconds",
            "validUntilEpochSeconds",
            "reviewedAtEpochSeconds",
            "privacy",
        },
        "low-value policy",
    )
    require_int(policy["schemaVersion"], "policy.schemaVersion", 1, 1)
    require_string(policy["contractId"], "policy.contractId", "sora-ios-funded-nexus-low-value-policy-v1")
    require_string(policy["platform"], "policy.platform", "ios")
    require_string(policy["networkId"], "policy.networkId", network_id)
    require_string(policy["assetAlias"], "policy.assetAlias", "xor#universal")
    maximum_amount = validate_quantity(policy["maximumAmountCanonical"], "policy.maximumAmountCanonical")
    maximum_fee = validate_quantity(policy["maximumFeeCanonical"], "policy.maximumFeeCanonical")
    if compare_quantities(maximum_amount, "1") > 0 or compare_quantities(maximum_fee, "1") > 0:
        fail("low-value policy exceeds the independent one-XOR hard ceiling")
    require_int(policy["maximumExecutions"], "policy.maximumExecutions", 1, 1)
    valid_from = require_int(policy["validFromEpochSeconds"], "policy.validFromEpochSeconds", 1, 9_999_999_999)
    valid_until = require_int(policy["validUntilEpochSeconds"], "policy.validUntilEpochSeconds", 1, 9_999_999_999)
    reviewed_at = require_int(policy["reviewedAtEpochSeconds"], "policy.reviewedAtEpochSeconds", 1, 9_999_999_999)
    if reviewed_at < valid_from or reviewed_at > valid_until:
        fail("low-value policy review is outside its validity interval")
    validate_privacy(policy["privacy"], "policy.privacy")
    return maximum_amount, maximum_fee, valid_from, valid_until, reviewed_at


def validate_finality_manifest(value: dict[str, Any], readiness: dict[str, Any]) -> int:
    manifest = exact_keys(
        value,
        {
            "schemaVersion",
            "contractId",
            "status",
            "platform",
            "reviewedAtEpochSeconds",
            "verifierSourceRevision",
            "verifierArtifactSha256",
            "serverContractSourceRevision",
            "serverOpenApiSha256",
            "serverRouteSourceSha256",
            "attestationRoute",
            "bundleRoute",
            "minamotoTrustContextReceiptSha256",
            "tairaTrustContextReceiptSha256",
            "reviewerRole",
            "reviewerKeyId",
            "privacy",
        },
        "finality trust manifest",
    )
    binding = readiness["productionFinalityBinding"]
    contract = readiness["finalityTrustContract"]
    require_int(manifest["schemaVersion"], "finalityManifest.schemaVersion", 1, 1)
    require_string(manifest["contractId"], "finalityManifest.contractId", "sora-ios-nexus-finality-trust-manifest-v1")
    require_string(manifest["status"], "finalityManifest.status", "qualified")
    require_string(manifest["platform"], "finalityManifest.platform", "ios")
    reviewed_at = require_int(
        manifest["reviewedAtEpochSeconds"],
        "finalityManifest.reviewedAtEpochSeconds",
        1,
        9_999_999_999,
    )
    require_string(manifest["verifierSourceRevision"], "finalityManifest.verifierSourceRevision", binding["reviewedVerifierSourceRevision"])
    require_string(manifest["verifierArtifactSha256"], "finalityManifest.verifierArtifactSha256", binding["reviewedVerifierArtifactSha256"])
    require_string(manifest["serverContractSourceRevision"], "finalityManifest.serverContractSourceRevision", contract["serverContractSourceRevision"])
    require_string(manifest["serverOpenApiSha256"], "finalityManifest.serverOpenApiSha256", contract["serverOpenApiSha256"])
    require_string(manifest["serverRouteSourceSha256"], "finalityManifest.serverRouteSourceSha256", contract["serverRouteSourceSha256"])
    require_string(manifest["attestationRoute"], "finalityManifest.attestationRoute", ATTESTATION_ROUTE)
    require_string(manifest["bundleRoute"], "finalityManifest.bundleRoute", BUNDLE_ROUTE)
    require_string(manifest["minamotoTrustContextReceiptSha256"], "finalityManifest.minamotoTrustContextReceiptSha256", contract["minamotoTrustedContextReceiptSha256"])
    require_string(manifest["tairaTrustContextReceiptSha256"], "finalityManifest.tairaTrustContextReceiptSha256", contract["tairaTrustedContextReceiptSha256"])
    require_string(manifest["reviewerRole"], "finalityManifest.reviewerRole", "independent-reviewer")
    require_identifier(manifest["reviewerKeyId"], "finalityManifest.reviewerKeyId")
    validate_privacy(manifest["privacy"], "finalityManifest.privacy")
    return reviewed_at


def validate_finality_native_canary(
    value: dict[str, Any],
    readiness: dict[str, Any],
    finality_manifest_sha: str,
) -> None:
    receipt = exact_keys(
        value,
        {
            "schemaVersion",
            "contractId",
            "status",
            "platform",
            "artifactClass",
            "sourceTreeClean",
            "requiredNativeAbi",
            "observedNativeAbi",
            "verifierSourceRevision",
            "verifierArtifactSha256",
            "finalityTrustManifestReceiptSha256",
            "attestationRoute",
            "attestationResponseType",
            "bundleRoute",
            "bundleResponseType",
            "requiredExportInventorySha256",
            "observedExportInventorySha256",
            "attestationNoritoRoundTripKatSha256",
            "bundleNoritoRoundTripKatSha256",
            "challengeBindingKatSha256",
            "genesisProofKatSha256",
            "tipProofKatSha256",
            "nodeSignatureKatSha256",
            "aggregateSignatureKatSha256",
            "statefulSuccessorKatSha256",
            "finalizedProjectionKatSha256",
            "requiredExportInventoryQualified",
            "attestationNoritoRoundTripQualified",
            "bundleNoritoRoundTripQualified",
            "challengeBindingQualified",
            "genesisProofQualified",
            "tipProofQualified",
            "nodeSignatureQualified",
            "aggregateSignatureQualified",
            "statefulSuccessorQualified",
            "finalizedProjectionQualified",
            "privacy",
        },
        "finality native canary",
    )
    binding = readiness["productionFinalityBinding"]
    require_int(receipt["schemaVersion"], "finalityNative.schemaVersion", 1, 1)
    require_string(
        receipt["contractId"],
        "finalityNative.contractId",
        "sora-ios-nexus-finality-native-canary-v1",
    )
    require_string(receipt["status"], "finalityNative.status", "qualified")
    require_string(receipt["platform"], "finalityNative.platform", "ios")
    require_string(
        receipt["artifactClass"],
        "finalityNative.artifactClass",
        "reviewed-platform-release",
    )
    require_bool(receipt["sourceTreeClean"], "finalityNative.sourceTreeClean", True)
    require_int(receipt["requiredNativeAbi"], "finalityNative.requiredNativeAbi", 21, 21)
    require_int(receipt["observedNativeAbi"], "finalityNative.observedNativeAbi", 21, 21)
    require_string(
        receipt["verifierSourceRevision"],
        "finalityNative.verifierSourceRevision",
        binding["reviewedVerifierSourceRevision"],
    )
    require_string(
        receipt["verifierArtifactSha256"],
        "finalityNative.verifierArtifactSha256",
        binding["reviewedVerifierArtifactSha256"],
    )
    require_string(
        receipt["finalityTrustManifestReceiptSha256"],
        "finalityNative.finalityTrustManifestReceiptSha256",
        finality_manifest_sha,
    )
    require_string(receipt["attestationRoute"], "finalityNative.attestationRoute", ATTESTATION_ROUTE)
    require_string(
        receipt["attestationResponseType"],
        "finalityNative.attestationResponseType",
        "BridgeFinalityAttestationV1",
    )
    require_string(receipt["bundleRoute"], "finalityNative.bundleRoute", BUNDLE_ROUTE)
    require_string(
        receipt["bundleResponseType"],
        "finalityNative.bundleResponseType",
        "BridgeFinalityBundle",
    )
    required_exports = require_hex64(
        receipt["requiredExportInventorySha256"],
        "finalityNative.requiredExportInventorySha256",
    )
    observed_exports = require_hex64(
        receipt["observedExportInventorySha256"],
        "finalityNative.observedExportInventorySha256",
    )
    if observed_exports != required_exports:
        fail("finality native export inventory differs from the reviewed requirement")
    kat_fields = (
        "attestationNoritoRoundTripKatSha256",
        "bundleNoritoRoundTripKatSha256",
        "challengeBindingKatSha256",
        "genesisProofKatSha256",
        "tipProofKatSha256",
        "nodeSignatureKatSha256",
        "aggregateSignatureKatSha256",
        "statefulSuccessorKatSha256",
        "finalizedProjectionKatSha256",
    )
    kat_hashes = [
        require_hex64(receipt[field], f"finalityNative.{field}")
        for field in kat_fields
    ]
    independent_identities = [
        required_exports,
        receipt["verifierArtifactSha256"],
        finality_manifest_sha,
        *kat_hashes,
    ]
    if len(set(independent_identities)) != len(independent_identities):
        fail("finality native artifact, manifest, export, and KAT identities must be independent")
    for field in (
        "requiredExportInventoryQualified",
        "attestationNoritoRoundTripQualified",
        "bundleNoritoRoundTripQualified",
        "challengeBindingQualified",
        "genesisProofQualified",
        "tipProofQualified",
        "nodeSignatureQualified",
        "aggregateSignatureQualified",
        "statefulSuccessorQualified",
        "finalizedProjectionQualified",
    ):
        require_bool(receipt[field], f"finalityNative.{field}", True)
    validate_privacy(receipt["privacy"], "finalityNative.privacy")


def validate_network_trust_context(
    value: dict[str, Any],
    network_id: str,
    readiness: dict[str, Any],
) -> tuple[int, int]:
    context = exact_keys(
        value,
        {
            "schemaVersion",
            "contractId",
            "status",
            "platform",
            "networkId",
            "chainId",
            "reviewedAtEpochSeconds",
            "expectedNodeKeySha256",
            "expectedNodeBuildFingerprint",
            "expectedProtocolVersion",
            "expectedConsensusMode",
            "validatorRosterSha256",
            "quorumNumerator",
            "quorumDenominator",
            "canonicalSignedGenesisSha256",
            "genesisPublicKeySha256",
            "trustedFirstHeight",
            "trustedFirstHeightContextId",
            "verifierSourceRevision",
            "verifierArtifactSha256",
            "serverContractSourceRevision",
            "serverOpenApiSha256",
            "serverRouteSourceSha256",
            "reviewerRole",
            "reviewerKeyId",
            "privacy",
        },
        "network finality trust context",
    )
    binding = readiness["productionFinalityBinding"]
    contract = readiness["finalityTrustContract"]
    require_int(context["schemaVersion"], "networkTrust.schemaVersion", 1, 1)
    require_string(context["contractId"], "networkTrust.contractId", "sora-ios-nexus-finality-trust-context-v1")
    require_string(context["status"], "networkTrust.status", "qualified")
    require_string(context["platform"], "networkTrust.platform", "ios")
    require_string(context["networkId"], "networkTrust.networkId", network_id)
    require_string(context["chainId"], "networkTrust.chainId", NETWORKS[network_id]["chainId"])
    reviewed_at = require_int(
        context["reviewedAtEpochSeconds"],
        "networkTrust.reviewedAtEpochSeconds",
        1,
        9_999_999_999,
    )
    require_hex64(context["expectedNodeKeySha256"], "networkTrust.expectedNodeKeySha256")
    require_hex64(context["expectedNodeBuildFingerprint"], "networkTrust.expectedNodeBuildFingerprint")
    require_identifier(context["expectedProtocolVersion"], "networkTrust.expectedProtocolVersion")
    require_identifier(context["expectedConsensusMode"], "networkTrust.expectedConsensusMode")
    require_hex64(context["validatorRosterSha256"], "networkTrust.validatorRosterSha256")
    numerator = require_int(context["quorumNumerator"], "networkTrust.quorumNumerator", 1, 1_000_000)
    denominator = require_int(context["quorumDenominator"], "networkTrust.quorumDenominator", 1, 1_000_000)
    if numerator > denominator:
        fail("network finality quorum numerator exceeds denominator")
    canonical_genesis = require_hex64(
        context["canonicalSignedGenesisSha256"],
        "networkTrust.canonicalSignedGenesisSha256",
    )
    if network_id == "taira":
        if TAIRA_DEPLOYMENT is None:
            fail("Taira finality trust lacks an authenticated deployment")
        require_string(
            canonical_genesis,
            "networkTrust.canonicalSignedGenesisSha256",
            TAIRA_DEPLOYMENT["currentGenesisHash"],
        )
    require_hex64(context["genesisPublicKeySha256"], "networkTrust.genesisPublicKeySha256")
    trusted_first_height = require_int(
        context["trustedFirstHeight"],
        "networkTrust.trustedFirstHeight",
        1,
    )
    require_hex64(context["trustedFirstHeightContextId"], "networkTrust.trustedFirstHeightContextId")
    require_string(context["verifierSourceRevision"], "networkTrust.verifierSourceRevision", binding["reviewedVerifierSourceRevision"])
    require_string(context["verifierArtifactSha256"], "networkTrust.verifierArtifactSha256", binding["reviewedVerifierArtifactSha256"])
    require_string(context["serverContractSourceRevision"], "networkTrust.serverContractSourceRevision", contract["serverContractSourceRevision"])
    require_string(context["serverOpenApiSha256"], "networkTrust.serverOpenApiSha256", contract["serverOpenApiSha256"])
    require_string(context["serverRouteSourceSha256"], "networkTrust.serverRouteSourceSha256", contract["serverRouteSourceSha256"])
    require_string(context["reviewerRole"], "networkTrust.reviewerRole", "independent-reviewer")
    require_identifier(context["reviewerKeyId"], "networkTrust.reviewerKeyId")
    validate_privacy(context["privacy"], "networkTrust.privacy")
    return reviewed_at, trusted_first_height


def validate_readiness(readiness: dict[str, Any], network_id: str) -> None:
    require_int(readiness.get("schemaVersion"), "readiness.schemaVersion", 4, 4)
    require_string(readiness.get("platform"), "readiness.platform", "ios")
    require_string(readiness.get("status"), "readiness.status", "qualified")
    require_bool(readiness.get("releaseEnabled"), "readiness.releaseEnabled", True)
    signer = readiness.get("productionSignerBinding")
    finality = readiness.get("productionFinalityBinding")
    contract = readiness.get("finalityTrustContract")
    native = readiness.get("nativeCanaryContract")
    criteria = readiness.get("releaseCriteria")
    if not all(type(item) is dict for item in (signer, finality, contract, native, criteria)):
        fail("readiness lacks signer, finality, trust, native-canary, or release-criteria contracts")
    require_string(signer.get("status"), "readiness.productionSignerBinding.status", "qualified")
    adapter_type = require_string(signer.get("adapterType"), "readiness.productionSignerBinding.adapterType")
    if "Unavailable" in adapter_type:
        fail("readiness still selects an unavailable production signer")
    require_string(readiness.get("defaultSigner"), "readiness.defaultSigner", adapter_type)
    require_hex64(signer.get("adapterSourceSha256"), "readiness.productionSignerBinding.adapterSourceSha256")
    require_hex64(signer.get("providerSourceSha256"), "readiness.productionSignerBinding.providerSourceSha256")
    require_hex64(signer.get("reviewedNativeArtifactSha256"), "readiness.productionSignerBinding.reviewedNativeArtifactSha256")
    require_hex64(signer.get("nativeCanaryReceiptSha256"), "readiness.productionSignerBinding.nativeCanaryReceiptSha256")

    require_string(finality.get("status"), "readiness.productionFinalityBinding.status", "qualified")
    finality_type = require_string(finality.get("adapterType"), "readiness.productionFinalityBinding.adapterType")
    if "Unavailable" in finality_type:
        fail("readiness still selects an unavailable finality reader")
    require_string(readiness.get("defaultFinalityReader"), "readiness.defaultFinalityReader", finality_type)
    require_hex64(finality.get("adapterSourceSha256"), "readiness.productionFinalityBinding.adapterSourceSha256")
    require_hex40(finality.get("reviewedVerifierSourceRevision"), "readiness.productionFinalityBinding.reviewedVerifierSourceRevision")
    require_hex64(finality.get("reviewedVerifierArtifactSha256"), "readiness.productionFinalityBinding.reviewedVerifierArtifactSha256")
    require_hex64(finality.get("trustedContextReceiptSha256"), "readiness.productionFinalityBinding.trustedContextReceiptSha256")
    require_hex64(finality.get("nativeCanaryReceiptSha256"), "readiness.productionFinalityBinding.nativeCanaryReceiptSha256")
    require_string(finality.get("attestationRoute"), "readiness.productionFinalityBinding.attestationRoute", ATTESTATION_ROUTE)
    require_string(finality.get("bundleRoute"), "readiness.productionFinalityBinding.bundleRoute", BUNDLE_ROUTE)

    require_int(contract.get("schemaVersion"), "readiness.finalityTrustContract.schemaVersion", 1, 1)
    for field in ("serverContractSourceRevision", "serverOpenApiSha256", "serverRouteSourceSha256"):
        if field == "serverContractSourceRevision":
            require_hex40(contract.get(field), f"readiness.finalityTrustContract.{field}")
        else:
            require_hex64(contract.get(field), f"readiness.finalityTrustContract.{field}")
    require_string(contract.get("attestationRoute"), "readiness.finalityTrustContract.attestationRoute", ATTESTATION_ROUTE)
    require_string(contract.get("bundleRoute"), "readiness.finalityTrustContract.bundleRoute", BUNDLE_ROUTE)
    network_receipt_field = f"{network_id}TrustedContextReceiptSha256"
    require_hex64(contract.get(network_receipt_field), f"readiness.finalityTrustContract.{network_receipt_field}")
    required_true = {
        "requiresUnpredictableNonzeroChallenge",
        "requiresExactLowercase64HexChallengeHeader",
        "rejectsDuplicateChallengeHeader",
        "requiresExactChallengeBinding",
        "requiresCanonicalNoritoRoundTrip",
        "requiresNoStoreOnSuccessAndError",
        "requiresExpectedChainId",
        "requiresExpectedNodeKey",
        "requiresExpectedNodeBuildFingerprint",
        "requiresExpectedProtocolVersion",
        "requiresExpectedConsensusMode",
        "requiresExpectedValidatorRoster",
        "requiresExpectedQuorum",
        "requiresCanonicalSignedGenesis",
        "requiresSignedGenesisSha256",
        "requiresGenesisPublicKey",
        "requiresTrustedFirstHeightContextId",
        "requiresStatefulSuccessorVerification",
        "requiresBoundedSequentialBundleCatchUp",
        "requiresImmediateSuccessorProofs",
        "requiresCrashDurableVerifierCheckpoint",
        "requiresMonotonicHeightAndContext",
        "rejectsAdvancedOrStaleProof",
        "requiresFreshAttestationAtSelectedTip",
        "requiresGenesisFinalityProof",
        "requiresTipFinalityProof",
        "requiresFinalizedBlockHashBinding",
        "requiresHeaderArtifactAndExecutionBinding",
        "requiresNodeSignatureVerification",
        "requiresAggregateSignatureVerification",
        "requiresSingleStateView",
    }
    for field in required_true:
        require_bool(contract.get(field), f"readiness.finalityTrustContract.{field}", True)
    require_bool(contract.get("acceptsStatusBlocksScalar"), "readiness.finalityTrustContract.acceptsStatusBlocksScalar", False)
    require_bool(contract.get("acceptsSelfDeclaredNodeTrust"), "readiness.finalityTrustContract.acceptsSelfDeclaredNodeTrust", False)

    require_int(native.get("requiredNativeAbi"), "readiness.nativeCanaryContract.requiredNativeAbi", 21, 21)
    require_bool(native.get("dirtyLocalDebugArtifactAccepted"), "readiness.nativeCanaryContract.dirtyLocalDebugArtifactAccepted", False)
    for field in (
        "reviewedPlatformArtifactPresent",
        "requiredExportInventoryQualified",
        "transactionBytesParityQualified",
        "signingPrehashParityQualified",
        "signedEnvelopeParityQualified",
        "decodeProjectionParityQualified",
    ):
        require_bool(native.get(field), f"readiness.nativeCanaryContract.{field}", True)
    evidence = native.get("qualificationEvidence")
    if type(evidence) is not dict:
        fail("readiness native canary qualification evidence is absent")
    require_string(evidence.get("status"), "readiness.nativeCanaryContract.qualificationEvidence.status", "qualified")
    require_hex64(evidence.get("receiptSha256"), "readiness.nativeCanaryContract.qualificationEvidence.receiptSha256")
    criteria = exact_keys(
        criteria,
        {
            "taggedSourceCompiles",
            "sourceToBinaryIdentityProven",
            "canonicalTransactionParityQualified",
            "licenseAndNoticeReviewed",
            "sbomReviewed",
            "buildProvenanceReviewed",
            "artifactAttestationReviewed",
            "minimalLifetimeSecretBoundaryReviewed",
            "authoritativeChainAssetAndFeeMappingQualified",
            "sdkDeployedNodeCompatibilityQualified",
            "nativeAbiAndExportInventoryQualified",
            "validationFeeReleaseVectorQualified",
            "transactionEnvelopeParityQualified",
            "reviewedPlatformCanaryQualified",
            "reviewedFinalityVerifierQualified",
            "finalityTrustedContextsQualified",
            "finalityAttestationCanaryQualified",
            "localReceiptHashParityQualified",
            "fundedTairaCanaryQualified",
            "fundedMinamotoCanaryQualified",
            "unavailableSignerReplaced",
            "unavailableFinalityReaderReplaced",
        },
        "readiness.releaseCriteria",
    )
    for field in (
        "taggedSourceCompiles",
        "sourceToBinaryIdentityProven",
        "canonicalTransactionParityQualified",
        "licenseAndNoticeReviewed",
        "sbomReviewed",
        "buildProvenanceReviewed",
        "artifactAttestationReviewed",
        "minimalLifetimeSecretBoundaryReviewed",
        "authoritativeChainAssetAndFeeMappingQualified",
        "sdkDeployedNodeCompatibilityQualified",
        "nativeAbiAndExportInventoryQualified",
        "validationFeeReleaseVectorQualified",
        "transactionEnvelopeParityQualified",
        "reviewedPlatformCanaryQualified",
        "reviewedFinalityVerifierQualified",
        "finalityTrustedContextsQualified",
        "finalityAttestationCanaryQualified",
        "localReceiptHashParityQualified",
        "unavailableSignerReplaced",
        "unavailableFinalityReaderReplaced",
    ):
        require_bool(criteria.get(field), f"readiness.releaseCriteria.{field}", True)
    # These are results of this contract, not prerequisites. A truthful bound
    # readiness receipt remains false until the two signed canaries and their
    # admission establish the outcome without changing the receipt hash.
    require_bool(criteria.get("fundedTairaCanaryQualified"), "readiness.releaseCriteria.fundedTairaCanaryQualified", False)
    require_bool(criteria.get("fundedMinamotoCanaryQualified"), "readiness.releaseCriteria.fundedMinamotoCanaryQualified", False)


def validate_feature_flags(receipt: dict[str, Any], pi: dict[str, Any], pi_sha: str, network_id: str) -> None:
    flags = exact_keys(
        receipt["featureFlags"],
        {
            "snapshotObservedAtEpochSeconds",
            "snapshotReceiptSha256",
            "configRevision",
            "nexusAvailable",
            "nexusSendsAvailable",
            "polkamarktVisible",
            "polkamarktMutationsAvailable",
            "tairaDefaultVisible",
            "tairaPreferenceIsExplicit",
            "tairaEffectiveVisible",
            "localNexusSendsQualified",
        },
        "featureFlags",
    )
    capabilities = exact_keys(
        pi.get("capabilities"),
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
        "pi.capabilities",
    )
    require_int(pi.get("schemaVersion"), "pi.schemaVersion", 3, 3)
    require_string(pi.get("contractId"), "pi.contractId", "sora-pi-production-capability-probe-v3")
    require_string(pi.get("status"), "pi.status", "qualified")
    captured = require_int(pi.get("capturedAtEpochSeconds"), "pi.capturedAtEpochSeconds", 1, 9_999_999_999)
    require_int(
        capabilities["capturedAtEpochSeconds"],
        "pi.capabilities.capturedAtEpochSeconds",
        captured,
        captured,
    )
    require_int(flags["snapshotObservedAtEpochSeconds"], "featureFlags.snapshotObservedAtEpochSeconds", captured, captured)
    require_string(flags["snapshotReceiptSha256"], "featureFlags.snapshotReceiptSha256", pi_sha)
    require_string(flags["configRevision"], "featureFlags.configRevision", capabilities["configRevision"])
    require_bool(
        capabilities["mobileConfigHealthBound"],
        "pi.capabilities.mobileConfigHealthBound",
        True,
    )
    require_bool(
        capabilities["historyBlockHeightContractDeployed"],
        "pi.capabilities.historyBlockHeightContractDeployed",
        True,
    )
    for field in (
        "nexusAvailable",
        "nexusSendsAvailable",
        "polkamarktVisible",
        "polkamarktMutationsAvailable",
        "tairaDefaultVisible",
    ):
        require_bool(capabilities[field], f"pi.capabilities.{field}", True)
        require_bool(flags[field], f"featureFlags.{field}", True)
    require_bool(flags["localNexusSendsQualified"], "featureFlags.localNexusSendsQualified", True)
    require_bool(flags["tairaPreferenceIsExplicit"], "featureFlags.tairaPreferenceIsExplicit")
    require_bool(flags["tairaEffectiveVisible"], "featureFlags.tairaEffectiveVisible")
    if network_id == "taira":
        require_bool(flags["tairaPreferenceIsExplicit"], "featureFlags.tairaPreferenceIsExplicit", True)
        require_bool(flags["tairaEffectiveVisible"], "featureFlags.tairaEffectiveVisible", True)


def validate_signer(receipt: dict[str, Any], readiness: dict[str, Any], readiness_sha: str, native_receipt_sha: str) -> None:
    signer = exact_keys(
        receipt["signer"],
        {
            "status",
            "readinessReceiptSha256",
            "adapterType",
            "adapterSourcePath",
            "adapterSourceSha256",
            "reviewedNativeArtifactSha256",
            "nativeCanaryReceiptSha256",
            "requiredNativeAbi",
            "observedNativeAbi",
            "artifactClass",
            "sourceTreeClean",
            "dirtyLocalDebugArtifactAccepted",
            "osSecurityBoundary",
            "bindingSha256",
        },
        "signer",
    )
    binding = readiness["productionSignerBinding"]
    native = readiness["nativeCanaryContract"]
    require_string(signer["status"], "signer.status", "qualified")
    require_string(signer["readinessReceiptSha256"], "signer.readinessReceiptSha256", readiness_sha)
    require_string(signer["adapterType"], "signer.adapterType", binding["adapterType"])
    if "Unavailable" in signer["adapterType"]:
        fail("qualified funded canary cannot use an unavailable signer")
    require_string(signer["adapterSourcePath"], "signer.adapterSourcePath", binding["adapterSourcePath"])
    require_string(signer["adapterSourceSha256"], "signer.adapterSourceSha256", binding["adapterSourceSha256"])
    require_string(signer["reviewedNativeArtifactSha256"], "signer.reviewedNativeArtifactSha256", binding["reviewedNativeArtifactSha256"])
    require_string(signer["nativeCanaryReceiptSha256"], "signer.nativeCanaryReceiptSha256", binding["nativeCanaryReceiptSha256"])
    if signer["nativeCanaryReceiptSha256"] != native_receipt_sha or native["qualificationEvidence"]["receiptSha256"] != native_receipt_sha:
        fail("signer does not bind the actual reviewed native canary receipt bytes")
    require_int(signer["requiredNativeAbi"], "signer.requiredNativeAbi", 21, 21)
    require_int(signer["observedNativeAbi"], "signer.observedNativeAbi", 21, 21)
    require_string(signer["artifactClass"], "signer.artifactClass", "reviewed-platform-release")
    require_bool(signer["sourceTreeClean"], "signer.sourceTreeClean", True)
    require_bool(signer["dirtyLocalDebugArtifactAccepted"], "signer.dirtyLocalDebugArtifactAccepted", False)
    require_string(signer["osSecurityBoundary"], "signer.osSecurityBoundary", "iOSDataProtectionKeychain")
    expected_binding = canonical_sha256(
        [
            f"status={signer['status']}",
            f"readinessReceiptSha256={signer['readinessReceiptSha256']}",
            f"adapterType={signer['adapterType']}",
            f"adapterSourcePath={signer['adapterSourcePath']}",
            f"adapterSourceSha256={signer['adapterSourceSha256']}",
            f"reviewedNativeArtifactSha256={signer['reviewedNativeArtifactSha256']}",
            f"nativeCanaryReceiptSha256={signer['nativeCanaryReceiptSha256']}",
            f"requiredNativeAbi={signer['requiredNativeAbi']}",
            f"observedNativeAbi={signer['observedNativeAbi']}",
            f"artifactClass={signer['artifactClass']}",
            f"sourceTreeClean={scalar(signer['sourceTreeClean'])}",
            f"dirtyLocalDebugArtifactAccepted={scalar(signer['dirtyLocalDebugArtifactAccepted'])}",
            f"osSecurityBoundary={signer['osSecurityBoundary']}",
        ]
    )
    require_string(signer["bindingSha256"], "signer.bindingSha256", expected_binding)


def validate_finality(
    receipt: dict[str, Any],
    readiness: dict[str, Any],
    readiness_sha: str,
    finality_native_sha: str,
    manifest_sha: str,
    network_trust_sha: str,
    network_id: str,
) -> None:
    finality = exact_keys(
        receipt["finality"],
        {
            "status",
            "readinessReceiptSha256",
            "adapterType",
            "adapterSourcePath",
            "adapterSourceSha256",
            "verifierSourceRevision",
            "verifierArtifactSha256",
            "finalityNativeCanaryReceiptSha256",
            "finalityTrustManifestReceiptSha256",
            "networkTrustContextReceiptSha256",
            "serverContractSourceRevision",
            "serverOpenApiSha256",
            "serverRouteSourceSha256",
            "attestationRoute",
            "bundleRoute",
            "bindingSha256",
        },
        "finality",
    )
    binding = readiness["productionFinalityBinding"]
    contract = readiness["finalityTrustContract"]
    require_string(finality["status"], "finality.status", "qualified")
    require_string(finality["readinessReceiptSha256"], "finality.readinessReceiptSha256", readiness_sha)
    require_string(finality["adapterType"], "finality.adapterType", binding["adapterType"])
    if "Unavailable" in finality["adapterType"]:
        fail("qualified funded canary cannot use an unavailable finality reader")
    require_string(finality["adapterSourcePath"], "finality.adapterSourcePath", binding["adapterSourcePath"])
    require_string(finality["adapterSourceSha256"], "finality.adapterSourceSha256", binding["adapterSourceSha256"])
    require_string(finality["verifierSourceRevision"], "finality.verifierSourceRevision", binding["reviewedVerifierSourceRevision"])
    require_string(finality["verifierArtifactSha256"], "finality.verifierArtifactSha256", binding["reviewedVerifierArtifactSha256"])
    require_string(finality["finalityNativeCanaryReceiptSha256"], "finality.finalityNativeCanaryReceiptSha256", binding["nativeCanaryReceiptSha256"])
    if finality["finalityNativeCanaryReceiptSha256"] != finality_native_sha:
        fail("finality does not bind the actual finality native-canary receipt bytes")
    require_string(finality["finalityTrustManifestReceiptSha256"], "finality.finalityTrustManifestReceiptSha256", manifest_sha)
    require_string(finality["finalityTrustManifestReceiptSha256"], "finality.finalityTrustManifestReceiptSha256", binding["trustedContextReceiptSha256"])
    require_string(finality["networkTrustContextReceiptSha256"], "finality.networkTrustContextReceiptSha256", network_trust_sha)
    require_string(finality["networkTrustContextReceiptSha256"], "finality.networkTrustContextReceiptSha256", contract[f"{network_id}TrustedContextReceiptSha256"])
    require_string(finality["serverContractSourceRevision"], "finality.serverContractSourceRevision", contract["serverContractSourceRevision"])
    require_string(finality["serverOpenApiSha256"], "finality.serverOpenApiSha256", contract["serverOpenApiSha256"])
    require_string(finality["serverRouteSourceSha256"], "finality.serverRouteSourceSha256", contract["serverRouteSourceSha256"])
    require_string(finality["attestationRoute"], "finality.attestationRoute", ATTESTATION_ROUTE)
    require_string(finality["bundleRoute"], "finality.bundleRoute", BUNDLE_ROUTE)
    expected_binding = canonical_sha256(
        [
            f"status={finality['status']}",
            f"readinessReceiptSha256={finality['readinessReceiptSha256']}",
            f"adapterType={finality['adapterType']}",
            f"adapterSourcePath={finality['adapterSourcePath']}",
            f"adapterSourceSha256={finality['adapterSourceSha256']}",
            f"verifierSourceRevision={finality['verifierSourceRevision']}",
            f"verifierArtifactSha256={finality['verifierArtifactSha256']}",
            f"finalityNativeCanaryReceiptSha256={finality['finalityNativeCanaryReceiptSha256']}",
            f"finalityTrustManifestReceiptSha256={finality['finalityTrustManifestReceiptSha256']}",
            f"networkTrustContextReceiptSha256={finality['networkTrustContextReceiptSha256']}",
            f"serverContractSourceRevision={finality['serverContractSourceRevision']}",
            f"serverOpenApiSha256={finality['serverOpenApiSha256']}",
            f"serverRouteSourceSha256={finality['serverRouteSourceSha256']}",
            f"attestationRoute={finality['attestationRoute']}",
            f"bundleRoute={finality['bundleRoute']}",
        ]
    )
    require_string(finality["bindingSha256"], "finality.bindingSha256", expected_binding)
    if finality["bindingSha256"] == receipt["signer"]["bindingSha256"]:
        fail("signer and finality bindings must remain independently identified")


def validate_candidate(
    receipt: dict[str, Any],
    artifact: dict[str, Any],
    artifact_raw: bytes,
    ipa_sha: str,
    ipa_bytes: int,
    expected_source_revision: str,
) -> None:
    candidate = exact_keys(
        receipt["candidate"],
        {
            "bundleIdentifier",
            "developmentTeam",
            "appVersion",
            "buildNumber",
            "appStoreBuildIdentifier",
            "sourceRevision",
            "ipaSha256",
            "ipaBytes",
            "artifactIdentityReceiptSha256",
            "tairaDeploymentManifestSha256",
            "tairaDeploymentAdmissionSha256",
            "tairaCurrentChainId",
            "tairaCurrentGenesisHash",
            "candidateBindingSha256",
        },
        "candidate",
    )
    require_string(artifact.get("contractId"), "artifact.contractId", "sora-ios-production-artifact-identity-v2")
    require_string(artifact.get("status"), "artifact.status", "qualified")
    application = artifact.get("application")
    ipa = artifact.get("ipa")
    if type(application) is not dict or type(ipa) is not dict:
        fail("artifact identity receipt lacks application or IPA identity")
    require_string(candidate["bundleIdentifier"], "candidate.bundleIdentifier", BUNDLE_IDENTIFIER)
    require_string(candidate["developmentTeam"], "candidate.developmentTeam", DEVELOPMENT_TEAM)
    require_string(candidate["appVersion"], "candidate.appVersion", application.get("appVersion"))
    require_string(candidate["buildNumber"], "candidate.buildNumber", application.get("buildNumber"))
    require_string(candidate["appStoreBuildIdentifier"], "candidate.appStoreBuildIdentifier", application.get("appStoreBuildIdentifier"))
    require_hex40(candidate["sourceRevision"], "candidate.sourceRevision")
    require_string(candidate["sourceRevision"], "candidate.sourceRevision", expected_source_revision)
    require_string(candidate["sourceRevision"], "candidate.sourceRevision", artifact.get("sourceRevision"))
    require_string(candidate["ipaSha256"], "candidate.ipaSha256", ipa_sha)
    require_int(candidate["ipaBytes"], "candidate.ipaBytes", ipa_bytes, ipa_bytes)
    require_string(ipa.get("sha256"), "artifact.ipa.sha256", ipa_sha)
    require_int(ipa.get("bytes"), "artifact.ipa.bytes", ipa_bytes, ipa_bytes)
    require_string(candidate["artifactIdentityReceiptSha256"], "candidate.artifactIdentityReceiptSha256", sha256_bytes(artifact_raw))
    if TAIRA_DEPLOYMENT is None:
        fail("qualified canary lacks an authenticated Taira deployment admission")
    require_string(
        candidate["tairaDeploymentManifestSha256"],
        "candidate.tairaDeploymentManifestSha256",
        TAIRA_DEPLOYMENT["manifestSha256"],
    )
    require_string(
        candidate["tairaDeploymentAdmissionSha256"],
        "candidate.tairaDeploymentAdmissionSha256",
        TAIRA_DEPLOYMENT["admissionSha256"],
    )
    require_string(
        candidate["tairaCurrentChainId"],
        "candidate.tairaCurrentChainId",
        TAIRA_DEPLOYMENT["currentChainId"],
    )
    require_string(
        candidate["tairaCurrentGenesisHash"],
        "candidate.tairaCurrentGenesisHash",
        TAIRA_DEPLOYMENT["currentGenesisHash"],
    )

    runtime = receipt["sora2Runtime"]
    flags = receipt["featureFlags"]
    signer = receipt["signer"]
    finality = receipt["finality"]
    network = receipt["network"]
    expected_binding = canonical_sha256(
        [
            f"contractId={receipt['contractId']}",
            f"platform={receipt['platform']}",
            f"bundleIdentifier={candidate['bundleIdentifier']}",
            f"developmentTeam={candidate['developmentTeam']}",
            f"appVersion={candidate['appVersion']}",
            f"buildNumber={candidate['buildNumber']}",
            f"appStoreBuildIdentifier={candidate['appStoreBuildIdentifier']}",
            f"sourceRevision={candidate['sourceRevision']}",
            f"ipaSha256={candidate['ipaSha256']}",
            f"ipaBytes={candidate['ipaBytes']}",
            f"artifactIdentityReceiptSha256={candidate['artifactIdentityReceiptSha256']}",
            f"tairaDeploymentManifestSha256={candidate['tairaDeploymentManifestSha256']}",
            f"tairaDeploymentAdmissionSha256={candidate['tairaDeploymentAdmissionSha256']}",
            f"tairaCurrentChainId={candidate['tairaCurrentChainId']}",
            f"tairaCurrentGenesisHash={candidate['tairaCurrentGenesisHash']}",
            f"sora2SourceRevision={runtime['sourceRevision']}",
            f"runtimeSpecVersion={runtime['specVersion']}",
            f"runtimeTransactionVersion={runtime['transactionVersion']}",
            f"runtimeGenesisHash={runtime['genesisHash']}",
            f"runtimeMetadataSha256={runtime['metadataSha256']}",
            f"runtimeTypesSha256={runtime['typesSha256']}",
            f"featureSnapshotObservedAtEpochSeconds={flags['snapshotObservedAtEpochSeconds']}",
            f"featureSnapshotReceiptSha256={flags['snapshotReceiptSha256']}",
            f"featureConfigRevision={flags['configRevision']}",
            f"nexusAvailable={scalar(flags['nexusAvailable'])}",
            f"nexusSendsAvailable={scalar(flags['nexusSendsAvailable'])}",
            f"polkamarktVisible={scalar(flags['polkamarktVisible'])}",
            f"polkamarktMutationsAvailable={scalar(flags['polkamarktMutationsAvailable'])}",
            f"tairaDefaultVisible={scalar(flags['tairaDefaultVisible'])}",
            f"tairaPreferenceIsExplicit={scalar(flags['tairaPreferenceIsExplicit'])}",
            f"tairaEffectiveVisible={scalar(flags['tairaEffectiveVisible'])}",
            f"localNexusSendsQualified={scalar(flags['localNexusSendsQualified'])}",
            f"signerBindingSha256={signer['bindingSha256']}",
            f"finalityBindingSha256={finality['bindingSha256']}",
            f"networkId={network['networkId']}",
            f"chainId={network['chainId']}",
        ]
    )
    require_string(candidate["candidateBindingSha256"], "candidate.candidateBindingSha256", expected_binding)


def validate_stage(stage_name: str, stage: Any, receipt: dict[str, Any]) -> int:
    expected_assertions = STAGE_ASSERTIONS[stage_name]
    if stage_name == "terminalStatusReadback":
        extra = {"committedBlockHeight"}
    elif stage_name == "finalityReadback":
        extra = {
            "networkId",
            "chainId",
            "finalizedBlockHeight",
            "finalizedBlockHash",
            "attestationChallengeSha256",
            "attestationChallengeBindingSha256",
            "attestationEvidenceSha256",
            "bundleEvidenceSha256",
            "reviewedVerifierSourceRevision",
            "reviewedVerifierArtifactSha256",
            "finalityNativeCanaryReceiptSha256",
            "finalityTrustManifestReceiptSha256",
            "networkTrustContextReceiptSha256",
            "finalityBindingSha256",
        }
    else:
        extra = set()
    stage_object = exact_keys(
        stage,
        {"status", "observedAtEpochSeconds", "evidenceSha256"} | set(expected_assertions.keys()) | extra,
        f"execution.{stage_name}",
    )
    require_string(stage_object["status"], f"execution.{stage_name}.status", "qualified")
    observed_at = require_int(stage_object["observedAtEpochSeconds"], f"execution.{stage_name}.observedAtEpochSeconds", 1, 9_999_999_999)
    for key, expected in expected_assertions.items():
        if type(expected) is bool:
            require_bool(stage_object[key], f"execution.{stage_name}.{key}", expected)
        else:
            require_string(stage_object[key], f"execution.{stage_name}.{key}", expected)
    projection = [
        "contractId=sora-ios-funded-nexus-canary-stage-v1",
        f"canaryRunId={receipt['execution']['canaryRunId']}",
        f"candidateBindingSha256={receipt['candidate']['candidateBindingSha256']}",
        f"networkId={receipt['network']['networkId']}",
        f"stageName={stage_name}",
        f"observedAtEpochSeconds={observed_at}",
        "status=qualified",
    ]
    if stage_name == "terminalStatusReadback":
        require_int(
            stage_object["committedBlockHeight"],
            "execution.terminalStatusReadback.committedBlockHeight",
            1,
        )
        projection.append(f"assertion.committedBlockHeight={stage_object['committedBlockHeight']}")
    elif stage_name == "finalityReadback":
        require_string(stage_object["networkId"], "execution.finalityReadback.networkId", receipt["network"]["networkId"])
        require_string(stage_object["chainId"], "execution.finalityReadback.chainId", receipt["network"]["chainId"])
        require_int(stage_object["finalizedBlockHeight"], "execution.finalityReadback.finalizedBlockHeight", 1)
        require_hex64(stage_object["finalizedBlockHash"], "execution.finalityReadback.finalizedBlockHash")
        challenge_sha = require_hex64(
            stage_object["attestationChallengeSha256"],
            "execution.finalityReadback.attestationChallengeSha256",
        )
        require_hex64(stage_object["attestationEvidenceSha256"], "execution.finalityReadback.attestationEvidenceSha256")
        require_hex64(stage_object["bundleEvidenceSha256"], "execution.finalityReadback.bundleEvidenceSha256")
        if stage_object["attestationEvidenceSha256"] == stage_object["bundleEvidenceSha256"]:
            fail("finality attestation and stateful bundle evidence must be independently identified")
        finality = receipt["finality"]
        for stage_key, finality_key in (
            ("reviewedVerifierSourceRevision", "verifierSourceRevision"),
            ("reviewedVerifierArtifactSha256", "verifierArtifactSha256"),
            ("finalityNativeCanaryReceiptSha256", "finalityNativeCanaryReceiptSha256"),
            ("finalityTrustManifestReceiptSha256", "finalityTrustManifestReceiptSha256"),
            ("networkTrustContextReceiptSha256", "networkTrustContextReceiptSha256"),
            ("finalityBindingSha256", "bindingSha256"),
        ):
            require_string(
                stage_object[stage_key],
                f"execution.finalityReadback.{stage_key}",
                finality[finality_key],
            )
        expected_challenge_binding = canonical_sha256(
            [
                "contractId=sora-ios-funded-nexus-finality-challenge-binding-v1",
                f"canaryRunId={receipt['execution']['canaryRunId']}",
                f"candidateBindingSha256={receipt['candidate']['candidateBindingSha256']}",
                f"networkId={stage_object['networkId']}",
                f"chainId={stage_object['chainId']}",
                f"finalizedBlockHeight={stage_object['finalizedBlockHeight']}",
                f"finalizedBlockHash={stage_object['finalizedBlockHash']}",
                f"attestationChallengeSha256={challenge_sha}",
                f"attestationEvidenceSha256={stage_object['attestationEvidenceSha256']}",
                f"bundleEvidenceSha256={stage_object['bundleEvidenceSha256']}",
                f"finalityBindingSha256={stage_object['finalityBindingSha256']}",
            ]
        )
        require_string(
            stage_object["attestationChallengeBindingSha256"],
            "execution.finalityReadback.attestationChallengeBindingSha256",
            expected_challenge_binding,
        )
        for key in (
            "networkId",
            "chainId",
            "finalizedBlockHeight",
            "finalizedBlockHash",
            "attestationChallengeSha256",
            "attestationChallengeBindingSha256",
            "attestationEvidenceSha256",
            "bundleEvidenceSha256",
            "reviewedVerifierSourceRevision",
            "reviewedVerifierArtifactSha256",
            "finalityNativeCanaryReceiptSha256",
            "finalityTrustManifestReceiptSha256",
            "networkTrustContextReceiptSha256",
            "finalityBindingSha256",
        ):
            projection.append(f"assertion.{key}={scalar(stage_object[key])}")
    for key in expected_assertions:
        projection.append(f"assertion.{key}={scalar(stage_object[key])}")
    require_string(stage_object["evidenceSha256"], f"execution.{stage_name}.evidenceSha256", canonical_sha256(projection))
    return observed_at


def validate_execution_stages(receipt: dict[str, Any]) -> list[int]:
    execution = receipt["execution"]
    observed = [validate_stage(name, execution[name], receipt) for name in STAGE_NAMES]
    if any(current <= previous for previous, current in zip(observed, observed[1:])):
        fail("funded canary stages are not in the exact strict execution order")
    if execution["finalityReadback"]["finalizedBlockHeight"] < execution["terminalStatusReadback"]["committedBlockHeight"]:
        fail("attested finality height does not cover the transaction's committed block height")
    return observed


def validate_consumption(
    value: dict[str, Any],
    receipt: dict[str, Any],
    approval_sha: str,
    trust: dict[str, Any],
) -> tuple[int, int]:
    consumption = exact_keys(
        value,
        {
            "schemaVersion",
            "contractId",
            "status",
            "platform",
            "ledgerStoreId",
            "networkId",
            "candidateBindingSha256",
            "approvalNonce",
            "approvalReceiptSha256",
            "canaryRunId",
            "reservedAtEpochSeconds",
            "finalizedAtEpochSeconds",
            "reservationStoreVersion",
            "finalizationStoreVersion",
            "previousLedgerHeadSha256",
            "reservationLedgerHeadSha256",
            "finalizationLedgerHeadSha256",
            "priorReservationCount",
            "submissionHandoffCount",
            "ambiguousAttemptCount",
            "ledgerAuthorityRole",
            "ledgerAuthorityKeyId",
            "privacy",
        },
        "consumption receipt",
    )
    require_int(consumption["schemaVersion"], "consumption.schemaVersion", 1, 1)
    require_string(consumption["contractId"], "consumption.contractId", "sora-ios-funded-nexus-approval-consumption-v1")
    require_string(consumption["status"], "consumption.status", "completed")
    require_string(consumption["platform"], "consumption.platform", "ios")
    require_string(consumption["ledgerStoreId"], "consumption.ledgerStoreId", trust["ledgerStoreId"])
    require_string(consumption["networkId"], "consumption.networkId", receipt["network"]["networkId"])
    require_string(consumption["candidateBindingSha256"], "consumption.candidateBindingSha256", receipt["candidate"]["candidateBindingSha256"])
    require_string(consumption["approvalNonce"], "consumption.approvalNonce", receipt["operatorApproval"]["approvalNonce"])
    require_string(consumption["approvalReceiptSha256"], "consumption.approvalReceiptSha256", approval_sha)
    require_string(consumption["canaryRunId"], "consumption.canaryRunId", receipt["execution"]["canaryRunId"])
    reserved_at = require_int(consumption["reservedAtEpochSeconds"], "consumption.reservedAtEpochSeconds", 1, 9_999_999_999)
    finalized_at = require_int(consumption["finalizedAtEpochSeconds"], "consumption.finalizedAtEpochSeconds", 1, 9_999_999_999)
    reservation_version = require_int(consumption["reservationStoreVersion"], "consumption.reservationStoreVersion", 1)
    finalization_version = require_int(consumption["finalizationStoreVersion"], "consumption.finalizationStoreVersion", 2)
    if finalization_version <= reservation_version:
        fail("append-only finalization store version does not advance the reservation")
    previous_head = require_hex64(consumption["previousLedgerHeadSha256"], "consumption.previousLedgerHeadSha256")
    reservation_head = require_hex64(consumption["reservationLedgerHeadSha256"], "consumption.reservationLedgerHeadSha256")
    finalization_head = require_hex64(consumption["finalizationLedgerHeadSha256"], "consumption.finalizationLedgerHeadSha256")
    if len({previous_head, reservation_head, finalization_head}) != 3:
        fail("append-only ledger heads do not prove two distinct transitions")
    require_int(consumption["priorReservationCount"], "consumption.priorReservationCount", 0, 0)
    require_int(consumption["submissionHandoffCount"], "consumption.submissionHandoffCount", 1, 1)
    require_int(consumption["ambiguousAttemptCount"], "consumption.ambiguousAttemptCount", 0, 0)
    require_string(consumption["ledgerAuthorityRole"], "consumption.ledgerAuthorityRole", "approval-consumption-ledger")
    require_string(consumption["ledgerAuthorityKeyId"], "consumption.ledgerAuthorityKeyId", trust["authorities"]["consumptionLedger"]["keyId"])
    validate_privacy(consumption["privacy"], "consumption.privacy")
    return reserved_at, finalized_at


def validate_evidence_bundle(
    value: dict[str, Any],
    receipt: dict[str, Any],
    artifact_sha: str,
    approval_sha: str,
    policy_sha: str,
    consumption_sha: str,
    trust: dict[str, Any],
) -> int:
    evidence = exact_keys(
        value,
        {
            "schemaVersion",
            "contractId",
            "platform",
            "networkId",
            "canaryRunId",
            "candidateBindingSha256",
            "artifactIdentityReceiptSha256",
            "approvalReceiptSha256",
            "lowValuePolicySha256",
            "approvalNonce",
            "consumptionReceiptSha256",
            "startedAtEpochSeconds",
            "completedAtEpochSeconds",
            "sendAmountCanonical",
            "feeAmountCanonical",
            "submissionAttemptCount",
            "automaticRetryAttempted",
            "ambiguousSubmissionObserved",
            "terminalStatus",
            "attestationEvidenceSha256",
            "bundleEvidenceSha256",
            "stages",
            "independentReviewerRole",
            "independentReviewerKeyId",
            "independentReviewedAtEpochSeconds",
            "privacy",
        },
        "evidence bundle",
    )
    execution = receipt["execution"]
    require_int(evidence["schemaVersion"], "evidence.schemaVersion", 1, 1)
    require_string(evidence["contractId"], "evidence.contractId", "sora-ios-funded-nexus-canary-evidence-v1")
    require_string(evidence["platform"], "evidence.platform", "ios")
    require_string(evidence["networkId"], "evidence.networkId", receipt["network"]["networkId"])
    require_string(evidence["canaryRunId"], "evidence.canaryRunId", execution["canaryRunId"])
    require_string(evidence["candidateBindingSha256"], "evidence.candidateBindingSha256", receipt["candidate"]["candidateBindingSha256"])
    require_string(evidence["artifactIdentityReceiptSha256"], "evidence.artifactIdentityReceiptSha256", artifact_sha)
    require_string(evidence["approvalReceiptSha256"], "evidence.approvalReceiptSha256", approval_sha)
    require_string(evidence["lowValuePolicySha256"], "evidence.lowValuePolicySha256", policy_sha)
    require_string(evidence["approvalNonce"], "evidence.approvalNonce", receipt["operatorApproval"]["approvalNonce"])
    require_string(evidence["consumptionReceiptSha256"], "evidence.consumptionReceiptSha256", consumption_sha)
    for field in (
        "startedAtEpochSeconds",
        "completedAtEpochSeconds",
        "sendAmountCanonical",
        "feeAmountCanonical",
        "submissionAttemptCount",
        "automaticRetryAttempted",
        "ambiguousSubmissionObserved",
        "terminalStatus",
    ):
        if evidence[field] != execution[field]:
            fail(f"evidence bundle differs from canary receipt: {field}")
    require_hex64(evidence["attestationEvidenceSha256"], "evidence.attestationEvidenceSha256")
    require_hex64(evidence["bundleEvidenceSha256"], "evidence.bundleEvidenceSha256")
    if evidence["attestationEvidenceSha256"] == evidence["bundleEvidenceSha256"]:
        fail("attestation and stateful bundle evidence must remain independently identified")
    finality_stage = execution["finalityReadback"]
    require_string(
        evidence["attestationEvidenceSha256"],
        "evidence.attestationEvidenceSha256",
        finality_stage["attestationEvidenceSha256"],
    )
    require_string(
        evidence["bundleEvidenceSha256"],
        "evidence.bundleEvidenceSha256",
        finality_stage["bundleEvidenceSha256"],
    )
    stages = exact_keys(evidence["stages"], STAGE_NAMES, "evidence.stages")
    for stage_name in STAGE_NAMES:
        if stages[stage_name] != execution[stage_name]:
            fail(f"evidence stage differs from canary receipt: {stage_name}")
    require_string(evidence["independentReviewerRole"], "evidence.independentReviewerRole", "independent-reviewer")
    require_string(evidence["independentReviewerKeyId"], "evidence.independentReviewerKeyId", trust["authorities"]["independentReviewer"]["keyId"])
    reviewed_at = require_int(evidence["independentReviewedAtEpochSeconds"], "evidence.independentReviewedAtEpochSeconds", 1, 9_999_999_999)
    validate_privacy(evidence["privacy"], "evidence.privacy")
    return reviewed_at


def validate_qualified_receipt(
    *,
    receipt_path: str,
    template_path: str,
    approval_path: str,
    policy_path: str,
    consumption_path: str,
    evidence_path: str,
    finality_manifest_path: str,
    network_trust_path: str,
    pi_path: str,
    readiness_path: str,
    native_canary_path: str,
    finality_native_canary_path: str,
    artifact_path: str,
    ipa_path: str,
    trust_path: str,
    network_id: str,
    expected_source_revision: str,
    evaluation_epoch: int,
) -> tuple[str, str]:
    if network_id not in NETWORKS:
        fail("funded canary network must be taira or minamoto")
    if evaluation_epoch <= 0 or evaluation_epoch > 9_999_999_999:
        fail("release evaluation epoch is invalid")
    receipt, receipt_raw = load_json_record(receipt_path, 64 * 1024)
    template, _ = load_json_record(template_path, 64 * 1024)
    same_shape(receipt, template)
    require_int(receipt["schemaVersion"], "schemaVersion", 1, 1)
    require_string(receipt["contractId"], "contractId", "sora-ios-funded-nexus-canary-v1")
    require_string(receipt["status"], "status", "qualified")
    require_string(receipt["platform"], "platform", "ios")
    validate_blocking_reasons(receipt["blockingReasons"], blocked=False)
    validate_privacy(receipt["privacy"])
    validate_runtime(receipt["sora2Runtime"])
    validate_network(receipt["network"], network_id)

    approval, approval_raw = load_json_record(approval_path, 64 * 1024)
    policy, policy_raw = load_json_record(policy_path, 64 * 1024)
    consumption, consumption_raw = load_json_record(consumption_path, 64 * 1024)
    evidence, evidence_raw = load_json_record(evidence_path, MAX_JSON_BYTES)
    finality_manifest, finality_manifest_raw = load_json_record(finality_manifest_path, 64 * 1024)
    network_trust, network_trust_raw = load_json_record(network_trust_path, 64 * 1024)
    pi, pi_raw = load_json_record(pi_path, MAX_JSON_BYTES)
    readiness, readiness_raw = load_json_record(readiness_path, MAX_JSON_BYTES, string_limit=4_096)
    _, native_canary_raw = load_json_record(native_canary_path, 64 * 1024, string_limit=4_096)
    finality_native, finality_native_raw = load_json_record(
        finality_native_canary_path,
        64 * 1024,
        string_limit=4_096,
    )
    artifact, artifact_raw = load_json_record(artifact_path, MAX_JSON_BYTES, string_limit=4_096)
    trust, _ = load_json_record(trust_path, 64 * 1024)
    ipa_sha, ipa_bytes = hash_regular(ipa_path, MAX_IPA_BYTES)
    if not ipa_path.endswith(".ipa"):
        fail("candidate artifact path must end in .ipa")

    validate_readiness(readiness, network_id)
    validate_trust(trust, qualified=True)
    finality_manifest_reviewed_at = validate_finality_manifest(
        finality_manifest,
        readiness,
    )
    network_trust_reviewed_at, trusted_first_height = validate_network_trust_context(
        network_trust,
        network_id,
        readiness,
    )
    reviewer_key_id = trust["authorities"]["independentReviewer"]["keyId"]
    require_string(finality_manifest["reviewerKeyId"], "finalityManifest.reviewerKeyId", reviewer_key_id)
    require_string(network_trust["reviewerKeyId"], "networkTrust.reviewerKeyId", reviewer_key_id)
    readiness_sha = sha256_bytes(readiness_raw)
    native_canary_sha = sha256_bytes(native_canary_raw)
    finality_native_sha = sha256_bytes(finality_native_raw)
    finality_manifest_sha = sha256_bytes(finality_manifest_raw)
    network_trust_sha = sha256_bytes(network_trust_raw)
    artifact_sha = sha256_bytes(artifact_raw)
    pi_sha = sha256_bytes(pi_raw)
    validate_feature_flags(receipt, pi, pi_sha, network_id)
    validate_signer(receipt, readiness, readiness_sha, native_canary_sha)
    validate_finality_native_canary(
        finality_native,
        readiness,
        finality_manifest_sha,
    )
    validate_finality(
        receipt,
        readiness,
        readiness_sha,
        finality_native_sha,
        finality_manifest_sha,
        network_trust_sha,
        network_id,
    )
    validate_candidate(receipt, artifact, artifact_raw, ipa_sha, ipa_bytes, expected_source_revision)

    policy_sha = sha256_bytes(policy_raw)
    (
        maximum_amount,
        maximum_fee,
        policy_from,
        policy_until,
        policy_reviewed_at,
    ) = validate_policy(policy, network_id)
    approval_sha = sha256_bytes(approval_raw)
    return _validate_execution_documents(
        receipt=receipt,
        receipt_raw=receipt_raw,
        approval=approval,
        approval_sha=approval_sha,
        policy_sha=policy_sha,
        maximum_amount=maximum_amount,
        maximum_fee=maximum_fee,
        policy_from=policy_from,
        policy_until=policy_until,
        policy_reviewed_at=policy_reviewed_at,
        consumption=consumption,
        consumption_raw=consumption_raw,
        evidence=evidence,
        evidence_raw=evidence_raw,
        artifact_sha=artifact_sha,
        evaluation_epoch=evaluation_epoch,
        trust=trust,
        finality_manifest_reviewed_at=finality_manifest_reviewed_at,
        network_trust_reviewed_at=network_trust_reviewed_at,
        trusted_first_height=trusted_first_height,
    )


def _validate_execution_documents(
    *,
    receipt: dict[str, Any],
    receipt_raw: bytes,
    approval: dict[str, Any],
    approval_sha: str,
    policy_sha: str,
    maximum_amount: str,
    maximum_fee: str,
    policy_from: int,
    policy_until: int,
    policy_reviewed_at: int,
    consumption: dict[str, Any],
    consumption_raw: bytes,
    evidence: dict[str, Any],
    evidence_raw: bytes,
    artifact_sha: str,
    evaluation_epoch: int,
    trust: dict[str, Any],
    finality_manifest_reviewed_at: int,
    network_trust_reviewed_at: int,
    trusted_first_height: int,
) -> tuple[str, str]:
    network_id = receipt["network"]["networkId"]
    execution = exact_keys(
        receipt["execution"],
        {
            "startedAtEpochSeconds",
            "completedAtEpochSeconds",
            "canaryRunId",
            "evidenceBundleSha256",
            "consumptionReceiptSha256",
            "sendAmountCanonical",
            "feeAmountCanonical",
            "submissionAttemptCount",
            "automaticRetryAttempted",
            "ambiguousSubmissionObserved",
            "terminalStatus",
        } | set(STAGE_NAMES),
        "execution",
    )
    started = require_int(execution["startedAtEpochSeconds"], "execution.startedAtEpochSeconds", 1, 9_999_999_999)
    completed = require_int(execution["completedAtEpochSeconds"], "execution.completedAtEpochSeconds", 1, 9_999_999_999)
    if completed <= started or completed - started > MAX_CANARY_DURATION_SECONDS:
        fail("funded canary duration must be positive and no more than two hours")
    if network_trust_reviewed_at > finality_manifest_reviewed_at:
        fail("finality trust manifest review predates its bound network trust context")
    if finality_manifest_reviewed_at > started:
        fail("finality trust evidence was reviewed after funded execution began")
    if completed > evaluation_epoch + MAX_FUTURE_SKEW_SECONDS or evaluation_epoch - completed > MAX_CANARY_AGE_SECONDS:
        fail("funded canary completion is outside the release-evaluation window")
    recorded = require_int(receipt["receiptRecordedAtEpochSeconds"], "receiptRecordedAtEpochSeconds", 1, 9_999_999_999)
    if recorded < completed or recorded - completed > MAX_RECORD_DELAY_SECONDS or recorded > evaluation_epoch + MAX_FUTURE_SKEW_SECONDS:
        fail("funded canary receipt recording chronology is invalid")
    require_hex64(execution["canaryRunId"], "execution.canaryRunId")
    amount = validate_quantity(execution["sendAmountCanonical"], "execution.sendAmountCanonical")
    fee = validate_quantity(execution["feeAmountCanonical"], "execution.feeAmountCanonical")
    if compare_quantities(amount, maximum_amount) > 0 or compare_quantities(amount, "1") > 0:
        fail("funded send amount exceeds its signed policy or one-XOR ceiling")
    if compare_quantities(fee, maximum_fee) > 0 or compare_quantities(fee, "1") > 0:
        fail("funded fee exceeds its signed policy or one-XOR ceiling")
    require_int(execution["submissionAttemptCount"], "execution.submissionAttemptCount", 1, 1)
    require_bool(execution["automaticRetryAttempted"], "execution.automaticRetryAttempted", False)
    require_bool(execution["ambiguousSubmissionObserved"], "execution.ambiguousSubmissionObserved", False)
    require_string(execution["terminalStatus"], "execution.terminalStatus", "committed")

    observed = validate_execution_stages(receipt)
    if trusted_first_height > execution["finalityReadback"]["finalizedBlockHeight"]:
        fail("trusted first finality height exceeds the attested finalized checkpoint")
    if observed[0] < started or observed[-1] > completed:
        fail("execution stage observation falls outside the canary interval")
    pi_observed = receipt["featureFlags"]["snapshotObservedAtEpochSeconds"]
    if pi_observed > started or started - pi_observed > MAX_PI_AGE_AT_START_SECONDS:
        fail("canary PI capability snapshot is not within five minutes before execution")

    validate_approval(approval, receipt, policy_sha, trust)
    approval_contract = exact_keys(
        receipt["operatorApproval"],
        {
            "scopeNetworkId",
            "approvalNonce",
            "approvalReceiptSha256",
            "lowValuePolicySha256",
            "approvedAtEpochSeconds",
            "expiresAtEpochSeconds",
            "operatorRole",
            "independentApproverRole",
        },
        "operatorApproval",
    )
    require_string(approval_contract["scopeNetworkId"], "operatorApproval.scopeNetworkId", network_id)
    require_string(approval_contract["approvalNonce"], "operatorApproval.approvalNonce", approval["approvalNonce"])
    require_string(approval_contract["approvalReceiptSha256"], "operatorApproval.approvalReceiptSha256", approval_sha)
    require_string(approval_contract["lowValuePolicySha256"], "operatorApproval.lowValuePolicySha256", policy_sha)
    require_int(approval_contract["approvedAtEpochSeconds"], "operatorApproval.approvedAtEpochSeconds", approval["approvedAtEpochSeconds"], approval["approvedAtEpochSeconds"])
    require_int(approval_contract["expiresAtEpochSeconds"], "operatorApproval.expiresAtEpochSeconds", approval["expiresAtEpochSeconds"], approval["expiresAtEpochSeconds"])
    require_string(approval_contract["operatorRole"], "operatorApproval.operatorRole", "release-operator")
    require_string(approval_contract["independentApproverRole"], "operatorApproval.independentApproverRole", "independent-approver")
    if policy_reviewed_at > approval["approvedAtEpochSeconds"]:
        fail("low-value policy was reviewed after the dual-controlled approval")
    if approval["approvedAtEpochSeconds"] > started or approval["expiresAtEpochSeconds"] < completed:
        fail("dual-controlled approval does not cover the complete execution")
    if policy_from > started or policy_until < completed:
        fail("low-value policy does not cover the complete execution")

    consumption_sha = sha256_bytes(consumption_raw)
    require_string(execution["consumptionReceiptSha256"], "execution.consumptionReceiptSha256", consumption_sha)
    reserved_at, finalized_at = validate_consumption(consumption, receipt, approval_sha, trust)
    fee_observed = execution["fee"]["observedAtEpochSeconds"]
    signing_observed = execution["signing"]["observedAtEpochSeconds"]
    if reserved_at < fee_observed or reserved_at > signing_observed:
        fail("one-use approval was not atomically reserved after fee validation and before signing")
    if finalized_at < completed:
        fail("append-only approval consumption was finalized before execution completion")

    evidence_sha = sha256_bytes(evidence_raw)
    require_string(execution["evidenceBundleSha256"], "execution.evidenceBundleSha256", evidence_sha)
    reviewed_at = validate_evidence_bundle(
        evidence,
        receipt,
        artifact_sha,
        approval_sha,
        policy_sha,
        consumption_sha,
        trust,
    )
    if reviewed_at < finalized_at or reviewed_at > recorded:
        fail("independent review did not occur after append-only finalization and before receipt recording")
    return sha256_bytes(receipt_raw), receipt["candidate"]["candidateBindingSha256"]


def validate_admission(
    admission_path: str,
    trust_path: str,
    artifact_path: str,
    ipa_path: str,
    taira_receipt_path: str,
    minamoto_receipt_path: str,
    readiness_path: str,
    expected_source_revision: str,
    evaluation_epoch: int,
) -> tuple[str, str, str]:
    admission, admission_raw = load_json_record(admission_path, 64 * 1024)
    trust, _ = load_json_record(trust_path, 64 * 1024)
    artifact, artifact_raw = load_json_record(artifact_path, MAX_JSON_BYTES, string_limit=4_096)
    taira, taira_raw = load_json_record(taira_receipt_path, 64 * 1024)
    minamoto, minamoto_raw = load_json_record(minamoto_receipt_path, 64 * 1024)
    _, readiness_raw = load_json_record(readiness_path, MAX_JSON_BYTES, string_limit=4_096)
    ipa_sha, ipa_bytes = hash_regular(ipa_path, MAX_IPA_BYTES)
    validate_trust(trust, qualified=True)
    root = exact_keys(
        admission,
        {
            "schemaVersion",
            "contractId",
            "status",
            "platform",
            "recordedAtEpochSeconds",
            "evaluatedAtEpochSeconds",
            "candidate",
            "readinessReceiptSha256",
            "finalityTrustManifestReceiptSha256",
            "taira",
            "minamoto",
            "independentReviewerRole",
            "independentReviewerKeyId",
            "privacy",
            "blockingReasons",
        },
        "funded canary admission",
    )
    require_int(root["schemaVersion"], "admission.schemaVersion", 1, 1)
    require_string(root["contractId"], "admission.contractId", "sora-ios-funded-nexus-canary-admission-v1")
    require_string(root["status"], "admission.status", "qualified")
    require_string(root["platform"], "admission.platform", "ios")
    recorded = require_int(root["recordedAtEpochSeconds"], "admission.recordedAtEpochSeconds", 1, 9_999_999_999)
    evaluated = require_int(root["evaluatedAtEpochSeconds"], "admission.evaluatedAtEpochSeconds", 1, evaluation_epoch)
    if recorded < evaluated or recorded - evaluated > MAX_PI_AGE_AT_START_SECONDS:
        fail("funded canary admission was not recorded immediately after its evaluation")
    if recorded > evaluation_epoch + MAX_FUTURE_SKEW_SECONDS:
        fail("funded canary admission was recorded after the release-evaluation window")
    if evaluation_epoch - evaluated > MAX_CANARY_AGE_SECONDS:
        fail("funded canary admission is older than seven days at release evaluation")
    candidate = exact_keys(
        root["candidate"],
        {
            "bundleIdentifier",
            "developmentTeam",
            "appVersion",
            "buildNumber",
            "appStoreBuildIdentifier",
            "sourceRevision",
            "ipaSha256",
            "ipaBytes",
            "artifactIdentityReceiptSha256",
            "tairaDeploymentManifestSha256",
            "tairaDeploymentAdmissionSha256",
            "tairaCurrentChainId",
            "tairaCurrentGenesisHash",
        },
        "admission.candidate",
    )
    application = artifact.get("application")
    artifact_ipa = artifact.get("ipa")
    if type(application) is not dict or type(artifact_ipa) is not dict:
        fail("artifact identity receipt lacks application or IPA identity")
    require_string(candidate["bundleIdentifier"], "admission.candidate.bundleIdentifier", BUNDLE_IDENTIFIER)
    require_string(candidate["developmentTeam"], "admission.candidate.developmentTeam", DEVELOPMENT_TEAM)
    require_string(candidate["appVersion"], "admission.candidate.appVersion", application.get("appVersion"))
    require_string(candidate["buildNumber"], "admission.candidate.buildNumber", application.get("buildNumber"))
    require_string(candidate["appStoreBuildIdentifier"], "admission.candidate.appStoreBuildIdentifier", application.get("appStoreBuildIdentifier"))
    require_string(candidate["sourceRevision"], "admission.candidate.sourceRevision", expected_source_revision)
    require_string(candidate["sourceRevision"], "admission.candidate.sourceRevision", artifact.get("sourceRevision"))
    require_string(candidate["ipaSha256"], "admission.candidate.ipaSha256", ipa_sha)
    require_int(candidate["ipaBytes"], "admission.candidate.ipaBytes", ipa_bytes, ipa_bytes)
    require_string(artifact_ipa.get("sha256"), "artifact.ipa.sha256", ipa_sha)
    require_int(artifact_ipa.get("bytes"), "artifact.ipa.bytes", ipa_bytes, ipa_bytes)
    require_string(candidate["artifactIdentityReceiptSha256"], "admission.candidate.artifactIdentityReceiptSha256", sha256_bytes(artifact_raw))
    if TAIRA_DEPLOYMENT is None:
        fail("funded admission lacks an authenticated Taira deployment")
    for key in (
        "tairaDeploymentManifestSha256",
        "tairaDeploymentAdmissionSha256",
        "tairaCurrentChainId",
        "tairaCurrentGenesisHash",
    ):
        expected_key = {
            "tairaDeploymentManifestSha256": "manifestSha256",
            "tairaDeploymentAdmissionSha256": "admissionSha256",
            "tairaCurrentChainId": "currentChainId",
            "tairaCurrentGenesisHash": "currentGenesisHash",
        }[key]
        require_string(
            candidate[key],
            f"admission.candidate.{key}",
            TAIRA_DEPLOYMENT[expected_key],
        )
    require_string(root["readinessReceiptSha256"], "admission.readinessReceiptSha256", sha256_bytes(readiness_raw))
    require_hex64(root["finalityTrustManifestReceiptSha256"], "admission.finalityTrustManifestReceiptSha256")
    network_bindings: list[str] = []
    finality_bindings: list[str] = []
    receipt_hashes: list[str] = []
    canary_run_ids: list[str] = []
    approval_nonces: list[str] = []
    challenge_hashes: list[str] = []
    latest_network_receipt_recorded_at = 0
    for network_id, receipt, raw in (("taira", taira, taira_raw), ("minamoto", minamoto, minamoto_raw)):
        require_int(receipt.get("schemaVersion"), f"{network_id}Receipt.schemaVersion", 1, 1)
        require_string(receipt.get("contractId"), f"{network_id}Receipt.contractId", "sora-ios-funded-nexus-canary-v1")
        require_string(receipt.get("status"), f"{network_id}Receipt.status", "qualified")
        require_string(receipt.get("platform"), f"{network_id}Receipt.platform", "ios")
        receipt_recorded = require_int(
            receipt.get("receiptRecordedAtEpochSeconds"),
            f"{network_id}Receipt.receiptRecordedAtEpochSeconds",
            1,
            evaluated,
        )
        latest_network_receipt_recorded_at = max(latest_network_receipt_recorded_at, receipt_recorded)
        validate_network(receipt.get("network"), network_id, f"{network_id}Receipt.network")
        receipt_candidate = receipt.get("candidate")
        receipt_finality = receipt.get("finality")
        receipt_execution = receipt.get("execution")
        receipt_approval = receipt.get("operatorApproval")
        if not all(
            type(value) is dict
            for value in (
                receipt_candidate,
                receipt_finality,
                receipt_execution,
                receipt_approval,
            )
        ):
            fail(f"{network_id} receipt lacks candidate, finality, execution, or approval binding")
        receipt_finality_stage = receipt_execution.get("finalityReadback")
        if type(receipt_finality_stage) is not dict:
            fail(f"{network_id} receipt lacks finality-stage evidence")
        network_binding = exact_keys(
            root[network_id],
            {"networkId", "chainId", "receiptSha256", "candidateBindingSha256", "finalityBindingSha256"},
            f"admission.{network_id}",
        )
        require_string(network_binding["networkId"], f"admission.{network_id}.networkId", network_id)
        require_string(network_binding["chainId"], f"admission.{network_id}.chainId", NETWORKS[network_id]["chainId"])
        receipt_sha = sha256_bytes(raw)
        require_string(network_binding["receiptSha256"], f"admission.{network_id}.receiptSha256", receipt_sha)
        require_string(network_binding["candidateBindingSha256"], f"admission.{network_id}.candidateBindingSha256", receipt_candidate.get("candidateBindingSha256"))
        require_string(network_binding["finalityBindingSha256"], f"admission.{network_id}.finalityBindingSha256", receipt_finality.get("bindingSha256"))
        require_string(receipt_candidate.get("ipaSha256"), f"{network_id}Receipt.candidate.ipaSha256", ipa_sha)
        require_string(receipt_candidate.get("artifactIdentityReceiptSha256"), f"{network_id}Receipt.candidate.artifactIdentityReceiptSha256", sha256_bytes(artifact_raw))
        require_string(receipt_finality.get("finalityTrustManifestReceiptSha256"), f"{network_id}Receipt.finality.finalityTrustManifestReceiptSha256", root["finalityTrustManifestReceiptSha256"])
        receipt_hashes.append(receipt_sha)
        network_bindings.append(network_binding["candidateBindingSha256"])
        finality_bindings.append(
            require_hex64(
                network_binding["finalityBindingSha256"],
                f"admission.{network_id}.finalityBindingSha256",
            )
        )
        canary_run_ids.append(
            require_hex64(
                receipt_execution.get("canaryRunId"),
                f"{network_id}Receipt.execution.canaryRunId",
            )
        )
        approval_nonces.append(
            require_hex64(
                receipt_approval.get("approvalNonce"),
                f"{network_id}Receipt.operatorApproval.approvalNonce",
            )
        )
        challenge_hashes.append(
            require_hex64(
                receipt_finality_stage.get("attestationChallengeSha256"),
                f"{network_id}Receipt.execution.finalityReadback.attestationChallengeSha256",
            )
        )
    if any(
        len(set(values)) != 2
        for values in (
            receipt_hashes,
            network_bindings,
            finality_bindings,
            canary_run_ids,
            approval_nonces,
            challenge_hashes,
        )
    ):
        fail(
            "Taira and Minamoto receipts must use distinct receipt, candidate, "
            "finality, run, approval, and challenge evidence"
        )
    if recorded < latest_network_receipt_recorded_at:
        fail("funded canary admission was recorded before one of its bound network receipts")
    if recorded - latest_network_receipt_recorded_at > MAX_RECORD_DELAY_SECONDS:
        fail("funded canary admission was recorded more than 24 hours after its latest network receipt")
    require_string(root["independentReviewerRole"], "admission.independentReviewerRole", "independent-reviewer")
    require_string(root["independentReviewerKeyId"], "admission.independentReviewerKeyId", trust["authorities"]["independentReviewer"]["keyId"])
    validate_privacy(root["privacy"], "admission.privacy")
    validate_blocking_reasons(root["blockingReasons"], blocked=False)
    return sha256_bytes(admission_raw), receipt_hashes[0], receipt_hashes[1]


def main(argv: list[str]) -> int:
    try:
        if len(argv) < 2:
            fail("missing funded canary validator mode")
        mode = argv[1]
        if mode == "templates" and len(argv) == 5:
            taira, _ = load_json_record(argv[2], 64 * 1024)
            minamoto, _ = load_json_record(argv[3], 64 * 1024)
            trust, _ = load_json_record(argv[4], 64 * 1024)
            same_shape(taira, minamoto)
            same_shape(minamoto, taira)
            validate_blocked_template(taira, taira, "taira")
            validate_blocked_template(minamoto, minamoto, "minamoto")
            if trust.get("status") == "blocked":
                validate_trust(trust, qualified=False)
            elif trust.get("status") == "qualified":
                validate_trust(trust, qualified=True)
            else:
                fail("funded canary trust root status must be blocked or qualified")
        elif mode == "trust" and len(argv) == 3:
            trust, _ = load_json_record(argv[2], 64 * 1024)
            validate_trust(trust, qualified=True)
        elif mode == "qualified" and len(argv) == 21:
            configure_authenticated_taira(argv[20])
            receipt_sha, candidate_binding = validate_qualified_receipt(
                receipt_path=argv[2],
                template_path=argv[3],
                approval_path=argv[4],
                policy_path=argv[5],
                consumption_path=argv[6],
                evidence_path=argv[7],
                finality_manifest_path=argv[8],
                network_trust_path=argv[9],
                pi_path=argv[10],
                readiness_path=argv[11],
                native_canary_path=argv[12],
                finality_native_canary_path=argv[13],
                artifact_path=argv[14],
                ipa_path=argv[15],
                trust_path=argv[16],
                network_id=argv[17],
                expected_source_revision=argv[18],
                evaluation_epoch=int(argv[19]),
            )
            print(f"receiptSha256={receipt_sha}")
            print(f"candidateBindingSha256={candidate_binding}")
        elif mode == "admission" and len(argv) == 12:
            configure_authenticated_taira(argv[11])
            admission_sha, taira_sha, minamoto_sha = validate_admission(
                admission_path=argv[2],
                trust_path=argv[3],
                artifact_path=argv[4],
                ipa_path=argv[5],
                taira_receipt_path=argv[6],
                minamoto_receipt_path=argv[7],
                readiness_path=argv[8],
                expected_source_revision=argv[9],
                evaluation_epoch=int(argv[10]),
            )
            print(f"admissionReceiptSha256={admission_sha}")
            print(f"tairaReceiptSha256={taira_sha}")
            print(f"minamotoReceiptSha256={minamoto_sha}")
        else:
            fail("invalid funded canary validator mode or argument count")
    except (ValidationError, ValueError, OSError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
