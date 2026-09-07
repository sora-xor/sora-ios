#!/usr/bin/env python3
"""Build non-authorizing, raw-bound iOS wallet-migration evidence.

This program deliberately cannot create a qualification receipt, trust root,
signature, key, or a JSON object whose status is ``qualified``.  It consumes a
completed retained-device run from an absolute protected directory and emits
only deterministic ``observed`` aggregates plus one
``collected-unreviewed`` receipt with ``releaseAuthorized: false``.
"""

from __future__ import annotations

import argparse
import base64
import ctypes
import errno
import hashlib
import json
import os
import plistlib
import re
import shutil
import sqlite3
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
from typing import Any, Iterable, Optional


ROOT = Path(__file__).resolve().parents[2]
MAX_JSON_BYTES = 4 * 1024 * 1024
MAX_TEXT_BYTES = 64 * 1024 * 1024
MAX_SETTINGS_BYTES = 16 * 1024 * 1024
MAX_IPA_BYTES = 1024 * 1024 * 1024
MAX_RAW_FILE_BYTES = 4 * 1024 * 1024 * 1024
MAX_RAW_FILES = 200_000
MAX_RAW_BYTES = 16 * 1024 * 1024 * 1024
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SHA1_RE = re.compile(r"^[0-9a-f]{40}$")
SOURCE_REVISION_RE = re.compile(r"^[0-9a-f]{40}$")
SAFE_COMPONENT_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9._+@-]{0,255}$")
SAFE_ID_RE = re.compile(r"^[a-z][a-z0-9-]{2,63}$")
SAFE_VERSION_RE = re.compile(r"^[0-9A-Za-z][0-9A-Za-z._-]{0,63}$")
FORBIDDEN_OUTPUT_KEY_PARTS = (
    "accountidentifier",
    "address",
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
SAFE_OUTPUT_AGGREGATE_KEYS = {
    "codesignaturedeepstrictverified",
    "productioncodesignatureverified",
    "successfulsecretsourcecohortcount",
    "secretfailurecohortcount",
}
SAFE_ENV = {
    "PATH": "/usr/bin:/bin",
    "LANG": "C",
    "LC_ALL": "C",
}
EXPECTED_SNAPSHOT_COHORTS = {
    "v1-single": ("UserDataModel", False),
    "v1-multi": ("UserDataModel", True),
    "v2-single": ("UserDataModel 2", False),
    "v2-multi": ("UserDataModel 2", True),
}
CORE_DATA_COMMON_SCHEMA = {
    "ZCDCONNECTIONITEM": {
        "Z_PK": ("INTEGER", True),
        "Z_ENT": ("INTEGER", False),
        "Z_OPT": ("INTEGER", False),
        "ZNETWORKTYPE": ("INTEGER", False),
        "ZORDER": ("INTEGER", False),
        "ZIDENTIFIER": ("TEXT", False),
        "ZTITLE": ("TEXT", False),
    },
    "Z_METADATA": {
        "Z_VERSION": ("INTEGER", True),
        "Z_UUID": ("TEXT", False),
        "Z_PLIST": ("BLOB", False),
    },
    "Z_PRIMARYKEY": {
        "Z_ENT": ("INTEGER", True),
        "Z_NAME": ("TEXT", False),
        "Z_SUPER": ("INTEGER", False),
        "Z_MAX": ("INTEGER", False),
    },
}
CORE_DATA_V1_ACCOUNT_SCHEMA = {
    "Z_PK": ("INTEGER", True),
    "Z_ENT": ("INTEGER", False),
    "Z_OPT": ("INTEGER", False),
    "ZCRYPTOTYPE": ("INTEGER", False),
    "ZNETWORKTYPE": ("INTEGER", False),
    "ZORDER": ("INTEGER", False),
    "ZIDENTIFIER": ("TEXT", False),
    "ZPUBLICKEY": ("BLOB", False),
    "ZUSERNAME": ("TEXT", False),
}
CORE_DATA_V2_ACCOUNT_SCHEMA = {
    **CORE_DATA_V1_ACCOUNT_SCHEMA,
    "ZISSELECTED": ("INTEGER", False),
    "ZSETTINGS": ("INTEGER", False),
}
CORE_DATA_V2_SETTINGS_SCHEMA = {
    "Z_PK": ("INTEGER", True),
    "Z_ENT": ("INTEGER", False),
    "Z_OPT": ("INTEGER", False),
    "ZFAVOURITEASSETS": ("BLOB", False),
    "ZLOCALE": ("TEXT", False),
    "ZORDEREDASSETS": ("BLOB", False),
    "ZVISIBLEASSETS": ("BLOB", False),
}
EXPECTED_KEYCHAIN_COHORTS = {
    "mnemonic-12": "success",
    "mnemonic-15-retained": "success",
    "mnemonic-18-retained": "success",
    "mnemonic-21-retained": "success",
    "iroha-v1-paired-keys": "success",
    "mnemonic-24": "success",
    "raw-seed": "success",
    "legacy-secret": "success",
    "watch-only": "success",
    "missing-secret": "recovery",
    "corrupt-secret": "recovery",
}
EXPECTED_DEVICE_SCENARIOS = {
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
EXPECTED_ATTACHMENT_PRODUCERS = {
    "ios-migration-run-binding-v3.json": "WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedDeviceRunBinding()",
    "ios-migration-keychain-observations-v3.json": "WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedKeychainCohortEvidence()",
    "ios-migration-device-events-v3.json": "WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedDeviceScenarioEvidence()",
}
EXPECTED_SCENARIO_ASSERTIONS = {
    "reinstall-upgrade": {
        "account-count-preserved",
        "selected-wallet-preserved",
        "keychain-identity-preserved",
        "legacy-store-retained",
    },
    "rollback": {
        "rollback-failed-closed",
        "live-store-preserved",
        "keychain-identity-preserved",
    },
    "low-storage": {
        "low-storage-failed-closed",
        "live-store-preserved",
        "recovery-evidence-retained",
    },
    "recovery-archive-export": {
        "archive-complete",
        "archive-protection-complete",
        "live-store-preserved",
    },
    "process-death-restart": {
        "journal-resumed",
        "no-mutation-retry",
        "selected-wallet-preserved",
    },
    "interruption-before-secret-retention": {"recovery-required", "no-live-store-loss"},
    "interruption-after-secret-retention": {"recovery-required", "keychain-bytes-preserved"},
    "interruption-after-core-data-commit": {"recovery-required", "core-data-commit-preserved"},
    "interruption-after-network-staging": {"recovery-required", "staged-network-not-activated"},
    "interruption-before-activation": {"recovery-required", "active-snapshot-unchanged"},
}
NONAUTHORIZING_BLOCKER = (
    "Observed collection only: independent review, protected trust pins, detached signatures, "
    "append-only sequence admission, and a schema-8 qualification receipt are absent."
)
DERIVATION_TOOL_RELATIVE = (
    "SoraPassport/Scripts/derive-ios-migration-test-host.py"
)
EXACT_CLONE_BINDING_KEYS = {
    "productionIpaSha256",
    "installedAppRawTreeSha256",
    "installedAppRawTreeRecordByteCount",
    "installedExecutableSha256",
    "installedExecutableByteCount",
    "productionCanonicalProjectionSha256",
    "installedCanonicalProjectionSha256",
    "canonicalProjectionReceiptSha256",
    "canonicalProjectorSourceSha256",
    "installedAppLaunchVerified",
    "installedRawTreeRecomputed",
    "installedExecutableRecomputed",
    "canonicalProjectionReceiptVerified",
    "canonicalProjectorSourceVerified",
    "canonicalProjectionEqualToProduction",
}
OUTPUT_NAMES = {
    "collection": "ios-migration-collection-receipt.json",
    "snapshots": "ios-migration-retained-snapshot-manifest.json",
    "tests": "ios-migration-tests.xcresult.zip",
    "keychain": "ios-migration-keychain-evidence.json",
    "device": "ios-migration-device-execution-evidence.json",
}
BLOCKED_COLLECTION_TEMPLATE = (
    ROOT / "Fixtures/Modernization/ios-migration-collection-receipt.blocked.json"
)


class CollectionError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise CollectionError(message)


def duplicate_rejecting_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            fail(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def validate_json_bounds(
    value: Any, label: str, depth: int = 0, allow_float: bool = False
) -> None:
    if depth > 32:
        fail(f"{label} exceeds the maximum JSON depth")
    if type(value) is dict:
        if len(value) > 1024:
            fail(f"{label} contains too many object fields")
        for key, child in value.items():
            if type(key) is not str or not key or len(key.encode("utf-8")) > 256:
                fail(f"{label} contains an invalid JSON key")
            validate_json_bounds(child, f"{label}.{key}", depth + 1, allow_float)
    elif type(value) is list:
        if len(value) > 200_000:
            fail(f"{label} contains too many array items")
        for index, child in enumerate(value):
            validate_json_bounds(child, f"{label}[{index}]", depth + 1, allow_float)
    elif type(value) is str:
        if len(value.encode("utf-8")) > 32_768:
            fail(f"{label} contains an oversized string")
    elif type(value) is int:
        if not (-9_999_999_999_999 <= value <= 9_999_999_999_999):
            fail(f"{label} contains an out-of-range integer")
    elif type(value) is float and not allow_float:
        fail(f"{label} contains an unsupported floating-point value")
    elif type(value) is float and (value != value or value in (float("inf"), float("-inf"))):
        fail(f"{label} contains a non-finite floating-point value")
    elif value is not None and type(value) not in (bool, int):
        fail(f"{label} contains an unsupported JSON value")


def load_json_bytes(raw: bytes, label: str) -> dict[str, Any]:
    if not raw or len(raw) > MAX_JSON_BYTES or raw.startswith(b"\xef\xbb\xbf"):
        fail(f"{label} has an invalid byte representation")
    try:
        value = json.loads(
            raw.decode("utf-8", errors="strict"),
            object_pairs_hook=duplicate_rejecting_object,
            parse_constant=lambda value: fail(
                f"{label} contains a non-finite number: {value}"
            ),
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fail(f"{label} is not strict JSON: {error}")
    if type(value) is not dict:
        fail(f"{label} must contain one JSON object")
    validate_json_bounds(value, label)
    return value


def load_tool_json_bytes(raw: bytes, label: str) -> dict[str, Any]:
    if not raw or len(raw) > 64 * 1024 * 1024 or raw.startswith(b"\xef\xbb\xbf"):
        fail(f"{label} has an invalid byte representation")
    try:
        value = json.loads(
            raw.decode("utf-8", errors="strict"),
            object_pairs_hook=duplicate_rejecting_object,
            parse_constant=lambda value: fail(
                f"{label} contains a non-finite number: {value}"
            ),
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fail(f"{label} is not strict JSON: {error}")
    if type(value) is not dict:
        fail(f"{label} must contain one JSON object")
    validate_json_bounds(value, label, allow_float=True)
    return value


def load_tool_json_value(raw: bytes, label: str) -> Any:
    if not raw or len(raw) > 64 * 1024 * 1024 or raw.startswith(b"\xef\xbb\xbf"):
        fail(f"{label} has an invalid byte representation")
    try:
        value = json.loads(
            raw.decode("utf-8", errors="strict"),
            object_pairs_hook=duplicate_rejecting_object,
            parse_constant=lambda value: fail(
                f"{label} contains a non-finite number: {value}"
            ),
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fail(f"{label} is not strict JSON: {error}")
    validate_json_bounds(value, label, allow_float=True)
    return value


def exact_keys(value: Any, expected: set[str], label: str) -> None:
    if type(value) is not dict or set(value) != expected:
        fail(f"{label} contains missing or unreviewed fields")


def exact_typed_equal(left: Any, right: Any) -> bool:
    if type(left) is not type(right):
        return False
    if type(left) is dict:
        return set(left) == set(right) and all(
            exact_typed_equal(left[key], right[key]) for key in left
        )
    if type(left) is list:
        return len(left) == len(right) and all(
            exact_typed_equal(left_value, right_value)
            for left_value, right_value in zip(left, right)
        )
    return left == right


def metadata_identity(value: os.stat_result) -> tuple[int, ...]:
    return (
        value.st_dev,
        value.st_ino,
        value.st_mode,
        value.st_uid,
        value.st_nlink,
        value.st_size,
        value.st_mtime_ns,
        value.st_ctime_ns,
    )


def positive_int(value: Any, label: str) -> int:
    if type(value) is not int or value <= 0:
        fail(f"{label} must be a positive integer")
    return value


def require_sha256(value: Any, label: str, expected: Optional[str] = None) -> str:
    if type(value) is not str or SHA256_RE.fullmatch(value) is None or value == "0" * 64:
        fail(f"{label} must be a nonzero lowercase SHA-256")
    if expected is not None and value != expected:
        fail(f"{label} differs from the opened bytes")
    return value


def canonical_json(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True) + "\n").encode("utf-8")


def pretty_json(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, indent=2, ensure_ascii=True) + "\n").encode("utf-8")


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def open_anchored_regular(
    root: Path, relative: PurePosixPath, label: str
) -> int:
    root_descriptor = open_anchored_directory(root, f"{label} root")
    descriptor = root_descriptor
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


def run_qualification_contract_tool(arguments: list[str]) -> str:
    relative = PurePosixPath(
        "SoraPassport/Scripts/ios-migration-qualification-contract.py"
    )
    descriptor = open_anchored_regular(ROOT, relative, "qualification contract tool")
    before = os.fstat(descriptor)
    try:
        result = subprocess.run(
            [
                "/usr/bin/python3",
                "-I",
                "-S",
                f"/dev/fd/{descriptor}",
                "--repository-root",
                str(ROOT),
                *arguments,
            ],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=SAFE_ENV,
            timeout=60,
            text=True,
            pass_fds=(descriptor,),
        )
    except (OSError, subprocess.SubprocessError) as error:
        fail(f"qualification source contract cannot be derived: {error}")
    finally:
        os.close(descriptor)
    recheck = open_anchored_regular(ROOT, relative, "qualification contract tool recheck")
    try:
        after = os.fstat(recheck)
    finally:
        os.close(recheck)
    if (
        after.st_dev,
        after.st_ino,
        after.st_size,
        after.st_mtime_ns,
        after.st_nlink,
    ) != (
        before.st_dev,
        before.st_ino,
        before.st_size,
        before.st_mtime_ns,
        before.st_nlink,
    ):
        fail("qualification contract tool changed while it was executing")
    digest = result.stdout.strip()
    if SHA256_RE.fullmatch(digest) is None:
        fail("qualification source contract tool returned an invalid digest")
    return digest


def ensure_absolute_noalias_directory(path: Path, label: str) -> Path:
    if not path.is_absolute():
        fail(f"{label} must be absolute")
    current = Path("/")
    for component in path.parts[1:]:
        if component in ("", ".", ".."):
            fail(f"{label} contains an unsafe component")
        current = current / component
        try:
            metadata = os.lstat(current)
        except OSError as error:
            fail(f"{label} cannot be inspected: {error}")
        if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISDIR(metadata.st_mode):
            fail(f"{label} traverses a symbolic or non-directory component")
    return path


def open_anchored_directory(path: Path, label: str) -> int:
    if not path.is_absolute() or path == Path("/"):
        fail(f"{label} must be an absolute non-root directory")
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open("/", flags)
    try:
        for component in path.parts[1:]:
            if component in ("", ".", ".."):
                fail(f"{label} contains an unsafe component")
            child = os.open(component, flags, dir_fd=descriptor)
            metadata = os.fstat(child)
            if not stat.S_ISDIR(metadata.st_mode):
                os.close(child)
                fail(f"{label} traverses a non-directory component")
            os.close(descriptor)
            descriptor = child
        return descriptor
    except Exception:
        os.close(descriptor)
        raise


def raw_tree_projection(entries: list[dict[str, Any]]) -> tuple[str, int, int]:
    ordered = sorted(entries, key=lambda value: value["relativePath"])
    projection = {
        "schemaVersion": 3,
        "contractId": "sora-ios-wallet-migration-raw-input-set-v3",
        "files": ordered,
    }
    return (
        sha256_bytes(canonical_json(projection)),
        len(ordered),
        sum(entry["size"] for entry in ordered),
    )


def snapshot_anchored_tree(
    source_root: Path, staging_parent: Path, label: str
) -> tuple[Path, list[dict[str, Any]], str]:
    source_descriptor = open_anchored_directory(source_root, label)
    staging = Path(
        tempfile.mkdtemp(prefix=".ios-migration-raw-snapshot-", dir=staging_parent)
    )
    os.chmod(staging, 0o700)
    seen_inodes: set[tuple[int, int]] = set()
    entries: list[dict[str, Any]] = []
    total = 0

    def copy_directory(source_fd: int, destination: Path, prefix: PurePosixPath) -> None:
        nonlocal total
        try:
            names = sorted(os.listdir(source_fd))
        except OSError as error:
            fail(f"{label} cannot be enumerated: {error}")
        for name in names:
            if SAFE_COMPONENT_RE.fullmatch(name) is None:
                fail(f"{label} contains an unsafe path component")
            try:
                metadata = os.stat(name, dir_fd=source_fd, follow_symlinks=False)
            except OSError as error:
                fail(f"{label} cannot inspect {name}: {error}")
            relative = prefix / name
            destination_path = destination / name
            if stat.S_ISLNK(metadata.st_mode):
                fail(f"{label} contains a symbolic link")
            if stat.S_ISDIR(metadata.st_mode):
                os.mkdir(destination_path, 0o700)
                child_fd = os.open(
                    name,
                    os.O_RDONLY
                    | getattr(os, "O_DIRECTORY", 0)
                    | getattr(os, "O_NOFOLLOW", 0),
                    dir_fd=source_fd,
                )
                try:
                    opened = os.fstat(child_fd)
                    if (opened.st_dev, opened.st_ino) != (
                        metadata.st_dev,
                        metadata.st_ino,
                    ):
                        fail(f"{label} directory changed during anchored open")
                    copy_directory(child_fd, destination_path, relative)
                finally:
                    os.close(child_fd)
                destination_fd = os.open(
                    destination_path,
                    os.O_RDONLY | getattr(os, "O_DIRECTORY", 0),
                )
                try:
                    os.fsync(destination_fd)
                finally:
                    os.close(destination_fd)
                continue
            if not stat.S_ISREG(metadata.st_mode):
                fail(f"{label} contains a special file")
            if metadata.st_size > MAX_RAW_FILE_BYTES or metadata.st_nlink != 1:
                fail(f"{label} contains an oversized or hard-linked file")
            identity = (metadata.st_dev, metadata.st_ino)
            if identity in seen_inodes:
                fail(f"{label} contains an inode alias")
            seen_inodes.add(identity)
            source_file = os.open(
                name,
                os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0),
                dir_fd=source_fd,
            )
            destination_file = os.open(
                destination_path,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0),
                0o700 if stat.S_IMODE(metadata.st_mode) & 0o111 else 0o600,
            )
            digest = hashlib.sha256()
            copied = 0
            try:
                before = os.fstat(source_file)
                if (
                    not stat.S_ISREG(before.st_mode)
                    or before.st_nlink != 1
                    or (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns)
                    != (
                        metadata.st_dev,
                        metadata.st_ino,
                        metadata.st_size,
                        metadata.st_mtime_ns,
                    )
                ):
                    fail(f"{label} file changed during anchored open")
                while True:
                    chunk = os.read(source_file, 1024 * 1024)
                    if not chunk:
                        break
                    copied += len(chunk)
                    total += len(chunk)
                    if total > MAX_RAW_BYTES:
                        fail(f"{label} exceeds the raw byte bound")
                    digest.update(chunk)
                    offset = 0
                    while offset < len(chunk):
                        offset += os.write(destination_file, chunk[offset:])
                os.fsync(destination_file)
                after = os.fstat(source_file)
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
                    fail(f"{label} file changed during snapshot")
            finally:
                os.close(source_file)
                os.close(destination_file)
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

    try:
        copy_directory(source_descriptor, staging, PurePosixPath())
    finally:
        os.close(source_descriptor)
    staging_fd = os.open(staging, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
    try:
        os.fsync(staging_fd)
    finally:
        os.close(staging_fd)
    digest, _, _ = raw_tree_projection(entries)
    return staging, sorted(entries, key=lambda value: value["relativePath"]), digest


def publish_directory_no_replace(partial: Path, final: Path) -> None:
    library = ctypes.CDLL(None, use_errno=True)
    renameatx_np = getattr(library, "renameatx_np", None)
    if renameatx_np is None:
        fail("atomic no-replace directory publication is unavailable")
    renameatx_np.argtypes = [
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_uint,
    ]
    renameatx_np.restype = ctypes.c_int
    at_fdcwd = -2
    rename_excl = 0x00000004
    result = renameatx_np(
        at_fdcwd,
        os.fsencode(partial),
        at_fdcwd,
        os.fsencode(final),
        rename_excl,
    )
    if result != 0:
        error = ctypes.get_errno()
        if error == errno.EEXIST:
            fail("output root appeared before no-replace publication")
        fail(f"atomic no-replace output publication failed: {os.strerror(error)}")


def create_exclusive_output(path: Path, input_root: Path) -> tuple[Path, Path]:
    if not path.is_absolute() or path == Path("/"):
        fail("output root must be an absolute non-root path")
    parent = ensure_absolute_noalias_directory(path.parent, "output parent")
    if input_root == path or input_root in path.parents or path in input_root.parents:
        fail("input and output roots must be disjoint")
    if ROOT == path or ROOT in path.parents or path in ROOT.parents:
        fail("raw migration evidence output must remain outside the repository")
    parent_metadata = os.lstat(parent)
    if parent_metadata.st_uid != os.getuid() or stat.S_IMODE(parent_metadata.st_mode) & 0o077:
        fail("output parent must be a private owner-only directory")
    try:
        os.lstat(path)
    except FileNotFoundError:
        pass
    else:
        fail("output root already exists; collection is append-only")
    partial = parent / f".{path.name}.partial-{uuid.uuid4()}"
    try:
        os.mkdir(partial, 0o700)
    except FileExistsError:
        fail("exclusive partial output namespace collided")
    except OSError as error:
        fail(f"cannot create partial output root: {error}")
    return ensure_absolute_noalias_directory(partial, "partial output root"), path


def safe_relative(value: Any, label: str) -> PurePosixPath:
    if type(value) is not str or not value or "\\" in value or value.startswith("/"):
        fail(f"{label} must be a relative POSIX path")
    path = PurePosixPath(value)
    if any(
        part in ("", ".", "..") or SAFE_COMPONENT_RE.fullmatch(part) is None
        for part in path.parts
    ):
        fail(f"{label} contains an unsafe path component")
    return path


def resolve_input(root: Path, value: Any, label: str) -> Path:
    relative = safe_relative(value, label)
    current = root
    for index, component in enumerate(relative.parts):
        current = current / component
        try:
            metadata = os.lstat(current)
        except OSError as error:
            fail(f"{label} cannot be inspected: {error}")
        if stat.S_ISLNK(metadata.st_mode):
            fail(f"{label} traverses a symbolic link")
        if index + 1 < len(relative.parts) and not stat.S_ISDIR(metadata.st_mode):
            fail(f"{label} traverses a non-directory component")
    return current


def read_regular(path: Path, maximum: int, label: str) -> bytes:
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    try:
        descriptor = os.open(path, flags)
    except OSError as error:
        fail(f"{label} cannot be opened: {error}")
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode) or before.st_size <= 0 or before.st_size > maximum:
            fail(f"{label} is not a bounded regular file")
        chunks: list[bytes] = []
        remaining = before.st_size
        while remaining:
            chunk = os.read(descriptor, min(1024 * 1024, remaining))
            if not chunk:
                fail(f"{label} ended before its declared size")
            chunks.append(chunk)
            remaining -= len(chunk)
        after = os.fstat(descriptor)
        if (
            before.st_dev,
            before.st_ino,
            before.st_size,
            before.st_mtime_ns,
        ) != (
            after.st_dev,
            after.st_ino,
            after.st_size,
            after.st_mtime_ns,
        ):
            fail(f"{label} changed while being read")
        return b"".join(chunks)
    finally:
        os.close(descriptor)


def hash_regular(path: Path, maximum: int, label: str) -> tuple[str, int]:
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    try:
        descriptor = os.open(path, flags)
    except OSError as error:
        fail(f"{label} cannot be opened: {error}")
    digest = hashlib.sha256()
    size = 0
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode) or before.st_size > maximum:
            fail(f"{label} is not a bounded regular file")
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
            before.st_dev,
            before.st_ino,
            before.st_size,
            before.st_mtime_ns,
            before.st_nlink,
        ) != (
            after.st_dev,
            after.st_ino,
            after.st_size,
            after.st_mtime_ns,
            after.st_nlink,
        ) or size != before.st_size:
            fail(f"{label} changed while being hashed")
        return digest.hexdigest(), size
    finally:
        os.close(descriptor)


