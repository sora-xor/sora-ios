#!/usr/bin/env python3
"""Fail-closed sanitizer for exact-IPA retained-device XCTest execution.

The generated XCTest runner remains a test-only product.  The application
under test is always the protected archive-derived installable clone supplied
by the controller; no build-for-testing SoraPassport.app path may survive.
"""

from __future__ import annotations

import hashlib
import os
import plistlib
import stat
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ID = "sora-ios-wallet-migration-xctestrun-sanitizer-v1"
TARGET_NAME = "SoraPassportUITests"
TARGET_TEST = (
    "RetainedMigrationEvidenceUITests/"
    "testExecuteAuthorizedRetainedMigrationCase"
)
BUNDLE_IDENTIFIER = "co.jp.soramitsu.sora"
REBUILT_APP_COMPONENT = "SoraPassport.app"
MAX_PLIST_BYTES = 16 * 1024 * 1024
REMOVABLE_REBUILT_HOST_KEYS = {
    "ApplicationPath",
    "ProductPath",
    "TargetApplicationPath",
    "TestHostPath",
    "UITargetAppPath",
}


class SanitizerError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise SanitizerError(message)


def safe_absolute(path: Path, label: str) -> Path:
    raw = str(path)
    if (
        not path.is_absolute()
        or path == Path("/")
        or any(component in ("", ".", "..") for component in path.parts[1:])
        or str(Path(raw)) != raw
    ):
        fail(f"{label} must be one canonical non-root absolute path")
    return path


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


def open_directory(path: Path, label: str) -> int:
    safe_absolute(path, label)
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | getattr(
        os, "O_CLOEXEC", 0
    )
    descriptor = os.open("/", flags)
    try:
        for component in path.parts[1:]:
            child = os.open(component, flags, dir_fd=descriptor)
            os.close(descriptor)
            descriptor = child
        metadata = os.fstat(descriptor)
        if not stat.S_ISDIR(metadata.st_mode):
            fail(f"{label} is not a directory")
        return descriptor
    except Exception:
        os.close(descriptor)
        raise


def require_private_ancestor(path: Path, label: str) -> None:
    current = path
    while current != Path("/"):
        metadata = os.lstat(current)
        if stat.S_ISLNK(metadata.st_mode):
            fail(f"{label} contains a symbolic path component")
        if (
            stat.S_ISDIR(metadata.st_mode)
            and metadata.st_uid == os.getuid()
            and stat.S_IMODE(metadata.st_mode) & 0o077 == 0
        ):
            return
        current = current.parent
    fail(f"{label} has no owner-private ancestor")


def read_regular(path: Path, label: str) -> bytes:
    safe_absolute(path, label)
    require_private_ancestor(path.parent, label)
    parent = open_directory(path.parent, f"{label} parent")
    descriptor: int | None = None
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
            or not 0 < before.st_size <= MAX_PLIST_BYTES
        ):
            fail(f"{label} is not one bounded owned unique regular file")
        raw = bytearray()
        while True:
            chunk = os.read(descriptor, min(1024 * 1024, MAX_PLIST_BYTES + 1 - len(raw)))
            if not chunk:
                break
            raw.extend(chunk)
            if len(raw) > MAX_PLIST_BYTES:
                fail(f"{label} exceeds its byte bound")
        after = os.fstat(descriptor)
        named = os.stat(path.name, dir_fd=parent, follow_symlinks=False)
        if (
            len(raw) != before.st_size
            or stable_identity(before) != stable_identity(after)
            or stable_identity(before) != stable_identity(named)
        ):
            fail(f"{label} changed while being read")
        return bytes(raw)
    finally:
        if descriptor is not None:
            os.close(descriptor)
        os.close(parent)


