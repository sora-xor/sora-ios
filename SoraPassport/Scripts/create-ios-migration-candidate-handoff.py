#!/usr/bin/env python3
"""Create a non-authorizing identity handoff for one exported migration IPA."""

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
from typing import Any, Optional


ROOT = Path(__file__).resolve().parents[2]
EXPORT_OPTIONS = ROOT / "SoraPassport/Configs/ios-migration-candidate-export-options.plist"
MAX_IPA_BYTES = 4 * 1024 * 1024 * 1024
MAX_EXECUTABLE_BYTES = 2 * 1024 * 1024 * 1024
MAX_ZIP_ENTRIES = 100_000
MAX_UNCOMPRESSED_BYTES = 8 * 1024 * 1024 * 1024
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SAFE_COMPONENT_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
BLOCKER = (
    "Observed candidate only: the exact exported IPA has not completed the retained-device run, "
    "independent schema-8 migration qualification, or post-export promotion admission."
)
EXPECTED_EXPORT_OPTIONS = {
    "destination": "export",
    "manageAppVersionAndBuildNumber": False,
    "method": "app-store-connect",
    "provisioningProfiles": {
        "co.jp.soramitsu.sora": "7ae520bc-599b-48ae-abfa-627eef530f0c",
    },
    "signingCertificate": "84AB95335BE14CAE9B050A353910F86FF2F9539B",
    "signingStyle": "manual",
    "stripSwiftSymbols": True,
    "teamID": "YLWWUD25VZ",
    "uploadSymbols": False,
}


class HandoffError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise HandoffError(message)


def canonical_json(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        + "\n"
    ).encode("utf-8")


def require_sha256(value: str, label: str) -> str:
    if SHA256_RE.fullmatch(value) is None or value == "0" * 64:
        fail(f"{label} must be a nonzero lowercase SHA-256")
    return value


def open_directory(path: Path, label: str, *, private: bool) -> int:
    if (
        path.anchor != "/"
        or not path.is_absolute()
        or any(part in ("", ".", "..") for part in path.parts[1:])
        or not hasattr(os, "O_NOFOLLOW")
        or not hasattr(os, "O_DIRECTORY")
    ):
        fail(f"{label} path is not a safe canonical absolute directory")
    flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY
    if hasattr(os, "O_CLOEXEC"):
        flags |= os.O_CLOEXEC
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
            fail(f"{label} must be an owner-only mode-0700 directory")
        return descriptor
    except OSError as error:
        if descriptor is not None:
            os.close(descriptor)
        fail(f"{label} cannot be opened without following aliases: {error}")
    except Exception:
        if descriptor is not None:
            os.close(descriptor)
        raise


def metadata_identity(value: os.stat_result) -> tuple[int, ...]:
    return (
        value.st_dev,
        value.st_ino,
        value.st_mode,
        value.st_size,
        value.st_mtime_ns,
        value.st_ctime_ns,
        value.st_nlink,
    )


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


def read_named_regular(
    directory_descriptor: int, name: str, maximum: int, label: str
) -> tuple[bytes, str, os.stat_result]:
    if SAFE_COMPONENT_RE.fullmatch(name) is None:
        fail(f"{label} leaf name is unsafe")
    descriptor = os.open(
        name,
        os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0),
        dir_fd=directory_descriptor,
    )
    result = bytearray()
    try:
        before = os.fstat(descriptor)
        if (
            not stat.S_ISREG(before.st_mode)
            or before.st_nlink != 1
            or not 0 < before.st_size <= maximum
        ):
            fail(f"{label} is not one bounded unique regular file")
        while True:
            chunk = os.read(descriptor, min(64 * 1024, maximum - len(result) + 1))
            if not chunk:
                break
            result.extend(chunk)
            if len(result) > maximum:
                fail(f"{label} exceeds its byte bound")
        after = os.fstat(descriptor)
        named_after = os.stat(name, dir_fd=directory_descriptor, follow_symlinks=False)
        if (
            len(result) != before.st_size
            or metadata_identity(after) != metadata_identity(before)
            or metadata_identity(named_after) != metadata_identity(before)
        ):
            fail(f"{label} changed while being read")
        raw = bytes(result)
        return raw, hashlib.sha256(raw).hexdigest(), before
    finally:
        os.close(descriptor)