def load_contract_source_entries(
    snapshot_path: Path, expected_contract_sha: str
) -> dict[str, tuple[str, int]]:
    snapshot = load_json_bytes(
        read_regular(
            snapshot_path,
            MAX_JSON_BYTES,
            "qualification source-contract snapshot",
        ),
        "qualification source-contract snapshot",
    )
    exact_keys(
        snapshot,
        {"schemaVersion", "contractId", "contractSha256", "entries"},
        "qualification source-contract snapshot",
    )
    if (
        type(snapshot["schemaVersion"]) is not int
        or snapshot["schemaVersion"] != 1
        or snapshot["contractId"]
        != "sora-ios-wallet-migration-source-snapshot-v1"
        or require_sha256(
            snapshot["contractSha256"],
            "qualification source-contract snapshot identity",
            expected_contract_sha,
        )
        != expected_contract_sha
        or type(snapshot["entries"]) is not list
        or not snapshot["entries"]
        or len(snapshot["entries"]) > 256
    ):
        fail("qualification source-contract snapshot is not exact v1")

    projection = hashlib.sha256()
    result: dict[str, tuple[str, int]] = {}
    for index, entry in enumerate(snapshot["entries"]):
        label = f"qualification source-contract snapshot.entries[{index}]"
        exact_keys(entry, {"relativePath", "sha256", "byteCount"}, label)
        relative_value = entry["relativePath"]
        relative = safe_relative(relative_value, f"{label}.relativePath")
        digest = require_sha256(entry["sha256"], f"{label}.sha256")
        byte_count = entry["byteCount"]
        if (
            relative.as_posix() != relative_value
            or relative_value in result
            or type(byte_count) is not int
            or not 0 < byte_count <= MAX_RAW_FILE_BYTES
        ):
            fail(f"{label} is not an exact unique bounded contract entry")
        projection.update(relative_value.encode("utf-8"))
        projection.update(b"\0")
        projection.update(digest.encode("ascii"))
        projection.update(b"\0")
        result[relative_value] = (digest, byte_count)
    if projection.hexdigest() != expected_contract_sha:
        fail("qualification source-contract snapshot projection is invalid")
    return result