def write_new_regular(path: Path, raw: bytes) -> str:
    safe_absolute(path, "sanitized xctestrun output")
    require_private_ancestor(path.parent, "sanitized xctestrun output")
    parent = open_directory(path.parent, "sanitized xctestrun output parent")
    descriptor: int | None = None
    try:
        descriptor = os.open(
            path.name,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
            0o600,
            dir_fd=parent,
        )
        view = memoryview(raw)
        while view:
            written = os.write(descriptor, view)
            if written <= 0:
                fail("sanitized xctestrun could not be written")
            view = view[written:]
        os.fsync(descriptor)
        before = os.fstat(descriptor)
    finally:
        if descriptor is not None:
            os.close(descriptor)
        os.fsync(parent)
        os.close(parent)
    named = os.lstat(path)
    if (
        stable_identity(before) != stable_identity(named)
        or not stat.S_ISREG(named.st_mode)
        or stat.S_IMODE(named.st_mode) != 0o600
    ):
        fail("sanitized xctestrun changed during publication")
    return hashlib.sha256(raw).hexdigest()


def load_plist(raw: bytes, label: str) -> dict[str, Any]:
    try:
        value = plistlib.loads(raw)
    except (plistlib.InvalidFileException, ValueError, TypeError, OverflowError) as error:
        fail(f"{label} is invalid: {error}")
    if type(value) is not dict:
        fail(f"{label} is not one dictionary")
    return value


def target_name(key: str, target: dict[str, Any]) -> str | None:
    for field in ("TestTargetName", "BlueprintName"):
        value = target.get(field)
        if type(value) is str:
            return value
    if key == TARGET_NAME or key.startswith(f"{TARGET_NAME}-"):
        return TARGET_NAME
    return None


def is_rebuilt_host_path(value: str, clone_app: Path) -> bool:
    if value == str(clone_app) or value.startswith(f"{clone_app}/"):
        return False
    normalized = value.replace("\\", "/")
    return REBUILT_APP_COMPONENT in normalized.split("/")


def contains_rebuilt_host_path(value: Any, clone_app: Path) -> bool:
    if type(value) is str:
        return is_rebuilt_host_path(value, clone_app)
    if type(value) is list:
        return any(contains_rebuilt_host_path(item, clone_app) for item in value)
    if type(value) is dict:
        return any(
            contains_rebuilt_host_path(item, clone_app) for item in value.values()
        )
    return False


def sanitize_target(target: dict[str, Any], clone_app: Path) -> dict[str, Any]:
    sanitized = dict(target)
    for key in ("TestBundlePath", "TestHostPath"):
        if type(sanitized.get(key)) is not str or not sanitized[key]:
            fail(f"retained UI target lacks its mandatory {key}")
    testing_environment = sanitized.get("TestingEnvironmentVariables")
    if (
        type(testing_environment) is not dict
        or any(
            type(key) is not str or type(value) is not str
            for key, value in testing_environment.items()
        )
    ):
        fail("retained UI target has invalid testing environment variables")
    dependencies = sanitized.get("DependentProductPaths", [])
    if type(dependencies) is not list or any(type(item) is not str for item in dependencies):
        fail("retained UI target has an invalid dependent-product inventory")
    sanitized["DependentProductPaths"] = [
        item for item in dependencies if not is_rebuilt_host_path(item, clone_app)
    ]
    if str(clone_app) not in sanitized["DependentProductPaths"]:
        sanitized["DependentProductPaths"].append(str(clone_app))
    for key in list(sanitized):
        if key in {"DependentProductPaths", "UITargetAppPath"}:
            continue
        if contains_rebuilt_host_path(sanitized[key], clone_app):
            if key in REMOVABLE_REBUILT_HOST_KEYS:
                sanitized.pop(key)
            else:
                fail(f"retained UI target has an unknown rebuilt-host path: {key}")
    if sanitized.get("TestHostBundleIdentifier") == BUNDLE_IDENTIFIER:
        sanitized.pop("TestHostBundleIdentifier")
    sanitized["UITargetAppPath"] = str(clone_app)
    sanitized["UITargetAppBundleIdentifier"] = BUNDLE_IDENTIFIER
    sanitized["IsUITestBundle"] = True
    sanitized["IsAppHostedTestBundle"] = False
    sanitized["OnlyTestIdentifiers"] = [TARGET_TEST]
    sanitized["SkipTestIdentifiers"] = []
    return sanitized


