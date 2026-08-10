#!/usr/bin/env python3
"""Drive one non-authorizing retained-device case against an exact exported IPA.

This controller never signs an authorization, creates qualification authority,
re-signs an application, or accepts an XCTest-built application as the tested
product.  A protected controller supplies a detached, one-run authorization.
The only application installed here is the exact application extracted from
the admitted production IPA.
"""

from __future__ import annotations

import base64
import hashlib
import importlib.util
import json
import os
import plistlib
import re
import shutil
import stat
import struct
import subprocess
import sys
import tempfile
import time
import unicodedata
import uuid
import zipfile
from pathlib import Path, PurePosixPath
from typing import Any, Optional


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ID = "sora-ios-wallet-migration-exact-ipa-controller-v1"
REQUEST_CONTRACT_ID = "sora-ios-wallet-migration-evidence-authorization-v3"
INSTALLABLE_CLONE_CONTRACT_ID = "sora-ios-wallet-migration-installable-clone-v1"
PREPARATION_CONTRACT_ID = "sora-ios-wallet-migration-case-preparation-v3"
CASE_RECEIPT_CONTRACT_ID = "sora-ios-wallet-migration-case-controller-receipt-v3"
PLATFORM = "ios"
BUNDLE_IDENTIFIER = "co.jp.soramitsu.sora"
TEAM_IDENTIFIER = "YLWWUD25VZ"
EVIDENCE_DIRECTORY = "Library/Application Support/SoraWalletMigrationEvidence"
ENROLLMENT_NONCE_NAME = "enrollment-nonce-v3.bin"
AUTHORIZATION_NAME = "authorization-request-v3.json"
AUTHORIZATION_SIGNATURE_NAME = "authorization-request-v3.sig"
APPLICATION_RECEIPT_NAME = "case-operation-receipt-v3.json"
APPLICATION_RECEIPT_SHA_NAME = "case-operation-receipt-v3.sha256"
CONTROLLER_RECEIPT_NAME = "case-controller-receipt-v3.json"
HARNESS_STATE_NAME = "harness-state-v3.json"
AUTHORITY_KEY_ID_PLIST_KEY = "SoraMigrationEvidenceAuthorizationKeyId"
AUTHORITY_KEY_X963_PLIST_KEY = "SoraMigrationEvidenceAuthorizationPublicKeyX963Base64"
SOURCE_REVISION_PLIST_KEY = "SoraMigrationEvidenceSourceRevision"
QUALIFICATION_CONTRACT_PLIST_KEY = "SoraMigrationEvidenceQualificationContractSha256"
PROJECTOR_RELATIVE = "SoraPassport/Scripts/derive-ios-migration-test-host.py"
PROJECTOR_PATH = ROOT / PROJECTOR_RELATIVE
XCTESTRUN_SANITIZER_RELATIVE = (
    "SoraPassport/Scripts/sanitize-ios-migration-xctestrun.py"
)
XCTESTRUN_SANITIZER_PATH = ROOT / XCTESTRUN_SANITIZER_RELATIVE
RAW_APP_TREE_PREFIX = b"SORA-IOS-MIGRATION-RAW-APP-TREE-V1\0"
WALLET_INPUT_TREE_PREFIX = b"SORA-IOS-MIGRATION-WALLET-INPUT-TREE-V1\0"
MAX_IPA_BYTES = 4 * 1024 * 1024 * 1024
MAX_UNCOMPRESSED_BYTES = 8 * 1024 * 1024 * 1024
MAX_FILE_BYTES = 2 * 1024 * 1024 * 1024
MAX_FILE_COUNT = 100_000
MAX_JSON_BYTES = 8 * 1024 * 1024
MAX_TOOL_OUTPUT_BYTES = 16 * 1024 * 1024
MAX_SIGNATURE_BYTES = 128
MAX_APPLICATION_RECEIPT_BYTES = 256 * 1024
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SHA1_RE = re.compile(r"^[0-9a-f]{40}$")
SOURCE_REVISION_RE = re.compile(r"^[0-9a-f]{40}$")
SAFE_COMPONENT_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9._+@-]{0,255}$")
SAFE_ARTIFACT_COMPONENT_RE = re.compile(
    r"^[A-Za-z0-9_](?:[A-Za-z0-9._+@ -]{0,254}[A-Za-z0-9._+@-])?$"
)
KEY_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
DEVICE_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9-]{7,127}$")
VERSION_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$")
TEST_IDENTIFIER_RE = re.compile(
    r"^(?:SoraPassportUITests[./])?RetainedMigrationEvidenceUITests/"
    r"testExecuteAuthorizedRetainedMigrationCase\(\)$"
)
TEST_RECEIPT_ATTACHMENT_RE = re.compile(
    r"^case-operation-receipt-v3-([0-9a-f]{64})\.json$"
)
SAFE_TOOL_ENV = {
    "PATH": "/usr/bin:/bin",
    "LANG": "C",
    "LC_ALL": "C",
    "TMPDIR": "/private/tmp",
}
NONAUTHORIZING_BLOCKER = (
    "Observed exact-IPA case only: this controller cannot sign, review, qualify, "
    "sequence, promote, upload, or enable a release."
)
INSTALLABLE_CLONE_NONAUTHORIZING_BLOCKER = (
    "Observed installable clone only: no rebuilt app is accepted; this controller cannot "
    "authorize, review, qualify, sequence, promote, upload, or enable a release."
)
KEYCHAIN_CASES = {
    "mnemonic-12",
    "mnemonic-15-retained",
    "mnemonic-24",
    "raw-seed",
    "legacy-secret",
    "watch-only",
    "missing-secret",
    "corrupt-secret",
}
DEVICE_CASES = {
    "reinstall-upgrade",
    "rollback",
    "low-storage",
    "recovery-archive-export",
    "process-death-restart",
    "interruption-before-secret-retention",
    "interruption-after-secret-retention",
    "interruption-after-core-data-commit",
    "interruption-after-network-staging",
    "interruption-before-activation",
}
INTERRUPTION_CHECKPOINTS = {
    "process-death-restart": "after-core-data-commit",
    "interruption-before-secret-retention": "before-secret-retention",
    "interruption-after-secret-retention": "after-secret-retention",
    "interruption-after-core-data-commit": "after-core-data-commit",
    "interruption-after-network-staging": "after-network-staging",
    "interruption-before-activation": "before-activation",
}
RECOVERY_ROUTE_CASES = {
    "missing-secret",
    "corrupt-secret",
    "rollback",
    "low-storage",
    "recovery-archive-export",
    "process-death-restart",
    "interruption-after-secret-retention",
    "interruption-after-core-data-commit",
    "interruption-after-network-staging",
    "interruption-before-activation",
}
SUCCESS_ROUTE_CASES = {
    "mnemonic-12",
    "mnemonic-15-retained",
    "mnemonic-24",
    "raw-seed",
    "legacy-secret",
    "watch-only",
    "reinstall-upgrade",
    "interruption-before-secret-retention",
}
KEYCHAIN_SIGNING_EXPECTATIONS = {
    "mnemonic-12": (True, True),
    "mnemonic-15-retained": (True, True),
    "mnemonic-24": (True, True),
    "raw-seed": (True, True),
    "legacy-secret": (True, True),
    "watch-only": (False, False),
    "missing-secret": (False, False),
    "corrupt-secret": (False, False),
}
REQUEST_KEYS = {
    "schemaVersion",
    "contractId",
    "platform",
    "purpose",
    "releaseAuthorized",
    "authorizationId",
    "authorizationKeyId",
    "signatureAlgorithm",
    "runId",
    "runChallengeSha256",
    "sourceRevision",
    "qualificationContractSha256",
    "productionIpaSha256",
    "installedAppRawTreeSha256",
    "installedExecutableSha256",
    "productionCanonicalProjectionSha256",
    "installedCanonicalProjectionSha256",
    "canonicalProjectionReceiptSha256",
    "canonicalProjectorSourceSha256",
    "preparedWalletInputTreeSha256",
    "enrollmentNonceSha256",
    "caseKind",
    "caseId",
    "issuedAtEpochSeconds",
    "expiresAtEpochSeconds",
    "maximumLaunchCount",
}
CLONE_BOUND_AUTHORIZATION_KEYS = {
    "qualificationContractSha256",
    "productionIpaSha256",
    "installedAppRawTreeSha256",
    "installedExecutableSha256",
    "productionCanonicalProjectionSha256",
    "installedCanonicalProjectionSha256",
    "canonicalProjectionReceiptSha256",
    "canonicalProjectorSourceSha256",
}
INSTALLABLE_CLONE_RECEIPT_KEYS = {
    "schemaVersion",
    "contractId",
    "platform",
    "status",
    "releaseAuthorized",
    "qualificationContractSha256",
    "productionIpaSha256",
    "productionCanonicalProjectionSha256",
    "installedAppRawTreeSha256",
    "installedAppRawTreeRecordByteCount",
    "installedAppFileCount",
    "installedCanonicalProjectionSha256",
    "installedExecutableSha256",
    "installedExecutableByteCount",
    "canonicalProjectionReceiptSha256",
    "canonicalProjectorSourceSha256",
    "registeredDeviceProvisioningProfileSha256",
    "registeredDeviceSigningCertificateSha1",
    "registeredDeviceUdidSha256",
    "checks",
    "blockingReasons",
}
INSTALLABLE_CLONE_CHECK_KEYS = {
    "exactProductionIpaExtracted",
    "registeredDeviceProfileVerified",
    "productionIdentityPreserved",
    "canonicalProjectionEqual",
    "installedCloneCodeSignatureDeepStrictVerified",
    "rebuiltApplicationAccepted",
    "qualificationCreated",
}


class ControllerError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise ControllerError(message)


def duplicate_rejecting_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            fail(f"JSON contains duplicate key: {key}")
        result[key] = value
    return result


def canonical_json(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        + "\n"
    ).encode("utf-8")


