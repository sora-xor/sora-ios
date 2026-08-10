#!/usr/bin/env python3
"""Authenticate and rederive iOS vendored-XCFramework qualification evidence."""

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
from pathlib import Path, PurePosixPath
from typing import Any, Dict, List, Optional, Tuple


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "Fixtures" / "Modernization"
OPENSSL = Path("/usr/bin/openssl")
MAX_JSON_BYTES = 2 * 1024 * 1024
MAX_MANIFEST_BYTES = 4 * 1024 * 1024
MAX_CONTRACT_FILE_BYTES = 32 * 1024 * 1024
MAX_TREE_FILE_BYTES = 1024 * 1024 * 1024
MAX_KEY_BYTES = 16 * 1024
MAX_SIGNATURE_BYTES = 16 * 1024
MAX_TREE_FILES = 10_000
MAX_TREE_BYTES = 4 * 1024 * 1024 * 1024
MAX_SAFE_INTEGER = 9_007_199_254_740_991
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SHA1_RE = re.compile(r"^[0-9a-f]{40}$")
KEY_ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{2,127}$")
SAFE_OPENSSL_ENV = {
    "PATH": "/usr/bin:/bin",
    "LANG": "C",
    "LC_ALL": "C",
}

RECEIPT = FIXTURES / "ios-vendored-binary-qualification.json"
EVIDENCE = FIXTURES / "ios-vendored-binary-qualification-evidence.json"
TRUST = FIXTURES / "ios-vendored-binary-qualification-trust.json"
BLOCKED_RECEIPT = FIXTURES / "ios-vendored-binary-qualification.blocked.json"
BLOCKED_EVIDENCE = FIXTURES / "ios-vendored-binary-qualification-evidence.blocked.json"
BLOCKED_TRUST = FIXTURES / "ios-vendored-binary-qualification-trust.blocked.json"
LEGACY_READINESS = FIXTURES / "ios-vendored-binary-readiness.json"

ARTIFACTS: Tuple[Tuple[str, str], ...] = (
    (
        "shared-blake2lib",
        "VendorPackages/shared-features-spm/Binaries/blake2lib.xcframework",
    ),
    (
        "shared-libed25519",
        "VendorPackages/shared-features-spm/Binaries/libed25519.xcframework",
    ),
    (
        "shared-sr25519lib",
        "VendorPackages/shared-features-spm/Binaries/sr25519lib.xcframework",
    ),
    (
        "shared-sorawallet",
        "VendorPackages/shared-features-spm/Binaries/sorawallet.xcframework",
    ),
    (
        "shared-mpqr-core-sdk",
        "VendorPackages/shared-features-spm/Binaries/MPQRCoreSDK.xcframework",
    ),
    (
        "sora-wallet-binary-sorawallet",
        "VendorPackages/SoraWalletBinary/Binaries/sorawallet.xcframework",
    ),
)

CONTRACT_FILES: Tuple[str, ...] = (
    "Fixtures/Modernization/ios-vendored-binary-qualification-README.md",
    "Fixtures/Modernization/ios-vendored-binary-readiness.json",
    "Fixtures/Modernization/ios-vendored-binary-qualification.blocked.json",
    "Fixtures/Modernization/ios-vendored-binary-qualification-evidence.blocked.json",
    "Fixtures/Modernization/ios-vendored-binary-qualification-trust.blocked.json",
    "SoraPassport/Configs/ModernizationDependencies.conf",
    "SoraPassport.xcodeproj/project.pbxproj",
    "SoraPassport/Scripts/verify-modernization-dependencies.sh",
    "SoraPassport/Scripts/verify-ios-vendored-binary-qualification.sh",
    "SoraPassport/Scripts/verify-ios-vendored-binary-qualification.py",
    "SoraPassport/Scripts/test-ios-vendored-binary-qualification.py",
    "VendorPackages/shared-features-spm/Package.swift",
    "VendorPackages/SoraWalletBinary/Package.swift",
)

