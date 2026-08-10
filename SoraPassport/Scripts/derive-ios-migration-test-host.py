#!/usr/bin/env python3
"""Prove that one Release XCTest host is derived from an exported production IPA.

The result is deliberately observed and non-authorizing.  Equality is computed
over a complete, versioned application-tree projection.  Only code signatures,
embedded provisioning profiles, and explicitly named XCTest bundles are
excluded.  Mach-O code-signature normalization is implemented here instead of
delegated to a mutable tool or accepting a rebuilt executable hash.
"""

from __future__ import annotations

import hashlib
import json
import os
import plistlib
import re
import stat
import struct
import subprocess
import sys
import tempfile
import unicodedata
import zipfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any, BinaryIO, Optional


ROOT = Path(__file__).resolve().parents[2]
SCHEMA_VERSION = 2
CONTRACT_ID = "sora-ios-wallet-migration-test-host-derivation-v2"
PROJECTION_CONTRACT_ID = "sora-ios-wallet-migration-canonical-app-projection-v2"
RAW_TREE_CONTRACT_ID = "sora-ios-wallet-migration-raw-app-tree-v1"
PRODUCTION_BUNDLE_ID = "co.jp.soramitsu.sora"
PRODUCTION_TEAM_ID = "YLWWUD25VZ"
MAX_IPA_BYTES = 4 * 1024 * 1024 * 1024
MAX_APP_BYTES = 8 * 1024 * 1024 * 1024
MAX_FILE_BYTES = 2 * 1024 * 1024 * 1024
MAX_SIGNATURE_BYTES = 64 * 1024 * 1024
MAX_PLIST_BYTES = 16 * 1024 * 1024
MAX_FILES = 100_000
MAX_ZIP_ENTRIES = 200_000
MAX_LOAD_COMMAND_BYTES = 16 * 1024 * 1024
MAX_LOAD_COMMANDS = 16_384
MAX_FAT_ARCHES = 32
MAX_JSON_BYTES = 8 * 1024 * 1024
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SAFE_COMPONENT_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9._+@-]{0,255}$")
# Compiled application resources can retain spaces from source model names
# (for example, ``UserDataModel 2.mom``).  Keep that allowance confined to
# application-tree components: the first and last characters remain from the
# original safe alphabet, and only an internal ASCII space is added.
SAFE_APP_COMPONENT_RE = re.compile(
    r"[A-Za-z0-9_](?:[A-Za-z0-9._+@ -]{0,254}[A-Za-z0-9._+@-])?"
)
SAFE_VERSION_RE = re.compile(r"^[0-9A-Za-z][0-9A-Za-z._-]{0,127}$")
PROJECTION_PREFIX = b"SORA-IOS-MIGRATION-CANONICAL-APP-PROJECTION-V2\0"
RAW_TREE_PREFIX = b"SORA-IOS-MIGRATION-RAW-APP-TREE-V1\0"
FAT_PROJECTION_PREFIX = b"SORA-IOS-MIGRATION-CANONICAL-FAT-MACHO-V2\0"
DERQ_PATH = Path("/usr/bin/derq")
MAX_DERQ_BYTES = 32 * 1024 * 1024
SAFE_TOOL_ENV = {
    "PATH": "/usr/bin:/bin",
    "LANG": "C",
    "LC_ALL": "C",
    "TMPDIR": "/private/tmp",
}
BLOCKER = (
    "Observed derivation only: the retained physical-device scenarios, independent review, "
    "schema-8 qualification, and post-export promotion admission remain required."
)

# These rules are the complete exclusion surface.  A case, spelling, or bundle
# suffix variant is rejected rather than silently treated as equivalent.
EXCLUSION_RULES = (
    {
        "ruleId": "terminal-macho-code-signature-v2",
        "match": "parsed-terminal-LC_CODE_SIGNATURE-payload-and-signature-derived-fields",
        "reason": "code-signature-material",
    },
    {
        "ruleId": "recognized-bundle-code-signature-directory-v2",
        "match": "exact-direct-child:_CodeSignature:of-recognized-signed-bundle-root",
        "reason": "code-signature-material",
    },
    {
        "ruleId": "recognized-bundle-embedded-provision-v2",
        "match": "exact-direct-child:embedded.mobileprovision:of-recognized-app-or-appex-root",
        "reason": "provisioning-material",
    },
    {
        "ruleId": "scheme-xctest-bundles-v2",
        "match": (
            "exact-roots:PlugIns/SoraPassportTests.xctest|"
            "PlugIns/SoraPassportIntegrationTests.xctest"
        ),
        "reason": "test-only-bundle",
    },
    {
        "ruleId": "xctest-runtime-frameworks-v2",
        "match": (
            "exact-roots:Frameworks/XCUnit.framework|Frameworks/XCTAutomationSupport.framework|"
            "Frameworks/XCUIAutomation.framework|Frameworks/XCTestSupport.framework|"
            "Frameworks/XCTest.framework|Frameworks/XCTestCore.framework|Frameworks/Testing.framework"
        ),
        "reason": "test-only-runtime",
    },
    {
        "ruleId": "xctest-runtime-dylibs-v2",
        "match": (
            "exact-leaves:Frameworks/libXCTestSwiftSupport.dylib|"
            "Frameworks/libXCTestBundleInject.dylib"
        ),
        "reason": "test-only-runtime",
    },
)

# Three exact vendor resource paths are mode 0755 in the signed production app
# or mode 0700 in the owner-only Release test host built under umask 077, even
# though their contents are not Mach-O.  This is an exact reviewed exception
# surface: a different path, any other mode, or a different four-byte magic is
# still handled by the normal fail-closed Mach-O rule.
REVIEWED_EXECUTABLE_NON_MACHO_RESOURCES = (
    (
        "Frameworks/GoogleAdsOnDeviceConversion.framework/Info.plist",
        bytes.fromhex("3c3f786d"),
    ),
    (
        "GoogleSignIn_GoogleSignIn.bundle/Roboto-Bold.ttf",
        bytes.fromhex("00010000"),
    ),
    (
        "Frameworks/GoogleSignIn_FD4A0B4974F15B1_PackageProduct.framework/"
        "GoogleSignIn_GoogleSignIn.bundle/Roboto-Bold.ttf",
        bytes.fromhex("00010000"),
    ),
)
REVIEWED_EXECUTABLE_NON_MACHO_MODES = (0o700, 0o755)
EXACT_TEST_BUNDLE_ROOTS = (
    PurePosixPath("PlugIns/SoraPassportTests.xctest"),
    PurePosixPath("PlugIns/SoraPassportIntegrationTests.xctest"),
)
EXACT_TEST_RUNTIME_FRAMEWORK_ROOTS = tuple(
    PurePosixPath(f"Frameworks/{name}.framework")
    for name in (
        "XCUnit",
        "XCTAutomationSupport",
        "XCUIAutomation",
        "XCTestSupport",
        "XCTest",
        "XCTestCore",
        "Testing",
    )
)
EXACT_TEST_RUNTIME_DYLIBS = (
    PurePosixPath("Frameworks/libXCTestSwiftSupport.dylib"),
    PurePosixPath("Frameworks/libXCTestBundleInject.dylib"),
)
EXACT_TEST_ONLY_ROOTS = EXACT_TEST_BUNDLE_ROOTS + EXACT_TEST_RUNTIME_FRAMEWORK_ROOTS
ALLOWED_SIGNING_ENTITLEMENT_DIFFERENCES = (
    "aps-environment",
    "beta-reports-active",
    "get-task-allow",
)
PRESERVED_ENTITLEMENT_KEYS = (
    "application-identifier",
    "com.apple.developer.team-identifier",
    "keychain-access-groups",
    "com.apple.security.application-groups",
)

# Public Mach-O constants.  Commands outside this exact reviewed inventory are
# rejected.  The required-dyld bit remains part of each allowed command value.
LC_REQ_DYLD = 0x80000000
LC_SEGMENT = 0x1
LC_SYMTAB = 0x2
LC_SYMSEG = 0x3
LC_THREAD = 0x4
LC_UNIXTHREAD = 0x5
LC_LOADFVMLIB = 0x6
LC_IDFVMLIB = 0x7
LC_IDENT = 0x8
LC_FVMFILE = 0x9
LC_PREPAGE = 0xA
LC_DYSYMTAB = 0xB
LC_LOAD_DYLIB = 0xC
LC_ID_DYLIB = 0xD
LC_LOAD_DYLINKER = 0xE
LC_ID_DYLINKER = 0xF
LC_PREBOUND_DYLIB = 0x10
LC_ROUTINES = 0x11
LC_SUB_FRAMEWORK = 0x12
LC_SUB_UMBRELLA = 0x13
LC_SUB_CLIENT = 0x14
LC_SUB_LIBRARY = 0x15
LC_TWOLEVEL_HINTS = 0x16
LC_PREBIND_CKSUM = 0x17
LC_LOAD_WEAK_DYLIB = 0x18 | LC_REQ_DYLD
LC_SEGMENT_64 = 0x19
LC_ROUTINES_64 = 0x1A
LC_UUID = 0x1B
LC_RPATH = 0x1C | LC_REQ_DYLD
LC_CODE_SIGNATURE = 0x1D
LC_SEGMENT_SPLIT_INFO = 0x1E
LC_REEXPORT_DYLIB = 0x1F | LC_REQ_DYLD
LC_LAZY_LOAD_DYLIB = 0x20
LC_ENCRYPTION_INFO = 0x21
LC_DYLD_INFO = 0x22
LC_DYLD_INFO_ONLY = 0x22 | LC_REQ_DYLD
LC_LOAD_UPWARD_DYLIB = 0x23 | LC_REQ_DYLD
LC_VERSION_MIN_MACOSX = 0x24
LC_VERSION_MIN_IPHONEOS = 0x25
LC_FUNCTION_STARTS = 0x26
LC_DYLD_ENVIRONMENT = 0x27
LC_MAIN = 0x28 | LC_REQ_DYLD
LC_DATA_IN_CODE = 0x29
LC_SOURCE_VERSION = 0x2A
LC_DYLIB_CODE_SIGN_DRS = 0x2B
LC_ENCRYPTION_INFO_64 = 0x2C
LC_LINKER_OPTION = 0x2D
LC_LINKER_OPTIMIZATION_HINT = 0x2E
LC_VERSION_MIN_TVOS = 0x2F
LC_VERSION_MIN_WATCHOS = 0x30
LC_NOTE = 0x31
LC_BUILD_VERSION = 0x32
LC_DYLD_EXPORTS_TRIE = 0x33 | LC_REQ_DYLD
LC_DYLD_CHAINED_FIXUPS = 0x34 | LC_REQ_DYLD
LC_FILESET_ENTRY = 0x35 | LC_REQ_DYLD
LC_ATOM_INFO = 0x36
CPU_TYPE_ARM = 12

FIXED_COMMAND_SIZES = {
    LC_SYMTAB: 24,
    LC_SYMSEG: 16,
    LC_DYSYMTAB: 80,
    LC_TWOLEVEL_HINTS: 16,
    LC_PREBIND_CKSUM: 12,
    LC_ROUTINES: 40,
    LC_ROUTINES_64: 72,
    LC_UUID: 24,
    LC_CODE_SIGNATURE: 16,
    LC_SEGMENT_SPLIT_INFO: 16,
    LC_ENCRYPTION_INFO: 20,
    LC_DYLD_INFO: 48,
    LC_DYLD_INFO_ONLY: 48,
    LC_VERSION_MIN_MACOSX: 16,
    LC_VERSION_MIN_IPHONEOS: 16,
    LC_FUNCTION_STARTS: 16,
    LC_MAIN: 24,
    LC_DATA_IN_CODE: 16,
    LC_SOURCE_VERSION: 16,
    LC_DYLIB_CODE_SIGN_DRS: 16,
    LC_ENCRYPTION_INFO_64: 24,
    LC_LINKER_OPTIMIZATION_HINT: 16,
    LC_VERSION_MIN_TVOS: 16,
    LC_VERSION_MIN_WATCHOS: 16,
    LC_NOTE: 40,
    LC_DYLD_EXPORTS_TRIE: 16,
    LC_DYLD_CHAINED_FIXUPS: 16,
    LC_ATOM_INFO: 16,
}
DYLIB_COMMANDS = {
    LC_LOAD_DYLIB,
    LC_ID_DYLIB,
    LC_LOAD_WEAK_DYLIB,
    LC_REEXPORT_DYLIB,
    LC_LAZY_LOAD_DYLIB,
    LC_LOAD_UPWARD_DYLIB,
}
STRING_COMMANDS = {
    LC_LOADFVMLIB,
    LC_IDFVMLIB,
    LC_LOAD_DYLINKER,
    LC_ID_DYLINKER,
    LC_SUB_FRAMEWORK,
    LC_SUB_UMBRELLA,
    LC_SUB_CLIENT,
    LC_SUB_LIBRARY,
    LC_RPATH,
    LC_DYLD_ENVIRONMENT,
}
VARIABLE_COMMANDS = {
    LC_THREAD,
    LC_UNIXTHREAD,
    LC_PREBOUND_DYLIB,
    LC_LINKER_OPTION,
    LC_BUILD_VERSION,
    LC_FILESET_ENTRY,
    LC_IDENT,
    LC_FVMFILE,
    LC_PREPAGE,
}
ALLOWED_COMMANDS = (
    set(FIXED_COMMAND_SIZES)
    | DYLIB_COMMANDS
    | STRING_COMMANDS
    | VARIABLE_COMMANDS
    | {LC_SEGMENT, LC_SEGMENT_64}
)
LINKEDIT_DATA_COMMANDS = {
    LC_CODE_SIGNATURE,
    LC_SEGMENT_SPLIT_INFO,
    LC_FUNCTION_STARTS,
    LC_DATA_IN_CODE,
    LC_DYLIB_CODE_SIGN_DRS,
    LC_LINKER_OPTIMIZATION_HINT,
    LC_DYLD_EXPORTS_TRIE,
    LC_DYLD_CHAINED_FIXUPS,
    LC_ATOM_INFO,
}
# Xcode 26 can emit an empty LC_DATA_IN_CODE with dataoff retained at a real
# __LINKEDIT boundary.  No other empty load-command range may retain a nonzero
# offset.
EMPTY_LINKEDIT_BOUNDARY_COMMANDS = (LC_DATA_IN_CODE,)
EMPTY_ENCRYPTION_BOUNDARY_COMMANDS = (LC_ENCRYPTION_INFO_64,)
EMPTY_ENCRYPTION_INFO_64_FILE_OFFSET = 16 * 1024