def parse_canonical_json(raw: bytes, label: str) -> dict[str, Any]:
    if not raw or len(raw) > MAX_JSON_BYTES:
        fail(f"{label} is empty or exceeds its byte bound")
    try:
        value = json.loads(
            raw.decode("utf-8", errors="strict"),
            object_pairs_hook=duplicate_rejecting_object,
            parse_constant=lambda token: fail(f"{label} contains invalid constant {token}"),
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fail(f"{label} is invalid canonical JSON: {error}")
    if type(value) is not dict or canonical_json(value) != raw:
        fail(f"{label} is not the exact canonical JSON encoding")
    return value


def require_exact_keys(value: dict[str, Any], expected: set[str], label: str) -> None:
    if set(value) != expected:
        fail(f"{label} has an unexpected or missing key")


def require_sha256(value: Any, label: str) -> str:
    if type(value) is not str or SHA256_RE.fullmatch(value) is None or value == "0" * 64:
        fail(f"{label} must be a nonzero lowercase SHA-256")
    return value


def require_uuid(value: Any, label: str) -> str:
    if type(value) is not str:
        fail(f"{label} must be a canonical UUID")
    try:
        parsed = uuid.UUID(value)
    except ValueError:
        fail(f"{label} must be a canonical UUID")
    if parsed.int == 0 or str(parsed) != value:
        fail(f"{label} must be a canonical lowercase nonzero UUID")
    return value


def validate_authorization_request(
    raw: bytes,
    *,
    now: Optional[int] = None,
) -> dict[str, Any]:
    request = parse_canonical_json(raw, "migration evidence authorization")
    require_exact_keys(request, REQUEST_KEYS, "migration evidence authorization")
    if (
        type(request["schemaVersion"]) is not int
        or request["schemaVersion"] != 3
        or request["contractId"] != REQUEST_CONTRACT_ID
        or request["platform"] != PLATFORM
        or request["purpose"] != "retained-wallet-migration-observation"
        or request["releaseAuthorized"] is not False
        or request["signatureAlgorithm"] != "ecdsa-p256-sha256"
    ):
        fail("migration evidence authorization has an invalid fixed contract")
    require_uuid(request["authorizationId"], "authorization ID")
    require_uuid(request["runId"], "run ID")
    key_id = request["authorizationKeyId"]
    if type(key_id) is not str or KEY_ID_RE.fullmatch(key_id) is None:
        fail("authorization key ID is invalid")
    require_sha256(request["runChallengeSha256"], "run challenge")
    source_revision = request["sourceRevision"]
    if (
        type(source_revision) is not str
        or SOURCE_REVISION_RE.fullmatch(source_revision) is None
        or source_revision == "0" * 40
    ):
        fail("source revision must be one lowercase 40-character revision")
    for key in (
        "qualificationContractSha256",
        "productionIpaSha256",
        "installedAppRawTreeSha256",
        "installedExecutableSha256",
        "productionCanonicalProjectionSha256",
        "installedCanonicalProjectionSha256",
        "canonicalProjectionReceiptSha256",
        "canonicalProjectorSourceSha256",
        "preparedWalletInputTreeSha256",
        "enrollmentNonceSha256",
    ):
        require_sha256(request[key], key)
    if (
        request["productionCanonicalProjectionSha256"]
        != request["installedCanonicalProjectionSha256"]
    ):
        fail("authorization canonical production/installable projections differ")
    case_kind = request["caseKind"]
    case_id = request["caseId"]
    if type(case_kind) is not str or type(case_id) is not str:
        fail("authorization case kind or ID is invalid")
    if (case_kind == "keychain" and case_id not in KEYCHAIN_CASES) or (
        case_kind == "device" and case_id not in DEVICE_CASES
    ) or case_kind not in {"keychain", "device"}:
        fail("authorization case kind and ID are not a reviewed pair")
    issued = request["issuedAtEpochSeconds"]
    expires = request["expiresAtEpochSeconds"]
    launch_count = request["maximumLaunchCount"]
    current = int(time.time()) if now is None else now
    if (
        type(issued) is not int
        or type(expires) is not int
        or type(launch_count) is not int
        or issued < 1_577_836_800
        or issued > current + 300
        or expires < current
        or expires < issued
        or expires - issued > 48 * 60 * 60
        or not 1 <= launch_count <= 8
    ):
        fail("authorization chronology or launch count is invalid")
    return request


def canonical_projector_source_sha256() -> str:
    try:
        digest, byte_count = hash_extracted_regular(
            PROJECTOR_PATH,
            MAX_FILE_BYTES,
            "canonical projector source",
        )
    except OSError as error:
        fail(f"canonical projector source cannot be admitted: {error}")
    if byte_count <= 0:
        fail("canonical projector source is empty")
    return digest


def load_xctestrun_sanitizer() -> Any:
    metadata = os.lstat(XCTESTRUN_SANITIZER_PATH)
    if not stat.S_ISREG(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode):
        fail("xctestrun sanitizer source is absent or symbolic")
    spec = importlib.util.spec_from_file_location(
        "sora_ios_migration_xctestrun_sanitizer",
        XCTESTRUN_SANITIZER_PATH,
    )
    if spec is None or spec.loader is None:
        fail("xctestrun sanitizer source cannot be loaded")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    final = os.lstat(XCTESTRUN_SANITIZER_PATH)
    if stable_identity(metadata) != stable_identity(final):
        fail("xctestrun sanitizer source changed while being loaded")
    try:
        module.lint_contract()
    except module.SanitizerError as error:
        fail(f"xctestrun sanitizer contract is invalid: {error}")
    return module


def validate_installable_clone_receipt(raw: bytes) -> dict[str, Any]:
    receipt = parse_canonical_json(raw, "protected installable-clone receipt")
    require_exact_keys(
        receipt,
        INSTALLABLE_CLONE_RECEIPT_KEYS,
        "protected installable-clone receipt",
    )
    if (
        type(receipt["schemaVersion"]) is not int
        or receipt["schemaVersion"] != 1
        or receipt["contractId"] != INSTALLABLE_CLONE_CONTRACT_ID
        or receipt["platform"] != PLATFORM
        or receipt["status"] != "observed"
        or receipt["releaseAuthorized"] is not False
    ):
        fail("protected installable-clone receipt has an invalid fixed contract")
    for key in (
        "qualificationContractSha256",
        "productionIpaSha256",
        "productionCanonicalProjectionSha256",
        "installedAppRawTreeSha256",
        "installedCanonicalProjectionSha256",
        "installedExecutableSha256",
        "canonicalProjectionReceiptSha256",
        "canonicalProjectorSourceSha256",
        "registeredDeviceProvisioningProfileSha256",
        "registeredDeviceUdidSha256",
    ):
        require_sha256(receipt[key], key)
    tree_record_bytes = receipt["installedAppRawTreeRecordByteCount"]
    file_count = receipt["installedAppFileCount"]
    executable_bytes = receipt["installedExecutableByteCount"]
    if (
        type(tree_record_bytes) is not int
        or type(file_count) is not int
        or type(executable_bytes) is not int
        or tree_record_bytes <= len(RAW_APP_TREE_PREFIX)
        or tree_record_bytes > MAX_UNCOMPRESSED_BYTES
        or not 1 <= file_count <= MAX_FILE_COUNT
        or not 1 <= executable_bytes <= MAX_FILE_BYTES
    ):
        fail("protected installable-clone receipt has invalid byte or file counts")
    signing_certificate = receipt["registeredDeviceSigningCertificateSha1"]
    if (
        type(signing_certificate) is not str
        or SHA1_RE.fullmatch(signing_certificate) is None
        or signing_certificate == "0" * 40
    ):
        fail("protected installable-clone receipt has an invalid signing certificate")
    checks = receipt["checks"]
    require_exact_keys(
        checks if type(checks) is dict else {},
        INSTALLABLE_CLONE_CHECK_KEYS,
        "protected installable-clone checks",
    )
    if any(type(value) is not bool for value in checks.values()) or checks != {
        "exactProductionIpaExtracted": True,
        "registeredDeviceProfileVerified": True,
        "productionIdentityPreserved": True,
        "canonicalProjectionEqual": True,
        "installedCloneCodeSignatureDeepStrictVerified": True,
        "rebuiltApplicationAccepted": False,
        "qualificationCreated": False,
    }:
        fail("protected installable-clone checks are not all reviewed facts")
    if receipt["blockingReasons"] != [INSTALLABLE_CLONE_NONAUTHORIZING_BLOCKER]:
        fail("protected installable-clone receipt is not explicitly non-authorizing")
    if (
        receipt["productionCanonicalProjectionSha256"]
        != receipt["installedCanonicalProjectionSha256"]
    ):
        fail("protected installable-clone canonical projections differ")
    if (
        receipt["canonicalProjectorSourceSha256"]
        != canonical_projector_source_sha256()
    ):
        fail("protected installable-clone receipt names a different projector source")
    return receipt


def validate_authorization_clone_binding(
    request: dict[str, Any],
    production_identity: dict[str, Any],
    clone_receipt: dict[str, Any],
) -> None:
    if (
        request["authorizationKeyId"] != production_identity["authorityKeyId"]
        or request["sourceRevision"] != production_identity["sourceRevision"]
        or request["qualificationContractSha256"]
        != production_identity["qualificationContractSha256"]
        or request["productionIpaSha256"] != production_identity["ipaSha256"]
    ):
        fail("authorization request differs from the exact production IPA identity")
    if (
        clone_receipt["qualificationContractSha256"]
        != production_identity["qualificationContractSha256"]
        or clone_receipt["productionIpaSha256"] != production_identity["ipaSha256"]
    ):
        fail("protected installable-clone receipt differs from the production IPA")
    for key in CLONE_BOUND_AUTHORIZATION_KEYS:
        if request[key] != clone_receipt[key]:
            fail(f"authorization request differs from protected clone binding: {key}")


def safe_absolute_input(path_raw: str, label: str) -> Path:
    path = Path(path_raw)
    if (
        str(path) != path_raw
        or path.anchor != "/"
        or path == Path("/")
        or any(part in ("", ".", "..") for part in path.parts[1:])
    ):
        fail(f"{label} must be a canonical non-root absolute path")
    return path


def open_directory(path: Path, label: str, *, private: bool) -> int:
    if not hasattr(os, "O_NOFOLLOW") or not hasattr(os, "O_DIRECTORY"):
        fail("this host lacks required no-follow directory admission")
    flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY | getattr(os, "O_CLOEXEC", 0)
    descriptor: Optional[int] = None
    try:
        descriptor = os.open("/", flags)
        for component in path.parts[1:]:
            child = os.open(component, flags, dir_fd=descriptor)
            os.close(descriptor)
            descriptor = child
        metadata = os.fstat(descriptor)
        if not stat.S_ISDIR(metadata.st_mode):
            fail(f"{label} is not a directory")
        if private and (
            metadata.st_uid != os.getuid() or stat.S_IMODE(metadata.st_mode) != 0o700
        ):
            fail(f"{label} must be current-user-owned mode 0700")
        return descriptor
    except Exception:
        if descriptor is not None:
            os.close(descriptor)
        raise


def stable_identity(metadata: os.stat_result) -> tuple[int, ...]:
    return (
        metadata.st_dev,
        metadata.st_ino,
        metadata.st_mode,
        metadata.st_size,
        metadata.st_mtime_ns,
        metadata.st_ctime_ns,
        metadata.st_nlink,
    )


def read_regular(path_raw: str, maximum: int, label: str) -> tuple[bytes, str, int]:
    path = safe_absolute_input(path_raw, label)
    parent = open_directory(path.parent, f"{label} parent", private=True)
    descriptor: Optional[int] = None
    try:
        descriptor = os.open(
            path.name,
            os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0),
            dir_fd=parent,
        )
        before = os.fstat(descriptor)
        if (
            not stat.S_ISREG(before.st_mode)
            or before.st_uid != os.getuid()
            or before.st_nlink != 1
            or not 0 < before.st_size <= maximum
        ):
            fail(f"{label} is not one bounded, owned, unique regular file")
        result = bytearray()
        while True:
            chunk = os.read(descriptor, min(1024 * 1024, maximum - len(result) + 1))
            if not chunk:
                break
            result.extend(chunk)
            if len(result) > maximum:
                fail(f"{label} exceeds its byte bound")
        after = os.fstat(descriptor)
        named = os.stat(path.name, dir_fd=parent, follow_symlinks=False)
        if (
            len(result) != before.st_size
            or stable_identity(before) != stable_identity(after)
            or stable_identity(before) != stable_identity(named)
        ):
            fail(f"{label} changed while being read")
        raw = bytes(result)
        return raw, hashlib.sha256(raw).hexdigest(), len(raw)
    finally:
        if descriptor is not None:
            os.close(descriptor)
        os.close(parent)


def open_private_regular(path_raw: str, maximum: int, label: str) -> tuple[int, int, os.stat_result]:
    path = safe_absolute_input(path_raw, label)
    parent = open_directory(path.parent, f"{label} parent", private=True)
    try:
        descriptor = os.open(
            path.name,
            os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0),
            dir_fd=parent,
        )
        metadata = os.fstat(descriptor)
        if (
            not stat.S_ISREG(metadata.st_mode)
            or metadata.st_uid != os.getuid()
            or metadata.st_nlink != 1
            or not 0 < metadata.st_size <= maximum
        ):
            os.close(descriptor)
            fail(f"{label} is not one bounded, owned, unique regular file")
        named = os.stat(path.name, dir_fd=parent, follow_symlinks=False)
        if stable_identity(named) != stable_identity(metadata):
            os.close(descriptor)
            fail(f"{label} changed during no-follow admission")
        return descriptor, parent, metadata
    except Exception:
        os.close(parent)
        raise


def hash_descriptor(descriptor: int, maximum: int, label: str) -> tuple[str, int]:
    os.lseek(descriptor, 0, os.SEEK_SET)
    digest = hashlib.sha256()
    size = 0
    while True:
        chunk = os.read(descriptor, 1024 * 1024)
        if not chunk:
            break
        size += len(chunk)
        if size > maximum:
            fail(f"{label} exceeds its byte bound")
        digest.update(chunk)
    return digest.hexdigest(), size


def hash_extracted_regular(path: Path, maximum: int, label: str) -> tuple[str, int]:
    before_path = os.lstat(path)
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0))
    try:
        before = os.fstat(descriptor)
        if (
            not stat.S_ISREG(before.st_mode)
            or before.st_nlink != 1
            or not 0 <= before.st_size <= maximum
            or stable_identity(before_path) != stable_identity(before)
        ):
            fail(f"{label} is not one bounded unique regular file")
        digest, size = hash_descriptor(descriptor, maximum, label)
        after = os.fstat(descriptor)
        named = os.lstat(path)
        if (
            size != before.st_size
            or stable_identity(before) != stable_identity(after)
            or stable_identity(before) != stable_identity(named)
        ):
            fail(f"{label} changed while being hashed")
        return digest, size
    finally:
        os.close(descriptor)


def read_extracted_regular(path: Path, maximum: int, label: str) -> bytes:
    before_path = os.lstat(path)
    descriptor = os.open(
        path,
        os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0),
    )
    try:
        before = os.fstat(descriptor)
        if (
            not stat.S_ISREG(before.st_mode)
            or before.st_nlink != 1
            or not 0 < before.st_size <= maximum
            or stable_identity(before_path) != stable_identity(before)
        ):
            fail(f"{label} is not one bounded unique regular file")
        raw = bytearray()
        while True:
            chunk = os.read(descriptor, min(1024 * 1024, maximum + 1 - len(raw)))
            if not chunk:
                break
            raw.extend(chunk)
            if len(raw) > maximum:
                fail(f"{label} exceeds its byte bound")
        after = os.fstat(descriptor)
        named = os.lstat(path)
        if (
            len(raw) != before.st_size
            or stable_identity(before) != stable_identity(after)
            or stable_identity(before) != stable_identity(named)
        ):
            fail(f"{label} changed while being read")
        return bytes(raw)
    finally:
        os.close(descriptor)


def complete_tree_record(root: Path, prefix: bytes, label: str) -> tuple[str, int, int]:
    root_before = os.lstat(root)
    if not stat.S_ISDIR(root_before.st_mode) or root_before.st_uid != os.getuid():
        fail(f"{label} root is not an owned directory")
    normalized: set[str] = set()
    inodes: set[tuple[int, int]] = {(root_before.st_dev, root_before.st_ino)}
    entries: list[tuple[str, bool, int, bytes]] = []
    total = 0

    def walk(directory: Path, relative_prefix: str, expected: os.stat_result) -> int:
        before = os.lstat(directory)
        if stable_identity(before) != stable_identity(expected):
            fail(f"{label} directory changed before enumeration")
        try:
            children = sorted(
                list(os.scandir(directory)), key=lambda child: child.name.encode("utf-8")
            )
        except OSError as error:
            fail(f"{label} directory cannot be enumerated: {error}")
        if not children:
            fail(f"{label} contains an empty directory")
        descendant_files = 0
        nonlocal total
        for child in children:
            component = child.name
            try:
                component_bytes = component.encode("utf-8", errors="strict")
            except UnicodeEncodeError:
                fail(f"{label} contains a non-UTF-8 path")
            if SAFE_ARTIFACT_COMPONENT_RE.fullmatch(component) is None:
                fail(f"{label} contains an unsafe path component")
            relative = component if not relative_prefix else f"{relative_prefix}/{component}"
            folded = unicodedata.normalize("NFC", relative).casefold()
            if folded in normalized:
                fail(f"{label} contains an NFC/casefold path collision")
            normalized.add(folded)
            metadata = os.lstat(child.path)
            inode = (metadata.st_dev, metadata.st_ino)
            if inode in inodes:
                fail(f"{label} contains a hard link or directory alias")
            inodes.add(inode)
            if stat.S_ISDIR(metadata.st_mode):
                if metadata.st_uid != os.getuid():
                    fail(f"{label} contains a foreign directory")
                child_count = walk(Path(child.path), relative, metadata)
                if child_count <= 0:
                    fail(f"{label} contains an empty semantic directory")
                descendant_files += child_count
                continue
            if (
                not stat.S_ISREG(metadata.st_mode)
                or metadata.st_uid != os.getuid()
                or metadata.st_nlink != 1
            ):
                fail(f"{label} contains a symbolic, special, linked, or foreign node")
            digest, size = hash_extracted_regular(
                Path(child.path), MAX_FILE_BYTES, f"{label} file"
            )
            total += size
            if total > MAX_UNCOMPRESSED_BYTES:
                fail(f"{label} exceeds its aggregate byte bound")
            entries.append(
                (relative, bool(metadata.st_mode & 0o111), size, bytes.fromhex(digest))
            )
            descendant_files += 1
            if len(entries) > MAX_FILE_COUNT:
                fail(f"{label} exceeds its file-count bound")
        after = os.lstat(directory)
        if stable_identity(before) != stable_identity(after):
            fail(f"{label} directory changed during enumeration")
        return descendant_files

    walk(root, "", root_before)
    root_after = os.lstat(root)
    if stable_identity(root_before) != stable_identity(root_after) or not entries:
        fail(f"{label} root changed or has no files")
    record = bytearray(prefix)
    record.extend(struct.pack(">I", len(entries)))
    for relative, executable, size, digest in sorted(
        entries, key=lambda entry: entry[0].encode("utf-8")
    ):
        path_bytes = relative.encode("utf-8")
        record.extend(struct.pack(">I", len(path_bytes)))
        record.extend(path_bytes)
        record.append(0x45 if executable else 0x4E)
        record.extend(struct.pack(">Q", size))
        record.extend(digest)
    return hashlib.sha256(record).hexdigest(), len(record), len(entries)