RECEIPT_KEYS = {
    "schemaVersion",
    "contractId",
    "platform",
    "status",
    "runId",
    "qualificationSequenceNumber",
    "sourceRevision",
    "reviewedAtEpochSeconds",
    "qualifiedAtEpochSeconds",
    "qualificationContractSha256",
    "trustRootSha256",
    "evidenceManifestSha256",
    "artifactEvidenceProducerKeyId",
    "independentReviewerKeyId",
    "artifactCount",
    "completeInventory",
    "wholeTreeContentQualified",
    "sourceOrVendorIdentityQualified",
    "licenseAndNoticeQualified",
    "sbomQualified",
    "buildProvenanceQualified",
    "artifactAttestationsQualified",
    "duplicateSorawalletByteIdentityProven",
    "blockingReasons",
}
EVIDENCE_KEYS = {
    "schemaVersion",
    "contractId",
    "platform",
    "status",
    "runId",
    "qualificationSequenceNumber",
    "sourceRevision",
    "runStartedAtEpochSeconds",
    "runFinishedAtEpochSeconds",
    "producedAtEpochSeconds",
    "qualificationContractSha256",
    "trustRootSha256",
    "artifactEvidenceProducerKeyId",
    "independentReviewerKeyId",
    "artifacts",
    "duplicateAssertions",
    "blockingReasons",
}
ARTIFACT_KEYS = {
    "id",
    "treePath",
    "contentManifestPath",
    "provenancePath",
    "reviewedFileCount",
    "contentManifestSha256",
    "provenanceSha256",
    "sourceOrVendorIdentityEvidenceSha256",
    "licenseAndNoticeEvidenceSha256",
    "sbomSha256",
    "buildProvenanceSha256",
    "artifactAttestationSha256",
    "treeContentSha256",
}
DUPLICATE_KEYS = {
    "leftId",
    "rightId",
    "byteIdentical",
    "contentManifestSha256",
    "treeContentSha256",
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
AUTHORITY_KEYS = {"role", "keyId", "publicKeyPemSha256", "enabled"}
REPLAY_KEYS = {
    "maximumQualificationAgeSeconds",
    "maximumRunDurationSeconds",
    "maximumReviewDelaySeconds",
}
PROVENANCE_KEYS = {
    "schemaVersion",
    "format",
    "platform",
    "artifactId",
    "treePath",
    "independentReviewStatus",
    "reviewedFileCount",
    "contentManifestSha256",
    "sourceOrVendorIdentityEvidenceSha256",
    "licenseAndNoticeEvidenceSha256",
    "sbomSha256",
    "buildProvenanceSha256",
    "artifactAttestationSha256",
}

RECEIPT_BLOCKER = (
    "No externally authenticated producer and independent-reviewer qualification has been "
    "supplied for the six production-reachable XCFramework trees."
)
EVIDENCE_BLOCKER = (
    "Template only: no independently authenticated whole-tree evidence, provenance evidence, "
    "or duplicate-tree proof has been supplied."
)
TRUST_BLOCKER = (
    "No independently protected artifact-evidence-producer or reviewer public-key pins have "
    "been supplied by the iOS release authority."
)


def fail(message: str) -> None:
    raise SystemExit(f"error: {message}")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_json(value: Any) -> bytes:
    return (
        json.dumps(value, ensure_ascii=True, separators=(",", ":"), sort_keys=True)
        + "\n"
    ).encode("utf-8")


def exact_keys(value: Any, expected: set[str], label: str) -> Dict[str, Any]:
    if type(value) is not dict or set(value) != expected:
        fail(f"{label} contains missing or unreviewed fields")
    return value


def exact_typed_equal(observed: Any, expected: Any) -> bool:
    if type(observed) is not type(expected):
        return False
    if type(expected) is dict:
        return set(observed) == set(expected) and all(
            exact_typed_equal(observed[key], expected[key]) for key in expected
        )
    if type(expected) is list:
        return len(observed) == len(expected) and all(
            exact_typed_equal(left, right)
            for left, right in zip(observed, expected)
        )
    return observed == expected


def require_sha256(value: Any, label: str, expected: Optional[str] = None) -> str:
    if type(value) is not str or SHA256_RE.fullmatch(value) is None or set(value) == {"0"}:
        fail(f"{label} must be a nonzero lowercase SHA-256")
    if expected is not None and value != expected:
        fail(f"{label} differs from its independently protected identity")
    return value


def require_source_revision(
    value: Any, label: str, expected: Optional[str] = None
) -> str:
    if type(value) is not str or SHA1_RE.fullmatch(value) is None or set(value) == {"0"}:
        fail(f"{label} must be a nonzero lowercase 40-hex source revision")
    if expected is not None and value != expected:
        fail(f"{label} differs from the protected release source revision")
    return value


def require_positive_int(value: Any, label: str) -> int:
    if type(value) is not int or value <= 0 or value > MAX_SAFE_INTEGER:
        fail(f"{label} must be a positive JSON-safe integer")
    return value


def require_uuid(value: Any, label: str, expected: Optional[str] = None) -> str:
    if type(value) is not str:
        fail(f"{label} must be a lowercase canonical UUID")
    try:
        canonical = str(uuid.UUID(value))
    except (AttributeError, ValueError):
        fail(f"{label} must be a lowercase canonical UUID")
    if canonical != value or value == "00000000-0000-0000-0000-000000000000":
        fail(f"{label} must be a nonzero lowercase canonical UUID")
    if expected is not None and value != expected:
        fail(f"{label} differs from the protected qualification run")
    return value


def required_env(name: str) -> str:
    value = os.environ.get(name, "")
    if not value:
        fail(f"required protected environment value is absent: {name}")
    return value


def required_absolute_path_env(name: str) -> Path:
    raw = required_env(name)
    path = Path(raw)
    if (
        not path.is_absolute()
        or str(path) != raw
        or raw == "/"
        or any(part in ("", ".", "..") for part in path.parts[1:])
    ):
        fail(f"protected qualification path must be absolute: {name}")
    try:
        parent = path.parent.resolve(strict=True)
    except OSError as error:
        fail(f"protected qualification path parent cannot be resolved: {name}: {error}")
    if parent != path.parent:
        fail(f"protected qualification path traverses an alias: {name}")
    try:
        path.relative_to(ROOT)
    except ValueError:
        return path
    fail(f"protected qualification path must remain outside the repository: {name}")


def duplicate_rejecting_object(pairs: List[Tuple[str, Any]]) -> Dict[str, Any]:
    result: Dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            fail(f"JSON contains a duplicate key: {key}")
        result[key] = value
    return result


def reject_json_constant(value: str) -> None:
    fail(f"JSON contains a non-finite value: {value}")


def reject_json_float(value: str) -> None:
    fail(f"JSON contains a floating-point number: {value}")


def parse_json_integer(value: str) -> int:
    if value == "-0":
        fail("JSON contains non-canonical negative zero")
    parsed = int(value, 10)
    if abs(parsed) > MAX_SAFE_INTEGER:
        fail("JSON integer exceeds the exact safe-integer bound")
    return parsed


def load_json_bytes(
    raw: bytes, label: str, *, canonical: bool = False
) -> Dict[str, Any]:
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as error:
        fail(f"{label} is not UTF-8 JSON: {error}")
    try:
        value = json.loads(
            text,
            object_pairs_hook=duplicate_rejecting_object,
            parse_int=parse_json_integer,
            parse_float=reject_json_float,
            parse_constant=reject_json_constant,
        )
    except json.JSONDecodeError as error:
        fail(f"{label} is malformed JSON: {error}")
    if type(value) is not dict:
        fail(f"{label} root must be an object")
    if canonical and canonical_json(value) != raw:
        fail(f"{label} must use canonical JSON")
    return value


def _repository_descriptor(path: Path, maximum: int, label: str) -> Tuple[int, os.stat_result]:
    if not path.is_absolute():
        fail(f"{label} is not repository-absolute")
    try:
        relative = path.relative_to(ROOT)
    except ValueError:
        fail(f"{label} escapes the canonical repository root")
    if not relative.parts or any(part in ("", ".", "..") for part in relative.parts):
        fail(f"{label} has an unsafe repository-relative path")
    if not hasattr(os, "O_NOFOLLOW") or not hasattr(os, "O_DIRECTORY"):
        fail("this platform cannot enforce repository path-component safety")
    directory_flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY
    file_flags = os.O_RDONLY | os.O_NOFOLLOW
    if hasattr(os, "O_CLOEXEC"):
        directory_flags |= os.O_CLOEXEC
        file_flags |= os.O_CLOEXEC
    directory_descriptor: Optional[int] = None
    try:
        directory_descriptor = os.open("/", directory_flags)
        for component in ROOT.parts[1:] + relative.parts[:-1]:
            next_descriptor = os.open(
                component, directory_flags, dir_fd=directory_descriptor
            )
            os.close(directory_descriptor)
            directory_descriptor = next_descriptor
        descriptor = os.open(
            relative.parts[-1], file_flags, dir_fd=directory_descriptor
        )
    except OSError as error:
        fail(f"{label} could not be opened through a non-symbolic repository path: {error}")
    finally:
        if directory_descriptor is not None:
            os.close(directory_descriptor)
    opened = os.fstat(descriptor)
    if not stat.S_ISREG(opened.st_mode) or opened.st_size <= 0 or opened.st_size > maximum:
        os.close(descriptor)
        fail(f"{label} must be a nonempty bounded regular repository file")
    return descriptor, opened


def _external_descriptor(path: Path, maximum: int, label: str) -> Tuple[int, os.stat_result]:
    try:
        before = path.lstat()
    except OSError as error:
        fail(f"{label} is absent or inaccessible: {error}")
    if (
        stat.S_ISLNK(before.st_mode)
        or not stat.S_ISREG(before.st_mode)
        or before.st_nlink != 1
        or before.st_uid != os.getuid()
        or stat.S_IMODE(before.st_mode) != 0o600
    ):
        fail(f"{label} must be one owner-only, unlinked regular file")
    if before.st_size <= 0 or before.st_size > maximum:
        fail(f"{label} has an invalid byte size")
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    if hasattr(os, "O_CLOEXEC"):
        flags |= os.O_CLOEXEC
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


def _read_descriptor(
    descriptor: int, opened: os.stat_result, maximum: int, label: str
) -> bytes:
    chunks: List[bytes] = []
    total = 0
    with os.fdopen(descriptor, "rb", closefd=True) as source:
        while True:
            chunk = source.read(1024 * 1024)
            if not chunk:
                break
            total += len(chunk)
            if total > maximum:
                fail(f"{label} exceeded its byte bound while reading")
            chunks.append(chunk)
        after = os.fstat(source.fileno())
    if total != opened.st_size:
        fail(f"{label} changed length while reading")
    identity = lambda value: (
        value.st_dev,
        value.st_ino,
        value.st_mode,
        value.st_nlink,
        value.st_uid,
        value.st_size,
        value.st_mtime_ns,
    )
    if identity(opened) != identity(after):
        fail(f"{label} changed while reading")
    return b"".join(chunks)


class StableInputs:
    def __init__(self, directory: Path) -> None:
        self.directory = directory
        self.records: List[
            Tuple[Path, int, str, bool, Tuple[int, int, int, int], str]
        ] = []
        self.counter = 0

    def snapshot(
        self,
        path: Path,
        maximum: int,
        label: str,
        repository_owned: bool,
    ) -> Tuple[Path, bytes]:
        opener = _repository_descriptor if repository_owned else _external_descriptor
        descriptor, opened = opener(path, maximum, label)
        raw = _read_descriptor(descriptor, opened, maximum, label)
        identity = (opened.st_dev, opened.st_ino, opened.st_size, opened.st_mtime_ns)
        digest = sha256_bytes(raw)
        self.counter += 1
        destination = self.directory / f"input-{self.counter:04d}"
        with destination.open("xb") as target:
            target.write(raw)
        self.records.append((path, maximum, label, repository_owned, identity, digest))
        self._recheck_record(self.records[-1])
        return destination, raw

    def json(
        self,
        path: Path,
        label: str,
        repository_owned: bool = True,
        *,
        canonical: bool = False,
    ) -> Tuple[Path, bytes, Dict[str, Any]]:
        snapshot, raw = self.snapshot(path, MAX_JSON_BYTES, label, repository_owned)
        return snapshot, raw, load_json_bytes(raw, label, canonical=canonical)

    def _recheck_record(
        self,
        record: Tuple[Path, int, str, bool, Tuple[int, int, int, int], str],
    ) -> None:
        path, maximum, label, repository_owned, identity, digest = record
        opener = _repository_descriptor if repository_owned else _external_descriptor
        descriptor, opened = opener(path, maximum, label)
        raw = _read_descriptor(descriptor, opened, maximum, label)
        current = (opened.st_dev, opened.st_ino, opened.st_size, opened.st_mtime_ns)
        if current != identity or sha256_bytes(raw) != digest:
            fail(f"{label} changed during qualification admission")

    def recheck_all(self) -> None:
        for record in self.records:
            self._recheck_record(record)


def expected_manifest_path(artifact_id: str) -> str:
    return f"Fixtures/Modernization/VendoredBinaries/{artifact_id}.sha256"


def expected_provenance_path(artifact_id: str) -> str:
    return f"Fixtures/Modernization/VendoredBinaries/{artifact_id}.provenance.json"


def validate_fixed_artifact_paths(artifacts: Any, label: str) -> List[Dict[str, Any]]:
    if type(artifacts) is not list or len(artifacts) != len(ARTIFACTS):
        fail(f"{label} must contain exactly six artifacts")
    checked: List[Dict[str, Any]] = []
    for index, (artifact_id, tree_path) in enumerate(ARTIFACTS):
        artifact = exact_keys(artifacts[index], ARTIFACT_KEYS, f"{label}[{index}]")
        if (
            artifact["id"] != artifact_id
            or artifact["treePath"] != tree_path
            or artifact["contentManifestPath"] != expected_manifest_path(artifact_id)
            or artifact["provenancePath"] != expected_provenance_path(artifact_id)
        ):
            fail(f"{label}[{index}] identity or fixed path drifted")
        checked.append(artifact)
    return checked


def validate_wire_shapes(
    receipt: Dict[str, Any], evidence: Dict[str, Any], trust: Dict[str, Any]
) -> None:
    exact_keys(receipt, RECEIPT_KEYS, "vendored-binary qualification receipt")
    exact_keys(evidence, EVIDENCE_KEYS, "vendored-binary evidence manifest")
    exact_keys(trust, TRUST_KEYS, "vendored-binary trust root")
    validate_fixed_artifact_paths(evidence["artifacts"], "vendored-binary artifacts")
    duplicates = evidence["duplicateAssertions"]
    if type(duplicates) is not list or len(duplicates) != 1:
        fail("vendored-binary evidence must contain one duplicate assertion")
    exact_keys(duplicates[0], DUPLICATE_KEYS, "vendored-binary duplicate assertion")
    authorities = exact_keys(
        trust["authorities"],
        {"artifactEvidenceProducer", "independentReviewer"},
        "vendored-binary trust authorities",
    )
    exact_keys(
        authorities["artifactEvidenceProducer"],
        AUTHORITY_KEYS,
        "vendored-binary producer authority",
    )
    exact_keys(
        authorities["independentReviewer"],
        AUTHORITY_KEYS,
        "vendored-binary reviewer authority",
    )
    exact_keys(trust["replayPolicy"], REPLAY_KEYS, "vendored-binary replay policy")


def _blocked_artifact_expected(artifact_id: str, tree_path: str) -> Dict[str, Any]:
    return {
        "id": artifact_id,
        "treePath": tree_path,
        "contentManifestPath": expected_manifest_path(artifact_id),
        "provenancePath": expected_provenance_path(artifact_id),
        "reviewedFileCount": None,
        "contentManifestSha256": None,
        "provenanceSha256": None,
        "sourceOrVendorIdentityEvidenceSha256": None,
        "licenseAndNoticeEvidenceSha256": None,
        "sbomSha256": None,
        "buildProvenanceSha256": None,
        "artifactAttestationSha256": None,
        "treeContentSha256": None,
    }


def validate_blocked_templates(inputs: StableInputs) -> None:
    _, _, receipt = inputs.json(BLOCKED_RECEIPT, "blocked vendored-binary receipt")
    _, _, evidence = inputs.json(BLOCKED_EVIDENCE, "blocked vendored-binary evidence")
    _, _, trust = inputs.json(BLOCKED_TRUST, "blocked vendored-binary trust root")
    _, _, readiness = inputs.json(LEGACY_READINESS, "blocked vendored-binary inventory")
    validate_wire_shapes(receipt, evidence, trust)

    expected_receipt = {
        "schemaVersion": 1,
        "contractId": "sora-ios-vendored-binary-qualification-v1",
        "platform": "ios",
        "status": "blocked",
        "runId": None,
        "qualificationSequenceNumber": 0,
        "sourceRevision": None,
        "reviewedAtEpochSeconds": 0,
        "qualifiedAtEpochSeconds": 0,
        "qualificationContractSha256": None,
        "trustRootSha256": None,
        "evidenceManifestSha256": None,
        "artifactEvidenceProducerKeyId": None,
        "independentReviewerKeyId": None,
        "artifactCount": 6,
        "completeInventory": False,
        "wholeTreeContentQualified": False,
        "sourceOrVendorIdentityQualified": False,
        "licenseAndNoticeQualified": False,
        "sbomQualified": False,
        "buildProvenanceQualified": False,
        "artifactAttestationsQualified": False,
        "duplicateSorawalletByteIdentityProven": False,
        "blockingReasons": [RECEIPT_BLOCKER],
    }
    if not exact_typed_equal(receipt, expected_receipt):
        fail("blocked vendored-binary receipt carries fabricated qualification material")

    expected_evidence = {
        "schemaVersion": 1,
        "contractId": "sora-ios-vendored-binary-evidence-v1",
        "platform": "ios",
        "status": "blocked",
        "runId": None,
        "qualificationSequenceNumber": 0,
        "sourceRevision": None,
        "runStartedAtEpochSeconds": 0,
        "runFinishedAtEpochSeconds": 0,
        "producedAtEpochSeconds": 0,
        "qualificationContractSha256": None,
        "trustRootSha256": None,
        "artifactEvidenceProducerKeyId": None,
        "independentReviewerKeyId": None,
        "artifacts": [
            _blocked_artifact_expected(artifact_id, tree_path)
            for artifact_id, tree_path in ARTIFACTS
        ],
        "duplicateAssertions": [
            {
                "leftId": "shared-sorawallet",
                "rightId": "sora-wallet-binary-sorawallet",
                "byteIdentical": False,
                "contentManifestSha256": None,
                "treeContentSha256": None,
            }
        ],
        "blockingReasons": [EVIDENCE_BLOCKER],
    }
    if not exact_typed_equal(evidence, expected_evidence):
        fail("blocked vendored-binary evidence carries fabricated qualification material")

    expected_trust = {
        "schemaVersion": 1,
        "contractId": "sora-ios-vendored-binary-qualification-trust-v1",
        "platform": "ios",
        "status": "blocked",
        "signatureAlgorithm": "ecdsa-p256-sha256",
        "authorities": {
            "artifactEvidenceProducer": {
                "role": "artifact-evidence-producer",
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
            "maximumQualificationAgeSeconds": 2592000,
            "maximumRunDurationSeconds": 172800,
            "maximumReviewDelaySeconds": 86400,
        },
        "blockingReasons": [TRUST_BLOCKER],
    }
    if not exact_typed_equal(trust, expected_trust):
        fail("blocked vendored-binary trust root carries fabricated authority material")

    validate_blocked_legacy_readiness(readiness)


def validate_blocked_legacy_readiness(readiness: Dict[str, Any]) -> None:
    exact_keys(
        readiness,
        {
            "schemaVersion",
            "platform",
            "assessedAt",
            "status",
            "releaseEnabled",
            "productionReachable",
            "completeInventory",
            "artifacts",
            "duplicateAssertions",
            "releaseCriteria",
            "blocker",
            "exitCriteria",
        },
        "legacy vendored-binary readiness",
    )
    if (
        type(readiness["schemaVersion"]) is not int
        or readiness["schemaVersion"] != 1
        or readiness["platform"] != "ios"
        or readiness["assessedAt"] != "2026-08-02"
        or readiness["status"] != "blocked"
        or readiness["releaseEnabled"] is not False
        or readiness["productionReachable"] is not True
        or readiness["completeInventory"] is not True
    ):
        fail("legacy vendored-binary readiness must remain a blocked inventory")
    artifacts = readiness["artifacts"]
    if type(artifacts) is not list or len(artifacts) != len(ARTIFACTS):
        fail("legacy vendored-binary readiness inventory is incomplete")
    legacy_keys = {
        "id",
        "treePath",
        "status",
        "reviewedFileCount",
        "contentManifestPath",
        "contentManifestSha256",
        "provenancePath",
        "provenanceSha256",
        "sourceOrVendorIdentityProven",
        "licenseAndNoticeReviewed",
        "sbomReviewed",
        "buildProvenanceReviewed",
        "artifactAttestationReviewed",
    }
    for index, (artifact_id, tree_path) in enumerate(ARTIFACTS):
        artifact = exact_keys(artifacts[index], legacy_keys, f"legacy artifact {index}")
        if (
            artifact["id"] != artifact_id
            or artifact["treePath"] != tree_path
            or artifact["contentManifestPath"] != expected_manifest_path(artifact_id)
            or artifact["provenancePath"] != expected_provenance_path(artifact_id)
            or artifact["status"] != "blocked"
            or artifact["reviewedFileCount"] is not None
            or artifact["contentManifestSha256"] is not None
            or artifact["provenanceSha256"] is not None
            or any(
                artifact[key] is not False
                for key in (
                    "sourceOrVendorIdentityProven",
                    "licenseAndNoticeReviewed",
                    "sbomReviewed",
                    "buildProvenanceReviewed",
                    "artifactAttestationReviewed",
                )
            )
        ):
            fail(f"legacy artifact {artifact_id} carries fabricated review state")
    duplicates = readiness["duplicateAssertions"]
    if not exact_typed_equal(
        duplicates,
        [
            {
                "leftId": "shared-sorawallet",
                "rightId": "sora-wallet-binary-sorawallet",
                "byteIdentical": False,
            }
        ],
    ):
        fail("legacy duplicate assertion must remain blocked")
    criteria = readiness["releaseCriteria"]
    expected_criteria = {
        "completeContentManifestsReviewed",
        "sourceOrVendorProvenanceReviewed",
        "licensesAndNoticesReviewed",
        "sbomsReviewed",
        "buildProvenanceReviewed",
        "artifactAttestationsReviewed",
        "duplicateSorawalletByteIdentityProven",
    }
    exact_keys(criteria, expected_criteria, "legacy vendored-binary release criteria")
    if any(criteria[key] is not False for key in expected_criteria):
        fail("legacy vendored-binary release criteria must remain blocked")
    blocker = exact_keys(
        readiness["blocker"], {"code", "reason"}, "legacy vendored-binary blocker"
    )
    if blocker != {
        "code": "production_vendored_xcframeworks_unverified",
        "reason": (
            "Six production-reachable XCFramework trees have no independently reviewed "
            "whole-tree content manifests or provenance receipts. The two sorawallet copies "
            "have not been proven byte-identical."
        ),
    }:
        fail("legacy vendored-binary blocker text drifted")
    if readiness["exitCriteria"] != [
        "inventory every regular file and reject symlinks, special nodes, missing files, and unlisted files",
        "independently review and pin source or vendor identity, licenses, SBOMs, build provenance, and attestations",
        "publish exact SHA-256 manifests and hashed provenance receipts for all six trees",
        "prove the two production sorawallet XCFramework trees are byte-identical or remove one copy",
    ]:
        fail("legacy vendored-binary exit criteria drifted")


def validate_key_id(value: Any, label: str, prefix: str) -> str:
    suffix = value[len(prefix) :] if type(value) is str and value.startswith(prefix) else ""
    if (
        type(value) is not str
        or KEY_ID_RE.fullmatch(value) is None
        or not value.startswith(prefix)
        or re.fullmatch(r"[a-z][a-z0-9._-]{2,31}", suffix) is None
        or SHA1_RE.fullmatch(suffix) is not None
        or SHA256_RE.fullmatch(suffix) is not None
    ):
        fail(f"{label} is not a canonical role key ID")
    return value


def validate_p256_key(path: Path, expected_sha: str, label: str) -> bytes:
    if not OPENSSL.is_file():
        fail("/usr/bin/openssl is required for vendored-binary qualification")
    if sha256_bytes(path.read_bytes()) != expected_sha:
        fail(f"{label} differs from its protected SHA-256")
    # macOS LibreSSL does not implement `openssl ec -check`. Parsing the public
    # key, pinning its exact bytes, requiring P-256 below, and deriving a
    # canonical uncompressed SPKI validates the protected public-key input
    # without relying on an OpenSSL-only option.
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
            str(OPENSSL),
            "ec",
            "-pubin",
            "-in",
            str(path),
            "-pubout",
            "-conv_form",
            "uncompressed",
            "-param_enc",
            "named_curve",
            "-outform",
            "DER",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
        env=SAFE_OPENSSL_ENV,
    )
    if canonical.returncode != 0 or not canonical.stdout:
        fail(f"{label} could not be canonicalized as SPKI DER")
    if sha256_bytes(path.read_bytes()) != expected_sha:
        fail(f"{label} changed during key validation")
    return canonical.stdout


def verify_signature(
    payload: Path,
    signature: Path,
    key: Path,
    expected_key_sha: str,
    label: str,
) -> None:
    before_payload = sha256_bytes(payload.read_bytes())
    before_signature = sha256_bytes(signature.read_bytes())
    before_key = sha256_bytes(key.read_bytes())
    if before_key != expected_key_sha:
        fail(f"{label} verification key differs from its protected SHA-256")
    verified = subprocess.run(
        [
            str(OPENSSL),
            "dgst",
            "-sha256",
            "-verify",
            str(key),
            "-signature",
            str(signature),
            str(payload),
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
        env=SAFE_OPENSSL_ENV,
    )
    if verified.returncode != 0:
        fail(f"{label} detached P-256 signature is invalid")
    if (
        sha256_bytes(payload.read_bytes()) != before_payload
        or sha256_bytes(signature.read_bytes()) != before_signature
        or sha256_bytes(key.read_bytes()) != before_key
    ):
        fail(f"{label} changed during signature verification")


def _open_repository_directory(relative: str, label: str) -> int:
    pure = PurePosixPath(relative)
    if pure.is_absolute() or not pure.parts or any(part in ("", ".", "..") for part in pure.parts):
        fail(f"{label} has an unsafe repository-relative path")
    flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY
    if hasattr(os, "O_CLOEXEC"):
        flags |= os.O_CLOEXEC
    descriptor: Optional[int] = None
    try:
        descriptor = os.open("/", flags)
        for component in ROOT.parts[1:] + pure.parts:
            next_descriptor = os.open(component, flags, dir_fd=descriptor)
            os.close(descriptor)
            descriptor = next_descriptor
    except OSError as error:
        if descriptor is not None:
            os.close(descriptor)
        fail(f"{label} could not be opened through a non-symbolic path: {error}")
    return descriptor


TreeEntry = Tuple[str, Tuple[int, int, int, int]]
TreeState = Dict[str, TreeEntry]


def inventory_tree(relative: str, label: str) -> TreeState:
    if not hasattr(os, "O_NOFOLLOW") or not hasattr(os, "O_DIRECTORY"):
        fail("this platform cannot enforce XCFramework tree path safety")
    root_descriptor = _open_repository_directory(relative, label)
    state: TreeState = {}
    total_bytes = 0

    def visit(directory_descriptor: int, prefix: str) -> None:
        nonlocal total_bytes
        try:
            names = sorted(os.listdir(directory_descriptor))
        except OSError as error:
            fail(f"{label} could not be enumerated safely: {error}")
        for name in names:
            if not name or name in (".", "..") or "/" in name or "\x00" in name:
                fail(f"{label} contains an unsafe path component")
            path = f"{prefix}/{name}" if prefix else name
            try:
                node = os.stat(name, dir_fd=directory_descriptor, follow_symlinks=False)
            except OSError as error:
                fail(f"{label} node changed during enumeration: {path}: {error}")
            if stat.S_ISDIR(node.st_mode):
                flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY
                if hasattr(os, "O_CLOEXEC"):
                    flags |= os.O_CLOEXEC
                try:
                    child = os.open(name, flags, dir_fd=directory_descriptor)
                except OSError as error:
                    fail(f"{label} directory could not be opened safely: {path}: {error}")
                try:
                    visit(child, path)
                finally:
                    os.close(child)
            elif stat.S_ISREG(node.st_mode):
                if len(state) >= MAX_TREE_FILES:
                    fail(f"{label} exceeds the file-count bound")
                if node.st_size > MAX_TREE_FILE_BYTES:
                    fail(f"{label} contains an oversized file: {path}")
                flags = os.O_RDONLY | os.O_NOFOLLOW
                if hasattr(os, "O_CLOEXEC"):
                    flags |= os.O_CLOEXEC
                try:
                    descriptor = os.open(name, flags, dir_fd=directory_descriptor)
                except OSError as error:
                    fail(f"{label} file could not be opened safely: {path}: {error}")
                opened = os.fstat(descriptor)
                if not stat.S_ISREG(opened.st_mode) or (opened.st_dev, opened.st_ino) != (
                    node.st_dev,
                    node.st_ino,
                ):
                    os.close(descriptor)
                    fail(f"{label} file changed during open: {path}")
                raw = _read_descriptor(descriptor, opened, MAX_TREE_FILE_BYTES, f"{label}/{path}")
                total_bytes += len(raw)
                if total_bytes > MAX_TREE_BYTES:
                    fail(f"{label} exceeds the aggregate byte bound")
                state[path] = (
                    sha256_bytes(raw),
                    (opened.st_dev, opened.st_ino, opened.st_size, opened.st_mtime_ns),
                )
            else:
                fail(f"{label} contains a symlink or special node: {path}")

    try:
        visit(root_descriptor, "")
    finally:
        os.close(root_descriptor)
    if not state:
        fail(f"{label} contains no regular files")
    return state


def parse_manifest(raw: bytes, label: str) -> Dict[str, str]:
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as error:
        fail(f"{label} is not UTF-8: {error}")
    if not text.endswith("\n") or "\r" in text or "\x00" in text:
        fail(f"{label} must be canonical newline-delimited text")
    entries: Dict[str, str] = {}
    for line in text.splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        if match is None:
            fail(f"{label} contains a malformed digest line")
        digest, path = match.groups()
        pure = PurePosixPath(path)
        if (
            pure.is_absolute()
            or not pure.parts
            or any(part in ("", ".", "..") for part in pure.parts)
            or "\\" in path
            or "//" in path
            or path in entries
        ):
            fail(f"{label} contains an unsafe or duplicate path")
        entries[path] = digest
    if not entries:
        fail(f"{label} is empty")
    return entries


def tree_content_sha256(entries: Dict[str, str]) -> str:
    digest = hashlib.sha256()
    for path in sorted(entries):
        digest.update(path.encode("utf-8"))
        digest.update(b"\0")
        digest.update(bytes.fromhex(entries[path]))
        digest.update(b"\0")
    return digest.hexdigest()


def contract_sha256(inputs: StableInputs) -> str:
    digest = hashlib.sha256()
    for relative in CONTRACT_FILES:
        _, raw = inputs.snapshot(
            ROOT / relative,
            MAX_CONTRACT_FILE_BYTES,
            f"vendored-binary qualification contract input {relative}",
            True,
        )
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update(bytes.fromhex(sha256_bytes(raw)))
        digest.update(b"\0")
    return digest.hexdigest()


def validate_provenance(
    provenance: Dict[str, Any], artifact: Dict[str, Any], label: str
) -> None:
    exact_keys(provenance, PROVENANCE_KEYS, label)
    if (
        type(provenance["schemaVersion"]) is not int
        or provenance["schemaVersion"] != 2
        or provenance["format"] != "sora-ios-vendored-binary-provenance-v2"
        or provenance["platform"] != "ios"
        or provenance["artifactId"] != artifact["id"]
        or provenance["treePath"] != artifact["treePath"]
        or provenance["independentReviewStatus"] != "qualified"
        or type(provenance["reviewedFileCount"]) is not int
        or provenance["reviewedFileCount"] != artifact["reviewedFileCount"]
        or provenance["contentManifestSha256"] != artifact["contentManifestSha256"]
    ):
        fail(f"{label} identity or reviewed artifact binding is invalid")
    for key in (
        "sourceOrVendorIdentityEvidenceSha256",
        "licenseAndNoticeEvidenceSha256",
        "sbomSha256",
        "buildProvenanceSha256",
        "artifactAttestationSha256",
    ):
        require_sha256(provenance[key], f"{label}.{key}", artifact[key])


def verify_qualified() -> str:
    expected_source = require_source_revision(
        required_env("IOS_VENDORED_BINARY_QUALIFICATION_SOURCE_REVISION"),
        "protected vendored-binary source revision",
    )
    expected_run = require_uuid(
        required_env("IOS_VENDORED_BINARY_QUALIFICATION_RUN_ID"),
        "protected vendored-binary run ID",
    )
    sequence_text = required_env(
        "IOS_VENDORED_BINARY_QUALIFICATION_SEQUENCE_NUMBER"
    )
    if re.fullmatch(r"[1-9][0-9]{0,15}", sequence_text) is None:
        fail("protected vendored-binary sequence is not canonical")
    expected_sequence = int(sequence_text, 10)
    if expected_sequence > MAX_SAFE_INTEGER:
        fail("protected vendored-binary sequence exceeds the exact safe-integer bound")
    expected_contract = require_sha256(
        required_env("IOS_VENDORED_BINARY_QUALIFICATION_CONTRACT_SHA256"),
        "protected vendored-binary qualification contract",
    )
    expected_trust = require_sha256(
        required_env("IOS_VENDORED_BINARY_QUALIFICATION_TRUST_SHA256"),
        "protected vendored-binary trust root",
    )
    expected_producer_key = require_sha256(
        required_env(
            "IOS_VENDORED_BINARY_QUALIFICATION_ARTIFACT_PRODUCER_PUBLIC_KEY_SHA256"
        ),
        "protected vendored-binary producer key",
    )
    expected_reviewer_key = require_sha256(
        required_env("IOS_VENDORED_BINARY_QUALIFICATION_REVIEWER_PUBLIC_KEY_SHA256"),
        "protected vendored-binary reviewer key",
    )

    with tempfile.TemporaryDirectory(prefix="sora-ios-vendored-binary.") as temporary:
        inputs = StableInputs(Path(temporary))
        validate_blocked_templates(inputs)
        receipt_path, receipt_raw, receipt = inputs.json(
            RECEIPT, "vendored-binary qualification receipt", canonical=True
        )
        evidence_path, evidence_raw, evidence = inputs.json(
            EVIDENCE, "vendored-binary evidence manifest", canonical=True
        )
        trust_path, trust_raw, trust = inputs.json(
            TRUST, "vendored-binary trust root", canonical=True
        )
        validate_wire_shapes(receipt, evidence, trust)

        receipt_signature, _ = inputs.snapshot(
            required_absolute_path_env(
                "IOS_VENDORED_BINARY_QUALIFICATION_RECEIPT_SIGNATURE_PATH"
            ),
            MAX_SIGNATURE_BYTES,
            "vendored-binary receipt signature",
            False,
        )
        producer_signature, _ = inputs.snapshot(
            required_absolute_path_env(
                "IOS_VENDORED_BINARY_QUALIFICATION_EVIDENCE_PRODUCER_SIGNATURE_PATH"
            ),
            MAX_SIGNATURE_BYTES,
            "vendored-binary producer evidence signature",
            False,
        )
        reviewer_signature, _ = inputs.snapshot(
            required_absolute_path_env(
                "IOS_VENDORED_BINARY_QUALIFICATION_EVIDENCE_REVIEWER_SIGNATURE_PATH"
            ),
            MAX_SIGNATURE_BYTES,
            "vendored-binary reviewer evidence signature",
            False,
        )
        producer_key, _ = inputs.snapshot(
            required_absolute_path_env(
                "IOS_VENDORED_BINARY_QUALIFICATION_ARTIFACT_PRODUCER_PUBLIC_KEY_PATH"
            ),
            MAX_KEY_BYTES,
            "vendored-binary producer public key",
            False,
        )
        reviewer_key, _ = inputs.snapshot(
            required_absolute_path_env(
                "IOS_VENDORED_BINARY_QUALIFICATION_REVIEWER_PUBLIC_KEY_PATH"
            ),
            MAX_KEY_BYTES,
            "vendored-binary reviewer public key",
            False,
        )

        trust_sha = require_sha256(
            sha256_bytes(trust_raw), "vendored-binary trust root SHA-256", expected_trust
        )
        if (
            type(trust["schemaVersion"]) is not int
            or trust["schemaVersion"] != 1
            or trust["contractId"]
            != "sora-ios-vendored-binary-qualification-trust-v1"
            or trust["platform"] != "ios"
            or trust["status"] != "qualified"
            or trust["signatureAlgorithm"] != "ecdsa-p256-sha256"
            or trust["blockingReasons"] != []
        ):
            fail("vendored-binary trust root is not exact qualified v1")
        producer = trust["authorities"]["artifactEvidenceProducer"]
        reviewer = trust["authorities"]["independentReviewer"]
        for authority, role, prefix, label in (
            (
                producer,
                "artifact-evidence-producer",
                "ios-vendored-artifact-producer-",
                "producer",
            ),
            (
                reviewer,
                "independent-reviewer",
                "ios-vendored-independent-reviewer-",
                "reviewer",
            ),
        ):
            if authority["role"] != role or authority["enabled"] is not True:
                fail(f"vendored-binary {label} authority is not qualified")
            validate_key_id(authority["keyId"], f"vendored-binary {label} key ID", prefix)
        if (
            producer["keyId"] == reviewer["keyId"]
            or producer["publicKeyPemSha256"] == reviewer["publicKeyPemSha256"]
        ):
            fail("vendored-binary producer and reviewer authorities must be distinct")
        require_sha256(
            producer["publicKeyPemSha256"], "producer key pin", expected_producer_key
        )
        require_sha256(
            reviewer["publicKeyPemSha256"], "reviewer key pin", expected_reviewer_key
        )
        producer_spki = validate_p256_key(
            producer_key, expected_producer_key, "vendored-binary producer key"
        )
        reviewer_spki = validate_p256_key(
            reviewer_key, expected_reviewer_key, "vendored-binary reviewer key"
        )
        if producer_spki == reviewer_spki:
            fail("vendored-binary producer and reviewer must use distinct P-256 keys")
        verify_signature(
            receipt_path,
            receipt_signature,
            reviewer_key,
            expected_reviewer_key,
            "vendored-binary qualification receipt",
        )
        verify_signature(
            evidence_path,
            producer_signature,
            producer_key,
            expected_producer_key,
            "vendored-binary producer evidence",
        )
        verify_signature(
            evidence_path,
            reviewer_signature,
            reviewer_key,
            expected_reviewer_key,
            "vendored-binary independent review",
        )

        computed_contract = contract_sha256(inputs)
        require_sha256(
            computed_contract,
            "current vendored-binary qualification contract",
            expected_contract,
        )
        evidence_sha = sha256_bytes(evidence_raw)
        receipt_sha = sha256_bytes(receipt_raw)
        if (
            type(receipt["schemaVersion"]) is not int
            or receipt["schemaVersion"] != 1
            or receipt["contractId"] != "sora-ios-vendored-binary-qualification-v1"
            or receipt["platform"] != "ios"
            or receipt["status"] != "qualified"
            or receipt["blockingReasons"] != []
            or type(receipt["artifactCount"]) is not int
            or receipt["artifactCount"] != 6
        ):
            fail("vendored-binary qualification receipt is not exact qualified v1")
        if (
            type(evidence["schemaVersion"]) is not int
            or evidence["schemaVersion"] != 1
            or evidence["contractId"] != "sora-ios-vendored-binary-evidence-v1"
            or evidence["platform"] != "ios"
            or evidence["status"] != "qualified"
            or evidence["blockingReasons"] != []
        ):
            fail("vendored-binary evidence manifest is not exact qualified v1")
        for key in (
            "completeInventory",
            "wholeTreeContentQualified",
            "sourceOrVendorIdentityQualified",
            "licenseAndNoticeQualified",
            "sbomQualified",
            "buildProvenanceQualified",
            "artifactAttestationsQualified",
            "duplicateSorawalletByteIdentityProven",
        ):
            if receipt[key] is not True:
                fail(f"vendored-binary signed receipt assertion is not qualified: {key}")
        require_uuid(receipt["runId"], "receipt run ID", expected_run)
        require_uuid(evidence["runId"], "evidence run ID", expected_run)
        if (
            type(receipt["qualificationSequenceNumber"]) is not int
            or type(evidence["qualificationSequenceNumber"]) is not int
            or receipt["qualificationSequenceNumber"] != expected_sequence
            or evidence["qualificationSequenceNumber"] != expected_sequence
        ):
            fail("vendored-binary sequence differs from the protected sequence")
        require_source_revision(receipt["sourceRevision"], "receipt source revision", expected_source)
        require_source_revision(evidence["sourceRevision"], "evidence source revision", expected_source)
        require_sha256(
            receipt["qualificationContractSha256"],
            "receipt qualification contract",
            computed_contract,
        )
        require_sha256(
            evidence["qualificationContractSha256"],
            "evidence qualification contract",
            computed_contract,
        )
        require_sha256(receipt["trustRootSha256"], "receipt trust root", trust_sha)
        require_sha256(evidence["trustRootSha256"], "evidence trust root", trust_sha)
        require_sha256(
            receipt["evidenceManifestSha256"], "receipt evidence manifest", evidence_sha
        )
        if (
            receipt["artifactEvidenceProducerKeyId"] != producer["keyId"]
            or evidence["artifactEvidenceProducerKeyId"] != producer["keyId"]
            or receipt["independentReviewerKeyId"] != reviewer["keyId"]
            or evidence["independentReviewerKeyId"] != reviewer["keyId"]
        ):
            fail("vendored-binary receipt/evidence authority binding is invalid")

        replay = trust["replayPolicy"]
        expected_replay = {
            "maximumQualificationAgeSeconds": 2592000,
            "maximumRunDurationSeconds": 172800,
            "maximumReviewDelaySeconds": 86400,
        }
        if not exact_typed_equal(replay, expected_replay):
            fail("vendored-binary replay policy differs from the reviewed v1 contract")
        started = require_positive_int(
            evidence["runStartedAtEpochSeconds"], "vendored-binary run start"
        )
        finished = require_positive_int(
            evidence["runFinishedAtEpochSeconds"], "vendored-binary run finish"
        )
        produced = require_positive_int(
            evidence["producedAtEpochSeconds"], "vendored-binary evidence time"
        )
        reviewed = require_positive_int(
            receipt["reviewedAtEpochSeconds"], "vendored-binary review time"
        )
        qualified = require_positive_int(
            receipt["qualifiedAtEpochSeconds"], "vendored-binary qualification time"
        )
        now = int(time.time())
        if not (started <= finished <= produced <= reviewed <= qualified <= now):
            fail("vendored-binary qualification chronology is invalid")
        if (
            finished - started > replay["maximumRunDurationSeconds"]
            or reviewed - produced > replay["maximumReviewDelaySeconds"]
            or qualified - reviewed > replay["maximumReviewDelaySeconds"]
            or now - qualified > replay["maximumQualificationAgeSeconds"]
        ):
            fail("vendored-binary qualification violates the reviewed replay policy")

        tree_states: Dict[str, TreeState] = {}
        manifest_bytes: Dict[str, bytes] = {}
        artifacts = validate_fixed_artifact_paths(
            evidence["artifacts"], "qualified vendored-binary artifacts"
        )
        for artifact in artifacts:
            artifact_id = artifact["id"]
            count = require_positive_int(
                artifact["reviewedFileCount"], f"{artifact_id} reviewed file count"
            )
            for key in (
                "contentManifestSha256",
                "provenanceSha256",
                "sourceOrVendorIdentityEvidenceSha256",
                "licenseAndNoticeEvidenceSha256",
                "sbomSha256",
                "buildProvenanceSha256",
                "artifactAttestationSha256",
                "treeContentSha256",
            ):
                require_sha256(artifact[key], f"{artifact_id}.{key}")
            _, manifest_raw = inputs.snapshot(
                ROOT / artifact["contentManifestPath"],
                MAX_MANIFEST_BYTES,
                f"{artifact_id} content manifest",
                True,
            )
            _, provenance_raw, provenance = inputs.json(
                ROOT / artifact["provenancePath"],
                f"{artifact_id} provenance receipt",
                canonical=True,
            )
            require_sha256(
                sha256_bytes(manifest_raw),
                f"{artifact_id} content manifest SHA-256",
                artifact["contentManifestSha256"],
            )
            require_sha256(
                sha256_bytes(provenance_raw),
                f"{artifact_id} provenance receipt SHA-256",
                artifact["provenanceSha256"],
            )
            validate_provenance(provenance, artifact, f"{artifact_id} provenance")
            manifest = parse_manifest(manifest_raw, f"{artifact_id} content manifest")
            if len(manifest) != count:
                fail(f"{artifact_id} manifest count differs from reviewed evidence")
            state = inventory_tree(artifact["treePath"], artifact_id)
            observed = {path: entry[0] for path, entry in state.items()}
            if observed != manifest:
                fail(f"{artifact_id} tree differs from its complete content manifest")
            require_sha256(
                tree_content_sha256(manifest),
                f"{artifact_id} deterministic tree content",
                artifact["treeContentSha256"],
            )
            tree_states[artifact_id] = state
            manifest_bytes[artifact_id] = manifest_raw

        duplicate = evidence["duplicateAssertions"][0]
        if (
            duplicate["leftId"] != "shared-sorawallet"
            or duplicate["rightId"] != "sora-wallet-binary-sorawallet"
            or duplicate["byteIdentical"] is not True
        ):
            fail("vendored-binary duplicate assertion is not exact qualified v1")
        left = artifacts[3]
        right = artifacts[5]
        if (
            left["contentManifestSha256"] != right["contentManifestSha256"]
            or left["treeContentSha256"] != right["treeContentSha256"]
            or duplicate["contentManifestSha256"] != left["contentManifestSha256"]
            or duplicate["treeContentSha256"] != left["treeContentSha256"]
            or manifest_bytes[left["id"]] != manifest_bytes[right["id"]]
            or {
                path: entry[0] for path, entry in tree_states[left["id"]].items()
            }
            != {
                path: entry[0] for path, entry in tree_states[right["id"]].items()
            }
        ):
            fail("the two production sorawallet XCFramework trees are not byte-identical")

        for artifact in artifacts:
            current = inventory_tree(artifact["treePath"], artifact["id"])
            if current != tree_states[artifact["id"]]:
                fail(f"{artifact['id']} tree changed during qualification admission")
        inputs.recheck_all()
        return receipt_sha


def lint_templates() -> None:
    with tempfile.TemporaryDirectory(prefix="sora-ios-vendored-binary-lint.") as temporary:
        inputs = StableInputs(Path(temporary))
        validate_blocked_templates(inputs)
        inputs.recheck_all()


def source_contract_sha256() -> str:
    with tempfile.TemporaryDirectory(prefix="sora-ios-vendored-binary-contract.") as temporary:
        inputs = StableInputs(Path(temporary))
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
    fail("usage: verify-ios-vendored-binary-qualification.py --lint-templates|--print-contract-sha256|--verify-qualified")


if __name__ == "__main__":
    main()
