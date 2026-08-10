#!/usr/bin/env python3
"""Fail-closed phase controller for one immutable iOS production candidate.

This source never owns credentials, private keys, signatures, App Store state, or
retained-device evidence.  It composes the checked-in validators with three
externally deployed, independently pinned executables.  Each invocation performs
one exact phase and advances an owner-only local state ledger only after success.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import stat
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "SoraPassport" / "Scripts"
SOURCE_GATE = SCRIPTS / "verify-modernization-dependencies.sh"
RELEASE_TESTS = SCRIPTS / "run-ios-release-tests.sh"
ARCHIVER = SCRIPTS / "archive-ios-migration-candidate.sh"
RELEASE_PACKAGE = SCRIPTS / "verify-ios-release-reproducibility-package.py"
QUALIFICATION = SCRIPTS / "verify-ios-migration-qualification.sh"
PROMOTION_ADMISSION = SCRIPTS / "verify-ios-migration-promotion-ipa.sh"
ROLLOUT_GATE = SCRIPTS / "verify-production-rollout.sh"
ROLLOUT_JSON = SCRIPTS / "verify-production-rollout-json.py"
TAIRA_ADMISSION = SCRIPTS / "verify-ios-taira-deployment-manifest.py"
TRUST_ROOT_RELATIVE = Path(
    "Fixtures/Modernization/production-rollout-controller-trust.json"
)
QUALIFICATION_RECEIPT_RELATIVE = Path(
    "Fixtures/Modernization/ios-migration-qualification.json"
)

CONTRACT_ID = "sora-ios-production-promotion-controller-v1"
LOWER_BOUND_CONTRACT_ID = "sora-ios-app-store-build-lower-bound-v1"
MUTATION_CONTRACT_ID = "sora-ios-app-store-distribution-mutation-v1"
BUNDLE_IDENTIFIER = "co.jp.soramitsu.sora"
CONTROLLER_ENVIRONMENTS = {
    "appStore": (
        "IOS_PRODUCTION_APP_STORE_CONTROLLER_PATH",
        "IOS_PRODUCTION_APP_STORE_CONTROLLER_SHA256",
    ),
    "retainedDevice": (
        "IOS_PRODUCTION_RETAINED_DEVICE_CONTROLLER_PATH",
        "IOS_PRODUCTION_RETAINED_DEVICE_CONTROLLER_SHA256",
    ),
    "distribution": (
        "IOS_PRODUCTION_DISTRIBUTION_CONTROLLER_PATH",
        "IOS_PRODUCTION_DISTRIBUTION_CONTROLLER_SHA256",
    ),
}
ROLE_NAMES = ("primary", "reproduction")
ROLLOUT_TARGETS = (1, 5, 25, 100)
EXECUTED_SOURCE_RELATIVES = (
    Path("SoraPassport/Scripts/run-ios-production-promotion.py"),
    Path("SoraPassport/Scripts/verify-modernization-dependencies.sh"),
    Path("SoraPassport/Scripts/run-ios-release-tests.sh"),
    Path("SoraPassport/Scripts/archive-ios-migration-candidate.sh"),
    Path("SoraPassport/Scripts/verify-ios-release-reproducibility-package.py"),
    Path("SoraPassport/Scripts/verify-ios-migration-qualification.sh"),
    Path("SoraPassport/Scripts/verify-ios-migration-qualification.py"),
    Path("SoraPassport/Scripts/verify-ios-migration-promotion-ipa.sh"),
    Path("SoraPassport/Scripts/verify-production-rollout.sh"),
    Path("SoraPassport/Scripts/verify-production-rollout-json.py"),
)
QUALIFICATION_OVERLAY_RELATIVES = (
    Path("Fixtures/Modernization/ios-migration-qualification.json"),
    Path("Fixtures/Modernization/ios-migration-qualification-evidence.json"),
    Path("Fixtures/Modernization/ios-migration-qualification-trust.json"),
)
MAX_FILE_BYTES = 4 * 1024 * 1024 * 1024
MAX_JSON_BYTES = 1024 * 1024
MAX_SIGNATURE_BYTES = 4096
MAX_CONTROLLER_BYTES = 64 * 1024 * 1024
MAX_CLOCK_SKEW_SECONDS = 30
MAX_CONTROLLER_OBSERVATION_AGE_SECONDS = 300
REVISION_RE = re.compile(r"^[0-9a-f]{40}$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
BUILD_RE = re.compile(r"^[1-9][0-9]{0,17}$")


class PromotionError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise PromotionError(message)


def exact_keys(value: Any, expected: set[str], label: str) -> dict[str, Any]:
    if type(value) is not dict or set(value) != expected:
        fail(f"{label} has an unexpected shape")
    return value


def duplicate_rejecting_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            fail(f"JSON contains duplicate key {key!r}")
        result[key] = value
    return result


def reject_float(raw: str) -> float:
    fail(f"JSON contains forbidden floating-point token {raw!r}")


def reject_constant(raw: str) -> float:
    fail(f"JSON contains forbidden non-finite token {raw!r}")


def canonical_json(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode(
        "utf-8"
    )


def parse_canonical_json(raw: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(
            raw.decode("utf-8", errors="strict"),
            object_pairs_hook=duplicate_rejecting_object,
            parse_int=lambda token: (
                fail("JSON contains negative zero")
                if token == "-0"
                else int(token)
            ),
            parse_float=reject_float,
            parse_constant=reject_constant,
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fail(f"{label} is invalid JSON: {error}")
    if type(value) is not dict or canonical_json(value) != raw:
        fail(f"{label} is not one canonical JSON object")
    return value


def require_revision(value: Any, label: str = "source revision") -> str:
    if type(value) is not str or REVISION_RE.fullmatch(value) is None or value == "0" * 40:
        fail(f"{label} is not one nonzero lowercase commit ID")
    return value


def require_sha256(value: Any, label: str) -> str:
    if type(value) is not str or SHA256_RE.fullmatch(value) is None or value == "0" * 64:
        fail(f"{label} is not one nonzero lowercase SHA-256")
    return value


def require_build_number(value: Any, label: str) -> str:
    if type(value) is not str or BUILD_RE.fullmatch(value) is None:
        fail(f"{label} is not one positive canonical decimal build number")
    return value


def upload_idempotency_key(build_number: str, ipa_sha256: str) -> str:
    require_build_number(build_number, "candidate build number")
    require_sha256(ipa_sha256, "candidate IPA")
    projection = (
        f"bundleIdentifier={BUNDLE_IDENTIFIER}\n"
        f"buildNumber={build_number}\n"
        f"ipaSha256={ipa_sha256}"
    ).encode("utf-8")
    return hashlib.sha256(projection).hexdigest()


def canonical_absolute(raw: str, label: str, *, must_exist: bool = True) -> Path:
    path = Path(raw)
    if (
        not path.is_absolute()
        or str(path) != raw
        or raw == "/"
        or any(part in ("", ".", "..") for part in path.parts[1:])
    ):
        fail(f"{label} must be one canonical absolute non-root path")
    try:
        resolved = path.resolve(strict=must_exist)
    except OSError as error:
        fail(f"{label} cannot be resolved canonically: {error}")
    if resolved != path:
        fail(f"{label} contains a symbolic or noncanonical component")
    return path


def inside(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def require_private_parent(path: Path, label: str) -> Path:
    parent = canonical_absolute(str(path.parent), f"{label} parent")
    metadata = parent.stat()
    if (
        not stat.S_ISDIR(metadata.st_mode)
        or metadata.st_uid != os.getuid()
        or stat.S_IMODE(metadata.st_mode) != 0o700
    ):
        fail(f"{label} parent must be current-user-owned mode 0700")
    return parent


def stable_read(path: Path, maximum: int, label: str) -> tuple[bytes, os.stat_result]:
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    try:
        descriptor = os.open(path, flags)
    except OSError as error:
        fail(f"{label} cannot be opened without following links: {error}")
    try:
        before = os.fstat(descriptor)
        if (
            not stat.S_ISREG(before.st_mode)
            or before.st_nlink != 1
            or before.st_size <= 0
            or before.st_size > maximum
        ):
            fail(f"{label} is not one bounded unique regular file")
        chunks: list[bytes] = []
        total = 0
        while True:
            chunk = os.read(descriptor, min(1024 * 1024, maximum - total + 1))
            if not chunk:
                break
            chunks.append(chunk)
            total += len(chunk)
            if total > maximum:
                fail(f"{label} exceeds its byte bound")
        after = os.fstat(descriptor)
        identity = lambda item: (
            item.st_dev,
            item.st_ino,
            item.st_mode,
            item.st_nlink,
            item.st_size,
            item.st_mtime_ns,
        )
        if total != before.st_size or identity(before) != identity(after):
            fail(f"{label} changed while it was read")
        return b"".join(chunks), after
    finally:
        os.close(descriptor)


def stable_hash(path: Path, maximum: int, label: str) -> tuple[str, int, os.stat_result]:
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    try:
        descriptor = os.open(path, flags)
    except OSError as error:
        fail(f"{label} cannot be opened without following links: {error}")
    try:
        before = os.fstat(descriptor)
        if (
            not stat.S_ISREG(before.st_mode)
            or before.st_nlink != 1
            or before.st_size <= 0
            or before.st_size > maximum
        ):
            fail(f"{label} is not one bounded unique regular file")
        digest = hashlib.sha256()
        total = 0
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
            total += len(chunk)
            if total > maximum:
                fail(f"{label} exceeds its byte bound")
        after = os.fstat(descriptor)
        identity = lambda item: (
            item.st_dev,
            item.st_ino,
            item.st_mode,
            item.st_nlink,
            item.st_size,
            item.st_mtime_ns,
        )
        if total != before.st_size or identity(before) != identity(after):
            fail(f"{label} changed while it was hashed")
        return digest.hexdigest(), total, after
    finally:
        os.close(descriptor)


def file_record(path: Path, maximum: int, label: str) -> dict[str, Any]:
    canonical_absolute(str(path), label)
    digest, byte_count, metadata = stable_hash(path, maximum, label)
    return {
        "path": str(path),
        "sha256": digest,
        "byteCount": byte_count,
        "device": metadata.st_dev,
        "inode": metadata.st_ino,
        "mtimeNanoseconds": metadata.st_mtime_ns,
    }


def verify_file_record(record: Any, maximum: int, label: str) -> Path:
    item = exact_keys(
        record,
        {"path", "sha256", "byteCount", "device", "inode", "mtimeNanoseconds"},
        label,
    )
    if type(item["path"]) is not str:
        fail(f"{label} path is invalid")
    require_sha256(item["sha256"], f"{label} SHA-256")
    if any(type(item[key]) is not int or item[key] <= 0 for key in (
        "byteCount", "device", "inode", "mtimeNanoseconds"
    )):
        fail(f"{label} physical identity is invalid")
    path = canonical_absolute(item["path"], f"{label} path")
    if file_record(path, maximum, label) != item:
        fail(f"{label} changed or was rebound")
    return path


def directory_record(path: Path, label: str) -> dict[str, Any]:
    canonical_absolute(str(path), label)
    metadata = os.lstat(path)
    if not stat.S_ISDIR(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode):
        fail(f"{label} is not one non-symbolic directory")
    return {"path": str(path), "device": metadata.st_dev, "inode": metadata.st_ino}


def verify_directory_record(record: Any, label: str) -> Path:
    item = exact_keys(record, {"path", "device", "inode"}, label)
    if type(item["path"]) is not str or any(
        type(item[key]) is not int or item[key] <= 0 for key in ("device", "inode")
    ):
        fail(f"{label} identity is invalid")
    path = canonical_absolute(item["path"], label)
    if directory_record(path, label) != item:
        fail(f"{label} changed or was rebound")
    return path


def git_output(checkout: Path, arguments: list[str], label: str) -> str:
    try:
        result = subprocess.run(
            ["/usr/bin/git", "-C", str(checkout), *arguments],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=30,
        )
    except subprocess.SubprocessError as error:
        fail(f"{label} failed: {error}")
    return result.stdout.rstrip("\r\n")


def verify_clean_checkout(path: Path, revision: str, label: str) -> dict[str, Any]:
    path = canonical_absolute(str(path), label)
    if git_output(path, ["rev-parse", "--show-toplevel"], label) != str(path):
        fail(f"{label} is not an exact checkout root")
    if git_output(path, ["rev-parse", "--verify", "HEAD^{commit}"], label) != revision:
        fail(f"{label} names a different source revision")
    if git_output(path, ["status", "--porcelain=v1", "--untracked-files=normal"], label):
        fail(f"{label} is not completely clean")
    return directory_record(path, label)


def capture_executed_sources(checkout: Path, label: str) -> dict[str, Any]:
    return {
        relative.as_posix(): file_record(
            checkout / relative,
            MAX_CONTROLLER_BYTES,
            f"{label} executed source {relative.as_posix()}",
        )
        for relative in EXECUTED_SOURCE_RELATIVES
    }


def verify_executed_sources(checkout: Path, records: Any, label: str) -> None:
    expected = {relative.as_posix() for relative in EXECUTED_SOURCE_RELATIVES}
    item = exact_keys(records, expected, f"{label} executed sources")
    for relative in EXECUTED_SOURCE_RELATIVES:
        observed = verify_file_record(
            item[relative.as_posix()],
            MAX_CONTROLLER_BYTES,
            f"{label} executed source {relative.as_posix()}",
        )
        if observed != checkout / relative:
            fail(f"{label} executed source path was rebound")


def checkout_status_entries(checkout: Path, label: str) -> dict[str, str]:
    output = git_output(
        checkout,
        ["status", "--porcelain=v1", "--untracked-files=normal"],
        label,
    )
    result: dict[str, str] = {}
    if not output:
        return result
    for line in output.splitlines():
        if len(line) < 4 or line[2] != " " or " -> " in line:
            fail(f"{label} has an ambiguous changed-path record")
        status_value = line[:2]
        relative = line[3:]
        if status_value not in ("??", " M", "M ") or relative in result:
            fail(f"{label} has an unauthorized checkout change")
        result[relative] = status_value
    return result


def capture_qualification_overlay(checkout: Path) -> dict[str, Any]:
    allowed = {relative.as_posix() for relative in QUALIFICATION_OVERLAY_RELATIVES}
    observed = checkout_status_entries(checkout, "primary checkout")
    if not set(observed).issubset(allowed):
        fail("retained-device qualification changed a non-evidence checkout path")
    return {
        relative.as_posix(): file_record(
            checkout / relative,
            MAX_JSON_BYTES,
            f"qualified evidence overlay {relative.as_posix()}",
        )
        for relative in QUALIFICATION_OVERLAY_RELATIVES
    }


def verify_qualification_overlay(checkout: Path, records: Any) -> None:
    allowed = {relative.as_posix() for relative in QUALIFICATION_OVERLAY_RELATIVES}
    item = exact_keys(records, allowed, "qualified evidence overlay")
    observed = checkout_status_entries(checkout, "primary checkout")
    if not set(observed).issubset(allowed):
        fail("primary checkout contains drift outside the signed qualification overlay")
    for relative in QUALIFICATION_OVERLAY_RELATIVES:
        path = verify_file_record(
            item[relative.as_posix()],
            MAX_JSON_BYTES,
            f"qualified evidence overlay {relative.as_posix()}",
        )
        if path != checkout / relative:
            fail("qualified evidence overlay path was rebound")


def verify_post_qualification_checkouts(state: dict[str, Any]) -> None:
    primary = verify_directory_record(state["checkouts"]["primary"], "primary checkout")
    reproduction = verify_directory_record(
        state["checkouts"]["reproduction"], "reproduction checkout"
    )
    verify_executed_sources(primary, state["executedSources"]["primary"], "primary")
    verify_executed_sources(
        reproduction, state["executedSources"]["reproduction"], "reproduction"
    )
    verify_qualification_overlay(
        primary, state["qualifiedPackage"]["qualificationEvidenceOverlay"]
    )
    current = verify_clean_checkout(
        reproduction, state["sourceRevision"], "reproduction checkout"
    )
    if current != state["checkouts"]["reproduction"]:
        fail("reproduction checkout changed after qualification")


def inspect_controller(path_raw: str, pin: str, label: str) -> dict[str, Any]:
    require_sha256(pin, f"{label} executable pin")
    path = canonical_absolute(path_raw, f"{label} executable")
    if inside(path, ROOT):
        fail(f"{label} executable must remain outside the source repository")
    raw, metadata = stable_read(path, MAX_CONTROLLER_BYTES, f"{label} executable")
    if not stat.S_ISREG(metadata.st_mode) or not os.access(path, os.X_OK):
        fail(f"{label} executable is not one regular executable")
    if metadata.st_uid not in (0, os.getuid()) or stat.S_IMODE(metadata.st_mode) & 0o022:
        fail(f"{label} executable is not protected from group/world mutation")
    digest = hashlib.sha256(raw).hexdigest()
    if digest != pin:
        fail(f"{label} executable differs from its protected SHA-256 pin")
    return {
        "path": str(path),
        "sha256": digest,
        "byteCount": len(raw),
        "device": metadata.st_dev,
        "inode": metadata.st_ino,
        "mtimeNanoseconds": metadata.st_mtime_ns,
    }


def controller_from_environment(role: str) -> dict[str, Any]:
    path_name, pin_name = CONTROLLER_ENVIRONMENTS[role]
    path = os.environ.get(path_name, "")
    pin = os.environ.get(pin_name, "")
    if not path or not pin:
        fail(f"protected {role} controller path and SHA-256 pin are required")
    return inspect_controller(path, pin, role)


def verify_controller_record(record: Any, role: str) -> Path:
    item = exact_keys(
        record,
        {"path", "sha256", "byteCount", "device", "inode", "mtimeNanoseconds"},
        f"{role} controller record",
    )
    current = controller_from_environment(role)
    if current != item:
        fail(f"protected {role} controller identity drifted after initialization")
    return Path(item["path"])


def run_external_controller(
    state: dict[str, Any], role: str, arguments: list[str]
) -> None:
    executable = verify_controller_record(state["controllers"][role], role)
    subprocess.run([str(executable), *arguments], check=True, close_fds=True)
    if controller_from_environment(role) != state["controllers"][role]:
        fail(f"protected {role} controller changed during execution")


def run_checked(arguments: list[str], *, env: dict[str, str] | None = None) -> str:
    result = subprocess.run(
        arguments,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        env=env,
        close_fds=True,
    )
    return result.stdout.strip()


def empty_state(
    source_revision: str,
    build_number: str,
    lower_bound: str,
    lower_bound_receipt: dict[str, Any],
    controllers: dict[str, Any],
    checkouts: dict[str, Any],
    executed_sources: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "contractId": CONTRACT_ID,
        "sourceRevision": source_revision,
        "buildNumber": build_number,
        "appStoreBuildNumberLowerBound": lower_bound,
        "lowerBoundReceipt": lower_bound_receipt,
        "controllers": controllers,
        "checkouts": checkouts,
        "executedSources": executed_sources or {role: {} for role in ROLE_NAMES},
        "releaseTests": {},
        "builds": {},
        "equivalenceReceipt": None,
        "qualifiedPackage": None,
        "postUploadArtifact": None,
        "rollouts": [],
    }


STATE_KEYS = {
    "schemaVersion",
    "contractId",
    "sourceRevision",
    "buildNumber",
    "appStoreBuildNumberLowerBound",
    "lowerBoundReceipt",
    "controllers",
    "checkouts",
    "executedSources",
    "releaseTests",
    "builds",
    "equivalenceReceipt",
    "qualifiedPackage",
    "postUploadArtifact",
    "rollouts",
}


def validate_state(value: Any) -> dict[str, Any]:
    state = exact_keys(value, STATE_KEYS, "promotion state")
    if state["schemaVersion"] != 1 or state["contractId"] != CONTRACT_ID:
        fail("promotion state contract is incompatible")
    require_revision(state["sourceRevision"])
    require_build_number(state["buildNumber"], "candidate build number")
    require_build_number(
        state["appStoreBuildNumberLowerBound"], "App Store build lower bound"
    )
    if int(state["buildNumber"]) <= int(state["appStoreBuildNumberLowerBound"]):
        fail("candidate build number is not newer than its App Store lower bound")
    exact_keys(state["controllers"], set(CONTROLLER_ENVIRONMENTS), "controllers")
    exact_keys(state["checkouts"], set(ROLE_NAMES), "checkouts")
    exact_keys(state["executedSources"], set(ROLE_NAMES), "executed sources")
    if type(state["releaseTests"]) is not dict or not set(state["releaseTests"]).issubset(ROLE_NAMES):
        fail("promotion state Release-test roles are invalid")
    if type(state["builds"]) is not dict or not set(state["builds"]).issubset(ROLE_NAMES):
        fail("promotion state build roles are invalid")
    if not set(state["builds"]).issubset(state["releaseTests"]):
        fail("promotion state records a build before full Release tests")
    if state["equivalenceReceipt"] is not None and set(state["builds"]) != set(ROLE_NAMES):
        fail("promotion state records equivalence without both exact builds")
    if state["qualifiedPackage"] is not None and state["equivalenceReceipt"] is None:
        fail("promotion state records qualification before reproduction")
    if state["qualifiedPackage"] is not None:
        qualified = exact_keys(
            state["qualifiedPackage"],
            {
                "package",
                "qualificationReceiptSha256",
                "ipaSha256",
                "qualificationEvidenceOverlay",
            },
            "qualified package state",
        )
        require_sha256(
            qualified["qualificationReceiptSha256"], "qualification receipt"
        )
        require_sha256(qualified["ipaSha256"], "qualified IPA")
        exact_keys(
            qualified["qualificationEvidenceOverlay"],
            {relative.as_posix() for relative in QUALIFICATION_OVERLAY_RELATIVES},
            "qualified evidence overlay",
        )
    if state["postUploadArtifact"] is not None and state["qualifiedPackage"] is None:
        fail("promotion state records upload before exact-IPA qualification")
    if state["postUploadArtifact"] is not None:
        exact_keys(
            state["postUploadArtifact"],
            {"receipt", "signature"},
            "post-upload artifact state",
        )
    if type(state["rollouts"]) is not list:
        fail("promotion rollout state is not an ordered list")
    observed_targets = [item.get("targetPercent") if type(item) is dict else None for item in state["rollouts"]]
    if observed_targets != list(ROLLOUT_TARGETS[: len(observed_targets)]):
        fail("promotion rollout targets are missing, duplicated, or out of order")
    if state["rollouts"] and state["postUploadArtifact"] is None:
        fail("promotion state records distribution before authenticated upload")
    for index, rollout in enumerate(state["rollouts"]):
        exact_keys(
            rollout,
            {"targetPercent", "rolloutReceipt", "rolloutSignature", "mutationReceipt"},
            f"rollout state {index}",
        )
    return state


def state_path(raw: str, *, must_exist: bool) -> Path:
    path = canonical_absolute(raw, "promotion state", must_exist=must_exist)
    require_private_parent(path, "promotion state")
    if inside(path, ROOT):
        fail("promotion state must remain outside the source repository")
    return path


def load_state(raw: str) -> tuple[Path, dict[str, Any]]:
    path = state_path(raw, must_exist=True)
    content, metadata = stable_read(path, MAX_JSON_BYTES, "promotion state")
    if stat.S_IMODE(metadata.st_mode) != 0o600 or metadata.st_uid != os.getuid():
        fail("promotion state must be current-user-owned mode 0600")
    state = validate_state(parse_canonical_json(content, "promotion state"))
    for role in CONTROLLER_ENVIRONMENTS:
        verify_controller_record(state["controllers"][role], role)
    for role in ROLE_NAMES:
        checkout = verify_directory_record(state["checkouts"][role], f"{role} checkout")
        verify_executed_sources(checkout, state["executedSources"][role], role)
        if role == "primary" and state["qualifiedPackage"] is not None:
            verify_qualification_overlay(
                checkout,
                state["qualifiedPackage"]["qualificationEvidenceOverlay"],
            )
        else:
            current = verify_clean_checkout(
                checkout, state["sourceRevision"], f"{role} checkout"
            )
            if current != state["checkouts"][role]:
                fail(f"{role} checkout changed after initialization")
    if state["qualifiedPackage"] is not None:
        verify_file_record(
            state["qualifiedPackage"]["package"],
            MAX_FILE_BYTES,
            "qualified-IPA package",
        )
    if state["postUploadArtifact"] is not None:
        verify_file_record(
            state["postUploadArtifact"]["receipt"],
            MAX_JSON_BYTES,
            "post-upload artifact receipt",
        )
        verify_file_record(
            state["postUploadArtifact"]["signature"],
            MAX_SIGNATURE_BYTES,
            "post-upload artifact signature",
        )
    for index, rollout in enumerate(state["rollouts"]):
        verify_file_record(
            rollout["rolloutReceipt"], MAX_JSON_BYTES, f"rollout {index} receipt"
        )
        verify_file_record(
            rollout["rolloutSignature"],
            MAX_SIGNATURE_BYTES,
            f"rollout {index} signature",
        )
        verify_file_record(
            rollout["mutationReceipt"],
            MAX_JSON_BYTES,
            f"rollout {index} mutation receipt",
        )
    return path, state


def write_state(path: Path, state: dict[str, Any], *, fresh: bool = False) -> None:
    validate_state(state)
    raw = canonical_json(state)
    temporary = path.parent / f".{path.name}.new"
    if temporary.exists() or temporary.is_symlink():
        fail("promotion state temporary path is not fresh")
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(temporary, flags, 0o600)
    try:
        os.write(descriptor, raw)
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    if fresh and (path.exists() or path.is_symlink()):
        temporary.unlink()
        fail("promotion state already exists; candidate creation is one-shot")
    os.replace(temporary, path)
    os.chmod(path, 0o600)


def parse_lower_bound_receipt(
    path: Path,
    *,
    source_revision: str,
    controller_sha256: str,
    now: int | None = None,
) -> str:
    raw, _ = stable_read(path, MAX_JSON_BYTES, "App Store lower-bound receipt")
    value = exact_keys(
        parse_canonical_json(raw, "App Store lower-bound receipt"),
        {
            "schemaVersion",
            "contractId",
            "status",
            "bundleIdentifier",
            "sourceRevision",
            "lowerBound",
            "queriedAtEpochSeconds",
            "controllerExecutableSha256",
        },
        "App Store lower-bound receipt",
    )
    if (
        value["schemaVersion"] != 1
        or value["contractId"] != LOWER_BOUND_CONTRACT_ID
        or value["status"] != "observed"
        or value["bundleIdentifier"] != BUNDLE_IDENTIFIER
        or value["sourceRevision"] != source_revision
        or value["controllerExecutableSha256"] != controller_sha256
    ):
        fail("App Store lower-bound receipt differs from this exact controller query")
    lower_bound = require_build_number(value["lowerBound"], "App Store build lower bound")
    captured = value["queriedAtEpochSeconds"]
    evaluated = int(time.time()) if now is None else now
    if (
        type(captured) is not int
        or captured > evaluated + MAX_CLOCK_SKEW_SECONDS
        or evaluated - captured > MAX_CONTROLLER_OBSERVATION_AGE_SECONDS
    ):
        fail("App Store build lower bound is not a fresh controller observation")
    return lower_bound


def initialize(
    state_raw: str,
    primary_raw: str,
    reproduction_raw: str,
    source_revision: str,
    build_number: str,
) -> None:
    source_revision = require_revision(source_revision)
    build_number = require_build_number(build_number, "candidate build number")
    path = state_path(state_raw, must_exist=False)
    if path.exists() or path.is_symlink():
        fail("promotion state already exists; candidate creation is one-shot")
    checkouts = {
        "primary": verify_clean_checkout(
            canonical_absolute(primary_raw, "primary checkout"),
            source_revision,
            "primary checkout",
        ),
        "reproduction": verify_clean_checkout(
            canonical_absolute(reproduction_raw, "reproduction checkout"),
            source_revision,
            "reproduction checkout",
        ),
    }
    if (
        checkouts["primary"]["path"] == checkouts["reproduction"]["path"]
        or (
            checkouts["primary"]["device"], checkouts["primary"]["inode"]
        )
        == (
            checkouts["reproduction"]["device"],
            checkouts["reproduction"]["inode"],
        )
    ):
        fail("primary and reproduction checkouts are not physically distinct")
    controllers = {
        role: controller_from_environment(role) for role in CONTROLLER_ENVIRONMENTS
    }
    executed_sources = {
        role: capture_executed_sources(Path(checkouts[role]["path"]), role)
        for role in ROLE_NAMES
    }
    lower_bound_path = path.parent / "app-store-build-lower-bound.json"
    if lower_bound_path.exists() or lower_bound_path.is_symlink():
        fail("App Store lower-bound receipt path must be fresh")
    provisional = empty_state(
        source_revision,
        build_number,
        "1",
        {},
        controllers,
        checkouts,
        executed_sources,
    )
    run_external_controller(
        provisional,
        "appStore",
        [
            "query-build-lower-bound",
            "--bundle-identifier",
            BUNDLE_IDENTIFIER,
            "--source-revision",
            source_revision,
            "--output-receipt",
            str(lower_bound_path),
        ],
    )
    lower_bound = parse_lower_bound_receipt(
        canonical_absolute(str(lower_bound_path), "App Store lower-bound receipt"),
        source_revision=source_revision,
        controller_sha256=controllers["appStore"]["sha256"],
    )
    if int(build_number) <= int(lower_bound):
        fail("explicit candidate build number is not newer than the controller-provided App Store lower bound")
    state = empty_state(
        source_revision,
        build_number,
        lower_bound,
        file_record(lower_bound_path, MAX_JSON_BYTES, "App Store lower-bound receipt"),
        controllers,
        checkouts,
        executed_sources,
    )
    write_state(path, state, fresh=True)


def role_output_parent(state_path_value: Path, role: str, *, create: bool) -> Path:
    parent = state_path_value.parent / f"{role}-outputs"
    if create:
        if parent.exists() or parent.is_symlink():
            fail(f"{role} output namespace is not fresh")
        os.mkdir(parent, 0o700)
    return canonical_absolute(str(parent), f"{role} output namespace")


def phase_release_tests(state_raw: str, role: str, destination: str) -> None:
    if role not in ROLE_NAMES:
        fail("Release-test role must be primary or reproduction")
    path, state = load_state(state_raw)
    if state["releaseTests"] or state["builds"] or state["equivalenceReceipt"] is not None:
        expected = ROLE_NAMES[len(state["releaseTests"])] if len(state["releaseTests"]) < 2 else None
        if role != expected or state["builds"] or state["equivalenceReceipt"] is not None:
            fail("full Release tests are duplicated or out of phase")
    elif role != "primary":
        fail("primary full Release tests must run first")
    checkout = verify_directory_record(state["checkouts"][role], f"{role} checkout")
    output = role_output_parent(path, role, create=True)
    derived_data = output / "release-tests-DerivedData"
    result_bundle = output / "SoraPassport-Release.xcresult"
    run_checked(
        [
            "/bin/sh",
            str(checkout / SOURCE_GATE.relative_to(ROOT)),
            "--lint-ios-migration-release-source-gate",
        ]
    )
    run_checked(
        [
            "/bin/sh",
            str(checkout / RELEASE_TESTS.relative_to(ROOT)),
            "--test",
            "--destination",
            destination,
            "--derived-data-path",
            str(derived_data),
            "--result-bundle-path",
            str(result_bundle),
        ]
    )
    current = verify_clean_checkout(checkout, state["sourceRevision"], f"{role} checkout")
    if current != state["checkouts"][role]:
        fail(f"{role} checkout physical identity changed during Release tests")
    state["releaseTests"][role] = {
        "resultBundle": directory_record(result_bundle, f"{role} Release result bundle"),
        "derivedData": directory_record(derived_data, f"{role} Release DerivedData"),
    }
    write_state(path, state)


def unique_exported_ipa(export: Path, label: str) -> Path:
    candidates = []
    for child in export.iterdir():
        if child.is_symlink():
            fail(f"{label} export contains a symbolic entry")
        if child.is_file() and child.suffix == ".ipa":
            candidates.append(child)
    if len(candidates) != 1:
        fail(f"{label} export does not contain exactly one regular IPA")
    return canonical_absolute(str(candidates[0]), f"{label} IPA")


def phase_archive(state_raw: str, role: str) -> None:
    if role not in ROLE_NAMES:
        fail("archive role must be primary or reproduction")
    path, state = load_state(state_raw)
    expected = ROLE_NAMES[len(state["builds"])] if len(state["builds"]) < 2 else None
    if role != expected or role not in state["releaseTests"] or state["equivalenceReceipt"] is not None:
        fail("candidate archive is duplicated, unordered, or lacks full Release tests")
    checkout = verify_directory_record(state["checkouts"][role], f"{role} checkout")
    output = role_output_parent(path, role, create=False)
    derived_data = output / "archive-DerivedData"
    archive = output / f"{role}.xcarchive"
    export = output / f"{role}-export"
    environment = dict(os.environ)
    environment["IOS_APP_STORE_BUILD_NUMBER_LOWER_BOUND"] = state[
        "appStoreBuildNumberLowerBound"
    ]
    if environment.get("IOS_MIGRATION_EVIDENCE_SOURCE_REVISION") != state["sourceRevision"]:
        fail("protected migration evidence source revision differs from the candidate")
    run_checked(
        [
            "/bin/sh",
            str(checkout / ARCHIVER.relative_to(ROOT)),
            "--archive-and-export-reproducible",
            "--role",
            role,
            "--build-number",
            state["buildNumber"],
            "--derived-data-path",
            str(derived_data),
            "--archive-path",
            str(archive),
            "--export-path",
            str(export),
        ],
        env=environment,
    )
    ipa = unique_exported_ipa(export, role)
    control = Path(f"{archive}.observed-control")
    manifest = control / f"{role}-build-manifest.json"
    taira = control / "taira-deployment-admission.json"
    current = verify_clean_checkout(checkout, state["sourceRevision"], f"{role} checkout")
    if current != state["checkouts"][role]:
        fail(f"{role} checkout changed during its one authorized archive")
    state["builds"][role] = {
        "derivedData": directory_record(derived_data, f"{role} archive DerivedData"),
        "archive": directory_record(archive, f"{role} archive"),
        "export": directory_record(export, f"{role} export"),
        "ipa": file_record(ipa, MAX_FILE_BYTES, f"{role} IPA"),
        "buildManifest": file_record(manifest, MAX_JSON_BYTES, f"{role} build manifest"),
        "tairaAdmission": file_record(taira, MAX_JSON_BYTES, f"{role} Taira admission"),
    }
    write_state(path, state)


def verify_build_records(state: dict[str, Any]) -> dict[str, dict[str, Path]]:
    if set(state["builds"]) != set(ROLE_NAMES):
        fail("both one-shot candidate builds are required")
    result: dict[str, dict[str, Path]] = {}
    for role in ROLE_NAMES:
        build = exact_keys(
            state["builds"][role],
            {"derivedData", "archive", "export", "ipa", "buildManifest", "tairaAdmission"},
            f"{role} build state",
        )
        result[role] = {
            "derivedData": verify_directory_record(build["derivedData"], f"{role} archive DerivedData"),
            "archive": verify_directory_record(build["archive"], f"{role} archive"),
            "export": verify_directory_record(build["export"], f"{role} export"),
            "ipa": verify_file_record(build["ipa"], MAX_FILE_BYTES, f"{role} IPA"),
            "buildManifest": verify_file_record(build["buildManifest"], MAX_JSON_BYTES, f"{role} build manifest"),
            "tairaAdmission": verify_file_record(build["tairaAdmission"], MAX_JSON_BYTES, f"{role} Taira admission"),
        }
    return result


def phase_compare(state_raw: str) -> None:
    path, state = load_state(state_raw)
    if state["equivalenceReceipt"] is not None or state["qualifiedPackage"] is not None:
        fail("Release reproduction comparison is duplicated or out of phase")
    builds = verify_build_records(state)
    package_parent = path.parent / "release-package"
    if package_parent.exists() or package_parent.is_symlink():
        fail("Release package namespace is not fresh")
    os.mkdir(package_parent, 0o700)
    equivalence = package_parent / "equivalence-receipt.json"
    primary_checkout = verify_directory_record(state["checkouts"]["primary"], "primary checkout")
    run_checked(
        [
            "/usr/bin/python3",
            "-B",
            "-I",
            "-S",
            str(primary_checkout / RELEASE_PACKAGE.relative_to(ROOT)),
            "--compare",
            "--primary-ipa",
            str(builds["primary"]["ipa"]),
            "--reproduction-ipa",
            str(builds["reproduction"]["ipa"]),
            "--primary-build-manifest",
            str(builds["primary"]["buildManifest"]),
            "--reproduction-build-manifest",
            str(builds["reproduction"]["buildManifest"]),
            "--output",
            str(equivalence),
        ]
    )
    state["equivalenceReceipt"] = file_record(
        equivalence, MAX_JSON_BYTES, "Release equivalence receipt"
    )
    write_state(path, state)


def verify_immutable_candidate(
    state: dict[str, Any], *, require_package: bool
) -> tuple[dict[str, dict[str, Path]], Path | None]:
    builds = verify_build_records(state)
    if state["equivalenceReceipt"] is None:
        fail("candidate lacks its reproduction equivalence receipt")
    verify_file_record(
        state["equivalenceReceipt"], MAX_JSON_BYTES, "Release equivalence receipt"
    )
    package: Path | None = None
    if require_package:
        if state["qualifiedPackage"] is None:
            fail("candidate lacks its sealed qualified-IPA package")
        package_record = exact_keys(
            state["qualifiedPackage"],
            {
                "package",
                "qualificationReceiptSha256",
                "ipaSha256",
                "qualificationEvidenceOverlay",
            },
            "qualified package state",
        )
        package = verify_file_record(
            package_record["package"], MAX_FILE_BYTES, "qualified-IPA package"
        )
        require_sha256(package_record["qualificationReceiptSha256"], "qualification receipt")
        if package_record["ipaSha256"] != state["builds"]["primary"]["ipa"]["sha256"]:
            fail("qualified package state names a different primary IPA")
    return builds, package


def promotion_admission(state: dict[str, Any], ipa: Path, package: Path) -> str:
    checkout = verify_directory_record(state["checkouts"]["primary"], "primary checkout")
    environment = dict(os.environ)
    environment["IOS_RELEASE_QUALIFIED_IPA_PACKAGE_PATH"] = str(package)
    output = run_checked(
        [
            "/bin/sh",
            str(checkout / PROMOTION_ADMISSION.relative_to(ROOT)),
            "--verify-qualified-ipa",
            str(ipa),
        ],
        env=environment,
    )
    match = re.fullmatch(r"receiptSha256=([0-9a-f]{64}) ipaSha256=([0-9a-f]{64})", output)
    if match is None or match.group(2) != state["builds"]["primary"]["ipa"]["sha256"]:
        fail("post-archive migration admission returned an invalid immutable identity")
    return require_sha256(match.group(1), "qualification receipt")


def phase_qualify(state_raw: str) -> None:
    path, state = load_state(state_raw)
    if state["qualifiedPackage"] is not None or state["postUploadArtifact"] is not None:
        fail("exact-IPA physical qualification is duplicated or out of phase")
    builds, _ = verify_immutable_candidate(state, require_package=False)
    equivalence = verify_file_record(
        state["equivalenceReceipt"], MAX_JSON_BYTES, "Release equivalence receipt"
    )
    ipa = builds["primary"]["ipa"]
    run_external_controller(
        state,
        "retainedDevice",
        [
            "qualify-exact-ipa",
            "--ipa",
            str(ipa),
            "--ipa-sha256",
            state["builds"]["primary"]["ipa"]["sha256"],
            "--source-revision",
            state["sourceRevision"],
            "--build-number",
            state["buildNumber"],
            "--equivalence-receipt",
            str(equivalence),
            "--primary-build-manifest",
            str(builds["primary"]["buildManifest"]),
            "--reproduction-build-manifest",
            str(builds["reproduction"]["buildManifest"]),
        ],
    )
    primary_checkout = verify_directory_record(state["checkouts"]["primary"], "primary checkout")
    verify_executed_sources(
        primary_checkout, state["executedSources"]["primary"], "primary"
    )
    qualification_overlay = capture_qualification_overlay(primary_checkout)
    qualification_output = run_checked(
        [
            "/bin/sh",
            str(primary_checkout / QUALIFICATION.relative_to(ROOT)),
            "--verify-qualified-ipa",
            str(ipa),
        ]
    )
    qualified = re.fullmatch(
        r"receiptSha256=([0-9a-f]{64}) ipaSha256=([0-9a-f]{64})",
        qualification_output,
    )
    if qualified is None or qualified.group(2) != state["builds"]["primary"]["ipa"]["sha256"]:
        fail("protected schema-v8 qualification did not admit the exact primary IPA")
    receipt_sha = require_sha256(qualified.group(1), "schema-v8 qualification receipt")
    package_parent = path.parent / "release-package"
    package = package_parent / "sora-qualified-ipa.zip"
    if package.exists() or package.is_symlink():
        fail("qualified-IPA package output must be fresh")
    signature_raw = os.environ.get("IOS_MIGRATION_QUALIFICATION_RECEIPT_SIGNATURE_PATH", "")
    if not signature_raw:
        fail("protected schema-v8 qualification signature path is required")
    signature = canonical_absolute(signature_raw, "qualification signature")
    qualification_receipt = primary_checkout / QUALIFICATION_RECEIPT_RELATIVE
    run_checked(
        [
            "/usr/bin/python3",
            "-B",
            "-I",
            "-S",
            str(primary_checkout / RELEASE_PACKAGE.relative_to(ROOT)),
            "--seal",
            "--package",
            str(package),
            "--primary-ipa",
            str(ipa),
            "--equivalence-receipt",
            str(equivalence),
            "--primary-build-manifest",
            str(builds["primary"]["buildManifest"]),
            "--reproduction-build-manifest",
            str(builds["reproduction"]["buildManifest"]),
            "--qualification-receipt",
            str(qualification_receipt),
            "--qualification-signature",
            str(signature),
        ]
    )
    package_record = file_record(package, MAX_FILE_BYTES, "qualified-IPA package")
    if capture_qualification_overlay(primary_checkout) != qualification_overlay:
        fail("signed qualification evidence overlay changed while packaging")
    state["qualifiedPackage"] = {
        "package": package_record,
        "qualificationReceiptSha256": receipt_sha,
        "ipaSha256": state["builds"]["primary"]["ipa"]["sha256"],
        "qualificationEvidenceOverlay": qualification_overlay,
    }
    promotion_admission(state, ipa, package)
    verify_qualification_overlay(primary_checkout, qualification_overlay)
    write_state(path, state)


def authenticate_post_upload_artifact(
    state: dict[str, Any], receipt: Path, signature: Path, ipa: Path
) -> None:
    checkout = verify_directory_record(state["checkouts"]["primary"], "primary checkout")
    trust = checkout / TRUST_ROOT_RELATIVE
    expected_trust = require_sha256(
        os.environ.get("PRODUCTION_ROLLOUT_TRUST_ROOT_SHA256", ""),
        "protected rollout trust-root pin",
    )
    trust_record = file_record(trust, MAX_JSON_BYTES, "rollout trust root")
    if trust_record["sha256"] != expected_trust:
        fail("rollout trust root differs from its protected SHA-256 pin")
    run_checked(
        [
            "/usr/bin/python3",
            "-I",
            "-S",
            str(checkout / ROLLOUT_JSON.relative_to(ROOT)),
            "trust",
            str(trust),
        ]
    )
    trust_raw, _ = stable_read(trust, MAX_JSON_BYTES, "rollout trust root")
    trust_value = parse_canonical_json(trust_raw, "rollout trust root")
    public_key_sha = require_sha256(
        trust_value.get("publicKeySha256"), "rollout controller public key"
    )
    public_key_raw = os.environ.get("PRODUCTION_ROLLOUT_CONTROLLER_PUBLIC_KEY_PATH", "")
    public_key = canonical_absolute(public_key_raw, "rollout controller public key")
    public_key_record = file_record(
        public_key, MAX_JSON_BYTES, "rollout controller public key"
    )
    if public_key_record["sha256"] != public_key_sha:
        fail("rollout public key differs from the authenticated trust root")
    stable_read(signature, MAX_SIGNATURE_BYTES, "artifact receipt signature")
    result = subprocess.run(
        [
            "/usr/bin/openssl",
            "dgst",
            "-sha256",
            "-verify",
            str(public_key),
            "-signature",
            str(signature),
            str(receipt),
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        close_fds=True,
    )
    if result.returncode != 0:
        fail("post-upload artifact receipt signature is not authenticated")
    if file_record(public_key, MAX_JSON_BYTES, "rollout controller public key") != public_key_record:
        fail("rollout controller public key changed during artifact authentication")
    taira = verify_file_record(
        state["builds"]["primary"]["tairaAdmission"],
        MAX_JSON_BYTES,
        "primary Taira admission",
    )
    run_checked(
        [
            "/usr/bin/python3",
            "-I",
            "-S",
            str(checkout / ROLLOUT_JSON.relative_to(ROOT)),
            "artifact",
            str(receipt),
            str(ipa),
            str(taira),
        ]
    )


def phase_upload(state_raw: str) -> None:
    path, state = load_state(state_raw)
    if state["postUploadArtifact"] is not None or state["rollouts"]:
        fail("App Store upload is duplicated or out of phase")
    builds, package = verify_immutable_candidate(state, require_package=True)
    assert package is not None
    ipa = builds["primary"]["ipa"]
    promotion_admission(state, ipa, package)
    receipt_raw = os.environ.get(
        "PRODUCTION_ROLLOUT_ARTIFACT_IDENTITY_RECEIPT_PATH", ""
    )
    signature_raw = os.environ.get(
        "PRODUCTION_ROLLOUT_ARTIFACT_IDENTITY_SIGNATURE_PATH", ""
    )
    if not receipt_raw or not signature_raw:
        fail("protected post-upload artifact receipt and signature paths are required")
    receipt = canonical_absolute(receipt_raw, "post-upload artifact receipt", must_exist=False)
    signature = canonical_absolute(signature_raw, "post-upload artifact signature", must_exist=False)
    require_private_parent(receipt, "post-upload artifact receipt")
    require_private_parent(signature, "post-upload artifact signature")
    if receipt.exists() or receipt.is_symlink() or signature.exists() or signature.is_symlink():
        fail("post-upload artifact receipt outputs must be fresh")
    run_external_controller(
        state,
        "appStore",
        [
            "upload-exact-ipa",
            "--ipa",
            str(ipa),
            "--ipa-sha256",
            state["builds"]["primary"]["ipa"]["sha256"],
            "--qualified-package",
            str(package),
            "--source-revision",
            state["sourceRevision"],
            "--build-number",
            state["buildNumber"],
            "--idempotency-key",
            upload_idempotency_key(
                state["buildNumber"],
                state["builds"]["primary"]["ipa"]["sha256"],
            ),
            "--artifact-receipt",
            str(receipt),
            "--artifact-signature",
            str(signature),
        ],
    )
    verify_post_qualification_checkouts(state)
    receipt = canonical_absolute(str(receipt), "post-upload artifact receipt")
    signature = canonical_absolute(str(signature), "post-upload artifact signature")
    authenticate_post_upload_artifact(state, receipt, signature, ipa)
    promotion_admission(state, ipa, package)
    state["postUploadArtifact"] = {
        "receipt": file_record(receipt, MAX_JSON_BYTES, "post-upload artifact receipt"),
        "signature": file_record(signature, MAX_SIGNATURE_BYTES, "post-upload artifact signature"),
    }
    write_state(path, state)


def parse_mutation_receipt(
    path: Path,
    *,
    state: dict[str, Any],
    target: int,
    artifact_sha: str,
    rollout_sha: str,
    controller_sha: str,
    not_before: int,
) -> None:
    raw, _ = stable_read(path, MAX_JSON_BYTES, "distribution mutation receipt")
    value = exact_keys(
        parse_canonical_json(raw, "distribution mutation receipt"),
        {
            "schemaVersion",
            "contractId",
            "status",
            "bundleIdentifier",
            "sourceRevision",
            "buildNumber",
            "candidateIpaSha256",
            "artifactIdentityReceiptSha256",
            "rolloutReceiptSha256",
            "targetPercent",
            "appliedAtEpochSeconds",
            "controllerExecutableSha256",
        },
        "distribution mutation receipt",
    )
    if (
        value["schemaVersion"] != 1
        or value["contractId"] != MUTATION_CONTRACT_ID
        or value["status"] != "applied"
        or value["bundleIdentifier"] != BUNDLE_IDENTIFIER
        or value["sourceRevision"] != state["sourceRevision"]
        or value["buildNumber"] != state["buildNumber"]
        or value["candidateIpaSha256"] != state["builds"]["primary"]["ipa"]["sha256"]
        or value["artifactIdentityReceiptSha256"] != artifact_sha
        or value["rolloutReceiptSha256"] != rollout_sha
        or value["targetPercent"] != target
        or value["controllerExecutableSha256"] != controller_sha
    ):
        fail("distribution mutation receipt differs from the admitted immutable cohort")
    applied = value["appliedAtEpochSeconds"]
    now = int(time.time())
    if (
        type(applied) is not int
        or applied < not_before - MAX_CLOCK_SKEW_SECONDS
        or applied > now + MAX_CLOCK_SKEW_SECONDS
        or now - applied > MAX_CONTROLLER_OBSERVATION_AGE_SECONDS
    ):
        fail("distribution mutation receipt is not a fresh post-gate observation")


def phase_rollout(state_raw: str, target: int) -> None:
    if target not in ROLLOUT_TARGETS:
        fail("rollout target must be exactly 1, 5, 25, or 100")
    path, state = load_state(state_raw)
    expected = ROLLOUT_TARGETS[len(state["rollouts"])] if len(state["rollouts"]) < 4 else None
    if target != expected or state["postUploadArtifact"] is None:
        fail("rollout target is duplicated, missing a predecessor, or out of order")
    for prior in state["rollouts"]:
        prior_target = prior["targetPercent"]
        receipt_name = f"PRODUCTION_ROLLOUT_RECEIPT_{prior_target}_PATH"
        signature_name = f"PRODUCTION_ROLLOUT_RECEIPT_{prior_target}_SIGNATURE_PATH"
        if (
            os.environ.get(receipt_name) != prior["rolloutReceipt"]["path"]
            or os.environ.get(signature_name) != prior["rolloutSignature"]["path"]
        ):
            fail("protected predecessor chain differs from the already distributed chain")
    builds, package = verify_immutable_candidate(state, require_package=True)
    assert package is not None
    ipa = builds["primary"]["ipa"]
    artifact = exact_keys(
        state["postUploadArtifact"], {"receipt", "signature"}, "post-upload artifact state"
    )
    artifact_receipt = verify_file_record(
        artifact["receipt"], MAX_JSON_BYTES, "post-upload artifact receipt"
    )
    artifact_signature = verify_file_record(
        artifact["signature"], MAX_SIGNATURE_BYTES, "post-upload artifact signature"
    )
    if os.environ.get("PRODUCTION_ROLLOUT_ARTIFACT_IDENTITY_RECEIPT_PATH") != str(artifact_receipt) or os.environ.get("PRODUCTION_ROLLOUT_ARTIFACT_IDENTITY_SIGNATURE_PATH") != str(artifact_signature):
        fail("rollout artifact environment differs from the authenticated upload outputs")
    promotion_admission(state, ipa, package)
    environment = dict(os.environ)
    environment["PRODUCTION_ROLLOUT_TARGET_PERCENT"] = str(target)
    environment["PRODUCTION_ROLLOUT_IPA_PATH"] = str(ipa)
    environment["IOS_RELEASE_QUALIFIED_IPA_PACKAGE_PATH"] = str(package)
    gate_started = int(time.time())
    run_checked(
        ["/bin/sh", str(verify_directory_record(state["checkouts"]["primary"], "primary checkout") / ROLLOUT_GATE.relative_to(ROOT))],
        env=environment,
    )
    promotion_admission(state, ipa, package)
    rollout_receipt_raw = os.environ.get("PRODUCTION_ROLLOUT_RECEIPT_PATH", "")
    rollout_signature_raw = os.environ.get("PRODUCTION_ROLLOUT_RECEIPT_SIGNATURE_PATH", "")
    mutation_raw = os.environ.get("IOS_DISTRIBUTION_MUTATION_RECEIPT_PATH", "")
    if not rollout_receipt_raw or not rollout_signature_raw or not mutation_raw:
        fail("rollout receipt/signature and fresh distribution mutation receipt path are required")
    rollout_receipt = canonical_absolute(rollout_receipt_raw, "rollout receipt")
    rollout_signature = canonical_absolute(rollout_signature_raw, "rollout receipt signature")
    mutation = canonical_absolute(mutation_raw, "distribution mutation receipt", must_exist=False)
    require_private_parent(mutation, "distribution mutation receipt")
    if mutation.exists() or mutation.is_symlink():
        fail("distribution mutation receipt output must be fresh")
    rollout_receipt_record = file_record(rollout_receipt, MAX_JSON_BYTES, "rollout receipt")
    rollout_signature_record = file_record(rollout_signature, MAX_SIGNATURE_BYTES, "rollout receipt signature")
    artifact_sha = state["postUploadArtifact"]["receipt"]["sha256"]
    run_external_controller(
        state,
        "distribution",
        [
            "advance-immutable-cohort",
            "--target-percent",
            str(target),
            "--ipa",
            str(ipa),
            "--ipa-sha256",
            state["builds"]["primary"]["ipa"]["sha256"],
            "--qualified-package",
            str(package),
            "--artifact-receipt",
            str(artifact_receipt),
            "--artifact-signature",
            str(artifact_signature),
            "--rollout-receipt",
            str(rollout_receipt),
            "--rollout-signature",
            str(rollout_signature),
            "--mutation-receipt",
            str(mutation),
        ],
    )
    verify_post_qualification_checkouts(state)
    mutation = canonical_absolute(str(mutation), "distribution mutation receipt")
    parse_mutation_receipt(
        mutation,
        state=state,
        target=target,
        artifact_sha=artifact_sha,
        rollout_sha=rollout_receipt_record["sha256"],
        controller_sha=state["controllers"]["distribution"]["sha256"],
        not_before=gate_started,
    )
    promotion_admission(state, ipa, package)
    verify_file_record(artifact["receipt"], MAX_JSON_BYTES, "post-upload artifact receipt")
    verify_file_record(artifact["signature"], MAX_SIGNATURE_BYTES, "post-upload artifact signature")
    if file_record(rollout_receipt, MAX_JSON_BYTES, "rollout receipt") != rollout_receipt_record or file_record(rollout_signature, MAX_SIGNATURE_BYTES, "rollout receipt signature") != rollout_signature_record:
        fail("signed rollout authority changed during distribution mutation")
    state["rollouts"].append(
        {
            "targetPercent": target,
            "rolloutReceipt": rollout_receipt_record,
            "rolloutSignature": rollout_signature_record,
            "mutationReceipt": file_record(
                mutation, MAX_JSON_BYTES, "distribution mutation receipt"
            ),
        }
    )
    write_state(path, state)


def lint_contract() -> None:
    required = (
        SOURCE_GATE,
        RELEASE_TESTS,
        ARCHIVER,
        RELEASE_PACKAGE,
        QUALIFICATION,
        PROMOTION_ADMISSION,
        ROLLOUT_GATE,
        ROLLOUT_JSON,
        TAIRA_ADMISSION,
        ROOT / "Jenkinsfile",
        ROOT / "Jenkinsfile.migration-evidence",
        ROOT / "Jenkinsfile.production-promotion",
        ROOT / "Fixtures/Modernization/ios-production-promotion-README.md",
        SCRIPTS / "test-ios-production-promotion.py",
    )
    for path in required:
        if not path.is_file() or path.is_symlink():
            fail(f"production promotion contract input is missing or symbolic: {path}")
    legacy = (ROOT / "Jenkinsfile").read_text(encoding="utf-8")
    pipeline = (ROOT / "Jenkinsfile.production-promotion").read_text(encoding="utf-8")
    if "legacy pipeline is not an authorized production promotion controller" not in legacy:
        fail("legacy Jenkins pipeline lost its explicit non-authorizing boundary")
    required_pipeline_markers = (
        "skipDefaultCheckout(true)",
        "disableConcurrentBuilds()",
        "PROMOTION_PHASE",
        "candidate",
        "qualify",
        "upload",
        "rollout-1",
        "rollout-5",
        "rollout-25",
        "rollout-100",
        "--phase initialize",
        "--phase release-tests",
        "--phase archive",
        "--phase compare",
        "--phase qualify",
        "--phase upload",
        "--phase rollout",
    )
    if any(marker not in pipeline for marker in required_pipeline_markers):
        fail("production Jenkins pipeline omits an exact fail-closed phase")
    if "evaluate(" in pipeline or "sh(params." in pipeline:
        fail("production Jenkins pipeline exposes an arbitrary command surface")
    run_checked(["/bin/sh", str(RELEASE_TESTS), "--lint-contract"])
    run_checked(["/bin/sh", str(ARCHIVER), "--lint-contract"])
    run_checked(["/usr/bin/python3", "-B", "-I", "-S", str(RELEASE_PACKAGE), "--lint-contract"])
    run_checked(["/bin/sh", str(QUALIFICATION), "--lint-templates"])
    run_checked(["/bin/sh", str(PROMOTION_ADMISSION), "--lint-contract"])
    run_checked(["/bin/sh", str(ROLLOUT_GATE), "--lint-templates"])


def main(argv: list[str]) -> int:
    try:
        if argv == ["--lint-contract"]:
            lint_contract()
            print("iOS production promotion controller contract: OK")
            return 0
        if len(argv) >= 2 and argv[:2] == ["--phase", "initialize"] and len(argv) == 12:
            expected = (
                "--state",
                "--primary-checkout",
                "--reproduction-checkout",
                "--source-revision",
                "--build-number",
            )
            if tuple(argv[index] for index in range(2, 12, 2)) != expected:
                fail("initialize arguments are not exact")
            initialize(argv[3], argv[5], argv[7], argv[9], argv[11])
            return 0
        if len(argv) == 8 and argv[:2] == ["--phase", "release-tests"]:
            if tuple(argv[index] for index in (2, 4, 6)) != ("--state", "--role", "--destination"):
                fail("Release-test arguments are not exact")
            phase_release_tests(argv[3], argv[5], argv[7])
            return 0
        if len(argv) == 6 and argv[:2] == ["--phase", "archive"]:
            if (argv[2], argv[4]) != ("--state", "--role"):
                fail("archive arguments are not exact")
            phase_archive(argv[3], argv[5])
            return 0
        if len(argv) == 4 and argv[:2] == ["--phase", "compare"] and argv[2] == "--state":
            phase_compare(argv[3])
            return 0
        if len(argv) == 4 and argv[:2] == ["--phase", "qualify"] and argv[2] == "--state":
            phase_qualify(argv[3])
            return 0
        if len(argv) == 4 and argv[:2] == ["--phase", "upload"] and argv[2] == "--state":
            phase_upload(argv[3])
            return 0
        if len(argv) == 6 and argv[:2] == ["--phase", "rollout"] and (argv[2], argv[4]) == ("--state", "--target"):
            if argv[5] not in {"1", "5", "25", "100"}:
                fail("rollout target is not exact")
            phase_rollout(argv[3], int(argv[5]))
            return 0
        fail(
            "usage: run-ios-production-promotion.py --lint-contract | "
            "--phase initialize --state PATH --primary-checkout PATH --reproduction-checkout PATH --source-revision REV --build-number N | "
            "--phase release-tests --state PATH --role primary|reproduction --destination DEST | "
            "--phase archive --state PATH --role primary|reproduction | "
            "--phase compare|qualify|upload --state PATH | "
            "--phase rollout --state PATH --target 1|5|25|100"
        )
    except (PromotionError, OSError, subprocess.SubprocessError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