def parse_strict_ecdsa_der(raw: bytes) -> tuple[int, int]:
    # P-256 signatures are a short DER SEQUENCE of two minimally encoded,
    # positive INTEGERs.  Reject alternate encodings before asking OpenSSL.
    if not 8 <= len(raw) <= 72 or raw[0] != 0x30 or raw[1] != len(raw) - 2:
        fail("authorization signature is not one canonical short DER sequence")
    offset = 2
    values: list[int] = []
    for label in ("r", "s"):
        if offset + 2 > len(raw) or raw[offset] != 0x02:
            fail(f"authorization signature {label} is not a DER INTEGER")
        length = raw[offset + 1]
        offset += 2
        if length == 0 or offset + length > len(raw):
            fail(f"authorization signature {label} has an invalid length")
        encoded = raw[offset : offset + length]
        offset += length
        if encoded[0] & 0x80 or (
            len(encoded) > 1 and encoded[0] == 0 and not (encoded[1] & 0x80)
        ):
            fail(f"authorization signature {label} is not minimally positive")
        values.append(int.from_bytes(encoded, "big"))
    if offset != len(raw):
        fail("authorization signature has trailing DER data")
    order = int("FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551", 16)
    if any(value <= 0 or value >= order for value in values):
        fail("authorization signature scalar is outside P-256")
    return values[0], values[1]


def p256_spki_der(point: bytes) -> bytes:
    if len(point) != 65 or point[0] != 0x04 or point[1:] == b"\0" * 64:
        fail("embedded evidence authority is not one uncompressed P-256 point")
    prefix = bytes.fromhex("3059301306072a8648ce3d020106082a8648ce3d030107034200")
    return prefix + point


def validate_p256_public_point(point: bytes) -> bytes:
    public_der = p256_spki_der(point)
    result = subprocess.run(
        ["/usr/bin/openssl", "pkey", "-pubin", "-inform", "DER", "-noout"],
        input=public_der,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=SAFE_TOOL_ENV,
        timeout=30,
    )
    if (
        result.returncode != 0
        or result.stdout
        or len(result.stderr) > MAX_JSON_BYTES
    ):
        fail("embedded evidence authority is not a valid P-256 public point")
    return public_der


def verify_authorization_signature(
    request_raw: bytes,
    signature_raw: bytes,
    public_point: bytes,
) -> None:
    parse_strict_ecdsa_der(signature_raw)
    public_der = validate_p256_public_point(public_point)
    with tempfile.TemporaryDirectory(prefix="sora-ios-evidence-signature-") as temp:
        directory = Path(temp)
        os.chmod(directory, 0o700)
        public_path = directory / "authority.der"
        request_path = directory / "request.json"
        signature_path = directory / "request.sig"
        for path, data in (
            (public_path, public_der),
            (request_path, request_raw),
            (signature_path, signature_raw),
        ):
            descriptor = os.open(
                path,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                0o600,
            )
            try:
                view = memoryview(data)
                while view:
                    written = os.write(descriptor, view)
                    if written <= 0:
                        fail("authorization verification input could not be written")
                    view = view[written:]
                os.fsync(descriptor)
            finally:
                os.close(descriptor)
        result = subprocess.run(
            [
                "/usr/bin/openssl",
                "dgst",
                "-sha256",
                "-verify",
                str(public_path),
                "-keyform",
                "DER",
                "-signature",
                str(signature_path),
                str(request_path),
            ],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=SAFE_TOOL_ENV,
            timeout=30,
        )
        if (
            result.returncode != 0
            or result.stdout != b"Verified OK\n"
            or result.stderr
        ):
            fail("authorization signature is not valid for the embedded evidence authority")


def safe_zip_path(info: zipfile.ZipInfo) -> PurePosixPath:
    pure = PurePosixPath(info.filename)
    canonical = "/".join(pure.parts) + ("/" if info.is_dir() else "")
    mode = (info.external_attr >> 16) & 0xFFFF
    if (
        not info.filename
        or info.filename.startswith("/")
        or "\\" in info.filename
        or any(
            part in ("", ".", "..")
            or SAFE_ARTIFACT_COMPONENT_RE.fullmatch(part) is None
            for part in pure.parts
        )
        or canonical != info.filename
        or info.flag_bits & 0x1
        or (mode and not (stat.S_ISREG(mode) or stat.S_ISDIR(mode)))
    ):
        fail(f"production IPA contains an unsafe member: {info.filename!r}")
    return pure


def extract_validated_archive(
    archive: zipfile.ZipFile,
    entries: list[zipfile.ZipInfo],
    destination: Path,
) -> None:
    directories: set[Path] = {destination}
    for entry in entries:
        pure = safe_zip_path(entry)
        target = destination.joinpath(*pure.parts)
        if destination not in target.parents and target != destination:
            fail("production IPA extraction escaped its private root")
        if entry.is_dir():
            target.mkdir(mode=0o700, parents=True, exist_ok=True)
            directories.add(target)
            continue
        target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        current = target.parent
        while current != destination:
            directories.add(current)
            current = current.parent
        descriptor = os.open(
            target,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
            0o600,
        )
        try:
            with archive.open(entry, "r") as source:
                total = 0
                while True:
                    chunk = source.read(1024 * 1024)
                    if not chunk:
                        break
                    total += len(chunk)
                    if total > entry.file_size or total > MAX_FILE_BYTES:
                        fail("production IPA member exceeds its admitted size")
                    view = memoryview(chunk)
                    while view:
                        written = os.write(descriptor, view)
                        if written <= 0:
                            fail("production IPA member could not be extracted")
                        view = view[written:]
                if total != entry.file_size:
                    fail("production IPA member differs from its central-directory size")
            os.fsync(descriptor)
            mode = (entry.external_attr >> 16) & 0xFFFF
            os.fchmod(descriptor, 0o755 if mode & 0o111 else 0o644)
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
    for directory in sorted(directories, key=lambda item: len(item.parts), reverse=True):
        os.chmod(directory, 0o755 if directory != destination else 0o700)


