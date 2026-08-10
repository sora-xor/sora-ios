#!/usr/bin/env python3
"""Hash and recheck the exact iOS migration qualification source contract."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import sys
from pathlib import Path, PurePosixPath
from typing import Any, Optional


MANIFEST_RELATIVE_PATH = PurePosixPath(
    "Fixtures/Modernization/ios-migration-qualification-contract-v1.json"
)
MAX_MANIFEST_BYTES = 1024 * 1024
MAX_CONTRACT_FILE_BYTES = 256 * 1024 * 1024
MAX_CONTRACT_FILES = 256
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
COMPONENT_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 ._+()@-]{0,191}$")


class ContractError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise ContractError(message)


def duplicate_rejecting_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            fail(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def canonical_json(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode(
        "utf-8"
    )


def safe_relative_path(value: Any, label: str) -> PurePosixPath:
    if type(value) is not str or not value or "\\" in value or value.startswith("/"):
        fail(f"{label} is not a relative POSIX path")
    path = PurePosixPath(value)
    if (
        path.as_posix() != value
        or any(
            component in ("", ".", "..") or COMPONENT_RE.fullmatch(component) is None
            for component in path.parts
        )
    ):
        fail(f"{label} contains an unsafe component")
    return path


def open_root(root: Path) -> int:
    if not root.is_absolute() or root == Path("/"):
        fail("repository root must be an absolute non-root directory")
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open("/", flags)
    try:
        for component in root.parts[1:]:
            if component in ("", ".", ".."):
                fail("repository root contains an unsafe component")
            child = os.open(component, flags, dir_fd=descriptor)
            metadata = os.fstat(child)
            if not stat.S_ISDIR(metadata.st_mode):
                os.close(child)
                fail("repository root traverses a non-directory component")
            os.close(descriptor)
            descriptor = child
        return descriptor
    except OSError as error:
        os.close(descriptor)
        fail(f"repository root cannot be opened without aliases: {error}")
    except Exception:
        os.close(descriptor)
        raise


def open_regular_at(root_descriptor: int, relative: PurePosixPath, label: str) -> int:
    descriptor = os.dup(root_descriptor)
    try:
        for component in relative.parts[:-1]:
            child = os.open(
                component,
                os.O_RDONLY
                | getattr(os, "O_DIRECTORY", 0)
                | getattr(os, "O_NOFOLLOW", 0),
                dir_fd=descriptor,
            )
            metadata = os.fstat(child)
            if not stat.S_ISDIR(metadata.st_mode):
                os.close(child)
                fail(f"{label} traverses a non-directory component")
            os.close(descriptor)
            descriptor = child
        leaf = os.open(
            relative.parts[-1],
            os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0),
            dir_fd=descriptor,
        )
        metadata = os.fstat(leaf)
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
            os.close(leaf)
            fail(f"{label} is not a unique regular file")
        return leaf
    except OSError as error:
        fail(f"{label} cannot be opened without aliases: {error}")
    finally:
        os.close(descriptor)


def read_bounded(descriptor: int, maximum: int, label: str) -> bytes:
    before = os.fstat(descriptor)
    if before.st_size <= 0 or before.st_size > maximum:
        fail(f"{label} is empty or exceeds its byte bound")
    result = bytearray()
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
        fail(f"{label} changed while it was read")
    return bytes(result)


def hash_regular(descriptor: int, label: str) -> tuple[str, int]:
    before = os.fstat(descriptor)
    if before.st_size <= 0 or before.st_size > MAX_CONTRACT_FILE_BYTES:
        fail(f"{label} is empty or exceeds its byte bound")
    digest = hashlib.sha256()
    total = 0
    while True:
        chunk = os.read(descriptor, 1024 * 1024)
        if not chunk:
            break
        digest.update(chunk)
        total += len(chunk)
        if total > MAX_CONTRACT_FILE_BYTES:
            fail(f"{label} exceeds its byte bound")
    after = os.fstat(descriptor)
    if (
        total != before.st_size
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
        fail(f"{label} changed while hashing")
    return digest.hexdigest(), total


def load_manifest(
    root_descriptor: int,
) -> tuple[list[PurePosixPath], str, int]:
    descriptor = open_regular_at(
        root_descriptor, MANIFEST_RELATIVE_PATH, "qualification contract manifest"
    )
    try:
        raw = read_bounded(descriptor, MAX_MANIFEST_BYTES, "qualification contract manifest")
    finally:
        os.close(descriptor)
    try:
        value = json.loads(
            raw.decode("utf-8", errors="strict"),
            object_pairs_hook=duplicate_rejecting_object,
            parse_constant=lambda token: fail(f"invalid JSON constant: {token}"),
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fail(f"qualification contract manifest is invalid JSON: {error}")
    if type(value) is not dict or set(value) != {
        "schemaVersion",
        "contractId",
        "platform",
        "paths",
    }:
        fail("qualification contract manifest has an unexpected root shape")
    if (
        type(value["schemaVersion"]) is not int
        or value["schemaVersion"] != 1
        or value["contractId"] != "sora-ios-wallet-migration-source-contract-v1"
        or value["platform"] != "ios"
        or type(value["paths"]) is not list
        or not value["paths"]
        or len(value["paths"]) > MAX_CONTRACT_FILES
    ):
        fail("qualification contract manifest is not exact v1")
    paths = [
        safe_relative_path(path, f"qualification contract paths[{index}]")
        for index, path in enumerate(value["paths"])
    ]
    if len(paths) != len(set(paths)) or paths[0] != MANIFEST_RELATIVE_PATH:
        fail("qualification contract paths are duplicated or not manifest-anchored")
    required = {
        MANIFEST_RELATIVE_PATH,
        PurePosixPath(
            "Fixtures/Modernization/ios-migration-collection-receipt.blocked.json"
        ),
        PurePosixPath(
            "Fixtures/Modernization/ios-migration-qualification.blocked.json"
        ),
        PurePosixPath(
            "Fixtures/Modernization/ios-migration-qualification-evidence.blocked.json"
        ),
        PurePosixPath(
            "Fixtures/Modernization/ios-migration-qualification-README.md"
        ),
        PurePosixPath(
            "Fixtures/Modernization/ios-production-signing-identity.json"
        ),
        PurePosixPath(
            "Fixtures/Modernization/ios-production-signing-identity-qualification.blocked.json"
        ),
        PurePosixPath(
            "Fixtures/Modernization/ios-production-signing-identity-qualification-trust.blocked.json"
        ),
        PurePosixPath(
            "Fixtures/Modernization/ios-production-signing-identity-qualification-README.md"
        ),
        PurePosixPath("Fixtures/Modernization/production-rollout-README.md"),
        PurePosixPath(
            "SoraPassport/Configs/ios-migration-candidate-export-options.plist"
        ),
        PurePosixPath("SoraPassport/Scripts/ios-migration-qualification-contract.py"),
        PurePosixPath("SoraPassport/Scripts/archive-ios-migration-candidate.sh"),
        PurePosixPath(
            "SoraPassport/Scripts/build-ios-migration-evidence-candidate.sh"
        ),
        PurePosixPath("SoraPassport/Scripts/collect-ios-migration-evidence.py"),
        PurePosixPath(
            "SoraPassport/Scripts/create-ios-migration-installable-clone.py"
        ),
        PurePosixPath(
            "SoraPassport/Scripts/create-ios-migration-candidate-handoff.py"
        ),
        PurePosixPath("SoraPassport/Scripts/run-ios-migration-evidence-collection.sh"),
        PurePosixPath(
            "SoraPassport/Scripts/run-ios-migration-exact-ipa-evidence.py"
        ),
        PurePosixPath(
            "SoraPassport/Scripts/sanitize-ios-migration-xctestrun.py"
        ),
        PurePosixPath(
            "SoraPassport/Scripts/test-ios-migration-exact-ipa-evidence.py"
        ),
        PurePosixPath(
            "SoraPassport/Scripts/test-ios-migration-evidence-collector.py"
        ),
        PurePosixPath(
            "SoraPassport/Scripts/test-ios-migration-installable-clone.py"
        ),
        PurePosixPath(
            "SoraPassport/Scripts/test-ios-migration-xctestrun-sanitizer.py"
        ),
        PurePosixPath("SoraPassport/Scripts/test-ios-migration-release-boundary.py"),
        PurePosixPath(
            "SoraPassport/Scripts/test-ios-production-signing-identity.py"
        ),
        PurePosixPath(
            "SoraPassport/Scripts/test-ios-release-reproducibility-package.py"
        ),
        PurePosixPath("SoraPassport/Scripts/verify-modernization-dependencies.sh"),
        PurePosixPath("SoraPassport/Scripts/verify-ios-migration-qualification.py"),
        PurePosixPath(
            "SoraPassport/Scripts/verify-ios-migration-promotion-ipa.sh"
        ),
        PurePosixPath(
            "SoraPassport/Scripts/verify-ios-production-signing-identity.py"
        ),
        PurePosixPath(
            "SoraPassport/Scripts/verify-ios-production-signing-identity.sh"
        ),
        PurePosixPath(
            "SoraPassport/Scripts/verify-ios-release-reproducibility-package.py"
        ),
        PurePosixPath("SoraPassport/Scripts/verify-production-rollout.sh"),
        PurePosixPath("Jenkinsfile.migration-evidence"),
        PurePosixPath(
            "SoraPassport.xcodeproj/xcshareddata/xcschemes/SoraPassportMigrationEvidence.xcscheme"
        ),
        PurePosixPath(
            "SoraPassport.xcodeproj/xcshareddata/xcschemes/SoraPassportMigrationEvidenceUI.xcscheme"
        ),
        PurePosixPath(
            "SoraPassport/Common/MigrationEvidence/RetainedMigrationEvidenceHarness.swift"
        ),
        PurePosixPath("SoraPassport/SoraPassport.entitlements"),
        PurePosixPath(
            "SoraPassportIntegrationTests/WalletMigrationRetainedDeviceEvidenceTests.swift"
        ),
        PurePosixPath(
            "SoraPassportUITests/RetainedMigrationEvidenceUITests.swift"
        ),
        PurePosixPath(
            "VendorPackages/shared-features-spm/Sources/SoraKeystore/Classes/Keychain/KeystoreProtocols.swift"
        ),
        PurePosixPath(
            "VendorPackages/shared-features-spm/Sources/SoraKeystore/Classes/Keychain/Keychain.swift"
        ),
    }
    if not required.issubset(paths):
        fail("qualification contract omits a required authority or collector input")
    return paths, hashlib.sha256(raw).hexdigest(), len(raw)


def calculate_contract(root: Path) -> tuple[str, list[dict[str, Any]]]:
    root_descriptor = open_root(root)
    try:
        paths, manifest_sha256, manifest_byte_count = load_manifest(root_descriptor)
        entries: list[dict[str, Any]] = []
        projection = hashlib.sha256()
        for path in paths:
            if path == MANIFEST_RELATIVE_PATH:
                digest, byte_count = manifest_sha256, manifest_byte_count
            else:
                descriptor = open_regular_at(
                    root_descriptor,
                    path,
                    f"qualification contract input {path.as_posix()}",
                )
                try:
                    digest, byte_count = hash_regular(
                        descriptor, f"qualification contract input {path.as_posix()}"
                    )
                finally:
                    os.close(descriptor)
            projection.update(path.as_posix().encode("utf-8"))
            projection.update(b"\0")
            projection.update(digest.encode("ascii"))
            projection.update(b"\0")
            entries.append(
                {"relativePath": path.as_posix(), "sha256": digest, "byteCount": byte_count}
            )
        return projection.hexdigest(), entries
    finally:
        os.close(root_descriptor)


def write_exclusive(path: Path, raw: bytes) -> None:
    if not path.is_absolute() or path == Path("/"):
        fail("contract snapshot path must be absolute and non-root")
    descriptor = os.open(
        path,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0),
        0o600,
    )
    try:
        offset = 0
        while offset < len(raw):
            offset += os.write(descriptor, raw[offset:])
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def load_snapshot(path: Path) -> dict[str, Any]:
    if not path.is_absolute() or path == Path("/"):
        fail("contract snapshot path must be absolute and non-root")
    descriptor = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
            fail("contract snapshot is not a unique regular file")
        raw = read_bounded(descriptor, MAX_MANIFEST_BYTES, "contract snapshot")
    finally:
        os.close(descriptor)
    try:
        value = json.loads(
            raw.decode("utf-8", errors="strict"),
            object_pairs_hook=duplicate_rejecting_object,
            parse_constant=lambda token: fail(f"invalid JSON constant: {token}"),
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fail(f"contract snapshot is invalid JSON: {error}")
    if type(value) is not dict or set(value) != {
        "schemaVersion",
        "contractId",
        "contractSha256",
        "entries",
    }:
        fail("contract snapshot has an unexpected root shape")
    if (
        type(value["schemaVersion"]) is not int
        or value["schemaVersion"] != 1
        or value["contractId"] != "sora-ios-wallet-migration-source-snapshot-v1"
        or type(value["contractSha256"]) is not str
        or SHA256_RE.fullmatch(value["contractSha256"]) is None
        or type(value["entries"]) is not list
    ):
        fail("contract snapshot is not exact v1")
    return value


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, required=True)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--print-sha", action="store_true")
    modes.add_argument("--snapshot", type=Path)
    modes.add_argument("--verify-snapshot", type=Path)
    parser.add_argument("--expected-sha")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    digest, entries = calculate_contract(args.repository_root)
    if args.print_sha:
        if args.expected_sha is not None:
            fail("--expected-sha is invalid with --print-sha")
    elif args.snapshot is not None:
        if args.expected_sha is not None:
            fail("--expected-sha is invalid with --snapshot")
        write_exclusive(
            args.snapshot,
            canonical_json(
                {
                    "schemaVersion": 1,
                    "contractId": "sora-ios-wallet-migration-source-snapshot-v1",
                    "contractSha256": digest,
                    "entries": entries,
                }
            ),
        )
    else:
        if args.expected_sha is None or SHA256_RE.fullmatch(args.expected_sha) is None:
            fail("--verify-snapshot requires an exact lowercase SHA-256")
        snapshot = load_snapshot(args.verify_snapshot)
        if (
            snapshot["contractSha256"] != args.expected_sha
            or digest != args.expected_sha
            or snapshot["entries"] != entries
        ):
            fail("qualification contract changed after its admission snapshot")
    print(digest)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except ContractError as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