CSMAGIC_EMBEDDED_SIGNATURE = 0xFADE0CC0
CSMAGIC_CODEDIRECTORY = 0xFADE0C02
CSMAGIC_REQUIREMENTS = 0xFADE0C01
CSMAGIC_REQUIREMENT = 0xFADE0C00
CSMAGIC_BLOBWRAPPER = 0xFADE0B01
CSMAGIC_ENTITLEMENTS = 0xFADE7171
CSMAGIC_DER_ENTITLEMENTS = 0xFADE7172
CODE_SIGNATURE_SLOT_MAGICS = {
    0: CSMAGIC_CODEDIRECTORY,
    2: CSMAGIC_REQUIREMENTS,
    5: CSMAGIC_ENTITLEMENTS,
    7: CSMAGIC_DER_ENTITLEMENTS,
    0x1000: CSMAGIC_CODEDIRECTORY,
    0x1001: CSMAGIC_CODEDIRECTORY,
    0x1002: CSMAGIC_CODEDIRECTORY,
    0x1003: CSMAGIC_CODEDIRECTORY,
    0x1004: CSMAGIC_CODEDIRECTORY,
    0x10000: CSMAGIC_BLOBWRAPPER,
}
UNSUPPORTED_CONSTRAINT_SLOTS = {8, 9, 10, 11}
S_ZEROFILL = 0x1
S_GB_ZEROFILL = 0xC
S_THREAD_LOCAL_REGULAR = 0x11
S_THREAD_LOCAL_ZEROFILL = 0x12
ZEROFILL_SECTION_TYPES = {S_ZEROFILL, S_GB_ZEROFILL, S_THREAD_LOCAL_ZEROFILL}


class DerivationError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise DerivationError(message)


def configure_repository_root(raw: str) -> None:
    global ROOT
    candidate = Path(raw)
    if (
        str(candidate) != raw
        or candidate.anchor != "/"
        or candidate == Path("/")
        or any(component in ("", ".", "..") for component in candidate.parts[1:])
    ):
        fail("repository root override is not one canonical absolute directory")
    current = Path("/")
    for component in candidate.parts[1:]:
        current /= component
        metadata = os.lstat(current)
        if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISDIR(metadata.st_mode):
            fail("repository root override traverses a symbolic or non-directory component")
    marker = candidate / "SoraPassport/Scripts/ios-migration-qualification-contract.py"
    marker_metadata = os.lstat(marker)
    if stat.S_ISLNK(marker_metadata.st_mode) or not stat.S_ISREG(marker_metadata.st_mode):
        fail("repository root override lacks the fixed qualification source-contract tool")
    ROOT = candidate


def canonical_json(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("utf-8")


def require_sha256(value: Any, label: str) -> str:
    if type(value) is not str or SHA256_RE.fullmatch(value) is None or value == "0" * 64:
        fail(f"{label} must be a nonzero lowercase SHA-256")
    return value


def exact_keys(value: Any, expected: set[str], label: str) -> None:
    if type(value) is not dict or set(value) != expected:
        fail(f"{label} contains missing or unreviewed fields")


def safe_relative(value: str, label: str) -> PurePosixPath:
    if not value or value.startswith("/") or "\\" in value:
        fail(f"{label} is not a safe relative POSIX path")
    path = PurePosixPath(value)
    if any(
        part in ("", ".", "..") or SAFE_APP_COMPONENT_RE.fullmatch(part) is None
        for part in path.parts
    ):
        fail(f"{label} contains an unsafe path component")
    return path


def normalized_path(value: str) -> str:
    return unicodedata.normalize("NFC", value).casefold()


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


def inode_identity(value: os.stat_result) -> tuple[int, int]:
    return value.st_dev, value.st_ino


def safe_absolute(path_raw: str, label: str) -> Path:
    path = Path(path_raw)
    if (
        str(path) != path_raw
        or path.anchor != "/"
        or path == Path("/")
        or any(component in ("", ".", "..") for component in path.parts[1:])
        or path == ROOT
        or ROOT in path.parents
    ):
        fail(f"{label} must be a canonical absolute path outside the repository")
    return path


def open_absolute_directory(
    path: Path, label: str, *, require_private_ancestor: bool
) -> int:
    if not hasattr(os, "O_NOFOLLOW") or not hasattr(os, "O_DIRECTORY"):
        fail("this platform cannot enforce alias-free derivation inputs")
    flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY | getattr(os, "O_CLOEXEC", 0)
    descriptor: Optional[int] = None
    private_ancestor = False
    try:
        descriptor = os.open("/", flags)
        for component in path.parts[1:]:
            child = os.open(component, flags, dir_fd=descriptor)
            opened = os.fstat(child)
            if not stat.S_ISDIR(opened.st_mode):
                os.close(child)
                fail(f"{label} traverses a non-directory component")
            if opened.st_uid == os.getuid() and stat.S_IMODE(opened.st_mode) == 0o700:
                private_ancestor = True
            os.close(descriptor)
            descriptor = child
        root_metadata = os.fstat(descriptor)
        if root_metadata.st_uid != os.getuid() or stat.S_IMODE(root_metadata.st_mode) & 0o022:
            fail(f"{label} must be current-user-owned and not group/world writable")
        if require_private_ancestor and not private_ancestor:
            fail(f"{label} must be anchored beneath an owner-only mode-0700 directory")
        return descriptor
    except OSError as error:
        if descriptor is not None:
            os.close(descriptor)
        fail(f"{label} cannot be opened without following aliases: {error}")
    except Exception:
        if descriptor is not None:
            os.close(descriptor)
        raise


def open_absolute_regular(path: Path, maximum: int, label: str) -> tuple[int, os.stat_result]:
    parent = open_absolute_directory(path.parent, f"{label} parent", require_private_ancestor=True)
    try:
        descriptor = os.open(
            path.name,
            os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0),
            dir_fd=parent,
        )
        metadata = os.fstat(descriptor)
        named = os.stat(path.name, dir_fd=parent, follow_symlinks=False)
        if (
            not stat.S_ISREG(metadata.st_mode)
            or metadata.st_uid != os.getuid()
            or metadata.st_nlink != 1
            or not 0 < metadata.st_size <= maximum
            or metadata_identity(named) != metadata_identity(metadata)
        ):
            os.close(descriptor)
            fail(f"{label} is not one stable owned bounded regular file")
        return descriptor, metadata
    finally:
        os.close(parent)


def hash_descriptor(
    descriptor: int, maximum: int, label: str, *, offset: int = 0, size: Optional[int] = None
) -> tuple[str, int]:
    metadata = os.fstat(descriptor)
    expected = metadata.st_size - offset if size is None else size
    if offset < 0 or expected <= 0 or offset + expected > metadata.st_size or expected > maximum:
        fail(f"{label} has an invalid byte range")
    digest = hashlib.sha256()
    consumed = 0
    while consumed < expected:
        chunk = os.pread(descriptor, min(1024 * 1024, expected - consumed), offset + consumed)
        if not chunk:
            fail(f"{label} ended before its declared size")
        digest.update(chunk)
        consumed += len(chunk)
    return digest.hexdigest(), consumed


def pread_exact(descriptor: int, offset: int, count: int, label: str) -> bytes:
    if offset < 0 or count < 0:
        fail(f"{label} requested an invalid byte range")
    result = bytearray()
    while len(result) < count:
        chunk = os.pread(descriptor, count - len(result), offset + len(result))
        if not chunk:
            fail(f"{label} ended before its declared size")
        result.extend(chunk)
    return bytes(result)


def open_fixed_derq() -> tuple[int, os.stat_result, dict[str, Any]]:
    try:
        descriptor = os.open(
            DERQ_PATH,
            os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0),
        )
    except OSError as error:
        fail(f"fixed DER entitlement decoder cannot be opened: {error}")
    try:
        before = os.fstat(descriptor)
        named = os.stat(DERQ_PATH, follow_symlinks=False)
        if (
            not stat.S_ISREG(before.st_mode)
            or before.st_uid != 0
            or before.st_nlink != 1
            or not before.st_mode & 0o111
            or stat.S_IMODE(before.st_mode) & 0o022
            or metadata_identity(before) != metadata_identity(named)
        ):
            fail("fixed DER entitlement decoder is not one immutable root-owned executable")
        digest, byte_count = hash_descriptor(
            descriptor, MAX_DERQ_BYTES, "fixed DER entitlement decoder"
        )
        after = os.fstat(descriptor)
        if metadata_identity(before) != metadata_identity(after):
            fail("fixed DER entitlement decoder changed while being identified")
        return descriptor, before, {
            "absolutePath": str(DERQ_PATH),
            "sha256": digest,
            "byteCount": byte_count,
            "invocation": "query --xml -i - -o -",
        }
    except Exception:
        os.close(descriptor)
        raise


def fixed_derq_identity() -> dict[str, Any]:
    descriptor, _, identity = open_fixed_derq()
    os.close(descriptor)
    return identity


def decode_der_entitlements(payload: bytes, label: str) -> tuple[dict[str, Any], dict[str, Any]]:
    if not payload or len(payload) > MAX_PLIST_BYTES:
        fail(f"{label} DER entitlement payload is empty or oversized")
    descriptor, before, identity = open_fixed_derq()
    try:
        try:
            result = subprocess.run(
                [
                    str(DERQ_PATH),
                    "query",
                    "--xml",
                    "-i",
                    "-",
                    "-o",
                    "-",
                ],
                input=payload,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
                env=SAFE_TOOL_ENV,
                timeout=30,
            )
        except (OSError, subprocess.SubprocessError) as error:
            fail(f"{label} DER entitlements cannot be decoded: {error}")
        after = os.fstat(descriptor)
        second_digest, second_size = hash_descriptor(
            descriptor, MAX_DERQ_BYTES, "fixed DER entitlement decoder recheck"
        )
        named_after = os.stat(DERQ_PATH, follow_symlinks=False)
        if (
            metadata_identity(before) != metadata_identity(after)
            or metadata_identity(before) != metadata_identity(named_after)
            or second_digest != identity["sha256"]
            or second_size != identity["byteCount"]
        ):
            fail("fixed DER entitlement decoder changed during bounded decode")
    finally:
        os.close(descriptor)
    if (
        result.returncode != 0
        or not result.stdout
        or len(result.stdout) > MAX_PLIST_BYTES
        or len(result.stderr) > 64 * 1024
    ):
        fail(f"{label} DER entitlements are not one supported CoreEntitlements value")
    try:
        value = plistlib.loads(result.stdout)
    except (plistlib.InvalidFileException, ValueError, TypeError, OverflowError) as error:
        fail(f"{label} decoded DER entitlements are invalid: {error}")
    if type(value) is not dict or not value:
        fail(f"{label} decoded DER entitlements are not one nonempty dictionary")
    return strict_entitlement_value(value, f"{label} decoded DER entitlements"), identity


def pack_u32(value: int) -> bytes:
    return struct.pack(">I", value)


def pack_u64(value: int) -> bytes:
    return struct.pack(">Q", value)


def projection_record(entries: list[dict[str, Any]]) -> bytes:
    ordered = sorted(entries, key=lambda item: item["relativePath"].encode("utf-8"))
    result = bytearray(PROJECTION_PREFIX)
    result.extend(pack_u32(len(ordered)))
    for item in ordered:
        path_raw = item["relativePath"].encode("utf-8")
        digest = bytes.fromhex(item["sha256"])
        entitlements_value = item.get("reviewedEntitlementsSha256")
        entitlements_digest = (
            bytes.fromhex(entitlements_value)
            if type(entitlements_value) is str
            else b"\0" * 32
        )
        kind = item["kind"]
        if (
            kind not in ("macho", "resource")
            or len(digest) != 32
            or len(entitlements_digest) != 32
            or (kind == "macho") != (type(entitlements_value) is str)
        ):
            fail("canonical projection contains an invalid internal entry")
        result.extend(pack_u32(len(path_raw)))
        result.extend(path_raw)
        result.extend(b"M" if kind == "macho" else b"R")
        result.extend(pack_u64(item["byteCount"]))
        result.extend(digest)
        result.extend(entitlements_digest)
    return bytes(result)


def raw_tree_record(entries: list[dict[str, Any]]) -> bytes:
    ordered = sorted(entries, key=lambda item: item["relativePath"].encode("utf-8"))
    result = bytearray(RAW_TREE_PREFIX)
    result.extend(pack_u32(len(ordered)))
    for item in ordered:
        path_raw = item["relativePath"].encode("utf-8")
        result.extend(pack_u32(len(path_raw)))
        result.extend(path_raw)
        mode_class = item.get("modeClass")
        if mode_class not in ("executable", "non-executable"):
            fail("raw application tree contains an invalid mode class")
        result.extend(b"E" if mode_class == "executable" else b"N")
        result.extend(pack_u64(item["byteCount"]))
        result.extend(bytes.fromhex(item["sha256"]))
    return bytes(result)


def candidate_exclusion_for_path(
    path: PurePosixPath,
) -> Optional[tuple[PurePosixPath, str, str]]:
    for root in EXACT_TEST_ONLY_ROOTS:
        if path == root or root in path.parents:
            return root, "directory", (
                "test-only-bundle"
                if root in EXACT_TEST_BUNDLE_ROOTS
                else "test-only-runtime"
            )
    if path in EXACT_TEST_RUNTIME_DYLIBS:
        return path, "file", "test-only-runtime"
    for index, component in enumerate(path.parts):
        folded = unicodedata.normalize("NFC", component).casefold()
        if folded == "_codesignature" and component != "_CodeSignature":
            fail("application tree contains an unreviewed code-signature exclusion spelling")
        if folded == "embedded.mobileprovision" and component != "embedded.mobileprovision":
            fail("application tree contains an unreviewed provisioning exclusion spelling")
        if folded.endswith(".xctest") and not component.endswith(".xctest"):
            fail("application tree contains an unreviewed XCTest exclusion spelling")
        if component == "_CodeSignature":
            return PurePosixPath(*path.parts[: index + 1]), "directory", "code-signature-material"
        if component == "embedded.mobileprovision":
            if index != len(path.parts) - 1:
                fail("embedded.mobileprovision must be one exact file leaf")
            return path, "file", "provisioning-material"
        if component.endswith(".xctest"):
            return PurePosixPath(*path.parts[: index + 1]), "directory", "test-only-bundle"
    return None