def validate_export_options_raw(raw: bytes, label: str) -> None:
    try:
        value = plistlib.loads(raw)
    except (plistlib.InvalidFileException, ValueError, TypeError, OverflowError) as error:
        fail(f"{label} are invalid: {error}")
    if type(value) is not dict or value != EXPECTED_EXPORT_OPTIONS:
        fail("candidate export options are not the exact no-upload production export contract")


def read_source_export_options() -> tuple[bytes, str]:
    parent = open_directory(EXPORT_OPTIONS.parent, "candidate export-options source parent", private=False)
    try:
        raw, digest, _ = read_named_regular(
            parent, EXPORT_OPTIONS.name, 64 * 1024, "candidate export-options source"
        )
    finally:
        os.close(parent)
    validate_export_options_raw(raw, "candidate export options")
    return raw, digest


def validate_export_options() -> None:
    read_source_export_options()


def canonical_private_output(raw_path: str, label: str) -> tuple[Path, int, str]:
    path = Path(raw_path)
    if (
        str(path) != raw_path
        or path.anchor != "/"
        or path == Path("/")
        or any(part in ("", ".", "..") for part in path.parts[1:])
        or SAFE_COMPONENT_RE.fullmatch(path.name) is None
        or ROOT == path
        or ROOT in path.parents
    ):
        fail(f"{label} must be a canonical safe absolute path outside the repository")
    parent = open_directory(path.parent, f"{label} parent", private=True)
    return path, parent, path.name


def snapshot_export_options(output_raw: str) -> str:
    raw, digest = read_source_export_options()
    _, parent, name = canonical_private_output(
        output_raw, "candidate export-options snapshot"
    )
    created = False
    try:
        descriptor = os.open(
            name,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
            0o600,
            dir_fd=parent,
        )
        created = True
        try:
            offset = 0
            while offset < len(raw):
                offset += os.write(descriptor, raw[offset:])
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
        os.fsync(parent)
        copied, copied_sha, _ = read_named_regular(
            parent, name, 64 * 1024, "candidate export-options snapshot"
        )
        validate_export_options_raw(copied, "candidate export-options snapshot")
        if copied != raw or copied_sha != digest:
            fail("candidate export-options snapshot differs from its admitted source")
        return digest
    except Exception:
        if created:
            try:
                os.unlink(name, dir_fd=parent)
                os.fsync(parent)
            except OSError:
                pass
        raise
    finally:
        os.close(parent)


def verify_export_options_snapshot(snapshot_raw: str, expected_sha: str) -> str:
    require_sha256(expected_sha, "protected candidate export-options snapshot")
    path = Path(snapshot_raw)
    if str(path) != snapshot_raw or path.anchor != "/" or path == Path("/"):
        fail("candidate export-options snapshot path must be canonical and absolute")
    parent = open_directory(path.parent, "candidate export-options snapshot parent", private=True)
    try:
        raw, digest, _ = read_named_regular(
            parent, path.name, 64 * 1024, "candidate export-options snapshot"
        )
    finally:
        os.close(parent)
    validate_export_options_raw(raw, "candidate export-options snapshot")
    if digest != expected_sha:
        fail("candidate export-options snapshot differs from its protected digest")
    return digest


def verify_source_export_options(expected_sha: str) -> str:
    require_sha256(expected_sha, "protected candidate export-options source")
    _, digest = read_source_export_options()
    if digest != expected_sha:
        fail("candidate export-options source changed after its private snapshot")
    return digest


def safe_zip_name(info: zipfile.ZipInfo) -> PurePosixPath:
    name = info.filename
    pure = PurePosixPath(name)
    canonical = "/".join(pure.parts) + ("/" if info.is_dir() else "")
    mode = (info.external_attr >> 16) & 0xFFFF
    if (
        not name
        or name.startswith("/")
        or "\\" in name
        or any(part in ("", ".", "..") for part in pure.parts)
        or canonical != name
        or info.flag_bits & 0x1
        or (mode and not (stat.S_ISREG(mode) or stat.S_ISDIR(mode)))
    ):
        fail(f"candidate IPA contains an unsafe ZIP member: {name!r}")
    return pure


