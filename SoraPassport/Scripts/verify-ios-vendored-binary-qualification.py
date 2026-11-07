#!/usr/bin/env python3
"""Keep the iOS app free of prebuilt and closed-source binaries.

Until 2026-11-07 the app linked six prebuilt XCFramework trees that were never
source-qualified (blake2lib, libed25519, sr25519lib, two copies of the
Kotlin/Native sorawallet framework, Mastercard's MPQRCoreSDK) and Firebase,
whose Analytics product pulls Google's closed GoogleAppMeasurement binary. Now:

- blake2lib, libed25519 and sr25519lib are C targets built from vendored source
  (VendorPackages/shared-features-spm/Sources/<name>/README.md gives each
  upstream commit and license; Tests/CryptoCompatibility checks them against the
  outputs of the binaries they replaced);
- sorawallet's indexer models are Swift source (VendorPackages/SoraWalletBinary);
- MPQRCoreSDK, XNetworking and Firebase are not used.

There is therefore nothing left to qualify; this tool makes sure nothing comes
back. It scans every file Git tracks (or, outside a Git checkout, the source
tree without build outputs) and fails on:

- an .xcframework or .framework directory, or a static/dynamic library or object
  file (.a .dylib .so .o), or any file whose bytes are a Mach-O, fat Mach-O, ELF
  or ar image;
- a SwiftPM `.binaryTarget(` in a tracked Package.swift;
- a pin for a closed-source or binary-only package in a tracked Package.resolved.

Commands (the interface the dependency gate and release scripts call):

  --scan-repository        run the scan; prints nothing when the tree is clean.
  --lint-templates         check the blocked template; prints nothing. Release
                           scripts call it many times per run, so it does not
                           scan; the gate's test suite runs the scan once.
  --print-contract-sha256  SHA-256 of this tool and the blocked template.
  --verify-qualified       production promotion. Fails closed: the promotion
                           receipt for a binary-free tree has not been produced.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Iterable, List, Optional

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "Fixtures" / "Modernization"
BLOCKED_RECEIPT = FIXTURES / "ios-vendored-binary-qualification.blocked.json"
GIT = "/usr/bin/git"

BINARY_DIRECTORY_SUFFIXES = (".xcframework", ".framework")
BINARY_FILE_SUFFIXES = (".a", ".dylib", ".so", ".o")
# Mach-O 32/64 (both byte orders), fat Mach-O (also Java class files), ELF, ar.
BINARY_MAGICS = (
    b"\xfe\xed\xfa\xce",
    b"\xce\xfa\xed\xfe",
    b"\xfe\xed\xfa\xcf",
    b"\xcf\xfa\xed\xfe",
    b"\xca\xfe\xba\xbe",
    b"\xca\xfe\xba\xbf",
    b"\x7fELF",
    b"!<arch>\n",
)
# Package identities that are closed source or ship only prebuilt binaries.
CLOSED_PACKAGE_IDENTITIES = {
    "firebase-ios-sdk",
    "googleappmeasurement",
    "google-ads-on-device-conversion-ios-sdk",
    "abseil-cpp-binary",
    "grpc-binary",
    "x-networking",
}
# Not part of the source tree: build outputs, caches and local scratch copies.
SKIPPED_DIRECTORIES = {
    ".git",
    ".build",
    ".swiftpm",
    ".local",
    "build",
    "DerivedData",
    "SourcePackages",
    "output",
    "tmp",
    "__pycache__",
}
BINARY_TARGET_RE = re.compile(r"\.binaryTarget\s*\(")

EXPECTED_BLOCKED_RECEIPT = {
    "schemaVersion": 2,
    "contractId": "sora-ios-vendored-binary-qualification-v2",
    "platform": "ios",
    "status": "blocked",
    "vendoredBinaryCount": 0,
    "artifacts": [],
    "blockingReasons": [
        "No prebuilt binary is vendored: the crypto libraries and the indexer models are built "
        "from source. A promotion receipt for this source tree has not been produced."
    ],
}


def fail(message: str) -> None:
    raise SystemExit(f"error: {message}")


def tracked_files(root: Path) -> Optional[List[str]]:
    """Paths Git tracks under root, or None outside a Git checkout."""
    if not (root / ".git").exists() or not os.path.exists(GIT):
        return None
    result = subprocess.run(
        [GIT, "-C", str(root), "ls-files", "-z"],
        capture_output=True,
        env={"PATH": "/usr/bin:/bin", "GIT_CONFIG_NOSYSTEM": "1", "HOME": "/nonexistent"},
    )
    if result.returncode != 0:
        return None
    return [path for path in result.stdout.decode("utf-8", "surrogateescape").split("\0") if path]


def walked_files(root: Path) -> List[str]:
    files: List[str] = []
    for directory, subdirectories, names in os.walk(root):
        subdirectories[:] = sorted(d for d in subdirectories if d not in SKIPPED_DIRECTORIES)
        for name in sorted(names):
            files.append(os.path.relpath(os.path.join(directory, name), root))
    return files


def binary_findings(root: Path, files: Iterable[str]) -> List[str]:
    findings: List[str] = []
    for relative in files:
        parts = Path(relative).parts
        if any(part in SKIPPED_DIRECTORIES for part in parts[:-1]):
            continue
        if any(part.endswith(BINARY_DIRECTORY_SUFFIXES) for part in parts[:-1]):
            findings.append(f"prebuilt framework: {relative}")
            continue
        name = parts[-1]
        path = root / relative
        if name.endswith(BINARY_FILE_SUFFIXES):
            findings.append(f"prebuilt library or object: {relative}")
            continue
        try:
            if path.is_symlink() or not path.is_file():
                continue
            with path.open("rb") as stream:
                head = stream.read(8)
        except OSError as error:
            findings.append(f"unreadable file {relative}: {error}")
            continue
        if any(head.startswith(magic) for magic in BINARY_MAGICS):
            findings.append(f"binary executable image: {relative}")
            continue
        if name == "Package.swift":
            text = path.read_text(encoding="utf-8", errors="replace")
            if BINARY_TARGET_RE.search(text):
                findings.append(f"SwiftPM binary target: {relative}")
        elif name == "Package.resolved":
            try:
                resolved = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, ValueError) as error:
                findings.append(f"unreadable Package.resolved {relative}: {error}")
                continue
            pins = resolved.get("pins") or resolved.get("object", {}).get("pins") or []
            for pin in pins:
                identity = str(pin.get("identity") or pin.get("package") or "").lower()
                if identity in CLOSED_PACKAGE_IDENTITIES:
                    findings.append(f"closed-source or binary-only package {identity}: {relative}")
    return findings


def scan(root: Path = ROOT) -> List[str]:
    files = tracked_files(root)
    return binary_findings(root, files if files is not None else walked_files(root))


def require_no_binaries(root: Path = ROOT) -> None:
    findings = scan(root)
    if findings:
        fail("prebuilt or closed-source binaries are not allowed:\n  " + "\n  ".join(findings))


def lint_templates(root: Path = ROOT) -> None:
    receipt_path = root / BLOCKED_RECEIPT.relative_to(ROOT)
    if receipt_path.is_symlink() or not receipt_path.is_file():
        fail("blocked vendored-binary template is absent or symbolic")
    try:
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    except ValueError as error:
        fail(f"blocked vendored-binary template is not JSON: {error}")
    if receipt != EXPECTED_BLOCKED_RECEIPT:
        fail("blocked vendored-binary template drifted from the binary-free contract")


def contract_sha256(root: Path = ROOT) -> str:
    digest = hashlib.sha256()
    for path in (Path(__file__).resolve(), root / BLOCKED_RECEIPT.relative_to(ROOT)):
        data = path.read_bytes()
        digest.update(len(data).to_bytes(8, "big"))
        digest.update(data)
    return digest.hexdigest()


def main() -> None:
    if sys.argv[1:] == ["--scan-repository"]:
        require_no_binaries()
        return
    if sys.argv[1:] == ["--lint-templates"]:
        lint_templates()
        return
    if sys.argv[1:] == ["--print-contract-sha256"]:
        lint_templates()
        print(contract_sha256())
        return
    if sys.argv[1:] == ["--verify-qualified"]:
        lint_templates()
        require_no_binaries()
        fail(
            "no vendored-binary promotion receipt: the tree holds no prebuilt binary, "
            "but no reviewed receipt for it has been produced"
        )
    fail(
        "usage: verify-ios-vendored-binary-qualification.py "
        "--scan-repository|--lint-templates|--print-contract-sha256|--verify-qualified"
    )


if __name__ == "__main__":
    main()