def path_is_excluded(
    path: PurePosixPath, exclusions: set[tuple[str, str, str]]
) -> bool:
    for relative, node_type, _ in exclusions:
        root = PurePosixPath(relative)
        if (node_type == "file" and path == root) or (
            node_type == "directory" and (path == root or root in path.parents)
        ):
            return True
    return False


def parse_nested_bundle_info(raw: bytes, root: PurePosixPath, label: str) -> tuple[str, str]:
    if not raw or len(raw) > MAX_PLIST_BYTES:
        fail(f"{label} recognized bundle {root} has an empty or oversized Info.plist")
    try:
        value = plistlib.loads(raw)
    except (plistlib.InvalidFileException, ValueError, TypeError, OverflowError) as error:
        fail(f"{label} recognized bundle {root} has invalid Info.plist: {error}")
    if type(value) is not dict:
        fail(f"{label} recognized bundle {root} Info.plist is not one dictionary")
    executable = value.get("CFBundleExecutable")
    package_type = value.get("CFBundlePackageType")
    bundle_id = value.get("CFBundleIdentifier")
    expected_type = "FMWK" if root.name.endswith(".framework") else "XPC!"
    if (
        type(executable) is not str
        or SAFE_COMPONENT_RE.fullmatch(executable) is None
        or package_type != expected_type
        or type(bundle_id) is not str
        or re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9.-]{0,511}", bundle_id) is None
    ):
        fail(f"{label} recognized bundle {root} has an invalid signed-bundle identity")
    return executable, expected_type


def resolve_exact_exclusions(
    *,
    label: str,
    records: list[
        tuple[
            str,
            int,
            int,
            str,
            Optional["MachOProjection"],
            Optional[bytes],
            bool,
        ]
    ],
    candidates: set[tuple[str, str, str]],
    allow_test_material: bool,
) -> tuple[set[tuple[str, str, str]], dict[PurePosixPath, str]]:
    records_by_path = {PurePosixPath(record[0]): record for record in records}
    bundle_roots: dict[PurePosixPath, str] = {PurePosixPath(): "app"}
    candidate_bundle_roots = {
        path.parent
        for path, record in records_by_path.items()
        if path.name == "Info.plist"
        and (path.parent.name.endswith(".framework") or path.parent.name.endswith(".appex"))
        and not any(
            path.parent == root or root in path.parent.parents
            for root in EXACT_TEST_ONLY_ROOTS
        )
    }
    for root in sorted(candidate_bundle_roots, key=lambda value: value.as_posix()):
        info_record = records_by_path[root / "Info.plist"]
        if info_record[5] is None:
            fail(f"{label} recognized bundle {root} lacks captured Info.plist bytes")
        executable, package_type = parse_nested_bundle_info(info_record[5], root, label)
        executable_record = records_by_path.get(root / executable)
        if (
            executable_record is None
            or executable_record[4] is None
            or not executable_record[1] & 0o111
        ):
            fail(f"{label} recognized bundle {root} lacks one direct executable Mach-O")
        bundle_roots[root] = "framework" if package_type == "FMWK" else "appex"

    resolved: set[tuple[str, str, str]] = set()
    for relative, node_type, reason in candidates:
        root = PurePosixPath(relative)
        if reason in {"test-only-bundle", "test-only-runtime"}:
            valid_exact = root in EXACT_TEST_ONLY_ROOTS or root in EXACT_TEST_RUNTIME_DYLIBS
            if not allow_test_material or not valid_exact:
                fail(f"{label} contains unreviewed or production XCTest-only material at {root}")
            resolved.add((relative, node_type, reason))
            continue
        if reason == "code-signature-material":
            bundle_root = root.parent
            if root.name != "_CodeSignature" or bundle_root not in bundle_roots:
                fail(f"{label} contains _CodeSignature outside a recognized signed-bundle root")
            resolved.add((relative, node_type, reason))
            continue
        if reason == "provisioning-material":
            bundle_root = root.parent
            if (
                root.name != "embedded.mobileprovision"
                or bundle_roots.get(bundle_root) not in {"app", "appex"}
            ):
                fail(
                    f"{label} contains embedded.mobileprovision outside a recognized app/appex root"
                )
            resolved.add((relative, node_type, reason))
            continue
        fail(f"{label} contains an unknown exclusion reason")
    return resolved, bundle_roots


def strict_entitlement_value(value: Any, label: str, depth: int = 0) -> Any:
    if depth > 16:
        fail(f"{label} exceeds the reviewed nesting depth")
    if type(value) in (str, bool, int):
        if type(value) is str and (not value or len(value.encode("utf-8")) > 4096):
            fail(f"{label} contains an invalid string")
        return value
    if type(value) is list:
        if len(value) > 256:
            fail(f"{label} contains too many values")
        return [strict_entitlement_value(child, f"{label}[]", depth + 1) for child in value]
    if type(value) is dict:
        if len(value) > 256 or any(type(key) is not str or not key for key in value):
            fail(f"{label} contains invalid keys")
        return {
            key: strict_entitlement_value(value[key], f"{label}.{key}", depth + 1)
            for key in sorted(value)
        }
    fail(f"{label} contains an unsupported property-list value")


@dataclass(frozen=True)
class EntitlementSlots:
    value: Optional[dict[str, Any]]
    xml_sha256: Optional[str]
    xml_byte_count: int
    der_sha256: Optional[str]
    der_byte_count: int
    der_decoder: Optional[dict[str, Any]]


def parse_entitlements_blob(signature: bytes, label: str) -> EntitlementSlots:
    if len(signature) < 12 or len(signature) > MAX_SIGNATURE_BYTES:
        fail(f"{label} is not a bounded embedded signature")
    magic, declared_length, count = struct.unpack_from(">III", signature, 0)
    if declared_length < 12 or declared_length > len(signature):
        fail(f"{label} SuperBlob declared length exceeds its LC_CODE_SIGNATURE allocation")
    if any(signature[declared_length:]):
        fail(f"{label} has nonzero LC_CODE_SIGNATURE allocation padding")
    superblob = signature[:declared_length]
    if (
        magic != CSMAGIC_EMBEDDED_SIGNATURE
        or count <= 0
        or count > 64
        or 12 + count * 8 > declared_length
    ):
        fail(f"{label} has an unknown SuperBlob shape")
    indexes: list[tuple[int, int]] = []
    seen_slots: set[int] = set()
    for index in range(count):
        slot, offset = struct.unpack_from(">II", superblob, 12 + index * 8)
        if slot in UNSUPPORTED_CONSTRAINT_SLOTS:
            fail(f"{label} contains an unsupported launch/library constraint slot")
        if slot not in CODE_SIGNATURE_SLOT_MAGICS or slot in seen_slots:
            fail(f"{label} contains an unknown or duplicate code-signature slot")
        if offset < 12 + count * 8 or offset + 8 > declared_length:
            fail(f"{label} contains an invalid code-signature blob offset")
        seen_slots.add(slot)
        indexes.append((slot, offset))
    ranges: list[tuple[int, int]] = []
    xml_payload: Optional[bytes] = None
    der_payload: Optional[bytes] = None
    for slot, offset in indexes:
        blob_magic, blob_length = struct.unpack_from(">II", superblob, offset)
        if (
            blob_magic != CODE_SIGNATURE_SLOT_MAGICS[slot]
            or blob_length < 8
            or offset + blob_length > declared_length
        ):
            fail(f"{label} contains a code-signature slot with an unknown magic or extent")
        blob_range = (offset, offset + blob_length)
        if any(blob_range[0] < end and start < blob_range[1] for start, end in ranges):
            fail(f"{label} contains overlapping code-signature blobs")
        ranges.append(blob_range)
        if slot == 5:
            if xml_payload is not None:
                fail(f"{label} contains an invalid embedded entitlement slot")
            xml_payload = superblob[offset + 8 : offset + blob_length]
        elif slot == 7:
            if der_payload is not None:
                fail(f"{label} contains an invalid DER entitlement slot")
            der_payload = superblob[offset + 8 : offset + blob_length]
    xml_value: Optional[dict[str, Any]] = None
    if xml_payload is not None:
        if not xml_payload:
            fail(f"{label} contains an empty XML entitlement blob")
        try:
            parsed = plistlib.loads(xml_payload)
        except (plistlib.InvalidFileException, ValueError, TypeError, OverflowError) as error:
            fail(f"{label} XML entitlements are invalid: {error}")
        if type(parsed) is not dict or not parsed:
            fail(f"{label} XML entitlements are not one nonempty dictionary")
        xml_value = strict_entitlement_value(parsed, f"{label} XML entitlements")
    der_value: Optional[dict[str, Any]] = None
    der_decoder: Optional[dict[str, Any]] = None
    if der_payload is not None:
        der_value, der_decoder = decode_der_entitlements(der_payload, label)
    if xml_value is not None and der_value is not None and xml_value != der_value:
        fail(f"{label} XML and DER entitlement slots have different semantics")
    value = xml_value if xml_value is not None else der_value
    return EntitlementSlots(
        value=value,
        xml_sha256=(
            hashlib.sha256(xml_payload).hexdigest() if xml_payload is not None else None
        ),
        xml_byte_count=len(xml_payload) if xml_payload is not None else 0,
        der_sha256=(
            hashlib.sha256(der_payload).hexdigest() if der_payload is not None else None
        ),
        der_byte_count=len(der_payload) if der_payload is not None else 0,
        der_decoder=der_decoder,
    )


def validate_c_string(command: bytes, offset_field: int, minimum: int, endian: str, label: str) -> None:
    if len(command) < minimum or offset_field + 4 > len(command):
        fail(f"{label} has an invalid string-command size")
    string_offset = struct.unpack_from(f"{endian}I", command, offset_field)[0]
    if string_offset < minimum or string_offset >= len(command) or b"\0" not in command[string_offset:]:
        fail(f"{label} has an invalid bounded command string")


def validate_load_command_shape(cmd: int, command: bytes, endian: str, is_64: bool, label: str) -> None:
    if cmd not in ALLOWED_COMMANDS:
        fail(f"{label} contains an unknown load command 0x{cmd:08x}")
    expected = FIXED_COMMAND_SIZES.get(cmd)
    if expected is not None and len(command) != expected:
        fail(f"{label} load command 0x{cmd:08x} has an unknown shape")
    if cmd in DYLIB_COMMANDS:
        validate_c_string(command, 8, 24, endian, label)
    elif cmd in STRING_COMMANDS:
        minimum = 20 if cmd in {LC_LOADFVMLIB, LC_IDFVMLIB} else 12
        validate_c_string(command, 8, minimum, endian, label)
    elif cmd in {LC_THREAD, LC_UNIXTHREAD}:
        fail(f"{label} contains an unsupported architecture-specific thread-state command")
    elif cmd == LC_PREBOUND_DYLIB:
        validate_c_string(command, 8, 20, endian, label)
    elif cmd == LC_LINKER_OPTION:
        if len(command) < 12:
            fail(f"{label} linker-option command has an unknown shape")
        count = struct.unpack_from(f"{endian}I", command, 8)[0]
        payload = command[12:]
        if count <= 0 or payload.count(b"\0") < count:
            fail(f"{label} linker-option command has invalid strings")
    elif cmd == LC_BUILD_VERSION:
        if len(command) < 24:
            fail(f"{label} build-version command has an unknown shape")
        tool_count = struct.unpack_from(f"{endian}I", command, 20)[0]
        if len(command) != 24 + tool_count * 8:
            fail(f"{label} build-version tools have an unknown shape")
    elif cmd == LC_FILESET_ENTRY:
        validate_c_string(command, 24, 32, endian, label)
    elif cmd in {LC_IDENT, LC_PREPAGE}:
        if len(command) != 8:
            fail(f"{label} obsolete command has an unknown shape")
    elif cmd == LC_FVMFILE:
        validate_c_string(command, 8, 16, endian, label)
    if len(command) % (8 if is_64 else 4) != 0:
        fail(f"{label} load command is not correctly aligned")


@dataclass(frozen=True)
class MachOProjection:
    sha256: str
    byte_count: int
    entitlements: Optional[dict[str, Any]]
    entitlement_slots: EntitlementSlots
    architectures: tuple[tuple[int, int], ...]


def hash_range_with_edits(
    descriptor: int,
    absolute_offset: int,
    length: int,
    edits: list[tuple[int, bytes]],
    label: str,
) -> str:
    ordered = sorted(edits)
    cursor = 0
    digest = hashlib.sha256()
    for edit_offset, replacement in ordered:
        if edit_offset < cursor or edit_offset + len(replacement) > length:
            fail(f"{label} contains overlapping canonical edits")
        remaining = edit_offset - cursor
        while remaining:
            chunk = os.pread(
                descriptor,
                min(1024 * 1024, remaining),
                absolute_offset + cursor,
            )
            if not chunk:
                fail(f"{label} ended while hashing canonical bytes")
            digest.update(chunk)
            cursor += len(chunk)
            remaining -= len(chunk)
        digest.update(replacement)
        cursor += len(replacement)
    remaining = length - cursor
    while remaining:
        chunk = os.pread(
            descriptor,
            min(1024 * 1024, remaining),
            absolute_offset + cursor,
        )
        if not chunk:
            fail(f"{label} ended while hashing canonical bytes")
        digest.update(chunk)
        cursor += len(chunk)
        remaining -= len(chunk)
    return digest.hexdigest()


