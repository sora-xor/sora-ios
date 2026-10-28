#!/usr/bin/env python3
"""Run retained arm64 iOS crypto objects on macOS without changing any section.

Only Mach-O platform/minimum-version load-command metadata is changed. Every
file-backed section (including code, constants, relocations' targets and data)
is hashed before and after. The original input archive is never modified.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess


def sections(path):
    data = path.read_bytes()
    magic, _, _, _, ncmds, _, _, _ = struct.unpack_from('<8I', data)
    assert magic == 0xfeedfacf, path
    offset = 32
    result = []
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<II', data, offset)
        if cmd == 0x19:  # LC_SEGMENT_64
            nsects = struct.unpack_from('<I', data, offset + 64)[0]
            for i in range(nsects):
                section = offset + 72 + 80 * i
                sectname, segname, _, length, start = struct.unpack_from('<16s16sQQI', data, section)
                flags = struct.unpack_from('<I', data, section + 64)[0]
                if flags & 0xff in (1, 12, 18):  # zero-fill sections have no bytes
                    continue
                body = data[start:start + length]
                assert len(body) == length
                result.append({'section': (segname.rstrip(b'\0') + b',' + sectname.rstrip(b'\0')).decode(),
                               'length': length, 'sha256': hashlib.sha256(body).hexdigest()})
        offset += size
    return result


def run(args):
    subprocess.run([str(a) for a in args], check=True, capture_output=True)


def retarget_metadata(original, target):
    # vtool cannot grow old relocatable objects' load-command region. Replace
    # existing metadata in place; do not change command sizes or file offsets.
    data = bytearray(original.read_bytes())
    offset = 32
    changes = []
    for _ in range(struct.unpack_from('<I', data, 16)[0]):
        cmd, size = struct.unpack_from('<II', data, offset)
        if cmd == 0x32:  # LC_BUILD_VERSION
            before = bytes(data[offset:offset + size]).hex()
            struct.pack_into('<III', data, offset + 8, 1, 13 << 16, 13 << 16)
            changes.append({'offset': offset, 'before': before, 'after': bytes(data[offset:offset + size]).hex()})
        elif cmd in (0x24, 0x25, 0x2f, 0x30):  # LC_VERSION_MIN_*; same 16-byte shape
            before = bytes(data[offset:offset + size]).hex()
            struct.pack_into('<IIII', data, offset, 0x24, 16, 13 << 16, 13 << 16)
            changes.append({'offset': offset, 'before': before, 'after': bytes(data[offset:offset + size]).hex()})
        offset += size
    target.write_bytes(data)
    return changes


def retarget(source, destination):
    destination.mkdir(parents=True, exist_ok=True)
    thin = destination / 'original-arm64.a'
    run(['xcrun', 'lipo', source, '-thin', 'arm64', '-output', thin])
    names = subprocess.check_output(['ar', '-t', str(thin)], text=True).splitlines()
    assert len(names) == len(set(names)), 'Duplicate member names require lossless extraction'
    originals, adapted = destination / 'original-objects', destination / 'macos-objects'
    originals.mkdir(exist_ok=True)
    adapted.mkdir(exist_ok=True)
    subprocess.run(['ar', '-x', str(thin)], cwd=originals, check=True)
    manifest = {'sourceArchive': str(source), 'sourceSHA256': hashlib.sha256(source.read_bytes()).hexdigest(),
                'adaptation': 'Only existing Mach-O platform/minimum-version metadata is replaced in place with macOS 13.0; no algorithm edits',
                'objects': []}
    objects = []
    for name in names:
        if name.startswith('__.SYMDEF'):
            continue
        original, target = originals / name, adapted / name
        magic = struct.unpack_from('<I', original.read_bytes())[0]
        if magic in (0x0b17c0de, 0xdec04342):  # retained LLVM bitcode, not machine code
            result = subprocess.run(['xcrun', 'clang', '-arch', 'arm64', '-mmacosx-version-min=13.0',
                                     '-x', 'ir', '-c', str(original), '-o', str(target)],
                                    capture_output=True, text=True, check=True)
            manifest['objects'].append({'name': name, 'originalBitcodeSHA256': hashlib.sha256(original.read_bytes()).hexdigest(),
                                        'adaptation': 'Compile retained historical LLVM IR with host clang; target triple overridden only',
                                        'compilerDiagnostics': result.stderr})
            objects.append(target)
            continue
        before = sections(original)
        changes = retarget_metadata(original, target)
        assert sections(target) == before, 'Changed section bytes: ' + name
        manifest['objects'].append({'name': name, 'metadataChanges': changes, 'unchangedSections': before})
        objects.append(target)
    archive = destination / 'macos.a'
    run(['xcrun', 'libtool', '-static', '-o', archive, *objects])
    (destination / 'section-verification.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'{source.name}: {len(objects)} historical objects; native sections unchanged; retained bitcode separately recorded')
    return archive


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    retarget(args.source.resolve(), args.destination.resolve())