def inspect_and_extract_ipa(ipa_path: str, destination: Path) -> dict[str, Any]:
    if destination.exists() or destination.is_symlink():
        fail("IPA extraction destination must be fresh")
    destination.mkdir(mode=0o700)
    ipa_descriptor, ipa_parent, ipa_before = open_private_regular(
        ipa_path, MAX_IPA_BYTES, "production IPA"
    )
    ipa_sha, ipa_size = hash_descriptor(
        ipa_descriptor, MAX_IPA_BYTES, "production IPA"
    )
    try:
        os.lseek(ipa_descriptor, 0, os.SEEK_SET)
        with os.fdopen(os.dup(ipa_descriptor), "rb") as source, zipfile.ZipFile(
            source, "r", allowZip64=True
        ) as archive:
            entries = archive.infolist()
            if not entries or len(entries) > MAX_FILE_COUNT:
                fail("production IPA has an empty or unbounded entry inventory")
            seen: set[str] = set()
            normalized: set[str] = set()
            total = 0
            app_roots: set[str] = set()
            for entry in entries:
                pure = safe_zip_path(entry)
                folded = unicodedata.normalize("NFC", entry.filename).casefold()
                if entry.filename in seen or folded in normalized:
                    fail("production IPA contains a duplicate or normalized path collision")
                seen.add(entry.filename)
                normalized.add(folded)
                total += entry.file_size
                if total > MAX_UNCOMPRESSED_BYTES:
                    fail("production IPA exceeds its uncompressed byte bound")
                if (
                    len(pure.parts) >= 2
                    and pure.parts[0] == "Payload"
                    and pure.parts[1].endswith(".app")
                ):
                    app_roots.add("/".join(pure.parts[:2]))
            if len(app_roots) != 1:
                fail("production IPA must contain exactly one top-level application")
            extract_validated_archive(archive, entries, destination)
            app_relative = next(iter(app_roots))
    except (OSError, zipfile.BadZipFile, zipfile.LargeZipFile) as error:
        fail(f"production IPA is not a valid bounded ZIP: {error}")
    finally:
        final_sha, final_size = hash_descriptor(
            ipa_descriptor, MAX_IPA_BYTES, "production IPA final recheck"
        )
        ipa_after = os.fstat(ipa_descriptor)
        ipa_named = os.stat(
            Path(ipa_path).name, dir_fd=ipa_parent, follow_symlinks=False
        )
        os.close(ipa_descriptor)
        os.close(ipa_parent)
    if (
        final_sha != ipa_sha
        or final_size != ipa_size
        or stable_identity(ipa_before) != stable_identity(ipa_after)
        or stable_identity(ipa_before) != stable_identity(ipa_named)
    ):
        fail("production IPA changed during exact extraction")
    app_path = destination / app_relative
    info_path = app_path / "Info.plist"
    if not info_path.is_file() or info_path.is_symlink():
        fail("production IPA application lacks a regular Info.plist")
    try:
        info = plistlib.loads(info_path.read_bytes())
    except (OSError, plistlib.InvalidFileException) as error:
        fail(f"production IPA Info.plist is invalid: {error}")
    if type(info) is not dict or info.get("CFBundleIdentifier") != BUNDLE_IDENTIFIER:
        fail("production IPA does not contain the reviewed production bundle")
    executable_name = info.get("CFBundleExecutable")
    if type(executable_name) is not str or SAFE_COMPONENT_RE.fullmatch(executable_name) is None:
        fail("production IPA executable name is invalid")
    executable_path = app_path / executable_name
    executable_sha, executable_size = hash_extracted_regular(
        executable_path, MAX_FILE_BYTES, "production application executable"
    )
    if executable_size <= 0:
        fail("production application executable is empty")
    key_id = info.get(AUTHORITY_KEY_ID_PLIST_KEY)
    public_b64 = info.get(AUTHORITY_KEY_X963_PLIST_KEY)
    source_revision = info.get(SOURCE_REVISION_PLIST_KEY)
    qualification_sha = info.get(QUALIFICATION_CONTRACT_PLIST_KEY)
    if type(key_id) is not str or KEY_ID_RE.fullmatch(key_id) is None:
        fail("production IPA lacks its reviewed evidence authority key ID")
    if type(public_b64) is not str or len(public_b64) > 128:
        fail("production IPA lacks its evidence authority public point")
    try:
        public_point = base64.b64decode(public_b64, validate=True)
    except (ValueError, TypeError):
        fail("production IPA evidence authority public point is not canonical Base64")
    validate_p256_public_point(public_point)
    if (
        type(source_revision) is not str
        or SOURCE_REVISION_RE.fullmatch(source_revision) is None
        or type(qualification_sha) is not str
        or SHA256_RE.fullmatch(qualification_sha) is None
        or qualification_sha == "0" * 64
    ):
        fail("production IPA lacks its source/qualification contract binding")
    verification = subprocess.run(
        ["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app_path)],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=SAFE_TOOL_ENV,
        timeout=120,
    )
    if verification.returncode != 0:
        fail("production IPA application does not pass codesign --deep --strict")
    signature_identity = inspect_production_signature_identity(app_path, info)
    raw_tree_sha, raw_tree_bytes, raw_tree_files = complete_tree_record(
        app_path, RAW_APP_TREE_PREFIX, "production application tree"
    )
    return {
        "ipaPath": ipa_path,
        "ipaSha256": ipa_sha,
        "ipaByteCount": ipa_size,
        "appPath": str(app_path),
        "bundleIdentifier": BUNDLE_IDENTIFIER,
        "executableSha256": executable_sha,
        "executableByteCount": executable_size,
        "rawTreeSha256": raw_tree_sha,
        "rawTreeRecordByteCount": raw_tree_bytes,
        "rawTreeFileCount": raw_tree_files,
        "authorityKeyId": key_id,
        "authorityPublicPoint": public_point,
        "authorityPublicPointSha256": hashlib.sha256(public_point).hexdigest(),
        "sourceRevision": source_revision,
        "qualificationContractSha256": qualification_sha,
        **signature_identity,
    }


CLONE_OMITTED_SIGNING_ENTITLEMENTS = frozenset(
    {"aps-environment", "beta-reports-active", "get-task-allow"}
)


def entitlement_group_array(
    entitlements: dict[str, Any], key: str, label: str, *, required: bool = False
) -> list[str]:
    if key not in entitlements:
        if required:
            fail(f"{label} lacks {key}")
        return []
    value = entitlements.get(key)
    if (
        type(value) is not list
        or not value
        or len(value) > 256
        or any(
            type(group) is not str
            or not group
            or len(group.encode("utf-8")) > 512
            for group in value
        )
        or len(set(value)) != len(value)
    ):
        fail(f"{label} {key} is not one ordered, bounded string array")
    return list(value)


def effective_keychain_access_groups(
    entitlements: dict[str, Any], label: str
) -> list[str]:
    application_identifier = entitlements.get("application-identifier")
    if type(application_identifier) is not str or not application_identifier:
        fail(f"{label} lacks one application identifier")
    candidates = (
        entitlement_group_array(
            entitlements, "keychain-access-groups", label
        )
        + [application_identifier]
        + entitlement_group_array(
            entitlements, "com.apple.security.application-groups", label
        )
    )
    effective: list[str] = []
    seen: set[str] = set()
    for group in candidates:
        if group not in seen:
            seen.add(group)
            effective.append(group)
    return effective


def profile_authorizes_group(group: str, profile_groups: list[str]) -> bool:
    team_wildcard = f"{TEAM_IDENTIFIER}.*"
    return any(
        candidate == group
        or (
            candidate == team_wildcard
            and group.startswith(f"{TEAM_IDENTIFIER}.")
        )
        for candidate in profile_groups
    )


def validate_production_entitlement_identity(
    info: dict[str, Any],
    profile_entitlements: dict[str, Any],
    entitlements: dict[str, Any],
) -> dict[str, Any]:
    application_identifier = entitlements.get("application-identifier")
    team_identifier = entitlements.get("com.apple.developer.team-identifier")
    profile_application_identifier = profile_entitlements.get(
        "application-identifier"
    )
    short_version = info.get("CFBundleShortVersionString")
    build_version = info.get("CFBundleVersion")
    if (
        info.get("CFBundleIdentifier") != BUNDLE_IDENTIFIER
        or team_identifier != TEAM_IDENTIFIER
        or application_identifier != f"{TEAM_IDENTIFIER}.{BUNDLE_IDENTIFIER}"
        or profile_application_identifier
        not in (application_identifier, f"{TEAM_IDENTIFIER}.*")
        or profile_entitlements.get("com.apple.developer.team-identifier")
        != team_identifier
        or type(short_version) is not str
        or VERSION_RE.fullmatch(short_version) is None
        or type(build_version) is not str
        or VERSION_RE.fullmatch(build_version) is None
    ):
        fail("production IPA does not have the reviewed signed application identity")

    effective_groups = effective_keychain_access_groups(
        entitlements, "production signed entitlements"
    )
    profile_groups = entitlement_group_array(
        profile_entitlements,
        "keychain-access-groups",
        "production provisioning profile",
        required=True,
    ) + entitlement_group_array(
        profile_entitlements,
        "com.apple.security.application-groups",
        "production provisioning profile",
    )
    if any(
        not profile_authorizes_group(group, profile_groups)
        for group in effective_groups
    ):
        fail("production profile does not authorize every effective access group")

    clone_signing_entitlements = {
        key: value
        for key, value in entitlements.items()
        if key not in CLONE_OMITTED_SIGNING_ENTITLEMENTS
    }
    for key, value in clone_signing_entitlements.items():
        if key in {
            "application-identifier",
            "com.apple.developer.team-identifier",
            "keychain-access-groups",
            "com.apple.security.application-groups",
        }:
            continue
        if profile_entitlements.get(key) != value:
            fail(
                "production profile does not authorize a preserved clone entitlement"
            )

    entitlements_bytes = canonical_json(entitlements)
    access_groups_bytes = canonical_json(effective_groups)
    return {
        "applicationIdentifier": application_identifier,
        "teamIdentifier": team_identifier,
        "shortVersion": short_version,
        "buildVersion": build_version,
        "signedEntitlementsSha256": hashlib.sha256(entitlements_bytes).hexdigest(),
        "keychainAccessGroupsSha256": hashlib.sha256(
            access_groups_bytes
        ).hexdigest(),
        # Internal-only values: receipt serialization selects explicit public
        # identity fields and never emits raw entitlements or access groups.
        "effectiveKeychainAccessGroups": effective_groups,
        "cloneSigningEntitlements": clone_signing_entitlements,
    }


def inspect_production_signature_identity(
    app_path: Path,
    info: dict[str, Any],
) -> dict[str, Any]:
    profile_path = app_path / "embedded.mobileprovision"
    profile_metadata = os.lstat(profile_path)
    if not stat.S_ISREG(profile_metadata.st_mode) or profile_metadata.st_nlink != 1:
        fail("production application lacks one regular provisioning profile")
    commands = (
        (
            ["/usr/bin/security", "cms", "-D", "-i", str(profile_path)],
            "production provisioning profile",
        ),
        (
            [
                "/usr/bin/codesign",
                "-d",
                "--entitlements",
                ":-",
                "--xml",
                str(app_path),
            ],
            "production signed entitlements",
        ),
    )
    outputs: list[bytes] = []
    for command, label in commands:
        result = subprocess.run(
            command,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=SAFE_TOOL_ENV,
            timeout=30,
        )
        if (
            result.returncode != 0
            or not result.stdout
            or len(result.stdout) > MAX_JSON_BYTES
            or len(result.stderr) > MAX_JSON_BYTES
        ):
            fail(f"{label} cannot be captured within its fixed bound")
        outputs.append(result.stdout)
    try:
        profile = plistlib.loads(outputs[0])
        entitlements = plistlib.loads(outputs[1])
    except plistlib.InvalidFileException as error:
        fail(f"production signing identity is not a valid plist: {error}")
    if (
        type(profile) is not dict
        or type(profile.get("Entitlements")) is not dict
        or type(entitlements) is not dict
    ):
        fail("production signing identity has no exact entitlement dictionaries")
    return validate_production_entitlement_identity(
        info, profile["Entitlements"], entitlements
    )


def validate_signed_request(
    ipa_path: str,
    clone_receipt_path: str,
    request_path: str,
    signature_path: str,
    output_parent: Path,
) -> dict[str, Any]:
    extraction = output_parent / "validated-application"
    identity = inspect_and_extract_ipa(ipa_path, extraction)
    request_raw, request_sha, request_size = read_regular(
        request_path, MAX_JSON_BYTES, "authorization request"
    )
    signature_raw, signature_sha, signature_size = read_regular(
        signature_path, MAX_SIGNATURE_BYTES, "authorization signature"
    )
    clone_receipt_raw, clone_receipt_sha, clone_receipt_size = read_regular(
        clone_receipt_path,
        MAX_JSON_BYTES,
        "protected installable-clone receipt",
    )
    request = validate_authorization_request(request_raw)
    clone_receipt = validate_installable_clone_receipt(clone_receipt_raw)
    validate_authorization_clone_binding(request, identity, clone_receipt)
    verify_authorization_signature(
        request_raw, signature_raw, identity["authorityPublicPoint"]
    )
    return {
        "request": request,
        "requestRaw": request_raw,
        "requestSha256": request_sha,
        "requestByteCount": request_size,
        "signatureSha256": signature_sha,
        "signatureRaw": signature_raw,
        "signatureByteCount": signature_size,
        "installableCloneReceipt": clone_receipt,
        "installableCloneReceiptSha256": clone_receipt_sha,
        "installableCloneReceiptByteCount": clone_receipt_size,
        "identity": identity,
    }


def validate_clone_projection_receipt(
    raw: bytes,
    clone_receipt: dict[str, Any],
) -> dict[str, Any]:
    projection = parse_canonical_json(raw, "clone canonical-projection receipt")
    require_exact_keys(
        projection,
        {
            "schemaVersion",
            "contractId",
            "platform",
            "status",
            "releaseAuthorized",
            "promotionAuthorized",
            "qualificationContractSha256",
            "projectionContract",
            "cryptographicValidityBoundary",
            "productionIpa",
            "releaseTestHost",
            "derivation",
            "checks",
            "blockingReasons",
        },
        "clone canonical-projection receipt",
    )
    production = projection["productionIpa"]
    installed = projection["releaseTestHost"]
    derivation = projection["derivation"]
    checks = projection["checks"]
    if (
        type(projection["schemaVersion"]) is not int
        or projection["schemaVersion"] != 2
        or projection["contractId"]
        != "sora-ios-wallet-migration-test-host-derivation-v2"
        or projection["platform"] != PLATFORM
        or projection["status"] != "observed"
        or projection["releaseAuthorized"] is not False
        or projection["promotionAuthorized"] is not False
        or projection["qualificationContractSha256"]
        != clone_receipt["qualificationContractSha256"]
        or type(production) is not dict
        or type(installed) is not dict
        or type(derivation) is not dict
        or type(checks) is not dict
    ):
        fail("clone canonical-projection receipt has an invalid fixed contract")
    production_projection = production.get("canonicalProjection")
    installed_projection = installed.get("canonicalProjection")
    installed_raw_tree = installed.get("rawTree")
    if (
        type(production_projection) is not dict
        or type(installed_projection) is not dict
        or type(installed_raw_tree) is not dict
        or production.get("sha256") != clone_receipt["productionIpaSha256"]
        or production_projection.get("recordSha256")
        != clone_receipt["productionCanonicalProjectionSha256"]
        or installed_projection.get("recordSha256")
        != clone_receipt["installedCanonicalProjectionSha256"]
        or installed_raw_tree.get("recordSha256")
        != clone_receipt["installedAppRawTreeSha256"]
        or installed.get("rawExecutableSha256")
        != clone_receipt["installedExecutableSha256"]
        or derivation.get("canonicalProjectionEqual") is not True
        or derivation.get("canonicalExecutableEqual") is not True
        or derivation.get("productionIdentityPreserved") is not True
        or checks.get("completeProjectionMatched") is not True
        or checks.get("secondCompleteInspectionMatched") is not True
        or checks.get("controllerNonAuthorizing") is not True
    ):
        fail("clone canonical-projection receipt differs from protected clone bytes")
    return projection


def recheck_installable_clone_artifacts(
    clone_receipt_path: str,
    clone_receipt: dict[str, Any],
    expected_receipt_sha: str,
) -> dict[str, Any]:
    path = safe_absolute_input(clone_receipt_path, "protected clone receipt")
    if path.name != "installable-clone-receipt-v1.json":
        fail("protected clone receipt has an unexpected file name")
    root_descriptor = open_directory(
        path.parent,
        "protected installable-clone root",
        private=True,
    )
    os.close(root_descriptor)
    retained_raw, retained_sha, retained_size = read_regular(
        str(path),
        MAX_JSON_BYTES,
        "protected installable-clone receipt recheck",
    )
    retained = validate_installable_clone_receipt(retained_raw)
    if (
        retained_sha != expected_receipt_sha
        or retained != clone_receipt
        or retained_size != len(retained_raw)
    ):
        fail("protected installable-clone receipt changed after authorization admission")
    complete_raw, _, _ = read_regular(
        str(path.parent / ".complete"),
        MAX_JSON_BYTES,
        "protected installable-clone completion marker",
    )
    complete = parse_canonical_json(
        complete_raw,
        "protected installable-clone completion marker",
    )
    require_exact_keys(
        complete,
        {
            "schemaVersion",
            "contractId",
            "installableCloneReceiptSha256",
            "releaseAuthorized",
        },
        "protected installable-clone completion marker",
    )
    if (
        type(complete["schemaVersion"]) is not int
        or complete["schemaVersion"] != 1
        or complete["contractId"]
        != "sora-ios-wallet-migration-installable-clone-complete-v1"
        or complete["installableCloneReceiptSha256"] != retained_sha
        or complete["releaseAuthorized"] is not False
    ):
        fail("protected installable-clone completion marker is invalid")
    projection_raw, projection_sha, _ = read_regular(
        str(path.parent / "canonical-projection-receipt-v2.json"),
        MAX_JSON_BYTES,
        "clone canonical-projection receipt",
    )
    if projection_sha != clone_receipt["canonicalProjectionReceiptSha256"]:
        fail("clone canonical-projection receipt hash differs from clone receipt")
    validate_clone_projection_receipt(projection_raw, clone_receipt)
    payload = path.parent / "installable-app" / "Payload"
    payload_metadata = os.lstat(payload)
    if not stat.S_ISDIR(payload_metadata.st_mode) or stat.S_ISLNK(
        payload_metadata.st_mode
    ):
        fail("protected installable clone lacks one real Payload directory")
    applications = []
    for entry in os.scandir(payload):
        metadata = os.lstat(entry.path)
        if entry.name.endswith(".app") and stat.S_ISDIR(metadata.st_mode):
            applications.append(Path(entry.path))
        else:
            fail("protected installable clone Payload contains an unexpected node")
    if len(applications) != 1:
        fail("protected installable clone does not contain exactly one app")
    app = applications[0]
    info_raw = read_extracted_regular(
        app / "Info.plist",
        MAX_JSON_BYTES,
        "protected installable-clone Info.plist",
    )
    try:
        info = plistlib.loads(info_raw)
    except plistlib.InvalidFileException as error:
        fail(f"protected installable-clone Info.plist is invalid: {error}")
    if type(info) is not dict or info.get("CFBundleIdentifier") != BUNDLE_IDENTIFIER:
        fail("protected installable clone has an unexpected bundle identity")
    executable_name = info.get("CFBundleExecutable")
    if (
        type(executable_name) is not str
        or SAFE_COMPONENT_RE.fullmatch(executable_name) is None
    ):
        fail("protected installable clone has an unsafe executable name")
    tree_sha, tree_bytes, file_count = complete_tree_record(
        app,
        RAW_APP_TREE_PREFIX,
        "protected installable-clone tree recheck",
    )
    executable_sha, executable_bytes = hash_extracted_regular(
        app / executable_name,
        MAX_FILE_BYTES,
        "protected installable-clone executable recheck",
    )
    if (
        tree_sha != clone_receipt["installedAppRawTreeSha256"]
        or tree_bytes != clone_receipt["installedAppRawTreeRecordByteCount"]
        or file_count != clone_receipt["installedAppFileCount"]
        or executable_sha != clone_receipt["installedExecutableSha256"]
        or executable_bytes != clone_receipt["installedExecutableByteCount"]
    ):
        fail("protected installable-clone artifact differs from its receipt")
    return {
        "appPath": str(app),
        "installedAppRawTreeSha256": tree_sha,
        "installedAppRawTreeRecordByteCount": tree_bytes,
        "installedAppFileCount": file_count,
        "installedExecutableSha256": executable_sha,
        "installedExecutableByteCount": executable_bytes,
        "productionCanonicalProjectionSha256": clone_receipt[
            "productionCanonicalProjectionSha256"
        ],
        "installedCanonicalProjectionSha256": clone_receipt[
            "installedCanonicalProjectionSha256"
        ],
        "canonicalProjectionReceiptSha256": projection_sha,
        "canonicalProjectorSourceSha256": canonical_projector_source_sha256(),
    }


def create_private_output_root(raw: str, label: str) -> Path:
    path = safe_absolute_input(raw, label)
    if ROOT == path or ROOT in path.parents:
        fail(f"{label} must remain outside the repository")
    if SAFE_COMPONENT_RE.fullmatch(path.name) is None:
        fail(f"{label} leaf is unsafe")
    parent = open_directory(path.parent, f"{label} parent", private=True)
    try:
        try:
            os.mkdir(path.name, 0o700, dir_fd=parent)
        except FileExistsError:
            fail(f"{label} must be fresh")
        os.fsync(parent)
    finally:
        os.close(parent)
    metadata = os.lstat(path)
    if (
        not stat.S_ISDIR(metadata.st_mode)
        or metadata.st_uid != os.getuid()
        or stat.S_IMODE(metadata.st_mode) != 0o700
    ):
        fail(f"{label} was not created as an owner-only directory")
    return path


def write_new_file(path: Path, raw: bytes, mode: int = 0o600) -> str:
    descriptor = os.open(
        path,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
        mode,
    )
    try:
        view = memoryview(raw)
        while view:
            written = os.write(descriptor, view)
            if written <= 0:
                fail(f"output could not be written: {path.name}")
            view = view[written:]
        os.fsync(descriptor)
        before = os.fstat(descriptor)
    finally:
        os.close(descriptor)
    named = os.lstat(path)
    if (
        stable_identity(before) != stable_identity(named)
        or not stat.S_ISREG(named.st_mode)
        or named.st_nlink != 1
    ):
        fail(f"output changed during publication: {path.name}")
    return hashlib.sha256(raw).hexdigest()


def safe_device_id(value: str) -> str:
    if DEVICE_ID_RE.fullmatch(value) is None:
        fail("retained physical-device identifier has an unsafe shape")
    return value


def run_step(
    output: Path,
    step: str,
    argv: list[str],
    *,
    timeout: int,
) -> dict[str, Any]:
    if SAFE_COMPONENT_RE.fullmatch(step) is None or not argv or any("\0" in item for item in argv):
        fail("controller step or argument is unsafe")
    receipt_root = output / "operation-receipts"
    receipt_root.mkdir(mode=0o700, exist_ok=True)
    stdout_path = receipt_root / f"{step}.stdout"
    stderr_path = receipt_root / f"{step}.stderr"
    started = int(time.time())
    try:
        result = subprocess.run(
            argv,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=SAFE_TOOL_ENV,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as error:
        stdout = error.stdout or b""
        stderr = error.stderr or b""
        if len(stdout) <= MAX_TOOL_OUTPUT_BYTES:
            write_new_file(stdout_path, stdout)
        if len(stderr) <= MAX_TOOL_OUTPUT_BYTES:
            write_new_file(stderr_path, stderr)
        fail(f"controller step timed out: {step}")
    finished = int(time.time())
    if len(result.stdout) > MAX_TOOL_OUTPUT_BYTES or len(result.stderr) > MAX_TOOL_OUTPUT_BYTES:
        fail(f"controller step output exceeds its bound: {step}")
    stdout_sha = write_new_file(stdout_path, result.stdout)
    stderr_sha = write_new_file(stderr_path, result.stderr)
    receipt = {
        "schemaVersion": 1,
        "contractId": "sora-ios-wallet-migration-controller-operation-v1",
        "step": step,
        "startedAtEpochSeconds": started,
        "finishedAtEpochSeconds": finished,
        "exitCode": result.returncode,
        "argvSha256": hashlib.sha256(canonical_json(argv)).hexdigest(),
        "stdoutSha256": stdout_sha,
        "stdoutByteCount": len(result.stdout),
        "stderrSha256": stderr_sha,
        "stderrByteCount": len(result.stderr),
    }
    write_new_file(receipt_root / f"{step}.json", canonical_json(receipt))
    if result.returncode != 0:
        fail(f"controller step failed closed: {step}")
    return receipt


def devicectl_command(
    output: Path,
    step: str,
    arguments: list[str],
    *,
    timeout: int,
) -> dict[str, Any]:
    json_output = output / "operation-receipts" / f"{step}.devicectl.json"
    log_output = output / "operation-receipts" / f"{step}.devicectl.log"
    return run_step(
        output,
        step,
        [
            "/usr/bin/xcrun",
            "devicectl",
            *arguments,
            "--json-output",
            str(json_output),
            "--log-output",
            str(log_output),
            "--timeout",
            str(timeout),
        ],
        timeout=timeout + 30,
    )


def copy_from_device(
    output: Path,
    step: str,
    device: str,
    source: str,
    destination: Path,
) -> None:
    if destination.exists() or destination.is_symlink():
        fail(f"device-copy destination must be fresh: {destination.name}")
    devicectl_command(
        output,
        step,
        [
            "device",
            "copy",
            "from",
            "--device",
            device,
            "--source",
            source,
            "--destination",
            str(destination),
            "--domain-type",
            "appDataContainer",
            "--domain-identifier",
            BUNDLE_IDENTIFIER,
        ],
        timeout=120,
    )


def copy_to_device(
    output: Path,
    step: str,
    device: str,
    source: Path,
    destination: str,
) -> None:
    if not source.is_file() or source.is_symlink() or ".." in PurePosixPath(destination).parts:
        fail("device-copy source or destination is unsafe")
    devicectl_command(
        output,
        step,
        [
            "device",
            "copy",
            "to",
            "--device",
            device,
            "--source",
            str(source),
            "--destination",
            destination,
            "--domain-type",
            "appDataContainer",
            "--domain-identifier",
            BUNDLE_IDENTIFIER,
        ],
        timeout=120,
    )


def find_unique_named(root: Path, name: str, label: str) -> Path:
    matches: list[Path] = []
    for directory, directory_names, file_names in os.walk(root, topdown=True, followlinks=False):
        directory_path = Path(directory)
        for child in directory_names:
            if (directory_path / child).is_symlink():
                fail(f"{label} contains a symbolic directory")
        for child in file_names:
            path = directory_path / child
            if path.is_symlink():
                fail(f"{label} contains a symbolic file")
            if child == name:
                matches.append(path)
    if len(matches) != 1:
        fail(f"{label} does not contain exactly one {name}")
    return matches[0]


def require_enrollment_snapshot(root: Path) -> tuple[str, int]:
    nonce_path = find_unique_named(
        root, ENROLLMENT_NONCE_NAME, "enrollment evidence"
    )
    parent = nonce_path.parent
    parent_metadata = os.lstat(parent)
    if not stat.S_ISDIR(parent_metadata.st_mode):
        fail("enrollment evidence directory is not a real directory")
    names = sorted(entry.name for entry in os.scandir(parent))
    if names != [ENROLLMENT_NONCE_NAME]:
        fail("enrollment evidence namespace contains stale or unexpected case state")
    digest, size = hash_extracted_regular(
        nonce_path, 32, "device enrollment nonce"
    )
    if size != 32:
        fail("device enrollment nonce is not exactly 32 random bytes")
    final_parent = os.lstat(parent)
    if stable_identity(parent_metadata) != stable_identity(final_parent):
        fail("enrollment evidence directory changed during admission")
    return digest, size


WALLET_INPUT_ROLES = (
    "Documents/CoreData",
    "Library/Preferences/co.jp.soramitsu.sora.plist",
    "Library/Application Support/SORA/WalletNetworks",
    "Library/Application Support/SORA/WalletAccountCommits",
)


def locate_container_snapshot_root(snapshot: Path) -> Path:
    candidates: list[Path] = []
    for candidate in [snapshot, *[path for path in snapshot.rglob("*") if path.is_dir()]]:
        if (candidate / "Documents").is_dir() and (candidate / "Library").is_dir():
            candidates.append(candidate)
    minimal = [
        candidate
        for candidate in candidates
        if not any(other != candidate and other in candidate.parents for other in candidates)
    ]
    if len(minimal) != 1:
        fail("appDataContainer copy has an absent or ambiguous container root")
    return minimal[0]


def wallet_role_entries(root: Path, role: str) -> Optional[list[tuple[str, bool, int, bytes]]]:
    target = root.joinpath(*PurePosixPath(role).parts)
    try:
        metadata = os.lstat(target)
    except FileNotFoundError:
        return None
    entries: list[tuple[str, bool, int, bytes]] = []
    seen_inodes: set[tuple[int, int]] = set()
    seen_names: set[str] = set()
    total = 0

    def add_file(path: Path, relative: str, expected: os.stat_result) -> None:
        nonlocal total
        inode = (expected.st_dev, expected.st_ino)
        if inode in seen_inodes:
            fail(f"wallet input role contains a hard link: {role}")
        seen_inodes.add(inode)
        folded = unicodedata.normalize("NFC", relative).casefold()
        if folded in seen_names:
            fail(f"wallet input role contains a path collision: {role}")
        seen_names.add(folded)
        digest, size = hash_extracted_regular(path, MAX_FILE_BYTES, f"wallet input {role}")
        total += size
        if total > MAX_UNCOMPRESSED_BYTES:
            fail(f"wallet input role exceeds its byte bound: {role}")
        entries.append((relative, bool(expected.st_mode & 0o111), size, bytes.fromhex(digest)))

    if stat.S_ISREG(metadata.st_mode):
        if metadata.st_nlink != 1:
            fail(f"wallet input regular role is linked: {role}")
        add_file(target, "", metadata)
        return entries
    if not stat.S_ISDIR(metadata.st_mode):
        fail(f"wallet input role is symbolic or special: {role}")
    root_inode = (metadata.st_dev, metadata.st_ino)
    seen_inodes.add(root_inode)
    for directory, directory_names, file_names in os.walk(target, topdown=True, followlinks=False):
        directory_path = Path(directory)
        directory_names.sort(key=lambda value: value.encode("utf-8"))
        file_names.sort(key=lambda value: value.encode("utf-8"))
        for child in directory_names:
            path = directory_path / child
            child_metadata = os.lstat(path)
            if not stat.S_ISDIR(child_metadata.st_mode):
                fail(f"wallet input role contains a linked/special directory: {role}")
            inode = (child_metadata.st_dev, child_metadata.st_ino)
            if inode in seen_inodes:
                fail(f"wallet input role contains a directory alias: {role}")
            seen_inodes.add(inode)
        for child in file_names:
            path = directory_path / child
            child_metadata = os.lstat(path)
            if not stat.S_ISREG(child_metadata.st_mode) or child_metadata.st_nlink != 1:
                fail(f"wallet input role contains a linked/special file: {role}")
            relative = path.relative_to(target).as_posix()
            add_file(path, relative, child_metadata)
            if len(entries) > MAX_FILE_COUNT:
                fail(f"wallet input role exceeds its file-count bound: {role}")
    return entries


def wallet_input_tree_record(
    container_root: Path,
) -> tuple[str, int, dict[str, int], dict[str, tuple[str, ...]]]:
    record = bytearray(WALLET_INPUT_TREE_PREFIX)
    record.extend(struct.pack(">I", len(WALLET_INPUT_ROLES)))
    counts: dict[str, int] = {}
    paths: dict[str, tuple[str, ...]] = {}
    for role in WALLET_INPUT_ROLES:
        role_bytes = role.encode("utf-8")
        record.extend(struct.pack(">I", len(role_bytes)))
        record.extend(role_bytes)
        entries = wallet_role_entries(container_root, role)
        if entries is None:
            record.append(0x41)
            counts[role] = 0
            paths[role] = ()
            continue
        record.append(0x50)
        ordered = sorted(entries, key=lambda item: item[0].encode("utf-8"))
        counts[role] = len(ordered)
        paths[role] = tuple(entry[0] for entry in ordered)
        record.extend(struct.pack(">I", len(ordered)))
        for relative, executable, size, digest in ordered:
            relative_bytes = relative.encode("utf-8")
            record.extend(struct.pack(">I", len(relative_bytes)))
            record.extend(relative_bytes)
            record.append(0x45 if executable else 0x4E)
            record.extend(struct.pack(">Q", size))
            record.extend(digest)
    return hashlib.sha256(record).hexdigest(), len(record), counts, paths


def canonical_swift_uuid(value: str) -> bool:
    try:
        parsed = uuid.UUID(value)
    except ValueError:
        return False
    return parsed.int != 0 and str(parsed).upper() == value


def validate_prepared_wallet_paths(
    paths: dict[str, tuple[str, ...]],
    case_id: str,
) -> None:
    core_data = paths["Documents/CoreData"]
    preferences = paths["Library/Preferences/co.jp.soramitsu.sora.plist"]
    networks = paths["Library/Application Support/SORA/WalletNetworks"]
    commits = paths["Library/Application Support/SORA/WalletAccountCommits"]
    if "UserDataModel.sqlite" not in core_data or preferences != ("",):
        fail("prepared case lacks its retained Core Data store or production preferences")
    safety_attempts: set[str] = set()
    live_core_data = {
        "UserDataModel.sqlite",
        "UserDataModel.sqlite-wal",
        "UserDataModel.sqlite-shm",
        "UserDataModel.sqlite-journal",
    }
    safety_root_files = {
        "account-manifest.json",
        "settings-backup.plist",
        "journal.json",
    }
    legacy_store_files = {
        "UserDataModel.sqlite",
        "UserDataModel.sqlite-wal",
        "UserDataModel.sqlite-shm",
        "UserDataModel.sqlite-journal",
        "backup-manifest.json",
    }
    staging_store_files = {
        "UserDataModel 2.sqlite",
        "UserDataModel 2.sqlite-wal",
        "UserDataModel 2.sqlite-shm",
        "UserDataModel 2.sqlite-journal",
    }
    for relative in core_data:
        components = relative.split("/")
        if len(components) == 1 and relative in live_core_data:
            continue
        if len(components) not in {3, 4} or components[0] != "WalletMigrationSafety":
            fail("prepared Core Data namespace contains an unreviewed path")
        attempt = components[1]
        if not canonical_swift_uuid(attempt):
            fail("prepared Core Data safety attempt has a noncanonical identifier")
        safety_attempts.add(attempt)
        tail = components[2:]
        if len(tail) == 1 and tail[0] in safety_root_files:
            continue
        if len(tail) == 2 and (
            (tail[0] == "legacy-store" and tail[1] in legacy_store_files)
            or (tail[0] == "staging" and tail[1] in staging_store_files)
        ):
            continue
        fail("prepared Core Data safety attempt contains an unreviewed artifact")
    for relative in networks:
        if relative == "active.json":
            continue
        match = re.fullmatch(r"wallet-network-([0-9A-F-]{36})\.json", relative)
        if match is None or not canonical_swift_uuid(match.group(1)):
            fail("prepared wallet-network namespace contains an unreviewed path")
    for relative in commits:
        match = re.fullmatch(r"wallet-account-([0-9A-F-]{36})\.json", relative)
        if match is None or not canonical_swift_uuid(match.group(1)):
            fail("prepared wallet-commit namespace contains an unreviewed path")
    if case_id == "recovery-archive-export" and not safety_attempts:
        fail("recovery archive case lacks a retained migration-safety attempt")


def snapshot_wallet_from_device(
    output: Path,
    step: str,
    device: str,
    destination: Path,
    case_id: str,
) -> dict[str, Any]:
    copy_from_device(output, step, device, ".", destination)
    container_root = locate_container_snapshot_root(destination)
    digest, record_bytes, role_counts, role_paths = wallet_input_tree_record(
        container_root
    )
    validate_prepared_wallet_paths(role_paths, case_id)
    return {
        "sha256": digest,
        "recordByteCount": record_bytes,
        "roleFileCounts": role_counts,
        "rolePaths": role_paths,
    }


def require_boolean_dictionary(
    value: Any,
    expected_keys: set[str],
    label: str,
) -> dict[str, bool]:
    if type(value) is not dict:
        fail(f"{label} is not one dictionary")
    require_exact_keys(value, expected_keys, label)
    if any(type(item) is not bool for item in value.values()):
        fail(f"{label} contains a non-boolean value")
    return value


def validate_application_case_receipt(
    raw: bytes,
    request: dict[str, Any],
    request_sha: str,
) -> dict[str, Any]:
    receipt = parse_canonical_json(raw, "application case-operation receipt")
    observation_key = (
        "keychainObservation" if request["caseKind"] == "keychain" else "deviceObservation"
    )
    require_exact_keys(
        receipt,
        {
            "schemaVersion",
            "contractId",
            "platform",
            "status",
            "releaseAuthorized",
            "authorizationId",
            "authorizationKeyId",
            "authorizationRequestSha256",
            "runId",
            "runChallengeSha256",
            "sourceRevision",
            "qualificationContractSha256",
            "productionIpaSha256",
            "installedAppRawTreeSha256",
            "installedExecutableSha256",
            "productionCanonicalProjectionSha256",
            "installedCanonicalProjectionSha256",
            "canonicalProjectionReceiptSha256",
            "canonicalProjectorSourceSha256",
            "preparedWalletInputTreeSha256",
            "caseKind",
            "caseId",
            "outcome",
            "startedAtEpochSeconds",
            "finishedAtEpochSeconds",
            "launchCount",
            "harnessStateSha256",
            "checkpointSequence",
            "applicationRoute",
            observation_key,
        },
        "application case-operation receipt",
    )
    bindings = {
        "authorizationId": "authorizationId",
        "authorizationKeyId": "authorizationKeyId",
        "runId": "runId",
        "runChallengeSha256": "runChallengeSha256",
        "sourceRevision": "sourceRevision",
        "qualificationContractSha256": "qualificationContractSha256",
        "productionIpaSha256": "productionIpaSha256",
        "installedAppRawTreeSha256": "installedAppRawTreeSha256",
        "installedExecutableSha256": "installedExecutableSha256",
        "productionCanonicalProjectionSha256": (
            "productionCanonicalProjectionSha256"
        ),
        "installedCanonicalProjectionSha256": (
            "installedCanonicalProjectionSha256"
        ),
        "canonicalProjectionReceiptSha256": (
            "canonicalProjectionReceiptSha256"
        ),
        "canonicalProjectorSourceSha256": "canonicalProjectorSourceSha256",
        "preparedWalletInputTreeSha256": "preparedWalletInputTreeSha256",
        "caseKind": "caseKind",
        "caseId": "caseId",
    }
    if (
        type(receipt["schemaVersion"]) is not int
        or receipt["schemaVersion"] != 3
        or receipt["contractId"]
        != "sora-ios-wallet-migration-case-operation-receipt-v3"
        or receipt["platform"] != PLATFORM
        or receipt["status"] != "observed"
        or receipt["releaseAuthorized"] is not False
        or receipt["authorizationRequestSha256"] != request_sha
        or any(receipt[key] != request[source] for key, source in bindings.items())
    ):
        fail("application case-operation receipt differs from its authorization")
    for key in (
        "authorizationRequestSha256",
        "runChallengeSha256",
        "qualificationContractSha256",
        "productionIpaSha256",
        "installedAppRawTreeSha256",
        "installedExecutableSha256",
        "productionCanonicalProjectionSha256",
        "installedCanonicalProjectionSha256",
        "canonicalProjectionReceiptSha256",
        "canonicalProjectorSourceSha256",
        "preparedWalletInputTreeSha256",
        "harnessStateSha256",
    ):
        require_sha256(receipt[key], f"application receipt {key}")
    started = receipt["startedAtEpochSeconds"]
    finished = receipt["finishedAtEpochSeconds"]
    launches = receipt["launchCount"]
    checkpoints = receipt["checkpointSequence"]
    route = receipt["applicationRoute"]
    if (
        type(started) is not int
        or type(finished) is not int
        or type(launches) is not int
        or started < request["issuedAtEpochSeconds"] - 300
        or finished < started
        or finished > request["expiresAtEpochSeconds"] + 300
        or not 1 <= launches <= request["maximumLaunchCount"]
        or type(checkpoints) is not list
        or any(type(item) is not str for item in checkpoints)
        or len(set(checkpoints)) != len(checkpoints)
        or type(route) is not str
    ):
        fail("application case-operation chronology or launch evidence is invalid")
    case_id = request["caseId"]
    expected_checkpoint = INTERRUPTION_CHECKPOINTS.get(case_id)
    if checkpoints != ([expected_checkpoint] if expected_checkpoint else []):
        fail("application case-operation checkpoint sequence is unexpected")
    if expected_checkpoint is not None and launches < 2:
        fail("interrupted application case did not prove a restarted launch")
    if case_id in RECOVERY_ROUTE_CASES:
        expected_route = route == "recovery"
    elif case_id in SUCCESS_ROUTE_CASES:
        expected_route = route in {"local-authentication", "pincode-setup"}
    else:
        expected_route = False
    if not expected_route:
        fail("application case-operation route differs from the reviewed case")
    if request["caseKind"] == "keychain":
        observation = require_boolean_dictionary(
            receipt["keychainObservation"],
            {
                "identifierSetUnchanged",
                "valuesByteForByteUnchanged",
                "accessibilityUnchanged",
                "credentialRewriteObserved",
                "credentialBehaviorProbePassed",
                "signingExpected",
                "signingSucceeded",
                "recoveryRouteEntered",
            },
            "application keychain observation",
        )
        signing_expected, signing_succeeded = KEYCHAIN_SIGNING_EXPECTATIONS[case_id]
        if (
            receipt["outcome"] != "passed"
            or observation["identifierSetUnchanged"] is not True
            or observation["valuesByteForByteUnchanged"] is not True
            or observation["accessibilityUnchanged"] is not True
            or observation["credentialRewriteObserved"] is not False
            or observation["credentialBehaviorProbePassed"] is not True
            or observation["signingExpected"] is not signing_expected
            or observation["signingSucceeded"] is not signing_succeeded
            or observation["recoveryRouteEntered"]
            is not (case_id in RECOVERY_ROUTE_CASES)
        ):
            fail("application keychain observation does not satisfy its reviewed case")
        return receipt
    observation = receipt["deviceObservation"]
    if type(observation) is not dict:
        fail("application device observation is not one dictionary")
    expected_device_keys = {
        "recoveryRouteEntered",
        "recoveryArchiveExportVerified",
        "processDeathRestartObserved",
        "controllerValidationRequired",
    }
    if case_id == "rollback":
        expected_device_keys.update(
            {
                "rollbackInjectionObserved",
                "rollbackRestorationVerified",
                "rollbackBeforeStoreTreeSha256",
                "rollbackReplacementStoreTreeSha256",
                "rollbackRestoredStoreTreeSha256",
            }
        )
    if case_id == "interruption-before-secret-retention":
        expected_device_keys.update(
            {
                "retainedKeychainIdentifierSetUnchanged",
                "retainedKeychainValuesUnchanged",
                "retainedKeychainAccessibilityUnchanged",
            }
        )
    if case_id == "low-storage":
        expected_device_keys.add("lowStorageConditionObserved")
    require_exact_keys(
        observation,
        expected_device_keys,
        "application device observation",
    )
    boolean_keys = expected_device_keys - {
        "rollbackBeforeStoreTreeSha256",
        "rollbackReplacementStoreTreeSha256",
        "rollbackRestoredStoreTreeSha256",
    }
    if any(type(observation[key]) is not bool for key in boolean_keys):
        fail("application device observation contains a non-boolean fact")
    if (
        receipt["outcome"] != "observed"
        or observation["controllerValidationRequired"] is not True
        or observation["recoveryRouteEntered"]
        is not (case_id in RECOVERY_ROUTE_CASES)
        or observation["recoveryArchiveExportVerified"]
        is not (case_id == "recovery-archive-export")
        or observation["processDeathRestartObserved"]
        is not (case_id == "process-death-restart")
    ):
        fail("application device observation does not satisfy its reviewed case")
    if case_id == "rollback":
        before = require_sha256(
            observation["rollbackBeforeStoreTreeSha256"],
            "rollback source tree",
        )
        replacement = require_sha256(
            observation["rollbackReplacementStoreTreeSha256"],
            "rollback replacement tree",
        )
        restored = require_sha256(
            observation["rollbackRestoredStoreTreeSha256"],
            "rollback restored tree",
        )
        if (
            observation["rollbackInjectionObserved"] is not True
            or observation["rollbackRestorationVerified"] is not True
            or before == replacement
            or restored != before
        ):
            fail("rollback case does not prove exact store restoration")
    if case_id == "low-storage" and observation["lowStorageConditionObserved"] is not True:
        fail("low-storage case lacks an OS-observed low-storage condition")
    if case_id == "interruption-before-secret-retention" and any(
        observation[key] is not True
        for key in (
            "retainedKeychainIdentifierSetUnchanged",
            "retainedKeychainValuesUnchanged",
            "retainedKeychainAccessibilityUnchanged",
        )
    ):
        fail("pre-secret interruption changed retained Keychain material")
    return receipt


def require_application_receipt_snapshot(
    snapshot: Path,
    request: dict[str, Any],
    request_sha: str,
) -> dict[str, Any]:
    receipt_path = find_unique_named(
        snapshot,
        APPLICATION_RECEIPT_NAME,
        "application result evidence",
    )
    sha_path = find_unique_named(
        snapshot,
        APPLICATION_RECEIPT_SHA_NAME,
        "application result evidence",
    )
    receipt_raw = read_extracted_regular(
        receipt_path,
        MAX_APPLICATION_RECEIPT_BYTES,
        "application case-operation receipt",
    )
    receipt_sha = hashlib.sha256(receipt_raw).hexdigest()
    sha_raw = read_extracted_regular(
        sha_path,
        65,
        "application case-operation receipt SHA",
    )
    if sha_raw != f"{receipt_sha}\n".encode("ascii"):
        fail("application case-operation receipt SHA file differs from receipt")
    receipt = validate_application_case_receipt(receipt_raw, request, request_sha)
    return {
        "receipt": receipt,
        "raw": receipt_raw,
        "sha256": receipt_sha,
        "byteCount": len(receipt_raw),
    }


def serializable_production_application_identity(
    identity: dict[str, Any],
) -> dict[str, Any]:
    return {
        "productionIpaSha256": identity["ipaSha256"],
        "productionIpaByteCount": identity["ipaByteCount"],
        "bundleIdentifier": identity["bundleIdentifier"],
        "productionAppRawTreeSha256": identity["rawTreeSha256"],
        "productionAppRawTreeRecordByteCount": identity["rawTreeRecordByteCount"],
        "productionAppFileCount": identity["rawTreeFileCount"],
        "productionExecutableSha256": identity["executableSha256"],
        "productionExecutableByteCount": identity["executableByteCount"],
        "authorizationKeyId": identity["authorityKeyId"],
        "authorizationPublicPointSha256": identity["authorityPublicPointSha256"],
        "sourceRevision": identity["sourceRevision"],
        "qualificationContractSha256": identity["qualificationContractSha256"],
        "applicationIdentifier": identity["applicationIdentifier"],
        "teamIdentifier": identity["teamIdentifier"],
        "shortVersion": identity["shortVersion"],
        "buildVersion": identity["buildVersion"],
        "signedEntitlementsSha256": identity["signedEntitlementsSha256"],
        "keychainAccessGroupsSha256": identity["keychainAccessGroupsSha256"],
    }


def validate_case_pair(case_kind: str, case_id: str) -> None:
    if (case_kind == "keychain" and case_id in KEYCHAIN_CASES) or (
        case_kind == "device" and case_id in DEVICE_CASES
    ):
        return
    fail("retained-device case kind and ID are not a reviewed pair")


def prepare_case(
    *,
    device: str,
    ipa_path: str,
    run_id: str,
    run_challenge_sha: str,
    case_kind: str,
    case_id: str,
    output_raw: str,
) -> dict[str, Any]:
    safe_device_id(device)
    require_uuid(run_id, "run ID")
    require_sha256(run_challenge_sha, "run challenge")
    validate_case_pair(case_kind, case_id)
    output = create_private_output_root(output_raw, "case preparation output")
    application_root = output / "application"
    identity = inspect_and_extract_ipa(ipa_path, application_root)
    app_path = identity["appPath"]
    devicectl_command(
        output,
        "install-exact-production-app",
        ["device", "install", "app", "--device", device, app_path],
        timeout=300,
    )
    devicectl_command(
        output,
        "launch-enrollment",
        [
            "device",
            "process",
            "launch",
            "--device",
            device,
            BUNDLE_IDENTIFIER,
            "-SORA_MIGRATION_EVIDENCE_ENROLL_V3",
        ],
        timeout=90,
    )
    time.sleep(2)
    evidence_snapshot = output / "device-enrollment"
    copy_from_device(
        output,
        "copy-enrollment-evidence",
        device,
        EVIDENCE_DIRECTORY,
        evidence_snapshot,
    )
    nonce_sha, _ = require_enrollment_snapshot(evidence_snapshot)

    container_snapshot = output / "prepared-app-data-container"
    copy_from_device(
        output,
        "copy-prepared-app-data-container",
        device,
        ".",
        container_snapshot,
    )
    container_root = locate_container_snapshot_root(container_snapshot)
    wallet_tree_sha, wallet_tree_bytes, role_counts, role_paths = wallet_input_tree_record(
        container_root
    )
    validate_prepared_wallet_paths(role_paths, case_id)
    prepared_at = int(time.time())
    preparation = {
        "schemaVersion": 3,
        "contractId": PREPARATION_CONTRACT_ID,
        "platform": PLATFORM,
        "status": "observed",
        "releaseAuthorized": False,
        "runId": run_id,
        "runChallengeSha256": run_challenge_sha,
        "caseKind": case_kind,
        "caseId": case_id,
        "preparedAtEpochSeconds": prepared_at,
        "application": serializable_production_application_identity(identity),
        "enrollmentNonceSha256": nonce_sha,
        "preparedWalletInputTreeSha256": wallet_tree_sha,
        "preparedWalletInputTreeRecordByteCount": wallet_tree_bytes,
        "preparedWalletRoleFileCounts": role_counts,
        "checks": {
            "exactIpaExtractedWithoutResigning": True,
            "productionCodeSignatureDeepStrictVerified": True,
            "exactExtractedAppInstalled": True,
            "enrollmentLaunchCompleted": True,
            "walletAuthoritativeInputsSnapshotted": True,
            "authorizationCreated": False,
            "qualificationCreated": False,
        },
        "blockingReasons": [NONAUTHORIZING_BLOCKER],
    }
    preparation_raw = canonical_json(preparation)
    preparation_sha = write_new_file(
        output / "case-preparation-v3.json", preparation_raw
    )
    marker = canonical_json(
        {
            "schemaVersion": 1,
            "contractId": "sora-ios-wallet-migration-case-preparation-complete-v1",
            "casePreparationSha256": preparation_sha,
            "releaseAuthorized": False,
        }
    )
    write_new_file(output / ".complete", marker)
    directory = open_directory(output, "case preparation output", private=True)
    try:
        os.fsync(directory)
    finally:
        os.close(directory)
    return {
        "casePreparationSha256": preparation_sha,
        "productionIpaSha256": identity["ipaSha256"],
        "enrollmentNonceSha256": nonce_sha,
        "preparedWalletInputTreeSha256": wallet_tree_sha,
    }


def require_result_bundle(path: Path) -> None:
    metadata = os.lstat(path)
    if (
        not stat.S_ISDIR(metadata.st_mode)
        or stat.S_ISLNK(metadata.st_mode)
        or metadata.st_uid != os.getuid()
    ):
        fail("test-without-building did not create one owned result bundle")
    file_count = 0
    for directory, directory_names, file_names in os.walk(
        path,
        topdown=True,
        followlinks=False,
    ):
        base = Path(directory)
        for name in directory_names:
            child = os.lstat(base / name)
            if not stat.S_ISDIR(child.st_mode):
                fail("test result bundle contains a linked or special directory")
        for name in file_names:
            child = os.lstat(base / name)
            if not stat.S_ISREG(child.st_mode) or child.st_nlink != 1:
                fail("test result bundle contains a linked or special file")
            file_count += 1
            if file_count > MAX_FILE_COUNT:
                fail("test result bundle exceeds its file-count bound")
    if file_count == 0:
        fail("test result bundle is empty")


def extract_test_receipt(
    output: Path,
    result_bundle: Path,
    device: str,
    request: dict[str, Any],
    request_sha: str,
) -> dict[str, Any]:
    attachment_root = output / "test-receipt-attachments"
    if attachment_root.exists() or attachment_root.is_symlink():
        fail("test-receipt attachment destination must be fresh")
    run_step(
        output,
        "extract-test-receipt",
        [
            "/usr/bin/xcrun",
            "xcresulttool",
            "export",
            "attachments",
            "--path",
            str(result_bundle),
            "--output-path",
            str(attachment_root),
        ],
        timeout=120,
    )
    root_metadata = os.lstat(attachment_root)
    if (
        not stat.S_ISDIR(root_metadata.st_mode)
        or stat.S_ISLNK(root_metadata.st_mode)
        or root_metadata.st_uid != os.getuid()
    ):
        fail("xcresult attachment export is not one owned directory")
    file_count = 0
    total_bytes = 0
    for directory, directory_names, file_names in os.walk(
        attachment_root,
        topdown=True,
        followlinks=False,
    ):
        base = Path(directory)
        for name in directory_names:
            child = os.lstat(base / name)
            if not stat.S_ISDIR(child.st_mode) or stat.S_ISLNK(child.st_mode):
                fail("xcresult attachment export contains a linked directory")
        for name in file_names:
            child = os.lstat(base / name)
            if (
                not stat.S_ISREG(child.st_mode)
                or child.st_nlink != 1
                or child.st_size > MAX_FILE_BYTES
            ):
                fail("xcresult attachment export contains a linked or oversized file")
            file_count += 1
            total_bytes += child.st_size
            if file_count > MAX_FILE_COUNT or total_bytes > MAX_UNCOMPRESSED_BYTES:
                fail("xcresult attachment export exceeds its resource bounds")
    manifest_raw = read_extracted_regular(
        attachment_root / "manifest.json",
        MAX_JSON_BYTES,
        "xcresult attachment manifest",
    )
    try:
        manifest = json.loads(
            manifest_raw.decode("utf-8", errors="strict"),
            object_pairs_hook=duplicate_rejecting_object,
            parse_constant=lambda token: fail(
                f"xcresult attachment manifest contains invalid constant {token}"
            ),
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fail(f"xcresult attachment manifest is invalid JSON: {error}")
    if type(manifest) is not list or len(manifest) != 1:
        fail("xcresult attachment manifest is not one exact test record")
    test_record = manifest[0]
    allowed_test_keys = {"testIdentifier", "testIdentifierURL", "attachments"}
    if (
        type(test_record) is not dict
        or not {"testIdentifier", "attachments"}.issubset(test_record)
        or not set(test_record).issubset(allowed_test_keys)
        or type(test_record["testIdentifier"]) is not str
        or TEST_IDENTIFIER_RE.fullmatch(test_record["testIdentifier"]) is None
        or type(test_record["attachments"]) is not list
        or len(test_record["attachments"]) != 1
        or (
            "testIdentifierURL" in test_record
            and type(test_record["testIdentifierURL"]) is not str
        )
    ):
        fail("xcresult attachment manifest differs from the exact UI test")
    attachment = test_record["attachments"][0]
    allowed_attachment_keys = {
        "exportedFileName",
        "suggestedHumanReadableName",
        "isAssociatedWithFailure",
        "timestamp",
        "configurationName",
        "deviceName",
        "deviceId",
        "repetitionNumber",
        "arguments",
    }
    required_attachment_keys = {
        "exportedFileName",
        "suggestedHumanReadableName",
        "isAssociatedWithFailure",
        "configurationName",
        "deviceName",
        "deviceId",
    }
    if (
        type(attachment) is not dict
        or not required_attachment_keys.issubset(attachment)
        or not set(attachment).issubset(allowed_attachment_keys)
        or any(
            type(attachment[key]) is not str
            for key in (
                "exportedFileName",
                "suggestedHumanReadableName",
                "configurationName",
                "deviceName",
                "deviceId",
            )
        )
        or attachment["isAssociatedWithFailure"] is not False
        or attachment["deviceId"] != device
    ):
        fail("xcresult receipt attachment metadata is invalid")
    exported_name = attachment["exportedFileName"]
    suggested_name = attachment["suggestedHumanReadableName"]
    name_match = TEST_RECEIPT_ATTACHMENT_RE.fullmatch(suggested_name)
    if (
        SAFE_COMPONENT_RE.fullmatch(exported_name) is None
        or Path(exported_name).name != exported_name
        or name_match is None
    ):
        fail("xcresult receipt attachment name is invalid")
    receipt_raw = read_extracted_regular(
        attachment_root / exported_name,
        MAX_APPLICATION_RECEIPT_BYTES,
        "xcresult case-operation receipt",
    )
    receipt_sha = hashlib.sha256(receipt_raw).hexdigest()
    if receipt_sha != name_match.group(1):
        fail("xcresult receipt attachment name differs from its bytes")
    receipt = validate_application_case_receipt(receipt_raw, request, request_sha)
    return {
        "receipt": receipt,
        "raw": receipt_raw,
        "sha256": receipt_sha,
        "byteCount": len(receipt_raw),
    }


def require_copied_authorization_artifacts(
    snapshot: Path,
    request_raw: bytes,
    signature_raw: bytes,
) -> None:
    request_path = find_unique_named(
        snapshot,
        AUTHORIZATION_NAME,
        "post-execution evidence",
    )
    signature_path = find_unique_named(
        snapshot,
        AUTHORIZATION_SIGNATURE_NAME,
        "post-execution evidence",
    )
    if (
        read_extracted_regular(
            request_path,
            MAX_JSON_BYTES,
            "copied authorization request",
        )
        != request_raw
        or read_extracted_regular(
            signature_path,
            MAX_SIGNATURE_BYTES,
            "copied authorization signature",
        )
        != signature_raw
    ):
        fail("post-execution authorization artifacts differ from admitted bytes")


def operation_receipt_hashes(
    output: Path,
    ordered_steps: list[str],
) -> dict[str, str]:
    hashes: dict[str, str] = {}
    for step in ordered_steps:
        raw = read_extracted_regular(
            output / "operation-receipts" / f"{step}.json",
            MAX_JSON_BYTES,
            f"controller operation receipt {step}",
        )
        receipt = parse_canonical_json(raw, f"controller operation receipt {step}")
        if (
            receipt.get("contractId")
            != "sora-ios-wallet-migration-controller-operation-v1"
            or receipt.get("step") != step
            or receipt.get("exitCode") != 0
        ):
            fail(f"controller operation receipt is invalid: {step}")
        hashes[step] = hashlib.sha256(raw).hexdigest()
    return hashes


def execute_case(
    *,
    device: str,
    ipa_path: str,
    clone_receipt_path: str,
    xctestrun_path: str,
    request_path: str,
    signature_path: str,
    output_raw: str,
) -> dict[str, Any]:
    safe_device_id(device)
    output = create_private_output_root(output_raw, "case execution output")
    admitted = validate_signed_request(
        ipa_path,
        clone_receipt_path,
        request_path,
        signature_path,
        output,
    )
    request = admitted["request"]
    validate_case_pair(request["caseKind"], request["caseId"])
    if admitted["installableCloneReceipt"]["registeredDeviceUdidSha256"] != (
        hashlib.sha256(device.encode("utf-8")).hexdigest()
    ):
        fail("selected device differs from the protected clone receipt")
    clone_admission = recheck_installable_clone_artifacts(
        clone_receipt_path,
        admitted["installableCloneReceipt"],
        admitted["installableCloneReceiptSha256"],
    )
    clone_app = Path(clone_admission["appPath"])
    sanitizer_source_sha, _ = hash_extracted_regular(
        XCTESTRUN_SANITIZER_PATH,
        MAX_FILE_BYTES,
        "xctestrun sanitizer source",
    )
    sanitizer = load_xctestrun_sanitizer()
    sanitized_path = output / "exact-ipa-retained-case.xctestrun"
    try:
        sanitized = sanitizer.sanitize_xctestrun(
            Path(xctestrun_path),
            clone_app,
            sanitized_path,
        )
    except sanitizer.SanitizerError as error:
        fail(f"generated xctestrun was rejected: {error}")

    enrollment_snapshot = output / "pre-execution-enrollment"
    copy_from_device(
        output,
        "copy-pre-execution-enrollment",
        device,
        EVIDENCE_DIRECTORY,
        enrollment_snapshot,
    )
    nonce_sha, _ = require_enrollment_snapshot(enrollment_snapshot)
    if nonce_sha != request["enrollmentNonceSha256"]:
        fail("device enrollment nonce differs from signed authorization")
    pre_wallet = snapshot_wallet_from_device(
        output,
        "copy-pre-execution-wallet",
        device,
        output / "pre-execution-wallet",
        request["caseId"],
    )
    if pre_wallet["sha256"] != request["preparedWalletInputTreeSha256"]:
        fail("pre-execution wallet tree differs from signed prepared inputs")

    authorization_staging = output / "authorization-staging"
    authorization_staging.mkdir(mode=0o700)
    staged_request = authorization_staging / AUTHORIZATION_NAME
    staged_signature = authorization_staging / AUTHORIZATION_SIGNATURE_NAME
    if (
        write_new_file(staged_request, admitted["requestRaw"])
        != admitted["requestSha256"]
        or write_new_file(staged_signature, admitted["signatureRaw"])
        != admitted["signatureSha256"]
    ):
        fail("authorization staging changed admitted bytes")
    copy_to_device(
        output,
        "copy-authorization-request",
        device,
        staged_request,
        f"{EVIDENCE_DIRECTORY}/{AUTHORIZATION_NAME}",
    )
    copy_to_device(
        output,
        "copy-authorization-signature",
        device,
        staged_signature,
        f"{EVIDENCE_DIRECTORY}/{AUTHORIZATION_SIGNATURE_NAME}",
    )
    try:
        sanitizer.verify_sanitized_xctestrun(
            sanitized_path,
            clone_app,
            sanitized["sanitizedXctestrunSha256"],
        )
    except sanitizer.SanitizerError as error:
        fail(f"sanitized xctestrun failed its pre-install recheck: {error}")
    clone_before_test = recheck_installable_clone_artifacts(
        clone_receipt_path,
        admitted["installableCloneReceipt"],
        admitted["installableCloneReceiptSha256"],
    )
    if clone_before_test != clone_admission:
        fail("protected installable-clone artifact changed before installation")

    result_bundle = output / "exact-ipa-retained-case.xcresult"
    devicectl_command(
        output,
        "install-archive-derived-clone",
        ["device", "install", "app", "--device", device, str(clone_app)],
        timeout=300,
    )
    run_step(
        output,
        "test-without-building",
        [
            "/usr/bin/xcodebuild",
            "test-without-building",
            "-xctestrun",
            str(sanitized_path),
            "-destination",
            f"platform=iOS,id={device}",
            "-only-testing:SoraPassportUITests/"
            "RetainedMigrationEvidenceUITests/"
            "testExecuteAuthorizedRetainedMigrationCase",
            "-parallel-testing-enabled",
            "NO",
            "-resultBundlePath",
            str(result_bundle),
        ],
        timeout=1_800,
    )
    require_result_bundle(result_bundle)
    test_receipt = extract_test_receipt(
        output,
        result_bundle,
        device,
        request,
        admitted["requestSha256"],
    )

    result_snapshot = output / "post-execution-evidence"
    copy_from_device(
        output,
        "copy-post-execution-evidence",
        device,
        EVIDENCE_DIRECTORY,
        result_snapshot,
    )
    require_copied_authorization_artifacts(
        result_snapshot,
        admitted["requestRaw"],
        admitted["signatureRaw"],
    )
    application_receipt = require_application_receipt_snapshot(
        result_snapshot,
        request,
        admitted["requestSha256"],
    )
    if application_receipt["raw"] != test_receipt["raw"]:
        fail("xcresult receipt differs from the application evidence receipt")
    post_wallet = snapshot_wallet_from_device(
        output,
        "copy-post-execution-wallet",
        device,
        output / "post-execution-wallet",
        request["caseId"],
    )
    clone_after_test = recheck_installable_clone_artifacts(
        clone_receipt_path,
        admitted["installableCloneReceipt"],
        admitted["installableCloneReceiptSha256"],
    )
    if clone_after_test != clone_before_test:
        fail("protected installable-clone artifact changed during execution")
    try:
        sanitizer.verify_sanitized_xctestrun(
            sanitized_path,
            clone_app,
            sanitized["sanitizedXctestrunSha256"],
        )
    except sanitizer.SanitizerError as error:
        fail(f"sanitized xctestrun failed its post-test recheck: {error}")
    final_sanitizer_source_sha, _ = hash_extracted_regular(
        XCTESTRUN_SANITIZER_PATH,
        MAX_FILE_BYTES,
        "xctestrun sanitizer source final recheck",
    )
    if final_sanitizer_source_sha != sanitizer_source_sha:
        fail("xctestrun sanitizer source changed during case execution")

    external_order = [
        "copy-pre-execution-enrollment",
        "copy-pre-execution-wallet",
        "copy-authorization-request",
        "copy-authorization-signature",
        "install-archive-derived-clone",
        "test-without-building",
        "extract-test-receipt",
        "copy-post-execution-evidence",
        "copy-post-execution-wallet",
    ]
    if external_order.index("test-without-building") != (
        external_order.index("install-archive-derived-clone") + 1
    ):
        fail("installable clone was not reinstalled immediately before XCTest")
    operation_hashes = operation_receipt_hashes(output, external_order)
    controller_receipt = {
        "schemaVersion": 3,
        "contractId": CASE_RECEIPT_CONTRACT_ID,
        "platform": PLATFORM,
        "status": "observed",
        "releaseAuthorized": False,
        "runId": request["runId"],
        "caseKind": request["caseKind"],
        "caseId": request["caseId"],
        "authorizationRequestSha256": admitted["requestSha256"],
        "authorizationSignatureSha256": admitted["signatureSha256"],
        "installableCloneReceiptSha256": admitted[
            "installableCloneReceiptSha256"
        ],
        "sanitizerSourceSha256": sanitizer_source_sha,
        "sourceXctestrunSha256": sanitized["sourceXctestrunSha256"],
        "sanitizedXctestrunSha256": sanitized[
            "sanitizedXctestrunSha256"
        ],
        "applicationReceiptSha256": application_receipt["sha256"],
        "applicationReceiptByteCount": application_receipt["byteCount"],
        "xcresultReceiptSha256": test_receipt["sha256"],
        "xcresultReceiptByteCount": test_receipt["byteCount"],
        "preExecutionWalletInputTreeSha256": pre_wallet["sha256"],
        "preExecutionWalletInputTreeRecordByteCount": pre_wallet[
            "recordByteCount"
        ],
        "postExecutionWalletInputTreeSha256": post_wallet["sha256"],
        "postExecutionWalletInputTreeRecordByteCount": post_wallet[
            "recordByteCount"
        ],
        "cloneIdentityBeforeTest": clone_before_test,
        "cloneIdentityAfterTest": clone_after_test,
        "externalOperationOrder": external_order,
        "externalOperationReceiptSha256": operation_hashes,
        "checks": {
            "authorizationSignatureVerified": True,
            "protectedCloneReceiptBound": True,
            "sanitizedXctestrunVerifiedBeforeAndAfter": True,
            "rebuiltHostInstallDisabled": True,
            "preparedWalletTreeMatched": True,
            "cloneReinstalledImmediatelyBeforeTest": True,
            "testWithoutBuildingSucceeded": True,
            "applicationReceiptExtractedAndValidated": True,
            "cloneIdentityStableBeforeAndAfter": True,
            "postExecutionWalletTreeCaptured": True,
            "caseSpecificExpectationSatisfied": True,
            "qualificationCreated": False,
        },
        "blockingReasons": [NONAUTHORIZING_BLOCKER],
    }
    controller_raw = canonical_json(controller_receipt)
    controller_sha = write_new_file(
        output / CONTROLLER_RECEIPT_NAME,
        controller_raw,
    )
    write_new_file(
        output / ".complete",
        canonical_json(
            {
                "schemaVersion": 1,
                "contractId": (
                    "sora-ios-wallet-migration-case-controller-complete-v1"
                ),
                "caseControllerReceiptSha256": controller_sha,
                "releaseAuthorized": False,
            }
        ),
    )
    return {
        "caseControllerReceiptSha256": controller_sha,
        "applicationReceiptSha256": application_receipt["sha256"],
        "sanitizedXctestrunSha256": sanitized["sanitizedXctestrunSha256"],
        "preExecutionWalletInputTreeSha256": pre_wallet["sha256"],
        "postExecutionWalletInputTreeSha256": post_wallet["sha256"],
    }


def lint_contract() -> None:
    if (
        CONTRACT_ID != "sora-ios-wallet-migration-exact-ipa-controller-v1"
        or len(KEYCHAIN_CASES) != 8
        or len(DEVICE_CASES) != 10
        or len(REQUEST_KEYS) != 26
        or not CLONE_BOUND_AUTHORIZATION_KEYS.issubset(REQUEST_KEYS)
        or ("extracted" + "AppRawTreeSha256") in REQUEST_KEYS
        or len(INSTALLABLE_CLONE_RECEIPT_KEYS) != 21
        or len(INSTALLABLE_CLONE_CHECK_KEYS) != 7
        or len(INTERRUPTION_CHECKPOINTS) != 6
        or len(RECOVERY_ROUTE_CASES) != 10
        or len(SUCCESS_ROUTE_CASES) != 8
        or RECOVERY_ROUTE_CASES & SUCCESS_ROUTE_CASES
        or RECOVERY_ROUTE_CASES | SUCCESS_ROUTE_CASES
        != KEYCHAIN_CASES | DEVICE_CASES
        or CLONE_OMITTED_SIGNING_ENTITLEMENTS
        != frozenset(
            {"aps-environment", "beta-reports-active", "get-task-allow"}
        )
        or INSTALLABLE_CLONE_CONTRACT_ID
        != "sora-ios-wallet-migration-installable-clone-v1"
        or not PROJECTOR_PATH.is_file()
        or not XCTESTRUN_SANITIZER_PATH.is_file()
        or not Path("/usr/bin/xcrun").is_file()
        or not Path("/usr/bin/xcodebuild").is_file()
        or not Path("/usr/bin/codesign").is_file()
        or not Path("/usr/bin/security").is_file()
        or not Path("/usr/bin/openssl").is_file()
    ):
        fail("exact-IPA retained-device controller contract is incomplete")
    canonical_projector_source_sha256()
    load_xctestrun_sanitizer()


def validate_authority_binding(
    key_id: str,
    public_point_base64: str,
    source_revision: str,
) -> dict[str, str]:
    if KEY_ID_RE.fullmatch(key_id) is None:
        fail("evidence authorization key ID has an unsafe shape")
    if (
        SOURCE_REVISION_RE.fullmatch(source_revision) is None
        or source_revision == "0" * 40
    ):
        fail("evidence source revision is not one nonzero lowercase commit ID")
    if len(public_point_base64) > 128:
        fail("evidence authorization public point exceeds its bound")
    try:
        public_point = base64.b64decode(public_point_base64, validate=True)
    except (ValueError, TypeError):
        fail("evidence authorization public point is not canonical Base64")
    if public_point_base64 != base64.b64encode(public_point).decode("ascii"):
        fail("evidence authorization public point has an alternate Base64 encoding")
    validate_p256_public_point(public_point)
    return {
        "authorizationKeyIdSha256": hashlib.sha256(key_id.encode("utf-8")).hexdigest(),
        "authorizationPublicPointSha256": hashlib.sha256(public_point).hexdigest(),
        "sourceRevision": source_revision,
    }


def main(argv: list[str]) -> int:
    try:
        if argv == ["--lint-contract"]:
            lint_contract()
            print("iOS migration exact-IPA retained-device controller contract: OK")
            return 0
        if (
            len(argv) == 7
            and argv[0] == "--validate-authority-binding"
            and argv[1] == "--key-id"
            and argv[3] == "--public-point-base64"
            and argv[5] == "--source-revision"
        ):
            lint_contract()
            result = validate_authority_binding(argv[2], argv[4], argv[6])
            print(
                "authorizationKeyIdSha256={authorizationKeyIdSha256} "
                "authorizationPublicPointSha256={authorizationPublicPointSha256} "
                "sourceRevision={sourceRevision}".format(**result)
            )
            return 0
        if (
            len(argv) == 9
            and argv[0] == "--validate-authorization"
            and argv[1] == "--ipa"
            and argv[3] == "--installable-clone-receipt"
            and argv[5] == "--request"
            and argv[7] == "--signature"
        ):
            lint_contract()
            with tempfile.TemporaryDirectory(
                prefix="sora-ios-migration-authorization-"
            ) as temp:
                result = validate_signed_request(
                    argv[2], argv[4], argv[6], argv[8], Path(temp)
                )
            print(
                "requestSha256={requestSha256} signatureSha256={signatureSha256} "
                "ipaSha256={ipaSha256} "
                "installableCloneReceiptSha256={installableCloneReceiptSha256}".format(
                    requestSha256=result["requestSha256"],
                    signatureSha256=result["signatureSha256"],
                    ipaSha256=result["identity"]["ipaSha256"],
                    installableCloneReceiptSha256=result[
                        "installableCloneReceiptSha256"
                    ],
                )
            )
            return 0
        if (
            len(argv) == 15
            and argv[0] == "--execute-case"
            and argv[1] == "--device"
            and argv[3] == "--ipa"
            and argv[5] == "--installable-clone-receipt"
            and argv[7] == "--xctestrun"
            and argv[9] == "--request"
            and argv[11] == "--signature"
            and argv[13] == "--output-root"
        ):
            lint_contract()
            result = execute_case(
                device=argv[2],
                ipa_path=argv[4],
                clone_receipt_path=argv[6],
                xctestrun_path=argv[8],
                request_path=argv[10],
                signature_path=argv[12],
                output_raw=argv[14],
            )
            print(" ".join(f"{key}={value}" for key, value in result.items()))
            return 0
        if (
            len(argv) == 15
            and argv[0] == "--prepare-case"
            and argv[1] == "--device"
            and argv[3] == "--ipa"
            and argv[5] == "--run-id"
            and argv[7] == "--run-challenge-sha256"
            and argv[9] == "--case-kind"
            and argv[11] == "--case-id"
            and argv[13] == "--output-root"
        ):
            lint_contract()
            result = prepare_case(
                device=argv[2],
                ipa_path=argv[4],
                run_id=argv[6],
                run_challenge_sha=argv[8],
                case_kind=argv[10],
                case_id=argv[12],
                output_raw=argv[14],
            )
            print(
                "casePreparationSha256={casePreparationSha256} "
                "productionIpaSha256={productionIpaSha256} "
                "enrollmentNonceSha256={enrollmentNonceSha256} "
                "preparedWalletInputTreeSha256={preparedWalletInputTreeSha256}".format(
                    **result
                )
            )
            return 0
        fail(
            "usage: run-ios-migration-exact-ipa-evidence.py --lint-contract | "
            "--validate-authorization --ipa /private/Sora.ipa "
            "--installable-clone-receipt /private/clone/installable-clone-receipt-v1.json "
            "--request /private/authorization-request-v3.json "
            "--signature /private/authorization-request-v3.sig | "
            "--execute-case --device DEVICE-UDID --ipa /private/Sora.ipa "
            "--installable-clone-receipt /private/clone/installable-clone-receipt-v1.json "
            "--xctestrun /private/generated.xctestrun "
            "--request /private/authorization-request-v3.json "
            "--signature /private/authorization-request-v3.sig "
            "--output-root /private/fresh-execution-directory | "
            "--validate-authority-binding --key-id REVIEWED-ID "
            "--public-point-base64 X963-BASE64 --source-revision COMMIT | "
            "--prepare-case --device DEVICE-UDID --ipa /private/Sora.ipa "
            "--run-id UUID --run-challenge-sha256 SHA256 "
            "--case-kind keychain-or-device --case-id REVIEWED-CASE "
            "--output-root /private/fresh-case-directory"
        )
    except (ControllerError, OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
