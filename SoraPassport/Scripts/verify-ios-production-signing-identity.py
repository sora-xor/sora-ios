#!/usr/bin/env python3
"""Authenticate retained iOS production-signing continuity without key material."""

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
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "Fixtures/Modernization"
INVENTORY = FIXTURES / "ios-production-signing-identity.json"
BLOCKED_RECEIPT = (
    FIXTURES / "ios-production-signing-identity-qualification.blocked.json"
)
BLOCKED_TRUST = (
    FIXTURES / "ios-production-signing-identity-qualification-trust.blocked.json"
)
OPENSSL = Path("/usr/bin/openssl")
MAX_JSON_BYTES = 2 * 1024 * 1024
MAX_KEY_BYTES = 16 * 1024
MAX_SIGNATURE_BYTES = 16 * 1024
MAX_CONTRACT_FILE_BYTES = 64 * 1024 * 1024
MAX_SAFE_INTEGER = 9_007_199_254_740_991
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SHA1_UPPER_RE = re.compile(r"^[0-9A-F]{40}$")
REVISION_RE = re.compile(r"^[0-9a-f]{40}$")
KEY_ID_RE = re.compile(r"^[a-z][a-z0-9._-]{2,127}$")
PROFILE_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 ._():+-]{2,127}$")
SAFE_OPENSSL_ENV = {"PATH": "/usr/bin:/bin", "LANG": "C", "LC_ALL": "C"}

CONTRACT_FILES = (
    "Fixtures/Modernization/ios-production-signing-identity.json",
    "Fixtures/Modernization/ios-production-signing-identity-qualification.blocked.json",
    "Fixtures/Modernization/ios-production-signing-identity-qualification-trust.blocked.json",
    "Fixtures/Modernization/ios-production-signing-identity-qualification-README.md",
    "SoraPassport/SoraPassport.entitlements",
    "SoraPassport/Configs/SoraPassport.release.xcconfig",
    "SoraPassport/Info.plist",
    "SoraPassport.xcodeproj/project.pbxproj",
    "SoraPassport/Scripts/verify-ios-production-signing-identity.py",
    "SoraPassport/Scripts/verify-ios-production-signing-identity.sh",
    "SoraPassport/Scripts/test-ios-production-signing-identity.py",
    "SoraPassport/Scripts/verify-ios-release-reproducibility-package.py",
    "SoraPassport/Scripts/test-ios-release-reproducibility-package.py",
    "SoraPassport/Scripts/verify-modernization-dependencies.sh",
)

RECEIPT_KEYS = {
    "schemaVersion",
    "contractId",
    "platform",
    "status",
    "runId",
    "qualificationSequenceNumber",
    "sourceRevision",
    "assessedAtEpochSeconds",
    "reviewedAtEpochSeconds",
    "qualifiedAtEpochSeconds",
    "qualificationContractSha256",
    "trustRootSha256",
    "releaseEvidenceProducerKeyId",
    "independentReviewerKeyId",
    "bundleIdentifier",
    "developmentTeam",
    "applicationIdentifier",
    "codeSignStyle",
    "configuredCodeSignIdentitySha1",
    "entitlementsPath",
    "sourceEntitlementsSha256",
    "signedEntitlementsSha256",
    "keychainAccessGroupsSha256",
    "productionDistributionCertificateSha256",
    "productionDistributionCertificateSha1",
    "productionProvisioningProfileUuid",
    "productionProvisioningProfileName",
    "rawProvisioningProfileSha256",
    "canonicalProvisioningProfileSha256",
    "releaseLineage",
    "privateKeyOrCredentialRecorded",
    "blockingReasons",
}
LINEAGE_KEYS = {
    "type",
    "appStoreAdamId",
    "priorAcceptedMarketingVersion",
    "priorAcceptedBuildNumber",
    "priorUploadedIpaSha256",
    "priorUploadReceiptSha256",
    "bundleIdentifierContinuityReviewed",
    "developmentTeamContinuityReviewed",
    "applicationIdentifierContinuityReviewed",
    "keychainAccessGroupsContinuityReviewed",
}
TRUST_KEYS = {
    "schemaVersion",
    "contractId",
    "platform",
    "status",
    "signatureAlgorithm",
    "authorities",
    "replayPolicy",
    "blockingReasons",
}

