#!/usr/bin/env python3
"""Verify Xcode's exact successful internal-TestFlight delivery record."""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import plistlib
import re
import stat
import sys
import uuid
from pathlib import Path


SCOPE = "sora-ios-xcode-apple-upload-receipt-v1"
BUILD_NUMBER = "2026081101"
MARKETING_VERSION = "3.8.7"
BUNDLE_IDENTIFIER = "co.jp.soramitsu.sora"
TEAM_ID = "YLWWUD25VZ"
ADAM_ID = "1457566711"
PROVIDER_ID = "69a6de8e-8bb9-47e3-e053-5b8c7c11a4d1"
SIGNING_IDENTITY = "Apple Development: Makoto Takemiya (6A4BK72ZFV)"
SIGNING_CERTIFICATE_SHA1 = "84AB95335BE14CAE9B050A353910F86FF2F9539B"
SIGNING_CERTIFICATE_NAME = "Apple Distribution: Soramitsu Co., Ltd. (YLWWUD25VZ)"
PROVISIONING_PROFILE_UUID = "7ae520bc-599b-48ae-abfa-627eef530f0c"
PROVISIONING_PROFILE_NAME = "iOS Team Store Provisioning Profile: co.jp.soramitsu.sora"
PROVISIONING_PROFILE_SHA256 = "19073a93bc09fe061e2346470b57aae1961aa38ad4c6b4922e0140bf8061bf93"
EXPECTED_EXPORT_OPTIONS = {
    "destination": "upload",
    "embedOnDemandResourcesAssetPacksInBundle": True,
    "generateAppStoreInformation": False,
    "manageAppVersionAndBuildNumber": False,
    "method": "app-store-connect",
    "raiseProfileSupportOptionalToRequired": False,
    "signingStyle": "automatic",
    "stripSwiftSymbols": True,
    "teamID": TEAM_ID,
    "testFlightInternalTestingOnly": True,
    "thinning": "<none>",
    "uploadSymbols": False,
}


def fail(message: str) -> "None":
    raise SystemExit(f"error: {message}")


def require_regular(path: Path, label: str, *, maximum_bytes: int = 1024 * 1024) -> bytes:
    try:
        metadata = path.lstat()
    except OSError as error:
        fail(f"{label} is unavailable: {error}")
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
        fail(f"{label} must be one non-symbolic regular file")
    try:
        value = path.read_bytes()
    except OSError as error:
        fail(f"{label} cannot be read: {error}")
    if not value or len(value) > maximum_bytes:
        fail(f"{label} is empty or exceeds its byte bound")
    return value


def require_distribution_logs(xcodebuild_log_path: Path) -> tuple[Path, bytes, bytes]:
    command_log = require_regular(xcodebuild_log_path, "xcodebuild upload log")
    try:
        command_text = command_log.decode("utf-8")
    except UnicodeDecodeError:
        fail("xcodebuild upload log is not UTF-8")
    matches = re.findall(
        r'Created bundle at path "([^"\r\n]+\.xcdistributionlogs)"\.',
        command_text,
    )
    if len(matches) != 1:
        fail("xcodebuild upload log must name exactly one distribution log bundle")
    raw_root = Path(matches[0])
    if not raw_root.is_absolute() or not re.fullmatch(
        r"SoraPassport_[A-Za-z0-9._-]+\.xcdistributionlogs", raw_root.name
    ):
        fail("Xcode distribution log bundle path is invalid")
    try:
        root = raw_root.resolve(strict=True)
        root_metadata = root.lstat()
        parent_metadata = root.parent.lstat()
    except OSError as error:
        fail(f"Xcode distribution log bundle is unavailable: {error}")
    if (
        not stat.S_ISDIR(root_metadata.st_mode)
        or root_metadata.st_uid != os.getuid()
        or stat.S_IMODE(root_metadata.st_mode) & 0o022
        or not stat.S_ISDIR(parent_metadata.st_mode)
        or parent_metadata.st_uid != os.getuid()
        or stat.S_IMODE(parent_metadata.st_mode) != 0o700
    ):
        fail("Xcode distribution log bundle ownership or permissions are unsafe")
    expected_files = {"IDEDistribution.standard.log", "IDEDistribution.verbose.log"}
    try:
        observed_files = {entry.name for entry in root.iterdir() if entry.is_file()}
    except OSError as error:
        fail(f"Xcode distribution log bundle cannot be inspected: {error}")
    if not expected_files.issubset(observed_files):
        fail("Xcode distribution log bundle lacks required logs")
    standard = require_regular(
        root / "IDEDistribution.standard.log",
        "Xcode standard distribution log",
        maximum_bytes=4 * 1024 * 1024,
    )
    verbose = require_regular(
        root / "IDEDistribution.verbose.log",
        "Xcode verbose distribution log",
        maximum_bytes=8 * 1024 * 1024,
    )
    return root, standard, verbose