def read_zip_member(
    archive: zipfile.ZipFile, info: zipfile.ZipInfo, maximum: int, label: str
) -> bytes:
    if info.file_size <= 0 or info.file_size > maximum:
        fail(f"{label} has an invalid uncompressed size")
    with archive.open(info, "r") as source:
        raw = source.read(maximum + 1)
    if len(raw) != info.file_size or len(raw) > maximum:
        fail(f"{label} changed size while being read")
    return raw


def inspect_ipa(descriptor: int) -> dict[str, Any]:
    try:
        with os.fdopen(os.dup(descriptor), "rb") as source, zipfile.ZipFile(
            source, "r", allowZip64=True
        ) as archive:
            infos = archive.infolist()
            if not infos or len(infos) > MAX_ZIP_ENTRIES:
                fail("candidate IPA has an empty or unbounded ZIP inventory")
            names: set[str] = set()
            total = 0
            app_roots: set[str] = set()
            for info in infos:
                pure = safe_zip_name(info)
                if info.filename in names:
                    fail("candidate IPA contains a duplicate ZIP member")
                names.add(info.filename)
                total += info.file_size
                if total > MAX_UNCOMPRESSED_BYTES:
                    fail("candidate IPA exceeds its aggregate uncompressed bound")
                if (
                    len(pure.parts) >= 2
                    and pure.parts[0] == "Payload"
                    and pure.parts[1].endswith(".app")
                ):
                    app_roots.add("/".join(pure.parts[:2]))
            if len(app_roots) != 1:
                fail("candidate IPA must contain exactly one top-level application")
            app_root = next(iter(app_roots))
            info_name = f"{app_root}/Info.plist"
            try:
                info_entry = archive.getinfo(info_name)
            except KeyError:
                fail("candidate IPA lacks its application Info.plist")
            info_raw = read_zip_member(
                archive, info_entry, 16 * 1024 * 1024, "candidate IPA Info.plist"
            )
            try:
                application_info = plistlib.loads(info_raw)
            except plistlib.InvalidFileException as error:
                fail(f"candidate IPA Info.plist is invalid: {error}")
            if type(application_info) is not dict:
                fail("candidate IPA Info.plist is not a dictionary")
            executable_name = application_info.get("CFBundleExecutable")
            bundle_identifier = application_info.get("CFBundleIdentifier")
            short_version = application_info.get("CFBundleShortVersionString")
            build_version = application_info.get("CFBundleVersion")
            if (
                bundle_identifier != "co.jp.soramitsu.sora"
                or type(executable_name) is not str
                or SAFE_COMPONENT_RE.fullmatch(executable_name) is None
                or type(short_version) is not str
                or not short_version
                or len(short_version) > 128
                or type(build_version) is not str
                or not build_version
                or len(build_version) > 128
            ):
                fail("candidate IPA does not carry the fixed production application identity")
            try:
                executable_entry = archive.getinfo(f"{app_root}/{executable_name}")
            except KeyError:
                fail("candidate IPA lacks its declared application executable")
            executable = read_zip_member(
                archive,
                executable_entry,
                MAX_EXECUTABLE_BYTES,
                "candidate IPA executable",
            )
            return {
                "bundleIdentifier": bundle_identifier,
                "shortVersion": short_version,
                "buildVersion": build_version,
                "executableSha256": hashlib.sha256(executable).hexdigest(),
                "executableByteCount": len(executable),
            }
    except (OSError, zipfile.BadZipFile, zipfile.LargeZipFile) as error:
        fail(f"candidate IPA ZIP is invalid: {error}")