def project_thin_macho(
    descriptor: int, base: int, size: int, label: str
) -> MachOProjection:
    if size < 28 or size > MAX_FILE_BYTES:
        fail(f"{label} is not a bounded thin Mach-O slice")
    magic_raw = pread_exact(descriptor, base, 4, label)
    magics = {
        b"\xce\xfa\xed\xfe": ("<", False),
        b"\xcf\xfa\xed\xfe": ("<", True),
        b"\xfe\xed\xfa\xce": (">", False),
        b"\xfe\xed\xfa\xcf": (">", True),
    }
    if magic_raw not in magics:
        fail(f"{label} has an unknown thin Mach-O magic")
    endian, is_64 = magics[magic_raw]
    header_size = 32 if is_64 else 28
    header = pread_exact(descriptor, base, header_size, label)
    fields = struct.unpack(f"{endian}IiiIIIII" if is_64 else f"{endian}IiiIIII", header)
    cpu_type = fields[1]
    cpu_subtype = fields[2]
    file_type = fields[3]
    command_count = fields[4]
    command_bytes = fields[5]
    if (
        file_type not in {2, 6, 8, 9, 11}
        or command_count <= 0
        or command_count > MAX_LOAD_COMMANDS
        or command_bytes <= 0
        or command_bytes > MAX_LOAD_COMMAND_BYTES
        or header_size + command_bytes >= size
    ):
        fail(f"{label} has an unknown Mach-O header shape")
    commands = pread_exact(descriptor, base + header_size, command_bytes, label)
    cursor = 0
    code_signature: Optional[tuple[int, int, int]] = None
    linkedit: Optional[tuple[int, int, int, int, int, int]] = None
    segment_ranges: list[tuple[int, int, str]] = []
    segments: list[dict[str, Any]] = []
    file_ranges: list[tuple[int, int, int, bool, str]] = []
    empty_linkedit_boundaries: list[tuple[int, int, str]] = []
    empty_symtab_symbol_offsets: list[tuple[int, int, int]] = []
    tls_zerofill_boundaries: list[tuple[int, str]] = []
    empty_encryption_offsets: list[tuple[int, int, str]] = []
    file_pointers: list[tuple[int, int, bool, str]] = []
    vm_pointers: list[tuple[int, int, str]] = []
    edits: list[tuple[int, bytes]] = []

    def add_file_range(
        start: int,
        count: int,
        unit: int,
        cmd: int,
        description: str,
        *,
        require_linkedit: bool,
    ) -> None:
        if count == 0:
            if start != 0:
                if (
                    cmd in EMPTY_LINKEDIT_BOUNDARY_COMMANDS
                    and require_linkedit
                    and unit == 1
                ):
                    empty_linkedit_boundaries.append((start, cmd, description))
                else:
                    fail(
                        f"{label} {description} has a nonzero offset for an empty range"
                    )
            return
        if start <= 0 or unit <= 0 or count > size // unit:
            fail(f"{label} {description} has an invalid file range")
        length = count * unit
        end = start + length
        if end > size or end <= start:
            fail(f"{label} {description} exceeds its slice")
        file_ranges.append((start, end, cmd, require_linkedit, description))

    for index in range(command_count):
        if cursor + 8 > len(commands):
            fail(f"{label} load-command inventory is truncated")
        cmd, cmdsize = struct.unpack_from(f"{endian}II", commands, cursor)
        if cmdsize < 8 or cursor + cmdsize > len(commands):
            fail(f"{label} load command has an invalid extent")
        command = commands[cursor : cursor + cmdsize]
        validate_load_command_shape(cmd, command, endian, is_64, label)
        absolute_command = header_size + cursor
        if cmd in {LC_SEGMENT, LC_SEGMENT_64}:
            expected_command = LC_SEGMENT_64 if is_64 else LC_SEGMENT
            if cmd != expected_command:
                fail(f"{label} mixes 32-bit and 64-bit segment commands")
            if is_64:
                if len(command) < 72:
                    fail(f"{label} segment command is truncated")
                name_raw = command[8:24]
                vm_address, vm_size, file_offset, file_size = struct.unpack_from(
                    f"{endian}QQQQ", command, 24
                )
                maximum_protection, initial_protection = struct.unpack_from(
                    f"{endian}ii", command, 56
                )
                section_count = struct.unpack_from(f"{endian}I", command, 64)[0]
                if len(command) != 72 + section_count * 80:
                    fail(f"{label} segment sections have an unknown shape")
                vm_size_offset = absolute_command + 32
                file_size_offset = absolute_command + 48
                integer_format = f"{endian}Q"
                section_size = 80
            else:
                if len(command) < 56:
                    fail(f"{label} segment command is truncated")
                name_raw = command[8:24]
                vm_address, vm_size, file_offset, file_size = struct.unpack_from(
                    f"{endian}IIII", command, 24
                )
                maximum_protection, initial_protection = struct.unpack_from(
                    f"{endian}ii", command, 40
                )
                section_count = struct.unpack_from(f"{endian}I", command, 48)[0]
                if len(command) != 56 + section_count * 68:
                    fail(f"{label} segment sections have an unknown shape")
                vm_size_offset = absolute_command + 28
                file_size_offset = absolute_command + 36
                integer_format = f"{endian}I"
                section_size = 68
            segment_name = name_raw.split(b"\0", 1)[0]
            if any(byte < 0x20 or byte > 0x7E for byte in segment_name):
                fail(f"{label} segment has an invalid name")
            name = segment_name.decode("ascii")
            if file_size:
                if file_offset + file_size > size:
                    fail(f"{label} segment exceeds its slice")
                if vm_size < file_size:
                    fail(f"{label} segment virtual size is smaller than its file-backed bytes")
                segment_ranges.append((file_offset, file_offset + file_size, name))
            elif file_offset != 0:
                fail(f"{label} empty segment has a nonzero file offset")
            segment = {
                "name": name,
                "vmAddress": vm_address,
                "vmSize": vm_size,
                "fileOffset": file_offset,
                "fileSize": file_size,
                "maximumProtection": maximum_protection,
                "initialProtection": initial_protection,
            }
            segments.append(segment)
            section_base = 72 if is_64 else 56
            segment_file_backed_sections: list[
                tuple[int, int, int, int, bytes, int]
            ] = []
            segment_tls_zerofill_sections: list[
                tuple[int, int, int, bytes]
            ] = []
            for section_index in range(section_count):
                section_offset = section_base + section_index * section_size
                section = command[section_offset : section_offset + section_size]
                section_name_raw = section[0:16]
                section_segment_raw = section[16:32]
                if is_64:
                    section_address, section_byte_count = struct.unpack_from(
                        f"{endian}QQ", section, 32
                    )
                    section_file_offset, alignment, relocation_offset, relocation_count, flags = (
                        struct.unpack_from(f"{endian}IIIII", section, 48)
                    )
                else:
                    section_address, section_byte_count, section_file_offset, alignment, relocation_offset, relocation_count, flags = (
                        struct.unpack_from(f"{endian}IIIIIII", section, 32)
                    )
                section_name = section_name_raw.split(b"\0", 1)[0]
                section_segment_name = section_segment_raw.split(b"\0", 1)[0]
                if (
                    any(byte < 0x20 or byte > 0x7E for byte in section_name)
                    or section_segment_name != segment_name
                    or alignment > 30
                    or section_address < vm_address
                    or section_address + section_byte_count < section_address
                    or section_address + section_byte_count > vm_address + vm_size
                ):
                    fail(f"{label} section has an invalid reviewed segment mapping")
                section_type = flags & 0xFF
                if section_byte_count and section_type not in ZEROFILL_SECTION_TYPES:
                    if (
                        section_file_offset < file_offset
                        or section_file_offset + section_byte_count < section_file_offset
                        or section_file_offset + section_byte_count > file_offset + file_size
                    ):
                        fail(f"{label} file-backed section exceeds its owning segment")
                    add_file_range(
                        section_file_offset,
                        section_byte_count,
                        1,
                        cmd,
                        f"section {section_name.decode('ascii')} data",
                        require_linkedit=False,
                    )
                    segment_file_backed_sections.append(
                        (
                            section_address,
                            section_address + section_byte_count,
                            section_file_offset,
                            section_file_offset + section_byte_count,
                            section_name,
                            section_type,
                        )
                    )
                elif section_type in ZEROFILL_SECTION_TYPES and section_file_offset != 0:
                    if section_type != S_THREAD_LOCAL_ZEROFILL:
                        fail(f"{label} zero-fill section has a nonzero file offset")
                    segment_tls_zerofill_sections.append(
                        (
                            section_address,
                            section_byte_count,
                            section_file_offset,
                            section_name,
                        )
                    )
                add_file_range(
                    relocation_offset,
                    relocation_count,
                    8,
                    cmd,
                    f"section {section_name.decode('ascii')} relocations",
                    require_linkedit=True,
                )
            for tls_address, tls_size, tls_file_offset, tls_name in (
                segment_tls_zerofill_sections
            ):
                address_derived_offset = file_offset + (tls_address - vm_address)
                predecessors = [
                    section
                    for section in segment_file_backed_sections
                    if section[1] == tls_address
                    and section[3] == tls_file_offset
                    and section[4] == b"__thread_data"
                    and section[5] == S_THREAD_LOCAL_REGULAR
                ]
                if (
                    name != "__DATA"
                    or tls_name != b"__thread_bss"
                    or tls_size <= 0
                    or tls_file_offset != address_derived_offset
                    or not (file_offset <= tls_file_offset <= file_offset + file_size)
                    or len(predecessors) != 1
                    or any(
                        vm_start < tls_address + tls_size and tls_address < vm_end
                        for vm_start, vm_end, _, _, _, _ in segment_file_backed_sections
                    )
                    or any(
                        file_start < tls_file_offset < file_end
                        for _, _, file_start, file_end, _, _ in segment_file_backed_sections
                    )
                ):
                    fail(
                        f"{label} TLS zero-fill section is not one exact "
                        "address-derived file boundary"
                    )
                tls_zerofill_boundaries.append(
                    (tls_file_offset, f"section {tls_name.decode('ascii')} zero-fill boundary")
                )
            if name == "__LINKEDIT":
                if linkedit is not None or file_size <= 0 or vm_size <= 0:
                    fail(f"{label} has an absent or ambiguous __LINKEDIT segment")
                linkedit = (
                    file_offset,
                    file_size,
                    vm_size,
                    vm_size_offset,
                    file_size_offset,
                    struct.calcsize(integer_format),
                )
        elif cmd == LC_CODE_SIGNATURE:
            data_offset, data_size = struct.unpack_from(f"{endian}II", command, 8)
            if code_signature is not None or data_offset <= 0 or data_size <= 0:
                fail(f"{label} has an absent or ambiguous LC_CODE_SIGNATURE")
            code_signature = (data_offset, data_size, absolute_command + 8)
        elif cmd in LINKEDIT_DATA_COMMANDS:
            data_offset, data_size = struct.unpack_from(f"{endian}II", command, 8)
            add_file_range(
                data_offset,
                data_size,
                1,
                cmd,
                f"load command 0x{cmd:08x} payload",
                require_linkedit=True,
            )
        elif cmd == LC_SYMTAB:
            symbol_offset, symbol_count, string_offset, string_size = struct.unpack_from(
                f"{endian}IIII", command, 8
            )
            if symbol_count == 0 and symbol_offset != 0:
                empty_symtab_symbol_offsets.append(
                    (symbol_offset, string_offset, string_size)
                )
            else:
                add_file_range(
                    symbol_offset,
                    symbol_count,
                    16 if is_64 else 12,
                    cmd,
                    "symbol table",
                    require_linkedit=True,
                )
            add_file_range(
                string_offset,
                string_size,
                1,
                cmd,
                "symbol string table",
                require_linkedit=True,
            )
        elif cmd == LC_SYMSEG:
            data_offset, data_size = struct.unpack_from(f"{endian}II", command, 8)
            add_file_range(
                data_offset,
                data_size,
                1,
                cmd,
                "obsolete symbol segment",
                require_linkedit=True,
            )
        elif cmd == LC_DYSYMTAB:
            values = struct.unpack_from(f"{endian}18I", command, 8)
            for description, offset_value, count_value, unit in (
                ("dynamic table of contents", values[6], values[7], 8),
                ("dynamic module table", values[8], values[9], 56 if is_64 else 52),
                ("dynamic referenced-symbol table", values[10], values[11], 4),
                ("dynamic indirect-symbol table", values[12], values[13], 4),
                ("external relocation table", values[14], values[15], 8),
                ("local relocation table", values[16], values[17], 8),
            ):
                add_file_range(
                    offset_value,
                    count_value,
                    unit,
                    cmd,
                    description,
                    require_linkedit=True,
                )
        elif cmd == LC_TWOLEVEL_HINTS:
            data_offset, hint_count = struct.unpack_from(f"{endian}II", command, 8)
            add_file_range(
                data_offset,
                hint_count,
                4,
                cmd,
                "two-level namespace hints",
                require_linkedit=True,
            )
        elif cmd in {LC_DYLD_INFO, LC_DYLD_INFO_ONLY}:
            values = struct.unpack_from(f"{endian}10I", command, 8)
            for description, pair_index in (
                ("dyld rebase opcodes", 0),
                ("dyld bind opcodes", 2),
                ("dyld weak-bind opcodes", 4),
                ("dyld lazy-bind opcodes", 6),
                ("dyld export trie", 8),
            ):
                add_file_range(
                    values[pair_index],
                    values[pair_index + 1],
                    1,
                    cmd,
                    description,
                    require_linkedit=True,
                )
        elif cmd == LC_NOTE:
            data_offset, data_size = struct.unpack_from(f"{endian}QQ", command, 24)
            add_file_range(
                data_offset,
                data_size,
                1,
                cmd,
                "note payload",
                require_linkedit=False,
            )
        elif cmd in {LC_ENCRYPTION_INFO, LC_ENCRYPTION_INFO_64}:
            crypt_offset, crypt_size, crypt_id = struct.unpack_from(f"{endian}III", command, 8)
            padding = (
                struct.unpack_from(f"{endian}I", command, 20)[0]
                if cmd == LC_ENCRYPTION_INFO_64
                else 0
            )
            if crypt_id != 0 or padding != 0:
                fail(f"{label} is encrypted or has an invalid encryption range")
            if (
                is_64
                and cmd in EMPTY_ENCRYPTION_BOUNDARY_COMMANDS
                and crypt_size == 0
                and crypt_offset != 0
            ):
                empty_encryption_offsets.append(
                    (crypt_offset, cmd, "empty unencrypted payload declaration")
                )
            else:
                add_file_range(
                    crypt_offset,
                    crypt_size,
                    1,
                    cmd,
                    "unencrypted payload declaration",
                    require_linkedit=False,
                )
        elif cmd == LC_MAIN:
            entry_offset = struct.unpack_from(f"{endian}Q", command, 8)[0]
            file_pointers.append((entry_offset, cmd, True, "LC_MAIN entry point"))
        elif cmd == LC_FILESET_ENTRY:
            file_offset = struct.unpack_from(f"{endian}Q", command, 16)[0]
            file_pointers.append((file_offset, cmd, False, "LC_FILESET_ENTRY file offset"))
        elif cmd == LC_ROUTINES:
            initial_address = struct.unpack_from(f"{endian}I", command, 8)[0]
            if initial_address:
                vm_pointers.append((initial_address, cmd, "LC_ROUTINES initializer"))
        elif cmd == LC_ROUTINES_64:
            initial_address = struct.unpack_from(f"{endian}Q", command, 8)[0]
            if initial_address:
                vm_pointers.append((initial_address, cmd, "LC_ROUTINES_64 initializer"))
        cursor += cmdsize
    if cursor != len(commands) or code_signature is None or linkedit is None:
        fail(f"{label} has an incomplete reviewed load-command inventory")
    signature_offset, signature_size, signature_fields_offset = code_signature
    if signature_offset + signature_size != size:
        fail(f"{label} code signature is overlapping, out of range, or nonterminal")
    linkedit_offset, linkedit_size, linkedit_vm_size, vm_size_offset, file_size_offset, integer_size = linkedit
    page_size = 16384 if (cpu_type & 0x00FFFFFF) == CPU_TYPE_ARM else 4096
    rounded_linkedit_size = (linkedit_size + page_size - 1) // page_size * page_size
    if (
        linkedit_offset >= signature_offset
        or linkedit_offset + linkedit_size != size
        or not (linkedit_offset <= signature_offset < size)
        or linkedit_vm_size != rounded_linkedit_size
    ):
        fail(
            f"{label} __LINKEDIT does not exactly contain the terminal signature "
            "with its reviewed page-rounded mapping"
        )
    for start, end, cmd, require_linkedit, description in file_ranges:
        if end > signature_offset or start >= end:
            fail(f"{label} {description} from command 0x{cmd:08x} overlaps signing material")
        if require_linkedit and start < linkedit_offset:
            fail(f"{label} {description} is outside the reviewed __LINKEDIT segment")
    for symbol_offset, string_offset, string_size in empty_symtab_symbol_offsets:
        expected_string_range = (
            string_offset,
            string_offset + string_size,
            LC_SYMTAB,
            True,
            "symbol string table",
        )
        if (
            string_size <= 0
            or symbol_offset != string_offset
            or expected_string_range not in file_ranges
        ):
            fail(
                f"{label} empty LC_SYMTAB symbol offset is not the admitted "
                "nonempty string-table start"
            )
    # The terminal signature start is the one admitted signature boundary.
    # Its end is the slice end, not a payload start, and remains rejected.
    admitted_linkedit_boundaries = {signature_offset}
    nonempty_linkedit_ranges = [
        (start, end)
        for start, end, _, require_linkedit, _ in file_ranges
        if require_linkedit
    ]
    for start, end in nonempty_linkedit_ranges:
        admitted_linkedit_boundaries.update((start, end))
    for pointer, cmd, description in empty_linkedit_boundaries:
        if (
            pointer not in admitted_linkedit_boundaries
            or any(start < pointer < end for start, end in nonempty_linkedit_ranges)
            or signature_offset < pointer < signature_offset + signature_size
        ):
            fail(
                f"{label} {description} from command 0x{cmd:08x} is not an "
                "admitted empty __LINKEDIT boundary"
            )
    for pointer, description in tls_zerofill_boundaries:
        if pointer <= 0 or pointer >= signature_offset:
            fail(f"{label} {description} reaches signing material or leaves its slice")
    nonempty_segments = sorted(segment_ranges)
    for (_, previous_end, previous_name), (start, _, name) in zip(
        nonempty_segments, nonempty_segments[1:]
    ):
        if start < previous_end:
            fail(f"{label} segments {previous_name} and {name} overlap")
    for pointer, cmd, description in empty_encryption_offsets:
        exact_text_successors = [
            (previous, following)
            for previous, following in zip(
                nonempty_segments, nonempty_segments[1:]
            )
            if previous[0] == 0
            and previous[1] == pointer
            and previous[2] == "__TEXT"
            and following[0] == pointer
        ]
        if (
            pointer != EMPTY_ENCRYPTION_INFO_64_FILE_OFFSET
            or (cpu_type & 0x00FFFFFF) != CPU_TYPE_ARM
            or pointer >= signature_offset
            or len(exact_text_successors) != 1
        ):
            fail(
                f"{label} {description} from command 0x{cmd:08x} is not the "
                "exact 16K __TEXT/next-segment boundary"
            )
    for pointer, cmd, executable_required, description in file_pointers:
        matching_segments = [
            segment
            for segment in segments
            if segment["fileSize"]
            and segment["fileOffset"] <= pointer < segment["fileOffset"] + segment["fileSize"]
        ]
        if (
            pointer >= signature_offset
            or len(matching_segments) != 1
            or (
                executable_required
                and not matching_segments[0]["initialProtection"] & 0x4
            )
        ):
            fail(f"{label} {description} from command 0x{cmd:08x} is not before signing material in one reviewed segment")
    for pointer, cmd, description in vm_pointers:
        matching_segments = [
            segment
            for segment in segments
            if segment["vmSize"]
            and segment["vmAddress"] <= pointer < segment["vmAddress"] + segment["vmSize"]
        ]
        if len(matching_segments) != 1:
            fail(f"{label} {description} from command 0x{cmd:08x} is outside one reviewed segment")
        segment = matching_segments[0]
        delta = pointer - segment["vmAddress"]
        if (
            not segment["initialProtection"] & 0x4
            or delta >= segment["fileSize"]
            or segment["fileOffset"] + delta >= signature_offset
        ):
            fail(f"{label} {description} resolves into non-file-backed or signing material")
    unsigned_linkedit_size = signature_offset - linkedit_offset
    unsigned_linkedit_vm_size = (
        (unsigned_linkedit_size + page_size - 1) // page_size * page_size
    )
    integer_format = f"{endian}{'Q' if integer_size == 8 else 'I'}"
    edits.extend(
        [
            (signature_fields_offset, b"\0" * 8),
            (vm_size_offset, struct.pack(integer_format, unsigned_linkedit_vm_size)),
            (file_size_offset, struct.pack(integer_format, unsigned_linkedit_size)),
        ]
    )
    digest = hash_range_with_edits(
        descriptor, base, signature_offset, edits, f"{label} canonical slice"
    )
    signature = pread_exact(
        descriptor, base + signature_offset, signature_size, f"{label} code signature"
    )
    entitlement_slots = parse_entitlements_blob(signature, f"{label} code signature")
    return MachOProjection(
        sha256=digest,
        byte_count=signature_offset,
        entitlements=entitlement_slots.value,
        entitlement_slots=entitlement_slots,
        architectures=((cpu_type, cpu_subtype),),
    )