EXPECTED_RELEASE_LINEAGE = {
    "type": "existing-app-update",
    "appStoreAdamId": "1457566711",
    "priorAcceptedMarketingVersion": "3.8.7",
    "priorAcceptedBuildNumber": "2026081001",
    "priorUploadedIpaSha256":
        "e8bc51066da5da3442a687687134f3e0dd5af7f12d32c8b055b2336207612b94",
    "priorUploadReceiptSha256":
        "1df6fdcf7fda9c0a433b177205e2bbf9a576623c4c6226c9d0dfafe7d445cf8e",
    "bundleIdentifierContinuityReviewed": True,
    "developmentTeamContinuityReviewed": True,
    "applicationIdentifierContinuityReviewed": True,
    "keychainAccessGroupsContinuityReviewed": True,
}
EXPECTED_DISTRIBUTION_CERTIFICATE_SHA1 = (
    "84AB95335BE14CAE9B050A353910F86FF2F9539B"
)
EXPECTED_DISTRIBUTION_CERTIFICATE_SHA256 = (
    "d830d54bce8e583089f2ed8cf927fc12b60c9d591e560ffe6f5d2a71c91317fb"
)
EXPECTED_PROFILE_UUID = "7ae520bc-599b-48ae-abfa-627eef530f0c"
EXPECTED_PROFILE_NAME = "iOS Team Store Provisioning Profile: co.jp.soramitsu.sora"
EXPECTED_RAW_PROFILE_SHA256 = (
    "19073a93bc09fe061e2346470b57aae1961aa38ad4c6b4922e0140bf8061bf93"
)
EXPECTED_CANONICAL_PROFILE_SHA256 = (
    "f6d534c50ba641341337a6ce9b34f55db7931491c43554ededffb8a47d88b931"
)
EXPECTED_SIGNED_ENTITLEMENTS_SHA256 = (
    "6ce476d496fb75e4510b9dfce490dc6c29d78b96d9114c85a44b09d9d2756b2d"
)
EXPECTED_KEYCHAIN_ACCESS_GROUPS_SHA256 = (
    "6382618e08a2e9678e9c4b1f2dec83836c3aeb2aea1508df83dde886979efdc0"
)


def fail(message: str) -> None:
    raise SystemExit(f"error: {message}")


def canonical_json(value: Any) -> bytes:
    return (
        json.dumps(value, ensure_ascii=True, separators=(",", ":"), sort_keys=True)
        + "\n"
    ).encode("utf-8")


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def duplicate_rejecting_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            fail(f"JSON contains duplicate key {key!r}")
        result[key] = value
    return result


def parse_json_integer(raw: str) -> int:
    if raw == "-0":
        fail("JSON contains negative zero")
    value = int(raw)
    if abs(value) > MAX_SAFE_INTEGER:
        fail("JSON integer exceeds the interoperable safe-integer bound")
    return value


def reject_json_float(raw: str) -> float:
    fail(f"JSON contains forbidden floating-point token {raw!r}")


def reject_json_constant(raw: str) -> float:
    fail(f"JSON contains forbidden non-finite token {raw!r}")


