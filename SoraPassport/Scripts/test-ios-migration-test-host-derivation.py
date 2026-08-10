#!/usr/bin/env python3
"""Hermetic regressions for canonical production-IPA test-host derivation."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import plistlib
import re
import stat
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from typing import Any
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / "SoraPassport/Scripts/derive-ios-migration-test-host.py"
SPEC = importlib.util.spec_from_file_location("ios_migration_host_derivation", TOOL)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


DEFAULT_DER_VALUE = object()
GOOGLE_ADS_INFO_PATH = (
    "Frameworks/GoogleAdsOnDeviceConversion.framework/Info.plist"
)
GOOGLE_SIGNIN_FONT_PATH = "GoogleSignIn_GoogleSignIn.bundle/Roboto-Bold.ttf"
GOOGLE_SIGNIN_NESTED_FONT_PATH = (
    "Frameworks/GoogleSignIn_FD4A0B4974F15B1_PackageProduct.framework/"
    "GoogleSignIn_GoogleSignIn.bundle/Roboto-Bold.ttf"
)
GOOGLE_SIGNIN_NESTED_FONT_NEAR_PATH = (
    "Frameworks/GoogleSignIn_FD4A0B4974F15B1_PackageProduct.framework/"
    "GoogleSignIn_GoogleSignIn.bundle/Roboto-Bold-copy.ttf"
)
GOOGLE_SIGNIN_FONT = b"\x00\x01\x00\x00synthetic-reviewed-font"


def der_length(value: int) -> bytes:
    if value < 0x80:
        return bytes([value])
    encoded = value.to_bytes((value.bit_length() + 7) // 8, "big")
    return bytes([0x80 | len(encoded)]) + encoded


def der_entitlements(value: dict[str, Any]) -> bytes:
    xml = plistlib.dumps(value, fmt=plistlib.FMT_XML, sort_keys=True)
    result = subprocess.run(
        ["/usr/bin/derq", "query", "-f", "xml", "-i", "-", "-o", "-"],
        input=xml,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        env=MODULE.SAFE_TOOL_ENV,
        timeout=30,
    )
    if result.returncode != 0 or not result.stdout or len(result.stderr) > 64 * 1024:
        raise RuntimeError("fixed derq cannot encode synthetic entitlement control")
    content = b"\x02\x01\x01" + result.stdout
    return b"\x70" + der_length(len(content)) + content


def entitlement_blob(
    value: dict[str, Any] | None,
    marker: bytes,
    *,
    der_value: object = DEFAULT_DER_VALUE,
) -> bytes:
    wrapper_payload = marker * 19
    wrapper = struct.pack(">II", MODULE.CSMAGIC_BLOBWRAPPER, 8 + len(wrapper_payload)) + wrapper_payload
    children: list[tuple[int, bytes]] = []
    if value is not None:
        payload = plistlib.dumps(value, fmt=plistlib.FMT_BINARY, sort_keys=True)
        entitlements = (
            struct.pack(">II", MODULE.CSMAGIC_ENTITLEMENTS, 8 + len(payload))
            + payload
        )
        children.append((5, entitlements))
        selected_der = value if der_value is DEFAULT_DER_VALUE else der_value
        if selected_der is not None:
            if type(selected_der) is not dict:
                raise TypeError("synthetic DER entitlements must be a dictionary or None")
            der_payload = der_entitlements(selected_der)
            children.append(
                (
                    7,
                    struct.pack(">II", MODULE.CSMAGIC_DER_ENTITLEMENTS, 8 + len(der_payload))
                    + der_payload,
                )
            )
    children.append((0x10000, wrapper))
    count = len(children)
    header_size = 12 + count * 8
    result = bytearray(struct.pack(">III", MODULE.CSMAGIC_EMBEDDED_SIGNATURE, 0, count))
    child_offset = header_size
    for slot, child in children:
        result.extend(struct.pack(">II", slot, child_offset))
        child_offset += len(child)
    for _, child in children:
        result.extend(child)
    struct.pack_into(">I", result, 4, len(result))
    return bytes(result)


def thin_macho(
    semantic: bytes,
    entitlements: dict[str, Any] | None,
    signature_marker: bytes,
    *,
    unknown_command: bool = False,
    nonterminal: bool = False,
    linkedit_mutation: bytes = b"",
    der_value: object = DEFAULT_DER_VALUE,
    symtab_mode: str | None = None,
    linkedit_section_in_signature: bool = False,
    signature_padding: bytes = b"",
) -> bytes:
    endian = "<"
    header_size = 32
    text_size = 72
    linkedit_size = 152 if linkedit_section_in_signature else 72
    signature_command_size = 16
    symtab_command_size = 24 if symtab_mode is not None else 0
    command_count = 3 + (1 if symtab_mode is not None else 0)
    commands_size = text_size + linkedit_size + symtab_command_size + signature_command_size
    prefix_size = 512
    semantic_payload = semantic + linkedit_mutation
    symtab_offset = 0
    symtab_size = 0
    if symtab_mode == "valid":
        symtab_offset = prefix_size + len(semantic_payload)
        symtab_payload = b"\0synthetic-symbol\0"
        symtab_size = len(symtab_payload)
        semantic_payload += symtab_payload
    elif symtab_mode not in (None, "signature"):
        raise ValueError("unknown synthetic symbol-table mode")
    signature = (
        entitlement_blob(entitlements, signature_marker, der_value=der_value)
        + signature_padding
    )
    signature_offset = prefix_size + len(semantic_payload)
    if signature_offset % 16:
        semantic_payload += b"\0" * (16 - signature_offset % 16)
        signature_offset = prefix_size + len(semantic_payload)
    total_size = signature_offset + len(signature) + (1 if nonterminal else 0)
    header = struct.pack(
        f"{endian}IiiIIIII",
        0xFEEDFACF,
        0x0100000C,
        0,
        2,
        command_count,
        commands_size,
        0x00200085,
        0,
    )
    text = struct.pack(
        f"{endian}II16sQQQQiiII",
        MODULE.LC_SEGMENT_64,
        text_size,
        b"__TEXT\0".ljust(16, b"\0"),
        0,
        prefix_size,
        0,
        prefix_size,
        7,
        5,
        0,
        0,
    )
    linkedit_cmd = MODULE.LC_SEGMENT_64 if not unknown_command else 0x77777777
    linkedit_vm_size = ((total_size - prefix_size + 16383) // 16384) * 16384
    linkedit = struct.pack(
        f"{endian}II16sQQQQiiII",
        linkedit_cmd,
        linkedit_size,
        b"__LINKEDIT\0".ljust(16, b"\0"),
        prefix_size,
        linkedit_vm_size,
        prefix_size,
        total_size - prefix_size,
        7,
        1,
        1 if linkedit_section_in_signature else 0,
        0,
    )
    if linkedit_section_in_signature:
        linkedit += struct.pack(
            f"{endian}16s16sQQIIIIIIII",
            b"__hidden\0".ljust(16, b"\0"),
            b"__LINKEDIT\0".ljust(16, b"\0"),
            signature_offset,
            1,
            signature_offset,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
        )
    if symtab_mode == "signature":
        symtab_offset = signature_offset
        symtab_size = len(signature)
    symtab = (
        struct.pack(
            f"{endian}IIIIII",
            MODULE.LC_SYMTAB,
            24,
            0,
            0,
            symtab_offset,
            symtab_size,
        )
        if symtab_mode is not None
        else b""
    )
    code_signature = struct.pack(
        f"{endian}IIII",
        MODULE.LC_CODE_SIGNATURE,
        signature_command_size,
        signature_offset,
        len(signature),
    )
    prefix = bytearray(header + text + linkedit + symtab + code_signature)
    prefix.extend(b"\0" * (prefix_size - len(prefix)))
    return bytes(prefix) + semantic_payload + signature + (b"X" if nonterminal else b"")


def thin_macho_with_tls_zerofill(
    *,
    tls_offset: str = "expected",
    tls_section_type: int = MODULE.S_THREAD_LOCAL_ZEROFILL,
    thread_data_name: bytes = b"__thread_data",
) -> bytes:
    endian = "<"
    prefix_size = 512
    thread_data_size = 32
    data_file_offset = prefix_size
    linkedit_offset = data_file_offset + thread_data_size
    data_vm_address = 0x530000
    tls_vm_address = data_vm_address + thread_data_size
    tls_size = 0x41
    linkedit_payload = b"reviewed-linkedit"
    signature = entitlement_blob(production_entitlements(), b"P")
    signature_offset = linkedit_offset + len(linkedit_payload)
    if signature_offset % 16:
        linkedit_payload += b"\0" * (16 - signature_offset % 16)
        signature_offset = linkedit_offset + len(linkedit_payload)
    total_size = signature_offset + len(signature)
    tls_offsets = {
        "expected": linkedit_offset,
        "mismatch": linkedit_offset + 1,
        "interior": linkedit_offset - 1,
        "out-of-range": total_size + 1,
        "signature": signature_offset,
    }
    if tls_offset not in tls_offsets:
        raise ValueError("unknown synthetic TLS zero-fill offset")

    text_command_size = 72
    data_command_size = 72 + 2 * 80
    linkedit_command_size = 72
    signature_command_size = 16
    commands_size = (
        text_command_size
        + data_command_size
        + linkedit_command_size
        + signature_command_size
    )
    header = struct.pack(
        f"{endian}IiiIIIII",
        0xFEEDFACF,
        0x0100000C,
        0,
        2,
        4,
        commands_size,
        0x00200085,
        0,
    )
    text = struct.pack(
        f"{endian}II16sQQQQiiII",
        MODULE.LC_SEGMENT_64,
        text_command_size,
        b"__TEXT\0".ljust(16, b"\0"),
        0,
        prefix_size,
        0,
        prefix_size,
        7,
        5,
        0,
        0,
    )
    data = struct.pack(
        f"{endian}II16sQQQQiiII",
        MODULE.LC_SEGMENT_64,
        data_command_size,
        b"__DATA\0".ljust(16, b"\0"),
        data_vm_address,
        thread_data_size + tls_size,
        data_file_offset,
        thread_data_size,
        7,
        3,
        2,
        0,
    )
    data += struct.pack(
        f"{endian}16s16sQQIIIIIIII",
        thread_data_name.ljust(16, b"\0"),
        b"__DATA\0".ljust(16, b"\0"),
        data_vm_address,
        thread_data_size,
        data_file_offset,
        3,
        0,
        0,
        MODULE.S_THREAD_LOCAL_REGULAR,
        0,
        0,
        0,
    )
    data += struct.pack(
        f"{endian}16s16sQQIIIIIIII",
        b"__thread_bss\0".ljust(16, b"\0"),
        b"__DATA\0".ljust(16, b"\0"),
        tls_vm_address,
        tls_size,
        tls_offsets[tls_offset],
        3,
        0,
        0,
        tls_section_type,
        0,
        0,
        0,
    )
    linkedit_vm_size = ((total_size - linkedit_offset + 16383) // 16384) * 16384
    linkedit = struct.pack(
        f"{endian}II16sQQQQiiII",
        MODULE.LC_SEGMENT_64,
        linkedit_command_size,
        b"__LINKEDIT\0".ljust(16, b"\0"),
        0x540000,
        linkedit_vm_size,
        linkedit_offset,
        total_size - linkedit_offset,
        7,
        1,
        0,
        0,
    )
    code_signature = struct.pack(
        f"{endian}IIII",
        MODULE.LC_CODE_SIGNATURE,
        signature_command_size,
        signature_offset,
        len(signature),
    )
    prefix = bytearray(header + text + data + linkedit + code_signature)
    prefix.extend(b"\0" * (prefix_size - len(prefix)))
    prefix.extend(b"T" * thread_data_size)
    return bytes(prefix) + linkedit_payload + signature


def thin_macho_with_empty_encryption_info_64(
    *,
    crypt_offset: str = "expected",
    crypt_id: int = 0,
    padding: int = 0,
    cpu_type: int = 0x0100000C,
    include_data_const: bool = True,
    next_segment_offset: int = 16_384,
    duplicate_text: bool = False,
) -> bytes:
    endian = "<"
    text_size = 16_384
    data_size = 16_384 if include_data_const else 0
    linkedit_offset = next_segment_offset + data_size
    linkedit_payload = b"reviewed-encryption-linkedit"
    signature = entitlement_blob(production_entitlements(), b"P")
    signature_offset = linkedit_offset + len(linkedit_payload)
    if signature_offset % 16:
        linkedit_payload += b"\0" * (16 - signature_offset % 16)
        signature_offset = linkedit_offset + len(linkedit_payload)
    total_size = signature_offset + len(signature)
    crypt_offsets = {
        "expected": text_size,
        "text-interior": text_size - 1,
        "next-interior": next_segment_offset + 1,
        "other-boundary": linkedit_offset,
        "signature": signature_offset,
        "out-of-range": total_size + 1,
    }
    if crypt_offset not in crypt_offsets:
        raise ValueError("unknown synthetic empty encryption offset")

    segment_command_size = 72
    encryption_command_size = 24
    signature_command_size = 16
    segment_count = 2 + int(include_data_const) + int(duplicate_text)
    command_count = segment_count + 2
    commands_size = (
        segment_count * segment_command_size
        + encryption_command_size
        + signature_command_size
    )
    header = struct.pack(
        f"{endian}IiiIIIII",
        0xFEEDFACF,
        cpu_type,
        0,
        2,
        command_count,
        commands_size,
        0x00200085,
        0,
    )

    def segment(
        name: bytes,
        vm_address: int,
        vm_size: int,
        file_offset: int,
        file_size: int,
        initial_protection: int,
    ) -> bytes:
        return struct.pack(
            f"{endian}II16sQQQQiiII",
            MODULE.LC_SEGMENT_64,
            segment_command_size,
            name.ljust(16, b"\0"),
            vm_address,
            vm_size,
            file_offset,
            file_size,
            7,
            initial_protection,
            0,
            0,
        )

    text = segment(b"__TEXT\0", 0, text_size, 0, text_size, 5)
    commands = bytearray(text)
    if duplicate_text:
        commands.extend(text)
    if include_data_const:
        commands.extend(
            segment(
                b"__DATA_CONST\0",
                text_size,
                data_size,
                next_segment_offset,
                data_size,
                3,
            )
        )
    page_size = (
        16_384 if (cpu_type & 0x00FFFFFF) == MODULE.CPU_TYPE_ARM else 4_096
    )
    linkedit_file_size = total_size - linkedit_offset
    linkedit_vm_size = (
        (linkedit_file_size + page_size - 1) // page_size * page_size
    )
    commands.extend(
        segment(
            b"__LINKEDIT\0",
            text_size + data_size,
            linkedit_vm_size,
            linkedit_offset,
            linkedit_file_size,
            1,
        )
    )
    commands.extend(
        struct.pack(
            f"{endian}IIIIII",
            MODULE.LC_ENCRYPTION_INFO_64,
            encryption_command_size,
            crypt_offsets[crypt_offset],
            0,
            crypt_id,
            padding,
        )
    )
    commands.extend(
        struct.pack(
            f"{endian}IIII",
            MODULE.LC_CODE_SIGNATURE,
            signature_command_size,
            signature_offset,
            len(signature),
        )
    )
    prefix = bytearray(header + commands)
    prefix.extend(b"\0" * (next_segment_offset - len(prefix)))
    if include_data_const:
        prefix.extend(b"D" * data_size)
    if len(prefix) != linkedit_offset:
        raise ValueError("synthetic empty encryption layout is not contiguous")
    return bytes(prefix) + linkedit_payload + signature


def thin_macho_32(
    *,
    cpu_type: int = MODULE.CPU_TYPE_ARM,
    cpu_subtype: int = 9,
    linkedit_file_size: int = 100_224,
    linkedit_vm_size: int | None = None,
) -> bytes:
    endian = "<"
    prefix_size = 16_384
    signature = entitlement_blob(production_entitlements(), b"P")
    total_size = prefix_size + linkedit_file_size
    signature_offset = total_size - len(signature)
    if signature_offset <= prefix_size:
        raise ValueError("synthetic 32-bit __LINKEDIT cannot contain its signature")
    page_size = (
        16_384 if (cpu_type & 0x00FFFFFF) == MODULE.CPU_TYPE_ARM else 4_096
    )
    if linkedit_vm_size is None:
        linkedit_vm_size = (
            (linkedit_file_size + page_size - 1) // page_size * page_size
        )

    text_command_size = 56
    linkedit_command_size = 56
    signature_command_size = 16
    commands_size = (
        text_command_size + linkedit_command_size + signature_command_size
    )
    header = struct.pack(
        f"{endian}IiiIIII",
        0xFEEDFACE,
        cpu_type,
        cpu_subtype,
        2,
        3,
        commands_size,
        0x00000085,
    )
    text = struct.pack(
        f"{endian}II16sIIIIiiII",
        MODULE.LC_SEGMENT,
        text_command_size,
        b"__TEXT\0".ljust(16, b"\0"),
        0,
        prefix_size,
        0,
        prefix_size,
        7,
        5,
        0,
        0,
    )
    linkedit = struct.pack(
        f"{endian}II16sIIIIiiII",
        MODULE.LC_SEGMENT,
        linkedit_command_size,
        b"__LINKEDIT\0".ljust(16, b"\0"),
        prefix_size,
        linkedit_vm_size,
        prefix_size,
        linkedit_file_size,
        7,
        1,
        0,
        0,
    )
    code_signature = struct.pack(
        f"{endian}IIII",
        MODULE.LC_CODE_SIGNATURE,
        signature_command_size,
        signature_offset,
        len(signature),
    )
    prefix = bytearray(header + text + linkedit + code_signature)
    prefix.extend(b"\0" * (prefix_size - len(prefix)))
    prefix.extend(b"L" * (signature_offset - len(prefix)))
    return bytes(prefix) + signature


def append_load_command(raw: bytes, command: bytes) -> bytes:
    if len(command) < 8 or len(command) % 8:
        raise ValueError("synthetic load command must be nonempty and aligned")
    result = bytearray(raw)
    command_count, command_bytes = struct.unpack_from("<II", result, 16)
    insertion = 32 + command_bytes
    if insertion + len(command) > 512:
        raise ValueError("synthetic load command exceeds reserved header space")
    result[insertion : insertion + len(command)] = command
    struct.pack_into("<II", result, 16, command_count + 1, command_bytes + len(command))
    return bytes(result)


def find_load_command_offset(
    raw: bytes, expected_command: int, occurrence: int = 0
) -> int:
    if occurrence < 0:
        raise ValueError("synthetic load-command occurrence must be nonnegative")
    command_count, command_bytes = struct.unpack_from("<II", raw, 16)
    cursor = 32
    command_end = cursor + command_bytes
    for _ in range(command_count):
        command, size = struct.unpack_from("<II", raw, cursor)
        if size < 8 or cursor + size > command_end:
            raise ValueError("synthetic Mach-O has an invalid load-command inventory")
        if command == expected_command:
            if occurrence == 0:
                return cursor
            occurrence -= 1
        cursor += size
    raise ValueError(f"synthetic Mach-O lacks command 0x{expected_command:08x}")


def find_load_command(raw: bytes, expected_command: int, occurrence: int = 0) -> bytes:
    cursor = find_load_command_offset(raw, expected_command, occurrence)
    size = struct.unpack_from("<I", raw, cursor + 4)[0]
    return raw[cursor : cursor + size]


def linkedit_data_command(command: int, offset: int, size: int) -> bytes:
    return struct.pack("<IIII", command, 16, offset, size)


def rewrite_symtab(
    raw: bytes,
    *,
    symbol_offset: int,
    string_offset: int,
    string_size: int,
) -> bytes:
    result = bytearray(raw)
    cursor = find_load_command_offset(result, MODULE.LC_SYMTAB)
    _, symbol_count, _, _ = struct.unpack_from("<IIII", result, cursor + 8)
    struct.pack_into(
        "<IIII",
        result,
        cursor + 8,
        symbol_offset,
        symbol_count,
        string_offset,
        string_size,
    )
    return bytes(result)


def fat_macho(
    thin: bytes,
    *,
    padding_byte: int = 0,
    alignment: int = 12,
    cpu_type: int = 0x0100000C,
    cpu_subtype: int = 0,
) -> bytes:
    slice_offset = 1 << alignment
    header = struct.pack(">II", 0xCAFEBABE, 1)
    architecture = struct.pack(
        ">iiIII", cpu_type, cpu_subtype, slice_offset, len(thin), alignment
    )
    padding = bytes([padding_byte]) * (slice_offset - len(header) - len(architecture))
    return header + architecture + padding + thin


def project_bytes(raw: bytes) -> Any:
    with tempfile.TemporaryFile() as source:
        source.write(raw)
        source.flush()
        return MODULE.project_macho_descriptor(source.fileno(), len(raw), "synthetic Mach-O")


def production_entitlements() -> dict[str, Any]:
    app_id = "YLWWUD25VZ.co.jp.soramitsu.sora"
    return {
        "application-identifier": app_id,
        "com.apple.developer.team-identifier": "YLWWUD25VZ",
        "keychain-access-groups": [app_id, "YLWWUD25VZ.shared.sora"],
        "aps-environment": "production",
        "beta-reports-active": True,
    }


def test_entitlements() -> dict[str, Any]:
    value = production_entitlements()
    value.pop("beta-reports-active")
    value["aps-environment"] = "development"
    value["get-task-allow"] = True
    return value


def extension_entitlements(*, test_host: bool) -> dict[str, Any]:
    app_id = "YLWWUD25VZ.co.jp.soramitsu.sora.share"
    value: dict[str, Any] = {
        "application-identifier": app_id,
        "com.apple.developer.team-identifier": "YLWWUD25VZ",
        "keychain-access-groups": [app_id, "YLWWUD25VZ.shared.sora"],
        "aps-environment": "development" if test_host else "production",
    }
    if test_host:
        value["get-task-allow"] = True
    else:
        value["beta-reports-active"] = True
    return value


class Fixture:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.production = root / "production"
        self.production.mkdir(mode=0o700)
        self.ipa = self.production / "Sora.ipa"
        self.host = root / "SoraPassport.app"
        self.host.mkdir(mode=0o700)
        self.output = root / "derivation.json"
        self.contract_sha = hashlib.sha256(b"qualification-contract").hexdigest()

    def info(self) -> bytes:
        return plistlib.dumps(
            {
                "CFBundleExecutable": "SoraPassport",
                "CFBundleIdentifier": "co.jp.soramitsu.sora",
                "CFBundleShortVersionString": "3.0.0",
                "CFBundleVersion": "300",
            },
            fmt=plistlib.FMT_BINARY,
            sort_keys=True,
        )

    def nested_info(self, *, executable: str, bundle_id: str, package_type: str) -> bytes:
        return plistlib.dumps(
            {
                "CFBundleExecutable": executable,
                "CFBundleIdentifier": bundle_id,
                "CFBundlePackageType": package_type,
            },
            fmt=plistlib.FMT_BINARY,
            sort_keys=True,
        )

    def write(
        self,
        *,
        production_semantic: bytes = b"semantic-main-v1",
        test_semantic: bytes = b"semantic-main-v1",
        production_kwargs: dict[str, Any] | None = None,
        test_kwargs: dict[str, Any] | None = None,
        collision: bool = False,
        hardlink: bool = False,
        unreviewed_entitlement: bool = False,
        unreviewed_nested_entitlement: bool = False,
        unreviewed_exclusion_spelling: bool = False,
        test_der_value: object = DEFAULT_DER_VALUE,
        production_test_material: bool = False,
        production_test_runtime: bool = False,
        malicious_resource_exclusion: str | None = None,
        legitimate_spaced_model: bool = False,
        reviewed_executable_resources: bool = False,
        implicit_default_access_groups: bool = False,
        production_reviewed_magic_mutation: str | None = None,
        production_reviewed_mode_mutation: tuple[str, int] | None = None,
        host_reviewed_mode_mutation: tuple[str, int] | None = None,
        production_unreviewed_near_path_resource: bool = False,
        host_unreviewed_near_path_resource: bool = False,
    ) -> None:
        production_kwargs = production_kwargs or {}
        test_kwargs = test_kwargs or {}
        prod_entitlements = production_entitlements()
        host_entitlements = test_entitlements()
        if implicit_default_access_groups:
            prod_entitlements.pop("keychain-access-groups")
            host_entitlements.pop("keychain-access-groups")
        if unreviewed_entitlement:
            host_entitlements["com.apple.developer.associated-domains"] = ["applinks:evil.example"]
        production_executable = thin_macho(
            production_semantic,
            prod_entitlements,
            b"P",
            **production_kwargs,
        )
        test_executable = thin_macho(
            test_semantic,
            host_entitlements,
            b"T",
            der_value=test_der_value,
            **test_kwargs,
        )
        framework_prod = thin_macho(b"framework-v1", None, b"F")
        framework_test = thin_macho(b"framework-v1", None, b"G")
        extension_prod_entitlements = extension_entitlements(test_host=False)
        extension_test_entitlements = extension_entitlements(test_host=True)
        if implicit_default_access_groups:
            extension_prod_entitlements.pop("keychain-access-groups")
            extension_test_entitlements.pop("keychain-access-groups")
        if unreviewed_nested_entitlement:
            extension_test_entitlements["com.apple.developer.networking.networkextension"] = [
                "packet-tunnel-provider"
            ]
        extension_prod = thin_macho(
            b"extension-v1", extension_prod_entitlements, b"E"
        )
        extension_test = thin_macho(
            b"extension-v1", extension_test_entitlements, b"H"
        )
        google_ads_prod = thin_macho(b"google-ads-v1", None, b"I")
        google_ads_test = thin_macho(b"google-ads-v1", None, b"J")
        info = self.info()
        framework_info = self.nested_info(
            executable="Wallet",
            bundle_id="co.jp.soramitsu.sora.wallet-framework",
            package_type="FMWK",
        )
        extension_info = self.nested_info(
            executable="SoraShare",
            bundle_id="co.jp.soramitsu.sora.share",
            package_type="XPC!",
        )
        google_ads_info = plistlib.dumps(
            {
                "CFBundleExecutable": "GoogleAdsOnDeviceConversion",
                "CFBundleIdentifier": "com.google.GoogleAdsOnDeviceConversion",
                "CFBundlePackageType": "FMWK",
            },
            fmt=plistlib.FMT_XML,
            sort_keys=True,
        )
        self.google_ads_info = google_ads_info
        production_files = {
            "Info.plist": (info, 0o644),
            "SoraPassport": (production_executable, 0o755),
            "Assets.car": (b"asset-catalog-v1", 0o644),
            "Frameworks/Wallet.framework/Wallet": (framework_prod, 0o755),
            "Frameworks/Wallet.framework/Info.plist": (framework_info, 0o644),
            "Frameworks/Wallet.framework/_CodeSignature/CodeResources": (
                b"production-framework-signature",
                0o644,
            ),
            "PlugIns/SoraShare.appex/SoraShare": (extension_prod, 0o755),
            "PlugIns/SoraShare.appex/Info.plist": (extension_info, 0o644),
            "PlugIns/SoraShare.appex/_CodeSignature/CodeResources": (
                b"production-extension-signature",
                0o644,
            ),
            "PlugIns/SoraShare.appex/embedded.mobileprovision": (
                b"production-extension-profile",
                0o644,
            ),
            "_CodeSignature/CodeResources": (b"production-code-resources", 0o644),
            "embedded.mobileprovision": (b"production-profile", 0o644),
        }
        if legitimate_spaced_model:
            production_files[
                "UserDataModel.momd/UserDataModel 2.mom"
            ] = (b"compiled-model-v2", 0o644)
        if reviewed_executable_resources:
            reviewed_production_files = {
                GOOGLE_ADS_INFO_PATH: google_ads_info,
                GOOGLE_SIGNIN_FONT_PATH: GOOGLE_SIGNIN_FONT,
                GOOGLE_SIGNIN_NESTED_FONT_PATH: GOOGLE_SIGNIN_FONT,
            }
            if production_reviewed_magic_mutation is not None:
                if production_reviewed_magic_mutation not in reviewed_production_files:
                    raise ValueError("unknown reviewed executable resource mutation")
                original = reviewed_production_files[
                    production_reviewed_magic_mutation
                ]
                reviewed_production_files[
                    production_reviewed_magic_mutation
                ] = b"BAD!" + original[4:]
            production_files.update(
                {
                    GOOGLE_ADS_INFO_PATH: (
                        reviewed_production_files[GOOGLE_ADS_INFO_PATH],
                        production_reviewed_mode_mutation[1]
                        if production_reviewed_mode_mutation is not None
                        and production_reviewed_mode_mutation[0]
                        == GOOGLE_ADS_INFO_PATH
                        else 0o755,
                    ),
                    GOOGLE_SIGNIN_FONT_PATH: (
                        reviewed_production_files[GOOGLE_SIGNIN_FONT_PATH],
                        production_reviewed_mode_mutation[1]
                        if production_reviewed_mode_mutation is not None
                        and production_reviewed_mode_mutation[0]
                        == GOOGLE_SIGNIN_FONT_PATH
                        else 0o755,
                    ),
                    GOOGLE_SIGNIN_NESTED_FONT_PATH: (
                        reviewed_production_files[GOOGLE_SIGNIN_NESTED_FONT_PATH],
                        production_reviewed_mode_mutation[1]
                        if production_reviewed_mode_mutation is not None
                        and production_reviewed_mode_mutation[0]
                        == GOOGLE_SIGNIN_NESTED_FONT_PATH
                        else 0o755,
                    ),
                    "Frameworks/GoogleAdsOnDeviceConversion.framework/GoogleAdsOnDeviceConversion": (
                        google_ads_prod,
                        0o755,
                    ),
                    "Frameworks/GoogleAdsOnDeviceConversion.framework/_CodeSignature/CodeResources": (
                        b"production-google-ads-signature",
                        0o644,
                    ),
                }
            )
        if production_unreviewed_near_path_resource:
            production_files[GOOGLE_SIGNIN_NESTED_FONT_NEAR_PATH] = (
                GOOGLE_SIGNIN_FONT,
                0o755,
            )
        if production_test_material:
            production_files["PlugIns/SoraPassportTests.xctest/Info.plist"] = (
                b"forbidden-production-test-bundle",
                0o644,
            )
        if production_test_runtime:
            production_files["Frameworks/XCTest.framework/Info.plist"] = (
                b"forbidden-production-test-runtime",
                0o644,
            )
            production_files["Frameworks/libXCTestSwiftSupport.dylib"] = (
                b"forbidden-production-test-dylib",
                0o755,
            )
        if unreviewed_exclusion_spelling:
            production_files.pop("_CodeSignature/CodeResources")
        with zipfile.ZipFile(self.ipa, "w", compression=zipfile.ZIP_STORED) as archive:
            for relative, (raw, mode) in production_files.items():
                entry = zipfile.ZipInfo(f"Payload/SoraPassport.app/{relative}")
                entry.external_attr = (stat.S_IFREG | mode) << 16
                archive.writestr(entry, raw)
            if collision:
                entry = zipfile.ZipInfo("Payload/SoraPassport.app/assets.CAR")
                entry.external_attr = (stat.S_IFREG | 0o644) << 16
                archive.writestr(entry, b"collision")
            if unreviewed_exclusion_spelling:
                entry = zipfile.ZipInfo(
                    "Payload/SoraPassport.app/_codesignature/CodeResources"
                )
                entry.external_attr = (stat.S_IFREG | 0o644) << 16
                archive.writestr(entry, b"not-reviewed")
        host_files = {
            "Info.plist": (info, 0o644),
            "SoraPassport": (test_executable, 0o755),
            "Assets.car": (b"asset-catalog-v1", 0o644),
            "Frameworks/Wallet.framework/Wallet": (framework_test, 0o755),
            "Frameworks/Wallet.framework/Info.plist": (framework_info, 0o644),
            "Frameworks/Wallet.framework/_CodeSignature/CodeResources": (
                b"test-framework-signature",
                0o644,
            ),
            "PlugIns/SoraShare.appex/SoraShare": (extension_test, 0o755),
            "PlugIns/SoraShare.appex/Info.plist": (extension_info, 0o644),
            "PlugIns/SoraShare.appex/_CodeSignature/CodeResources": (
                b"test-extension-signature",
                0o644,
            ),
            "PlugIns/SoraShare.appex/embedded.mobileprovision": (
                b"test-extension-profile",
                0o644,
            ),
            "_CodeSignature/CodeResources": (b"test-code-resources", 0o644),
            "embedded.mobileprovision": (b"test-profile", 0o644),
            "PlugIns/SoraPassportTests.xctest/Info.plist": (b"test-only-unit", 0o644),
            "PlugIns/SoraPassportTests.xctest/SoraPassportTests": (b"test-code-unit", 0o755),
            "PlugIns/SoraPassportIntegrationTests.xctest/Info.plist": (
                b"test-only-integration",
                0o644,
            ),
            "PlugIns/SoraPassportIntegrationTests.xctest/SoraPassportIntegrationTests": (
                b"test-code-integration",
                0o755,
            ),
            "Frameworks/XCTest.framework/Info.plist": (b"test-runtime-framework", 0o644),
            "Frameworks/Testing.framework/Info.plist": (b"testing-runtime-framework", 0o644),
            "Frameworks/libXCTestSwiftSupport.dylib": (b"test-runtime-dylib", 0o755),
            "Frameworks/libXCTestBundleInject.dylib": (b"test-inject-dylib", 0o755),
        }
        if legitimate_spaced_model:
            host_files[
                "UserDataModel.momd/UserDataModel 2.mom"
            ] = (b"compiled-model-v2", 0o644)
        if reviewed_executable_resources:
            host_files.update(
                {
                    GOOGLE_ADS_INFO_PATH: (
                        google_ads_info,
                        host_reviewed_mode_mutation[1]
                        if host_reviewed_mode_mutation is not None
                        and host_reviewed_mode_mutation[0] == GOOGLE_ADS_INFO_PATH
                        else 0o700,
                    ),
                    GOOGLE_SIGNIN_FONT_PATH: (
                        GOOGLE_SIGNIN_FONT,
                        host_reviewed_mode_mutation[1]
                        if host_reviewed_mode_mutation is not None
                        and host_reviewed_mode_mutation[0] == GOOGLE_SIGNIN_FONT_PATH
                        else 0o700,
                    ),
                    GOOGLE_SIGNIN_NESTED_FONT_PATH: (
                        GOOGLE_SIGNIN_FONT,
                        host_reviewed_mode_mutation[1]
                        if host_reviewed_mode_mutation is not None
                        and host_reviewed_mode_mutation[0]
                        == GOOGLE_SIGNIN_NESTED_FONT_PATH
                        else 0o700,
                    ),
                    "Frameworks/GoogleAdsOnDeviceConversion.framework/GoogleAdsOnDeviceConversion": (
                        google_ads_test,
                        0o755,
                    ),
                    "Frameworks/GoogleAdsOnDeviceConversion.framework/_CodeSignature/CodeResources": (
                        b"test-google-ads-signature",
                        0o644,
                    ),
                }
            )
        if host_unreviewed_near_path_resource:
            host_files[GOOGLE_SIGNIN_NESTED_FONT_NEAR_PATH] = (
                GOOGLE_SIGNIN_FONT,
                0o755,
            )
        for runtime_root in MODULE.EXACT_TEST_RUNTIME_FRAMEWORK_ROOTS:
            host_files.setdefault(
                f"{runtime_root.as_posix()}/Info.plist",
                (f"test-runtime:{runtime_root.name}".encode("ascii"), 0o644),
            )
        if malicious_resource_exclusion == "codesign":
            host_files["Assets/_CodeSignature/behavior.dat"] = (b"hidden-behavior", 0o644)
        elif malicious_resource_exclusion == "profile":
            host_files["Assets/embedded.mobileprovision"] = (b"hidden-profile", 0o644)
        elif malicious_resource_exclusion == "xctest":
            host_files["Assets/Fake.xctest/behavior.dat"] = (b"hidden-test", 0o644)
        elif malicious_resource_exclusion == "runtime-near-name":
            host_files["Frameworks/XCTestEvil.framework/behavior.dat"] = (
                b"must-remain-semantic",
                0o644,
            )
        for relative, (raw, mode) in host_files.items():
            path = self.host / relative
            path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            path.write_bytes(raw)
            path.chmod(mode)
        if hardlink:
            os.link(self.host / "Assets.car", self.host / "Assets.alias")

    def create(self) -> dict[str, Any]:
        result = MODULE.create(
            str(self.ipa), str(self.host), str(self.output), self.contract_sha
        )
        self.result = result
        return json.loads(self.output.read_text(encoding="utf-8"))


class TestHostDerivationTests(unittest.TestCase):
    def fixture(self) -> tuple[tempfile.TemporaryDirectory[str], Fixture]:
        temporary = tempfile.TemporaryDirectory(
            prefix="sora-ios-host-derivation.", dir="/private/tmp"
        )
        root = Path(temporary.name)
        root.chmod(0o700)
        return temporary, Fixture(root)

    def test_equivalent_signed_apps_produce_observed_derivation(self) -> None:
        temporary, fixture = self.fixture()
        with temporary:
            fixture.write()
            receipt = fixture.create()
            self.assertEqual(receipt["schemaVersion"], 2)
            self.assertEqual(
                receipt["projectionContract"]["contractId"],
                "sora-ios-wallet-migration-canonical-app-projection-v2",
            )
            self.assertEqual(receipt["status"], "observed")
            self.assertIs(receipt["releaseAuthorized"], False)
            self.assertIs(receipt["promotionAuthorized"], False)
            self.assertTrue(receipt["derivation"]["canonicalDerivedTestHostAccepted"])
            self.assertFalse(receipt["derivation"]["rawExecutableEqualityRequired"])
            self.assertNotEqual(
                receipt["productionIpa"]["rawExecutableSha256"],
                receipt["releaseTestHost"]["rawExecutableSha256"],
            )
            self.assertEqual(
                receipt["productionIpa"]["canonicalProjection"],
                receipt["releaseTestHost"]["canonicalProjection"],
            )
            self.assertRegex(
                receipt["projectionContract"]["derEntitlementDecoder"]["sha256"],
                r"^[0-9a-f]{64}$",
            )
            main_slots = next(
                value
                for value in receipt["releaseTestHost"]["signedEntitlementProjection"]
                if value["relativePath"] == "SoraPassport"
            )
            self.assertIsNotNone(main_slots["xmlEntitlementsSlotSha256"])
            self.assertIsNotNone(main_slots["derEntitlementsSlotSha256"])
            self.assertEqual(
                receipt["productionIpa"]["canonicalExecutableSha256"],
                receipt["releaseTestHost"]["canonicalExecutableSha256"],
            )
            self.assertEqual(
                {
                    (item["relativePath"], item["key"])
                    for item in receipt["derivation"]["reviewedSigningEntitlementDifferences"]
                },
                {
                    (path, key)
                    for path in ("SoraPassport", "PlugIns/SoraShare.appex/SoraShare")
                    for key in ("aps-environment", "beta-reports-active", "get-task-allow")
                },
            )
            verified = MODULE.verify(
                str(fixture.ipa),
                str(fixture.host),
                str(fixture.output),
                fixture.contract_sha,
            )
            self.assertEqual(
                verified["canonicalProjectionSha256"],
                receipt["releaseTestHost"]["canonicalProjection"]["recordSha256"],
            )

        application_id = "YLWWUD25VZ.co.jp.soramitsu.sora"
        temporary, fixture = self.fixture()
        with temporary:
            fixture.write(implicit_default_access_groups=True)
            receipt = fixture.create()
            expected_default_sha = hashlib.sha256(
                MODULE.canonical_json([application_id])
            ).hexdigest()
            self.assertEqual(
                receipt["productionIpa"]["signedIdentity"][
                    "keychainAccessGroupsSha256"
                ],
                expected_default_sha,
            )
            self.assertEqual(
                receipt["releaseTestHost"]["signedIdentity"][
                    "keychainAccessGroupsSha256"
                ],
                expected_default_sha,
            )

        ordered = production_entitlements()
        ordered["keychain-access-groups"] = [
            "YLWWUD25VZ.shared.sora",
            application_id,
        ]
        ordered["com.apple.security.application-groups"] = [
            "group.co.jp.soramitsu.sora"
        ]
        identity = MODULE.signing_identity(ordered, "ordered production identity")
        expected_effective = [
            "YLWWUD25VZ.shared.sora",
            application_id,
            "group.co.jp.soramitsu.sora",
        ]
        self.assertEqual(
            identity["keychainAccessGroupsSha256"],
            hashlib.sha256(MODULE.canonical_json(expected_effective)).hexdigest(),
        )
        reversed_explicit = dict(ordered)
        reversed_explicit["keychain-access-groups"] = list(
            reversed(ordered["keychain-access-groups"])
        )
        self.assertNotEqual(
            MODULE.signing_identity(
                reversed_explicit, "reordered production identity"
            )["keychainAccessGroupsSha256"],
            identity["keychainAccessGroupsSha256"],
        )
        explicit_default = production_entitlements()
        explicit_default["keychain-access-groups"] = [application_id]
        self.assertEqual(
            MODULE.signing_identity(
                explicit_default, "explicit-default production identity"
            )["keychainAccessGroupsSha256"],
            hashlib.sha256(MODULE.canonical_json([application_id])).hexdigest(),
        )

    def test_compiled_model_member_with_internal_ascii_space_is_accepted(self) -> None:
        temporary, fixture = self.fixture()
        with temporary:
            fixture.write(legitimate_spaced_model=True)
            receipt = fixture.create()
            self.assertEqual(
                receipt["productionIpa"]["canonicalProjection"],
                receipt["releaseTestHost"]["canonicalProjection"],
            )

    def test_zip_member_space_allowance_rejects_unsafe_name_shapes(self) -> None:
        legitimate_name = (
            "Payload/SoraPassport.app/UserDataModel.momd/UserDataModel 2.mom"
        )
        legitimate = zipfile.ZipInfo(legitimate_name)
        legitimate.external_attr = (stat.S_IFREG | 0o644) << 16
        self.assertEqual(
            MODULE.safe_zip_member(legitimate, "production IPA").as_posix(),
            legitimate_name,
        )

        unsafe_names = (
            "/Payload/SoraPassport.app/UserDataModel 2.mom",
            "Payload\\SoraPassport.app\\UserDataModel 2.mom",
            "Payload//SoraPassport.app/UserDataModel 2.mom",
            "Payload/SoraPassport.app/./UserDataModel 2.mom",
            "Payload/SoraPassport.app/../UserDataModel 2.mom",
            "Payload/SoraPassport.app/ UserDataModel 2.mom",
            "Payload/SoraPassport.app/UserDataModel 2.mom ",
            "Payload/SoraPassport.app/UserDataModel\t2.mom",
            "Payload/SoraPassport.app/UserDataModel\x1f2.mom",
            "Payload/SoraPassport.app/UserDataModel:2.mom",
            "Payload/SoraPassport.app/.UserDataModel 2.mom",
        )
        for unsafe_name in unsafe_names:
            with self.subTest(unsafe_name=repr(unsafe_name)):
                unsafe = zipfile.ZipInfo(unsafe_name)
                unsafe.external_attr = (stat.S_IFREG | 0o644) << 16
                with self.assertRaisesRegex(
                    MODULE.DerivationError, "unsafe ZIP member"
                ):
                    MODULE.safe_zip_member(unsafe, "production IPA")

    def test_exact_reviewed_executable_non_macho_resources_are_projected(self) -> None:
        temporary, fixture = self.fixture()
        with temporary:
            fixture.write(reviewed_executable_resources=True)
            captured_raw_entries: list[list[dict[str, Any]]] = []
            captured_projection_entries: list[list[dict[str, Any]]] = []
            original_raw_tree_record = MODULE.raw_tree_record
            original_projection_record = MODULE.projection_record

            def capture_raw(entries: list[dict[str, Any]]) -> bytes:
                captured_raw_entries.append([dict(item) for item in entries])
                return original_raw_tree_record(entries)

            def capture_projection(entries: list[dict[str, Any]]) -> bytes:
                captured_projection_entries.append([dict(item) for item in entries])
                return original_projection_record(entries)

            with mock.patch.object(MODULE, "raw_tree_record", side_effect=capture_raw), mock.patch.object(
                MODULE, "projection_record", side_effect=capture_projection
            ):
                receipt = fixture.create()

            self.assertEqual(
                receipt["productionIpa"]["canonicalProjection"],
                receipt["releaseTestHost"]["canonicalProjection"],
            )
            for path, raw in (
                (GOOGLE_ADS_INFO_PATH, fixture.google_ads_info),
                (GOOGLE_SIGNIN_FONT_PATH, GOOGLE_SIGNIN_FONT),
                (GOOGLE_SIGNIN_NESTED_FONT_PATH, GOOGLE_SIGNIN_FONT),
            ):
                expected_sha = hashlib.sha256(raw).hexdigest()
                self.assertTrue(
                    any(
                        item.get("relativePath") == path
                        and item.get("modeClass") == "executable"
                        and item.get("sha256") == expected_sha
                        for entries in captured_raw_entries
                        for item in entries
                    )
                )
                self.assertTrue(
                    any(
                        item.get("relativePath") == path
                        and item.get("kind") == "resource"
                        and item.get("sha256") == expected_sha
                        for entries in captured_projection_entries
                        for item in entries
                    )
                )

        for path in (
            GOOGLE_ADS_INFO_PATH,
            GOOGLE_SIGNIN_FONT_PATH,
            GOOGLE_SIGNIN_NESTED_FONT_PATH,
        ):
            for mode in (0o600, 0o711, 0o744, 0o777):
                for source in ("IPA", "app directory"):
                    with self.subTest(
                        path=path,
                        mode=oct(mode),
                        source=source,
                    ):
                        temporary, fixture = self.fixture()
                        with temporary:
                            fixture.write(
                                reviewed_executable_resources=True,
                                production_reviewed_mode_mutation=(path, mode)
                                if source == "IPA"
                                else None,
                                host_reviewed_mode_mutation=(path, mode)
                                if source == "app directory"
                                else None,
                            )
                            with self.assertRaisesRegex(
                                MODULE.DerivationError, "unexpected mode"
                            ):
                                fixture.create()

    def test_reviewed_executable_resource_wrong_magic_fails_in_ipa_and_host(self) -> None:
        for path in (
            GOOGLE_ADS_INFO_PATH,
            GOOGLE_SIGNIN_FONT_PATH,
            GOOGLE_SIGNIN_NESTED_FONT_PATH,
        ):
            with self.subTest(source="IPA", path=path):
                temporary, fixture = self.fixture()
                with temporary:
                    fixture.write(
                        reviewed_executable_resources=True,
                        production_reviewed_magic_mutation=path,
                    )
                    with self.assertRaisesRegex(
                        MODULE.DerivationError, "unexpected magic"
                    ):
                        fixture.create()

            with self.subTest(source="app directory", path=path):
                temporary, fixture = self.fixture()
                with temporary:
                    fixture.write(reviewed_executable_resources=True)
                    resource = fixture.host / path
                    original = resource.read_bytes()
                    resource.write_bytes(b"BAD!" + original[4:])
                    resource.chmod(0o755)
                    with self.assertRaisesRegex(
                        MODULE.DerivationError, "unexpected magic"
                    ):
                        fixture.create()

    def test_unreviewed_executable_non_macho_resource_remains_rejected(self) -> None:
        for source in ("IPA", "app directory"):
            with self.subTest(source=source):
                temporary, fixture = self.fixture()
                with temporary:
                    fixture.write(
                        production_unreviewed_near_path_resource=source == "IPA",
                        host_unreviewed_near_path_resource=source == "app directory",
                    )
                    with self.assertRaisesRegex(MODULE.DerivationError, "Mach-O"):
                        fixture.create()

    def test_semantic_main_or_linkedit_change_is_rejected(self) -> None:
        for kwargs in (
            {"test_semantic": b"semantic-main-v2"},
            {"test_kwargs": {"linkedit_mutation": b"non-signature-linkedit-delta"}},
        ):
            temporary, fixture = self.fixture()
            with temporary:
                fixture.write(**kwargs)
                with self.assertRaisesRegex(MODULE.DerivationError, "canonical application projection"):
                    fixture.create()

    def test_nonterminal_signature_and_unknown_load_command_are_rejected(self) -> None:
        for kwargs, expected in (
            ({"test_kwargs": {"nonterminal": True}}, "nonterminal"),
            ({"test_kwargs": {"unknown_command": True}}, "unknown load command"),
        ):
            temporary, fixture = self.fixture()
            with temporary:
                fixture.write(**kwargs)
                with self.assertRaisesRegex(MODULE.DerivationError, expected):
                    fixture.create()

    def test_unreviewed_entitlement_difference_is_rejected(self) -> None:
        for kwargs, path in (
            ({"unreviewed_entitlement": True}, "SoraPassport"),
            (
                {"unreviewed_nested_entitlement": True},
                "PlugIns/SoraShare.appex/SoraShare",
            ),
        ):
            temporary, fixture = self.fixture()
            with temporary:
                fixture.write(**kwargs)
                with self.assertRaisesRegex(
                    MODULE.DerivationError,
                    f"unreviewed signed entitlement at {re.escape(path)}",
                ):
                    fixture.create()

        for invalid_groups in ([], ["duplicate", "duplicate"], None):
            with self.subTest(invalid_groups=invalid_groups):
                entitlements = production_entitlements()
                entitlements["keychain-access-groups"] = invalid_groups
                with self.assertRaisesRegex(
                    MODULE.DerivationError, "ordered, bounded access-group array"
                ):
                    MODULE.signing_identity(entitlements, "invalid production identity")

    def test_every_post_publication_failure_withdraws_exact_receipt(self) -> None:
        temporary, fixture = self.fixture()
        with temporary:
            fixture.write()
            receipt = MODULE.derive_receipt(
                fixture.ipa, fixture.host, fixture.contract_sha
            )
            with mock.patch.object(
                MODULE,
                "derive_receipt",
                side_effect=[receipt, MODULE.DerivationError("post-publication failure")],
            ):
                with self.assertRaisesRegex(
                    MODULE.DerivationError, "post-publication failure"
                ):
                    MODULE.create(
                        str(fixture.ipa),
                        str(fixture.host),
                        str(fixture.output),
                        fixture.contract_sha,
                    )
            self.assertFalse(fixture.output.exists())

    def test_fat_layout_is_projected_per_slice_and_nonzero_padding_is_rejected(self) -> None:
        production = thin_macho(
            b"fat-semantic-v1", production_entitlements(), b"P"
        )
        test_host = thin_macho(b"fat-semantic-v1", test_entitlements(), b"T")
        production_projection = project_bytes(fat_macho(production))
        test_projection = project_bytes(fat_macho(test_host))
        self.assertEqual(production_projection.sha256, test_projection.sha256)
        self.assertEqual(production_projection.byte_count, test_projection.byte_count)
        with self.assertRaisesRegex(MODULE.DerivationError, "nonzero bytes"):
            project_bytes(fat_macho(production, padding_byte=1))

    def test_unknown_or_overlapping_superblob_slot_is_rejected(self) -> None:
        raw = bytearray(
            thin_macho(b"signature-shape", production_entitlements(), b"P")
        )
        signature_offset = raw.find(struct.pack(">I", MODULE.CSMAGIC_EMBEDDED_SIGNATURE))
        self.assertGreater(signature_offset, 0)
        unknown = bytearray(raw)
        struct.pack_into(">I", unknown, signature_offset + 12, 6)
        with self.assertRaisesRegex(MODULE.DerivationError, "unknown or duplicate"):
            project_bytes(bytes(unknown))

        overlapping = bytearray(raw)
        first_blob_offset = struct.unpack_from(">I", overlapping, signature_offset + 16)[0]
        struct.pack_into(">I", overlapping, signature_offset + 24, first_blob_offset)
        with self.assertRaisesRegex(MODULE.DerivationError, "unknown magic|overlapping"):
            project_bytes(bytes(overlapping))

    def test_zero_padded_code_signature_allocation_is_canonically_excluded(self) -> None:
        production = thin_macho(
            b"padded-signature-v1",
            production_entitlements(),
            b"P",
            signature_padding=b"\0" * 13_218,
        )
        test_host = thin_macho(
            b"padded-signature-v1",
            test_entitlements(),
            b"T",
            signature_padding=b"\0" * 257,
        )
        production_projection = project_bytes(production)
        test_projection = project_bytes(test_host)
        self.assertEqual(production_projection.sha256, test_projection.sha256)
        self.assertEqual(
            production_projection.byte_count, test_projection.byte_count
        )

    def test_nonzero_code_signature_allocation_padding_is_rejected(self) -> None:
        raw = thin_macho(
            b"nonzero-signature-padding",
            production_entitlements(),
            b"P",
            signature_padding=b"\0" * 31 + b"X",
        )
        with self.assertRaisesRegex(
            MODULE.DerivationError, "nonzero LC_CODE_SIGNATURE allocation padding"
        ):
            project_bytes(raw)

    def test_superblob_declared_overrun_and_padding_slot_extent_are_rejected(self) -> None:
        overrun = bytearray(
            thin_macho(b"declared-overrun", production_entitlements(), b"P")
        )
        signature = find_load_command(overrun, MODULE.LC_CODE_SIGNATURE)
        signature_offset, signature_size = struct.unpack_from("<II", signature, 8)
        struct.pack_into(">I", overrun, signature_offset + 4, signature_size + 1)
        with self.assertRaisesRegex(
            MODULE.DerivationError, "declared length exceeds"
        ):
            project_bytes(bytes(overrun))

        padding_extent = bytearray(
            thin_macho(
                b"padding-slot-extent",
                production_entitlements(),
                b"P",
                signature_padding=b"\0" * 32,
            )
        )
        signature = find_load_command(padding_extent, MODULE.LC_CODE_SIGNATURE)
        signature_offset = struct.unpack_from("<I", signature, 8)[0]
        declared_length = struct.unpack_from(">I", padding_extent, signature_offset + 4)[0]
        struct.pack_into(">I", padding_extent, signature_offset + 16, declared_length)
        with self.assertRaisesRegex(
            MODULE.DerivationError, "invalid code-signature blob offset"
        ):
            project_bytes(bytes(padding_extent))

    def test_der_entitlement_semantics_and_slot_topology_are_fail_closed(self) -> None:
        temporary, fixture = self.fixture()
        with temporary:
            malicious_der = test_entitlements()
            malicious_der["com.apple.developer.associated-domains"] = ["applinks:evil.example"]
            fixture.write(test_der_value=malicious_der)
            with self.assertRaisesRegex(MODULE.DerivationError, "XML and DER entitlement"):
                fixture.create()

        temporary, fixture = self.fixture()
        with temporary:
            fixture.write(test_der_value=None)
            with self.assertRaisesRegex(MODULE.DerivationError, "XML/DER entitlement slot inventories"):
                fixture.create()

    def test_every_non_signature_range_ends_before_terminal_signature(self) -> None:
        valid = thin_macho(
            b"range-positive", production_entitlements(), b"P", symtab_mode="valid"
        )
        project_bytes(valid)

        for raw, expected in (
            (
                thin_macho(
                    b"range-negative",
                    production_entitlements(),
                    b"P",
                    symtab_mode="signature",
                ),
                "symbol string table.*overlaps signing material",
            ),
            (
                thin_macho(
                    b"range-negative-section",
                    production_entitlements(),
                    b"P",
                    linkedit_section_in_signature=True,
                ),
                "section __hidden data.*overlaps signing material",
            ),
        ):
            with self.assertRaisesRegex(MODULE.DerivationError, expected):
                project_bytes(raw)

        changed_vm_size = bytearray(
            thin_macho(b"mapping-negative", production_entitlements(), b"P")
        )
        linkedit_vm_size_offset = 32 + 72 + 32
        original = struct.unpack_from("<Q", changed_vm_size, linkedit_vm_size_offset)[0]
        struct.pack_into("<Q", changed_vm_size, linkedit_vm_size_offset, original + 16384)
        with self.assertRaisesRegex(MODULE.DerivationError, "page-rounded mapping"):
            project_bytes(bytes(changed_vm_size))

    def test_thread_local_zerofill_accepts_only_exact_thread_data_boundary(
        self,
    ) -> None:
        project_bytes(thin_macho_with_tls_zerofill())

        for description, options, expected in (
            (
                "ordinary-zerofill",
                {"tls_section_type": MODULE.S_ZEROFILL},
                "zero-fill section has a nonzero file offset",
            ),
            (
                "wrong-predecessor",
                {"thread_data_name": b"__not_thread"},
                "TLS zero-fill section is not one exact",
            ),
            (
                "mismatched-boundary",
                {"tls_offset": "mismatch"},
                "TLS zero-fill section is not one exact",
            ),
            (
                "predecessor-interior",
                {"tls_offset": "interior"},
                "TLS zero-fill section is not one exact",
            ),
            (
                "out-of-range",
                {"tls_offset": "out-of-range"},
                "TLS zero-fill section is not one exact",
            ),
            (
                "signature",
                {"tls_offset": "signature"},
                "TLS zero-fill section is not one exact",
            ),
        ):
            with self.subTest(description=description):
                with self.assertRaisesRegex(MODULE.DerivationError, expected):
                    project_bytes(thin_macho_with_tls_zerofill(**options))

    def test_empty_encryption_info_64_accepts_only_16k_text_successor_boundary(
        self,
    ) -> None:
        # Firebase.framework uses the first three-segment form; other reviewed
        # Apple slices place __LINKEDIT directly after the same 16K __TEXT.
        project_bytes(thin_macho_with_empty_encryption_info_64())
        project_bytes(
            thin_macho_with_empty_encryption_info_64(include_data_const=False)
        )
        for description, options, expected in (
            (
                "encrypted",
                {"crypt_id": 1},
                "encrypted or has an invalid encryption range",
            ),
            (
                "nonzero-pad",
                {"padding": 1},
                "encrypted or has an invalid encryption range",
            ),
            (
                "text-interior",
                {"crypt_offset": "text-interior"},
                "exact 16K __TEXT/next-segment boundary",
            ),
            (
                "next-segment-interior",
                {"crypt_offset": "next-interior"},
                "exact 16K __TEXT/next-segment boundary",
            ),
            (
                "later-segment-boundary",
                {"crypt_offset": "other-boundary"},
                "exact 16K __TEXT/next-segment boundary",
            ),
            (
                "next-segment-gap",
                {"next_segment_offset": 16_385},
                "exact 16K __TEXT/next-segment boundary",
            ),
            (
                "signature",
                {"crypt_offset": "signature"},
                "exact 16K __TEXT/next-segment boundary",
            ),
            (
                "out-of-range",
                {"crypt_offset": "out-of-range"},
                "exact 16K __TEXT/next-segment boundary",
            ),
            (
                "non-arm",
                {"cpu_type": 0x01000007},
                "exact 16K __TEXT/next-segment boundary",
            ),
            (
                "multiple-text-segments",
                {"duplicate_text": True},
                "segments __TEXT and __TEXT overlap",
            ),
        ):
            with self.subTest(description=description):
                with self.assertRaisesRegex(MODULE.DerivationError, expected):
                    project_bytes(
                        thin_macho_with_empty_encryption_info_64(**options)
                    )

    def test_32_bit_arm_uses_16k_linkedit_rounding(self) -> None:
        linkedit_file_size = 100_224
        arm = thin_macho_32(linkedit_file_size=linkedit_file_size)
        arm_projection = project_bytes(
            fat_macho(
                arm,
                alignment=14,
                cpu_type=MODULE.CPU_TYPE_ARM,
                cpu_subtype=9,
            )
        )
        self.assertEqual(arm_projection.architectures, ((MODULE.CPU_TYPE_ARM, 9),))
        self.assertEqual(
            struct.unpack_from("<I", arm, 28 + 56 + 28)[0],
            114_688,
        )

        four_k_rounding = (
            (linkedit_file_size + 4_095) // 4_096 * 4_096
        )
        wrong_arm = thin_macho_32(linkedit_vm_size=four_k_rounding)
        with self.assertRaisesRegex(MODULE.DerivationError, "page-rounded mapping"):
            project_bytes(
                fat_macho(
                    wrong_arm,
                    alignment=14,
                    cpu_type=MODULE.CPU_TYPE_ARM,
                    cpu_subtype=9,
                )
            )

        other_cpu = 7
        wrong_other = thin_macho_32(
            cpu_type=other_cpu,
            cpu_subtype=3,
            linkedit_vm_size=114_688,
        )
        with self.assertRaisesRegex(MODULE.DerivationError, "page-rounded mapping"):
            project_bytes(
                fat_macho(
                    wrong_other,
                    alignment=14,
                    cpu_type=other_cpu,
                    cpu_subtype=3,
                )
            )
        project_bytes(
            fat_macho(
                thin_macho_32(cpu_type=other_cpu, cpu_subtype=3),
                alignment=14,
                cpu_type=other_cpu,
                cpu_subtype=3,
            )
        )

    def test_empty_data_in_code_accepts_only_admitted_linkedit_boundaries(self) -> None:
        raw = thin_macho(
            b"empty-data-in-code", production_entitlements(), b"P", symtab_mode="valid"
        )
        signature = find_load_command(raw, MODULE.LC_CODE_SIGNATURE)
        signature_offset, _ = struct.unpack_from("<II", signature, 8)
        symbol_table = find_load_command(raw, MODULE.LC_SYMTAB)
        _, _, string_offset, string_size = struct.unpack_from("<IIII", symbol_table, 8)
        self.assertGreater(string_size, 1)

        for boundary in (
            0,
            string_offset,
            string_offset + string_size,
            signature_offset,
        ):
            with self.subTest(boundary=boundary):
                projected = append_load_command(
                    raw,
                    linkedit_data_command(MODULE.LC_DATA_IN_CODE, boundary, 0),
                )
                project_bytes(projected)

    def test_empty_data_in_code_rejects_arbitrary_interior_and_out_of_range_offsets(
        self,
    ) -> None:
        raw = thin_macho(
            b"empty-data-in-code", production_entitlements(), b"P", symtab_mode="valid"
        )
        linkedit = find_load_command(raw, MODULE.LC_SEGMENT_64, occurrence=1)
        linkedit_offset = struct.unpack_from("<Q", linkedit, 40)[0]
        symbol_table = find_load_command(raw, MODULE.LC_SYMTAB)
        _, _, string_offset, string_size = struct.unpack_from("<IIII", symbol_table, 8)
        self.assertGreater(string_size, 1)

        for description, offset in (
            ("arbitrary", linkedit_offset + 1),
            ("interior", string_offset + 1),
            ("slice-end", len(raw)),
            ("out-of-range", len(raw) + 1),
        ):
            with self.subTest(description=description, offset=offset):
                projected = append_load_command(
                    raw,
                    linkedit_data_command(MODULE.LC_DATA_IN_CODE, offset, 0),
                )
                with self.assertRaisesRegex(
                    MODULE.DerivationError,
                    "not an admitted empty __LINKEDIT boundary",
                ):
                    project_bytes(projected)

    def test_other_empty_load_command_ranges_still_reject_nonzero_offsets(self) -> None:
        raw = thin_macho(b"empty-other-range", production_entitlements(), b"P")
        signature = find_load_command(raw, MODULE.LC_CODE_SIGNATURE)
        signature_offset = struct.unpack_from("<I", signature, 8)[0]
        commands = sorted(
            MODULE.LINKEDIT_DATA_COMMANDS
            - {MODULE.LC_CODE_SIGNATURE, MODULE.LC_DATA_IN_CODE}
        ) + [MODULE.LC_TWOLEVEL_HINTS]
        for command in commands:
            with self.subTest(command=f"0x{command:08x}"):
                projected = append_load_command(
                    raw, linkedit_data_command(command, signature_offset, 0)
                )
                with self.assertRaisesRegex(
                    MODULE.DerivationError, "nonzero offset for an empty range"
                ):
                    project_bytes(projected)

    def test_empty_symtab_symbol_array_accepts_its_nonempty_string_start(self) -> None:
        raw = thin_macho(
            b"xcode26-empty-symtab", production_entitlements(), b"P", symtab_mode="valid"
        )
        symbol_table = find_load_command(raw, MODULE.LC_SYMTAB)
        _, symbol_count, string_offset, string_size = struct.unpack_from(
            "<IIII", symbol_table, 8
        )
        self.assertEqual(symbol_count, 0)
        self.assertGreater(string_size, 0)
        raw = rewrite_symtab(
            raw,
            symbol_offset=string_offset,
            string_offset=string_offset,
            string_size=string_size,
        )
        raw = append_load_command(
            raw,
            linkedit_data_command(
                MODULE.LC_FUNCTION_STARTS, string_offset - 8, 8
            ),
        )
        raw = append_load_command(
            raw,
            linkedit_data_command(MODULE.LC_DATA_IN_CODE, string_offset, 0),
        )
        project_bytes(raw)

    def test_empty_symtab_symbol_offset_rejects_mismatch_and_invalid_locations(
        self,
    ) -> None:
        raw = thin_macho(
            b"xcode26-empty-symtab", production_entitlements(), b"P", symtab_mode="valid"
        )
        symbol_table = find_load_command(raw, MODULE.LC_SYMTAB)
        _, _, string_offset, string_size = struct.unpack_from("<IIII", symbol_table, 8)
        linkedit = find_load_command(raw, MODULE.LC_SEGMENT_64, occurrence=1)
        linkedit_offset = struct.unpack_from("<Q", linkedit, 40)[0]
        for description, symbol_offset, mutated_string_offset, expected in (
            (
                "not-string-start",
                string_offset + string_size,
                string_offset,
                "not the admitted nonempty string-table start",
            ),
            (
                "arbitrary",
                linkedit_offset + 1,
                string_offset,
                "not the admitted nonempty string-table start",
            ),
            (
                "string-interior",
                string_offset + 1,
                string_offset,
                "not the admitted nonempty string-table start",
            ),
            (
                "out-of-range",
                len(raw) + 1,
                len(raw) + 1,
                "exceeds its slice",
            ),
        ):
            with self.subTest(description=description):
                mutated = rewrite_symtab(
                    raw,
                    symbol_offset=symbol_offset,
                    string_offset=mutated_string_offset,
                    string_size=string_size,
                )
                with self.assertRaisesRegex(MODULE.DerivationError, expected):
                    project_bytes(mutated)

    def test_empty_symtab_symbol_offset_requires_a_nonempty_string_table(self) -> None:
        raw = thin_macho(
            b"xcode26-empty-symtab", production_entitlements(), b"P", symtab_mode="valid"
        )
        symbol_table = find_load_command(raw, MODULE.LC_SYMTAB)
        _, _, string_offset, _ = struct.unpack_from("<IIII", symbol_table, 8)
        for description, mutated_string_offset, expected in (
            (
                "absent",
                0,
                "not the admitted nonempty string-table start",
            ),
            (
                "empty-at-nonzero-offset",
                string_offset,
                "nonzero offset for an empty range",
            ),
        ):
            with self.subTest(description=description):
                mutated = rewrite_symtab(
                    raw,
                    symbol_offset=string_offset,
                    string_offset=mutated_string_offset,
                    string_size=0,
                )
                with self.assertRaisesRegex(MODULE.DerivationError, expected):
                    project_bytes(mutated)

    def test_exclusions_require_exact_bundle_or_scheme_runtime_context(self) -> None:
        temporary, fixture = self.fixture()
        with temporary:
            fixture.write()
            receipt = fixture.create()
            excluded = {
                (item["relativePath"], item["nodeType"], item["reason"])
                for item in receipt["releaseTestHost"]["exactExclusions"]
            }
            required = {
                ("Frameworks/Wallet.framework/_CodeSignature", "directory", "code-signature-material"),
                ("PlugIns/SoraShare.appex/_CodeSignature", "directory", "code-signature-material"),
                (
                    "PlugIns/SoraShare.appex/embedded.mobileprovision",
                    "file",
                    "provisioning-material",
                ),
                (
                    "PlugIns/SoraPassportTests.xctest",
                    "directory",
                    "test-only-bundle",
                ),
                (
                    "PlugIns/SoraPassportIntegrationTests.xctest",
                    "directory",
                    "test-only-bundle",
                ),
                ("Frameworks/XCTest.framework", "directory", "test-only-runtime"),
                (
                    "Frameworks/libXCTestSwiftSupport.dylib",
                    "file",
                    "test-only-runtime",
                ),
            }
            self.assertTrue(required.issubset(excluded))

        for malicious, expected in (
            ("codesign", "outside a recognized signed-bundle root"),
            ("profile", "outside a recognized app/appex root"),
            ("xctest", "unreviewed or production XCTest-only material"),
            ("runtime-near-name", "canonical application projection"),
        ):
            temporary, fixture = self.fixture()
            with temporary:
                fixture.write(malicious_resource_exclusion=malicious)
                with self.assertRaisesRegex(MODULE.DerivationError, expected):
                    fixture.create()

        for kwargs in (
            {"production_test_material": True},
            {"production_test_runtime": True},
        ):
            temporary, fixture = self.fixture()
            with temporary:
                fixture.write(**kwargs)
                with self.assertRaisesRegex(
                    MODULE.DerivationError, "production XCTest-only material"
                ):
                    fixture.create()

    def test_casefold_collision_and_hardlink_are_rejected(self) -> None:
        for kwargs, expected in (
            ({"collision": True}, "collid"),
            ({"hardlink": True}, "hard-link|linked"),
        ):
            temporary, fixture = self.fixture()
            with temporary:
                fixture.write(**kwargs)
                with self.assertRaisesRegex(MODULE.DerivationError, expected):
                    fixture.create()

    def test_stale_schema_or_contract_receipt_is_rejected(self) -> None:
        temporary, fixture = self.fixture()
        with temporary:
            fixture.write()
            receipt = fixture.create()
            receipt["schemaVersion"] = 0
            fixture.output.write_bytes(MODULE.canonical_json(receipt))
            with self.assertRaisesRegex(MODULE.DerivationError, "independent raw-byte recomputation"):
                MODULE.verify(
                    str(fixture.ipa),
                    str(fixture.host),
                    str(fixture.output),
                    fixture.contract_sha,
                )
            receipt["schemaVersion"] = 1
            receipt["qualificationContractSha256"] = hashlib.sha256(b"stale").hexdigest()
            fixture.output.write_bytes(MODULE.canonical_json(receipt))
            with self.assertRaisesRegex(MODULE.DerivationError, "stale qualification"):
                MODULE.verify(
                    str(fixture.ipa),
                    str(fixture.host),
                    str(fixture.output),
                    fixture.contract_sha,
                )

    def test_symlink_and_unreviewed_exclusion_spelling_are_rejected(self) -> None:
        for mutation, expected in (
            ("symlink", "symbolic|alias"),
            ("spelling", "unreviewed code-signature exclusion spelling"),
        ):
            temporary, fixture = self.fixture()
            with temporary:
                fixture.write()
                if mutation == "symlink":
                    (fixture.host / "LinkedAssets").symlink_to("Assets.car")
                else:
                    fixture.ipa.unlink()
                    fixture.write(unreviewed_exclusion_spelling=True)
                with self.assertRaisesRegex(MODULE.DerivationError, expected):
                    fixture.create()


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(TestHostDerivationTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if result.wasSuccessful() else 1)