def project_macho_descriptor(descriptor: int, size: int, label: str) -> MachOProjection:
    if size <= 0 or size > MAX_FILE_BYTES:
        fail(f"{label} is not a bounded nonempty Mach-O file")
    magic = pread_exact(descriptor, 0, 4, label)
    thin_magics = {
        b"\xce\xfa\xed\xfe",
        b"\xcf\xfa\xed\xfe",
        b"\xfe\xed\xfa\xce",
        b"\xfe\xed\xfa\xcf",
    }
    if magic in thin_magics:
        return project_thin_macho(descriptor, 0, size, label)
    fat_formats = {
        b"\xca\xfe\xba\xbe": (">", False),
        b"\xbe\xba\xfe\xca": ("<", False),
        b"\xca\xfe\xba\xbf": (">", True),
        b"\xbf\xba\xfe\xca": ("<", True),
    }
    if magic not in fat_formats:
        fail(f"{label} is executable/Mach-O-shaped but has an unknown magic")
    endian, is_64 = fat_formats[magic]
    header = pread_exact(descriptor, 0, 8, label)
    arch_count = struct.unpack_from(f"{endian}I", header, 4)[0]
    entry_size = 32 if is_64 else 20
    if arch_count <= 0 or arch_count > MAX_FAT_ARCHES or 8 + arch_count * entry_size >= size:
        fail(f"{label} fat header has an unknown shape")
    entries_raw = pread_exact(descriptor, 8, arch_count * entry_size, label)
    arches: list[tuple[int, int, int, int, int]] = []
    identities: set[tuple[int, int]] = set()
    for index in range(arch_count):
        offset = index * entry_size
        if is_64:
            cpu_type, cpu_subtype, slice_offset, slice_size, alignment, reserved = struct.unpack_from(
                f"{endian}iiQQII", entries_raw, offset
            )
            if reserved != 0:
                fail(f"{label} fat64 architecture has a nonzero reserved field")
        else:
            cpu_type, cpu_subtype, slice_offset, slice_size, alignment = struct.unpack_from(
                f"{endian}iiIII", entries_raw, offset
            )
        if (
            (cpu_type, cpu_subtype) in identities
            or alignment > 30
            or slice_offset % (1 << alignment) != 0
            or slice_size <= 0
            or slice_offset < 8 + arch_count * entry_size
            or slice_offset + slice_size > size
        ):
            fail(f"{label} fat architecture has an invalid identity or range")
        identities.add((cpu_type, cpu_subtype))
        arches.append((cpu_type, cpu_subtype, slice_offset, slice_size, alignment))
    ordered_ranges = sorted((offset, offset + length) for _, _, offset, length, _ in arches)
    cursor = 8 + arch_count * entry_size
    for start, end in ordered_ranges:
        if start < cursor:
            fail(f"{label} fat architecture ranges overlap")
        padding = pread_exact(descriptor, cursor, start - cursor, f"{label} fat padding")
        if any(padding):
            fail(f"{label} fat layout hides nonzero bytes outside its slices")
        cursor = end
    trailing = pread_exact(descriptor, cursor, size - cursor, f"{label} fat trailing padding")
    if any(trailing):
        fail(f"{label} fat layout has nonzero trailing bytes")
    projected: list[tuple[int, int, int, MachOProjection]] = []
    for cpu_type, cpu_subtype, offset, length, alignment in arches:
        child = project_thin_macho(
            descriptor, offset, length, f"{label} architecture {cpu_type}:{cpu_subtype}"
        )
        if child.architectures != ((cpu_type, cpu_subtype),):
            fail(f"{label} fat architecture differs from its thin header")
        projected.append((cpu_type, cpu_subtype, alignment, child))
    projected.sort(key=lambda item: (item[0], item[1]))
    entitlement_values = [item[3].entitlements for item in projected]
    if any(value != entitlement_values[0] for value in entitlement_values[1:]):
        fail(f"{label} fat slices carry different signed entitlements")
    entitlement_slots = [item[3].entitlement_slots for item in projected]
    if any(value != entitlement_slots[0] for value in entitlement_slots[1:]):
        fail(f"{label} fat slices carry different XML/DER entitlement-slot projections")
    record = bytearray(FAT_PROJECTION_PREFIX)
    record.extend(pack_u32(len(projected)))
    canonical_size = 0
    for cpu_type, cpu_subtype, alignment, child in projected:
        record.extend(struct.pack(">iiI", cpu_type, cpu_subtype, alignment))
        record.extend(pack_u64(child.byte_count))
        record.extend(bytes.fromhex(child.sha256))
        canonical_size += child.byte_count
    return MachOProjection(
        sha256=hashlib.sha256(record).hexdigest(),
        byte_count=canonical_size,
        entitlements=entitlement_values[0],
        entitlement_slots=entitlement_slots[0],
        architectures=tuple((item[0], item[1]) for item in projected),
    )


def is_macho_magic(raw: bytes) -> bool:
    return raw in {
        b"\xce\xfa\xed\xfe",
        b"\xcf\xfa\xed\xfe",
        b"\xfe\xed\xfa\xce",
        b"\xfe\xed\xfa\xcf",
        b"\xca\xfe\xba\xbe",
        b"\xbe\xba\xfe\xca",
        b"\xca\xfe\xba\xbf",
        b"\xbf\xba\xfe\xca",
    }


def reviewed_executable_non_macho_resource(
    relative: PurePosixPath, mode: int, magic: bytes, label: str
) -> bool:
    expected_magic = next(
        (
            expected
            for reviewed_path, expected in REVIEWED_EXECUTABLE_NON_MACHO_RESOURCES
            if reviewed_path == relative.as_posix()
        ),
        None,
    )
    if expected_magic is None:
        return False
    if magic != expected_magic:
        fail(f"{label}:{relative} reviewed executable resource has unexpected magic")
    if not mode & 0o111 or mode not in REVIEWED_EXECUTABLE_NON_MACHO_MODES:
        fail(f"{label}:{relative} reviewed executable resource has unexpected mode")
    return True


@dataclass(frozen=True)
class AppInspection:
    projection: dict[str, Any]
    raw_tree: dict[str, Any]
    exclusions: tuple[dict[str, str], ...]
    info: dict[str, str]
    executable_raw_sha256: str
    executable_byte_count: int
    executable_canonical_sha256: str
    main_entitlements: dict[str, Any]
    entitlement_projection: tuple[dict[str, Any], ...]
    entitlements_by_path: tuple[tuple[str, Optional[dict[str, Any]]], ...]
    entitlement_slot_presence_by_path: tuple[tuple[str, bool, bool], ...]


def reviewed_entitlements(entitlements: Optional[dict[str, Any]]) -> dict[str, Any]:
    if entitlements is None:
        return {}
    return {
        key: value
        for key, value in entitlements.items()
        if key not in ALLOWED_SIGNING_ENTITLEMENT_DIFFERENCES
    }


def reviewed_entitlements_sha256(entitlements: Optional[dict[str, Any]]) -> str:
    return hashlib.sha256(canonical_json(reviewed_entitlements(entitlements))).hexdigest()