def load_json_bytes(raw: bytes, label: str, *, canonical: bool = False) -> dict[str, Any]:
    try:
        value = json.loads(
            raw.decode("utf-8"),
            object_pairs_hook=duplicate_rejecting_object,
            parse_int=parse_json_integer,
            parse_float=reject_json_float,
            parse_constant=reject_json_constant,
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fail(f"{label} is not strict UTF-8 JSON: {error}")
    if type(value) is not dict:
        fail(f"{label} is not a JSON object")
    if canonical and canonical_json(value) != raw:
        fail(f"{label} is not canonical JSON")
    return value


def metadata_identity(value: os.stat_result) -> tuple[int, ...]:
    return (
        value.st_dev,
        value.st_ino,
        value.st_mode,
        value.st_nlink,
        value.st_uid,
        value.st_size,
        value.st_mtime_ns,
    )


class StableInputs:
    def __init__(self, snapshot_root: Path) -> None:
        self.snapshot_root = snapshot_root
        self.records: list[tuple[Path, tuple[int, ...], str]] = []
        self.counter = 0

    def read(
        self,
        path: Path,
        maximum: int,
        label: str,
        *,
        owner_only: bool = False,
    ) -> tuple[Path, bytes]:
        flags = os.O_RDONLY
        if hasattr(os, "O_NOFOLLOW"):
            flags |= os.O_NOFOLLOW
        if hasattr(os, "O_CLOEXEC"):
            flags |= os.O_CLOEXEC
        try:
            descriptor = os.open(path, flags)
        except OSError as error:
            fail(f"{label} cannot be opened without following aliases: {error}")
        try:
            before = os.fstat(descriptor)
            if (
                not stat.S_ISREG(before.st_mode)
                or before.st_nlink != 1
                or before.st_size <= 0
                or before.st_size > maximum
                or (
                    owner_only
                    and (
                        before.st_uid != os.getuid()
                        or stat.S_IMODE(before.st_mode) != 0o600
                    )
                )
            ):
                fail(f"{label} is not one bounded regular inode")
            raw = os.read(descriptor, maximum + 1)
            if len(raw) != before.st_size or os.read(descriptor, 1):
                fail(f"{label} changed or exceeded its byte bound while read")
            after = os.fstat(descriptor)
        finally:
            os.close(descriptor)
        named = os.stat(path, follow_symlinks=False)
        identity = metadata_identity(before)
        if identity != metadata_identity(after) or identity != metadata_identity(named):
            fail(f"{label} changed while read")
        self.counter += 1
        snapshot = self.snapshot_root / f"{self.counter:03d}.input"
        descriptor = os.open(snapshot, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        try:
            if os.write(descriptor, raw) != len(raw):
                fail(f"{label} snapshot write was incomplete")
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
        self.records.append((path, identity, sha256_bytes(raw)))
        return snapshot, raw

    def json(
        self,
        path: Path,
        label: str,
        *,
        canonical: bool = False,
        owner_only: bool = False,
    ) -> tuple[Path, bytes, dict[str, Any]]:
        snapshot, raw = self.read(
            path,
            MAX_JSON_BYTES,
            label,
            owner_only=owner_only,
        )
        return snapshot, raw, load_json_bytes(raw, label, canonical=canonical)

    def recheck_all(self) -> None:
        for path, expected_identity, expected_sha in self.records:
            flags = os.O_RDONLY
            if hasattr(os, "O_NOFOLLOW"):
                flags |= os.O_NOFOLLOW
            if hasattr(os, "O_CLOEXEC"):
                flags |= os.O_CLOEXEC
            try:
                descriptor = os.open(path, flags)
            except OSError as error:
                fail(f"protected input changed before admission completed: {error}")
            try:
                before = os.fstat(descriptor)
                digest = hashlib.sha256()
                consumed = 0
                while True:
                    chunk = os.read(descriptor, 1024 * 1024)
                    if not chunk:
                        break
                    consumed += len(chunk)
                    if consumed > expected_identity[5]:
                        fail("protected input grew before admission completed")
                    digest.update(chunk)
                after = os.fstat(descriptor)
            finally:
                os.close(descriptor)
            named = os.stat(path, follow_symlinks=False)
            if (
                consumed != expected_identity[5]
                or metadata_identity(before) != expected_identity
                or metadata_identity(after) != expected_identity
                or metadata_identity(named) != expected_identity
                or digest.hexdigest() != expected_sha
            ):
                fail("protected input changed before admission completed")


def exact_keys(value: Any, keys: set[str], label: str) -> dict[str, Any]:
    if type(value) is not dict or set(value) != keys:
        fail(f"{label} has a stale, mixed, or incomplete shape")
    return value


def require_sha256(value: Any, label: str, expected: str | None = None) -> str:
    if (
        type(value) is not str
        or SHA256_RE.fullmatch(value) is None
        or value == "0" * 64
    ):
        fail(f"{label} is not a nonzero lowercase SHA-256")
    if expected is not None and value != expected:
        fail(f"{label} differs from its protected SHA-256")
    return value


def require_revision(value: Any, label: str, expected: str | None = None) -> str:
    if (
        type(value) is not str
        or REVISION_RE.fullmatch(value) is None
        or value == "0" * 40
    ):
        fail(f"{label} is not one nonzero source revision")
    if expected is not None and value != expected:
        fail(f"{label} differs from the protected source revision")
    return value


def require_positive_int(value: Any, label: str) -> int:
    if type(value) is not int or value <= 0 or value > MAX_SAFE_INTEGER:
        fail(f"{label} is not one positive safe integer")
    return value


def required_env(name: str) -> str:
    value = os.environ.get(name)
    if value is None or not value or len(value) > 4096:
        fail(f"protected environment variable {name} is required")
    return value


def protected_path(name: str) -> Path:
    raw = required_env(name)
    path = Path(raw)
    if not path.is_absolute() or str(path) != raw or raw == "/":
        fail(f"{name} must name one canonical absolute path")
    if any(part in ("", ".", "..") for part in path.parts[1:]):
        fail(f"{name} contains an unsafe path component")
    try:
        parent = path.parent.resolve(strict=True)
    except OSError as error:
        fail(f"{name} parent cannot be resolved: {error}")
    if parent != path.parent:
        fail(f"{name} traverses a symbolic or noncanonical parent")
    try:
        path.relative_to(ROOT)
    except ValueError:
        return path
    fail(f"{name} must not use a repository-controlled path")


def contract_sha256(inputs: StableInputs) -> str:
    records: list[dict[str, str]] = []
    if len(CONTRACT_FILES) != len(set(CONTRACT_FILES)):
        fail("signing-continuity contract file inventory contains duplicates")
    for relative in CONTRACT_FILES:
        path = ROOT / relative
        _, raw = inputs.read(
            path,
            MAX_CONTRACT_FILE_BYTES,
            f"signing-continuity contract file {relative}",
        )
        records.append({"path": relative, "sha256": sha256_bytes(raw)})
    return sha256_bytes(canonical_json(records))


def validate_blocked_templates(inputs: StableInputs) -> None:
    _, _, inventory = inputs.json(INVENTORY, "production signing-identity inventory")
    if inventory != {
        "schemaVersion": 2,
        "platform": "ios",
        "assessedAt": "2026-08-24",
        "status": "configured",
        "releaseEnabled": False,
        "releaseLineage": EXPECTED_RELEASE_LINEAGE,
        "bundleIdentifier": "co.jp.soramitsu.sora",
        "developmentTeam": "YLWWUD25VZ",
        "applicationIdentifier": "YLWWUD25VZ.co.jp.soramitsu.sora",
        "projectCodeSignStyle": "Automatic",
        "projectConfiguredCodeSignIdentity": "iPhone Developer",
        "releaseArchiveCodeSignStyle": "Manual",
        "releaseArchiveCodeSignIdentitySha1":
            EXPECTED_DISTRIBUTION_CERTIFICATE_SHA1,
        "entitlementsPath": "SoraPassport/SoraPassport.entitlements",
        "entitlementsSha256":
            "97704a8960b4facceef54397a08fb5d0a456247c3627359215aa2a27df22656c",
        "signedEntitlementsSha256": EXPECTED_SIGNED_ENTITLEMENTS_SHA256,
        "keychainAccessGroupsSha256": EXPECTED_KEYCHAIN_ACCESS_GROUPS_SHA256,
        "productionDistributionCertificateSha1":
            EXPECTED_DISTRIBUTION_CERTIFICATE_SHA1,
        "productionDistributionCertificateSha256":
            EXPECTED_DISTRIBUTION_CERTIFICATE_SHA256,
        "productionProvisioningProfileUuid": EXPECTED_PROFILE_UUID,
        "productionProvisioningProfileName": EXPECTED_PROFILE_NAME,
        "rawProvisioningProfileSha256": EXPECTED_RAW_PROFILE_SHA256,
        "canonicalProvisioningProfileSha256":
            EXPECTED_CANONICAL_PROFILE_SHA256,
        "archivedApplicationCertificateMatched": True,
        "archivedProvisioningProfileMatched": True,
        "archivedEntitlementsMatched": True,
        "appStoreRecordContinuityObserved": True,
        "keychainAccessGroupsUnchanged": True,
        "privateKeyOrCredentialRecorded": False,
        "blocker": {
            "code": "ios_production_signing_admission_not_supplied",
            "reason": (
                "The real Apple signing selection and existing App Store lineage are "
                "configured, but the current clean revision still requires an external "
                "dual-authority admission and protected release-runner credentials."
            ),
        },
        "exitCriteria": [
            "materialize the authorized Apple Distribution private identity and exact App Store profile in the protected release runner",
            "obtain a fresh dual-P-256-signed signing-selection and existing-app-lineage receipt for the exact clean source revision",
            "archive and export with the pinned manual certificate and provisioning-profile selection",
            "match both independently reproduced IPAs to the admitted certificate, profile, entitlements, application identity, and Keychain groups",
        ],
    }:
        fail("production signing-identity inventory drifted")

    _, _, blocked_receipt = inputs.json(
        BLOCKED_RECEIPT, "blocked signing-continuity receipt"
    )
    if blocked_receipt != {
        "schemaVersion": 2,
        "contractId": "sora-ios-production-signing-identity-qualification-v2",
        "platform": "ios",
        "status": "blocked",
        "runId": None,
        "qualificationSequenceNumber": 0,
        "sourceRevision": None,
        "assessedAtEpochSeconds": 0,
        "reviewedAtEpochSeconds": 0,
        "qualifiedAtEpochSeconds": 0,
        "qualificationContractSha256": None,
        "trustRootSha256": None,
        "releaseEvidenceProducerKeyId": None,
        "independentReviewerKeyId": None,
        "bundleIdentifier": "co.jp.soramitsu.sora",
        "developmentTeam": "YLWWUD25VZ",
        "applicationIdentifier": "YLWWUD25VZ.co.jp.soramitsu.sora",
        "codeSignStyle": "Manual",
        "configuredCodeSignIdentitySha1":
            EXPECTED_DISTRIBUTION_CERTIFICATE_SHA1,
        "entitlementsPath": "SoraPassport/SoraPassport.entitlements",
        "sourceEntitlementsSha256":
            "97704a8960b4facceef54397a08fb5d0a456247c3627359215aa2a27df22656c",
        "signedEntitlementsSha256": EXPECTED_SIGNED_ENTITLEMENTS_SHA256,
        "keychainAccessGroupsSha256": EXPECTED_KEYCHAIN_ACCESS_GROUPS_SHA256,
        "productionDistributionCertificateSha256":
            EXPECTED_DISTRIBUTION_CERTIFICATE_SHA256,
        "productionDistributionCertificateSha1":
            EXPECTED_DISTRIBUTION_CERTIFICATE_SHA1,
        "productionProvisioningProfileUuid": EXPECTED_PROFILE_UUID,
        "productionProvisioningProfileName": EXPECTED_PROFILE_NAME,
        "rawProvisioningProfileSha256": EXPECTED_RAW_PROFILE_SHA256,
        "canonicalProvisioningProfileSha256":
            EXPECTED_CANONICAL_PROFILE_SHA256,
        "releaseLineage": EXPECTED_RELEASE_LINEAGE,
        "privateKeyOrCredentialRecorded": False,
        "blockingReasons": [
            "protected dual-authority signing-selection and lineage admission is absent"
        ],
    }:
        fail("blocked signing-continuity receipt drifted")

    _, _, blocked_trust = inputs.json(BLOCKED_TRUST, "blocked signing trust root")
    if blocked_trust != {
        "schemaVersion": 2,
        "contractId": "sora-ios-production-signing-identity-trust-v2",
        "platform": "ios",
        "status": "blocked",
        "signatureAlgorithm": "ecdsa-p256-sha256",
        "authorities": {
            "releaseEvidenceProducer": {
                "role": "release-evidence-producer",
                "keyId": None,
                "publicKeyPemSha256": None,
                "enabled": False,
            },
            "independentReviewer": {
                "role": "independent-reviewer",
                "keyId": None,
                "publicKeyPemSha256": None,
                "enabled": False,
            },
        },
        "replayPolicy": {
            "maximumQualificationAgeSeconds": 2_592_000,
            "maximumReviewDelaySeconds": 86_400,
        },
        "blockingReasons": ["protected signing-continuity trust roots are absent"],
    }:
        fail("blocked signing trust root drifted")


def validate_key_id(value: Any, label: str, prefix: str) -> str:
    suffix = value[len(prefix) :] if type(value) is str and value.startswith(prefix) else ""
    if (
        type(value) is not str
        or KEY_ID_RE.fullmatch(value) is None
        or not value.startswith(prefix)
        or re.fullmatch(r"[a-z][a-z0-9._-]{2,31}", suffix) is None
        or SHA256_RE.fullmatch(suffix) is not None
    ):
        fail(f"{label} is not a canonical role key ID")
    return value


def validate_p256_key(path: Path, expected_sha: str, label: str) -> bytes:
    if sha256_bytes(path.read_bytes()) != expected_sha:
        fail(f"{label} differs from its protected SHA-256")
    described = subprocess.run(
        [str(OPENSSL), "ec", "-pubin", "-in", str(path), "-text", "-noout"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
        text=True,
        env=SAFE_OPENSSL_ENV,
    )
    if described.returncode != 0:
        fail(f"{label} is not a valid EC public key")
    if not (
        "ASN1 OID: prime256v1" in described.stdout
        or "NIST CURVE: P-256" in described.stdout
    ):
        fail(f"{label} must use ECDSA P-256")
    canonical = subprocess.run(
        [
            str(OPENSSL), "ec", "-pubin", "-in", str(path), "-pubout",
            "-conv_form", "uncompressed", "-param_enc", "named_curve",
            "-outform", "DER",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
        env=SAFE_OPENSSL_ENV,
    )
    if canonical.returncode != 0 or not canonical.stdout:
        fail(f"{label} could not be canonicalized as SPKI DER")
    return canonical.stdout


def verify_signature(
    payload: Path,
    signature: Path,
    key: Path,
    label: str,
) -> None:
    result = subprocess.run(
        [
            str(OPENSSL), "dgst", "-sha256", "-verify", str(key),
            "-signature", str(signature), str(payload),
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
        env=SAFE_OPENSSL_ENV,
    )
    if result.returncode != 0:
        fail(f"{label} signature is invalid")


def canonical_uuid(value: Any, label: str, *, version: int | None = None) -> str:
    if type(value) is not str or len(value) != 36 or value.lower() != value:
        fail(f"{label} is not a canonical UUID")
    try:
        parsed = uuid.UUID(value)
    except ValueError:
        fail(f"{label} is not a canonical UUID")
    if str(parsed) != value or (version is not None and parsed.version != version):
        fail(f"{label} is not a canonical UUID")
    return value


def verify_qualified() -> str:
    expected_source = require_revision(
        required_env("IOS_SIGNING_IDENTITY_SOURCE_REVISION"), "protected source revision"
    )
    expected_run = canonical_uuid(
        required_env("IOS_SIGNING_IDENTITY_RUN_ID"), "protected run ID", version=4
    )
    raw_sequence = required_env("IOS_SIGNING_IDENTITY_SEQUENCE_NUMBER")
    if re.fullmatch(r"[1-9][0-9]{0,15}", raw_sequence) is None:
        fail("protected signing sequence is not canonical")
    expected_sequence = int(raw_sequence)
    if expected_sequence > MAX_SAFE_INTEGER:
        fail("protected signing sequence exceeds the safe-integer bound")
    expected_contract = require_sha256(
        required_env("IOS_SIGNING_IDENTITY_CONTRACT_SHA256"),
        "protected signing contract",
    )
    expected_trust = require_sha256(
        required_env("IOS_SIGNING_IDENTITY_TRUST_SHA256"),
        "protected signing trust root",
    )
    expected_producer_key = require_sha256(
        required_env("IOS_SIGNING_IDENTITY_PRODUCER_PUBLIC_KEY_SHA256"),
        "protected signing producer key",
    )
    expected_reviewer_key = require_sha256(
        required_env("IOS_SIGNING_IDENTITY_REVIEWER_PUBLIC_KEY_SHA256"),
        "protected signing reviewer key",
    )

    with tempfile.TemporaryDirectory(prefix="sora-ios-signing-identity.") as temporary:
        snapshot_root = Path(temporary)
        os.chmod(snapshot_root, 0o700)
        inputs = StableInputs(snapshot_root)
        validate_blocked_templates(inputs)
        if contract_sha256(inputs) != expected_contract:
            fail("signing-continuity contract differs from its protected SHA-256")
        receipt_path, receipt_raw, receipt = inputs.json(
            protected_path("IOS_SIGNING_IDENTITY_RECEIPT_PATH"),
            "signing-selection and lineage receipt",
            canonical=True,
            owner_only=True,
        )
        trust_path, trust_raw, trust = inputs.json(
            protected_path("IOS_SIGNING_IDENTITY_TRUST_PATH"),
            "signing-selection trust root",
            canonical=True,
            owner_only=True,
        )
        exact_keys(receipt, RECEIPT_KEYS, "signing-continuity receipt")
        exact_keys(trust, TRUST_KEYS, "signing-continuity trust root")

        producer_key, _ = inputs.read(
            protected_path("IOS_SIGNING_IDENTITY_PRODUCER_PUBLIC_KEY_PATH"),
            MAX_KEY_BYTES,
            "signing producer public key",
            owner_only=True,
        )
        reviewer_key, _ = inputs.read(
            protected_path("IOS_SIGNING_IDENTITY_REVIEWER_PUBLIC_KEY_PATH"),
            MAX_KEY_BYTES,
            "signing reviewer public key",
            owner_only=True,
        )
        producer_signature, _ = inputs.read(
            protected_path("IOS_SIGNING_IDENTITY_PRODUCER_SIGNATURE_PATH"),
            MAX_SIGNATURE_BYTES,
            "signing producer signature",
            owner_only=True,
        )
        reviewer_signature, _ = inputs.read(
            protected_path("IOS_SIGNING_IDENTITY_REVIEWER_SIGNATURE_PATH"),
            MAX_SIGNATURE_BYTES,
            "signing reviewer signature",
            owner_only=True,
        )

        trust_sha = require_sha256(
            sha256_bytes(trust_raw), "signing trust root", expected_trust
        )
        if (
            trust["schemaVersion"] != 2
            or trust["contractId"] != "sora-ios-production-signing-identity-trust-v2"
            or trust["platform"] != "ios"
            or trust["status"] != "qualified"
            or trust["signatureAlgorithm"] != "ecdsa-p256-sha256"
            or trust["blockingReasons"] != []
        ):
            fail("signing-selection trust root is not exact qualified v2")
        authorities = exact_keys(
            trust["authorities"],
            {"releaseEvidenceProducer", "independentReviewer"},
            "signing-continuity authorities",
        )
        producer = exact_keys(
            authorities["releaseEvidenceProducer"],
            {"role", "keyId", "publicKeyPemSha256", "enabled"},
            "signing producer authority",
        )
        reviewer = exact_keys(
            authorities["independentReviewer"],
            {"role", "keyId", "publicKeyPemSha256", "enabled"},
            "signing reviewer authority",
        )
        if producer["role"] != "release-evidence-producer" or producer["enabled"] is not True:
            fail("signing producer authority is not enabled")
        if reviewer["role"] != "independent-reviewer" or reviewer["enabled"] is not True:
            fail("signing reviewer authority is not enabled")
        validate_key_id(
            producer["keyId"], "signing producer key ID", "ios-signing-producer-"
        )
        validate_key_id(
            reviewer["keyId"], "signing reviewer key ID", "ios-signing-reviewer-"
        )
        require_sha256(
            producer["publicKeyPemSha256"], "signing producer key pin",
            expected_producer_key,
        )
        require_sha256(
            reviewer["publicKeyPemSha256"], "signing reviewer key pin",
            expected_reviewer_key,
        )
        if (
            producer["keyId"] == reviewer["keyId"]
            or expected_producer_key == expected_reviewer_key
        ):
            fail("signing producer and reviewer authorities must be distinct")
        producer_spki = validate_p256_key(
            producer_key, expected_producer_key, "signing producer key"
        )
        reviewer_spki = validate_p256_key(
            reviewer_key, expected_reviewer_key, "signing reviewer key"
        )
        if producer_spki == reviewer_spki:
            fail("signing producer and reviewer must use distinct P-256 points")
        verify_signature(
            receipt_path, producer_signature, producer_key, "signing producer receipt"
        )
        verify_signature(
            receipt_path, reviewer_signature, reviewer_key, "signing reviewer receipt"
        )

        replay = exact_keys(
            trust["replayPolicy"],
            {"maximumQualificationAgeSeconds", "maximumReviewDelaySeconds"},
            "signing replay policy",
        )
        if replay != {
            "maximumQualificationAgeSeconds": 2_592_000,
            "maximumReviewDelaySeconds": 86_400,
        }:
            fail("signing replay policy is not exact v2")
        if (
            receipt["schemaVersion"] != 2
            or receipt["contractId"]
            != "sora-ios-production-signing-identity-qualification-v2"
            or receipt["platform"] != "ios"
            or receipt["status"] != "qualified"
            or receipt["blockingReasons"] != []
            or receipt["privateKeyOrCredentialRecorded"] is not False
        ):
            fail("signing-selection receipt is not exact qualified v2")
        canonical_uuid(receipt["runId"], "signing receipt run ID", version=4)
        if receipt["runId"] != expected_run:
            fail("signing receipt run ID differs from the protected run")
        if require_positive_int(
            receipt["qualificationSequenceNumber"], "signing sequence"
        ) != expected_sequence:
            fail("signing receipt sequence differs from the protected sequence")
        require_revision(
            receipt["sourceRevision"], "signing receipt source revision", expected_source
        )
        require_sha256(
            receipt["qualificationContractSha256"],
            "signing receipt contract",
            expected_contract,
        )
        require_sha256(
            receipt["trustRootSha256"], "signing receipt trust root", trust_sha
        )
        if (
            receipt["releaseEvidenceProducerKeyId"] != producer["keyId"]
            or receipt["independentReviewerKeyId"] != reviewer["keyId"]
        ):
            fail("signing receipt does not bind both trusted roles")

        times = [
            require_positive_int(receipt[key], f"signing receipt {key}")
            for key in (
                "assessedAtEpochSeconds",
                "reviewedAtEpochSeconds",
                "qualifiedAtEpochSeconds",
            )
        ]
        now = int(time.time())
        if times != sorted(times) or times[2] > now + 300:
            fail("signing receipt chronology is invalid")
        if times[1] - times[0] > replay["maximumReviewDelaySeconds"]:
            fail("signing review exceeded its maximum delay")
        if now - times[2] > replay["maximumQualificationAgeSeconds"]:
            fail("signing-continuity qualification is stale")

        if (
            receipt["bundleIdentifier"] != "co.jp.soramitsu.sora"
            or receipt["developmentTeam"] != "YLWWUD25VZ"
            or receipt["applicationIdentifier"]
            != "YLWWUD25VZ.co.jp.soramitsu.sora"
            or receipt["codeSignStyle"] != "Manual"
            or receipt["configuredCodeSignIdentitySha1"]
            != EXPECTED_DISTRIBUTION_CERTIFICATE_SHA1
            or receipt["entitlementsPath"]
            != "SoraPassport/SoraPassport.entitlements"
        ):
            fail("signing receipt changed the durable application identity or selection")
        source_entitlements = ROOT / receipt["entitlementsPath"]
        _, source_raw = inputs.read(
            source_entitlements, MAX_JSON_BYTES, "source entitlements"
        )
        require_sha256(
            receipt["sourceEntitlementsSha256"],
            "source entitlements identity",
            sha256_bytes(source_raw),
        )
        for key, expected_value in (
            ("signedEntitlementsSha256", EXPECTED_SIGNED_ENTITLEMENTS_SHA256),
            ("keychainAccessGroupsSha256", EXPECTED_KEYCHAIN_ACCESS_GROUPS_SHA256),
            (
                "productionDistributionCertificateSha256",
                EXPECTED_DISTRIBUTION_CERTIFICATE_SHA256,
            ),
            ("rawProvisioningProfileSha256", EXPECTED_RAW_PROFILE_SHA256),
            (
                "canonicalProvisioningProfileSha256",
                EXPECTED_CANONICAL_PROFILE_SHA256,
            ),
        ):
            require_sha256(
                receipt[key],
                f"signing receipt {key}",
                expected_value,
            )
        if (
            type(receipt["productionDistributionCertificateSha1"]) is not str
            or SHA1_UPPER_RE.fullmatch(
                receipt["productionDistributionCertificateSha1"]
            ) is None
            or receipt["productionDistributionCertificateSha1"]
            != EXPECTED_DISTRIBUTION_CERTIFICATE_SHA1
        ):
            fail("signing receipt distribution-certificate SHA-1 drifted")
        profile_uuid = canonical_uuid(
            receipt["productionProvisioningProfileUuid"],
            "production provisioning-profile UUID",
        )
        if profile_uuid != EXPECTED_PROFILE_UUID:
            fail("production provisioning-profile UUID drifted")
        if (
            type(receipt["productionProvisioningProfileName"]) is not str
            or PROFILE_NAME_RE.fullmatch(
                receipt["productionProvisioningProfileName"]
            )
            is None
            or receipt["productionProvisioningProfileName"]
            != EXPECTED_PROFILE_NAME
        ):
            fail("production provisioning-profile name is not canonical")
        lineage = exact_keys(
            receipt["releaseLineage"],
            LINEAGE_KEYS,
            "signing receipt release lineage",
        )
        if lineage != EXPECTED_RELEASE_LINEAGE:
            fail("signing receipt does not bind the reviewed existing-app lineage")
        if (
            receipt["sourceEntitlementsSha256"]
            == receipt["signedEntitlementsSha256"]
        ):
            fail("source and signed entitlements identities are implausibly conflated")

        receipt_sha = sha256_bytes(receipt_raw)
        inputs.recheck_all()
        return receipt_sha


def lint_templates() -> None:
    with tempfile.TemporaryDirectory(prefix="sora-ios-signing-lint.") as temporary:
        root = Path(temporary)
        os.chmod(root, 0o700)
        inputs = StableInputs(root)
        validate_blocked_templates(inputs)
        contract_sha256(inputs)
        inputs.recheck_all()


def source_contract_sha256() -> str:
    with tempfile.TemporaryDirectory(prefix="sora-ios-signing-contract.") as temporary:
        root = Path(temporary)
        os.chmod(root, 0o700)
        inputs = StableInputs(root)
        validate_blocked_templates(inputs)
        digest = contract_sha256(inputs)
        inputs.recheck_all()
        return digest


def main() -> None:
    if sys.argv[1:] == ["--lint-templates"]:
        lint_templates()
        return
    if sys.argv[1:] == ["--verify-qualified"]:
        print(f"receiptSha256={verify_qualified()}")
        return
    if sys.argv[1:] == ["--print-contract-sha256"]:
        print(f"contractSha256={source_contract_sha256()}")
        return
    fail(
        "usage: verify-ios-production-signing-identity.py "
        "--lint-templates|--print-contract-sha256|--verify-qualified"
    )


if __name__ == "__main__":
    main()