def verify_distribution_signing(
    xcodebuild_log_path: Path,
    reviewed_profile_path: Path,
    *,
    expected_profile_sha256: str = PROVISIONING_PROFILE_SHA256,
) -> dict[str, str | bool]:
    log_root, standard_raw, verbose_raw = require_distribution_logs(xcodebuild_log_path)
    try:
        standard = standard_raw.decode("utf-8")
        verbose = verbose_raw.decode("utf-8")
    except UnicodeDecodeError:
        fail("Xcode distribution logs are not UTF-8")
    option_matches = re.findall(r"Starting export with options: (\{[^\r\n]+\})", standard)
    if len(option_matches) != 1:
        fail("Xcode standard log must contain one effective export-options record")
    try:
        effective_options = json.loads(option_matches[0])
    except json.JSONDecodeError as error:
        fail(f"Xcode effective export options are invalid JSON: {error}")
    if effective_options != EXPECTED_EXPORT_OPTIONS:
        fail("Xcode effective export options drifted")

    anchors = list(
        re.finditer(
            r"(?m)^\d{4}-\d{2}-\d{2} .* \[MT\] Evaluation for SoraPassport\.app is ",
            verbose,
        )
    )
    if len(anchors) != 1:
        fail("Xcode verbose log must contain one SoraPassport.app signing evaluation")
    block_start = anchors[0].start()
    next_record = re.search(r"(?m)^\d{4}-\d{2}-\d{2} .* \[MT\] ", verbose[anchors[0].end() :])
    block_end = (
        anchors[0].end() + next_record.start() if next_record is not None else len(verbose)
    )
    block = verbose[block_start:block_end]
    profile_matches = re.findall(
        r"Profile:\s+<DVTEmbeddedProvisioningProfile [^:\r\n]+: name: ([^,\r\n]+), "
        r"UUID: ([0-9a-f-]+), teamName: (.+?), (?=teamIdentifierPrefixes:|isXcodeManaged:)",
        block,
    )
    managed_matches = re.findall(r"isXcodeManaged: ([01]),", block)
    path_matches = re.findall(r"filePath: <DVTFilePath:[^:>]+:'([^'\r\n]+)'>", block)
    identity_matches = re.findall(r"(?m)^Identity: ([0-9A-F]{40})$", block)
    certificate_matches = re.findall(
        r"Certificate <DVTSigningCertificate: [^;]+; name='([^']+)', hash='([0-9A-F]{40})'",
        block,
    )
    if not (
        len(profile_matches) == 1
        and len(managed_matches) == 1
        and len(path_matches) == 1
        and len(identity_matches) == 1
        and len(certificate_matches) == 1
    ):
        fail("Xcode SoraPassport.app signing-selection shape drifted")
    profile_name, profile_uuid, team_name = profile_matches[0]
    certificate_name, certificate_sha1 = certificate_matches[0]
    if (
        profile_name != PROVISIONING_PROFILE_NAME
        or profile_uuid != PROVISIONING_PROFILE_UUID
        or team_name != "Soramitsu Co., Ltd."
        or managed_matches[0] != "1"
        or identity_matches[0] != SIGNING_CERTIFICATE_SHA1
        or certificate_name != SIGNING_CERTIFICATE_NAME
        or certificate_sha1 != SIGNING_CERTIFICATE_SHA1
        or f"teamID='{TEAM_ID}'" not in block
        or f"bundleIdentifier: {BUNDLE_IDENTIFIER}" not in block
        or "provisioningPurpose: app-store" not in block
        or "provisioningStyle: 0" not in block
    ):
        fail("Xcode selected an unreviewed signing identity or provisioning profile")
    try:
        selected_profile = Path(path_matches[0]).resolve(strict=True)
        reviewed_profile = reviewed_profile_path.resolve(strict=True)
    except OSError as error:
        fail(f"selected provisioning profile cannot be resolved: {error}")
    if selected_profile != reviewed_profile:
        fail("Xcode selected an unexpected provisioning-profile path")
    profile_raw = require_regular(reviewed_profile, "reviewed App Store provisioning profile")
    profile_sha256 = hashlib.sha256(profile_raw).hexdigest()
    if profile_sha256 != expected_profile_sha256:
        fail("Xcode selected provisioning-profile bytes that drifted")
    return {
        "profileUuid": profile_uuid,
        "profileName": profile_name,
        "profileSha256": profile_sha256,
        "profileIsXcodeManaged": True,
        "signingStyle": "automatic",
        "standardLogSha256": hashlib.sha256(standard_raw).hexdigest(),
        "verboseLogSha256": hashlib.sha256(verbose_raw).hexdigest(),
        "distributionLogBundle": str(log_root),
    }