def summarize_records(
    projection_entries: list[dict[str, Any]], raw_entries: list[dict[str, Any]]
) -> tuple[dict[str, Any], dict[str, Any]]:
    if not projection_entries or not raw_entries:
        fail("application inspection produced an empty semantic or raw tree")
    projection_raw = projection_record(projection_entries)
    raw_tree_raw = raw_tree_record(raw_entries)
    return (
        {
            "contractId": PROJECTION_CONTRACT_ID,
            "recordSha256": hashlib.sha256(projection_raw).hexdigest(),
            "recordByteCount": len(projection_raw),
            "fileCount": len(projection_entries),
            "semanticByteCount": sum(item["byteCount"] for item in projection_entries),
        },
        {
            "contractId": RAW_TREE_CONTRACT_ID,
            "recordSha256": hashlib.sha256(raw_tree_raw).hexdigest(),
            "recordByteCount": len(raw_tree_raw),
            "fileCount": len(raw_entries),
            "rawByteCount": sum(item["byteCount"] for item in raw_entries),
        },
    )


def parse_app_info(raw: bytes, label: str) -> dict[str, str]:
    if not raw or len(raw) > MAX_PLIST_BYTES:
        fail(f"{label} Info.plist is empty or oversized")
    try:
        value = plistlib.loads(raw)
    except (plistlib.InvalidFileException, ValueError, TypeError, OverflowError) as error:
        fail(f"{label} Info.plist is invalid: {error}")
    if type(value) is not dict:
        fail(f"{label} Info.plist is not one dictionary")
    executable = value.get("CFBundleExecutable")
    bundle_id = value.get("CFBundleIdentifier")
    short_version = value.get("CFBundleShortVersionString")
    build_version = value.get("CFBundleVersion")
    if (
        bundle_id != PRODUCTION_BUNDLE_ID
        or type(executable) is not str
        or SAFE_COMPONENT_RE.fullmatch(executable) is None
        or type(short_version) is not str
        or SAFE_VERSION_RE.fullmatch(short_version) is None
        or type(build_version) is not str
        or SAFE_VERSION_RE.fullmatch(build_version) is None
    ):
        fail(f"{label} does not preserve the fixed production bundle identity")
    return {
        "bundleIdentifier": bundle_id,
        "executableName": executable,
        "shortVersion": short_version,
        "buildVersion": build_version,
    }


def inspect_app_records(
    *,
    label: str,
    records: list[
        tuple[
            str,
            int,
            int,
            str,
            Optional[MachOProjection],
            Optional[bytes],
            bool,
        ]
    ],
    exclusions: set[tuple[str, str, str]],
    allow_test_material: bool,
) -> AppInspection:
    if len(records) <= 0 or len(records) > MAX_FILES:
        fail(f"{label} has an empty or unbounded file inventory")
    raw_entries: list[dict[str, Any]] = []
    projection_entries: list[dict[str, Any]] = []
    info_raw: Optional[bytes] = None
    resolved_exclusions, _ = resolve_exact_exclusions(
        label=label,
        records=records,
        candidates=exclusions,
        allow_test_material=allow_test_material,
    )
    total = 0
    normalized: set[str] = set()
    for relative, mode, size, raw_sha, macho, retained_raw, _ in records:
        safe_relative(relative, f"{label} path")
        normalized_value = normalized_path(relative)
        if normalized_value in normalized:
            fail(f"{label} contains an NFC/casefold path collision")
        normalized.add(normalized_value)
        total += size
        if size <= 0 or total > MAX_APP_BYTES:
            fail(f"{label} contains an empty or unbounded semantic input")
        raw_entries.append(
            {
                "relativePath": relative,
                "modeClass": "executable" if mode & 0o111 else "non-executable",
                "byteCount": size,
                "sha256": raw_sha,
            }
        )
        if path_is_excluded(PurePosixPath(relative), resolved_exclusions):
            continue
        if relative == "Info.plist":
            if retained_raw is None or info_raw is not None:
                fail(f"{label} has an absent or ambiguous Info.plist")
            info_raw = retained_raw
    if info_raw is None:
        fail(f"{label} lacks its fixed Info.plist")
    info = parse_app_info(info_raw, label)
    executable_name = info["executableName"]
    matching = [record for record in records if record[0] == executable_name]
    if len(matching) != 1 or matching[0][4] is None:
        fail(f"{label} lacks one Mach-O at its declared executable path")
    main_raw_size = matching[0][2]
    main_raw_sha = matching[0][3]
    main_projection = matching[0][4]
    assert main_projection is not None and main_raw_sha is not None
    if main_projection.entitlements is None:
        fail(f"{label} main executable lacks parsed signed entitlements")
    entitlement_projection: list[dict[str, Any]] = []
    entitlements_by_path: list[tuple[str, Optional[dict[str, Any]]]] = []
    entitlement_slot_presence_by_path: list[tuple[str, bool, bool]] = []
    for relative, mode, size, raw_sha, macho, _, reviewed_non_macho in records:
        if path_is_excluded(PurePosixPath(relative), resolved_exclusions):
            continue
        if macho is None:
            if mode & 0o111 and not reviewed_non_macho:
                fail(f"{label} contains a non-Mach-O executable file")
            projection_entries.append(
                {
                    "relativePath": relative,
                    "kind": "resource",
                    "byteCount": size,
                    "sha256": raw_sha,
                }
            )
            continue
        if not mode & 0o111:
            fail(f"{label} contains a non-executable Mach-O file")
        reviewed_sha = reviewed_entitlements_sha256(macho.entitlements)
        projection_entries.append(
            {
                "relativePath": relative,
                "kind": "macho",
                "byteCount": macho.byte_count,
                "sha256": macho.sha256,
                "reviewedEntitlementsSha256": reviewed_sha,
            }
        )
        entitlements_by_path.append((relative, macho.entitlements))
        slots = macho.entitlement_slots
        entitlement_slot_presence_by_path.append(
            (relative, slots.xml_sha256 is not None, slots.der_sha256 is not None)
        )
        entitlement_projection.append(
            {
                "relativePath": relative,
                "hasEntitlements": macho.entitlements is not None,
                "signedEntitlementsSha256": (
                    hashlib.sha256(canonical_json(macho.entitlements)).hexdigest()
                    if macho.entitlements is not None
                    else None
                ),
                "reviewedEntitlementsSha256": reviewed_sha,
                "xmlEntitlementsSlotSha256": slots.xml_sha256,
                "xmlEntitlementsSlotByteCount": slots.xml_byte_count,
                "derEntitlementsSlotSha256": slots.der_sha256,
                "derEntitlementsSlotByteCount": slots.der_byte_count,
            }
        )
    projection, raw_tree = summarize_records(projection_entries, raw_entries)
    exclusion_values = tuple(
        {
            "relativePath": relative,
            "nodeType": node_type,
            "reason": reason,
        }
        for relative, node_type, reason in sorted(resolved_exclusions)
    )
    if not exclusion_values or not any(
        item["reason"] == "code-signature-material" for item in exclusion_values
    ) or not any(item["reason"] == "provisioning-material" for item in exclusion_values):
        fail(f"{label} lacks exact signature/provisioning exclusion instances")
    return AppInspection(
        projection=projection,
        raw_tree=raw_tree,
        exclusions=exclusion_values,
        info=info,
        executable_raw_sha256=main_raw_sha,
        executable_byte_count=main_raw_size,
        executable_canonical_sha256=main_projection.sha256,
        main_entitlements=main_projection.entitlements,
        entitlement_projection=tuple(entitlement_projection),
        entitlements_by_path=tuple(entitlements_by_path),
        entitlement_slot_presence_by_path=tuple(entitlement_slot_presence_by_path),
    )


def inspect_app_directory(path: Path, label: str) -> AppInspection:
    root_fd = open_absolute_directory(path, label, require_private_ancestor=True)
    records: list[
        tuple[
            str,
            int,
            int,
            str,
            Optional[MachOProjection],
            Optional[bytes],
            bool,
        ]
    ] = []
    exclusions: set[tuple[str, str, str]] = set()
    seen_inodes: set[tuple[int, int]] = set()
    normalized_nodes: set[str] = set()

    def walk(directory_fd: int, prefix: PurePosixPath) -> int:
        try:
            names = sorted(os.listdir(directory_fd), key=lambda value: value.encode("utf-8"))
        except OSError as error:
            fail(f"{label} cannot be enumerated: {error}")
        if not names:
            fail(f"{label} contains an empty directory")
        descendant_files = 0
        for name in names:
            if SAFE_APP_COMPONENT_RE.fullmatch(name) is None:
                fail(f"{label} contains an unsafe path component")
            relative = prefix / name
            normalized = normalized_path(relative.as_posix())
            if normalized in normalized_nodes:
                fail(f"{label} contains an NFC/casefold node collision")
            normalized_nodes.add(normalized)
            metadata = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
            inode = (metadata.st_dev, metadata.st_ino)
            if inode in seen_inodes:
                fail(f"{label} contains a hard-link or directory alias")
            seen_inodes.add(inode)
            exclusion = candidate_exclusion_for_path(relative)
            if exclusion is not None:
                actual_type = "directory" if stat.S_ISDIR(metadata.st_mode) else "file"
                if exclusion[0] == relative and exclusion[1] != actual_type:
                    fail(f"{label} contains an exclusion with an unreviewed node type")
                exclusions.add((exclusion[0].as_posix(), exclusion[1], exclusion[2]))
            if stat.S_ISDIR(metadata.st_mode):
                child = os.open(
                    name,
                    os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0),
                    dir_fd=directory_fd,
                )
                try:
                    opened = os.fstat(child)
                    if metadata_identity(opened) != metadata_identity(metadata):
                        fail(f"{label} directory changed during anchored open")
                    count = walk(child, relative)
                finally:
                    os.close(child)
                descendant_files += count
                continue
            if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1 or metadata.st_uid != os.getuid():
                fail(f"{label} contains a symbolic, special, linked, or foreign-owned file")
            if not 0 < metadata.st_size <= MAX_FILE_BYTES:
                fail(f"{label} contains an empty or oversized file")
            descriptor = os.open(
                name,
                os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0),
                dir_fd=directory_fd,
            )
            try:
                before = os.fstat(descriptor)
                raw_sha, raw_size = hash_descriptor(descriptor, MAX_FILE_BYTES, f"{label}:{relative}")
                magic = pread_exact(descriptor, 0, min(4, raw_size), f"{label}:{relative}")
                excluded = candidate_exclusion_for_path(relative) is not None
                file_mode = stat.S_IMODE(metadata.st_mode)
                reviewed_non_macho = reviewed_executable_non_macho_resource(
                    relative, file_mode, magic, label
                )
                macho: Optional[MachOProjection] = None
                if (
                    not excluded
                    and not reviewed_non_macho
                    and (is_macho_magic(magic) or file_mode & 0o111)
                ):
                    macho = project_macho_descriptor(descriptor, raw_size, f"{label}:{relative}")
                retained_raw = (
                    pread_exact(descriptor, 0, raw_size, f"{label}:{relative}")
                    if relative.name == "Info.plist" and raw_size <= MAX_PLIST_BYTES
                    else None
                )
                after = os.fstat(descriptor)
                named_after = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
                if (
                    raw_size != before.st_size
                    or metadata_identity(before) != metadata_identity(after)
                    or metadata_identity(before) != metadata_identity(named_after)
                ):
                    fail(f"{label}:{relative} changed while being inspected")
            finally:
                os.close(descriptor)
            records.append(
                (
                    relative.as_posix(),
                    stat.S_IMODE(metadata.st_mode),
                    raw_size,
                    raw_sha,
                    macho,
                    retained_raw,
                    reviewed_non_macho,
                )
            )
            descendant_files += 1
            if len(records) > MAX_FILES:
                fail(f"{label} exceeds its file-count bound")
        if descendant_files <= 0:
            fail(f"{label} contains an empty semantic directory")
        return descendant_files

    before = os.fstat(root_fd)
    try:
        walk(root_fd, PurePosixPath())
        after = os.fstat(root_fd)
        if metadata_identity(before) != metadata_identity(after):
            fail(f"{label} root changed while being inspected")
    finally:
        os.close(root_fd)
    return inspect_app_records(
        label=label,
        records=records,
        exclusions=exclusions,
        allow_test_material=True,
    )


def safe_zip_member(info: zipfile.ZipInfo, label: str) -> PurePosixPath:
    name = info.filename
    path = PurePosixPath(name)
    canonical = "/".join(path.parts) + ("/" if info.is_dir() else "")
    mode = (info.external_attr >> 16) & 0xFFFF
    if (
        not name
        or name.startswith("/")
        or "\\" in name
        or any(
            part in ("", ".", "..")
            or SAFE_APP_COMPONENT_RE.fullmatch(part) is None
            for part in path.parts
        )
        or canonical != name
        or info.flag_bits & 0x1
        or (mode and not (stat.S_ISREG(mode) or stat.S_ISDIR(mode)))
    ):
        fail(f"{label} contains an unsafe ZIP member: {name!r}")
    return path


def spool_zip_member(
    archive: zipfile.ZipFile, info: zipfile.ZipInfo, label: str
) -> tuple[BinaryIO, str, int]:
    if not 0 < info.file_size <= MAX_FILE_BYTES:
        fail(f"{label} is empty or exceeds its byte bound")
    # SpooledTemporaryFile rolls to an owner-only unnamed/unlinked temporary
    # file; no caller-controlled path is followed for proprietary app bytes.
    spool = tempfile.SpooledTemporaryFile(max_size=8 * 1024 * 1024)
    digest = hashlib.sha256()
    consumed = 0
    try:
        with archive.open(info, "r") as source:
            while True:
                chunk = source.read(1024 * 1024)
                if not chunk:
                    break
                consumed += len(chunk)
                if consumed > info.file_size or consumed > MAX_FILE_BYTES:
                    fail(f"{label} exceeds its declared byte count")
                digest.update(chunk)
                spool.write(chunk)
        if consumed != info.file_size:
            fail(f"{label} differs from its ZIP byte count")
        spool.flush()
        spool.seek(0)
        return spool, digest.hexdigest(), consumed
    except Exception:
        spool.close()
        raise


