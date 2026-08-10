#!/usr/bin/env python3
"""Verify Xcode's exact successful internal-TestFlight delivery record."""

from __future__ import annotations

import argparse
import datetime
import json
import os
import plistlib
import stat
import sys
import uuid
from pathlib import Path


SCOPE = "sora-ios-xcode-apple-upload-receipt-v1"
BUILD_NUMBER = "2026081002"
MARKETING_VERSION = "3.8.7"
BUNDLE_IDENTIFIER = "co.jp.soramitsu.sora"
TEAM_ID = "YLWWUD25VZ"
ADAM_ID = "1457566711"
PROVIDER_ID = "69a6de8e-8bb9-47e3-e053-5b8c7c11a4d1"
SIGNING_IDENTITY = "Apple Distribution: Soramitsu Co., Ltd. (YLWWUD25VZ)"
SIGNING_CERTIFICATE_SHA1 = "84AB95335BE14CAE9B050A353910F86FF2F9539B"


def fail(message: str) -> "None":
    raise SystemExit(f"error: {message}")


def require_regular(path: Path, label: str) -> bytes:
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
    if not value or len(value) > 1024 * 1024:
        fail(f"{label} is empty or exceeds its byte bound")
    return value


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


def verify(archive_info_path: Path, receipt_path: Path, build_number: str) -> tuple[str, str]:
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
        "destination": "upload",
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
    parser.add_argument("--receipt", type=Path)
    parser.add_argument("--build-number")
    arguments = parser.parse_args()
    if arguments.lint_contract:
        if any(
            value is not None
            for value in (arguments.archive_info, arguments.receipt, arguments.build_number)
        ):
            parser.error("--lint-contract cannot be combined with delivery inputs")
    elif None in (arguments.archive_info, arguments.receipt, arguments.build_number):
        parser.error("--archive-info, --receipt, and --build-number are required")
    return arguments


def main() -> None:
    arguments = parse_arguments()
    if arguments.lint_contract:
        print("iOS internal TestFlight delivery verifier: OK")
        return
    delivery_id, uploaded_at = verify(
        arguments.archive_info,
        arguments.receipt,
        arguments.build_number,
    )
    print(f"appleDeliveryId={delivery_id} appleUploadState=success appleUploadedAt={uploaded_at}")


if __name__ == "__main__":
    main()
