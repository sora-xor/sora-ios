#!/usr/bin/env python3
"""Prepare app-owned languages and remove Xcode's unused static-framework stubs.

Runs after linking/resource copying and before app signing, in every configuration.
Static library code is already linked into the executable. Xcode 27 embeds empty
dylib placeholders for these five libraries, which produce spurious dSYM warnings.
Never remove a framework containing code, resources, or a runtime dependency.
"""
import argparse
from pathlib import Path
import plistlib
import re
import shutil
import subprocess


STATIC_STUBS = ("FirebaseAnalytics", "GoogleAppMeasurement", "blake2lib", "libed25519", "sr25519lib")


def output(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def is_static_archive(path):
    """A link-time `ar` archive, thin or universal: dyld never loads one."""
    if path.suffix != ".a":
        return False
    data = path.read_bytes()
    if data.startswith(b"!<arch>\n"):
        return True
    magic = int.from_bytes(data[:4], "big")
    if magic not in (0xCAFEBABE, 0xCAFEBABF):
        return False
    # fat_arch: offset at bytes 8..12; fat_arch_64: 8..16.
    entry, width = (20, 4) if magic == 0xCAFEBABE else (32, 8)
    count = int.from_bytes(data[4:8], "big")
    offsets = [int.from_bytes(data[8 + i * entry + 8:8 + i * entry + 8 + width], "big") for i in range(count)]
    return bool(offsets) and all(data[o:o + 8] == b"!<arch>\n" for o in offsets)


def prepare(app, localizations):
    app = Path(app)
    if app.suffix != ".app" or not app.is_dir():
        raise ValueError("Expected a built .app directory")
    with (app / "Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    executable = app / info["CFBundleExecutable"]
    frameworks = app / "Frameworks"
    binaries = [executable] + list(app.glob("*.dylib"))
    for framework in frameworks.glob("*.framework"):
        with (framework / "Info.plist").open("rb") as stream:
            name = plistlib.load(stream)["CFBundleExecutable"]
        binaries.append(framework / name)

    # Read every binary before removing anything. Ignore LC_ID_DYLIB (the
    # framework's own name); all actual load commands are dependencies.
    dependencies = []
    for binary in binaries:
        commands = output("/usr/bin/otool", "-l", str(binary))
        for command in re.split(r"Load command \d+", commands):
            if re.search(r"cmd LC_(?:LOAD|LOAD_WEAK|REEXPORT|LOAD_UPWARD)_DYLIB\b", command):
                dependencies.extend(re.findall(r"\bname (.+?) \(offset", command))

    removable = []
    for name in STATIC_STUBS:
        framework = frameworks / f"{name}.framework"
        if not framework.exists():
            continue
        binary = framework / name
        if any(f"/{name}.framework/" in path for path in dependencies):
            raise ValueError(f"{name} is a runtime dependency; refusing to remove it")
        commands = output("/usr/bin/otool", "-l", str(binary))
        sections = re.findall(r"sectname \S+\s+segname \S+\s+addr \S+\s+size (0x[0-9a-fA-F]+)", commands)
        if not sections or any(int(size, 16) for size in sections):
            raise ValueError(f"{name} contains code or data; refusing to remove it")
        if output("/usr/bin/nm", "-gjU", str(binary)).strip():
            raise ValueError(f"{name} contains exported symbols; refusing to remove it")
        # The simulator slices also carry the static archives the executable
        # was linked from (blake2lib-arm64.a, libed25519_sha2.a,
        # libsr25519crust.a); none is loaded at run time.
        extra = [p for p in framework.rglob("*") if p.is_file()
                 and p.relative_to(framework).parts[0] != "_CodeSignature"
                 and p.name not in (name, "Info.plist")
                 and not is_static_archive(p)]
        if extra:
            raise ValueError(f"{name} contains resources; refusing to remove it: {extra}")
        removable.append(framework)

    # Keep the source catalogs available to translation tooling, but do not
    # ship an unrecognized .lproj or list it in CFBundleLocalizations.
    language = "egy-Egyp"
    source = Path(localizations) / f"{language}.lproj"
    destination = app / "AppLanguages" / language
    destination.mkdir(parents=True, exist_ok=True)
    for name in ("Localizable.strings", "Localizable.stringsdict", "InfoPlist.strings"):
        shutil.copyfile(source / name, destination / name)
    if (app / f"{language}.lproj").exists() or language in info.get("CFBundleLocalizations", []):
        raise ValueError("Middle Egyptian must be an in-app language, not an Apple locale")
    for framework in removable:
        shutil.rmtree(framework)
        print(f"Removed unused static-library stub: {framework.name}")
    print("Packaged Middle Egyptian as an in-app language")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", required=True, type=Path)
    parser.add_argument("--localizations", required=True, type=Path)
    args = parser.parse_args()
    prepare(args.app, args.localizations)
