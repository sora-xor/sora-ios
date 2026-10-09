#!/usr/bin/env python3
"""Verify the historical writer's source identity before a disposable rehearsal.

This checks source provenance, not migration success or production qualification.
The historical implementation is rebuilt with the current dependencies; the
record must never be described as an original App Store application binary.
"""

import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
REVISION = "b890dd5c5b64e336f6f6510cf1284b54ab7e6edb"
SOURCE = "SoraPassport/Common/Operation/AccountOperationFactory.swift"
TARGET = (
    "SoraPassportTests/Common/Modernization/"
    "HistoricalReleaseAccountOperationFactory.swift"
)
SOURCE_SHA256 = "7d057c6c8da0d78f97cb8310cb976713997c243f3101d86c588bb60c22128703"
PREFIX = "@testable import SoraPassport\n"
SUBSTITUTIONS = {
    "AccountOperationFactoryProtocol": "HistoricalReleaseAccountOperationFactoryProtocol",
    "AccountOperationFactory": "HistoricalReleaseAccountOperationFactory",
}
PRESERVED_PATHS = [
    "SoraPassport/Common/Model/AccountItemMapper.swift",
    "SoraPassport/Common/Model/ManagedAccountItemMapper.swift",
    "SoraPassport/Common/Storage/UserDataModel.xcdatamodeld/UserDataModel.xcdatamodel/contents",
    "SoraPassport/Common/Storage/UserDataModel.xcdatamodeld/UserDataModel 2.xcdatamodel/contents",
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def git(*arguments: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(ROOT), *arguments])


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def transform(text: str, substitutions: dict[str, str]) -> str:
    pattern = r"\b(?:" + "|".join(map(re.escape, substitutions)) + r")\b"
    return re.sub(pattern, lambda match: substitutions[match.group()], text)


def main() -> None:
    provenance = json.loads(
        (ROOT / "Fixtures/Modernization/ios-historical-writer-provenance.json").read_bytes()
    )
    require(provenance["schemaVersion"] == 1, "unexpected provenance schema")
    require(provenance["historicalCommit"] == REVISION, "historical revision changed")
    require(provenance["historicalTag"] == "3.8.7", "historical tag changed")
    require(git("rev-parse", "3.8.7^{commit}").decode().strip() == REVISION, "tag no longer identifies the recorded release")
    historical = git("show", f"{REVISION}:{SOURCE}")
    require(sha256(historical) == SOURCE_SHA256, "historical writer bytes changed")
    require(git("show", f"3.8.9:{SOURCE}") == historical, "writer differs at release 3.8.9")
    require(provenance["alsoIdenticalAtTag"] == "3.8.9", "second historical tag changed")

    expected = (PREFIX + transform(historical.decode(), SUBSTITUTIONS)).encode()
    actual = (ROOT / TARGET).read_bytes()
    require(actual == expected, "test writer has edits beyond the test import and two identifier substitutions")
    reverse = {value: key for key, value in SUBSTITUTIONS.items()}
    recovered = transform(actual.decode()[len(PREFIX):], reverse).encode()
    require(recovered == historical, "namespace transformation is not losslessly reversible")
    require(provenance["writer"] == {
        "sourcePath": SOURCE,
        "sourceGitBlob": git("rev-parse", f"{REVISION}:{SOURCE}").decode().strip(),
        "sourceSha256": SOURCE_SHA256,
        "testOnlyPath": TARGET,
        "testOnlySha256": sha256(actual),
        "prefix": PREFIX,
        "identifierSubstitutions": SUBSTITUTIONS,
    }, "writer provenance does not match observed bytes")

    records = provenance["preservedHistoricalSerializersAndModels"]
    require([record["path"] for record in records] == PRESERVED_PATHS, "preserved file inventory changed")
    for record in records:
        path = record["path"]
        old = git("show", f"{REVISION}:{path}")
        require((ROOT / path).read_bytes() == old, f"current historical serializer/model differs: {path}")
        require(record["sha256"] == sha256(old), f"historical SHA-256 mismatch: {path}")
        require(record["gitBlob"] == git("rev-parse", f"{REVISION}:{path}").decode().strip(), f"historical Git blob mismatch: {path}")

    print("Historical writer provenance verified: releases 3.8.7/3.8.9; exact reversible namespace adaptation; two unchanged serializers and two unchanged Core Data models.")
    print("Scope: rebuilt historical writer using current dependencies for a disposable simulator rehearsal; no migration outcome or production approval asserted.")


if __name__ == "__main__":
    try:
        main()
    except (KeyError, ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"Historical writer provenance FAILED: {error}", file=sys.stderr)
        sys.exit(1)