def create_handoff(
    export_root_raw: str, contract_sha: str, export_options_sha: str
) -> dict[str, Any]:
    export_root = Path(export_root_raw)
    if str(export_root) != export_root_raw or export_root == Path("/"):
        fail("candidate export root must be a canonical non-root absolute path")
    require_sha256(contract_sha, "candidate qualification source contract")
    require_sha256(export_options_sha, "candidate export-options identity")
    export_descriptor = open_directory(export_root, "candidate export root", private=True)
    ipa_descriptor: Optional[int] = None
    output_name = "ios-migration-candidate-handoff.json"
    output_created_identity: Optional[tuple[int, ...]] = None
    try:
        names_before = sorted(os.listdir(export_descriptor))
        if output_name in names_before:
            fail("candidate handoff already exists")
        ipa_names = [name for name in names_before if name.endswith(".ipa")]
        if len(ipa_names) != 1 or SAFE_COMPONENT_RE.fullmatch(ipa_names[0]) is None:
            fail("candidate export must contain exactly one safely named IPA")
        for name in names_before:
            metadata = os.stat(name, dir_fd=export_descriptor, follow_symlinks=False)
            if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
                fail("candidate export contains a symbolic, special, linked, or nested entry")
        ipa_name = ipa_names[0]
        ipa_descriptor = os.open(
            ipa_name,
            os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0),
            dir_fd=export_descriptor,
        )
        before = os.fstat(ipa_descriptor)
        if (
            not stat.S_ISREG(before.st_mode)
            or before.st_nlink != 1
            or not 0 < before.st_size <= MAX_IPA_BYTES
        ):
            fail("candidate IPA is not one bounded unique regular file")
        ipa_sha, ipa_size = hash_descriptor(
            ipa_descriptor, MAX_IPA_BYTES, "candidate IPA"
        )
        application = inspect_ipa(ipa_descriptor)
        second_sha, second_size = hash_descriptor(
            ipa_descriptor, MAX_IPA_BYTES, "candidate IPA recheck"
        )
        after = os.fstat(ipa_descriptor)
        named_after = os.stat(
            ipa_name, dir_fd=export_descriptor, follow_symlinks=False
        )
        if (
            ipa_sha != second_sha
            or ipa_size != second_size
            or metadata_identity(after) != metadata_identity(before)
            or metadata_identity(named_after) != metadata_identity(before)
        ):
            fail("candidate IPA changed while its handoff was created")
        absolute_ipa = str(export_root / ipa_name)
        handoff = {
            "schemaVersion": 1,
            "contractId": "sora-ios-wallet-migration-candidate-handoff-v1",
            "platform": "ios",
            "status": "observed",
            "releaseAuthorized": False,
            "promotionAuthorized": False,
            "scheme": "SoraPassport",
            "configuration": "Release",
            "requiredDevelopmentTeam": "YLWWUD25VZ",
            "qualificationContractSha256": contract_sha,
            "exportOptionsSha256": export_options_sha,
            "ipa": {
                "absolutePath": absolute_ipa,
                "sha256": ipa_sha,
                "byteCount": ipa_size,
                **application,
            },
            "exactAppTestHandoff": {
                "status": "pending",
                "requiredIpaSha256": ipa_sha,
                "requiredExecutableSha256": application["executableSha256"],
                "rebuiltTestHostAccepted": False,
            },
            "blockingReasons": [BLOCKER],
        }
        raw = canonical_json(handoff)
        output_descriptor = os.open(
            output_name,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
            0o600,
            dir_fd=export_descriptor,
        )
        try:
            offset = 0
            while offset < len(raw):
                offset += os.write(output_descriptor, raw[offset:])
            output_created_identity = metadata_identity(os.fstat(output_descriptor))
            os.fsync(output_descriptor)
        finally:
            try:
                if output_created_identity is None:
                    output_created_identity = metadata_identity(os.fstat(output_descriptor))
            finally:
                os.close(output_descriptor)
        os.fsync(export_descriptor)
        final_names = sorted(os.listdir(export_descriptor))
        if final_names != sorted(names_before + [output_name]):
            fail("candidate export changed while publishing its handoff")
        final_ipa_sha, final_ipa_size = hash_descriptor(
            ipa_descriptor, MAX_IPA_BYTES, "candidate IPA final recheck"
        )
        final_ipa_metadata = os.fstat(ipa_descriptor)
        final_named_ipa = os.stat(
            ipa_name, dir_fd=export_descriptor, follow_symlinks=False
        )
        output_check = os.open(
            output_name,
            os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0),
            dir_fd=export_descriptor,
        )
        try:
            output_metadata = os.fstat(output_check)
            output_raw = bytearray()
            while len(output_raw) <= len(raw):
                chunk = os.read(output_check, len(raw) - len(output_raw) + 1)
                if not chunk:
                    break
                output_raw.extend(chunk)
        finally:
            os.close(output_check)
        if (
            final_ipa_sha != ipa_sha
            or final_ipa_size != ipa_size
            or metadata_identity(final_ipa_metadata) != metadata_identity(before)
            or metadata_identity(final_named_ipa) != metadata_identity(before)
            or not stat.S_ISREG(output_metadata.st_mode)
            or output_metadata.st_nlink != 1
            or bytes(output_raw) != raw
        ):
            fail("candidate IPA or handoff changed before final publication")
        return {
            "ipaPath": absolute_ipa,
            "ipaSha256": ipa_sha,
            "handoffSha256": hashlib.sha256(raw).hexdigest(),
        }
    except Exception:
        if output_created_identity is not None:
            try:
                current_output = os.stat(
                    output_name,
                    dir_fd=export_descriptor,
                    follow_symlinks=False,
                )
            except FileNotFoundError:
                current_output = None
            if current_output is not None:
                if metadata_identity(current_output) != output_created_identity:
                    raise HandoffError(
                        "failed candidate handoff could not safely withdraw its exact output inode"
                    )
                try:
                    os.unlink(output_name, dir_fd=export_descriptor)
                    os.fsync(export_descriptor)
                    os.stat(
                        output_name,
                        dir_fd=export_descriptor,
                        follow_symlinks=False,
                    )
                except FileNotFoundError:
                    pass
                except OSError as cleanup_error:
                    raise HandoffError(
                        f"failed candidate handoff exact-output withdrawal failed: {cleanup_error}"
                    )
                else:
                    raise HandoffError(
                        "failed candidate handoff output remained after exact withdrawal"
                    )
        raise
    finally:
        if ipa_descriptor is not None:
            os.close(ipa_descriptor)
        os.close(export_descriptor)