def sanitize_value(value: dict[str, Any], clone_app: Path) -> dict[str, Any]:
    metadata = value.get("__xctestrun_metadata__")
    if type(metadata) is not dict or type(metadata.get("FormatVersion")) is not int:
        fail("xctestrun metadata is absent or malformed")
    format_version = metadata["FormatVersion"]
    if format_version not in {1, 2}:
        fail("xctestrun format version is not reviewed")
    if "TestConfigurations" in value:
        if set(value) != {"__xctestrun_metadata__", "TestConfigurations"}:
            fail("format-2 xctestrun contains an unknown top-level key")
        configurations = value["TestConfigurations"]
        if type(configurations) is not list:
            fail("format-2 xctestrun configurations are malformed")
        matches: list[tuple[dict[str, Any], dict[str, Any]]] = []
        for configuration in configurations:
            if type(configuration) is not dict:
                fail("format-2 xctestrun configuration is malformed")
            targets = configuration.get("TestTargets")
            if type(targets) is not list:
                fail("format-2 xctestrun target inventory is malformed")
            for target in targets:
                if type(target) is not dict:
                    fail("format-2 xctestrun target is malformed")
                if target_name("", target) == TARGET_NAME:
                    matches.append((configuration, target))
        if len(matches) != 1:
            fail("xctestrun does not contain exactly one retained migration UI target")
        configuration, target = matches[0]
        retained_configuration = dict(configuration)
        retained_configuration["IsEnabled"] = True
        retained_configuration["TestTargets"] = [sanitize_target(target, clone_app)]
        return {
            "TestConfigurations": [retained_configuration],
            "__xctestrun_metadata__": metadata,
        }
    matches = []
    for key, target in value.items():
        if key == "__xctestrun_metadata__":
            continue
        if type(target) is not dict:
            fail("format-1 xctestrun target is malformed")
        if target_name(key, target) == TARGET_NAME:
            matches.append((key, target))
    if len(matches) != 1:
        fail("xctestrun does not contain exactly one retained migration UI target")
    key, target = matches[0]
    return {
        key: sanitize_target(target, clone_app),
        "__xctestrun_metadata__": metadata,
    }


def extract_targets(value: dict[str, Any]) -> list[dict[str, Any]]:
    if "TestConfigurations" in value:
        configurations = value.get("TestConfigurations")
        if type(configurations) is not list:
            fail("sanitized format-2 configuration inventory is malformed")
        result: list[dict[str, Any]] = []
        for configuration in configurations:
            if type(configuration) is not dict:
                fail("sanitized format-2 configuration is malformed")
            targets = configuration.get("TestTargets")
            if type(targets) is not list:
                fail("sanitized format-2 target inventory is malformed")
            result.extend(target for target in targets if type(target) is dict)
        return result
    return [
        target
        for key, target in value.items()
        if key != "__xctestrun_metadata__" and type(target) is dict
    ]


def verify_sanitized_value(value: dict[str, Any], clone_app: Path) -> None:
    targets = extract_targets(value)
    if len(targets) != 1:
        fail("sanitized xctestrun does not contain exactly one test target")
    target = targets[0]
    if (
        target_name(TARGET_NAME, target) != TARGET_NAME
        or target.get("UITargetAppPath") != str(clone_app)
        or target.get("UITargetAppBundleIdentifier") != BUNDLE_IDENTIFIER
        or target.get("IsUITestBundle") is not True
        or target.get("IsAppHostedTestBundle") is not False
        or target.get("OnlyTestIdentifiers") != [TARGET_TEST]
        or target.get("SkipTestIdentifiers") != []
        or contains_rebuilt_host_path(value, clone_app)
    ):
        fail("sanitized xctestrun retains an unsafe or ambiguous host configuration")
    dependencies = target.get("DependentProductPaths")
    if type(dependencies) is not list or str(clone_app) not in dependencies:
        fail("sanitized xctestrun does not bind the archive-derived clone")


