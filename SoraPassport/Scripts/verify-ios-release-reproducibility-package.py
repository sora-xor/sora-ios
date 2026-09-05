#!/usr/bin/env python3
"""Fail-closed iOS Release reproduction and qualified-IPA package sealing.

The production export is always the candidate.  A second export may prove the
same bytes, but when Apple signing introduces legitimate container variance we
record that fact and admit only an exact canonical app/signing identity match.
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import plistlib
import re
import stat
import subprocess
import sys
import tempfile
import uuid
import zipfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[2]
PROJECTOR_PATH = ROOT / "SoraPassport/Scripts/derive-ios-migration-test-host.py"
CONTROLLER_PATH = ROOT / "SoraPassport/Scripts/run-ios-migration-exact-ipa-evidence.py"
SIGNING_BLOCKED = ROOT / "Fixtures/Modernization/ios-production-signing-identity.json"
SIGNING_VERIFIER = (
    ROOT / "SoraPassport/Scripts/verify-ios-production-signing-identity.py"
)
SIGNING_TESTS = ROOT / "SoraPassport/Scripts/test-ios-production-signing-identity.py"
VENDORED_BLOCKED = (
    ROOT / "Fixtures/Modernization/ios-vendored-binary-qualification.blocked.json"
)
VENDORED_RECEIPT = (
    ROOT / "Fixtures/Modernization/ios-vendored-binary-qualification.json"
)
VENDORED_VERIFIER = (
    ROOT / "SoraPassport/Scripts/verify-ios-vendored-binary-qualification.py"
)
VENDORED_TESTS = (
    ROOT / "SoraPassport/Scripts/test-ios-vendored-binary-qualification.py"
)
DEPENDENCY_PATHS = (
    "VendorPackages/shared-features-spm/Package.swift",
    "VendorPackages/Rswift/Package.swift",
    "VendorPackages/GoogleSignIn-iOS/Package.swift",
    "VendorPackages/google-api-objectivec-client-for-rest/Package.swift",
    "Vendor/IrohaSwift/REVIEWED_CONTENTS.sha256",
    "Vendor/NoritoBridge.xcframework/REVIEWED_CONTENTS.sha256",
)
BUILD_FORMAT = "sora-ios-release-build-manifest-v4"
EQUIVALENCE_FORMAT = "sora-ios-release-reproducibility-equivalence-v4"
PACKAGE_FORMAT = "sora-ios-qualified-ipa-package-v4"
PACKAGE_MEMBERS = (
    "candidate.ipa",
    "equivalence-receipt.json",
    "qualification-receipt.json",
    "qualification-receipt.sig",
    "signing-identity-receipt.json",
    "vendored-binary-qualification-receipt.json",
    "primary-build-manifest.json",
    "reproduction-build-manifest.json",
    "primary-archive-content-manifest.json",
    "primary-export-content-manifest.json",
    "reproduction-archive-content-manifest.json",
    "reproduction-export-content-manifest.json",
    "primary-archive.log",
    "primary-export.log",
    "reproduction-archive.log",
    "reproduction-export.log",
    *(f"dependencies/{index + 1:02d}-{Path(path).name}" for index, path in enumerate(DEPENDENCY_PATHS)),
    "package-manifest.json",
)
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SHA1_UPPER_RE = re.compile(r"^[0-9A-F]{40}$")
REVISION_RE = re.compile(r"^[0-9a-f]{40}$")
BUILD_NUMBER_RE = re.compile(r"^[1-9][0-9]{0,17}$")
SAFE_RELATIVE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._/-]{0,511}$")
MAX_IPA_BYTES = 4 * 1024 * 1024 * 1024
MAX_JSON_BYTES = 8 * 1024 * 1024
MAX_LOG_BYTES = 256 * 1024 * 1024
MAX_SIGNATURE_BYTES = 64 * 1024
MAX_PACKAGE_MEMBERS = 64
MAX_SAFE_INTEGER = 9_007_199_254_740_991
SAFE_ENV = {"PATH": "/usr/bin:/bin", "LANG": "C", "LC_ALL": "C"}
TAIRA_CHAIN_IDS = {
    "809574f5-fee7-5e69-bfcf-52451e42d50f",
    "fc56984b-2be7-431d-840e-21514d1883f0",
}
TAIRA_CONVENIENCE_HOST = "taira.sora.org"
EXPECTED_SIGNING_CERTIFICATE_SHA1 = "84AB95335BE14CAE9B050A353910F86FF2F9539B"
EXPECTED_SIGNING_CERTIFICATE_SHA256 = (
    "d830d54bce8e583089f2ed8cf927fc12b60c9d591e560ffe6f5d2a71c91317fb"
)
EXPECTED_SIGNING_PROFILE_UUID = "7ae520bc-599b-48ae-abfa-627eef530f0c"
EXPECTED_SIGNING_PROFILE_NAME = (
    "iOS Team Store Provisioning Profile: co.jp.soramitsu.sora"
)
EXPECTED_SIGNING_PROFILE_RAW_SHA256 = (
    "19073a93bc09fe061e2346470b57aae1961aa38ad4c6b4922e0140bf8061bf93"
)
EXPECTED_SIGNING_PROFILE_CANONICAL_SHA256 = (
    "f6d534c50ba641341337a6ce9b34f55db7931491c43554ededffb8a47d88b931"
)
EXPECTED_SIGNED_ENTITLEMENTS_SHA256 = (
    "6ce476d496fb75e4510b9dfce490dc6c29d78b96d9114c85a44b09d9d2756b2d"
)
EXPECTED_KEYCHAIN_ACCESS_GROUPS_SHA256 = (
    "6382618e08a2e9678e9c4b1f2dec83836c3aeb2aea1508df83dde886979efdc0"
)
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
SIGNING_RECEIPT_KEYS = {
    "schemaVersion", "contractId", "platform", "status", "runId",
    "qualificationSequenceNumber", "sourceRevision", "assessedAtEpochSeconds",
    "reviewedAtEpochSeconds", "qualifiedAtEpochSeconds",
    "qualificationContractSha256", "trustRootSha256",
    "releaseEvidenceProducerKeyId", "independentReviewerKeyId",
    "bundleIdentifier", "developmentTeam", "applicationIdentifier",
    "codeSignStyle", "configuredCodeSignIdentitySha1", "entitlementsPath",
    "sourceEntitlementsSha256", "signedEntitlementsSha256",
    "keychainAccessGroupsSha256", "productionDistributionCertificateSha256",
    "productionDistributionCertificateSha1", "productionProvisioningProfileUuid",
    "productionProvisioningProfileName", "rawProvisioningProfileSha256",
    "canonicalProvisioningProfileSha256", "releaseLineage",
    "privateKeyOrCredentialRecorded", "blockingReasons",
}
SIGNING_LINEAGE_KEYS = set(EXPECTED_RELEASE_LINEAGE)
VENDORED_RECEIPT_KEYS = {
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


class ReleaseReproducibilityError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise ReleaseReproducibilityError(message)


def canonical_json(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        + b"\n"
    )


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def require_exact_keys(value: Any, expected: set[str], label: str) -> dict[str, Any]:
    if type(value) is not dict or set(value) != expected:
        fail(f"{label} has a stale, mixed, or incomplete shape")
    return value


def require_sha256(value: Any, label: str, *, allow_zero: bool = False) -> str:
    if type(value) is not str or SHA256_RE.fullmatch(value) is None:
        fail(f"{label} is not a lowercase SHA-256")
    if not allow_zero and value == "0" * 64:
        fail(f"{label} must not be the zero digest")
    return value


def require_revision(value: Any, label: str) -> str:
    if type(value) is not str or REVISION_RE.fullmatch(value) is None or value == "0" * 40:
        fail(f"{label} is not an exact nonzero source revision")
    return value


def require_build_number(value: Any, label: str) -> str:
    if type(value) is not str or BUILD_NUMBER_RE.fullmatch(value) is None:
        fail(f"{label} is not one positive canonical decimal build number")
    return value


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


def parse_taira_deployment_projection(info: Any, label: str) -> dict[str, Any]:
    if type(info) is not dict:
        fail(f"{label} Info.plist is not a dictionary")
    names = {
        "contractId": "SoraTairaDeploymentAdmissionContractId",
        "manifestSha256": "SoraTairaDeploymentManifestSha256",
        "manifestSequenceNumber": "SoraTairaDeploymentManifestSequenceNumber",
        "admissionSha256": "SoraTairaDeploymentAdmissionSha256",
        "currentChainId": "SoraTairaCurrentChainId",
        "retiredChainId": "SoraTairaRetiredChainId",
        "currentGenesisHash": "SoraTairaCurrentGenesisHash",
        "retiredGenesisHash": "SoraTairaRetiredGenesisHash",
        "currentDeploymentEpoch": "SoraTairaCurrentDeploymentEpoch",
        "retiredDeploymentEpoch": "SoraTairaRetiredDeploymentEpoch",
        "canonicalToriiBaseUrl": "SoraTairaCanonicalToriiBaseUrl",
        "publicMcpEndpoint": "SoraTairaPublicMcpEndpoint",
        "explorerBaseUrl": "SoraTairaExplorerBaseUrl",
        "pendingRowPolicy": "SoraTairaPendingRowPolicy",
    }
    projection = {key: info.get(source) for key, source in names.items()}
    if any(type(value) is not str or not value or len(value) > 2048 for value in projection.values()):
        fail(f"{label} lacks the exact embedded Taira deployment admission projection")
    if projection["contractId"] != "sora-ios-taira-deployment-admission-v2":
        fail(f"{label} has an obsolete Taira admission contract")
    require_sha256(projection["manifestSha256"], f"{label} Taira manifest")
    if (
        re.fullmatch(r"[1-9][0-9]{0,15}", projection["manifestSequenceNumber"])
        is None
        or int(projection["manifestSequenceNumber"]) > MAX_SAFE_INTEGER
    ):
        fail(f"{label} Taira manifest sequence is not one positive exact integer")
    require_sha256(projection["admissionSha256"], f"{label} Taira admission")
    if projection["manifestSha256"] == projection["admissionSha256"]:
        fail(f"{label} conflates Taira manifest and admission identities")
    if {
        projection["currentChainId"], projection["retiredChainId"]
    } != TAIRA_CHAIN_IDS:
        fail(f"{label} does not preserve both known Taira UUIDs in distinct roles")
    require_sha256(projection["currentGenesisHash"], f"{label} current Taira genesis")
    require_sha256(projection["retiredGenesisHash"], f"{label} retired Taira genesis")
    if projection["currentGenesisHash"] == projection["retiredGenesisHash"]:
        fail(f"{label} Taira genesis identities are not distinct")
    epochs: list[int] = []
    for key in ("currentDeploymentEpoch", "retiredDeploymentEpoch"):
        raw = projection[key]
        if (
            re.fullmatch(r"[1-9][0-9]{0,15}", raw) is None
            or int(raw) > MAX_SAFE_INTEGER
        ):
            fail(f"{label} {key} is not one positive canonical epoch")
        epochs.append(int(raw))
    if epochs[0] <= epochs[1]:
        fail(f"{label} current Taira deployment epoch is not newer than retired")
    from urllib.parse import urlsplit
    base = urlsplit(projection["canonicalToriiBaseUrl"])
    explorer = urlsplit(projection["explorerBaseUrl"])
    if (
        base.scheme != "https"
        or base.hostname is None
        or base.hostname != base.hostname.lower()
        or base.hostname == TAIRA_CONVENIENCE_HOST
        or "." not in base.hostname
        or base.username is not None
        or base.password is not None
        or base.port not in (None, 443)
        or base.path
        or base.query
        or base.fragment
        or projection["publicMcpEndpoint"]
        != f"{projection['canonicalToriiBaseUrl']}/v1/mcp"
        or explorer.scheme != "https"
        or explorer.hostname is None
        or explorer.hostname != explorer.hostname.lower()
        or explorer.hostname == TAIRA_CONVENIENCE_HOST
        or "." not in explorer.hostname
        or explorer.username is not None
        or explorer.password is not None
        or explorer.port not in (None, 443)
        or explorer.path
        or explorer.query
        or explorer.fragment
    ):
        fail(f"{label} does not bind one explicit canonical public HTTPS /v1/mcp route")
    if projection["pendingRowPolicy"] != (
        "schema-77:preserve-exact-uuid:quarantine-recovery-only:no-reinterpretation"
    ):
        fail(f"{label} permits schema-77 pending-row reinterpretation")
    return projection


def archive_taira_deployment_projection(archive: Path, label: str) -> dict[str, Any]:
    applications = sorted((archive / "Products/Applications").glob("*.app"))
    if len(applications) != 1 or applications[0].is_symlink():
        fail(f"{label} archive does not contain exactly one non-symbolic application")
    info_path = applications[0] / "Info.plist"
    raw, _ = open_regular(info_path, MAX_JSON_BYTES, f"{label} archived Info.plist")
    try:
        info = plistlib.loads(raw)
    except plistlib.InvalidFileException as error:
        fail(f"{label} archived Info.plist is invalid: {error}")
    return parse_taira_deployment_projection(info, label)


def archive_build_number(archive: Path, label: str) -> str:
    applications = sorted((archive / "Products/Applications").glob("*.app"))
    if len(applications) != 1 or applications[0].is_symlink():
        fail(f"{label} archive does not contain exactly one non-symbolic application")
    info_path = applications[0] / "Info.plist"
    raw, _ = open_regular(info_path, MAX_JSON_BYTES, f"{label} archived Info.plist")
    try:
        info = plistlib.loads(raw)
    except plistlib.InvalidFileException as error:
        fail(f"{label} archived Info.plist is invalid: {error}")
    if type(info) is not dict:
        fail(f"{label} archived Info.plist is not a dictionary")
    return require_build_number(info.get("CFBundleVersion"), f"{label} build number")


def absolute_path(raw: str, label: str) -> Path:
    path = Path(raw)
    if not path.is_absolute() or str(path) != raw or raw == "/" or len(raw) > 4096:
        fail(f"{label} must be one canonical absolute path")
    if any(part in ("", ".", "..") for part in path.parts[1:]):
        fail(f"{label} contains an unsafe component")
    try:
        resolved_parent = path.parent.resolve(strict=True)
    except (OSError, RuntimeError) as error:
        fail(f"{label} parent cannot be resolved without aliases: {error}")
    if resolved_parent != path.parent:
        fail(f"{label} traverses a symbolic or noncanonical parent")
    return path


def open_regular(path: Path, maximum: int, label: str, *, owner_only: bool = False) -> tuple[bytes, os.stat_result]:
    if not hasattr(os, "O_NOFOLLOW"):
        fail("this platform cannot reject symbolic links")
    flags = os.O_RDONLY | os.O_NOFOLLOW
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
            or (owner_only and (before.st_uid != os.getuid() or stat.S_IMODE(before.st_mode) != 0o600))
        ):
            fail(f"{label} is not one bounded owner-only regular inode")
        chunks: list[bytes] = []
        consumed = 0
        while True:
            chunk = os.read(descriptor, min(1024 * 1024, maximum + 1 - consumed))
            if not chunk:
                break
            consumed += len(chunk)
            if consumed > maximum:
                fail(f"{label} exceeds its byte bound")
            chunks.append(chunk)
        after = os.fstat(descriptor)
        named = os.stat(path, follow_symlinks=False)
        identity = lambda item: (item.st_dev, item.st_ino, item.st_mode, item.st_nlink, item.st_size, item.st_mtime_ns)
        if consumed != before.st_size or identity(before) != identity(after) or identity(before) != identity(named):
            fail(f"{label} changed while read")
        return b"".join(chunks), before
    finally:
        os.close(descriptor)


def digest_regular(
    path: Path,
    maximum: int,
    label: str,
    *,
    owner_only: bool = False,
    allow_empty: bool = False,
) -> tuple[dict[str, Any], os.stat_result]:
    if not hasattr(os, "O_NOFOLLOW"):
        fail("this platform cannot reject symbolic links")
    flags = os.O_RDONLY | os.O_NOFOLLOW
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
            or (before.st_size <= 0 and not allow_empty)
            or before.st_size > maximum
            or (owner_only and (before.st_uid != os.getuid() or stat.S_IMODE(before.st_mode) != 0o600))
        ):
            fail(f"{label} is not one bounded owner-only regular inode")
        digest = hashlib.sha256()
        consumed = 0
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                break
            consumed += len(chunk)
            if consumed > maximum:
                fail(f"{label} exceeds its byte bound")
            digest.update(chunk)
        after = os.fstat(descriptor)
        named = os.stat(path, follow_symlinks=False)
        identity = lambda item: (item.st_dev, item.st_ino, item.st_mode, item.st_nlink, item.st_size, item.st_mtime_ns)
        if consumed != before.st_size or identity(before) != identity(after) or identity(before) != identity(named):
            fail(f"{label} changed while hashed")
        return {"sha256": digest.hexdigest(), "byteCount": consumed}, before
    finally:
        os.close(descriptor)


def parse_canonical_json(raw: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(
            raw.decode("utf-8"),
            object_pairs_hook=duplicate_rejecting_object,
            parse_int=parse_json_integer,
            parse_float=reject_json_float,
            parse_constant=reject_json_constant,
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fail(f"{label} is not valid UTF-8 JSON: {error}")
    if type(value) is not dict or canonical_json(value) != raw:
        fail(f"{label} is not canonical JSON")
    return value


def file_identity(path: Path, label: str, *, directory: bool) -> dict[str, Any]:
    try:
        metadata = os.stat(path, follow_symlinks=False)
    except OSError as error:
        fail(f"{label} is absent: {error}")
    expected = stat.S_ISDIR(metadata.st_mode) if directory else stat.S_ISREG(metadata.st_mode)
    if not expected or stat.S_ISLNK(metadata.st_mode) or (not directory and metadata.st_nlink != 1):
        fail(f"{label} is not one non-symbolic {'directory' if directory else 'file'}")
    return {
        "path": str(path),
        "device": metadata.st_dev,
        "inode": metadata.st_ino,
    }


def content_manifest(root: Path, label: str) -> dict[str, Any]:
    root_identity = file_identity(root, label, directory=True)
    entries: list[dict[str, Any]] = []
    normalized: set[str] = set()
    for current, directory_names, file_names in os.walk(root, topdown=True, followlinks=False):
        current_path = Path(current)
        directory_names.sort()
        file_names.sort()
        for name in list(directory_names):
            path = current_path / name
            relative = path.relative_to(root).as_posix()
            metadata = os.lstat(path)
            if stat.S_ISLNK(metadata.st_mode):
                target = os.readlink(path)
                resolved = (path.parent / target).resolve(strict=False)
                try:
                    resolved.relative_to(root.resolve())
                except ValueError:
                    fail(f"{label} contains an escaping directory symlink")
                entries.append({"path": relative, "type": "symlink", "target": target})
                directory_names.remove(name)
            elif stat.S_ISDIR(metadata.st_mode):
                entries.append({"path": relative, "type": "directory", "mode": stat.S_IMODE(metadata.st_mode)})
            else:
                fail(f"{label} contains an unknown directory node")
        for name in file_names:
            path = current_path / name
            relative = path.relative_to(root).as_posix()
            folded = relative.casefold()
            if folded in normalized:
                fail(f"{label} contains a case-folding path collision")
            normalized.add(folded)
            metadata = os.lstat(path)
            if stat.S_ISLNK(metadata.st_mode):
                target = os.readlink(path)
                resolved = (path.parent / target).resolve(strict=False)
                try:
                    resolved.relative_to(root.resolve())
                except ValueError:
                    fail(f"{label} contains an escaping file symlink")
                entries.append({"path": relative, "type": "symlink", "target": target})
            elif stat.S_ISREG(metadata.st_mode):
                identity, stable = digest_regular(
                    path,
                    MAX_IPA_BYTES,
                    f"{label}:{relative}",
                    allow_empty=True,
                )
                entries.append(
                    {
                        "path": relative,
                        "type": "file",
                        "mode": stat.S_IMODE(stable.st_mode),
                        **identity,
                    }
                )
            else:
                fail(f"{label} contains an unknown filesystem node")
    entries.sort(key=lambda item: item["path"])
    record_raw = canonical_json(entries)
    return {
        "format": "sora-ios-release-directory-content-manifest-v1",
        "rootIdentity": root_identity,
        "entryCount": len(entries),
        "recordSha256": sha256_bytes(record_raw),
        "entries": entries,
    }


def load_module(path: Path, name: str) -> Any:
    specification = importlib.util.spec_from_file_location(name, path)
    if specification is None or specification.loader is None:
        fail(f"cannot load reviewed source: {path}")
    module = importlib.util.module_from_spec(specification)
    sys.modules[name] = module
    specification.loader.exec_module(module)
    return module


def plist_projection(value: Any) -> Any:
    if value is None or type(value) in (bool, int, str):
        return value
    if isinstance(value, bytes):
        return {"dataSha256": sha256_bytes(value), "byteCount": len(value)}
    if isinstance(value, datetime):
        # plistlib decodes the CreationDate and ExpirationDate fields in real
        # mobileprovision payloads as naive UTC datetimes. Keep their type and
        # instant explicit in the canonical JSON projection; aware datetimes
        # are normalized to the same UTC representation.
        normalized = (
            value.replace(tzinfo=timezone.utc)
            if value.tzinfo is None
            else value.astimezone(timezone.utc)
        )
        return {
            "dateUtc": normalized.isoformat(timespec="microseconds").replace(
                "+00:00", "Z"
            )
        }
    if isinstance(value, list):
        return [plist_projection(item) for item in value]
    if isinstance(value, dict) and all(type(key) is str for key in value):
        return {key: plist_projection(value[key]) for key in sorted(value)}
    fail("provisioning profile contains an unsupported plist value")


def run_tool(command: list[str], label: str, maximum: int = MAX_JSON_BYTES) -> tuple[bytes, bytes]:
    result = subprocess.run(
        command,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=SAFE_ENV,
        timeout=120,
    )
    if result.returncode != 0 or len(result.stdout) > maximum or len(result.stderr) > maximum:
        fail(f"{label} failed or exceeded its byte bound")
    return result.stdout, result.stderr


def code_directory_identity(app_path: Path, macho_paths: tuple[tuple[str, Any], ...]) -> list[dict[str, Any]]:
    relative_paths = sorted(relative for relative, _ in macho_paths)
    if not relative_paths or len(relative_paths) != len(set(relative_paths)):
        fail("canonical application has an empty or duplicate Mach-O inventory")
    records: list[dict[str, Any]] = []
    for relative in relative_paths:
        pure = PurePosixPath(relative)
        if pure.is_absolute() or any(part in ("", ".", "..") for part in pure.parts):
            fail("canonical application has an unsafe Mach-O path")
        code = app_path.joinpath(*pure.parts)
        metadata = os.stat(code, follow_symlinks=False)
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
            fail("canonical application Mach-O is not one regular inode")
        _, diagnostic = run_tool(
            ["/usr/bin/codesign", "-d", "--verbose=5", str(code)],
            f"CodeDirectory display for {relative}",
        )
        text = diagnostic.decode("utf-8", "strict")
        candidates = sorted(
            set(re.findall(r"^CandidateCDHashFull sha256=([0-9a-f]{64})$", text, re.MULTILINE))
        )
        if not candidates:
            fail(f"signed Mach-O lacks a full SHA-256 CodeDirectory identity: {relative}")
        records.append(
            {
                "codePath": relative,
                "candidateCodeDirectorySha256": candidates,
            }
        )
    return records


def application_signing_certificate_sha256(
    app_path: Path,
    temporary_path: Path,
) -> str:
    prefix = temporary_path / "application-signing-certificate-"
    run_tool(
        [
            "/usr/bin/codesign",
            "-d",
            f"--extract-certificates={prefix}",
            str(app_path),
        ],
        "application signing-certificate extraction",
    )
    certificates = sorted(temporary_path.glob(f"{prefix.name}*"))
    if (
        not certificates
        or len(certificates) > 8
        or [item.name for item in certificates]
        != [f"{prefix.name}{index}" for index in range(len(certificates))]
    ):
        fail("application signing-certificate chain inventory is not exact")
    leaf_raw, _ = open_regular(
        certificates[0],
        MAX_JSON_BYTES,
        "application leaf signing certificate",
    )
    return sha256_bytes(leaf_raw)


def inspect_release_ipa(path: Path) -> dict[str, Any]:
    projector = load_module(PROJECTOR_PATH, "sora_release_projector")
    controller = load_module(CONTROLLER_PATH, "sora_release_controller")
    inspection, ipa_sha, ipa_size = projector.inspect_ipa(path)
    with tempfile.TemporaryDirectory(prefix="sora-ios-release-inspection.") as temporary:
        temporary_path = Path(temporary)
        os.chmod(temporary_path, 0o700)
        extracted = controller.inspect_and_extract_ipa(str(path), temporary_path / "extracted")
        if extracted["ipaSha256"] != ipa_sha or extracted["ipaByteCount"] != ipa_size:
            fail("independent IPA inspectors disagree on the raw candidate")
        app_path = Path(extracted["appPath"])
        profile_path = app_path / "embedded.mobileprovision"
        profile_raw, _ = open_regular(profile_path, MAX_JSON_BYTES, "embedded provisioning profile")
        profile_plist_raw, _ = run_tool(
            ["/usr/bin/security", "cms", "-D", "-i", str(profile_path)],
            "embedded provisioning profile decode",
        )
        try:
            profile = plistlib.loads(profile_plist_raw)
        except plistlib.InvalidFileException as error:
            fail(f"embedded provisioning profile is invalid: {error}")
        if type(profile) is not dict:
            fail("embedded provisioning profile is not a dictionary")
        certificates = profile.get("DeveloperCertificates")
        if type(certificates) is not list or not certificates or any(type(item) is not bytes for item in certificates):
            fail("embedded provisioning profile lacks exact developer certificates")
        certificate_sha = sorted(sha256_bytes(item) for item in certificates)
        application_certificate_sha = application_signing_certificate_sha256(
            app_path,
            temporary_path,
        )
        if application_certificate_sha not in certificate_sha:
            fail("application signer certificate is absent from the embedded profile")
        signed_identity = {
            "applicationIdentifier": extracted["applicationIdentifier"],
            "teamIdentifier": extracted["teamIdentifier"],
            "signedEntitlementsSha256": extracted["signedEntitlementsSha256"],
            "keychainAccessGroupsSha256": extracted["keychainAccessGroupsSha256"],
            "embeddedProvisioningProfileSha256": sha256_bytes(profile_raw),
            "canonicalProvisioningProfileSha256": sha256_bytes(canonical_json(plist_projection(profile))),
            "provisioningProfileUuid": profile.get("UUID"),
            "provisioningProfileName": profile.get("Name"),
            "applicationSigningCertificateSha256": application_certificate_sha,
            "developerCertificateSha256": certificate_sha,
            "codeDirectories": code_directory_identity(app_path, inspection.entitlements_by_path),
        }
        info_raw, _ = open_regular(
            app_path / "Info.plist",
            MAX_JSON_BYTES,
            "candidate application Info.plist",
        )
        try:
            application_info = plistlib.loads(info_raw)
        except plistlib.InvalidFileException as error:
            fail(f"candidate application Info.plist is invalid: {error}")
        taira_deployment = parse_taira_deployment_projection(
            application_info,
            "candidate application",
        )
        if (
            type(signed_identity["provisioningProfileUuid"]) is not str
            or type(signed_identity["provisioningProfileName"]) is not str
        ):
            fail("embedded provisioning profile lacks its UUID or name")
    return {
        "ipaSha256": ipa_sha,
        "ipaByteCount": ipa_size,
        "sourceRevision": extracted["sourceRevision"],
        "qualificationContractSha256": extracted["qualificationContractSha256"],
        "bundleIdentifier": extracted["bundleIdentifier"],
        "canonicalProjection": inspection.projection,
        "canonicalExecutableSha256": inspection.executable_canonical_sha256,
        "canonicalExecutableByteCount": inspection.executable_byte_count,
        "canonicalInfo": inspection.info,
        "entitlementProjection": list(inspection.entitlement_projection),
        "signedIdentity": signed_identity,
        "tairaDeployment": taira_deployment,
    }


def checked_digest(path: Path, maximum: int, label: str) -> dict[str, Any]:
    identity, _ = digest_regular(path, maximum, label)
    return identity


def git_output(repository: Path, arguments: list[str], label: str) -> str:
    stdout, _ = run_tool(["/usr/bin/git", "-C", str(repository), *arguments], label)
    try:
        return stdout.decode("utf-8", "strict")
    except UnicodeDecodeError:
        fail(f"{label} is not UTF-8")


def parse_signing_identity_receipt(raw: bytes, label: str) -> dict[str, Any]:
    value = parse_canonical_json(raw, label)
    require_exact_keys(value, SIGNING_RECEIPT_KEYS, label)
    if (
        value["schemaVersion"] != 2
        or value["contractId"]
        != "sora-ios-production-signing-identity-qualification-v2"
        or value["platform"] != "ios"
        or value["status"] != "qualified"
        or value["bundleIdentifier"] != "co.jp.soramitsu.sora"
        or value["developmentTeam"] != "YLWWUD25VZ"
        or value["applicationIdentifier"] != "YLWWUD25VZ.co.jp.soramitsu.sora"
        or value["codeSignStyle"] != "Manual"
        or value["configuredCodeSignIdentitySha1"]
        != EXPECTED_SIGNING_CERTIFICATE_SHA1
        or value["entitlementsPath"] != "SoraPassport/SoraPassport.entitlements"
        or value["sourceEntitlementsSha256"]
        != "97704a8960b4facceef54397a08fb5d0a456247c3627359215aa2a27df22656c"
        or value["signedEntitlementsSha256"]
        != EXPECTED_SIGNED_ENTITLEMENTS_SHA256
        or value["keychainAccessGroupsSha256"]
        != EXPECTED_KEYCHAIN_ACCESS_GROUPS_SHA256
        or value["productionDistributionCertificateSha256"]
        != EXPECTED_SIGNING_CERTIFICATE_SHA256
        or value["productionDistributionCertificateSha1"]
        != EXPECTED_SIGNING_CERTIFICATE_SHA1
        or value["productionProvisioningProfileUuid"]
        != EXPECTED_SIGNING_PROFILE_UUID
        or value["productionProvisioningProfileName"]
        != EXPECTED_SIGNING_PROFILE_NAME
        or value["rawProvisioningProfileSha256"]
        != EXPECTED_SIGNING_PROFILE_RAW_SHA256
        or value["canonicalProvisioningProfileSha256"]
        != EXPECTED_SIGNING_PROFILE_CANONICAL_SHA256
        or value["privateKeyOrCredentialRecorded"] is not False
        or value["blockingReasons"] != []
    ):
        fail(f"{label} is not one exact qualified manual signing-continuity receipt v2")
    require_revision(value["sourceRevision"], f"{label} source revision")
    for key in (
        "qualificationContractSha256", "trustRootSha256",
        "sourceEntitlementsSha256", "signedEntitlementsSha256",
        "keychainAccessGroupsSha256", "productionDistributionCertificateSha256",
        "rawProvisioningProfileSha256", "canonicalProvisioningProfileSha256",
    ):
        require_sha256(value[key], f"{label} {key}")
    if (
        type(value["configuredCodeSignIdentitySha1"]) is not str
        or SHA1_UPPER_RE.fullmatch(value["configuredCodeSignIdentitySha1"]) is None
        or type(value["productionDistributionCertificateSha1"]) is not str
        or SHA1_UPPER_RE.fullmatch(
            value["productionDistributionCertificateSha1"]
        ) is None
    ):
        fail(f"{label} distribution certificate SHA-1 is invalid")
    if value["sourceEntitlementsSha256"] == value["signedEntitlementsSha256"]:
        fail(f"{label} conflates source and signed entitlements")
    for key in (
        "qualificationSequenceNumber", "assessedAtEpochSeconds",
        "reviewedAtEpochSeconds", "qualifiedAtEpochSeconds",
    ):
        if type(value[key]) is not int or value[key] <= 0 or value[key] > MAX_SAFE_INTEGER:
            fail(f"{label} {key} is not one positive safe integer")
    chronology = [
        value["assessedAtEpochSeconds"], value["reviewedAtEpochSeconds"],
        value["qualifiedAtEpochSeconds"],
    ]
    if chronology != sorted(chronology):
        fail(f"{label} chronology is invalid")
    for key, key_label in (
        ("runId", "run ID"),
        ("productionProvisioningProfileUuid", "profile UUID"),
    ):
        raw_uuid = value[key]
        try:
            parsed_uuid = uuid.UUID(raw_uuid) if type(raw_uuid) is str else None
        except ValueError:
            parsed_uuid = None
        if parsed_uuid is None or str(parsed_uuid) != raw_uuid:
            fail(f"{label} {key_label} is not a canonical UUID")
    if uuid.UUID(value["runId"]).version != 4:
        fail(f"{label} run ID is not a version-4 UUID")
    for key in (
        "releaseEvidenceProducerKeyId", "independentReviewerKeyId",
        "productionProvisioningProfileName",
    ):
        if type(value[key]) is not str or not value[key] or len(value[key]) > 128:
            fail(f"{label} {key} is invalid")
    if value["releaseEvidenceProducerKeyId"] == value["independentReviewerKeyId"]:
        fail(f"{label} producer and reviewer identities are not distinct")
    lineage = require_exact_keys(
        value["releaseLineage"], SIGNING_LINEAGE_KEYS, f"{label} release lineage"
    )
    if lineage != EXPECTED_RELEASE_LINEAGE:
        fail(f"{label} does not bind the reviewed existing-app release lineage")
    return value


def parse_vendored_binary_receipt(raw: bytes, label: str) -> dict[str, Any]:
    value = parse_canonical_json(raw, label)
    require_exact_keys(value, VENDORED_RECEIPT_KEYS, label)
    if (
        value["schemaVersion"] != 1
        or value["contractId"]
        != "sora-ios-vendored-binary-qualification-v1"
        or value["platform"] != "ios"
        or value["status"] != "qualified"
        or value["artifactCount"] != 6
        or value["blockingReasons"] != []
    ):
        fail(f"{label} is not an exact qualified vendored-binary receipt v1")
    require_revision(value["sourceRevision"], f"{label} source revision")
    for key in (
        "qualificationContractSha256",
        "trustRootSha256",
        "evidenceManifestSha256",
    ):
        require_sha256(value[key], f"{label} {key}")
    for key in (
        "qualificationSequenceNumber",
        "reviewedAtEpochSeconds",
        "qualifiedAtEpochSeconds",
    ):
        if (
            type(value[key]) is not int
            or value[key] <= 0
            or value[key] > MAX_SAFE_INTEGER
        ):
            fail(f"{label} {key} is not one positive safe integer")
    try:
        run_id = uuid.UUID(value["runId"])
    except (TypeError, ValueError, AttributeError):
        run_id = None
    if run_id is None or run_id.version != 4 or str(run_id) != value["runId"]:
        fail(f"{label} run ID is not a canonical version-4 UUID")
    for key in ("artifactEvidenceProducerKeyId", "independentReviewerKeyId"):
        if type(value[key]) is not str or not value[key] or len(value[key]) > 128:
            fail(f"{label} {key} is invalid")
    if value["artifactEvidenceProducerKeyId"] == value["independentReviewerKeyId"]:
        fail(f"{label} producer and reviewer identities are not distinct")
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
        if value[key] is not True:
            fail(f"{label} assertion is not qualified: {key}")
    if value["reviewedAtEpochSeconds"] > value["qualifiedAtEpochSeconds"]:
        fail(f"{label} chronology is invalid")
    return value


def signing_receipt_for_manifest(
    manifest: dict[str, Any],
    label: str,
) -> tuple[bytes, dict[str, Any]]:
    retained = manifest["signingIdentityReceipt"]
    path = absolute_path(retained["path"], f"{label} signing receipt")
    raw, _ = open_regular(
        path,
        MAX_JSON_BYTES,
        f"{label} signing receipt",
        owner_only=True,
    )
    if (
        sha256_bytes(raw) != retained["sha256"]
        or len(raw) != retained["byteCount"]
    ):
        fail(f"{label} signing receipt changed")
    return raw, parse_signing_identity_receipt(raw, f"{label} signing receipt")


def vendored_receipt_for_manifest(
    manifest: dict[str, Any],
    label: str,
) -> tuple[bytes, dict[str, Any]]:
    retained = manifest["vendoredBinaryReceipt"]
    path = absolute_path(retained["path"], f"{label} vendored-binary receipt")
    raw, _ = open_regular(
        path,
        MAX_JSON_BYTES,
        f"{label} vendored-binary receipt",
    )
    if (
        sha256_bytes(raw) != retained["sha256"]
        or len(raw) != retained["byteCount"]
    ):
        fail(f"{label} vendored-binary receipt changed")
    return raw, parse_vendored_binary_receipt(
        raw,
        f"{label} vendored-binary receipt",
    )


def require_retained_signing_identity(
    inspection: dict[str, Any],
    receipt: dict[str, Any],
    label: str,
) -> None:
    identity = inspection["signedIdentity"]
    expected = {
        "applicationIdentifier": receipt["applicationIdentifier"],
        "teamIdentifier": receipt["developmentTeam"],
        "signedEntitlementsSha256": receipt["signedEntitlementsSha256"],
        "keychainAccessGroupsSha256": receipt["keychainAccessGroupsSha256"],
        "embeddedProvisioningProfileSha256":
            receipt["rawProvisioningProfileSha256"],
        "canonicalProvisioningProfileSha256":
            receipt["canonicalProvisioningProfileSha256"],
        "provisioningProfileUuid": receipt["productionProvisioningProfileUuid"],
        "provisioningProfileName": receipt["productionProvisioningProfileName"],
        "applicationSigningCertificateSha256":
            receipt["productionDistributionCertificateSha256"],
    }
    if inspection["bundleIdentifier"] != receipt["bundleIdentifier"]:
        fail(f"{label} bundle identifier differs from retained signing continuity")
    for key, expected_value in expected.items():
        if identity.get(key) != expected_value:
            fail(f"{label} signed identity {key} differs from retained continuity")
    certificates = identity.get("developerCertificateSha256")
    if (
        type(certificates) is not list
        or receipt["productionDistributionCertificateSha256"] not in certificates
    ):
        fail(f"{label} retained application signer is absent from its profile")


def capture_build_manifest(
    *,
    role: str,
    repository: Path,
    derived_data: Path,
    archive: Path,
    export: Path,
    ipa: Path,
    archive_log: Path,
    export_log: Path,
    qualification_contract_sha: str,
    signing_receipt_path: Path,
    signing_receipt_sha: str,
    vendored_receipt_sha: str,
    build_number: str,
    app_store_build_lower_bound: str,
    output: Path,
) -> dict[str, Any]:
    if role not in ("primary", "reproduction"):
        fail("build role must be primary or reproduction")
    signing_path = absolute_path(
        str(signing_receipt_path), "authenticated signing-identity receipt"
    )
    try:
        canonical_repository = repository.resolve(strict=True)
    except (OSError, RuntimeError) as error:
        fail(f"repository cannot be resolved canonically: {error}")
    if canonical_repository != repository:
        fail("Release repository path is symbolic or noncanonical")
    if signing_path == repository or repository in signing_path.parents:
        fail("authenticated signing receipt must remain outside the clean checkout")
    status = git_output(repository, ["status", "--porcelain=v1", "--untracked-files=normal"], "checkout status")
    if status != "":
        fail("Release reproduction requires a completely clean checkout")
    revision = git_output(repository, ["rev-parse", "--verify", "HEAD^{commit}"], "source revision").strip()
    require_revision(revision, "source revision")
    require_sha256(qualification_contract_sha, "qualification source contract")
    require_sha256(signing_receipt_sha, "authenticated signing receipt")
    require_sha256(vendored_receipt_sha, "authenticated vendored-binary receipt")
    require_build_number(build_number, "candidate build number")
    require_build_number(
        app_store_build_lower_bound,
        "controller-provided App Store build-number lower bound",
    )
    if int(build_number) <= int(app_store_build_lower_bound):
        fail("candidate build number is not newer than the App Store lower bound")
    if archive_build_number(archive, f"{role} build") != build_number:
        fail("archived application build number differs from the controller-authorized input")
    dependencies = []
    for relative in DEPENDENCY_PATHS:
        path = repository / relative
        identity = checked_digest(path, MAX_JSON_BYTES, f"dependency manifest {relative}")
        dependencies.append({"path": relative, **identity})
    signing_raw, _ = open_regular(
        signing_path,
        MAX_JSON_BYTES,
        "authenticated signing-identity receipt",
        owner_only=True,
    )
    signing_receipt = parse_signing_identity_receipt(
        signing_raw,
        "authenticated signing-identity receipt",
    )
    if signing_receipt["sourceRevision"] != revision:
        fail("authenticated signing receipt names a different clean source revision")
    signing = {"sha256": sha256_bytes(signing_raw), "byteCount": len(signing_raw)}
    if signing["sha256"] != signing_receipt_sha:
        fail("signing receipt differs from its immediately authenticated SHA-256")
    vendored_path = repository / VENDORED_RECEIPT.relative_to(ROOT)
    vendored_raw, _ = open_regular(
        vendored_path,
        MAX_JSON_BYTES,
        "authenticated vendored-binary receipt",
    )
    vendored_receipt = parse_vendored_binary_receipt(
        vendored_raw,
        "authenticated vendored-binary receipt",
    )
    if vendored_receipt["sourceRevision"] != revision:
        fail("authenticated vendored-binary receipt names a different clean source revision")
    vendored = {
        "sha256": sha256_bytes(vendored_raw),
        "byteCount": len(vendored_raw),
    }
    if vendored["sha256"] != vendored_receipt_sha:
        fail(
            "vendored-binary receipt differs from its immediately authenticated SHA-256"
        )
    ipa_identity = checked_digest(ipa, MAX_IPA_BYTES, "exported production IPA")
    archive_content_path = output.parent / f"{role}-archive-content-manifest.json"
    export_content_path = output.parent / f"{role}-export-content-manifest.json"
    publish_canonical_json(archive_content_path, content_manifest(archive, "archive content"), "archive content manifest")
    publish_canonical_json(export_content_path, content_manifest(export, "export content"), "export content manifest")
    manifest = {
        "format": BUILD_FORMAT,
        "role": role,
        "cleanCheckout": True,
        "sourceRevision": revision,
        "qualificationContractSha256": qualification_contract_sha,
        "buildNumber": build_number,
        "appStoreBuildNumberLowerBound": app_store_build_lower_bound,
        "tairaDeployment": archive_taira_deployment_projection(
            archive,
            f"{role} build",
        ),
        "checkoutIdentity": file_identity(repository, "checkout", directory=True),
        "derivedDataIdentity": file_identity(derived_data, "DerivedData", directory=True),
        "archiveIdentity": file_identity(archive, "archive", directory=True),
        "exportIdentity": file_identity(export, "export", directory=True),
        "archiveContentManifest": {
            "path": str(archive_content_path),
            **checked_digest(archive_content_path, MAX_JSON_BYTES, "archive content manifest"),
        },
        "exportContentManifest": {
            "path": str(export_content_path),
            **checked_digest(export_content_path, MAX_JSON_BYTES, "export content manifest"),
        },
        "ipa": {"path": str(ipa), **ipa_identity},
        "dependencyManifests": dependencies,
        "signingIdentityReceipt": {
            "path": str(signing_path),
            **signing,
        },
        "vendoredBinaryReceipt": {
            "path": str(vendored_path),
            **vendored,
        },
        "logs": {
            "archive": {"path": str(archive_log), **checked_digest(archive_log, MAX_LOG_BYTES, "archive log")},
            "export": {"path": str(export_log), **checked_digest(export_log, MAX_LOG_BYTES, "export log")},
        },
    }
    publish_canonical_json(output, manifest, "build manifest")
    return manifest


def parse_file_digest(value: Any, label: str, *, require_path: bool = True) -> dict[str, Any]:
    keys = {"sha256", "byteCount"} | ({"path"} if require_path else set())
    item = require_exact_keys(value, keys, label)
    require_sha256(item["sha256"], f"{label} SHA-256")
    if type(item["byteCount"]) is not int or item["byteCount"] <= 0:
        fail(f"{label} byte count is invalid")
    if require_path:
        absolute_path(item["path"], f"{label} path")
    return item


def parse_physical_identity(value: Any, label: str) -> dict[str, Any]:
    item = require_exact_keys(value, {"path", "device", "inode"}, label)
    absolute_path(item["path"], f"{label} path")
    if any(type(item[key]) is not int or item[key] <= 0 for key in ("device", "inode")):
        fail(f"{label} physical identity is invalid")
    return item


def parse_build_manifest(raw: bytes, label: str) -> dict[str, Any]:
    value = parse_canonical_json(raw, label)
    require_exact_keys(
        value,
        {
            "format", "role", "cleanCheckout", "sourceRevision", "qualificationContractSha256",
            "buildNumber", "appStoreBuildNumberLowerBound", "checkoutIdentity",
            "derivedDataIdentity", "archiveIdentity", "exportIdentity", "ipa",
            "archiveContentManifest", "exportContentManifest", "dependencyManifests",
            "signingIdentityReceipt", "vendoredBinaryReceipt", "logs",
            "tairaDeployment",
        },
        label,
    )
    if value["format"] != BUILD_FORMAT or value["role"] not in ("primary", "reproduction") or value["cleanCheckout"] is not True:
        fail(f"{label} is not a clean exact Release build manifest")
    require_revision(value["sourceRevision"], f"{label} source revision")
    require_sha256(value["qualificationContractSha256"], f"{label} qualification source contract")
    require_build_number(value["buildNumber"], f"{label} build number")
    require_build_number(
        value["appStoreBuildNumberLowerBound"],
        f"{label} App Store build-number lower bound",
    )
    if int(value["buildNumber"]) <= int(value["appStoreBuildNumberLowerBound"]):
        fail(f"{label} build number is not newer than its App Store lower bound")
    parse_taira_deployment_projection(
        {
            {
                "contractId": "SoraTairaDeploymentAdmissionContractId",
                "manifestSha256": "SoraTairaDeploymentManifestSha256",
                "manifestSequenceNumber": "SoraTairaDeploymentManifestSequenceNumber",
                "admissionSha256": "SoraTairaDeploymentAdmissionSha256",
                "currentChainId": "SoraTairaCurrentChainId",
                "retiredChainId": "SoraTairaRetiredChainId",
                "currentGenesisHash": "SoraTairaCurrentGenesisHash",
                "retiredGenesisHash": "SoraTairaRetiredGenesisHash",
                "currentDeploymentEpoch": "SoraTairaCurrentDeploymentEpoch",
                "retiredDeploymentEpoch": "SoraTairaRetiredDeploymentEpoch",
                "canonicalToriiBaseUrl": "SoraTairaCanonicalToriiBaseUrl",
                "publicMcpEndpoint": "SoraTairaPublicMcpEndpoint",
                "explorerBaseUrl": "SoraTairaExplorerBaseUrl",
                "pendingRowPolicy": "SoraTairaPendingRowPolicy",
            }[key]: child
            for key, child in require_exact_keys(
                value["tairaDeployment"],
                {
                    "contractId", "manifestSha256", "manifestSequenceNumber",
                    "admissionSha256",
                    "currentChainId", "retiredChainId", "currentGenesisHash",
                    "retiredGenesisHash", "currentDeploymentEpoch",
                    "retiredDeploymentEpoch", "canonicalToriiBaseUrl",
                    "publicMcpEndpoint", "explorerBaseUrl", "pendingRowPolicy",
                },
                f"{label} Taira deployment",
            ).items()
        },
        f"{label} Taira deployment",
    )
    for key in ("checkoutIdentity", "derivedDataIdentity", "archiveIdentity", "exportIdentity"):
        parse_physical_identity(value[key], f"{label} {key}")
    parse_file_digest(value["archiveContentManifest"], f"{label} archive content manifest")
    parse_file_digest(value["exportContentManifest"], f"{label} export content manifest")
    parse_file_digest(value["ipa"], f"{label} IPA")
    parse_file_digest(value["signingIdentityReceipt"], f"{label} signing receipt")
    checkout_path = absolute_path(
        value["checkoutIdentity"]["path"], f"{label} checkout"
    )
    signing_path = absolute_path(
        value["signingIdentityReceipt"]["path"], f"{label} signing receipt"
    )
    if signing_path == checkout_path or checkout_path in signing_path.parents:
        fail(f"{label} signing receipt must remain outside the clean checkout")
    parse_file_digest(
        value["vendoredBinaryReceipt"],
        f"{label} vendored-binary receipt",
    )
    logs = require_exact_keys(value["logs"], {"archive", "export"}, f"{label} logs")
    parse_file_digest(logs["archive"], f"{label} archive log")
    parse_file_digest(logs["export"], f"{label} export log")
    dependencies = value["dependencyManifests"]
    if type(dependencies) is not list or len(dependencies) != len(DEPENDENCY_PATHS):
        fail(f"{label} does not bind exactly six dependency manifests")
    for index, (item, expected_path) in enumerate(zip(dependencies, DEPENDENCY_PATHS)):
        parsed = require_exact_keys(item, {"path", "sha256", "byteCount"}, f"{label} dependency {index}")
        if parsed["path"] != expected_path:
            fail(f"{label} dependency manifest order or path drifted")
        parse_file_digest(
            {key: parsed[key] for key in ("sha256", "byteCount")},
            f"{label} dependency {index}",
            require_path=False,
        )
    return value


def distinct_physical(left: dict[str, Any], right: dict[str, Any], label: str) -> None:
    if left["path"] == right["path"] or (left["device"], left["inode"]) == (right["device"], right["inode"]):
        fail(f"primary and reproduction {label} are not physically distinct")


def verify_manifest_files(manifest: dict[str, Any], label: str, ipa_path: Path) -> None:
    for key, kind in (
        ("checkoutIdentity", "checkout"),
        ("derivedDataIdentity", "DerivedData"),
        ("archiveIdentity", "archive"),
        ("exportIdentity", "export"),
    ):
        retained = manifest[key]
        current = file_identity(
            absolute_path(retained["path"], f"{label} {kind}"),
            f"{label} {kind}",
            directory=True,
        )
        if current != retained:
            fail(f"{label} {kind} physical identity changed")
    retained_archive = absolute_path(
        manifest["archiveIdentity"]["path"],
        f"{label} archive",
    )
    if archive_build_number(retained_archive, label) != manifest["buildNumber"]:
        fail(f"{label} archived application build number changed")
    if manifest["ipa"]["path"] != str(ipa_path):
        fail(f"{label} IPA path differs from its build manifest")
    ipa_actual = checked_digest(ipa_path, MAX_IPA_BYTES, f"{label} IPA")
    if any(ipa_actual[key] != manifest["ipa"][key] for key in ("sha256", "byteCount")):
        fail(f"{label} IPA differs from its build manifest")
    for log_name in ("archive", "export"):
        record = manifest["logs"][log_name]
        actual = checked_digest(absolute_path(record["path"], f"{label} {log_name} log"), MAX_LOG_BYTES, f"{label} {log_name} log")
        if actual != {"sha256": record["sha256"], "byteCount": record["byteCount"]}:
            fail(f"{label} {log_name} log differs from its build manifest")
    for kind, identity_key, manifest_key in (
        ("archive", "archiveIdentity", "archiveContentManifest"),
        ("export", "exportIdentity", "exportContentManifest"),
    ):
        retained = manifest[manifest_key]
        retained_raw, _ = open_regular(
            absolute_path(retained["path"], f"{label} {kind} content manifest"),
            MAX_JSON_BYTES,
            f"{label} {kind} content manifest",
        )
        if sha256_bytes(retained_raw) != retained["sha256"] or len(retained_raw) != retained["byteCount"]:
            fail(f"{label} {kind} content manifest changed")
        observed = canonical_json(
            content_manifest(
                absolute_path(manifest[identity_key]["path"], f"{label} {kind}"),
                f"{label} {kind} content",
            )
        )
        if observed != retained_raw:
            fail(f"{label} {kind} content changed after its manifest")
    checkout = absolute_path(manifest["checkoutIdentity"]["path"], f"{label} checkout")
    for dependency in manifest["dependencyManifests"]:
        actual = checked_digest(
            checkout / dependency["path"],
            MAX_JSON_BYTES,
            f"{label} dependency {dependency['path']}",
        )
        if actual != {key: dependency[key] for key in ("sha256", "byteCount")}:
            fail(f"{label} dependency manifest changed")
    signing = manifest["signingIdentityReceipt"]
    signing_actual, _ = digest_regular(
        absolute_path(signing["path"], f"{label} signing receipt"),
        MAX_JSON_BYTES,
        f"{label} signing receipt",
        owner_only=True,
    )
    if signing_actual != {key: signing[key] for key in ("sha256", "byteCount")}:
        fail(f"{label} signing identity receipt changed")
    vendored = manifest["vendoredBinaryReceipt"]
    vendored_actual = checked_digest(
        absolute_path(
            vendored["path"],
            f"{label} vendored-binary receipt",
        ),
        MAX_JSON_BYTES,
        f"{label} vendored-binary receipt",
    )
    if vendored_actual != {
        key: vendored[key] for key in ("sha256", "byteCount")
    }:
        fail(f"{label} vendored-binary receipt changed")
    archive_projection = archive_taira_deployment_projection(
        absolute_path(manifest["archiveIdentity"]["path"], f"{label} archive"),
        f"{label} archive",
    )
    if archive_projection != manifest["tairaDeployment"]:
        fail(f"{label} Taira deployment admission changed after archive capture")


def compare_releases(
    primary_ipa: Path,
    reproduction_ipa: Path,
    primary_manifest_path: Path,
    reproduction_manifest_path: Path,
    output: Path,
    inspector: Callable[[Path], dict[str, Any]] = inspect_release_ipa,
) -> dict[str, Any]:
    primary_raw, _ = open_regular(primary_manifest_path, MAX_JSON_BYTES, "primary build manifest")
    reproduction_raw, _ = open_regular(reproduction_manifest_path, MAX_JSON_BYTES, "reproduction build manifest")
    primary_manifest = parse_build_manifest(primary_raw, "primary build manifest")
    reproduction_manifest = parse_build_manifest(reproduction_raw, "reproduction build manifest")
    if primary_manifest["role"] != "primary" or reproduction_manifest["role"] != "reproduction":
        fail("build manifests have swapped or ambiguous roles")
    verify_manifest_files(primary_manifest, "primary", primary_ipa)
    verify_manifest_files(reproduction_manifest, "reproduction", reproduction_ipa)
    for key, label in (
        ("checkoutIdentity", "checkout"), ("derivedDataIdentity", "DerivedData"),
        ("archiveIdentity", "archive"), ("exportIdentity", "export"),
    ):
        distinct_physical(primary_manifest[key], reproduction_manifest[key], label)
    for key in (
        "sourceRevision", "qualificationContractSha256", "buildNumber",
        "appStoreBuildNumberLowerBound",
        "dependencyManifests", "tairaDeployment",
    ):
        if primary_manifest[key] != reproduction_manifest[key]:
            fail(f"primary and reproduction {key} identities differ")
    for key in ("sha256", "byteCount"):
        if primary_manifest["signingIdentityReceipt"][key] != reproduction_manifest["signingIdentityReceipt"][key]:
            fail("primary and reproduction signing identity receipt digests differ")
        if primary_manifest["vendoredBinaryReceipt"][key] != reproduction_manifest["vendoredBinaryReceipt"][key]:
            fail("primary and reproduction vendored-binary receipt digests differ")
    primary_signing_raw, primary_signing = signing_receipt_for_manifest(
        primary_manifest,
        "primary",
    )
    reproduction_signing_raw, reproduction_signing = signing_receipt_for_manifest(
        reproduction_manifest,
        "reproduction",
    )
    if primary_signing_raw != reproduction_signing_raw:
        fail("primary and reproduction authenticated signing receipts differ")
    if primary_signing["sourceRevision"] != primary_manifest["sourceRevision"]:
        fail("authenticated signing receipt names a different release source revision")
    primary_vendored_raw, primary_vendored = vendored_receipt_for_manifest(
        primary_manifest,
        "primary",
    )
    reproduction_vendored_raw, _ = vendored_receipt_for_manifest(
        reproduction_manifest,
        "reproduction",
    )
    if primary_vendored_raw != reproduction_vendored_raw:
        fail("primary and reproduction authenticated vendored-binary receipts differ")
    if primary_vendored["sourceRevision"] != primary_manifest["sourceRevision"]:
        fail(
            "authenticated vendored-binary receipt names a different release source revision"
        )
    primary = inspector(primary_ipa)
    reproduction = inspector(reproduction_ipa)
    if primary["ipaSha256"] != primary_manifest["ipa"]["sha256"] or reproduction["ipaSha256"] != reproduction_manifest["ipa"]["sha256"]:
        fail("signed IPA inspection differs from a build manifest")
    if primary["sourceRevision"] != primary_manifest["sourceRevision"] or reproduction["sourceRevision"] != primary_manifest["sourceRevision"]:
        fail("signed IPA source revision differs from the clean checkouts")
    if primary["qualificationContractSha256"] != primary_manifest["qualificationContractSha256"] or reproduction["qualificationContractSha256"] != primary_manifest["qualificationContractSha256"]:
        fail("signed IPA qualification contract differs from the clean builds")
    if (
        primary["canonicalInfo"].get("buildVersion")
        != primary_manifest["buildNumber"]
        or reproduction["canonicalInfo"].get("buildVersion")
        != primary_manifest["buildNumber"]
    ):
        fail("signed IPA build number differs from the controller-authorized clean builds")
    if (
        primary["tairaDeployment"] != primary_manifest["tairaDeployment"]
        or reproduction["tairaDeployment"]
        != reproduction_manifest["tairaDeployment"]
    ):
        fail("signed IPA Taira deployment admission differs from a clean archive")
    equality_fields = (
        "qualificationContractSha256", "bundleIdentifier", "canonicalProjection",
        "canonicalExecutableSha256", "canonicalExecutableByteCount", "canonicalInfo",
        "entitlementProjection", "signedIdentity", "tairaDeployment",
    )
    for key in equality_fields:
        if primary[key] != reproduction[key]:
            fail(f"primary and reproduction signed application {key} differ")
    require_retained_signing_identity(primary, primary_signing, "primary IPA")
    require_retained_signing_identity(
        reproduction,
        reproduction_signing,
        "reproduction IPA",
    )
    exact_bytes = primary["ipaSha256"] == reproduction["ipaSha256"]
    policy = "exact-ipa-bytes-v1" if exact_bytes else "canonical-signed-application-equivalence-v1"
    receipt = {
        "format": EQUIVALENCE_FORMAT,
        "status": "qualified",
        "releaseAuthorized": False,
        "uploadAuthorized": False,
        "equivalencePolicy": policy,
        "exactIpaByteEquality": exact_bytes,
        "deterministicProductionExportDemonstrated": exact_bytes,
        "signedContainerNondeterminismObserved": not exact_bytes,
        "sourceRevision": primary_manifest["sourceRevision"],
        "qualificationContractSha256": primary["qualificationContractSha256"],
        "buildNumber": primary_manifest["buildNumber"],
        "appStoreBuildNumberLowerBound":
            primary_manifest["appStoreBuildNumberLowerBound"],
        "tairaDeployment": primary["tairaDeployment"],
        "dependencyManifests": primary_manifest["dependencyManifests"],
        "signingIdentityReceipt": primary_manifest["signingIdentityReceipt"],
        "vendoredBinaryReceipt": primary_manifest["vendoredBinaryReceipt"],
        "primary": {
            "ipaSha256": primary["ipaSha256"], "ipaByteCount": primary["ipaByteCount"],
            "buildManifestSha256": sha256_bytes(primary_raw),
            "archiveLogSha256": primary_manifest["logs"]["archive"]["sha256"],
            "exportLogSha256": primary_manifest["logs"]["export"]["sha256"],
            "archiveContentManifestSha256": primary_manifest["archiveContentManifest"]["sha256"],
            "exportContentManifestSha256": primary_manifest["exportContentManifest"]["sha256"],
        },
        "reproduction": {
            "ipaSha256": reproduction["ipaSha256"], "ipaByteCount": reproduction["ipaByteCount"],
            "buildManifestSha256": sha256_bytes(reproduction_raw),
            "archiveLogSha256": reproduction_manifest["logs"]["archive"]["sha256"],
            "exportLogSha256": reproduction_manifest["logs"]["export"]["sha256"],
            "archiveContentManifestSha256": reproduction_manifest["archiveContentManifest"]["sha256"],
            "exportContentManifestSha256": reproduction_manifest["exportContentManifest"]["sha256"],
        },
        "canonicalApplication": {
            "projection": primary["canonicalProjection"],
            "executableSha256": primary["canonicalExecutableSha256"],
            "executableByteCount": primary["canonicalExecutableByteCount"],
            "resourceAndInfoProjectionSha256": sha256_bytes(canonical_json({
                "projection": primary["canonicalProjection"], "info": primary["canonicalInfo"]
            })),
            "entitlementProjectionSha256": sha256_bytes(canonical_json(primary["entitlementProjection"])),
        },
        "signedIdentity": primary["signedIdentity"],
        "checks": {
            "physicallyDistinctCleanCheckouts": True,
            "physicallyDistinctDerivedData": True,
            "physicallyDistinctArchives": True,
            "physicallyDistinctExports": True,
            "sameSourceAndSixDependencyManifests": True,
            "sameSigningIdentity": True,
            "matchesAuthenticatedRetainedSigningIdentity": True,
            "sameAuthenticatedVendoredBinaryQualification": True,
            "sameProtectedTairaDeploymentAdmission": True,
            "canonicalAppExecutableResourcesEqual": True,
            "exactCodeDirectoryProfileEntitlementsCertificatesEqual": True,
        },
    }
    parse_equivalence_receipt(canonical_json(receipt))
    publish_canonical_json(output, receipt, "equivalence receipt")
    return receipt


def parse_equivalence_receipt(raw: bytes) -> dict[str, Any]:
    value = parse_canonical_json(raw, "equivalence receipt")
    require_exact_keys(
        value,
        {
            "format", "status", "releaseAuthorized", "uploadAuthorized",
            "equivalencePolicy", "exactIpaByteEquality",
            "deterministicProductionExportDemonstrated",
            "signedContainerNondeterminismObserved", "sourceRevision",
            "qualificationContractSha256", "buildNumber",
            "appStoreBuildNumberLowerBound", "dependencyManifests",
            "tairaDeployment",
            "signingIdentityReceipt", "vendoredBinaryReceipt",
            "primary", "reproduction",
            "canonicalApplication", "signedIdentity", "checks",
        },
        "equivalence receipt",
    )
    exact = value["exactIpaByteEquality"]
    if (
        value["format"] != EQUIVALENCE_FORMAT
        or value["status"] != "qualified"
        or value["releaseAuthorized"] is not False
        or value["uploadAuthorized"] is not False
        or type(exact) is not bool
        or type(value["deterministicProductionExportDemonstrated"]) is not bool
        or type(value["signedContainerNondeterminismObserved"]) is not bool
    ):
        fail("equivalence receipt has an authorizing or invalid fixed contract")
    require_revision(value["sourceRevision"], "equivalence source revision")
    require_sha256(value["qualificationContractSha256"], "equivalence qualification contract")
    require_build_number(value["buildNumber"], "equivalence build number")
    require_build_number(
        value["appStoreBuildNumberLowerBound"],
        "equivalence App Store build-number lower bound",
    )
    if int(value["buildNumber"]) <= int(value["appStoreBuildNumberLowerBound"]):
        fail("equivalence build number is not newer than its App Store lower bound")
    taira_projection = require_exact_keys(
        value["tairaDeployment"],
        {
            "contractId", "manifestSha256", "manifestSequenceNumber",
            "admissionSha256",
            "currentChainId", "retiredChainId", "currentGenesisHash",
            "retiredGenesisHash", "currentDeploymentEpoch",
            "retiredDeploymentEpoch", "canonicalToriiBaseUrl",
            "publicMcpEndpoint", "explorerBaseUrl", "pendingRowPolicy",
        },
        "equivalence Taira deployment",
    )
    parse_taira_deployment_projection(
        {
            {
                "contractId": "SoraTairaDeploymentAdmissionContractId",
                "manifestSha256": "SoraTairaDeploymentManifestSha256",
                "manifestSequenceNumber": "SoraTairaDeploymentManifestSequenceNumber",
                "admissionSha256": "SoraTairaDeploymentAdmissionSha256",
                "currentChainId": "SoraTairaCurrentChainId",
                "retiredChainId": "SoraTairaRetiredChainId",
                "currentGenesisHash": "SoraTairaCurrentGenesisHash",
                "retiredGenesisHash": "SoraTairaRetiredGenesisHash",
                "currentDeploymentEpoch": "SoraTairaCurrentDeploymentEpoch",
                "retiredDeploymentEpoch": "SoraTairaRetiredDeploymentEpoch",
                "canonicalToriiBaseUrl": "SoraTairaCanonicalToriiBaseUrl",
                "publicMcpEndpoint": "SoraTairaPublicMcpEndpoint",
                "explorerBaseUrl": "SoraTairaExplorerBaseUrl",
                "pendingRowPolicy": "SoraTairaPendingRowPolicy",
            }[key]: child
            for key, child in taira_projection.items()
        },
        "equivalence Taira deployment",
    )
    expected_policy = "exact-ipa-bytes-v1" if exact else "canonical-signed-application-equivalence-v1"
    if (
        value["equivalencePolicy"] != expected_policy
        or value["deterministicProductionExportDemonstrated"] is not exact
        or value["signedContainerNondeterminismObserved"] is exact
    ):
        fail("equivalence receipt makes an inconsistent IPA byte-equality claim")
    build_keys = {
        "ipaSha256", "ipaByteCount", "buildManifestSha256", "archiveLogSha256",
        "exportLogSha256", "archiveContentManifestSha256",
        "exportContentManifestSha256",
    }
    builds = []
    for role in ("primary", "reproduction"):
        build = require_exact_keys(value[role], build_keys, f"equivalence {role}")
        for key in build_keys - {"ipaByteCount"}:
            require_sha256(build[key], f"equivalence {role} {key}")
        if type(build["ipaByteCount"]) is not int or build["ipaByteCount"] <= 0:
            fail(f"equivalence {role} IPA byte count is invalid")
        builds.append(build)
    raw_identity_equal = (
        builds[0]["ipaSha256"] == builds[1]["ipaSha256"]
        and builds[0]["ipaByteCount"] == builds[1]["ipaByteCount"]
    )
    if raw_identity_equal is not exact:
        fail("equivalence receipt byte-equality claim differs from both raw IPA identities")
    dependencies = value["dependencyManifests"]
    if type(dependencies) is not list or len(dependencies) != len(DEPENDENCY_PATHS):
        fail("equivalence receipt does not bind exactly six dependency manifests")
    for index, (item, expected_path) in enumerate(zip(dependencies, DEPENDENCY_PATHS)):
        item = require_exact_keys(item, {"path", "sha256", "byteCount"}, f"equivalence dependency {index}")
        if item["path"] != expected_path:
            fail("equivalence dependency path or order drifted")
        parse_file_digest(
            {key: item[key] for key in ("sha256", "byteCount")},
            f"equivalence dependency {index}",
            require_path=False,
        )
    signing_receipt = require_exact_keys(
        value["signingIdentityReceipt"],
        {"path", "sha256", "byteCount"},
        "equivalence signing receipt",
    )
    if type(signing_receipt["path"]) is not str:
        fail("equivalence signing receipt path is invalid")
    signing_receipt_path = Path(signing_receipt["path"])
    if (
        not signing_receipt_path.is_absolute()
        or any(part in ("", ".", "..") for part in signing_receipt_path.parts[1:])
    ):
        fail("equivalence signing receipt path is invalid")
    parse_file_digest(
        {key: signing_receipt[key] for key in ("sha256", "byteCount")},
        "equivalence signing receipt",
        require_path=False,
    )
    vendored_receipt = require_exact_keys(
        value["vendoredBinaryReceipt"],
        {"path", "sha256", "byteCount"},
        "equivalence vendored-binary receipt",
    )
    if type(vendored_receipt["path"]) is not str:
        fail("equivalence vendored-binary receipt path is invalid")
    vendored_receipt_path = Path(vendored_receipt["path"])
    if (
        not vendored_receipt_path.is_absolute()
        or any(
            part in ("", ".", "..")
            for part in vendored_receipt_path.parts[1:]
        )
    ):
        fail("equivalence vendored-binary receipt path is invalid")
    parse_file_digest(
        {key: vendored_receipt[key] for key in ("sha256", "byteCount")},
        "equivalence vendored-binary receipt",
        require_path=False,
    )
    application = require_exact_keys(
        value["canonicalApplication"],
        {
            "projection", "executableSha256", "executableByteCount",
            "resourceAndInfoProjectionSha256", "entitlementProjectionSha256",
        },
        "equivalence canonical application",
    )
    if type(application["projection"]) is not dict or type(application["executableByteCount"]) is not int or application["executableByteCount"] <= 0:
        fail("equivalence canonical application is invalid")
    for key in ("executableSha256", "resourceAndInfoProjectionSha256", "entitlementProjectionSha256"):
        require_sha256(application[key], f"equivalence canonical application {key}")
    signing = require_exact_keys(
        value["signedIdentity"],
        {
            "applicationIdentifier", "teamIdentifier", "signedEntitlementsSha256",
            "keychainAccessGroupsSha256", "embeddedProvisioningProfileSha256",
            "canonicalProvisioningProfileSha256", "provisioningProfileUuid",
            "provisioningProfileName", "applicationSigningCertificateSha256",
            "developerCertificateSha256", "codeDirectories",
        },
        "equivalence signed identity",
    )
    for key in (
        "applicationIdentifier", "teamIdentifier", "provisioningProfileUuid",
        "provisioningProfileName",
    ):
        if type(signing[key]) is not str or not signing[key] or len(signing[key]) > 512:
            fail(f"equivalence signed identity {key} is invalid")
    for key in (
        "signedEntitlementsSha256", "keychainAccessGroupsSha256",
        "embeddedProvisioningProfileSha256", "canonicalProvisioningProfileSha256",
        "applicationSigningCertificateSha256",
    ):
        require_sha256(signing[key], f"equivalence signed identity {key}")
    certificates = signing["developerCertificateSha256"]
    if type(certificates) is not list or not certificates or certificates != sorted(set(certificates)):
        fail("equivalence signed identity certificate inventory is invalid")
    for certificate in certificates:
        require_sha256(certificate, "equivalence developer certificate")
    if signing["applicationSigningCertificateSha256"] not in certificates:
        fail("equivalence application signer is absent from the embedded profile")
    code_directories = signing["codeDirectories"]
    if type(code_directories) is not list or not code_directories:
        fail("equivalence signed identity CodeDirectory inventory is empty")
    observed_code_paths: list[str] = []
    for index, item in enumerate(code_directories):
        item = require_exact_keys(
            item,
            {"codePath", "candidateCodeDirectorySha256"},
            f"equivalence CodeDirectory {index}",
        )
        path = item["codePath"]
        hashes = item["candidateCodeDirectorySha256"]
        pure = PurePosixPath(path) if type(path) is str else PurePosixPath("/")
        if (
            type(path) is not str
            or pure.is_absolute()
            or any(part in ("", ".", "..") for part in pure.parts)
            or type(hashes) is not list
            or not hashes
            or hashes != sorted(set(hashes))
        ):
            fail("equivalence CodeDirectory inventory is invalid")
        observed_code_paths.append(path)
        for digest in hashes:
            require_sha256(digest, "equivalence CodeDirectory")
    if observed_code_paths != sorted(set(observed_code_paths)):
        fail("equivalence CodeDirectory paths are duplicated or unordered")
    checks = require_exact_keys(
        value["checks"],
        {
            "physicallyDistinctCleanCheckouts", "physicallyDistinctDerivedData",
            "physicallyDistinctArchives", "physicallyDistinctExports",
            "sameSourceAndSixDependencyManifests", "sameSigningIdentity",
            "matchesAuthenticatedRetainedSigningIdentity",
            "sameAuthenticatedVendoredBinaryQualification",
            "sameProtectedTairaDeploymentAdmission",
            "canonicalAppExecutableResourcesEqual",
            "exactCodeDirectoryProfileEntitlementsCertificatesEqual",
        },
        "equivalence checks",
    )
    if any(result is not True for result in checks.values()):
        fail("equivalence receipt contains a false check")
    return value


def publish_canonical_json(path: Path, value: dict[str, Any], label: str) -> None:
    raw = canonical_json(value)
    path = absolute_path(str(path), label)
    parent = path.parent
    metadata = os.stat(parent, follow_symlinks=False)
    if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != os.getuid() or stat.S_IMODE(metadata.st_mode) != 0o700:
        fail(f"{label} parent must be current-user-owned mode 0700")
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    descriptor = os.open(path, flags, 0o600)
    try:
        view = memoryview(raw)
        while view:
            written = os.write(descriptor, view)
            if written <= 0:
                fail(f"{label} could not be written completely")
            view = view[written:]
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def package_attachment(path: Path, maximum: int, label: str) -> tuple[bytes, dict[str, Any]]:
    raw, _ = open_regular(path, maximum, label)
    return raw, {"sha256": sha256_bytes(raw), "byteCount": len(raw)}


def zip_member_info(name: str, *, stored: bool = False) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name)
    info.create_system = 3
    info.external_attr = (stat.S_IFREG | 0o600) << 16
    info.compress_type = zipfile.ZIP_STORED if stored else zipfile.ZIP_DEFLATED
    return info


def write_path_member(
    archive: zipfile.ZipFile,
    name: str,
    path: Path,
    expected: dict[str, Any],
    maximum: int,
    label: str,
    *,
    stored: bool = False,
) -> None:
    flags = os.O_RDONLY | os.O_NOFOLLOW
    if hasattr(os, "O_CLOEXEC"):
        flags |= os.O_CLOEXEC
    descriptor = os.open(path, flags)
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1 or before.st_size <= 0 or before.st_size > maximum:
            fail(f"{label} is not one bounded regular inode")
        digest = hashlib.sha256()
        consumed = 0
        with archive.open(zip_member_info(name, stored=stored), "w", force_zip64=True) as destination:
            while True:
                chunk = os.read(descriptor, 1024 * 1024)
                if not chunk:
                    break
                consumed += len(chunk)
                if consumed > maximum:
                    fail(f"{label} exceeds its byte bound")
                digest.update(chunk)
                destination.write(chunk)
        after = os.fstat(descriptor)
        named = os.stat(path, follow_symlinks=False)
        identity = lambda item: (item.st_dev, item.st_ino, item.st_mode, item.st_nlink, item.st_size, item.st_mtime_ns)
        if (
            consumed != before.st_size
            or identity(before) != identity(after)
            or identity(before) != identity(named)
            or {"sha256": digest.hexdigest(), "byteCount": consumed} != expected
        ):
            fail(f"{label} changed while sealed")
    finally:
        os.close(descriptor)


def hash_zip_member(archive: zipfile.ZipFile, info: zipfile.ZipInfo, maximum: int, label: str) -> dict[str, Any]:
    if info.file_size <= 0 or info.file_size > maximum:
        fail(f"{label} has an invalid ZIP byte count")
    digest = hashlib.sha256()
    consumed = 0
    with archive.open(info, "r") as source:
        while True:
            chunk = source.read(1024 * 1024)
            if not chunk:
                break
            consumed += len(chunk)
            if consumed > maximum:
                fail(f"{label} exceeds its ZIP byte bound")
            digest.update(chunk)
    if consumed != info.file_size:
        fail(f"{label} differs from its ZIP directory byte count")
    return {"sha256": digest.hexdigest(), "byteCount": consumed}


def compare_zip_member_to_file(
    archive: zipfile.ZipFile,
    info: zipfile.ZipInfo,
    expected_path: Path,
    maximum: int,
    label: str,
) -> dict[str, Any]:
    flags = os.O_RDONLY | os.O_NOFOLLOW
    if hasattr(os, "O_CLOEXEC"):
        flags |= os.O_CLOEXEC
    descriptor = os.open(expected_path, flags)
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1 or before.st_size <= 0 or before.st_size > maximum:
            fail(f"expected {label} is not one bounded regular inode")
        digest = hashlib.sha256()
        consumed = 0
        with archive.open(info, "r") as packaged:
            while True:
                expected_chunk = os.read(descriptor, 1024 * 1024)
                packaged_chunk = packaged.read(1024 * 1024)
                if expected_chunk != packaged_chunk:
                    fail(f"downloaded package does not contain the exact {label} bytes")
                if not expected_chunk:
                    break
                consumed += len(expected_chunk)
                if consumed > maximum:
                    fail(f"{label} exceeds its byte bound")
                digest.update(expected_chunk)
        after = os.fstat(descriptor)
        named = os.stat(expected_path, follow_symlinks=False)
        identity = lambda item: (item.st_dev, item.st_ino, item.st_mode, item.st_nlink, item.st_size, item.st_mtime_ns)
        if consumed != before.st_size or consumed != info.file_size or identity(before) != identity(after) or identity(before) != identity(named):
            fail(f"expected {label} changed while compared")
        return {"sha256": digest.hexdigest(), "byteCount": consumed}
    finally:
        os.close(descriptor)


def seal_package(
    package_path: Path,
    primary_ipa: Path,
    equivalence_path: Path,
    primary_manifest_path: Path,
    reproduction_manifest_path: Path,
    qualification_receipt_path: Path,
    qualification_signature_path: Path,
) -> dict[str, Any]:
    ipa_identity = checked_digest(primary_ipa, MAX_IPA_BYTES, "primary candidate IPA")
    equivalence_raw, equivalence_identity = package_attachment(equivalence_path, MAX_JSON_BYTES, "equivalence receipt")
    equivalence = parse_equivalence_receipt(equivalence_raw)
    if equivalence["primary"]["ipaSha256"] != ipa_identity["sha256"]:
        fail("equivalence receipt does not qualify the immutable primary candidate")
    primary_raw, primary_identity = package_attachment(primary_manifest_path, MAX_JSON_BYTES, "primary build manifest")
    reproduction_raw, reproduction_identity = package_attachment(reproduction_manifest_path, MAX_JSON_BYTES, "reproduction build manifest")
    primary_manifest = parse_build_manifest(primary_raw, "primary build manifest")
    reproduction_manifest = parse_build_manifest(reproduction_raw, "reproduction build manifest")
    if equivalence["primary"]["buildManifestSha256"] != primary_identity["sha256"] or equivalence["reproduction"]["buildManifestSha256"] != reproduction_identity["sha256"]:
        fail("equivalence receipt does not bind both build manifests")
    for key in ("buildNumber", "appStoreBuildNumberLowerBound"):
        if (
            equivalence[key] != primary_manifest[key]
            or equivalence[key] != reproduction_manifest[key]
        ):
            fail(f"equivalence receipt does not bind both build manifests' {key}")
    reproduction_ipa = absolute_path(
        reproduction_manifest["ipa"]["path"],
        "reproduction IPA",
    )
    verify_manifest_files(primary_manifest, "primary seal recheck", primary_ipa)
    verify_manifest_files(
        reproduction_manifest,
        "reproduction seal recheck",
        reproduction_ipa,
    )
    signing_raw, signing_receipt = signing_receipt_for_manifest(
        primary_manifest,
        "primary seal recheck",
    )
    reproduction_signing_raw, _ = signing_receipt_for_manifest(
        reproduction_manifest,
        "reproduction seal recheck",
    )
    signing_identity = {
        "sha256": sha256_bytes(signing_raw),
        "byteCount": len(signing_raw),
    }
    if (
        signing_raw != reproduction_signing_raw
        or signing_receipt["sourceRevision"] != equivalence["sourceRevision"]
        or signing_identity
        != {
            key: equivalence["signingIdentityReceipt"][key]
            for key in ("sha256", "byteCount")
        }
    ):
        fail("authenticated signing receipt differs from the qualified release")
    vendored_raw, vendored_receipt = vendored_receipt_for_manifest(
        primary_manifest,
        "primary seal recheck",
    )
    reproduction_vendored_raw, _ = vendored_receipt_for_manifest(
        reproduction_manifest,
        "reproduction seal recheck",
    )
    vendored_identity = {
        "sha256": sha256_bytes(vendored_raw),
        "byteCount": len(vendored_raw),
    }
    if (
        vendored_raw != reproduction_vendored_raw
        or vendored_receipt["sourceRevision"] != equivalence["sourceRevision"]
        or vendored_identity
        != {
            key: equivalence["vendoredBinaryReceipt"][key]
            for key in ("sha256", "byteCount")
        }
    ):
        fail(
            "authenticated vendored-binary receipt differs from the qualified release"
        )
    for key, label in (
        ("checkoutIdentity", "checkout"),
        ("derivedDataIdentity", "DerivedData"),
        ("archiveIdentity", "archive"),
        ("exportIdentity", "export"),
    ):
        distinct_physical(primary_manifest[key], reproduction_manifest[key], label)
    qualification_raw, qualification_identity = package_attachment(qualification_receipt_path, MAX_JSON_BYTES, "signed qualification receipt")
    qualification = parse_canonical_json(qualification_raw, "signed qualification receipt")
    if qualification.get("schemaVersion") != 8 or qualification.get("contractId") != "sora-ios-wallet-migration-qualification-v8" or qualification.get("status") != "qualified":
        fail("package requires one admitted-shape signed qualification receipt v8")
    qualification_signature_raw, qualification_signature_identity = package_attachment(qualification_signature_path, MAX_SIGNATURE_BYTES, "qualification receipt signature")
    attachments: dict[str, bytes] = {
        "equivalence-receipt.json": equivalence_raw,
        "qualification-receipt.json": qualification_raw,
        "qualification-receipt.sig": qualification_signature_raw,
        "signing-identity-receipt.json": signing_raw,
        "vendored-binary-qualification-receipt.json": vendored_raw,
        "primary-build-manifest.json": primary_raw,
        "reproduction-build-manifest.json": reproduction_raw,
    }
    attachment_paths: dict[str, tuple[Path, int, str]] = {
        "candidate.ipa": (primary_ipa, MAX_IPA_BYTES, "primary candidate IPA"),
    }
    manifest_records = {
        "candidate.ipa": ipa_identity,
        "equivalence-receipt.json": equivalence_identity,
        "qualification-receipt.json": qualification_identity,
        "qualification-receipt.sig": qualification_signature_identity,
        "signing-identity-receipt.json": signing_identity,
        "vendored-binary-qualification-receipt.json": vendored_identity,
        "primary-build-manifest.json": primary_identity,
        "reproduction-build-manifest.json": reproduction_identity,
    }
    for role, build in (("primary", primary_manifest), ("reproduction", reproduction_manifest)):
        for log_name in ("archive", "export"):
            member = f"{role}-{log_name}.log"
            source = absolute_path(build["logs"][log_name]["path"], f"{role} {log_name} log")
            identity = checked_digest(source, MAX_LOG_BYTES, f"{role} {log_name} log")
            if identity != {key: build["logs"][log_name][key] for key in ("sha256", "byteCount")}:
                fail(f"{role} {log_name} log changed after comparison")
            attachment_paths[member] = (source, MAX_LOG_BYTES, f"{role} {log_name} log")
            manifest_records[member] = identity
        for kind, key in (("archive", "archiveContentManifest"), ("export", "exportContentManifest")):
            member = f"{role}-{kind}-content-manifest.json"
            source = absolute_path(build[key]["path"], f"{role} {kind} content manifest")
            raw, identity = package_attachment(source, MAX_JSON_BYTES, f"{role} {kind} content manifest")
            if identity != {name: build[key][name] for name in ("sha256", "byteCount")}:
                fail(f"{role} {kind} content manifest changed after comparison")
            attachments[member] = raw
            manifest_records[member] = identity
    for index, dependency in enumerate(primary_manifest["dependencyManifests"]):
        member = f"dependencies/{index + 1:02d}-{Path(dependency['path']).name}"
        source = (
            absolute_path(
                primary_manifest["checkoutIdentity"]["path"],
                "primary checkout",
            )
            / dependency["path"]
        )
        raw, identity = package_attachment(source, MAX_JSON_BYTES, f"dependency {dependency['path']}")
        if identity != {key: dependency[key] for key in ("sha256", "byteCount")}:
            fail("repository dependency manifest differs from qualified clean build identity")
        attachments[member] = raw
        manifest_records[member] = identity
    package_manifest = {
        "format": PACKAGE_FORMAT,
        "status": "sealed-qualified-candidate",
        "releaseAuthorized": False,
        "uploadAuthorized": False,
        "primaryCandidateImmutable": True,
        "sourceRevision": equivalence["sourceRevision"],
        "buildNumber": equivalence["buildNumber"],
        "appStoreBuildNumberLowerBound":
            equivalence["appStoreBuildNumberLowerBound"],
        "qualificationReceiptSha256": qualification_identity["sha256"],
        "signingIdentityReceiptSha256": signing_identity["sha256"],
        "vendoredBinaryReceiptSha256": vendored_identity["sha256"],
        "tairaDeploymentManifestSha256":
            equivalence["tairaDeployment"]["manifestSha256"],
        "tairaDeploymentAdmissionSha256":
            equivalence["tairaDeployment"]["admissionSha256"],
        "equivalencePolicy": equivalence["equivalencePolicy"],
        "exactIpaByteEquality": equivalence["exactIpaByteEquality"],
        "members": {name: manifest_records[name] for name in sorted(manifest_records)},
    }
    manifest_raw = canonical_json(package_manifest)
    attachments["package-manifest.json"] = manifest_raw
    package_path = absolute_path(str(package_path), "qualified IPA package")
    parent_metadata = os.stat(package_path.parent, follow_symlinks=False)
    if not stat.S_ISDIR(parent_metadata.st_mode) or parent_metadata.st_uid != os.getuid() or stat.S_IMODE(parent_metadata.st_mode) != 0o700:
        fail("qualified IPA package parent must be current-user-owned mode 0700")
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    descriptor = os.open(package_path, flags, 0o600)
    created_metadata = os.fstat(descriptor)
    completed = False
    try:
        try:
            with os.fdopen(descriptor, "w+b", closefd=False) as output, zipfile.ZipFile(output, "w", allowZip64=True) as archive:
                for name in sorted(set(attachments) | set(attachment_paths)):
                    if name in attachment_paths:
                        path, maximum, label = attachment_paths[name]
                        write_path_member(
                            archive,
                            name,
                            path,
                            manifest_records[name],
                            maximum,
                            label,
                            stored=name == "candidate.ipa",
                        )
                    else:
                        archive.writestr(zip_member_info(name), attachments[name])
                output.flush()
                os.fsync(output.fileno())
        finally:
            os.close(descriptor)
        verify_package(package_path, primary_ipa, qualification_identity["sha256"], qualification_signature_path)
        completed = True
        return package_manifest
    finally:
        if not completed:
            try:
                current = os.stat(package_path, follow_symlinks=False)
            except FileNotFoundError:
                current = None
            if current is not None:
                identity = lambda item: (item.st_dev, item.st_ino, item.st_mode)
                if identity(current) != identity(created_metadata):
                    fail("failed package output was rebound and cannot be withdrawn safely")
                os.unlink(package_path)


def verify_package(package_path: Path, expected_ipa: Path, expected_qualification_sha: str, expected_signature: Path) -> dict[str, Any]:
    require_sha256(expected_qualification_sha, "expected qualification receipt")
    package_path = absolute_path(str(package_path), "downloaded qualified IPA package")
    parent_metadata = os.stat(package_path.parent, follow_symlinks=False)
    if (
        not stat.S_ISDIR(parent_metadata.st_mode)
        or parent_metadata.st_uid != os.getuid()
        or stat.S_IMODE(parent_metadata.st_mode) != 0o700
    ):
        fail("downloaded qualified IPA package parent must be current-user-owned mode 0700")
    flags = os.O_RDONLY | os.O_NOFOLLOW
    if hasattr(os, "O_CLOEXEC"):
        flags |= os.O_CLOEXEC
    try:
        descriptor = os.open(package_path, flags)
    except OSError as error:
        fail(f"downloaded qualified IPA package cannot be opened without aliases: {error}")
    try:
        package_metadata = os.fstat(descriptor)
        if (
            not stat.S_ISREG(package_metadata.st_mode)
            or package_metadata.st_nlink != 1
            or package_metadata.st_uid != os.getuid()
            or stat.S_IMODE(package_metadata.st_mode) != 0o600
            or package_metadata.st_size <= 0
            or package_metadata.st_size > MAX_IPA_BYTES + 1024 * 1024 * 1024
        ):
            fail("downloaded qualified IPA package is not one bounded owner-only regular inode")
        with os.fdopen(os.dup(descriptor), "rb") as source, zipfile.ZipFile(source, "r", allowZip64=True) as archive:
            if archive.comment != b"":
                fail("qualified IPA package contains an unauthenticated ZIP comment")
            infos = archive.infolist()
            if len(infos) != len(PACKAGE_MEMBERS) or len(infos) > MAX_PACKAGE_MEMBERS:
                fail("qualified IPA package member count is not exact")
            names = [item.filename for item in infos]
            if len(names) != len(set(names)) or set(names) != set(PACKAGE_MEMBERS):
                fail("qualified IPA package has a missing, duplicate, or unexpected member")
            by_name: dict[str, zipfile.ZipInfo] = {}
            aggregate_uncompressed = 0
            header_offsets: set[int] = set()
            for info in infos:
                path = PurePosixPath(info.filename)
                mode = (info.external_attr >> 16) & 0xFFFF
                if path.is_absolute() or any(part in ("", ".", "..") for part in path.parts) or SAFE_RELATIVE_RE.fullmatch(info.filename) is None:
                    fail("qualified IPA package contains an unsafe member path")
                aggregate_uncompressed += info.file_size
                if aggregate_uncompressed > MAX_IPA_BYTES + 1024 * 1024 * 1024:
                    fail("qualified IPA package has an excessive uncompressed inventory")
                if info.header_offset < 0 or info.header_offset in header_offsets:
                    fail("qualified IPA package has an overlapping header inventory")
                header_offsets.add(info.header_offset)
                if (
                    info.is_dir()
                    or info.flag_bits & 0x1
                    or info.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED)
                    or (info.filename == "candidate.ipa" and info.compress_type != zipfile.ZIP_STORED)
                    or not stat.S_ISREG(mode)
                    or stat.S_IMODE(mode) != 0o600
                ):
                    fail("qualified IPA package contains a non-regular, alias-capable, or non-owner-only member")
                by_name[info.filename] = info
            manifest_info = by_name["package-manifest.json"]
            if manifest_info.file_size <= 0 or manifest_info.file_size > MAX_JSON_BYTES:
                fail("package manifest exceeds its fixed bound")
            manifest_raw = archive.read(manifest_info)
            manifest = parse_canonical_json(manifest_raw, "package manifest")
            require_exact_keys(manifest, {"format", "status", "releaseAuthorized", "uploadAuthorized", "primaryCandidateImmutable", "sourceRevision", "buildNumber", "appStoreBuildNumberLowerBound", "qualificationReceiptSha256", "signingIdentityReceiptSha256", "vendoredBinaryReceiptSha256", "tairaDeploymentManifestSha256", "tairaDeploymentAdmissionSha256", "equivalencePolicy", "exactIpaByteEquality", "members"}, "package manifest")
            if manifest["format"] != PACKAGE_FORMAT or manifest["status"] != "sealed-qualified-candidate" or manifest["releaseAuthorized"] is not False or manifest["uploadAuthorized"] is not False or manifest["primaryCandidateImmutable"] is not True:
                fail("package manifest has an authorizing, stale, or incomplete contract")
            require_sha256(
                manifest["tairaDeploymentManifestSha256"],
                "package Taira deployment manifest",
            )
            require_sha256(
                manifest["tairaDeploymentAdmissionSha256"],
                "package Taira deployment admission",
            )
            require_sha256(
                manifest["signingIdentityReceiptSha256"],
                "package signing-identity receipt",
            )
            require_sha256(
                manifest["vendoredBinaryReceiptSha256"],
                "package vendored-binary receipt",
            )
            require_build_number(manifest["buildNumber"], "package build number")
            require_build_number(
                manifest["appStoreBuildNumberLowerBound"],
                "package App Store build-number lower bound",
            )
            if int(manifest["buildNumber"]) <= int(manifest["appStoreBuildNumberLowerBound"]):
                fail("package build number is not newer than its App Store lower bound")
            members = manifest["members"]
            if type(members) is not dict or set(members) != set(PACKAGE_MEMBERS) - {"package-manifest.json"}:
                fail("package manifest attachment inventory is not exact")
            maxima = {name: MAX_JSON_BYTES for name in members}
            maxima["candidate.ipa"] = MAX_IPA_BYTES
            for name in ("primary-archive.log", "primary-export.log", "reproduction-archive.log", "reproduction-export.log"):
                maxima[name] = MAX_LOG_BYTES
            maxima["qualification-receipt.sig"] = MAX_SIGNATURE_BYTES
            for name, identity in members.items():
                parse_file_digest(identity, f"package member {name}", require_path=False)
                observed = hash_zip_member(archive, by_name[name], maxima[name], f"package member {name}")
                if observed != identity:
                    fail(f"downloaded package member changed: {name}")
            equivalence_info = by_name["equivalence-receipt.json"]
            if equivalence_info.file_size <= 0 or equivalence_info.file_size > MAX_JSON_BYTES:
                fail("packaged equivalence receipt exceeds its fixed bound")
            equivalence = parse_equivalence_receipt(archive.read(equivalence_info))
            signing_info = by_name["signing-identity-receipt.json"]
            if signing_info.file_size <= 0 or signing_info.file_size > MAX_JSON_BYTES:
                fail("packaged signing-identity receipt exceeds its fixed bound")
            signing_raw = archive.read(signing_info)
            signing_receipt = parse_signing_identity_receipt(
                signing_raw,
                "packaged signing-identity receipt",
            )
            vendored_info = by_name[
                "vendored-binary-qualification-receipt.json"
            ]
            if vendored_info.file_size <= 0 or vendored_info.file_size > MAX_JSON_BYTES:
                fail("packaged vendored-binary receipt exceeds its fixed bound")
            vendored_raw = archive.read(vendored_info)
            vendored_receipt = parse_vendored_binary_receipt(
                vendored_raw,
                "packaged vendored-binary receipt",
            )
            if (
                equivalence["equivalencePolicy"] != manifest["equivalencePolicy"]
                or equivalence["exactIpaByteEquality"]
                is not manifest["exactIpaByteEquality"]
                or equivalence["sourceRevision"] != manifest["sourceRevision"]
                or equivalence["buildNumber"] != manifest["buildNumber"]
                or equivalence["appStoreBuildNumberLowerBound"]
                != manifest["appStoreBuildNumberLowerBound"]
                or equivalence["primary"]["ipaSha256"]
                != members["candidate.ipa"]["sha256"]
                or equivalence["primary"]["ipaByteCount"]
                != members["candidate.ipa"]["byteCount"]
                or equivalence["primary"]["buildManifestSha256"]
                != members["primary-build-manifest.json"]["sha256"]
                or equivalence["reproduction"]["buildManifestSha256"]
                != members["reproduction-build-manifest.json"]["sha256"]
                or equivalence["tairaDeployment"]["manifestSha256"]
                != manifest["tairaDeploymentManifestSha256"]
                or equivalence["tairaDeployment"]["admissionSha256"]
                != manifest["tairaDeploymentAdmissionSha256"]
                or sha256_bytes(signing_raw)
                != manifest["signingIdentityReceiptSha256"]
                or equivalence["signingIdentityReceipt"]["sha256"]
                != manifest["signingIdentityReceiptSha256"]
                or equivalence["signingIdentityReceipt"]["byteCount"]
                != len(signing_raw)
                or signing_receipt["sourceRevision"] != manifest["sourceRevision"]
                or sha256_bytes(vendored_raw)
                != manifest["vendoredBinaryReceiptSha256"]
                or equivalence["vendoredBinaryReceipt"]["sha256"]
                != manifest["vendoredBinaryReceiptSha256"]
                or equivalence["vendoredBinaryReceipt"]["byteCount"]
                != len(vendored_raw)
                or vendored_receipt["sourceRevision"]
                != manifest["sourceRevision"]
            ):
                fail("package manifest differs from its equivalence receipt")
            for role in ("primary", "reproduction"):
                for kind, equivalence_key, suffix in (
                    ("archive", "archiveLogSha256", "archive.log"),
                    ("export", "exportLogSha256", "export.log"),
                    (
                        "archive content",
                        "archiveContentManifestSha256",
                        "archive-content-manifest.json",
                    ),
                    (
                        "export content",
                        "exportContentManifestSha256",
                        "export-content-manifest.json",
                    ),
                ):
                    member_name = f"{role}-{suffix}"
                    if equivalence[role][equivalence_key] != members[member_name]["sha256"]:
                        fail(f"package {role} {kind} differs from its equivalence receipt")
            for index, dependency in enumerate(equivalence["dependencyManifests"]):
                member_name = f"dependencies/{index + 1:02d}-{Path(dependency['path']).name}"
                if (
                    dependency["sha256"] != members[member_name]["sha256"]
                    or dependency["byteCount"] != members[member_name]["byteCount"]
                ):
                    fail("packaged dependency differs from its equivalence receipt")
            candidate_identity = compare_zip_member_to_file(
                archive,
                by_name["candidate.ipa"],
                expected_ipa,
                MAX_IPA_BYTES,
                "immutable primary IPA",
            )
            if candidate_identity != members["candidate.ipa"]:
                fail("package candidate identity differs from its manifest")
            qualification_identity = hash_zip_member(
                archive,
                by_name["qualification-receipt.json"],
                MAX_JSON_BYTES,
                "qualification receipt",
            )
            if qualification_identity["sha256"] != expected_qualification_sha or manifest["qualificationReceiptSha256"] != expected_qualification_sha:
                fail("downloaded package does not bind the admitted qualification receipt")
            signature_identity = compare_zip_member_to_file(
                archive,
                by_name["qualification-receipt.sig"],
                expected_signature,
                MAX_SIGNATURE_BYTES,
                "qualification signature",
            )
            if signature_identity != members["qualification-receipt.sig"]:
                fail("package qualification signature differs from its manifest")
    except (OSError, zipfile.BadZipFile, zipfile.LargeZipFile) as error:
        fail(f"qualified IPA package is not a bounded ZIP: {error}")
    else:
        after = os.fstat(descriptor)
        named = os.stat(package_path, follow_symlinks=False)
        identity = lambda item: (item.st_dev, item.st_ino, item.st_mode, item.st_nlink, item.st_size, item.st_mtime_ns)
        if identity(package_metadata) != identity(after) or identity(package_metadata) != identity(named):
            fail("downloaded qualified IPA package changed during verification")
        return manifest
    finally:
        os.close(descriptor)


def lint_contract() -> None:
    if len(DEPENDENCY_PATHS) != 6 or len(set(DEPENDENCY_PATHS)) != 6:
        fail("Release package must bind exactly six dependency manifests")
    for source in (
        PROJECTOR_PATH,
        CONTROLLER_PATH,
        SIGNING_BLOCKED,
        SIGNING_VERIFIER,
        SIGNING_TESTS,
        VENDORED_BLOCKED,
        VENDORED_VERIFIER,
        VENDORED_TESTS,
    ):
        if not source.is_file() or source.is_symlink():
            fail(f"Release package source input is missing or symbolic: {source}")
    if "candidate.ipa" not in PACKAGE_MEMBERS or len(PACKAGE_MEMBERS) != len(set(PACKAGE_MEMBERS)):
        fail("Release package inventory is not exact")


def main(argv: list[str]) -> int:
    try:
        if argv == ["--lint-contract"]:
            lint_contract()
            print("iOS Release reproduction/package contract: OK")
            return 0
        if len(argv) == 31 and argv[0] == "--capture-build-manifest":
            expected = ("--role", "--repository", "--derived-data", "--archive", "--export", "--ipa", "--archive-log", "--export-log", "--qualification-contract-sha", "--signing-receipt", "--signing-receipt-sha", "--vendored-receipt-sha", "--build-number", "--app-store-build-lower-bound", "--output")
            if tuple(argv[index] for index in range(1, 30, 2)) != expected:
                fail("capture-build-manifest arguments are not exact")
            result = capture_build_manifest(
                role=argv[2], repository=absolute_path(argv[4], "repository"),
                derived_data=absolute_path(argv[6], "DerivedData"), archive=absolute_path(argv[8], "archive"),
                export=absolute_path(argv[10], "export"), ipa=absolute_path(argv[12], "IPA"),
                archive_log=absolute_path(argv[14], "archive log"), export_log=absolute_path(argv[16], "export log"),
                qualification_contract_sha=argv[18],
                signing_receipt_path=absolute_path(argv[20], "signing receipt"),
                signing_receipt_sha=argv[22],
                vendored_receipt_sha=argv[24],
                build_number=argv[26],
                app_store_build_lower_bound=argv[28],
                output=absolute_path(argv[30], "build manifest"),
            )
            print(f"buildManifestSha256={sha256_bytes(canonical_json(result))}")
            return 0
        if len(argv) == 11 and argv[0] == "--compare":
            expected = ("--primary-ipa", "--reproduction-ipa", "--primary-build-manifest", "--reproduction-build-manifest", "--output")
            if tuple(argv[index] for index in range(1, 10, 2)) != expected:
                fail("compare arguments are not exact")
            result = compare_releases(*(absolute_path(argv[index], expected[(index - 2) // 2]) for index in (2, 4, 6, 8, 10)))
            print(f"equivalenceReceiptSha256={sha256_bytes(canonical_json(result))} policy={result['equivalencePolicy']}")
            return 0
        if len(argv) == 15 and argv[0] == "--seal":
            expected = ("--package", "--primary-ipa", "--equivalence-receipt", "--primary-build-manifest", "--reproduction-build-manifest", "--qualification-receipt", "--qualification-signature")
            if tuple(argv[index] for index in range(1, 14, 2)) != expected:
                fail("seal arguments are not exact")
            result = seal_package(*(absolute_path(argv[index], expected[(index - 2) // 2]) for index in range(2, 15, 2)))
            print(f"packageManifestSha256={sha256_bytes(canonical_json(result))}")
            return 0
        if len(argv) == 9 and argv[0] == "--verify-download":
            if tuple(argv[index] for index in (1, 3, 5, 7)) != ("--package", "--expected-primary-ipa", "--expected-qualification-receipt", "--expected-qualification-signature"):
                fail("verify-download arguments are not exact")
            expected_receipt_path = absolute_path(argv[6], "qualification receipt")
            expected_receipt_raw, _ = open_regular(
                expected_receipt_path,
                MAX_JSON_BYTES,
                "expected qualification receipt",
            )
            expected_receipt = parse_canonical_json(
                expected_receipt_raw,
                "expected qualification receipt",
            )
            if (
                expected_receipt.get("schemaVersion") != 8
                or expected_receipt.get("contractId")
                != "sora-ios-wallet-migration-qualification-v8"
                or expected_receipt.get("status") != "qualified"
            ):
                fail("download verification requires one qualification receipt v8")
            expected_receipt_sha = sha256_bytes(expected_receipt_raw)
            result = verify_package(absolute_path(argv[2], "package"), absolute_path(argv[4], "primary IPA"), expected_receipt_sha, absolute_path(argv[8], "qualification signature"))
            print(
                f"candidateIpaSha256={result['members']['candidate.ipa']['sha256']} "
                f"qualificationReceiptSha256={expected_receipt_sha} "
                f"signingReceiptSha256={result['signingIdentityReceiptSha256']} "
                f"vendoredReceiptSha256={result['vendoredBinaryReceiptSha256']} "
                f"packageStatus={result['status']}"
            )
            return 0
        fail("usage: verify-ios-release-reproducibility-package.py --lint-contract | --capture-build-manifest ... | --compare ... | --seal ... | --verify-download ...")
    except (ReleaseReproducibilityError, OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