def read_contract_bound_source(
    entries: dict[str, tuple[str, int]],
    relative_value: str,
    maximum: int,
    label: str,
) -> bytes:
    expected = entries.get(relative_value)
    if expected is None:
        fail(f"{label} is absent from the qualification source contract")
    expected_digest, expected_size = expected
    if expected_size > maximum:
        fail(f"{label} exceeds its point-of-use byte bound")
    relative = safe_relative(relative_value, label)
    descriptor = open_anchored_regular(ROOT, relative, label)
    digest = hashlib.sha256()
    result = bytearray()
    try:
        before = os.fstat(descriptor)
        if before.st_size != expected_size:
            fail(f"{label} differs from the admitted source-contract size")
        while True:
            chunk = os.read(descriptor, min(1024 * 1024, maximum - len(result) + 1))
            if not chunk:
                break
            result.extend(chunk)
            digest.update(chunk)
            if len(result) > maximum:
                fail(f"{label} exceeds its point-of-use byte bound")
        after = os.fstat(descriptor)
        if (
            len(result) != expected_size
            or digest.hexdigest() != expected_digest
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
            fail(f"{label} changed or differs from its admitted source-contract bytes")
    finally:
        os.close(descriptor)
    return bytes(result)


def verify_release_test_host_code_signature(path: Path) -> None:
    try:
        result = subprocess.run(
            ["/usr/bin/codesign", "--verify", "--deep", "--strict", str(path)],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=SAFE_ENV,
            timeout=120,
        )
    except (OSError, subprocess.SubprocessError) as error:
        fail(f"Release test-host code signature cannot be verified: {error}")
    if len(result.stdout) > MAX_TEXT_BYTES or len(result.stderr) > MAX_TEXT_BYTES:
        fail("Release test-host codesign output exceeds its byte bound")
    if result.returncode != 0:
        fail("Release test host does not pass codesign --deep --strict")


def verify_test_host_derivation(
    ipa_path: Path,
    test_host_path: Path,
    receipt_path: Path,
    qualification_contract_sha: str,
    contract_entries: dict[str, tuple[str, int]],
) -> dict[str, Any]:
    source = read_contract_bound_source(
        contract_entries,
        DERIVATION_TOOL_RELATIVE,
        MAX_TEXT_BYTES,
        "canonical test-host derivation tool",
    )
    expected_keys = {
        "ipaSha256",
        "testHostRawTreeSha256",
        "testHostRawTreeRecordByteCount",
        "canonicalProjectionSha256",
        "canonicalProjectionRecordByteCount",
        "testHostExecutableSha256",
        "testHostExecutableByteCount",
        "derivationReceiptSha256",
    }
    try:
        with tempfile.TemporaryFile() as captured_tool:
            captured_tool.write(source)
            captured_tool.flush()
            captured_tool.seek(0)
            descriptor = captured_tool.fileno()
            before = os.fstat(descriptor)
            result = subprocess.run(
                [
                    "/usr/bin/python3",
                    "-I",
                    "-S",
                    f"/dev/fd/{descriptor}",
                    "--repository-root",
                    str(ROOT),
                    "--verify-raw",
                    "--ipa",
                    str(ipa_path),
                    "--test-host",
                    str(test_host_path),
                    "--receipt",
                    str(receipt_path),
                    "--expected-qualification-contract-sha",
                    qualification_contract_sha,
                ],
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=SAFE_ENV,
                timeout=300,
                pass_fds=(descriptor,),
            )
            after = os.fstat(descriptor)
    except (OSError, subprocess.SubprocessError) as error:
        fail(f"canonical test-host derivation cannot be independently executed: {error}")
    if (
        metadata_identity(before) != metadata_identity(after)
        or len(result.stdout) > 16 * 1024
        or len(result.stderr) > 64 * 1024
    ):
        fail("canonical test-host derivation source or output changed/exceeded its bound")
    if result.returncode != 0:
        fail("protected test-host derivation failed independent raw-byte recomputation")
    try:
        output = result.stdout.decode("ascii", errors="strict")
    except UnicodeDecodeError:
        fail("canonical test-host derivation returned non-ASCII output")
    if not output.endswith("\n") or output.count("\n") != 1:
        fail("canonical test-host derivation returned a noncanonical output line")
    values: dict[str, Any] = {}
    for token in output[:-1].split(" "):
        if token.count("=") != 1:
            fail("canonical test-host derivation returned a malformed token")
        key, value = token.split("=", 1)
        if key not in expected_keys or key in values:
            fail("canonical test-host derivation returned an unexpected token")
        if key.endswith("ByteCount"):
            if not value.isascii() or not value.isdigit() or value.startswith("0"):
                fail(f"canonical test-host derivation {key} is invalid")
            integer = int(value)
            if not 0 < integer <= MAX_RAW_BYTES:
                fail(f"canonical test-host derivation {key} exceeds its bound")
            values[key] = integer
        else:
            values[key] = require_sha256(
                value, f"canonical test-host derivation {key}"
            )
    if set(values) != expected_keys:
        fail("canonical test-host derivation output inventory is incomplete")
    verify_release_test_host_code_signature(test_host_path)
    return values


def validate_installable_clone_receipt(
    path: Path,
    derived: dict[str, Any],
    qualification_contract_sha: str,
    canonical_projector_source_sha: str,
) -> dict[str, Any]:
    raw = read_regular(
        path,
        MAX_JSON_BYTES,
        "protected installable-clone receipt",
    )
    receipt = load_json_bytes(raw, "protected installable-clone receipt")
    if canonical_json(receipt) != raw:
        fail("protected installable-clone receipt is not canonical JSON")
    exact_keys(
        receipt,
        {
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
        },
        "protected installable-clone receipt",
    )
    exact_keys(
        receipt["checks"],
        {
            "exactProductionIpaExtracted",
            "registeredDeviceProfileVerified",
            "productionIdentityPreserved",
            "canonicalProjectionEqual",
            "installedCloneCodeSignatureDeepStrictVerified",
            "rebuiltApplicationAccepted",
            "qualificationCreated",
        },
        "protected installable-clone checks",
    )
    expected_checks = {
        "exactProductionIpaExtracted": True,
        "registeredDeviceProfileVerified": True,
        "productionIdentityPreserved": True,
        "canonicalProjectionEqual": True,
        "installedCloneCodeSignatureDeepStrictVerified": True,
        "rebuiltApplicationAccepted": False,
        "qualificationCreated": False,
    }
    if (
        receipt["schemaVersion"] != 1
        or type(receipt["schemaVersion"]) is not int
        or receipt["contractId"]
        != "sora-ios-wallet-migration-installable-clone-v1"
        or receipt["platform"] != "ios"
        or receipt["status"] != "observed"
        or receipt["releaseAuthorized"] is not False
        or receipt["qualificationContractSha256"]
        != qualification_contract_sha
        or not exact_typed_equal(receipt["checks"], expected_checks)
        or receipt["blockingReasons"]
        != [
            "Observed installable clone only: no rebuilt app is accepted; this controller cannot "
            "authorize, review, qualify, sequence, promote, upload, or enable a release."
        ]
    ):
        fail("protected installable-clone receipt has an invalid fixed contract")
    for key in (
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
        require_sha256(receipt[key], f"protected clone {key}")
    if (
        type(receipt["registeredDeviceSigningCertificateSha1"]) is not str
        or SHA1_RE.fullmatch(
            receipt["registeredDeviceSigningCertificateSha1"]
        )
        is None
        or receipt["registeredDeviceSigningCertificateSha1"] == "0" * 40
        or positive_int(
            receipt["installedAppRawTreeRecordByteCount"],
            "protected clone raw-tree record byte count",
        )
        != derived["testHostRawTreeRecordByteCount"]
        or positive_int(
            receipt["installedAppFileCount"],
            "protected clone file count",
        )
        > MAX_RAW_FILES
        or positive_int(
            receipt["installedExecutableByteCount"],
            "protected clone executable byte count",
        )
        != derived["testHostExecutableByteCount"]
        or receipt["productionIpaSha256"] != derived["ipaSha256"]
        or receipt["installedAppRawTreeSha256"]
        != derived["testHostRawTreeSha256"]
        or receipt["installedExecutableSha256"]
        != derived["testHostExecutableSha256"]
        or receipt["productionCanonicalProjectionSha256"]
        != derived["canonicalProjectionSha256"]
        or receipt["installedCanonicalProjectionSha256"]
        != derived["canonicalProjectionSha256"]
        or receipt["canonicalProjectionReceiptSha256"]
        != derived["derivationReceiptSha256"]
        or receipt["canonicalProjectorSourceSha256"]
        != canonical_projector_source_sha
    ):
        fail("protected installable-clone receipt differs from recomputed bytes")
    return {
        "receiptSha256": sha256_bytes(raw),
        "productionIpaSha256": receipt["productionIpaSha256"],
        "installedAppRawTreeSha256": receipt["installedAppRawTreeSha256"],
        "installedAppRawTreeRecordByteCount": receipt[
            "installedAppRawTreeRecordByteCount"
        ],
        "installedExecutableSha256": receipt["installedExecutableSha256"],
        "installedExecutableByteCount": receipt[
            "installedExecutableByteCount"
        ],
        "productionCanonicalProjectionSha256": receipt[
            "productionCanonicalProjectionSha256"
        ],
        "installedCanonicalProjectionSha256": receipt[
            "installedCanonicalProjectionSha256"
        ],
        "canonicalProjectionReceiptSha256": receipt[
            "canonicalProjectionReceiptSha256"
        ],
        "canonicalProjectorSourceSha256": receipt[
            "canonicalProjectorSourceSha256"
        ],
    }


def inventory_tree(root: Path, label: str) -> tuple[list[dict[str, Any]], str]:
    entries: list[dict[str, Any]] = []
    total = 0
    stack = [root]
    while stack:
        directory = stack.pop()
        try:
            children = sorted(os.scandir(directory), key=lambda entry: entry.name)
        except OSError as error:
            fail(f"{label} cannot enumerate {directory}: {error}")
        for child in children:
            if SAFE_COMPONENT_RE.fullmatch(child.name) is None:
                fail(f"{label} contains an unsafe name")
            path = Path(child.path)
            try:
                metadata = child.stat(follow_symlinks=False)
            except OSError as error:
                fail(f"{label} cannot inspect {path}: {error}")
            relative = path.relative_to(root).as_posix()
            if stat.S_ISLNK(metadata.st_mode):
                fail(f"{label} contains a symbolic link")
            if stat.S_ISDIR(metadata.st_mode):
                stack.append(path)
                continue
            if not stat.S_ISREG(metadata.st_mode):
                fail(f"{label} contains a special file")
            if metadata.st_size > MAX_RAW_FILE_BYTES or metadata.st_nlink != 1:
                fail(f"{label} contains an oversized or hard-linked file")
            digest, size = hash_regular(path, MAX_RAW_FILE_BYTES, f"{label}:{relative}")
            total += size
            if len(entries) >= MAX_RAW_FILES or total > MAX_RAW_BYTES:
                fail(f"{label} exceeds its file or byte bound")
            entries.append({"relativePath": relative, "sha256": digest, "size": size})
    entries.sort(key=lambda value: value["relativePath"])
    if not entries:
        fail(f"{label} is empty")
    projection = {
        "schemaVersion": 1,
        "contractId": "sora-ios-wallet-migration-raw-tree-v1",
        "files": entries,
    }
    return entries, sha256_bytes(canonical_json(projection))


def parse_plist(raw: bytes, label: str) -> Any:
    if not raw or len(raw) > MAX_SETTINGS_BYTES:
        fail(f"{label} is empty or exceeds its property-list byte bound")
    try:
        return plistlib.loads(raw)
    except Exception as error:
        fail(f"{label} is not a valid property list: {error}")


def plist_strings(value: Any, depth: int = 0) -> Iterable[str]:
    if depth > 20:
        return
    if type(value) is str:
        yield value
    elif type(value) is bytes:
        try:
            if value.startswith(b"bplist"):
                nested = plistlib.loads(value)
            else:
                nested = json.loads(
                    value.decode("utf-8", errors="strict"),
                    object_pairs_hook=duplicate_rejecting_object,
                    parse_constant=lambda token: fail(
                        f"invalid selected-account JSON constant: {token}"
                    ),
                )
        except (UnicodeDecodeError, json.JSONDecodeError, ValueError):
            return
        yield from plist_strings(nested, depth + 1)
    elif type(value) is dict:
        for child in value.values():
            yield from plist_strings(child, depth + 1)
    elif type(value) in (list, tuple):
        for child in value:
            yield from plist_strings(child, depth + 1)


def sqlite_value_projection(value: Any, label: str) -> bytes:
    if value is None:
        return b"n"
    if type(value) is int:
        raw = str(value).encode("ascii")
        return b"i" + len(raw).to_bytes(8, "big") + raw
    if type(value) is float:
        return b"f" + struct.pack(">d", value)
    if type(value) is str:
        raw = value.encode("utf-8", errors="strict")
        return b"s" + len(raw).to_bytes(8, "big") + raw
    if type(value) is bytes:
        return b"b" + len(value).to_bytes(8, "big") + value
    fail(f"{label} contains an unsupported SQLite value type")


def sqlite_logical_projection(connection: sqlite3.Connection, label: str) -> str:
    schema = list(
        connection.execute(
            "SELECT type, name, tbl_name, sql FROM sqlite_master "
            "WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name"
        )
    )
    tables = [row[1] for row in schema if row[0] == "table"]
    if not tables or len(tables) > 128:
        fail(f"{label} has an invalid SQLite table inventory")
    digest = hashlib.sha256(canonical_json(schema))
    total_rows = 0
    total_value_bytes = 0
    for table in tables:
        quoted = '"' + table.replace('"', '""') + '"'
        columns = list(connection.execute(f"PRAGMA table_info({quoted})"))
        if not columns or len(columns) > 256:
            fail(f"{label} table {table} has an invalid column inventory")
        row_digests: list[str] = []
        for row in connection.execute(f"SELECT * FROM {quoted}"):
            total_rows += 1
            if total_rows > 500_000:
                fail(f"{label} exceeds the SQLite row bound")
            row_digest = hashlib.sha256()
            for value in row:
                projected = sqlite_value_projection(value, f"{label} table {table}")
                total_value_bytes += len(projected)
                if total_value_bytes > 512 * 1024 * 1024:
                    fail(f"{label} exceeds the SQLite logical byte bound")
                row_digest.update(projected)
            row_digests.append(row_digest.hexdigest())
        digest.update(table.encode("utf-8"))
        digest.update(b"\0")
        digest.update(canonical_json(columns))
        digest.update(canonical_json(sorted(row_digests)))
    return digest.hexdigest()


def sqlite_type_affinity(declared_type: Any, label: str) -> str:
    if type(declared_type) is not str:
        fail(f"{label} has an invalid SQLite declared type")
    normalized = declared_type.upper()
    if "INT" in normalized:
        return "INTEGER"
    if any(token in normalized for token in ("CHAR", "CLOB", "TEXT")):
        return "TEXT"
    if not normalized or "BLOB" in normalized:
        return "BLOB"
    if any(token in normalized for token in ("REAL", "FLOA", "DOUB")):
        return "REAL"
    return "NUMERIC"


def reviewed_core_data_model(
    connection: sqlite3.Connection, label: str
) -> str:
    table_names = {
        row[0]
        for row in connection.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%'"
        )
    }
    v1_schema = {
        **CORE_DATA_COMMON_SCHEMA,
        "ZCDACCOUNTITEM": CORE_DATA_V1_ACCOUNT_SCHEMA,
    }
    v2_schema = {
        **CORE_DATA_COMMON_SCHEMA,
        "ZCDACCOUNTITEM": CORE_DATA_V2_ACCOUNT_SCHEMA,
        "ZCDACCOUNTSETTINGS": CORE_DATA_V2_SETTINGS_SCHEMA,
    }
    if table_names == set(v1_schema):
        model, expected = "UserDataModel", v1_schema
    elif table_names == set(v2_schema):
        model, expected = "UserDataModel 2", v2_schema
    else:
        fail(f"{label} does not have an exact reviewed Core Data table inventory")
    for table, expected_columns in expected.items():
        quoted = '"' + table.replace('"', '""') + '"'
        actual: dict[str, tuple[str, bool]] = {}
        for row in connection.execute(f"PRAGMA table_info({quoted})"):
            column_name = row[1]
            if type(column_name) is not str or column_name in actual:
                fail(f"{label} has an invalid column in {table}")
            actual[column_name.upper()] = (
                sqlite_type_affinity(row[2], f"{label}.{table}.{column_name}"),
                row[5] == 1,
            )
        if actual != expected_columns:
            fail(f"{label} table {table} differs from the reviewed model fingerprint")
    return model


def sqlite_accounts(
    path: Path, label: str
) -> tuple[list[tuple[str, bytes, str, int, int, int]], list[str], str, str]:
    uri = f"{path.resolve().as_uri()}?mode=ro"
    try:
        connection = sqlite3.connect(uri, uri=True, timeout=2.0)
        connection.execute("PRAGMA query_only = ON")
        integrity = [row[0] for row in connection.execute("PRAGMA integrity_check")]
        if integrity != ["ok"]:
            fail(f"{label} fails SQLite integrity_check")
        model_version = reviewed_core_data_model(connection, label)
        columns = {
            row[1].upper()
            for row in connection.execute("PRAGMA table_info('ZCDACCOUNTITEM')")
        }
        required_account_columns = {
            "ZIDENTIFIER",
            "ZPUBLICKEY",
            "ZUSERNAME",
            "ZCRYPTOTYPE",
            "ZNETWORKTYPE",
            "ZORDER",
        }
        if not required_account_columns.issubset(columns):
            fail(f"{label} lacks the retained account identity columns")
        selected_expression = "ZISSELECTED" if "ZISSELECTED" in columns else "0"
        rows = list(
            connection.execute(
                "SELECT ZIDENTIFIER, ZPUBLICKEY, ZUSERNAME, ZCRYPTOTYPE, "
                f"ZNETWORKTYPE, ZORDER, {selected_expression} "
                "FROM ZCDACCOUNTITEM ORDER BY ZIDENTIFIER"
            )
        )
        logical_projection = sqlite_logical_projection(connection, label)
    except sqlite3.Error as error:
        fail(f"{label} cannot be opened read-only: {error}")
    finally:
        try:
            connection.close()
        except UnboundLocalError:
            pass
    accounts: list[tuple[str, bytes, str, int, int, int]] = []
    selected: list[str] = []
    for (
        identifier,
        public_key,
        username,
        crypto_type,
        network_type,
        order,
        is_selected,
    ) in rows:
        if (
            type(identifier) is not str
            or not identifier
            or type(public_key) is not bytes
            or not public_key
            or type(username) is not str
            or type(crypto_type) is not int
            or not 0 <= crypto_type <= 2
            or type(network_type) is not int
            or not 0 <= network_type <= 65535
            or type(order) is not int
            or not -32768 <= order <= 32767
        ):
            fail(f"{label} contains an incomplete account identity")
        accounts.append(
            (identifier, public_key, username, crypto_type, network_type, order)
        )
        if is_selected == 1:
            selected.append(identifier)
        elif is_selected not in (0, None):
            fail(f"{label} contains an invalid selected-account flag")
    if len({account[0] for account in accounts}) != len(accounts):
        fail(f"{label} contains duplicate account identities")
    return accounts, selected, model_version, logical_projection


def canonical_plist_value(value: Any) -> bytes:
    try:
        return plistlib.dumps(value, fmt=plistlib.FMT_BINARY, sort_keys=True)
    except Exception as error:
        fail(f"retained settings value cannot be canonicalized: {error}")


def decoded_selected_account_address(value: Any, label: str) -> str:
    if type(value) is not bytes or not value:
        fail(f"{label} is not the JSON Data written by SettingsManager")
    try:
        decoded = json.loads(
            value.decode("utf-8", errors="strict"),
            object_pairs_hook=duplicate_rejecting_object,
            parse_constant=lambda token: fail(
                f"invalid selected-account JSON constant: {token}"
            ),
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fail(f"{label} is not duplicate-safe AccountItem JSON: {error}")
    required_keys = {"address", "cryptoType", "username", "publicKeyData"}
    allowed_keys = required_keys | {"networkType", "settings", "isSelected", "order"}
    if (
        type(decoded) is not dict
        or not required_keys.issubset(decoded)
        or not set(decoded).issubset(allowed_keys)
    ):
        fail(f"{label} does not have the exact AccountItem wire shape")
    address = decoded["address"]
    if type(address) is not str or not address:
        fail(f"{label}.address is invalid")
    crypto_type = decoded["cryptoType"]
    username = decoded["username"]
    public_key = decoded["publicKeyData"]
    if (
        type(crypto_type) is not int
        or crypto_type not in (0, 1, 2)
        or type(username) is not str
        or type(public_key) is not str
        or not public_key
    ):
        fail(f"{label} contains an invalid required AccountItem value")
    try:
        decoded_public_key = base64.b64decode(public_key, validate=True)
    except (ValueError, TypeError):
        fail(f"{label}.publicKeyData is not JSONDecoder-compatible Base64")
    if not decoded_public_key:
        fail(f"{label}.publicKeyData is empty")
    network_type = decoded.get("networkType")
    if network_type is not None and (
        type(network_type) is not int or not 0 <= network_type <= 65535
    ):
        fail(f"{label}.networkType is invalid")
    is_selected = decoded.get("isSelected")
    if is_selected is not None and type(is_selected) is not bool:
        fail(f"{label}.isSelected is invalid")
    order = decoded.get("order")
    if order is not None and (type(order) is not int or not -32768 <= order <= 32767):
        fail(f"{label}.order is invalid")
    settings = decoded.get("settings")
    if settings is not None:
        if type(settings) is not dict or not set(settings).issubset(
            {"visibleAssetIds", "orderedAssetIds"}
        ):
            fail(f"{label}.settings is invalid")
        for key, value in settings.items():
            if value is not None and (
                type(value) is not list
                or any(type(asset_id) is not str for asset_id in value)
            ):
                fail(f"{label}.settings.{key} is invalid")
    return address


def selected_account_from_settings(
    settings: dict[str, Any], account_identifiers: set[str], label: str
) -> Optional[str]:
    if "selectedAccount" not in settings:
        return None
    selected_account = decoded_selected_account_address(
        settings["selectedAccount"], f"{label}.selectedAccount"
    )
    if selected_account not in account_identifiers:
        fail(f"{label}.selectedAccount is not a retained account")
    return selected_account


def reviewed_settings_keys(
    contract_entries: dict[str, tuple[str, int]]
) -> set[str]:
    source = read_contract_bound_source(
        contract_entries,
        "SoraPassport/Common/Extensions/SettingsExtension.swift",
        MAX_TEXT_BYTES,
        "SettingsKey source contract",
    )
    try:
        text = source.decode("utf-8", errors="strict")
    except UnicodeDecodeError as error:
        fail(f"SettingsKey source contract is not UTF-8: {error}")
    matches = re.findall(
        r"enum[ \t]+SettingsKey[ \t]*:[ \t]*String[ \t]*\{(.*?)^\}",
        text,
        re.MULTILINE | re.DOTALL,
    )
    if len(matches) != 1:
        fail("SettingsKey source contract is ambiguous")
    keys = set(re.findall(r"^[ \t]+case[ \t]+([A-Za-z0-9_]+)[ \t]*$", matches[0], re.MULTILINE))
    if len(keys) != 33:
        fail("SettingsKey source contract must contain exactly 33 reviewed keys")
    return keys


def preserved_settings_projection(
    settings: dict[str, Any], reviewed_keys: set[str]
) -> dict[str, Any]:
    return {
        key: (
            {"present": True, "sha256": sha256_bytes(canonical_plist_value(settings[key]))}
            if key in settings
            else {"present": False, "sha256": None}
        )
        for key in sorted(reviewed_keys)
    }


def fixed_snapshot_member(
    root: Path, relative: str, label: str, required: bool = True
) -> Optional[Path]:
    path = root / relative
    try:
        metadata = os.lstat(path)
    except FileNotFoundError:
        if required:
            fail(f"{label} is absent")
        return None
    except OSError as error:
        fail(f"{label} cannot be inspected: {error}")
    if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISREG(metadata.st_mode):
        fail(f"{label} is not a regular non-symbolic file")
    return path


def require_fixed_child_inventory(
    directory: Path, expected: dict[str, str], label: str
) -> None:
    try:
        children = list(directory.iterdir())
    except OSError as error:
        fail(f"{label} cannot be enumerated: {error}")
    if {child.name for child in children} != set(expected):
        fail(f"{label} differs from the fixed raw input layout")
    for child in children:
        metadata = os.lstat(child)
        expected_kind = expected[child.name]
        if stat.S_ISLNK(metadata.st_mode) or (
            expected_kind == "directory" and not stat.S_ISDIR(metadata.st_mode)
        ) or (
            expected_kind == "file" and not stat.S_ISREG(metadata.st_mode)
        ):
            fail(f"{label}/{child.name} has an invalid node type")


def validate_fixed_raw_layout(root: Path) -> None:
    require_fixed_child_inventory(
        root,
        {
            "request.json": "file",
            "application": "directory",
            "tests": "directory",
            "snapshots": "directory",
        },
        "raw migration run",
    )
    require_fixed_child_inventory(
        root / "application",
        {
            "Sora.ipa": "file",
            "SoraPassport.app": "directory",
            "canonical-projection-receipt-v2.json": "file",
            "installable-clone-receipt-v1.json": "file",
        },
        "raw migration application",
    )
    require_fixed_child_inventory(
        root / "tests",
        {"Migration.xcresult": "directory"},
        "raw migration tests",
    )
    require_fixed_child_inventory(
        root / "snapshots",
        {"index.json": "file", "data": "directory"},
        "raw migration snapshots",
    )


def snapshot_store_bundle(
    snapshot_root: Path, role: str, label: str
) -> tuple[Path, Optional[Path], Optional[Path], Path]:
    directory = snapshot_root / role
    try:
        metadata = os.lstat(directory)
    except OSError as error:
        fail(f"{label} directory is absent: {error}")
    if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISDIR(metadata.st_mode):
        fail(f"{label} is not a regular directory")
    try:
        names = sorted(child.name for child in directory.iterdir())
    except OSError as error:
        fail(f"{label} cannot be inventoried: {error}")
    allowed = {
        "UserDataModel.sqlite",
        "UserDataModel.sqlite-wal",
        "UserDataModel.sqlite-shm",
        "settings.plist",
    }
    if not set(names).issubset(allowed) or not {
        "UserDataModel.sqlite",
        "settings.plist",
    }.issubset(names):
        fail(f"{label} contains an incomplete or unexpected fixed member inventory")
    store = fixed_snapshot_member(directory, "UserDataModel.sqlite", f"{label} store")
    settings = fixed_snapshot_member(directory, "settings.plist", f"{label} settings")
    wal = fixed_snapshot_member(
        directory, "UserDataModel.sqlite-wal", f"{label} WAL", required=False
    )
    shm = fixed_snapshot_member(
        directory, "UserDataModel.sqlite-shm", f"{label} SHM", required=False
    )
    if (wal is None) != (shm is None):
        fail(f"{label} must bind both WAL and SHM or neither")
    assert store is not None and settings is not None
    return store, wal, shm, settings


def hash_snapshot_members(
    members: tuple[Path, Optional[Path], Optional[Path], Path], label: str
) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for name, path in zip(("store", "wal", "shm", "settings"), members):
        if path is None:
            continue
        digest, size = hash_regular(path, MAX_RAW_FILE_BYTES, f"{label} {name}")
        result[name] = {"sha256": digest, "size": size}
    return result


def inspect_store_from_work_copy(
    members: tuple[Path, Optional[Path], Optional[Path], Path], label: str
) -> tuple[
    list[tuple[str, bytes, str, int, int, int]],
    list[str],
    str,
    str,
    bool,
]:
    store, wal, shm, _ = members
    with tempfile.TemporaryDirectory(prefix="ios-migration-store-read-") as temp:
        work = Path(temp)
        os.chmod(work, 0o700)
        work_store = work / "UserDataModel.sqlite"
        shutil.copyfile(store, work_store)
        if wal is not None and shm is not None:
            shutil.copyfile(wal, work / "UserDataModel.sqlite-wal")
            shutil.copyfile(shm, work / "UserDataModel.sqlite-shm")
        accounts, selected, model, logical_projection = sqlite_accounts(work_store, label)
    wal_sensitive = False
    if wal is not None:
        with tempfile.TemporaryDirectory(prefix="ios-migration-main-only-read-") as temp:
            main_only = Path(temp)
            os.chmod(main_only, 0o700)
            main_store = main_only / "UserDataModel.sqlite"
            shutil.copyfile(store, main_store)
            try:
                main_accounts, main_selected, main_model, main_projection = sqlite_accounts(
                    main_store, f"{label} main-only comparison"
                )
            except CollectionError:
                wal_sensitive = True
            else:
                wal_sensitive = (
                    main_accounts,
                    main_selected,
                    main_model,
                    main_projection,
                ) != (
                    accounts,
                    selected,
                    model,
                    logical_projection,
                )
    return accounts, selected, model, logical_projection, wal_sensitive


def validate_zip_entry_inventory(
    entries: list[zipfile.ZipInfo], label: str, maximum_entries: int, maximum_bytes: int
) -> None:
    names = [entry.filename for entry in entries]
    if not entries or len(entries) > maximum_entries or len(set(names)) != len(names):
        fail(f"{label} has an invalid or duplicate entry inventory")
    total_uncompressed = 0
    normalized_names: set[str] = set()
    for entry in entries:
        pure = PurePosixPath(entry.filename)
        canonical_name = "/".join(pure.parts) + ("/" if entry.is_dir() else "")
        normalized_name = unicodedata.normalize("NFC", canonical_name).casefold()
        if (
            not entry.filename
            or entry.filename.startswith("/")
            or "\\" in entry.filename
            or any(part in ("", ".", "..") for part in pure.parts)
            or entry.filename != canonical_name
            or normalized_name in normalized_names
        ):
            fail(f"{label} contains an unsafe or colliding path")
        normalized_names.add(normalized_name)
        mode = (entry.external_attr >> 16) & 0xFFFF
        if entry.flag_bits & 0x1:
            fail(f"{label} contains an encrypted entry")
        if mode and not (stat.S_ISREG(mode) or stat.S_ISDIR(mode)):
            fail(f"{label} contains a symbolic or special entry")
        total_uncompressed += entry.file_size
        if total_uncompressed > maximum_bytes:
            fail(f"{label} exceeds the uncompressed byte bound")


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
    application_id = entitlements.get("application-identifier")
    if type(application_id) is not str or not application_id:
        fail(f"{label} lacks one application identifier")
    candidates = (
        entitlement_group_array(entitlements, "keychain-access-groups", label)
        + [application_id]
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
    team_wildcard = "YLWWUD25VZ.*"
    return any(
        candidate == group
        or (candidate == team_wildcard and group.startswith("YLWWUD25VZ."))
        for candidate in profile_groups
    )


def validate_production_entitlement_identity(
    info: dict[str, Any],
    profile_entitlements: dict[str, Any],
    entitlements: dict[str, Any],
) -> list[str]:
    bundle_id = info.get("CFBundleIdentifier")
    application_id = entitlements.get("application-identifier")
    team_id = entitlements.get("com.apple.developer.team-identifier")
    short_version = info.get("CFBundleShortVersionString")
    build_version = info.get("CFBundleVersion")
    executable_name = info.get("CFBundleExecutable")
    if (
        bundle_id != "co.jp.soramitsu.sora"
        or team_id != "YLWWUD25VZ"
        or application_id != f"{team_id}.{bundle_id}"
        or profile_entitlements.get("application-identifier")
        not in (application_id, "YLWWUD25VZ.*")
        or profile_entitlements.get("com.apple.developer.team-identifier")
        != team_id
        or type(short_version) is not str
        or SAFE_VERSION_RE.fullmatch(short_version) is None
        or type(build_version) is not str
        or SAFE_VERSION_RE.fullmatch(build_version) is None
        or type(executable_name) is not str
        or SAFE_COMPONENT_RE.fullmatch(executable_name) is None
    ):
        fail("tested IPA does not have the reviewed production identity")
    effective_groups = effective_keychain_access_groups(
        entitlements, "tested IPA signed entitlements"
    )
    profile_groups = entitlement_group_array(
        profile_entitlements,
        "keychain-access-groups",
        "tested IPA provisioning profile",
        required=True,
    ) + entitlement_group_array(
        profile_entitlements,
        "com.apple.security.application-groups",
        "tested IPA provisioning profile",
    )
    if any(
        not profile_authorizes_group(group, profile_groups)
        for group in effective_groups
    ):
        fail("tested IPA profile does not authorize every effective access group")
    return effective_groups


def inspect_ipa(path: Path) -> tuple[dict[str, Any], str, int]:
    digest, size = hash_regular(path, MAX_IPA_BYTES, "tested production IPA")
    try:
        with tempfile.TemporaryDirectory(prefix="sora-ios-migration-ipa-") as temp:
            extraction_root = Path(temp) / "extracted"
            extraction_root.mkdir(mode=0o700)
            with zipfile.ZipFile(path, "r") as archive:
                entries = archive.infolist()
                validate_zip_entry_inventory(
                    entries,
                    "tested IPA",
                    maximum_entries=100_000,
                    maximum_bytes=4 * 1024 * 1024 * 1024,
                )
                names = [entry.filename for entry in entries]
                app_roots = sorted(
                    {
                        "/".join(PurePosixPath(name).parts[:2])
                        for name in names
                        if len(PurePosixPath(name).parts) >= 3
                        and PurePosixPath(name).parts[0] == "Payload"
                        and PurePosixPath(name).parts[1].endswith(".app")
                    }
                )
                if len(app_roots) != 1:
                    fail("tested IPA must contain exactly one application bundle")
                app_root = app_roots[0]
                info_name = f"{app_root}/Info.plist"
                profile_name = f"{app_root}/embedded.mobileprovision"
                if info_name not in names or profile_name not in names:
                    fail("tested IPA lacks Info.plist or embedded.mobileprovision")
                info = parse_plist(archive.read(info_name), "tested IPA Info.plist")
                archive.extractall(extraction_root)
            if type(info) is not dict:
                fail("tested IPA Info.plist is not an object")
            app_path = extraction_root / app_root
            profile_path = app_path / "embedded.mobileprovision"
            try:
                verification = subprocess.run(
                    ["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app_path)],
                    check=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    env=SAFE_ENV,
                    timeout=120,
                )
                decoded_result = subprocess.run(
                    ["/usr/bin/security", "cms", "-D", "-i", str(profile_path)],
                    check=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    env=SAFE_ENV,
                    timeout=30,
                )
                entitlement_result = subprocess.run(
                    [
                        "/usr/bin/codesign",
                        "-d",
                        "--entitlements",
                        ":-",
                        "--xml",
                        str(app_path),
                    ],
                    check=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    env=SAFE_ENV,
                    timeout=30,
                )
            except (OSError, subprocess.SubprocessError) as error:
                fail(f"tested IPA signature/provisioning identity cannot be verified: {error}")
            for result, label in (
                (verification, "tested IPA codesign verification"),
                (decoded_result, "tested IPA provisioning decode"),
                (entitlement_result, "tested IPA entitlement capture"),
            ):
                if (
                    len(result.stdout) > MAX_SETTINGS_BYTES
                    or len(result.stderr) > MAX_SETTINGS_BYTES
                ):
                    fail(f"{label} output exceeds its captured byte bound")
            decoded = decoded_result.stdout
            signed_entitlements_raw = entitlement_result.stdout
            profile = parse_plist(decoded, "tested IPA provisioning profile")
            signed_entitlements = parse_plist(
                signed_entitlements_raw, "tested IPA signed entitlements"
            )
    except (OSError, zipfile.BadZipFile, zipfile.LargeZipFile, RuntimeError) as error:
        fail(f"tested production IPA is invalid: {error}")
    if (
        type(profile) is not dict
        or type(profile.get("Entitlements")) is not dict
        or type(signed_entitlements) is not dict
    ):
        fail("tested IPA provisioning profile lacks entitlements")
    profile_entitlements = profile["Entitlements"]
    entitlements = signed_entitlements
    bundle_id = info.get("CFBundleIdentifier")
    executable_name = info.get("CFBundleExecutable")
    short_version = info.get("CFBundleShortVersionString")
    build_version = info.get("CFBundleVersion")
    application_id = entitlements.get("application-identifier")
    team_id = entitlements.get("com.apple.developer.team-identifier")
    effective_groups = validate_production_entitlement_identity(
        info, profile_entitlements, entitlements
    )
    executable_path = app_path / executable_name
    executable_sha, executable_size = hash_regular(
        executable_path, MAX_IPA_BYTES, "tested IPA executable"
    )
    entitlements_bytes = canonical_json(entitlements)
    access_groups_bytes = canonical_json(effective_groups)
    identity = {
        "ipaSha256": digest,
        "bundleId": bundle_id,
        "applicationId": application_id,
        "teamId": team_id,
        "shortVersion": short_version,
        "buildVersion": build_version,
        "executableSha256": executable_sha,
        "executableByteCount": executable_size,
        "signedEntitlementsSha256": sha256_bytes(entitlements_bytes),
        "keychainAccessGroupsSha256": sha256_bytes(access_groups_bytes),
    }
    return identity, digest, size


def inspect_snapshots(
    data_root: Path,
    record: dict[str, Any],
    contract_entries: dict[str, tuple[str, int]],
) -> dict[str, Any]:
    exact_keys(
        record,
        {
            "schemaVersion",
            "contractId",
            "platform",
            "runId",
            "runChallengeSha256",
            "sourceRevision",
            "snapshots",
        },
        "retained snapshot inventory",
    )
    if (
        type(record["schemaVersion"]) is not int
        or record["schemaVersion"] != 1
        or record["contractId"] != "sora-ios-wallet-migration-retained-raw-v1"
        or record["platform"] != "ios"
        or type(record["snapshots"]) is not list
        or not 4 <= len(record["snapshots"]) <= 256
    ):
        fail("retained snapshot inventory contract is invalid")
    seen_ids: set[str] = set()
    seen_cohorts: set[str] = set()
    source_versions: set[str] = set()
    snapshot_projection: list[dict[str, Any]] = []
    wal_snapshot_count = 0
    wal_sensitive_snapshot_count = 0
    settings_keys = reviewed_settings_keys(contract_entries)
    for index, item in enumerate(record["snapshots"]):
        label = f"retained snapshot inventory.snapshots[{index}]"
        exact_keys(item, {"snapshotId", "cohortId"}, label)
        snapshot_id = item["snapshotId"]
        cohort = item["cohortId"]
        if (
            type(snapshot_id) is not str
            or SAFE_ID_RE.fullmatch(snapshot_id) is None
            or snapshot_id in seen_ids
        ):
            fail(f"{label}.snapshotId is not an exact unique generic ID")
        if cohort not in EXPECTED_SNAPSHOT_COHORTS:
            fail(f"{label}.cohortId is not an approved retained cohort")
        seen_ids.add(snapshot_id)
        seen_cohorts.add(cohort)
        expected_model, is_multi = EXPECTED_SNAPSHOT_COHORTS[cohort]
        snapshot_root = data_root / snapshot_id
        try:
            snapshot_metadata = os.lstat(snapshot_root)
        except OSError as error:
            fail(f"{label} fixed snapshot directory is absent: {error}")
        if stat.S_ISLNK(snapshot_metadata.st_mode) or not stat.S_ISDIR(
            snapshot_metadata.st_mode
        ):
            fail(f"{label} fixed snapshot path is not a directory")
        if sorted(child.name for child in snapshot_root.iterdir()) != ["migrated", "source"]:
            fail(f"{label} fixed snapshot directory must contain source and migrated only")
        source_members = snapshot_store_bundle(snapshot_root, "source", f"{snapshot_id} source")
        migrated_members = snapshot_store_bundle(
            snapshot_root, "migrated", f"{snapshot_id} migrated"
        )
        source_before = hash_snapshot_members(source_members, f"{snapshot_id} source")
        migrated_before = hash_snapshot_members(
            migrated_members, f"{snapshot_id} migrated"
        )
        source_store, source_wal, source_shm, source_settings = source_members
        migrated_store, migrated_wal, migrated_shm, migrated_settings = migrated_members
        (
            source_accounts,
            source_selected,
            source_model,
            source_logical_sha,
            source_wal_sensitive,
        ) = (
            inspect_store_from_work_copy(
                source_members, f"{snapshot_id} source store"
            )
        )
        (
            migrated_accounts,
            migrated_selected,
            migrated_model,
            migrated_logical_sha,
            _,
        ) = (
            inspect_store_from_work_copy(
                migrated_members, f"{snapshot_id} migrated store"
            )
        )
        source_after = hash_snapshot_members(source_members, f"{snapshot_id} source")
        migrated_after = hash_snapshot_members(
            migrated_members, f"{snapshot_id} migrated"
        )
        if source_before != source_after or migrated_before != migrated_after:
            fail(f"{snapshot_id} retained store bundle changed during read-only inspection")
        if source_model != expected_model or migrated_model != "UserDataModel 2":
            fail(f"{snapshot_id} model identity differs from its derived cohort")
        if (is_multi and len(source_accounts) < 2) or (
            not is_multi and len(source_accounts) != 1
        ):
            fail(f"{snapshot_id} account cardinality differs from its cohort")
        if source_accounts != migrated_accounts:
            fail(f"{snapshot_id} does not preserve every retained account identity")
        source_versions.add(source_model)
        if source_wal is not None:
            wal_snapshot_count += 1
        if source_wal_sensitive:
            wal_sensitive_snapshot_count += 1
        source_plist = parse_plist(
            read_regular(
                source_settings, MAX_SETTINGS_BYTES, f"{snapshot_id} source settings"
            ),
            f"{snapshot_id} source settings",
        )
        migrated_plist = parse_plist(
            read_regular(
                migrated_settings, MAX_SETTINGS_BYTES, f"{snapshot_id} migrated settings"
            ),
            f"{snapshot_id} migrated settings",
        )
        if type(source_plist) is not dict or type(migrated_plist) is not dict:
            fail(f"{snapshot_id} settings are not dictionary property lists")
        if preserved_settings_projection(
            source_plist, settings_keys
        ) != preserved_settings_projection(migrated_plist, settings_keys):
            fail(f"{snapshot_id} changes a reviewed retained settings value")
        source_identifiers = {account[0] for account in source_accounts}
        if source_model == "UserDataModel":
            source_settings_selected = selected_account_from_settings(
                source_plist, source_identifiers, f"{snapshot_id} source settings"
            )
            migrated_settings_selected = selected_account_from_settings(
                migrated_plist, source_identifiers, f"{snapshot_id} migrated settings"
            )
            if source_selected or source_settings_selected is None:
                fail(f"{snapshot_id} v1 selection is not settings-authoritative")
            expected_selected = source_settings_selected
            if migrated_settings_selected != expected_selected:
                fail(f"{snapshot_id} changes the retained v1 settings selection")
        else:
            if len(source_selected) != 1:
                fail(f"{snapshot_id} v2 store does not have one authoritative selection")
            expected_selected = source_selected[0]
        if migrated_selected != [expected_selected]:
            fail(f"{snapshot_id} does not preserve the selected account")
        file_projection: dict[str, Any] = {
            "snapshotId": snapshot_id,
            "cohortId": cohort,
            "sourceModelVersion": source_model,
            "migratedModelVersion": migrated_model,
            "sourceLogicalStoreSha256": source_logical_sha,
            "migratedLogicalStoreSha256": migrated_logical_sha,
            "source": source_before,
            "migrated": migrated_before,
        }
        file_projection["accountCount"] = len(source_accounts)
        file_projection["selectedAccountParity"] = True
        snapshot_projection.append(file_projection)
    if (
        seen_cohorts != set(EXPECTED_SNAPSHOT_COHORTS)
        or source_versions != {"UserDataModel", "UserDataModel 2"}
        or wal_snapshot_count < 1
        or wal_sensitive_snapshot_count < 1
    ):
        fail("retained snapshot inventory is incomplete")
    try:
        actual_snapshot_ids: set[str] = set()
        for child in data_root.iterdir():
            metadata = os.lstat(child)
            if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISDIR(metadata.st_mode):
                fail("retained snapshot data root contains a non-directory entry")
            actual_snapshot_ids.add(child.name)
    except OSError as error:
        fail(f"retained snapshot data root cannot be enumerated: {error}")
    if actual_snapshot_ids != seen_ids:
        fail("retained snapshot data root contains an unindexed snapshot namespace")
    return {
        "retainedReleaseSnapshotCount": len(snapshot_projection),
        "sourceModelVersions": ["UserDataModel", "UserDataModel 2"],
        "walBearingSnapshotCount": wal_snapshot_count,
        "walSensitiveSnapshotCount": wal_sensitive_snapshot_count,
        "allSnapshotFilesRegular": True,
        "allSnapshotHashesVerified": True,
        "allSnapshotStoresOpenedReadOnly": True,
        "walSidecarsOpenedReadOnly": True,
        "reviewedSettingsParity": True,
        "accountCountParity": True,
        "selectedWalletParity": True,
        "snapshotsSha256": sha256_bytes(
            canonical_json(sorted(snapshot_projection, key=lambda value: value["snapshotId"]))
        ),
    }


def inspect_keychain(record: dict[str, Any]) -> dict[str, Any]:
    exact_keys(
        record,
        {
            "schemaVersion",
            "contractId",
            "platform",
            "runId",
            "runChallengeSha256",
            "sourceRevision",
            "producerTestIdentifier",
            "observations",
            *EXACT_CLONE_BINDING_KEYS,
        },
        "Keychain observations",
    )
    if (
        type(record["schemaVersion"]) is not int
        or record["schemaVersion"] != 3
        or record["contractId"] != "sora-ios-wallet-migration-keychain-observations-v3"
        or record["platform"] != "ios"
        or type(record["observations"]) is not list
        or len(record["observations"]) != len(EXPECTED_KEYCHAIN_COHORTS)
    ):
        fail("Keychain observation contract is invalid")
    seen: set[str] = set()
    projection: list[dict[str, Any]] = []
    for index, item in enumerate(record["observations"]):
        label = f"Keychain observations[{index}]"
        exact_keys(
            item,
            {
                "cohortId",
                "outcome",
                "identifierSetUnchanged",
                "valuesByteForByteUnchanged",
                "accessibilityUnchanged",
                "credentialRewriteObserved",
                "signingProbePassed",
                "recoveryRouteEntered",
            },
            label,
        )
        cohort = item["cohortId"]
        expected_outcome = EXPECTED_KEYCHAIN_COHORTS.get(cohort)
        if expected_outcome is None or cohort in seen or item["outcome"] != expected_outcome:
            fail(f"{label} has an invalid cohort or outcome")
        seen.add(cohort)
        if (
            item["identifierSetUnchanged"] is not True
            or item["valuesByteForByteUnchanged"] is not True
            or item["accessibilityUnchanged"] is not True
            or item["credentialRewriteObserved"] is not False
        ):
            fail(f"{label} does not preserve exact Keychain identity/value/accessibility")
        if expected_outcome == "success":
            if item["signingProbePassed"] is not True or item["recoveryRouteEntered"] is not False:
                fail(f"{label} does not prove the success route")
        elif item["signingProbePassed"] is not False or item["recoveryRouteEntered"] is not True:
            fail(f"{label} does not prove the fail-closed recovery route")
        projection.append(
            {
                "cohortId": cohort,
                "outcome": expected_outcome,
                "identityUnchanged": True,
                "accessibilityUnchanged": True,
                "signingProbePassed": item["signingProbePassed"],
                "recoveryRouteEntered": item["recoveryRouteEntered"],
            }
        )
    if seen != set(EXPECTED_KEYCHAIN_COHORTS):
        fail("Keychain observations omit a required cohort")
    return {
        "successfulSecretSourceCohortCount": 9,
        "secretFailureCohortCount": 2,
        "identityUnchanged": True,
        "accessibilityUnchanged": True,
        "noCredentialRewrite": True,
        "rawValuesExcluded": True,
        "observationProjectionSha256": sha256_bytes(canonical_json(sorted(projection, key=lambda value: value["cohortId"]))),
    }


def inspect_device_events(
    record: dict[str, Any],
    xcresult_started: int,
    xcresult_finished: int,
) -> tuple[dict[str, Any], int, int]:
    exact_keys(
        record,
        {
            "schemaVersion",
            "contractId",
            "platform",
            "runId",
            "runChallengeSha256",
            "sourceRevision",
            "producerTestIdentifier",
            "events",
            *EXACT_CLONE_BINDING_KEYS,
        },
        "device execution events",
    )
    if (
        type(record["schemaVersion"]) is not int
        or record["schemaVersion"] != 3
        or record["contractId"] != "sora-ios-wallet-migration-device-events-v3"
        or record["platform"] != "ios"
        or type(record["events"]) is not list
        or len(record["events"]) != len(EXPECTED_DEVICE_SCENARIOS)
    ):
        fail("device execution event contract is invalid")
    if (
        type(xcresult_started) is not int
        or type(xcresult_finished) is not int
        or xcresult_started <= 0
        or xcresult_finished < xcresult_started
    ):
        fail("xcresult chronology is unavailable to device-event admission")
    seen: set[str] = set()
    projection: list[dict[str, Any]] = []
    earliest_event = xcresult_started
    latest_event = xcresult_finished
    current_time = int(time.time())
    for index, event in enumerate(record["events"]):
        label = f"device execution events[{index}]"
        exact_keys(
            event,
            {
                "scenario",
                "outcome",
                "startedAtEpochSeconds",
                "finishedAtEpochSeconds",
                "assertions",
            },
            label,
        )
        scenario = event["scenario"]
        started = positive_int(event["startedAtEpochSeconds"], f"{label}.startedAtEpochSeconds")
        finished = positive_int(event["finishedAtEpochSeconds"], f"{label}.finishedAtEpochSeconds")
        if (
            scenario not in EXPECTED_DEVICE_SCENARIOS
            or scenario in seen
            or event["outcome"] != "passed"
            or finished < started
            or finished - started > 172800
            or finished > xcresult_finished
            or finished > current_time + 300
        ):
            fail(f"{label} is not an exact successful required scenario")
        earliest_event = min(earliest_event, started)
        latest_event = max(latest_event, finished)
        seen.add(scenario)
        assertions = event["assertions"]
        if (
            type(assertions) is not list
            or any(type(value) is not str for value in assertions)
            or len(assertions) != len(EXPECTED_SCENARIO_ASSERTIONS[scenario])
            or len(assertions) != len(set(assertions))
            or set(assertions) != EXPECTED_SCENARIO_ASSERTIONS[scenario]
        ):
            fail(f"{label}.assertions is invalid")
        projection.append(
            {
                "scenario": scenario,
                "outcome": "passed",
                "startedAtEpochSeconds": started,
                "finishedAtEpochSeconds": finished,
                "assertions": sorted(assertions),
            }
        )
    if seen != EXPECTED_DEVICE_SCENARIOS:
        fail("device execution events omit a required scenario")
    if latest_event - earliest_event > 172800:
        fail("device scenarios and xcresult exceed the reviewed 48-hour run window")
    aggregate = {
        "retainedCoreDataCohortCount": 4,
        "interruptionPointCohortCount": 5,
        "reinstallUpgradeQualified": True,
        "rollbackQualified": True,
        "lowStorageQualified": True,
        "recoveryArchiveExportQualified": True,
        "processDeathRestartQualified": True,
        "eventProjectionSha256": sha256_bytes(canonical_json(sorted(projection, key=lambda value: value["scenario"]))),
    }
    return aggregate, earliest_event, latest_event


def run_xcresulttool(path: Path, subcommand: str) -> dict[str, Any]:
    try:
        output = subprocess.run(
            [
                "/usr/bin/xcrun",
                "xcresulttool",
                "get",
                "test-results",
                subcommand,
                "--path",
                str(path),
                "--compact",
            ],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=SAFE_ENV,
            timeout=120,
        ).stdout
    except (OSError, subprocess.SubprocessError) as error:
        fail(f"raw xcresult cannot be inspected with xcresulttool: {error}")
    return load_tool_json_bytes(output, f"xcresulttool {subcommand}")


def export_observation_attachments(
    path: Path,
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    expected_names = set(EXPECTED_ATTACHMENT_PRODUCERS)
    with tempfile.TemporaryDirectory(prefix="sora-ios-migration-attachments-") as temp:
        output = Path(temp) / "attachments"
        try:
            subprocess.run(
                [
                    "/usr/bin/xcrun",
                    "xcresulttool",
                    "export",
                    "attachments",
                    "--path",
                    str(path),
                    "--output-path",
                    str(output),
                ],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=SAFE_ENV,
                timeout=120,
            )
        except (OSError, subprocess.SubprocessError) as error:
            fail(f"raw xcresult attachments cannot be exported: {error}")
        inventory_tree(output, "exported xcresult attachments")
        manifest_path = output / "manifest.json"
        manifest = load_tool_json_value(
            read_regular(manifest_path, MAX_JSON_BYTES, "xcresult attachment manifest"),
            "xcresult attachment manifest",
        )
        if type(manifest) is not list or not manifest:
            fail("xcresult attachment manifest is not a nonempty array")
        found: dict[str, Path] = {}
        associations: dict[str, str] = {}
        for test_entry in manifest:
            if type(test_entry) is not dict:
                fail("xcresult attachment manifest contains a malformed test entry")
            if set(test_entry) not in (
                {"testIdentifier", "attachments"},
                {"testIdentifier", "testIdentifierURL", "attachments"},
            ):
                fail("xcresult attachment test entry contains unreviewed fields")
            test_identifier = test_entry.get("testIdentifier")
            attachments = test_entry.get("attachments")
            if type(test_identifier) is not str or type(attachments) is not list:
                fail("xcresult attachment manifest test association is invalid")
            for attachment in attachments:
                if type(attachment) is not dict:
                    fail("xcresult attachment manifest contains a malformed attachment")
                suggested = attachment.get("suggestedHumanReadableName")
                exported = attachment.get("exportedFileName")
                if type(suggested) is not str or type(exported) is not str:
                    fail("xcresult attachment manifest lacks attachment names")
                if suggested.startswith("ios-migration-") and suggested not in expected_names:
                    fail("raw xcresult contains an unreviewed migration evidence attachment")
                if suggested not in expected_names:
                    continue
                if attachment.get("isAssociatedWithFailure") is not False:
                    fail(f"{suggested} is associated with a test failure")
                expected_producer = EXPECTED_ATTACHMENT_PRODUCERS[suggested]
                if test_identifier != expected_producer:
                    fail(f"{suggested} is attached by an unreviewed test")
                if suggested in found:
                    fail(f"raw xcresult contains duplicate {suggested} attachments")
                exported_relative = safe_relative(
                    exported, f"xcresult exported attachment {suggested}"
                )
                exported_path = output.joinpath(*exported_relative.parts)
                if not exported_path.is_file() or exported_path.is_symlink():
                    fail(f"xcresult exported attachment {suggested} is not regular")
                found[suggested] = exported_path
                associations[suggested] = test_identifier
        if set(found) != expected_names:
            fail("raw xcresult lacks the exact run/Keychain/device attachments")
        run_binding = load_json_bytes(
            read_regular(
                found["ios-migration-run-binding-v3.json"],
                MAX_JSON_BYTES,
                "migration run binding",
            ),
            "migration run binding",
        )
        keychain = load_json_bytes(
            read_regular(
                found["ios-migration-keychain-observations-v3.json"],
                MAX_JSON_BYTES,
                "Keychain observations",
            ),
            "Keychain observations",
        )
        device = load_json_bytes(
            read_regular(
                found["ios-migration-device-events-v3.json"],
                MAX_JSON_BYTES,
                "device execution events",
            ),
            "device execution events",
        )
        for name, record in (
            ("ios-migration-run-binding-v3.json", run_binding),
            ("ios-migration-keychain-observations-v3.json", keychain),
            ("ios-migration-device-events-v3.json", device),
        ):
            if record.get("producerTestIdentifier") != associations[name]:
                fail(f"{name} producer field differs from its xcresult association")
        return run_binding, keychain, device


def expected_test_identifiers(
    contract_entries: dict[str, tuple[str, int]]
) -> set[str]:
    sources = {
        "WalletModernizationTests":
        "SoraPassportTests/Common/Modernization/WalletModernizationTests.swift",
        "WalletRecoveryCapabilityGateTests":
        "SoraPassportTests/Common/Modernization/WalletRecoveryCapabilityGateTests.swift",
        "WalletRecoveryExporterTests":
        "SoraPassportTests/Common/Modernization/WalletRecoveryExporterTests.swift",
        "WalletMigrationRetainedDeviceEvidenceTests":
        "SoraPassportIntegrationTests/WalletMigrationRetainedDeviceEvidenceTests.swift",
    }
    result: set[str] = set()
    for suite, relative in sources.items():
        raw = read_contract_bound_source(
            contract_entries,
            relative,
            MAX_TEXT_BYTES,
            f"{suite} source inventory",
        )
        try:
            text = raw.decode("utf-8", errors="strict")
        except UnicodeDecodeError as error:
            fail(f"{suite} source inventory is not UTF-8: {error}")
        methods = re.findall(r"^[ \t]+func[ \t]+(test[A-Za-z0-9_]+)[ \t]*\(", text, re.MULTILINE)
        if not methods or len(methods) != len(set(methods)):
            fail(f"{suite} source has an invalid test-method inventory")
        result.update(f"{suite}/{method}()" for method in methods)
    if len(result) != 233:
        fail("migration test source inventory must contain exactly 233 identifiers")
    return result


def count_test_cases(
    nodes: Any, ancestors: tuple[str, ...] = ()
) -> tuple[dict[str, int], int, set[str]]:
    counts = {
        "WalletModernizationTests": 0,
        "WalletRecoveryCapabilityGateTests": 0,
        "WalletRecoveryExporterTests": 0,
        "WalletMigrationRetainedDeviceEvidenceTests": 0,
    }
    total = 0
    observed: set[str] = set()
    if type(nodes) is not list:
        fail("xcresult test nodes are invalid")
    for node in nodes:
        if type(node) is not dict or type(node.get("nodeType")) is not str or type(node.get("name")) is not str:
            fail("xcresult contains a malformed test node")
        lineage = ancestors + (node["name"],)
        if node["nodeType"] == "Test Case":
            total += 1
            matches = [suite for suite in counts if any(suite in value for value in lineage)]
            method_match = re.search(r"(test[A-Za-z0-9_]+)\(\)$", node["name"])
            if len(matches) != 1 or method_match is None or node.get("result") != "Passed":
                fail("xcresult contains an unreviewed or non-passing migration test case")
            identifier = f"{matches[0]}/{method_match.group(1)}()"
            if identifier in observed:
                fail("xcresult contains a duplicate migration test identifier")
            observed.add(identifier)
            counts[matches[0]] += 1
        children = node.get("children", [])
        if children is not None:
            child_counts, child_total, child_observed = count_test_cases(children, lineage)
            total += child_total
            for key, value in child_counts.items():
                counts[key] += value
            if observed.intersection(child_observed):
                fail("xcresult repeats a migration test identifier")
            observed.update(child_observed)
    return counts, total, observed


def inspect_xcresult(
    path: Path,
    contract_entries: dict[str, tuple[str, int]],
) -> tuple[
    dict[str, Any],
    list[dict[str, Any]],
    str,
    dict[str, Any],
    dict[str, Any],
    dict[str, Any],
]:
    metadata = os.lstat(path)
    if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISDIR(metadata.st_mode):
        fail("raw xcresult must be a non-symbolic directory")
    entries, tree_sha = inventory_tree(path, "raw xcresult")
    summary = run_xcresulttool(path, "summary")
    tests = run_xcresulttool(path, "tests")
    for key in ("totalTestCount", "passedTests", "failedTests", "skippedTests", "expectedFailures"):
        if type(summary.get(key)) is not int or summary[key] < 0:
            fail(f"xcresult summary.{key} is invalid")
    if (
        summary.get("result") != "Passed"
        or summary["failedTests"] != 0
        or summary["skippedTests"] != 0
        or summary["expectedFailures"] != 0
        or summary["passedTests"] != summary["totalTestCount"]
    ):
        fail("raw xcresult is not a complete passing test run")
    start_time = summary.get("startTime")
    finish_time = summary.get("finishTime")
    if (
        type(start_time) not in (int, float)
        or type(finish_time) not in (int, float)
        or start_time <= 0
        or finish_time < start_time
        or finish_time - start_time > 172800
    ):
        fail("raw xcresult chronology is invalid")
    exact_keys(tests, {"testPlanConfigurations", "devices", "testNodes"}, "xcresult tests")
    suite_counts, enumerated_total, observed_tests = count_test_cases(tests["testNodes"])
    required_counts = {
        "WalletModernizationTests": 207,
        "WalletRecoveryCapabilityGateTests": 11,
        "WalletRecoveryExporterTests": 12,
        "WalletMigrationRetainedDeviceEvidenceTests": 3,
    }
    if (
        suite_counts != required_counts
        or enumerated_total != summary["totalTestCount"]
        or observed_tests != expected_test_identifiers(contract_entries)
    ):
        fail("raw xcresult does not contain the exact four-suite migration inventory")
    devices = tests["devices"]
    if type(devices) is not list or not devices:
        fail("raw xcresult lacks a test device")
    generic_device_classes: set[str] = set()
    operating_system_builds: set[str] = set()
    for device in devices:
        if type(device) is not dict:
            fail("raw xcresult device is invalid")
        model = device.get("modelName")
        platform = device.get("platform")
        version = device.get("osVersion")
        build = device.get("osBuildNumber")
        architecture = device.get("architecture")
        if any(
            type(value) is not str or not value
            for value in (model, platform, version, build, architecture)
        ):
            fail("raw xcresult device lacks generic model/OS identity")
        if (
            platform != "iOS"
            or not (model.startswith("iPhone") or model.startswith("iPad"))
            or architecture != "arm64"
            or "Simulator" in model
        ):
            fail("raw xcresult did not execute on a retained physical iOS device")
        generic_device_classes.add(model)
        operating_system_builds.add(f"{platform} {version} ({build})")
    result = {
        "executedWalletModernizationTestCount": suite_counts["WalletModernizationTests"],
        "executedRecoveryCapabilityGateTestCount": suite_counts["WalletRecoveryCapabilityGateTests"],
        "executedRecoveryExporterTestCount": suite_counts["WalletRecoveryExporterTests"],
        "executedRetainedDeviceEvidenceTestCount": suite_counts[
            "WalletMigrationRetainedDeviceEvidenceTests"
        ],
        "testFailureCount": 0,
        "testUnexpectedFailureCount": 0,
        "testSkippedCount": 0,
        "testExpectedFailureCount": 0,
        "executedTestIdentifierSetSha256": sha256_bytes(
            canonical_json(sorted(observed_tests))
        ),
        "deviceClasses": sorted(generic_device_classes),
        "operatingSystemBuilds": sorted(operating_system_builds),
        "runStartedAtEpochSeconds": int(start_time),
        "runFinishedAtEpochSeconds": int(finish_time),
    }
    run_binding, keychain_record, device_record = export_observation_attachments(path)
    return result, entries, tree_sha, run_binding, keychain_record, device_record


def make_zip(xcresult: Path, summary: dict[str, Any], destination: Path) -> None:
    try:
        with zipfile.ZipFile(
            destination,
            "x",
            compression=zipfile.ZIP_DEFLATED,
            compresslevel=9,
            allowZip64=True,
        ) as archive:
            summary_info = zipfile.ZipInfo("ios-migration-test-summary.json", (1980, 1, 1, 0, 0, 0))
            summary_info.external_attr = 0o100600 << 16
            summary_info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(summary_info, pretty_json(summary))
            # Raw xcresult bytes remain in the protected handoff namespace.
            # The repository-facing ZIP contains only the privacy-safe summary;
            # the signed evidence manifest binds the independently re-opened
            # raw input-set digest.
    except (OSError, RuntimeError, zipfile.BadZipFile, zipfile.LargeZipFile) as error:
        fail(f"cannot create deterministic xcresult ZIP: {error}")


def validate_identity_array(value: Any, label: str) -> list[str]:
    if type(value) is not list or not value or len(value) > 64:
        fail(f"{label} must be a nonempty bounded array")
    if any(type(item) is not str or not item or len(item.encode("utf-8")) > 128 for item in value):
        fail(f"{label} contains an invalid value")
    if len(set(value)) != len(value):
        fail(f"{label} contains duplicates")
    return value


def privacy_projection() -> dict[str, Any]:
    return {
        "aggregateOnly": True,
        "accountIdentifiersIncluded": False,
        "addressesIncluded": False,
        "deviceIdentifiersIncluded": False,
        "phrasesOrSeedsIncluded": False,
        "privateKeysIncluded": False,
        "publicKeysIncluded": False,
        "rawKeychainValuesIncluded": False,
        "rawSignedPayloadsIncluded": False,
        "perWalletRecordsIncluded": False,
    }


def assert_output_privacy(value: Any, label: str) -> None:
    if type(value) is dict:
        for key, child in value.items():
            normalized = re.sub(r"[^a-z0-9]", "", key.lower())
            if (
                any(part in normalized for part in FORBIDDEN_OUTPUT_KEY_PARTS)
                and normalized not in SAFE_OUTPUT_AGGREGATE_KEYS
            ):
                if not (normalized.endswith("included") and child is False):
                    fail(f"{label} contains a prohibited output field: {key}")
            assert_output_privacy(child, f"{label}.{key}")
    elif type(value) is list:
        for index, child in enumerate(value):
            assert_output_privacy(child, f"{label}[{index}]")


def write_exclusive(path: Path, raw: bytes) -> None:
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags, 0o600)
    try:
        written = 0
        while written < len(raw):
            written += os.write(descriptor, raw[written:])
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def unlink_exact_regular(path: Path, label: str) -> None:
    metadata = os.lstat(path)
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
        fail(f"{label} is not an exact unique regular file")
    os.unlink(path)
    try:
        os.lstat(path)
    except FileNotFoundError:
        return
    fail(f"{label} remained after exact unlink")


def collect(input_root: Path, output_root: Path) -> dict[str, Any]:
    input_root = ensure_absolute_noalias_directory(input_root, "raw input root")
    if ROOT == input_root or ROOT in input_root.parents or input_root in ROOT.parents:
        fail("raw migration inputs must remain outside the repository")
    partial_output, final_output = create_exclusive_output(output_root, input_root)
    snapshots: list[Path] = []
    try:
        contract_snapshot_path = partial_output / ".qualification-contract-snapshot.json"
        current_contract = run_qualification_contract_tool(
            ["--snapshot", str(contract_snapshot_path)]
        )
        contract_entries = load_contract_source_entries(
            contract_snapshot_path, current_contract
        )
        snapshot_root, initial_entries, raw_root_sha = snapshot_anchored_tree(
            input_root, partial_output.parent, "raw migration run"
        )
        snapshots.append(snapshot_root)
        validate_fixed_raw_layout(snapshot_root)
        request_path = resolve_input(snapshot_root, "request.json", "collection request")
        request = load_json_bytes(
            read_regular(request_path, MAX_JSON_BYTES, "collection request"),
            "collection request",
        )
        exact_keys(
            request,
            {
                "schemaVersion",
                "contractId",
                "platform",
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
            },
            "collection request",
        )
        if (
            type(request["schemaVersion"]) is not int
            or request["schemaVersion"] != 3
            or request["contractId"]
            != "sora-ios-wallet-migration-collection-request-v3"
            or request["platform"] != "ios"
        ):
            fail("collection request is not exact v3")
        try:
            run_id = str(uuid.UUID(request["runId"]))
        except (TypeError, ValueError, AttributeError):
            fail("collection run ID is not a UUID")
        if run_id == str(uuid.UUID(int=0)) or run_id != request["runId"]:
            fail("collection run ID is not canonical and nonzero")
        challenge = require_sha256(
            request["runChallengeSha256"], "collection run challenge"
        )
        source_revision = request["sourceRevision"]
        if (
            type(source_revision) is not str
            or SOURCE_REVISION_RE.fullmatch(source_revision) is None
            or source_revision == "0" * 40
        ):
            fail("collection source revision is invalid")
        qualification_contract = require_sha256(
            request["qualificationContractSha256"], "collection qualification contract"
        )
        if current_contract != qualification_contract:
            fail("collection request is not bound to the current qualification source contract")
        requested_clone_identity = {
            key: require_sha256(request[key], f"collection request {key}")
            for key in (
                "productionIpaSha256",
                "installedAppRawTreeSha256",
                "installedExecutableSha256",
                "productionCanonicalProjectionSha256",
                "installedCanonicalProjectionSha256",
                "canonicalProjectionReceiptSha256",
                "canonicalProjectorSourceSha256",
            )
        }
        if (
            requested_clone_identity["productionCanonicalProjectionSha256"]
            != requested_clone_identity["installedCanonicalProjectionSha256"]
        ):
            fail("collection request canonical projections are unequal")

        ipa_path = resolve_input(
            snapshot_root, "application/Sora.ipa", "fixed tested production IPA"
        )
        installed_clone_path = resolve_input(
            snapshot_root,
            "application/SoraPassport.app",
            "fixed archive-derived installed clone",
        )
        projection_receipt_path = resolve_input(
            snapshot_root,
            "application/canonical-projection-receipt-v2.json",
            "fixed canonical projection receipt",
        )
        clone_receipt_path = resolve_input(
            snapshot_root,
            "application/installable-clone-receipt-v1.json",
            "fixed installable-clone receipt",
        )
        xcresult_path = resolve_input(
            snapshot_root, "tests/Migration.xcresult", "fixed raw xcresult"
        )
        snapshots_path = resolve_input(
            snapshot_root, "snapshots/index.json", "fixed retained snapshot inventory"
        )
        snapshot_data_root = resolve_input(
            snapshot_root, "snapshots/data", "fixed retained snapshot data root"
        )
        if not snapshot_data_root.is_dir():
            fail("fixed retained snapshot data root is not a directory")

        clone_projection = verify_test_host_derivation(
            ipa_path,
            installed_clone_path,
            projection_receipt_path,
            qualification_contract,
            contract_entries,
        )
        canonical_projector_source_sha = contract_entries[
            DERIVATION_TOOL_RELATIVE
        ][0]
        installable_clone = validate_installable_clone_receipt(
            clone_receipt_path,
            clone_projection,
            qualification_contract,
            canonical_projector_source_sha,
        )
        if any(
            installable_clone[key] != value
            for key, value in requested_clone_identity.items()
        ):
            fail("collection request differs from the protected installed clone")
        artifact_identity, ipa_sha, ipa_size = inspect_ipa(ipa_path)
        if installable_clone["productionIpaSha256"] != ipa_sha:
            fail("installed-clone receipt differs from the opened production IPA")
        (
            xcresult_result,
            xcresult_entries,
            xcresult_tree_sha,
            run_binding,
            keychain_record,
            device_record,
        ) = inspect_xcresult(xcresult_path, contract_entries)
        started = xcresult_result["runStartedAtEpochSeconds"]
        finished = xcresult_result["runFinishedAtEpochSeconds"]
        identity = {
            **requested_clone_identity,
            "installedAppRawTreeRecordByteCount": installable_clone[
                "installedAppRawTreeRecordByteCount"
            ],
            "installedExecutableByteCount": installable_clone[
                "installedExecutableByteCount"
            ],
            "deviceClasses": validate_identity_array(
                xcresult_result["deviceClasses"], "xcresult device classes"
            ),
            "operatingSystemBuilds": validate_identity_array(
                xcresult_result["operatingSystemBuilds"], "xcresult OS builds"
            ),
        }
        snapshots_record = load_json_bytes(
            read_regular(
                snapshots_path, MAX_JSON_BYTES, "retained snapshot inventory"
            ),
            "retained snapshot inventory",
        )
        exact_keys(
            run_binding,
            {
                "schemaVersion",
                "contractId",
                "platform",
                "runId",
                "runChallengeSha256",
                "sourceRevision",
                "producerTestIdentifier",
                *EXACT_CLONE_BINDING_KEYS,
            },
            "migration run binding",
        )
        if (
            type(run_binding["schemaVersion"]) is not int
            or run_binding["schemaVersion"] != 3
            or run_binding["contractId"]
            != "sora-ios-wallet-migration-run-binding-v3"
            or run_binding["platform"] != "ios"
            or require_sha256(
                run_binding["installedExecutableSha256"],
                "migration run binding tested executable",
                installable_clone["installedExecutableSha256"],
            )
            != installable_clone["installedExecutableSha256"]
        ):
            fail("migration run binding contract is invalid")
        expected_clone_binding = {
            **identity,
            "installedAppLaunchVerified": True,
            "installedRawTreeRecomputed": True,
            "installedExecutableRecomputed": True,
            "canonicalProjectionReceiptVerified": True,
            "canonicalProjectorSourceVerified": True,
            "canonicalProjectionEqualToProduction": True,
        }
        expected_clone_binding.pop("deviceClasses")
        expected_clone_binding.pop("operatingSystemBuilds")
        for label, record in (
            ("migration run binding", run_binding),
            ("retained snapshot inventory", snapshots_record),
            ("Keychain observations", keychain_record),
            ("device execution events", device_record),
        ):
            if (
                record.get("runId") != run_id
                or record.get("runChallengeSha256") != challenge
                or record.get("sourceRevision") != source_revision
                or (
                    label != "retained snapshot inventory"
                    and any(
                        not exact_typed_equal(record.get(key), value)
                        for key, value in expected_clone_binding.items()
                    )
                )
            ):
                fail(f"{label} differs from the collection request")
        snapshot_aggregate = inspect_snapshots(
            snapshot_data_root, snapshots_record, contract_entries
        )
        keychain_aggregate = inspect_keychain(keychain_record)
        device_aggregate, started, finished = inspect_device_events(
            device_record, started, finished
        )

        produced_at = finished
        common = {
            "schemaVersion": 4,
            "platform": "ios",
            "status": "observed",
            "releaseAuthorized": False,
            "runId": run_id,
            "runChallengeSha256": challenge,
            "sourceRevision": source_revision,
            "producedAtEpochSeconds": produced_at,
            "rawInputSetSha256": raw_root_sha,
            "identity": identity,
            "privacy": privacy_projection(),
            "blockingReasons": [NONAUTHORIZING_BLOCKER],
        }
        snapshot_artifact = {
            **common,
            "contractId": "sora-ios-wallet-migration-retained-snapshot-manifest-v4",
            "aggregate": snapshot_aggregate,
        }
        keychain_artifact = {
            **common,
            "contractId": "sora-ios-wallet-migration-keychain-evidence-v4",
            "aggregate": keychain_aggregate,
        }
        device_artifact = {
            **common,
            "contractId": "sora-ios-wallet-migration-device-execution-evidence-v4",
            "aggregate": device_aggregate,
        }
        summary = {
            **common,
            "contractId": "sora-ios-wallet-migration-test-summary-v4",
            **{key: xcresult_result[key] for key in (
                "executedWalletModernizationTestCount",
                "executedRecoveryCapabilityGateTestCount",
                "executedRecoveryExporterTestCount",
                "executedRetainedDeviceEvidenceTestCount",
                "testFailureCount",
                "testUnexpectedFailureCount",
                "testSkippedCount",
                "testExpectedFailureCount",
            )},
            "xcresultTreeSha256": xcresult_tree_sha,
            "executedTestIdentifierSetSha256": xcresult_result[
                "executedTestIdentifierSetSha256"
            ],
        }
        for label, value in (
            ("snapshot aggregate", snapshot_artifact),
            ("Keychain aggregate", keychain_artifact),
            ("device aggregate", device_artifact),
            ("test summary", summary),
        ):
            assert_output_privacy(value, label)

        snapshot_bytes = pretty_json(snapshot_artifact)
        keychain_bytes = pretty_json(keychain_artifact)
        device_bytes = pretty_json(device_artifact)
        write_exclusive(partial_output / OUTPUT_NAMES["snapshots"], snapshot_bytes)
        write_exclusive(partial_output / OUTPUT_NAMES["keychain"], keychain_bytes)
        write_exclusive(partial_output / OUTPUT_NAMES["device"], device_bytes)
        make_zip(xcresult_path, summary, partial_output / OUTPUT_NAMES["tests"])
        test_sha, test_size = hash_regular(partial_output / OUTPUT_NAMES["tests"], MAX_IPA_BYTES, "derived xcresult ZIP")

        artifacts = {
            "retainedReleaseSnapshotManifest": {
                "relativePath": "Fixtures/Modernization/ios-migration-retained-snapshot-manifest.json",
                "sha256": sha256_bytes(snapshot_bytes),
                "byteCount": len(snapshot_bytes),
            },
            "testResultBundle": {
                "relativePath": "Fixtures/Modernization/ios-migration-tests.xcresult.zip",
                "sha256": test_sha,
                "byteCount": test_size,
            },
            "keychainEvidence": {
                "relativePath": "Fixtures/Modernization/ios-migration-keychain-evidence.json",
                "sha256": sha256_bytes(keychain_bytes),
                "byteCount": len(keychain_bytes),
            },
            "deviceExecutionEvidence": {
                "relativePath": "Fixtures/Modernization/ios-migration-device-execution-evidence.json",
                "sha256": sha256_bytes(device_bytes),
                "byteCount": len(device_bytes),
            },
        }
        try:
            xcresulttool_version = subprocess.run(
                ["/usr/bin/xcrun", "xcresulttool", "--version"],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=SAFE_ENV,
                timeout=30,
                text=True,
            ).stdout.strip()
            xcode_build_version = " ".join(
                subprocess.run(
                    ["/usr/bin/xcodebuild", "-version"],
                    check=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    env=SAFE_ENV,
                    timeout=30,
                    text=True,
                ).stdout.split()
            )
        except (OSError, subprocess.SubprocessError) as error:
            fail(f"Xcode evidence toolchain cannot be recorded: {error}")
        if (
            not xcresulttool_version
            or len(xcresulttool_version) > 128
            or not xcode_build_version.startswith("Xcode ")
            or len(xcode_build_version) > 128
        ):
            fail("Xcode evidence toolchain identity is invalid")
        collection_receipt = {
            "schemaVersion": 3,
            "contractId": "sora-ios-wallet-migration-collection-receipt-v3",
            "platform": "ios",
            "status": "observed",
            "releaseAuthorized": False,
            "runId": run_id,
            "runChallengeSha256": challenge,
            "sourceRevision": source_revision,
            "qualificationContractSha256": qualification_contract,
            "collectedAtEpochSeconds": produced_at,
            "rawInputSet": {
                "contractId": "sora-ios-wallet-migration-raw-input-set-v3",
                "sha256": raw_root_sha,
                "fileCount": len(initial_entries),
                "byteCount": sum(entry["size"] for entry in initial_entries),
            },
            "identity": identity,
            "testedApplication": {
                "sha256": ipa_sha,
                "byteCount": ipa_size,
                "bundleIdentifier": artifact_identity["bundleId"],
                "shortVersion": artifact_identity["shortVersion"],
                "buildVersion": artifact_identity["buildVersion"],
                "executableSha256": artifact_identity["executableSha256"],
                "executableByteCount": artifact_identity["executableByteCount"],
                "productionCodeSignatureVerified": True,
                "productionApplicationIdentifierVerified": True,
                "productionTeamIdentifierVerified": True,
                "productionKeychainAccessGroupVerified": True,
            },
            "installedClone": {
                "receiptSha256": installable_clone["receiptSha256"],
                "rawTreeSha256": installable_clone[
                    "installedAppRawTreeSha256"
                ],
                "rawTreeRecordByteCount": installable_clone[
                    "installedAppRawTreeRecordByteCount"
                ],
                "executableSha256": installable_clone[
                    "installedExecutableSha256"
                ],
                "executableByteCount": installable_clone[
                    "installedExecutableByteCount"
                ],
                "productionCanonicalProjectionSha256": installable_clone[
                    "productionCanonicalProjectionSha256"
                ],
                "installedCanonicalProjectionSha256": installable_clone[
                    "installedCanonicalProjectionSha256"
                ],
                "canonicalProjectionReceiptSha256": installable_clone[
                    "canonicalProjectionReceiptSha256"
                ],
                "canonicalProjectorSourceSha256": installable_clone[
                    "canonicalProjectorSourceSha256"
                ],
                "codeSignatureDeepStrictVerified": True,
                "installedAppLaunchVerified": True,
                "installedRawTreeRecomputed": True,
                "installedExecutableRecomputed": True,
                "canonicalProjectionEqualToProduction": True,
            },
            "privacy": privacy_projection(),
            "toolchain": {
                "xcodeBuildVersion": xcode_build_version,
                "xcresultFormatVersion": "0.1.0",
            },
            "artifacts": artifacts,
            "checks": {
                "allRawFilesRegular": True,
                "allRawHashesVerified": True,
                "testedProductionIpaOpened": True,
                "signedProductionIdentityVerified": True,
                "installableCloneReceiptVerified": True,
                "installedCloneCodeSignatureVerified": True,
                "installedCloneIdentityBound": True,
                "canonicalProjectionReceiptVerified": True,
                "canonicalProjectorSourceVerified": True,
                "rawXcresultParsed": True,
                "retainedStoresOpenedReadOnly": True,
                "keychainObservationsBound": True,
                "deviceScenarioAttachmentsBound": True,
                "collectorNonAuthorizing": True,
            },
            "blockingReasons": [NONAUTHORIZING_BLOCKER],
        }
        assert_output_privacy(collection_receipt, "collection receipt")
        collection_bytes = pretty_json(collection_receipt)
        write_exclusive(
            partial_output / OUTPUT_NAMES["collection"], collection_bytes
        )

        final_snapshot, final_entries, final_raw_root_sha = snapshot_anchored_tree(
            input_root, partial_output.parent, "raw migration run final recheck"
        )
        snapshots.append(final_snapshot)
        if final_entries != initial_entries or final_raw_root_sha != raw_root_sha:
            fail("raw migration inputs changed during evidence collection")
        if (
            run_qualification_contract_tool(
                [
                    "--verify-snapshot",
                    str(contract_snapshot_path),
                    "--expected-sha",
                    qualification_contract,
                ]
            )
            != qualification_contract
        ):
            fail("qualification source contract changed during evidence collection")
        unlink_exact_regular(contract_snapshot_path, "qualification contract snapshot")
        for path in partial_output.iterdir():
            if path.name not in OUTPUT_NAMES.values() or path.is_symlink() or not path.is_file():
                fail("derived output namespace contains an unexpected entry")
        directory_descriptor = os.open(partial_output, os.O_RDONLY)
        try:
            os.fsync(directory_descriptor)
        finally:
            os.close(directory_descriptor)
        for snapshot in snapshots:
            shutil.rmtree(snapshot)
        snapshots.clear()
        parent_descriptor = os.open(
            partial_output.parent, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
        )
        try:
            os.fsync(parent_descriptor)
            publish_directory_no_replace(partial_output, final_output)
            os.fsync(parent_descriptor)
        finally:
            os.close(parent_descriptor)
        return {
            "schemaVersion": 2,
            "contractId": "sora-ios-wallet-migration-collector-result-v2",
            "runId": run_id,
            "runChallengeSha256": challenge,
            "sourceRevision": source_revision,
            "qualificationContractSha256": qualification_contract,
            "rawInputSetSha256": raw_root_sha,
            "runStartedAtEpochSeconds": started,
            "runFinishedAtEpochSeconds": finished,
            "collectionReceiptSha256": sha256_bytes(collection_bytes),
            "outputRoot": str(final_output),
            "artifactCount": len(OUTPUT_NAMES),
        }
    except Exception:
        # Never publish a partial namespace as a successful handoff.  The
        # exclusive directory remains as fail-closed forensic evidence.
        for snapshot in snapshots:
            try:
                shutil.rmtree(snapshot)
            except OSError:
                pass
        raise


def lint_contract() -> None:
    if set(OUTPUT_NAMES) != {"collection", "snapshots", "tests", "keychain", "device"}:
        fail("collector output inventory changed")
    if len(set(OUTPUT_NAMES.values())) != len(OUTPUT_NAMES):
        fail("collector output names are not unique")
    if EXPECTED_DEVICE_SCENARIOS != {
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
    }:
        fail("collector scenario inventory changed")
    blocked = load_json_bytes(
        read_regular(
            BLOCKED_COLLECTION_TEMPLATE,
            MAX_JSON_BYTES,
            "blocked collection receipt template",
        ),
        "blocked collection receipt template",
    )
    exact_keys(
        blocked,
        {
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
        },
        "blocked collection receipt template",
    )
    if (
        type(blocked["schemaVersion"]) is not int
        or blocked["schemaVersion"] != 3
        or blocked["contractId"]
        != "sora-ios-wallet-migration-collection-receipt-v3"
        or blocked["platform"] != "ios"
        or blocked["status"] != "blocked-template"
        or blocked["releaseAuthorized"] is not False
        or any(
            blocked[key] is not None
            for key in (
                "runId",
                "runChallengeSha256",
                "sourceRevision",
                "qualificationContractSha256",
            )
        )
        or type(blocked["collectedAtEpochSeconds"]) is not int
        or blocked["collectedAtEpochSeconds"] != 0
        or blocked["blockingReasons"] != [NONAUTHORIZING_BLOCKER]
    ):
        fail("blocked collection receipt template can fabricate collection authority")
    if not exact_typed_equal(blocked["privacy"], privacy_projection()):
        fail("blocked collection receipt template privacy projection changed")
    expected_artifact_paths = {
        "retainedReleaseSnapshotManifest": "Fixtures/Modernization/ios-migration-retained-snapshot-manifest.json",
        "testResultBundle": "Fixtures/Modernization/ios-migration-tests.xcresult.zip",
        "keychainEvidence": "Fixtures/Modernization/ios-migration-keychain-evidence.json",
        "deviceExecutionEvidence": "Fixtures/Modernization/ios-migration-device-execution-evidence.json",
    }
    if type(blocked["artifacts"]) is not dict or set(blocked["artifacts"]) != set(
        expected_artifact_paths
    ):
        fail("blocked collection receipt artifact inventory changed")
    for key, expected_path in expected_artifact_paths.items():
        artifact = blocked["artifacts"][key]
        if (
            type(artifact) is not dict
            or set(artifact) != {"relativePath", "sha256", "byteCount"}
            or artifact["relativePath"] != expected_path
            or artifact["sha256"] is not None
            or type(artifact["byteCount"]) is not int
            or artifact["byteCount"] != 0
        ):
            fail("blocked collection receipt contains materialized artifact evidence")
    checks = blocked["checks"]
    if (
        type(checks) is not dict
        or checks.get("collectorNonAuthorizing") is not True
        or any(value is not False for key, value in checks.items() if key != "collectorNonAuthorizing")
    ):
        fail("blocked collection receipt contains a qualifying check")
    raw_input = blocked["rawInputSet"]
    identity = blocked["identity"]
    tested = blocked["testedApplication"]
    toolchain = blocked["toolchain"]
    if (
        not exact_typed_equal(raw_input, {
            "contractId": "sora-ios-wallet-migration-raw-input-set-v3",
            "sha256": None,
            "fileCount": 0,
            "byteCount": 0,
        })
        or not exact_typed_equal(identity, {
            "productionIpaSha256": None,
            "installedAppRawTreeSha256": None,
            "installedAppRawTreeRecordByteCount": 0,
            "installedExecutableSha256": None,
            "installedExecutableByteCount": 0,
            "productionCanonicalProjectionSha256": None,
            "installedCanonicalProjectionSha256": None,
            "canonicalProjectionReceiptSha256": None,
            "canonicalProjectorSourceSha256": None,
            "deviceClasses": [],
            "operatingSystemBuilds": [],
        })
        or not exact_typed_equal(
            toolchain,
            {"xcodeBuildVersion": None, "xcresultFormatVersion": None},
        )
        or not exact_typed_equal(tested, {
            "sha256": None,
            "byteCount": 0,
            "bundleIdentifier": None,
            "shortVersion": None,
            "buildVersion": None,
            "executableSha256": None,
            "executableByteCount": 0,
            "productionCodeSignatureVerified": False,
            "productionApplicationIdentifierVerified": False,
            "productionTeamIdentifierVerified": False,
            "productionKeychainAccessGroupVerified": False,
        })
        or not exact_typed_equal(blocked["installedClone"], {
            "receiptSha256": None,
            "rawTreeSha256": None,
            "rawTreeRecordByteCount": 0,
            "executableSha256": None,
            "executableByteCount": 0,
            "productionCanonicalProjectionSha256": None,
            "installedCanonicalProjectionSha256": None,
            "canonicalProjectionReceiptSha256": None,
            "canonicalProjectorSourceSha256": None,
            "codeSignatureDeepStrictVerified": False,
            "installedAppLaunchVerified": False,
            "installedRawTreeRecomputed": False,
            "installedExecutableRecomputed": False,
            "canonicalProjectionEqualToProduction": False,
        })
    ):
        fail("blocked collection receipt contains materialized run identity")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--lint-contract", action="store_true")
    modes.add_argument("--collect", action="store_true")
    parser.add_argument("--input-root")
    parser.add_argument("--output-root")
    args = parser.parse_args(argv)
    if args.collect and (not args.input_root or not args.output_root):
        parser.error("--collect requires --input-root and --output-root")
    if args.lint_contract and (args.input_root or args.output_root):
        parser.error("--lint-contract accepts no input/output roots")
    return args


def main(argv: list[str]) -> int:
    try:
        args = parse_args(argv)
        if args.lint_contract:
            lint_contract()
            print("iOS migration raw-evidence collector contract: OK")
            return 0
        result = collect(Path(args.input_root), Path(args.output_root))
        print(json.dumps(result, sort_keys=True, separators=(",", ":")))
        return 0
    except CollectionError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