def validate_clone_app_path(path: Path) -> Path:
    safe_absolute(path, "installable clone app")
    require_private_ancestor(path, "installable clone app")
    descriptor = open_directory(path, "installable clone app")
    try:
        metadata = os.fstat(descriptor)
        if metadata.st_uid != os.getuid() or not path.name.endswith(".app"):
            fail("installable clone app is not one owned application directory")
    finally:
        os.close(descriptor)
    return path


def sanitize_xctestrun(input_path: Path, clone_app: Path, output_path: Path) -> dict[str, Any]:
    clone_app = validate_clone_app_path(clone_app)
    source_raw = read_regular(input_path, "generated xctestrun")
    source = load_plist(source_raw, "generated xctestrun")
    sanitized = sanitize_value(source, clone_app)
    verify_sanitized_value(sanitized, clone_app)
    raw = plistlib.dumps(sanitized, fmt=plistlib.FMT_XML, sort_keys=True)
    published_sha = write_new_regular(output_path, raw)
    retained_raw = read_regular(output_path, "sanitized xctestrun")
    if retained_raw != raw:
        fail("sanitized xctestrun changed after publication")
    retained = load_plist(retained_raw, "sanitized xctestrun")
    verify_sanitized_value(retained, clone_app)
    return {
        "contractId": CONTRACT_ID,
        "sourceXctestrunSha256": hashlib.sha256(source_raw).hexdigest(),
        "sanitizedXctestrunSha256": published_sha,
        "cloneAppPathSha256": hashlib.sha256(str(clone_app).encode("utf-8")).hexdigest(),
        "testTarget": TARGET_NAME,
        "onlyTestIdentifier": TARGET_TEST,
        "rebuiltHostInstallDisabled": True,
    }


def verify_sanitized_xctestrun(path: Path, clone_app: Path, expected_sha: str) -> None:
    raw = read_regular(path, "sanitized xctestrun")
    if hashlib.sha256(raw).hexdigest() != expected_sha:
        fail("sanitized xctestrun hash changed")
    value = load_plist(raw, "sanitized xctestrun")
    verify_sanitized_value(value, validate_clone_app_path(clone_app))


def lint_contract() -> None:
    ui_source = ROOT / "SoraPassportUITests/RetainedMigrationEvidenceUITests.swift"
    ui_scheme = (
        ROOT
        / "SoraPassport.xcodeproj/xcshareddata/xcschemes/"
        "SoraPassportMigrationEvidenceUI.xcscheme"
    )
    if (
        ROOT.name != "sora-ios"
        or CONTRACT_ID != "sora-ios-wallet-migration-xctestrun-sanitizer-v1"
        or TARGET_NAME != "SoraPassportUITests"
        or not ui_source.is_file()
        or not ui_scheme.is_file()
    ):
        fail("iOS migration xctestrun sanitizer contract is incomplete")


def main(argv: list[str]) -> int:
    try:
        if argv == ["--lint-contract"]:
            lint_contract()
            print("iOS migration xctestrun sanitizer contract: OK")
            return 0
        if (
            len(argv) == 7
            and argv[0] == "--sanitize"
            and argv[1] == "--input"
            and argv[3] == "--clone-app"
            and argv[5] == "--output"
        ):
            lint_contract()
            result = sanitize_xctestrun(
                Path(argv[2]),
                Path(argv[4]),
                Path(argv[6]),
            )
            print(" ".join(f"{key}={value}" for key, value in result.items()))
            return 0
        fail(
            "usage: sanitize-ios-migration-xctestrun.py --lint-contract | "
            "--sanitize --input /private/generated.xctestrun "
            "--clone-app /private/clone/Payload/SoraPassport.app "
            "--output /private/sanitized.xctestrun"
        )
    except (SanitizerError, OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