def inspect_ipa_descriptor(descriptor: int, label: str) -> AppInspection:
    records: list[
        tuple[
            str,
            int,
            int,
            str,
            Optional[MachOProjection],
            Optional[bytes],
            bool,
        ]
    ] = []
    exclusions: set[tuple[str, str, str]] = set()
    try:
        with os.fdopen(os.dup(descriptor), "rb") as source, zipfile.ZipFile(
            source, "r", allowZip64=True
        ) as archive:
            infos = archive.infolist()
            if not infos or len(infos) > MAX_ZIP_ENTRIES:
                fail(f"{label} has an empty or unbounded ZIP inventory")
            seen_names: set[str] = set()
            normalized_names: set[str] = set()
            app_roots: set[PurePosixPath] = set()
            explicit_directories: set[str] = set()
            file_names: set[str] = set()
            total = 0
            parsed: list[tuple[zipfile.ZipInfo, PurePosixPath]] = []
            for info in infos:
                path = safe_zip_member(info, label)
                normalized = normalized_path(info.filename.rstrip("/"))
                if info.filename in seen_names or normalized in normalized_names:
                    fail(f"{label} contains a duplicate or NFC/casefold-colliding ZIP member")
                seen_names.add(info.filename)
                normalized_names.add(normalized)
                total += info.file_size
                if total > MAX_APP_BYTES * 2:
                    fail(f"{label} exceeds its aggregate ZIP byte bound")
                if info.is_dir():
                    explicit_directories.add(info.filename.rstrip("/"))
                else:
                    file_names.add(info.filename)
                if len(path.parts) >= 2 and path.parts[0] == "Payload" and path.parts[1].endswith(".app"):
                    app_roots.add(PurePosixPath(*path.parts[:2]))
                parsed.append((info, path))
            if len(app_roots) != 1:
                fail(f"{label} must contain exactly one top-level application")
            app_root = next(iter(app_roots))
            for directory in explicit_directories:
                if not any(name.startswith(directory + "/") for name in file_names):
                    fail(f"{label} contains an empty ZIP directory")
            for info, path in parsed:
                if info.is_dir() or path.parts[:2] != app_root.parts:
                    continue
                relative = PurePosixPath(*path.parts[2:])
                if not relative.parts:
                    continue
                exclusion = candidate_exclusion_for_path(relative)
                if exclusion is not None:
                    if exclusion[0] == relative and exclusion[1] != "file":
                        fail(f"{label} contains an exclusion with an unreviewed node type")
                    exclusions.add((exclusion[0].as_posix(), exclusion[1], exclusion[2]))
                mode = (info.external_attr >> 16) & 0xFFFF
                file_mode = stat.S_IMODE(mode) if mode else 0o644
                spool, raw_sha, raw_size = spool_zip_member(
                    archive, info, f"{label}:{relative}"
                )
                try:
                    file_descriptor = spool.fileno()
                    magic = pread_exact(file_descriptor, 0, min(4, raw_size), f"{label}:{relative}")
                    reviewed_non_macho = reviewed_executable_non_macho_resource(
                        relative, file_mode, magic, label
                    )
                    macho: Optional[MachOProjection] = None
                    if (
                        exclusion is None
                        and not reviewed_non_macho
                        and (is_macho_magic(magic) or file_mode & 0o111)
                    ):
                        macho = project_macho_descriptor(
                            file_descriptor, raw_size, f"{label}:{relative}"
                        )
                    retained_raw = (
                        pread_exact(file_descriptor, 0, raw_size, f"{label}:{relative}")
                        if relative.name == "Info.plist" and raw_size <= MAX_PLIST_BYTES
                        else None
                    )
                finally:
                    spool.close()
                records.append(
                    (
                        relative.as_posix(),
                        file_mode,
                        raw_size,
                        raw_sha,
                        macho,
                        retained_raw,
                        reviewed_non_macho,
                    )
                )
    except (OSError, zipfile.BadZipFile, zipfile.LargeZipFile, RuntimeError) as error:
        fail(f"{label} ZIP cannot be inspected: {error}")
    return inspect_app_records(
        label=label,
        records=records,
        exclusions=exclusions,
        allow_test_material=False,
    )


def inspect_ipa(path: Path) -> tuple[AppInspection, str, int]:
    descriptor, before = open_absolute_regular(path, MAX_IPA_BYTES, "production IPA")
    try:
        ipa_sha, ipa_size = hash_descriptor(descriptor, MAX_IPA_BYTES, "production IPA")
        inspection = inspect_ipa_descriptor(descriptor, "production IPA app")
        second_sha, second_size = hash_descriptor(descriptor, MAX_IPA_BYTES, "production IPA recheck")
        after = os.fstat(descriptor)
        parent = open_absolute_directory(path.parent, "production IPA parent recheck", require_private_ancestor=True)
        try:
            named_after = os.stat(path.name, dir_fd=parent, follow_symlinks=False)
        finally:
            os.close(parent)
        if (
            ipa_sha != second_sha
            or ipa_size != second_size
            or metadata_identity(before) != metadata_identity(after)
            or metadata_identity(before) != metadata_identity(named_after)
        ):
            fail("production IPA changed during derivation")
        return inspection, ipa_sha, ipa_size
    finally:
        os.close(descriptor)


def entitlement_group_array(
    value: Any, label: str, *, optional: bool
) -> list[str]:
    if value is None and optional:
        return []
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
        fail(f"{label} is not one ordered, bounded access-group array")
    return list(value)


def effective_keychain_access_groups(
    entitlements: dict[str, Any], label: str
) -> list[str]:
    application_id = entitlements.get("application-identifier")
    if type(application_id) is not str or not application_id:
        fail(f"{label} lacks one application identifier")
    explicit_groups = entitlement_group_array(
        entitlements.get("keychain-access-groups"),
        f"{label} explicit Keychain access groups",
        optional="keychain-access-groups" not in entitlements,
    )
    application_groups = entitlement_group_array(
        entitlements.get("com.apple.security.application-groups"),
        f"{label} application groups",
        optional="com.apple.security.application-groups" not in entitlements,
    )
    # Security derives the ordered effective list from the optional explicit
    # Keychain groups, the application identifier, and then application groups.
    # Preserve first occurrence so absent and explicit-default forms have the
    # same runtime identity; do not sort or import profile-only wildcard/token
    # entries.
    effective: list[str] = []
    seen: set[str] = set()
    for group in explicit_groups + [application_id] + application_groups:
        if group not in seen:
            seen.add(group)
            effective.append(group)
    return effective


def signing_identity(entitlements: dict[str, Any], label: str) -> dict[str, Any]:
    application_id = entitlements.get("application-identifier")
    team_id = entitlements.get("com.apple.developer.team-identifier")
    if (
        application_id != f"{PRODUCTION_TEAM_ID}.{PRODUCTION_BUNDLE_ID}"
        or team_id != PRODUCTION_TEAM_ID
    ):
        fail(f"{label} does not preserve the production team/application/Keychain identity")
    effective_groups = effective_keychain_access_groups(entitlements, label)
    return {
        "applicationIdentifier": application_id,
        "teamIdentifier": team_id,
        "keychainAccessGroupsSha256": hashlib.sha256(
            canonical_json(effective_groups)
        ).hexdigest(),
        "signedEntitlementsSha256": hashlib.sha256(canonical_json(entitlements)).hexdigest(),
    }


def validate_nested_signing_identity(
    relative_path: str, entitlements: Optional[dict[str, Any]], label: str
) -> None:
    if entitlements is None:
        return
    application_id = entitlements.get("application-identifier")
    team_id = entitlements.get("com.apple.developer.team-identifier")
    if (
        team_id != PRODUCTION_TEAM_ID
        or type(application_id) is not str
        or not application_id.startswith(f"{PRODUCTION_TEAM_ID}.")
    ):
        fail(
            f"{label} entitlement-bearing Mach-O {relative_path} does not preserve "
            "the production team/application/Keychain identity shape"
        )
    effective_keychain_access_groups(
        entitlements, f"{label} entitlement-bearing Mach-O {relative_path}"
    )


def per_path_entitlement_differences(
    production: AppInspection, test_host: AppInspection
) -> list[dict[str, Any]]:
    production_map = dict(production.entitlements_by_path)
    test_map = dict(test_host.entitlements_by_path)
    if set(production_map) != set(test_map):
        fail("production and test-host Mach-O entitlement path inventories differ")
    production_slot_map = {
        path: (has_xml, has_der)
        for path, has_xml, has_der in production.entitlement_slot_presence_by_path
    }
    test_slot_map = {
        path: (has_xml, has_der)
        for path, has_xml, has_der in test_host.entitlement_slot_presence_by_path
    }
    if production_slot_map != test_slot_map:
        fail("production and test-host XML/DER entitlement slot inventories differ")
    differences: list[dict[str, Any]] = []
    for relative_path in sorted(production_map):
        production_entitlements = production_map[relative_path]
        test_entitlements = test_map[relative_path]
        validate_nested_signing_identity(
            relative_path, production_entitlements, "production IPA"
        )
        validate_nested_signing_identity(
            relative_path, test_entitlements, "Release test host"
        )
        production_values = production_entitlements or {}
        test_values = test_entitlements or {}
        keys = sorted(set(production_values) | set(test_values))
        for key in keys:
            production_value = production_values.get(key)
            test_value = test_values.get(key)
            if production_value == test_value:
                continue
            if key not in ALLOWED_SIGNING_ENTITLEMENT_DIFFERENCES:
                fail(
                    "test host differs in unreviewed signed entitlement at "
                    f"{relative_path}: {key}"
                )
            if key == "get-task-allow" and not (
                production_value in (None, False) and test_value is True
            ):
                fail(
                    f"test host {relative_path} get-task-allow difference is not "
                    "the reviewed XCTest signing transition"
                )
            if key == "beta-reports-active" and not (
                production_value in (None, True) and test_value in (None, False)
            ):
                fail(
                    f"test host {relative_path} beta-reports-active difference is unreviewed"
                )
            if key == "aps-environment" and not (
                production_value in ("production", None)
                and test_value in ("development", "production", None)
            ):
                fail(f"test host {relative_path} aps-environment difference is unreviewed")
            differences.append(
                {
                    "relativePath": relative_path,
                    "key": key,
                    "productionValueSha256": hashlib.sha256(
                        canonical_json(production_value)
                    ).hexdigest(),
                    "testHostValueSha256": hashlib.sha256(
                        canonical_json(test_value)
                    ).hexdigest(),
                }
            )
    return differences


def inspection_projection(value: AppInspection) -> dict[str, Any]:
    identity = signing_identity(
        value.main_entitlements, "application signed entitlements"
    )
    return {
        "bundleIdentifier": value.info["bundleIdentifier"],
        "shortVersion": value.info["shortVersion"],
        "buildVersion": value.info["buildVersion"],
        "executableName": value.info["executableName"],
        "rawExecutableSha256": value.executable_raw_sha256,
        "rawExecutableByteCount": value.executable_byte_count,
        "canonicalExecutableSha256": value.executable_canonical_sha256,
        "canonicalProjection": value.projection,
        "rawTree": value.raw_tree,
        "signedIdentity": identity,
        "signedEntitlementProjection": list(value.entitlement_projection),
        "exactExclusions": list(value.exclusions),
    }


def derive_receipt(
    ipa_path: Path,
    test_host_path: Path,
    qualification_contract_sha: str,
) -> dict[str, Any]:
    require_sha256(qualification_contract_sha, "qualification source contract")
    if ipa_path == test_host_path or ipa_path in test_host_path.parents or test_host_path in ipa_path.parents:
        fail("production IPA and test-host paths must be disjoint")
    der_decoder = fixed_derq_identity()
    production, ipa_sha, ipa_size = inspect_ipa(ipa_path)
    test_host = inspect_app_directory(test_host_path, "Release build-for-testing host")
    # A complete second inspection rejects transient mutations restored between
    # individual file reads and receipt publication.
    production_recheck, recheck_sha, recheck_size = inspect_ipa(ipa_path)
    test_host_recheck = inspect_app_directory(test_host_path, "Release build-for-testing host recheck")
    if (
        production != production_recheck
        or test_host != test_host_recheck
        or ipa_sha != recheck_sha
        or ipa_size != recheck_size
    ):
        fail("derivation inputs changed between complete inspections")
    if fixed_derq_identity() != der_decoder:
        fail("fixed DER entitlement decoder changed between complete inspections")
    if production.info != test_host.info:
        fail("test host does not preserve production bundle/version/executable identity")
    production_identity = signing_identity(
        production.main_entitlements, "production IPA"
    )
    test_identity = signing_identity(
        test_host.main_entitlements, "Release test host"
    )
    for key in ("applicationIdentifier", "teamIdentifier", "keychainAccessGroupsSha256"):
        if production_identity[key] != test_identity[key]:
            fail("test host does not preserve production signing/Keychain identity")
    differences = per_path_entitlement_differences(production, test_host)
    if production.projection != test_host.projection:
        fail("test host canonical application projection differs from the production IPA")
    if production.executable_canonical_sha256 != test_host.executable_canonical_sha256:
        fail("test host canonical executable differs from the production IPA")
    production_projection = inspection_projection(production)
    test_projection = inspection_projection(test_host)
    return {
        "schemaVersion": SCHEMA_VERSION,
        "contractId": CONTRACT_ID,
        "platform": "ios",
        "status": "observed",
        "releaseAuthorized": False,
        "promotionAuthorized": False,
        "qualificationContractSha256": qualification_contract_sha,
        "projectionContract": {
            "schemaVersion": 2,
            "contractId": PROJECTION_CONTRACT_ID,
            "exactExclusionRules": list(EXCLUSION_RULES),
            "allowedSigningEntitlementDifferences": list(
                ALLOWED_SIGNING_ENTITLEMENT_DIFFERENCES
            ),
            "derEntitlementDecoder": der_decoder,
        },
        "cryptographicValidityBoundary": {
            "productionIpa": "collector-codesign-deep-strict-and-provisioning-verification-required",
            "releaseTestHost": (
                "collector-codesign-deep-strict-plus-successful-ios-install-launch-and-"
                "installed-raw-tree-recomputation-and-canonical-projection-transitive-"
                "binding-required"
            ),
            "claimedByDerivationController": False,
        },
        "productionIpa": {
            "sha256": ipa_sha,
            "byteCount": ipa_size,
            **production_projection,
        },
        "releaseTestHost": test_projection,
        "derivation": {
            "canonicalProjectionEqual": True,
            "canonicalExecutableEqual": True,
            "productionIdentityPreserved": True,
            "allMachOEntitlementsReviewedPerPath": True,
            "rawExecutableEqualityRequired": False,
            "canonicalDerivedTestHostAccepted": True,
            "reviewedSigningEntitlementDifferences": differences,
        },
        "checks": {
            "allInputsAliasFree": True,
            "allFilesUniqueRegular": True,
            "allPathsCollisionFree": True,
            "allMachOSlicesParsed": True,
            "allEntitlementSlotsMappedAndSemanticallyMatched": True,
            "allNonSignatureFileRangesPrecedeTerminalSignature": True,
            "terminalCodeSignaturesOnly": True,
            "exactExclusionsOnly": True,
            "completeProjectionMatched": True,
            "productionSigningIdentityPreserved": True,
            "secondCompleteInspectionMatched": True,
            "controllerNonAuthorizing": True,
        },
        "blockingReasons": [BLOCKER],
    }