def successful_event(value: object, *, short_title: str, title: str) -> tuple[str, datetime.datetime]:
    if not isinstance(value, dict) or set(value) != {
        "date",
        "errors",
        "infoMessages",
        "shortTitle",
        "state",
        "title",
        "warnings",
    }:
        fail("Xcode upload event shape drifted")
    if (
        value.get("state") != "success"
        or value.get("shortTitle") != short_title
        or value.get("title") != title
        or value.get("errors") != []
        or value.get("warnings") != []
        or not isinstance(value.get("infoMessages"), list)
        or any(not isinstance(item, str) for item in value["infoMessages"])
    ):
        fail("Xcode upload event did not complete cleanly")
    raw_date = value.get("date")
    if not isinstance(raw_date, str) or not raw_date.endswith("Z"):
        fail("Xcode upload event date is not canonical UTC")
    try:
        parsed = datetime.datetime.fromisoformat(raw_date[:-1] + "+00:00")
    except ValueError:
        fail("Xcode upload event date is invalid")
    if parsed.tzinfo != datetime.timezone.utc:
        fail("Xcode upload event date is not UTC")
    return raw_date, parsed


def verify(
    archive_info_path: Path,
    xcodebuild_log_path: Path,
    reviewed_profile_path: Path,
    receipt_path: Path,
    build_number: str,
    *,
    expected_profile_sha256: str = PROVISIONING_PROFILE_SHA256,
) -> tuple[str, str]:
    if build_number != BUILD_NUMBER:
        fail("delivery build number is not the reviewed one-time value")
    try:
        archive = plistlib.loads(require_regular(archive_info_path, "archive Info.plist"))
    except plistlib.InvalidFileException as error:
        fail(f"archive Info.plist is invalid: {error}")
    if not isinstance(archive, dict) or (
        archive.get("ArchiveVersion") != 2
        or archive.get("Name") != "SoraPassport"
        or archive.get("SchemeName") != "SoraPassport"
    ):
        fail("archive identity drifted")
    application = archive.get("ApplicationProperties")
    if not isinstance(application, dict) or (
        application.get("CFBundleIdentifier") != BUNDLE_IDENTIFIER
        or application.get("CFBundleShortVersionString") != MARKETING_VERSION
        or application.get("CFBundleVersion") != build_number
        or application.get("SigningIdentity") != SIGNING_IDENTITY
        or application.get("Team") != TEAM_ID
    ):
        fail("archived application delivery identity drifted")
    distributions = archive.get("Distributions")
    if not isinstance(distributions, list) or len(distributions) != 1:
        fail("archive must record exactly one distribution")
    distribution = distributions[0]
    if not isinstance(distribution, dict) or set(distribution) != {
        "adamId",
        "certificateSHA1",
        "destination",
        "identifier",
        "preparationEvent",
        "providerId",
        "task",
        "teamID",
        "uploadDestination",
        "uploadedBuildNumber",
        "uploadEvent",
    }:
        fail("Xcode distribution record shape drifted")
    if (
        distribution.get("adamId") != ADAM_ID
        or distribution.get("certificateSHA1") != SIGNING_CERTIFICATE_SHA1
        or distribution.get("destination") != "upload"
        or distribution.get("providerId") != PROVIDER_ID
        or distribution.get("task") != "distribute"
        or distribution.get("teamID") != TEAM_ID
        or distribution.get("uploadDestination") != "App Store"
        or distribution.get("uploadedBuildNumber") != build_number
    ):
        fail("Xcode distribution record identity drifted")
    delivery_id = distribution.get("identifier")
    if not isinstance(delivery_id, str):
        fail("Apple delivery identifier is absent")
    try:
        if str(uuid.UUID(delivery_id)) != delivery_id:
            fail("Apple delivery identifier is not canonical")
    except ValueError:
        fail("Apple delivery identifier is invalid")
    _, prepared = successful_event(
        distribution.get("preparationEvent"),
        short_title="Prepared",
        title="Prepared archive for uploading",
    )
    uploaded_at, uploaded = successful_event(
        distribution.get("uploadEvent"),
        short_title="Uploaded",
        title="Uploaded to Apple",
    )
    if uploaded < prepared:
        fail("Apple upload predates archive preparation")
    signing = verify_distribution_signing(
        xcodebuild_log_path,
        reviewed_profile_path,
        expected_profile_sha256=expected_profile_sha256,
    )
    receipt = {
        "schemaVersion": 1,
        "scope": SCOPE,
        "deliveryId": delivery_id,
        "adamId": ADAM_ID,
        "providerId": PROVIDER_ID,
        "teamId": TEAM_ID,
        "buildNumber": build_number,
        "marketingVersion": MARKETING_VERSION,
        "certificateSha1": SIGNING_CERTIFICATE_SHA1,
        "provisioningProfileUuid": signing["profileUuid"],
        "provisioningProfileName": signing["profileName"],
        "provisioningProfileSha256": signing["profileSha256"],
        "provisioningProfileIsXcodeManaged": signing["profileIsXcodeManaged"],
        "signingStyle": signing["signingStyle"],
        "standardDistributionLogSha256": signing["standardLogSha256"],
        "verboseDistributionLogSha256": signing["verboseLogSha256"],
        "destination": "upload",
        "testFlightInternalTestingOnly": True,
        "uploadState": "success",
        "uploadedAt": uploaded_at,
    }
    try:
        parent = receipt_path.parent.resolve(strict=True)
        parent_metadata = parent.lstat()
    except OSError as error:
        fail(f"delivery receipt parent is invalid: {error}")
    if (
        not stat.S_ISDIR(parent_metadata.st_mode)
        or stat.S_IMODE(parent_metadata.st_mode) != 0o700
        or parent_metadata.st_uid != os.getuid()
    ):
        fail("delivery receipt parent must be current-user-owned mode 0700")
    try:
        descriptor = os.open(
            parent / receipt_path.name,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
            0o600,
        )
    except OSError as error:
        fail(f"delivery receipt cannot be created safely: {error}")
    with os.fdopen(descriptor, "w", encoding="utf-8") as output:
        json.dump(receipt, output, sort_keys=True, separators=(",", ":"))
        output.write("\n")
    return delivery_id, uploaded_at


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lint-contract", action="store_true")
    parser.add_argument("--archive-info", type=Path)
    parser.add_argument("--xcodebuild-log", type=Path)
    parser.add_argument("--reviewed-profile", type=Path)
    parser.add_argument("--receipt", type=Path)
    parser.add_argument("--build-number")
    arguments = parser.parse_args()
    if arguments.lint_contract:
        if any(
            value is not None
            for value in (
                arguments.archive_info,
                arguments.xcodebuild_log,
                arguments.reviewed_profile,
                arguments.receipt,
                arguments.build_number,
            )
        ):
            parser.error("--lint-contract cannot be combined with delivery inputs")
    elif None in (
        arguments.archive_info,
        arguments.xcodebuild_log,
        arguments.reviewed_profile,
        arguments.receipt,
        arguments.build_number,
    ):
        parser.error(
            "--archive-info, --xcodebuild-log, --reviewed-profile, --receipt, and --build-number are required"
        )
    return arguments


def main() -> None:
    arguments = parse_arguments()
    if arguments.lint_contract:
        print("iOS internal TestFlight delivery verifier: OK")
        return
    delivery_id, uploaded_at = verify(
        arguments.archive_info,
        arguments.xcodebuild_log,
        arguments.reviewed_profile,
        arguments.receipt,
        arguments.build_number,
    )
    print(f"appleDeliveryId={delivery_id} appleUploadState=success appleUploadedAt={uploaded_at}")


if __name__ == "__main__":
    main()
