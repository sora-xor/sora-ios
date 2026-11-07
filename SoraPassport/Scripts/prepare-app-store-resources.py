#!/usr/bin/env python3
"""Prepare app-owned languages in the built app.

Runs after linking/resource copying and before app signing, in every configuration.
(It used to also strip Xcode's empty dylib placeholders for the prebuilt static
xcframeworks blake2lib, libed25519, sr25519lib, FirebaseAnalytics and
GoogleAppMeasurement. Those binaries are gone: the crypto libraries are built from
source and Firebase is not linked, so there is nothing to strip.)
"""
import argparse
from pathlib import Path
import plistlib
import shutil


def prepare(app, localizations):
    app = Path(app)
    if app.suffix != ".app" or not app.is_dir():
        raise ValueError("Expected a built .app directory")
    with (app / "Info.plist").open("rb") as stream:
        info = plistlib.load(stream)

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
    print("Packaged Middle Egyptian as an in-app language")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", required=True, type=Path)
    parser.add_argument("--localizations", required=True, type=Path)
    args = parser.parse_args()
    prepare(args.app, args.localizations)