def load_receipt(path: Path) -> tuple[dict[str, Any], bytes, str]:
    descriptor, before = open_absolute_regular(path, MAX_JSON_BYTES, "test-host derivation receipt")
    try:
        raw = pread_exact(descriptor, 0, before.st_size, "test-host derivation receipt")
        after = os.fstat(descriptor)
        if metadata_identity(before) != metadata_identity(after):
            fail("test-host derivation receipt changed while being read")
    finally:
        os.close(descriptor)
    try:
        value = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fail(f"test-host derivation receipt is invalid JSON: {error}")
    if type(value) is not dict or canonical_json(value) != raw:
        fail("test-host derivation receipt is not exact canonical JSON")
    return value, raw, hashlib.sha256(raw).hexdigest()


def write_receipt(path: Path, receipt: dict[str, Any]) -> tuple[str, tuple[int, ...]]:
    parent = open_absolute_directory(path.parent, "derivation receipt parent", require_private_ancestor=True)
    raw = canonical_json(receipt)
    created_inode: Optional[tuple[int, int]] = None
    try:
        descriptor = os.open(
            path.name,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0),
            0o600,
            dir_fd=parent,
        )
        try:
            created_inode = inode_identity(os.fstat(descriptor))
            offset = 0
            while offset < len(raw):
                written = os.write(descriptor, raw[offset:])
                if written <= 0:
                    fail("derivation receipt write made no progress")
                offset += written
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
        os.fsync(parent)
        opened = os.open(
            path.name,
            os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0),
            dir_fd=parent,
        )
        try:
            metadata = os.fstat(opened)
            actual = pread_exact(opened, 0, metadata.st_size, "published derivation receipt")
            after = os.fstat(opened)
            named_after = os.stat(path.name, dir_fd=parent, follow_symlinks=False)
            if (
                not stat.S_ISREG(metadata.st_mode)
                or metadata.st_nlink != 1
                or metadata.st_uid != os.getuid()
                or stat.S_IMODE(metadata.st_mode) != 0o600
                or actual != raw
                or metadata_identity(metadata) != metadata_identity(after)
                or metadata_identity(metadata) != metadata_identity(named_after)
            ):
                fail("published derivation receipt differs from its exact protected bytes")
        finally:
            os.close(opened)
        published_identity = metadata_identity(after)
        return hashlib.sha256(raw).hexdigest(), published_identity
    except Exception:
        if created_inode is not None:
            try:
                current = os.stat(path.name, dir_fd=parent, follow_symlinks=False)
                if (
                    inode_identity(current) != created_inode
                    or not stat.S_ISREG(current.st_mode)
                    or current.st_nlink != 1
                    or current.st_uid != os.getuid()
                ):
                    fail("failed derivation receipt output was replaced before exact withdrawal")
                os.unlink(path.name, dir_fd=parent)
                os.fsync(parent)
            except FileNotFoundError:
                pass
        raise
    finally:
        os.close(parent)


def withdraw_exact_receipt(
    path: Path, expected_sha: str, expected_identity: tuple[int, ...]
) -> None:
    parent = open_absolute_directory(
        path.parent, "derivation receipt withdrawal parent", require_private_ancestor=True
    )
    descriptor: Optional[int] = None
    try:
        descriptor = os.open(
            path.name,
            os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0),
            dir_fd=parent,
        )
        before = os.fstat(descriptor)
        digest, _ = hash_descriptor(
            descriptor, MAX_JSON_BYTES, "failed derivation receipt withdrawal"
        )
        named = os.stat(path.name, dir_fd=parent, follow_symlinks=False)
        if (
            not stat.S_ISREG(before.st_mode)
            or before.st_nlink != 1
            or digest != expected_sha
            or metadata_identity(before) != expected_identity
            or metadata_identity(before) != metadata_identity(named)
        ):
            fail("failed derivation receipt is no longer the exact published output")
        os.unlink(path.name, dir_fd=parent)
        os.fsync(parent)
        try:
            os.stat(path.name, dir_fd=parent, follow_symlinks=False)
        except FileNotFoundError:
            return
        fail("failed derivation receipt remained after exact withdrawal")
    finally:
        if descriptor is not None:
            os.close(descriptor)
        os.close(parent)


def create(
    ipa_raw: str, test_host_raw: str, output_raw: str, qualification_contract_sha: str
) -> dict[str, str]:
    ipa = safe_absolute(ipa_raw, "production IPA")
    test_host = safe_absolute(test_host_raw, "Release test host")
    output = safe_absolute(output_raw, "derivation receipt output")
    if output.suffix != ".json" or SAFE_COMPONENT_RE.fullmatch(output.name) is None:
        fail("derivation receipt output must use one safe .json leaf")
    if output == ipa or output == test_host or output in test_host.parents:
        fail("derivation receipt output must be disjoint from its inputs")
    output_parent = open_absolute_directory(
        output.parent, "derivation receipt parent", require_private_ancestor=True
    )
    os.close(output_parent)
    receipt = derive_receipt(ipa, test_host, qualification_contract_sha)
    receipt_sha, published_identity = write_receipt(output, receipt)
    try:
        final_receipt = derive_receipt(ipa, test_host, qualification_contract_sha)
        if canonical_json(final_receipt) != canonical_json(receipt):
            fail("derivation inputs changed after observed receipt publication")
    except Exception:
        withdraw_exact_receipt(output, receipt_sha, published_identity)
        raise
    return {
        "ipaSha256": receipt["productionIpa"]["sha256"],
        "testHostRawTreeSha256": receipt["releaseTestHost"]["rawTree"]["recordSha256"],
        "testHostRawTreeRecordByteCount": receipt["releaseTestHost"]["rawTree"]["recordByteCount"],
        "canonicalProjectionSha256": receipt["releaseTestHost"]["canonicalProjection"]["recordSha256"],
        "canonicalProjectionRecordByteCount": receipt["releaseTestHost"]["canonicalProjection"]["recordByteCount"],
        "testHostExecutableSha256": receipt["releaseTestHost"]["rawExecutableSha256"],
        "testHostExecutableByteCount": receipt["releaseTestHost"]["rawExecutableByteCount"],
        "derivationReceiptSha256": receipt_sha,
    }


def verify(
    ipa_raw: str,
    test_host_raw: str,
    receipt_raw: str,
    expected_qualification_contract_sha: str,
) -> dict[str, str]:
    ipa = safe_absolute(ipa_raw, "protected production IPA")
    test_host = safe_absolute(test_host_raw, "protected Release test host")
    receipt_path = safe_absolute(receipt_raw, "protected derivation receipt")
    expected_contract = require_sha256(
        expected_qualification_contract_sha, "expected qualification source contract"
    )
    receipt, raw, receipt_sha = load_receipt(receipt_path)
    if receipt.get("qualificationContractSha256") != expected_contract:
        fail("test-host derivation receipt has a stale qualification source contract")
    independently_derived = derive_receipt(ipa, test_host, expected_contract)
    if canonical_json(independently_derived) != raw:
        fail("test-host derivation receipt differs from independent raw-byte recomputation")
    return {
        "ipaSha256": independently_derived["productionIpa"]["sha256"],
        "testHostRawTreeSha256": independently_derived["releaseTestHost"]["rawTree"]["recordSha256"],
        "testHostRawTreeRecordByteCount": independently_derived["releaseTestHost"]["rawTree"]["recordByteCount"],
        "canonicalProjectionSha256": independently_derived["releaseTestHost"]["canonicalProjection"]["recordSha256"],
        "canonicalProjectionRecordByteCount": independently_derived["releaseTestHost"]["canonicalProjection"]["recordByteCount"],
        "testHostExecutableSha256": independently_derived["releaseTestHost"]["rawExecutableSha256"],
        "testHostExecutableByteCount": independently_derived["releaseTestHost"]["rawExecutableByteCount"],
        "derivationReceiptSha256": receipt_sha,
    }


def lint_contract() -> None:
    if [rule["ruleId"] for rule in EXCLUSION_RULES] != [
        "terminal-macho-code-signature-v2",
        "recognized-bundle-code-signature-directory-v2",
        "recognized-bundle-embedded-provision-v2",
        "scheme-xctest-bundles-v2",
        "xctest-runtime-frameworks-v2",
        "xctest-runtime-dylibs-v2",
    ]:
        fail("derivation exclusion rule inventory drifted")
    if tuple(sorted(ALLOWED_SIGNING_ENTITLEMENT_DIFFERENCES)) != ALLOWED_SIGNING_ENTITLEMENT_DIFFERENCES:
        fail("allowed signing entitlement differences are not exact and sorted")
    if tuple(
        (path, magic.hex())
        for path, magic in REVIEWED_EXECUTABLE_NON_MACHO_RESOURCES
    ) != (
        (
            "Frameworks/GoogleAdsOnDeviceConversion.framework/Info.plist",
            "3c3f786d",
        ),
        ("GoogleSignIn_GoogleSignIn.bundle/Roboto-Bold.ttf", "00010000"),
        (
            "Frameworks/GoogleSignIn_FD4A0B4974F15B1_PackageProduct.framework/"
            "GoogleSignIn_GoogleSignIn.bundle/Roboto-Bold.ttf",
            "00010000",
        ),
    ):
        fail("reviewed executable non-Mach-O resource inventory drifted")
    if REVIEWED_EXECUTABLE_NON_MACHO_MODES != (0o700, 0o755):
        fail("reviewed executable non-Mach-O mode inventory drifted")
    if LC_CODE_SIGNATURE not in ALLOWED_COMMANDS or LC_SEGMENT_64 not in ALLOWED_COMMANDS:
        fail("Mach-O projection command inventory is incomplete")
    if (
        EMPTY_LINKEDIT_BOUNDARY_COMMANDS != (LC_DATA_IN_CODE,)
        or LC_DATA_IN_CODE not in LINKEDIT_DATA_COMMANDS
        or FIXED_COMMAND_SIZES.get(LC_DATA_IN_CODE) != 16
    ):
        fail("empty __LINKEDIT boundary command inventory drifted")
    if (
        EMPTY_ENCRYPTION_BOUNDARY_COMMANDS != (LC_ENCRYPTION_INFO_64,)
        or FIXED_COMMAND_SIZES.get(LC_ENCRYPTION_INFO_64) != 24
        or EMPTY_ENCRYPTION_INFO_64_FILE_OFFSET != 16 * 1024
        or CPU_TYPE_ARM != 12
        or ZEROFILL_SECTION_TYPES
        != {S_ZEROFILL, S_GB_ZEROFILL, S_THREAD_LOCAL_ZEROFILL}
        or S_THREAD_LOCAL_REGULAR != 0x11
        or S_THREAD_LOCAL_ZEROFILL != 0x12
    ):
        fail("Apple Mach-O boundary exception inventory drifted")
    expected_test_bundles = {
        "PlugIns/SoraPassportTests.xctest",
        "PlugIns/SoraPassportIntegrationTests.xctest",
    }
    if {path.as_posix() for path in EXACT_TEST_BUNDLE_ROOTS} != expected_test_bundles:
        fail("scheme-bound XCTest bundle exclusion inventory drifted")
    scheme_path = (
        ROOT
        / "SoraPassport.xcodeproj/xcshareddata/xcschemes/SoraPassportMigrationEvidence.xcscheme"
    )
    try:
        scheme_metadata = os.lstat(scheme_path)
        if stat.S_ISLNK(scheme_metadata.st_mode) or not stat.S_ISREG(scheme_metadata.st_mode):
            fail("migration evidence scheme is absent or symbolic")
        scheme_root = ET.parse(scheme_path).getroot()
    except (OSError, ET.ParseError) as error:
        fail(f"migration evidence scheme cannot bind XCTest exclusions: {error}")
    scheme_test_bundles = {
        node.get("BuildableName")
        for node in scheme_root.findall("./TestAction/Testables/TestableReference/BuildableReference")
    }
    if scheme_test_bundles != {path.name for path in EXACT_TEST_BUNDLE_ROOTS}:
        fail("scheme Testables differ from the exact XCTest bundle exclusion roots")


def main(argv: list[str]) -> int:
    try:
        if len(argv) >= 2 and argv[0] == "--repository-root":
            configure_repository_root(argv[1])
            argv = argv[2:]
        if argv == ["--lint-contract"]:
            lint_contract()
            print("iOS migration canonical test-host derivation contract: OK")
            return 0
        if (
            len(argv) == 9
            and argv[0] == "--derive"
            and argv[1] == "--ipa"
            and argv[3] == "--test-host"
            and argv[5] == "--output"
            and argv[7] == "--qualification-contract-sha"
        ):
            lint_contract()
            result = create(argv[2], argv[4], argv[6], argv[8])
        elif (
            len(argv) == 9
            and argv[0] == "--verify-raw"
            and argv[1] == "--ipa"
            and argv[3] == "--test-host"
            and argv[5] == "--receipt"
            and argv[7] == "--expected-qualification-contract-sha"
        ):
            lint_contract()
            result = verify(argv[2], argv[4], argv[6], argv[8])
        else:
            fail(
                "usage: derive-ios-migration-test-host.py --lint-contract | "
                "[--repository-root /absolute/repository] "
                "--derive --ipa /private/Sora.ipa --test-host /private/SoraPassport.app "
                "--output /private/derivation.json --qualification-contract-sha SHA256 | "
                "--verify-raw --ipa /private/Sora.ipa --test-host /private/SoraPassport.app "
                "--receipt /private/derivation.json --expected-qualification-contract-sha SHA256"
            )
        print(" ".join(f"{key}={value}" for key, value in result.items()))
        return 0
    except (DerivationError, OSError, ValueError, struct.error) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