def main(argv: list[str]) -> int:
    try:
        if argv == ["--lint-contract"]:
            validate_export_options()
            print("iOS migration candidate archive handoff contract: OK")
            return 0
        if len(argv) == 2 and argv[0] == "--snapshot-export-options":
            digest = snapshot_export_options(argv[1])
            print(f"exportOptionsSha256={digest}")
            return 0
        if len(argv) == 3 and argv[0] == "--verify-export-options-snapshot":
            digest = verify_export_options_snapshot(argv[1], argv[2])
            print(f"exportOptionsSha256={digest}")
            return 0
        if len(argv) == 2 and argv[0] == "--verify-export-options-source":
            digest = verify_source_export_options(argv[1])
            print(f"exportOptionsSha256={digest}")
            return 0
        if (
            len(argv) == 7
            and argv[0] == "--create"
            and argv[1] == "--export-root"
            and argv[3] == "--qualification-contract-sha"
            and argv[5] == "--export-options-sha"
        ):
            validate_export_options()
            result = create_handoff(argv[2], argv[4], argv[6])
            print(
                "ipaPath={ipaPath} ipaSha256={ipaSha256} handoffSha256={handoffSha256}".format(
                    **result
                )
            )
            return 0
        fail(
            "usage: create-ios-migration-candidate-handoff.py --lint-contract | "
            "--snapshot-export-options /private/path | "
            "--verify-export-options-snapshot /private/path SHA256 | "
            "--verify-export-options-source SHA256 | "
            "--create --export-root /private/path --qualification-contract-sha SHA256 "
            "--export-options-sha SHA256"
        )
    except (HandoffError, OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
